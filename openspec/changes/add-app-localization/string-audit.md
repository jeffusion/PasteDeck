# 用户可见字符串审计

## 审计边界

判定原则不是“字符串是否出现在 View 文件”，而是用户是否能在界面中看到或通过辅助技术听到。任何进入窗口、菜单、卡片、tooltip、alert、辅助功能语义或用户可见错误的产品文本都必须本地化。

## 必须迁移

| 区域 | 当前文件 | 必须覆盖的内容 |
| --- | --- | --- |
| 抽屉与 Header | `Views/MainWindow.swift` | 搜索占位、搜索/清除提示、筛选名称、条目数量、更多菜单、设置/关于/退出、空状态标题与说明 |
| 卡片 | `Views/ClipCardView.swift` | 内容类型、时间、字符/文件元数据、未知来源、置顶/收藏状态、上下文菜单、tooltip、辅助功能 label/value/action |
| 备用列表 | `Views/ClipListView.swift` | 内容摘要、来源/时间/大小标签和全部上下文菜单 |
| 设置导航 | `Views/SettingsView.swift` | 通用、隐私、快捷键、关于四个 tab 名称及窗口内容 |
| 通用设置 | `Views/SettingsView.swift` | 登录、同步、菜单栏、音效、粘贴模式、纯文本、历史保留和删除历史 |
| 隐私设置 | `Views/SettingsView.swift` | 权限状态、说明、排除应用、空状态和添加/删除动作 |
| 快捷键设置 | `Views/SettingsView.swift` | 基础动作、快速粘贴说明、修饰键编辑、预览、校验、重置/确认/取消 |
| 关于设置 | `Views/SettingsView.swift` | 版本格式、产品说明、GitHub、问题反馈和许可证名称 |
| 设置对话框 | `Views/SettingsView.swift` | 设置失败、保留期限确认、清理结果、删除数量和按钮 |
| 保留期限 | `Views/RetentionSlider.swift` | 天、周、月、年、永久及带数量的当前值 |
| 权限引导 | `Views/PermissionGuideView.swift` | 三步标题、说明、按钮、等待/成功状态和功能差异 |
| AppKit 窗口 | `App/AppDelegate.swift`、`Services/AccessibilityPermissionGuide.swift` | 设置和辅助功能权限窗口标题 |
| 内容模型 | `Models/ClipContent.swift` | 富文本/文本/图片/文件/颜色类型名、图片摘要、文件数、字符数和 footer 元数据 |
| 条目模型 | `Models/ClipItem.swift` | 图片标题、多文件标题、内容筛选名称、日期筛选名称、相对时间和大小 |
| 用户可见服务错误 | `Services/LaunchAtLoginService.swift` 及 UI 消费边界 | 登录项启用/禁用失败等最终进入界面的错误 |
| 快捷键状态 | `Services/HotKeyManager.swift` | “未设置”等展示状态 |

## 动态格式 key

以下内容禁止继续通过字符串拼接实现，必须使用格式参数或复数资源：

- 当前显示和已捕获的条目数；
- 文本字符数；
- 单个/多个文件数量及预览摘要；
- 已删除的历史记录数量；
- 1 天到永久的保留期限及缩短期限警告；
- 图片尺寸中的数字格式；
- 相对时间和文件大小；
- 快捷键预览中可变修饰键组合。

## 允许保留原样

| 类别 | 示例 | 原因 |
| --- | --- | --- |
| 品牌 | `PasteDeck`、`GitHub`、`iCloud` | 专有名称 |
| 用户内容 | 剪贴板文本、文件名、来源 App 名称、标签、备注 | 不得篡改用户数据 |
| 技术格式 | `PNG`、`JPEG`、`#FF0000`、`rgb(...)`、`1920 × 1080` | 跨语言技术表示；数字部分仍按 app locale 处理 |
| 快捷键符号 | `⌘`、`⌃`、`⌥`、`⇧`、`1...9` | macOS 标准符号；周围说明需要翻译 |
| 内部标识 | UserDefaults key、CloudKit key、通知名、枚举 raw value | 不展示给用户且涉及兼容性 |
| 系统资源名 | SF Symbol 名称、MIME type、URL scheme | 机器读取标识 |
| 开发者输出 | `print` 日志、编码错误 debugDescription、测试夹具 | 不属于产品 UI；若错误进入 alert，需在 UI 边界转译 |
| 版权主体 | `© 2025 PasteDeck Contributors` | 法定/专有主体保持不变；许可证周围文本可翻译 |

## 回归扫描规则

实施后对 `Sources/PasteDeck` 的字符串字面量执行扫描，并按以下顺序判定：

1. 用户可见或可听：必须改为 `L10n` key。
2. 用户数据或技术标识：允许保留。
3. 仅日志/持久化/API 标识：允许保留，但不得被 View 直接展示。
4. 无法证明属于白名单：按用户可见处理并迁移。

扫描结果必须人工复核，不能仅依赖“源码中不存在中文字符”，因为当前英文硬编码同样是问题。
