# 应用资源

- `AppIcon.png`：1024 x 1024 图标源文件。
- `AppIcon.icns`：打包进 `PasteDeck.app` 的 macOS 图标。
- `MenuBarIcon.png`：菜单栏 Template Image 的 18 x 18 px（1×）版本。
- `MenuBarIcon@2x.png`：菜单栏 Template Image 的 36 x 36 px（2×）版本。

图形将 AppIcon 中的实心 `D` 与单层卡片轮廓合并，形成方形 Deck Mark；不包含箭头和剪贴板夹。

Xcode 构建时会将两张 PNG 自动合并为应用包内的多分辨率 `MenuBarIcon.tiff`。

如果更新 `AppIcon.png`，请同时重新生成并提交 `AppIcon.icns`，随后运行 `make verify` 检查应用包。
