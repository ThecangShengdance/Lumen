## Lumen 1.0.2

### 新增
- 导入校验：检查 App Bundle 的 Info.plist、Bundle ID 与可执行文件
- 分片 MP4 自动修复：检测 Bilibili DASH 等 moof/mvex 视频，提示并重封装为标准 MP4
- 闲置轮播：主界面无操作后只浏览游戏、不启动游戏；默认 5 分钟，可设 1/3/5/10/15/30 分钟或关闭

### 修复
- 分片 MP4 宣传片只播放前 5 秒的问题
- 导入损坏 App 或无画面轨道视频时的错误提示

### 安装
- 适用于 macOS 14 及以上；预编译包为 Apple Silicon (arm64)
- 应用使用 ad-hoc 签名，未经过 Apple 公证；首次打开请在「系统设置 → 隐私与安全性」选择「仍要打开」

### 说明
- 由 GitHub Actions 从源码构建并自动生成安装包
- 当前源码：https://github.com/ThecangShengdance/Lumen
