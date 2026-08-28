# PasteDeck 动画对比原型设计系统 (DESIGN.md)

本文件记录了 PasteDeck 底部抽屉（Drawer）的视觉 Token、组件结构、三种动画方向的 Token、减弱动态（reduced-motion）行为以及无障碍约束。

## 1. 视觉 Token (Visual Tokens)

### 1.1 几何尺寸 (Geometry)
* **底部抽屉高度 (Drawer Height)**: `280px`
* **头部高度 (Header Height)**: `44px`
* **卡片区域高度 (Card Region Height)**: `212px` (包含 `16px` 的上下内边距)
* **卡片尺寸 (Card Size)**: `180px * 180px`
* **卡片圆角 (Card Corner Radius)**: `8px`
* **卡片间距 (Card Spacing)**: `12px`
* **内容内边距 (Content Padding)**: `16px`
* **搜索框尺寸 (Search Size)**: 折叠时宽度 `34px`，展开时宽度 `210px`，高度 `34px`，圆角 `10px`

### 1.2 颜色与材质 (Colors & Materials)
* **抽屉背景 (Drawer Background)**: macOS 磨砂玻璃效果 (Frosted Glass)
  * 暗色模式: `rgba(30, 30, 30, 0.75)`，伴随 `backdrop-filter: blur(20px) saturate(140%)`
  * 亮色模式: `rgba(245, 245, 245, 0.8)`，伴随 `backdrop-filter: blur(20px) saturate(140%)`
* **卡片背景 (Card Background)**:
  * 暗色模式: `rgba(45, 45, 45, 0.8)`
  * 亮色模式: `rgba(255, 255, 255, 0.9)`
* **卡片边框 (Card Border)**:
  * 默认状态: `1px` 实线，暗色 `rgba(255, 255, 255, 0.1)`，亮色 `rgba(0, 0, 0, 0.1)`
  * 悬停状态: `1px` 实线，暗色 `rgba(255, 255, 255, 0.3)`，亮色 `rgba(0, 0, 0, 0.3)`
  * 选中状态: `2px` 实线，macOS 强调色 (Accent Color, 通常为蓝色 `#007aff`)
* **卡片阴影 (Card Shadow)**:
  * 未选中: `0 2px 4px rgba(0, 0, 0, 0.14)`
  * 选中: `0 4px 8px rgba(0, 0, 0, 0.20)`
* **卡片头部语义色 (Card Header Semantic Colors)**:
  * 文本 (Text): `#173866` (暗蓝色)
  * 图片 (Image): `#1c6e66` (暗青色)
  * 文件 (Files): `#4f5966` (暗灰色)
  * 颜色 (Color): `#a65c14` (暗橙色)

---

## 2. 组件结构 (Component Anatomy)

* **Drawer (抽屉容器)**: 固定在屏幕底部，高度 `280px`，宽度 `100%`。
* **Header (头部)**: 高度 `44px`，包含分类切换（Tabs）和搜索框（Search Bar）。
* **Category Tabs (分类标签)**: 包含 `All`, `Text`, `Image`, `Files` 四个分类。
* **Search Bar (搜索框)**: 位于头部右侧，支持点击/聚焦展开，失去焦点且为空时折叠。
* **Card Grid (卡片网格)**: 水平滚动的卡片列表，支持键盘左右键切换选中卡片。
* **Clip Card (剪贴板卡片)**: `180px` 见方，包含头部（显示类型和时间）、内容预览区、底部（显示来源应用和大小/字数）。

---

## 3. 动画方向 Token (Motion Direction Tokens)

本原型实现了三种可选的动画方向，用于对比不同的交互体验：

### 3.1 方向 A: Native Snappy (原生脆爽)
* **设计理念**: 匹配 macOS 原生系统的快速、利落的响应，无多余修饰，追求极致的效率感。
* **抽屉进入 (Drawer Enter)**:
  * 变换: `translateY(280px) -> translateY(0)`
  * 持续时间: `150ms`
  * 缓动曲线: `cubic-bezier(0.16, 1, 0.3, 1)` (easeOutExpo)
* **抽屉退出 (Drawer Exit)**:
  * 变换: `translateY(0) -> translateY(280px)`
  * 持续时间: `120ms`
  * 缓动曲线: `cubic-bezier(0.7, 0, 0.84, 0)` (easeInExpo)
* **分类切换 (Category Switch)**:
  * 共享卡片移动 (FLIP): `180ms`, `cubic-bezier(0.16, 1, 0.3, 1)`
  * 新卡片进入/旧卡片离开: `120ms` 淡入淡出，无缩放
* **搜索展开 (Search Expand)**:
  * 宽度变化: `34px -> 210px`
  * 持续时间: `200ms`
  * 缓动曲线: `cubic-bezier(0.16, 1, 0.3, 1)`

