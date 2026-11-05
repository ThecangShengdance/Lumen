import AVFoundation
import Foundation

struct TrailerInspection: Sendable {
    let url: URL
    let duration: Double
    let nominalDuration: Double
    let fragmentCount: Int
    let videoTracks: Int
    let audioTracks: Int

    var isFragmented: Bool { fragmentCount > 0 }
    var needsRepair: Bool {
        isFragmented && nominalDuration > duration + 0.4
    }

    var durationLabel: String {
        Self.format(duration)
    }

    var nominalLabel: String {
        Self.format(nominalDuration)
    }

    private static func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "未知" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let rest = total % 60
        return String(format: "%d:%02d", minutes, rest)
    }
}

enum TrailerInspector {
    struct InspectionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Checks the file's container, duration and tracks. The file is not modified.
    nonisolated static func inspect(_ url: URL) async throws -> TrailerInspection {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let boxes = topLevelBoxes(in: data)
            let fragments = boxes.filter { $0.type == "moof" }
            let metadata = movieMetadata(in: data, boxes: boxes)

            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let video = try await asset.loadTracks(withMediaType: .video)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            guard !video.isEmpty else {
                throw InspectionError(message: "这个视频没有可读取的画面轨道，请换一个 MP4 / MOV 文件。")
            }

            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite, seconds > 0.1 else {
                throw InspectionError(message: "无法读取视频时长，文件可能已损坏。")
            }

            return TrailerInspection(
                url: url,
                duration: seconds,
                nominalDuration: metadata.duration,
                fragmentCount: fragments.count,
                videoTracks: video.count,
                audioTracks: audio.count
            )
        }.value
    }

    /// Converts a fragmented MP4 into a standard MP4 by exporting each
    /// self-contained fragment, then assembling those files in a composition.
    /// This is deliberately native AVFoundation so the app does not bundle ffmpeg.
    nonisolated static func repair(
        _ url: URL,
        progress: @escaping @Sendable (Double, String) -> Void = { _, _ in }
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let boxes = topLevelBoxes(in: data)
            let fragments = boxes.filter { $0.type == "moof" }
            guard let firstFragment = fragments.first else {
                throw InspectionError(message: "没有检测到分片结构，无需修复。")
            }

            let fm = FileManager.default
            let work = fm.temporaryDirectory
                .appendingPathComponent("LumenTrailerRepair-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)

            let initData = data.prefix(firstFragment.offset)
            var segmentURLs: [URL] = []
            segmentURLs.reserveCapacity(fragments.count)

            for (index, fragment) in fragments.enumerated() {
                let end = index + 1 < fragments.count ? fragments[index + 1].offset : data.count
                guard end > fragment.offset else { continue }
                let segment = work.appendingPathComponent(String(format: "fragment-%03d.mp4", index))
                var payload = Data()
                payload.append(initData)
                payload.append(data.subdata(in: fragment.offset..<end))
                try payload.write(to: segment, options: .atomic)
                segmentURLs.append(segment)
            }

            guard !segmentURLs.isEmpty else {
                throw InspectionError(message: "分片读取失败，无法自动修复。")
            }

            var encoded: [URL] = []
            encoded.reserveCapacity(segmentURLs.count)
            for (index, segment) in segmentURLs.enumerated() {
                try Task.checkCancellation()
                let fraction = Double(index) / Double(segmentURLs.count) * 0.82
                progress(fraction, "正在整理第 \(index + 1) / \(segmentURLs.count) 段…")
                let output = work.appendingPathComponent(String(format: "segment-%03d.mp4", index))
                try await export(AVURLAsset(url: segment), to: output)
                encoded.append(output)
            }

            progress(0.86, "正在拼接完整宣传片…")
            let composition = AVMutableComposition()
            var cursor = CMTime.zero
            var videoTrack: AVMutableCompositionTrack?
            var audioTrack: AVMutableCompositionTrack?

            for (index, file) in encoded.enumerated() {
                try Task.checkCancellation()
                let asset = AVURLAsset(url: file)
                let duration = try await asset.load(.duration)
                guard duration.seconds > 0.01 else { continue }
                let videos = try await asset.loadTracks(withMediaType: .video)
                let audios = try await asset.loadTracks(withMediaType: .audio)
                if let source = videos.first {
                    if videoTrack == nil {
                        videoTrack = composition.addMutableTrack(
                            withMediaType: .video,
                            preferredTrackID: kCMPersistentTrackID_Invalid
                        )
                    }
                    try videoTrack?.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: source,
                        at: cursor
                    )
                }
                if let source = audios.first {
                    if audioTrack == nil {
                        audioTrack = composition.addMutableTrack(
                            withMediaType: .audio,
                            preferredTrackID: kCMPersistentTrackID_Invalid
                        )
                    }
                    try audioTrack?.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: source,
                        at: cursor
                    )
                }
                let fraction = 0.86 + Double(index) / Double(max(encoded.count, 1)) * 0.07
                progress(fraction, "正在拼接第 \(index + 1) / \(encoded.count) 段…")
                cursor = CMTimeAdd(cursor, duration)
            }

            guard cursor.seconds > 0.1 else {
                throw InspectionError(message: "拼接后的视频为空，无法完成修复。")
            }

            let repaired = work.appendingPathComponent("repair-\(UUID().uuidString.prefix(8)).mp4")
            progress(0.94, "正在写出标准 MP4…")
            try await export(composition, to: repaired)

            let finalAsset = AVURLAsset(url: repaired)
            let finalDuration = try await finalAsset.load(.duration)
            guard finalDuration.seconds > 0.2 else {
                throw InspectionError(message: "修复后的视频为空，请换一个文件试试。")
            }

            // Keep only the finished file; the fragment working files are no longer needed.
            for file in encoded { try? fm.removeItem(at: file) }
            for file in segmentURLs { try? fm.removeItem(at: file) }
            progress(1.0, "已修复为完整视频")
            return repaired
        }.value
    }

    // MARK: - MP4 boxes

    private struct Box {
        let type: String
        let offset: Int
        let size: Int
    }

    private static func topLevelBoxes(in data: Data) -> [Box] {
        var result: [Box] = []
        var cursor = 0
        while cursor + 8 <= data.count {
            let size32 = readUInt32(data, at: cursor)
            let type = fourCC(data, at: cursor + 4)
            var header = 8
            var size = Int(size32)
            if size32 == 1 {
                guard cursor + 16 <= data.count else { break }
                size = Int(readUInt64(data, at: cursor + 8))
                header = 16
            } else if size32 == 0 {
                size = data.count - cursor
            }
            guard size >= header, cursor + size <= data.count else { break }
            result.append(Box(type: type, offset: cursor, size: size))
            cursor += size
        }
        return result
    }

    private static func childBoxes(in data: Data, parent: Box) -> [Box] {
        var result: [Box] = []
        var cursor = parent.offset + 8
        let upper = parent.offset + parent.size
        while cursor + 8 <= upper {
            let size32 = readUInt32(data, at: cursor)
            let type = fourCC(data, at: cursor + 4)
            var header = 8
            var size = Int(size32)
            if size32 == 1 {
                guard cursor + 16 <= upper else { break }
                size = Int(readUInt64(data, at: cursor + 8))
                header = 16
            } else if size32 == 0 {
                size = upper - cursor
            }
            guard size >= header, cursor + size <= upper else { break }
            result.append(Box(type: type, offset: cursor, size: size))
            cursor += size
        }
        return result
    }

    private static func movieMetadata(in data: Data, boxes: [Box]) -> (duration: Double, isFragmented: Bool) {
        guard let moov = boxes.first(where: { $0.type == "moov" }) else { return (0, false) }
        let children = childBoxes(in: data, parent: moov)
        var movieDuration = 0.0
        if let mvhd = children.first(where: { $0.type == "mvhd" }) {
            let body = mvhd.offset + 8
            let version = data[body]
            if version == 1 {
                guard body + 32 <= data.count else { return (0, false) }
                let timescale = readUInt32(data, at: body + 20)
                let duration = readUInt64(data, at: body + 24)
                if timescale > 0 { movieDuration = Double(duration) / Double(timescale) }
            } else {
                guard body + 20 <= data.count else { return (0, false) }
                let timescale = readUInt32(data, at: body + 12)
                let duration = readUInt32(data, at: body + 16)
                if timescale > 0 { movieDuration = Double(duration) / Double(timescale) }
            }
        }

        var movieTimescale = 0.0
        if let mvhd = children.first(where: { $0.type == "mvhd" }) {
            let body = mvhd.offset + 8
            let version = data[body]
            let scaleOffset = version == 1 ? 20 : 12
            if body + scaleOffset + 4 <= data.count {
                movieTimescale = Double(readUInt32(data, at: body + scaleOffset))
            }
        }

        var fragmentDuration = 0.0
        if let mvex = children.first(where: { $0.type == "mvex" }),
           let mehd = childBoxes(in: data, parent: mvex).first(where: { $0.type == "mehd" }) {
            let body = mehd.offset + 8
            let version = data[body]
            let raw: Double
            if version == 1, body + 12 <= data.count {
                raw = Double(readUInt64(data, at: body + 4))
            } else if body + 8 <= data.count {
                raw = Double(readUInt32(data, at: body + 4))
            } else {
                raw = 0
            }
            let scale = movieTimescale > 0 ? movieTimescale : 1000
            fragmentDuration = raw / scale
        }
        return (max(movieDuration, fragmentDuration), boxes.contains(where: { $0.type == "moof" }))
    }

    private static func fourCC(_ data: Data, at offset: Int) -> String {
        guard offset + 4 <= data.count else { return "" }
        return String(bytes: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        guard offset + 8 <= data.count else { return 0 }
        return (UInt64(readUInt32(data, at: offset)) << 32) | UInt64(readUInt32(data, at: offset + 4))
    }

    private static func export(_ asset: AVAsset, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw InspectionError(message: "系统无法创建视频导出会话。")
        }
        session.outputURL = url
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                if session.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: session.error ?? InspectionError(message: "视频导出失败。"))
                }
            }
        }
    }
}
