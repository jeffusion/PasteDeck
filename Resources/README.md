# Resources 目录

此目录包含 PasteDeck 应用的资源文件。

## 应用图标 (AppIcon.icns)

### 如何创建 AppIcon.icns

1. **使用在线工具**：
   - 访问 https://cloudconvert.com/png-to-icns
   - 上传 1024x1024 PNG 图标
   - 下载生成的 .icns 文件

2. **使用 macOS 自带工具**：
   ```bash
   # 准备图标（需要 1024x1024 PNG）
   mkdir AppIcon.iconset
   sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png
   sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png
   sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png
   sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png
   sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png
   sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png
   sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png
   sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png
   sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png
   sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png

   # 生成 .icns 文件
   iconutil -c icns AppIcon.iconset -o AppIcon.icns

   # 移动到 Resources 目录
   mv AppIcon.icns Resources/
   ```

3. **使用第三方工具**：
   - [Image2Icon](https://img2icnsapp.com/) (免费 Mac 应用)
   - Sketch、Figma 等设计工具导出

### 图标设计建议

- **尺寸**：1024x1024 像素
- **格式**：PNG（透明背景）
- **风格**：简洁、现代、符合 macOS Big Sur+ 设计语言
- **内容**：剪贴板相关图标（如文档、粘贴板、层叠卡片等）
- **颜色**：建议使用品牌色或系统兼容色

### 当前状态

- ⚠️ **AppIcon.icns 尚未创建**
- 如果没有图标文件，构建脚本会跳过图标复制步骤
- DMG 和应用仍可正常构建，但会使用默认图标

## DMG 背景图 (可选)

如需自定义 DMG 安装窗口背景：

1. 创建 `dmg-background.png` 或 `dmg-background@2x.png`
2. 推荐尺寸：660x400 像素（标准）或 1320x800（Retina）
3. 设计建议：
   - 左侧：应用图标和名称
   - 右侧：Applications 文件夹图标
   - 中间：拖动箭头引导
   - 背景：渐变或纯色，避免过于复杂

## 文件清单

预期的资源文件：
- `AppIcon.icns` - 应用图标（必需，用于应用和 DMG）
- `dmg-background.png` - DMG 背景图（可选）
- `dmg-background@2x.png` - DMG 背景图 Retina 版本（可选）

当前状态：
- 📝 此 README 文件（说明文档）
