import Foundation
import GameController

/// Bridges GameController.framework into the same semantic actions used by the
/// keyboard. The manager only routes navigation — it never touches game processes.
@MainActor
final class GamepadManager: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var controllerName = ""
    @Published private(set) var batteryLevel: Float?

    var onAction: ((GamepadAction) -> Void)?
    var onConnectionChange: ((Bool, String, Float?) -> Void)?

    private var currentController: GCController?
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var heldDirection: PadDirection?
    private var repeatTask: Task<Void, Never>?

    private enum PadDirection: Equatable {
        case up, down, left, right
        var action: GamepadAction {
            switch self {
            case .up: .up
            case .down: .down
            case .left: .left
            case .right: .right
            }
        }
    }

    init() {
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let controller = note.object as? GCController
            Task { @MainActor in self?.activate(controller) }
        }

        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let controller = note.object as? GCController
            Task { @MainActor in self?.deactivate(controller) }
        }

        if let existing = GCController.controllers().first {
            activate(existing)
        } else {
            startDiscovery()
        }
    }

    deinit {
        if let connectObserver { NotificationCenter.default.removeObserver(connectObserver) }
        if let disconnectObserver { NotificationCenter.default.removeObserver(disconnectObserver) }
    }

    func rescan() {
        repeatTask?.cancel()
        startDiscovery()
        if let existing = GCController.controllers().first {
            activate(existing)
        }
    }

    private func startDiscovery() {
        GCController.startWirelessControllerDiscovery {}
    }

    private func activate(_ controller: GCController?) {
        guard let controller else { return }
        if currentController === controller, isConnected { return }
        currentController = controller
        controller.playerIndex = .index1

        isConnected = true
        controllerName = controller.vendorName ?? "无线手柄"
        batteryLevel = controller.battery?.batteryLevel
        configureHandlers(for: controller)
        onConnectionChange?(true, controllerName, batteryLevel)
    }

    private func deactivate(_ controller: GCController?) {
        guard controller == nil || controller === currentController else { return }
        clearHandlers()
        currentController = nil
        isConnected = false
        controllerName = ""
        batteryLevel = nil
        onConnectionChange?(false, "", nil)
    }

    private func configureHandlers(for controller: GCController) {
        if let pad = controller.extendedGamepad {
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.confirm) }
            }
            pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.cancel) }
            }
            pad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.options) }
            }
            pad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.favorite) }
            }
            pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.menu) }
            }
            pad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.menu) }
            }
            pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.previousTab) }
            }
            pad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.nextTab) }
            }

            pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
                Task { @MainActor in self?.handleStick(x: x, y: y) }
            }
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in
                Task { @MainActor in self?.handleStick(x: x, y: y) }
            }
        } else if let pad = controller.microGamepad {
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.confirm) }
            }
            pad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.options) }
            }
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in
                Task { @MainActor in self?.handleStick(x: x, y: y) }
            }
        }
    }

    private func clearHandlers() {
        guard let controller = currentController else { return }
        controller.extendedGamepad?.buttonA.pressedChangedHandler = nil
        controller.extendedGamepad?.buttonB.pressedChangedHandler = nil
        controller.extendedGamepad?.buttonX.pressedChangedHandler = nil
        controller.extendedGamepad?.buttonY.pressedChangedHandler = nil
        controller.extendedGamepad?.buttonMenu.pressedChangedHandler = nil
        controller.extendedGamepad?.buttonOptions?.pressedChangedHandler = nil
        controller.extendedGamepad?.leftShoulder.pressedChangedHandler = nil
        controller.extendedGamepad?.rightShoulder.pressedChangedHandler = nil
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = nil
        controller.extendedGamepad?.dpad.valueChangedHandler = nil
        controller.microGamepad?.buttonA.pressedChangedHandler = nil
        controller.microGamepad?.buttonX.pressedChangedHandler = nil
        controller.microGamepad?.dpad.valueChangedHandler = nil
    }

    private func handleStick(x: Float, y: Float) {
        let deadZone: Float = 0.48
        let releaseZone: Float = 0.3

        if abs(x) < releaseZone && abs(y) < releaseZone {
            setDirection(nil)
            return
        }
        guard abs(x) > deadZone || abs(y) > deadZone else { return }

        let direction: PadDirection
        if abs(x) > abs(y) {
            direction = x < 0 ? .left : .right
        } else {
            direction = y < 0 ? .down : .up
        }
        setDirection(direction)
    }

    private func setDirection(_ direction: PadDirection?) {
        guard direction != heldDirection else { return }
        heldDirection = direction
        repeatTask?.cancel()
        guard let direction else { return }

        emit(direction.action)
        repeatTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 360_000_000)
            while !Task.isCancelled {
                guard let self, self.heldDirection == direction else { return }
                self.onAction?(direction.action)
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func emit(_ action: GamepadAction) {
        Task { @MainActor in self.onAction?(action) }
    }
}