### 3.2 方向 B: Spatial Spring (空间弹簧)
* **设计理念**: 强调物理空间感和连续性，卡片在切换分类时会像有弹性的实体一样平滑滑移，带来生动、有机的交互体验。
* **抽屉进入 (Drawer Enter)**:
  * 变换: `translateY(280px) -> translateY(0)`，伴随轻微的过冲（Overshoot）
  * 持续时间: `320ms`
  * 缓动曲线: `cubic-bezier(0.34, 1.56, 0.64, 1)` (弹簧过冲曲线)
  * 子元素进入: 卡片采用 `30ms` 的交错（Stagger）延迟，从下往上微弱弹跳进入
* **抽屉退出 (Drawer Exit)**:
  * 变换: `translateY(0) -> translateY(280px)`，伴随轻微的下沉回弹
  * 持续时间: `250ms`
  * 缓动曲线: `cubic-bezier(0.36, 0, 0.66, -0.56)`
* **分类切换 (Category Switch)**:
  * 共享卡片移动 (FLIP): `350ms`，使用强烈的空间连续性弹簧效果，缓动曲线 `cubic-bezier(0.175, 0.885, 0.32, 1.1)`
  * 新卡片进入/旧卡片离开: `250ms`，伴随缩放 `scale(0.8 -> 1.0)` 和淡入淡出
* **搜索展开 (Search Expand)**:
  * 宽度变化: `34px -> 210px`，伴随轻微的弹性过冲
  * 持续时间: `280ms`
  * 缓动曲线: `cubic-bezier(0.175, 0.885, 0.32, 1.1)`

### 3.3 方向 C: Soft Material (柔和材质)
* **设计理念**: 模仿高档纸张或流体材质，强调优雅、平滑和视觉舒适度，适合长时间使用而不产生视觉疲劳。
* **抽屉进入 (Drawer Enter)**:
  * 变换: `translateY(40px) -> translateY(0)`，同时 `scale(0.96 -> 1.0)`，`opacity(0 -> 1)`，伴随 `backdrop-filter: blur(0px -> 20px)`
  * 持续时间: `280ms`
  * 缓动曲线: `cubic-bezier(0.215, 0.61, 0.355, 1)` (easeOutCubic)
* **抽屉退出 (Drawer Exit)**:
  * 变换: `translateY(0) -> translateY(20px)`，`scale(1.0 -> 0.98)`，`opacity(1 -> 0)`
  * 持续时间: `220ms`
  * 缓动曲线: `cubic-bezier(0.55, 0.055, 0.675, 0.19)`
* **分类切换 (Category Switch)**:
  * 共享卡片移动 (FLIP): `300ms`，柔和的渐变/模糊与温和的移动，缓动曲线 `cubic-bezier(0.4, 0, 0.2, 1)` (easeInOutQuad)
  * 新卡片进入/旧卡片离开: `250ms`，伴随轻微的模糊渐变 `filter: blur(4px -> 0px)` 和淡入淡出
* **搜索展开 (Search Expand)**:
  * 宽度变化: `34px -> 210px`
  * 持续时间: `250ms`
  * 缓动曲线: `cubic-bezier(0.4, 0, 0.2, 1)`

---

## 4. 减弱动态行为 (Reduced Motion Behavior)

* **触发条件**: 开启页面内的 "Reduced Motion" 开关，或系统检测到 `prefers-reduced-motion: reduce`。
* **行为规范**:
  * 禁用所有空间位移（`translate`）、缩放（`scale`）和过冲（`overshoot`）动画。
  * 状态切换（抽屉开关、分类切换、搜索展开）采用近乎瞬时的淡入淡出（`opacity`，持续时间 `<= 50ms`）或直接瞬间切换。
  * 确保状态变化的即时性和确定性，不影响任何功能和键盘导航。

---

## 5. 无障碍与语义约束 (Accessibility & Semantics)

* **语义化 HTML**:
  * 分类切换使用 `role="tablist"`，每个标签使用 `role="tab"`，并正确维护 `aria-selected` 和 `aria-controls` 属性。
  * 搜索框和按钮使用标准的 `<input>` 和 `<button>` 元素，并配有明确的 `aria-label`。
* **键盘导航 (Keyboard Navigation)**:
  * 支持 `Tab` 键在控制区和卡片之间切换焦点。
  * 聚焦到卡片列表时，支持使用键盘 `Left` 和 `Right` 箭头键切换选中的卡片，并自动滚动使选中卡片可见。
  * 支持 `Escape` 键：
    * 当搜索框聚焦时，按 `Escape` 清除搜索内容并折叠搜索框。
    * 当抽屉打开时，按 `Escape` 关闭抽屉。
  * 支持 `Enter` 键：在选中卡片上按 `Enter` 模拟复制并粘贴操作。
* **视觉焦点环 (Focus Rings)**:
  * 所有可聚焦元素在通过键盘聚焦时，必须显示清晰、高对比度的焦点环（例如 `outline: 2px solid var(--accent-color)`）。
