# Design Resources

此目录包含 PasteDeck 的设计源文件。

## 文件说明

### PasteDeck.psd
- **文件类型**: Adobe Photoshop 文档
- **用途**: 应用图标设计源文件
- **尺寸**: 1024×1024px
- **说明**: 如需修改应用图标，请编辑此文件后重新导出为 PNG，然后运行图标转换脚本

## 图标导出流程

1. 在 Photoshop 中编辑 `PasteDeck.psd`
2. 导出为 1024×1024 PNG 文件：`Resources/AppIcon.png`
3. 运行图标转换脚本：
   ```bash
   cd Resources
   # 生成 .iconset 目录
   mkdir -p AppIcon.iconset
   sips -z 16 16     AppIcon.png --out AppIcon.iconset/icon_16x16.png
   sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_16x16@2x.png
   sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_32x32.png
   sips -z 64 64     AppIcon.png --out AppIcon.iconset/icon_32x32@2x.png
   sips -z 128 128   AppIcon.png --out AppIcon.iconset/icon_128x128.png
   sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_128x128@2x.png
   sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_256x256.png
   sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_256x256@2x.png
   sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_512x512.png
   sips -z 1024 1024 AppIcon.png --out AppIcon.iconset/icon_512x512@2x.png

   # 转换为 .icns
   iconutil -c icns AppIcon.iconset -o AppIcon.icns

   # 清理临时文件
   rm -rf AppIcon.iconset
   ```
4. 重新构建应用：`./Scripts/build-dmg.sh`

## 设计规范

- **图标风格**: 简约现代
- **主色调**: 根据应用主题
- **导出格式**: PNG (1024×1024) → .icns (macOS 图标格式)
- **分辨率**: 支持 Retina 显示屏 (@1x 和 @2x)
