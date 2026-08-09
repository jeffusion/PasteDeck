## ADDED Requirements

### Requirement: 协调的状态栏图标

系统 MUST 以与 macOS 状态栏相协调的视觉尺寸显示 PasteDeck 图标，同时保持系统提供的点击区域和辅助功能描述。

#### Scenario: 应用创建状态栏入口

- **WHEN** PasteDeck 创建菜单栏状态项
- **THEN** 系统使用 14pt 的 `doc.on.clipboard` SF Symbol
- **AND** 图像按比例缩小
- **AND** `NSStatusBarButton` 的系统点击区域不因图像缩小而改变
- **AND** 状态栏按钮仍提供 `PasteDeck` 辅助功能描述
