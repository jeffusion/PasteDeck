# Change: 改进剪贴板抽屉交互反馈

## Why

当前状态栏图标视觉尺寸偏大，搜索框展开时会改变中心位置，置顶后缺少持久反馈，卡片选择还会强制居中。这些行为降低了界面协调性和操作稳定感。

## What Changes

- 缩小状态栏图标的视觉尺寸，但保持系统点击区域不变。
- 将搜索框固定在抽屉左侧，并只向右展开。
- 在置顶卡片标题栏显示持久的图钉图标和可访问性状态。
- 选择卡片时仅在卡片未完整可见时执行最小必要滚动。

## Impact

- Affected specs: `menu-bar-access`, `clipboard-drawer`
- Affected code:
  - `Sources/PasteDeck/App/AppDelegate.swift`
  - `Sources/PasteDeck/Views/MainWindow.swift`
  - `Sources/PasteDeck/Views/ClipCardView.swift`
  - `Sources/PasteDeck/Views/CardGridView.swift`
- 不修改数据模型、持久化格式、排序规则或卡片尺寸。
