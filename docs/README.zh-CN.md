# Beast Panorama

Apple Silicon 上的原生 360° 全景播放器，支持 VITURE Beast 实验性 3DoF 头追。使用 Swift、AppKit、Metal 与 AVFoundation 构建，当前界面为简体中文。

## 功能与限制

- 打开 2:1 等距柱状图片与视频；视频含音轨、循环播放、进度跳转。
- 头追、R 居中、视场角调节、全屏、自动隐藏控制栏。
- 可读取并调节眼镜亮度、镜片遮光和发光占空比。
- 已验证 60Hz；120Hz 只有尝试切换与回退逻辑，测试设备尚未实际达到高刷。
- HDR 当前为 SDR 预览，不支持立体视频。

本项目与 VITURE 无隶属关系。专有 SDK、厂商头文件、测试视频均不包含在仓库中。

## 构建

直接安装请前往 [Releases](https://github.com/AlexwellChen/beast-panorama/releases/tag/v0.2.0)，下载 **`Beast-Panorama-0.2.0-arm64-with-sdk.dmg`**。此版内置本机已验证的专有 SDK，无需另外下载或选择 SDK。请先阅读发布说明中的 SDK 条款、来源及尚未完成的第三方合规核查说明。仓库和默认构建仍不包含 SDK。

需要 Apple Silicon Mac、macOS 13+、Swift 5.9+ 和 Apple Command Line Tools 或 Xcode。

```sh
./scripts/test.sh
./scripts/build-app.sh
open 'dist/public/Beast Panorama.app'
```

无需 SDK 即可构建、运行鼠标模式和执行测试。头追需自行从 [VITURE 官网](https://www.viture.com/developer) 获取 macOS arm64 XR Glasses SDK，然后在「眼镜 → 选择 SDK…」中选择动态库。开发基于 2.4.0；参考 [SDK 配置](../SDK/README.md)。

快捷键：空格播放/暂停、R 居中、F 全屏、Esc 退出全屏、左右键跳转 5 秒、M 静音、⌘O 打开、⌘, 显示设置。

## 打包

```sh
./scripts/build-dmg.sh
```

默认生成不含专有 SDK 的公开分发包。本地 ad-hoc 签名尚未经过 Apple 公证。以前用于本机测试的 SDK 内置版 DMG 不应直接发布。

官方协议允许有条件地随应用分发 SDK，但当前镜像二进制对应的完整合规材料尚未核实。默认构建不含 SDK；Release 另提供附带条款和声明的内置版。详见 [授权核查](sdk-licensing.md) 和 [隐私说明](../Resources/Privacy.txt)。

更多信息：[贡献指南](../CONTRIBUTING.md)、[硬件实测](hardware.md)、[发布流程](releasing.md)、[第三方说明](../THIRD_PARTY_NOTICES.md)。
