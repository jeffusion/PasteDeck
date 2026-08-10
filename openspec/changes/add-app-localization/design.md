## Context

PasteDeck 是 SwiftPM 构建的 macOS 13+ 菜单栏应用，发布包由 Makefile 手工组装。当前没有 `.lproj`、字符串目录或本地化访问层，用户可见字符串同时分布在 SwiftUI `Text`/`Button`、AppKit 窗口标题、模型计算属性和服务错误中。

现状审计确认以下文本需要纳入迁移：

- 抽屉搜索、筛选、数量、菜单和空状态；
- 卡片类型、时间、元数据、来源回退、上下文菜单和辅助功能动作；
- 设置四个页面、保留期限、快捷键编辑和确认/错误对话框；
- 辅助功能权限引导及相关窗口标题；
- 内容标题、预览、文件数量、字符数量、字节大小和用户可见服务错误。

## Goals / Non-Goals

### Goals

- 四种支持语言下，同一界面不再混入另一种语言的产品文案。
- 语言解析、字符串查找、格式化和回退行为可预测且可测试。
- 复数、相对时间、数量和单位符合目标语言习惯。
- 资源能进入最终 `.app`，而不只是存在于源码目录。
- 不破坏 macOS 13 兼容性和现有交互。

### Non-Goals

- 应用内即时切换语言。
- 自动翻译用户内容、来源应用名称或文件名。
- 以本地化为由重构业务架构或视觉布局。

## Decisions

### 1. 使用 macOS 原生首选语言，英语兜底

应用通过主 Bundle 的首选本地化选择 `zh-Hans`、`en`、`ja` 或 `ru`。macOS 系统语言和系统提供的“按 App 设置”入口是唯一语言来源；语言变更按系统惯例在重新启动应用后生效。

资源查找链为：精确支持的 localization -> 对应语言 -> `en`。当某个 key 在目标语言中缺失时，必须回退英语，不得直接显示 key，也不得依赖开发机器当前语言。

选择该方案的原因：macOS 已提供用户熟悉的应用语言管理；再增加应用内状态会要求动态替换 Bundle、刷新 AppKit 窗口和重建全部 SwiftUI 环境，复杂度高且不在当前需求中。

### 2. 采用 `.strings` 与 `.stringsdict`，建立统一访问层

每个 locale 使用 `Localizable.strings` 保存普通文案，使用 `Localizable.stringsdict` 保存条目数、文件数、字符数、天/周/月/年等需要复数或变量插值的文案。英语资源是 canonical key 集，其他三种语言必须与其保持 key 对等。

源码通过集中式 `L10n` API 读取字符串和格式化参数。稳定 key 使用按功能划分的命名，例如 `drawer.search.placeholder`、`card.action.pin`、`settings.general.title`、`permission.step.open_settings`。SwiftUI、AppKit 和模型层均使用同一入口，避免 `Text` 的隐式本地化与动态 `String` 混用。

### 3. 格式化 locale 与 App 展示语言绑定

语言解析层同时暴露当前 App locale。相对日期、数值、字节大小和单位格式必须显式使用该 locale，不能只依赖进程的 `Locale.current`，因为 macOS 的按 App 语言可能与系统区域设置不同。

用户数据保持原样：复制文本、文件名、来源 App 名称、标签和备注不参与翻译。技术标识如 `PNG`、`⌘`、`1...9` 也不本地化，但其周围说明文本必须本地化。

### 4. 本地化资源属于最终 App Bundle

资源存放在 SwiftPM target 内的 `Sources/Resources/<locale>.lproj`。Makefile 在组装 `.app` 时复制四个 `.lproj` 到 `Contents/Resources`，并在生成的 `Info.plist` 中声明 `CFBundleLocalizations`；`CFBundleDevelopmentRegion` 保持 `en`。

SwiftPM 继续负责源码编译和单元测试；资源测试直接验证仓库资源与最终 App Bundle。这样不引入仅为生成资源 Bundle 而存在的第二套查找路径，也不改变当前手工 App 打包结构。

### 5. 完整迁移以“用户能看到或听到”为边界

必须迁移：界面文字、菜单项、tooltip、窗口标题、警告/错误、辅助功能 label/value/action、模型生成的展示文本。

无需迁移：调试 `print`、内部错误 domain/key、通知名、SF Symbol 名称、URL、文件扩展名、序列化枚举 raw value，以及测试夹具中的用户内容。内部错误若最终会进入 alert，则在 UI 边界转换为本地化消息。

## Risks / Trade-offs

- **俄语文本膨胀：** 按钮和设置行可能比中文长。迁移时优先允许自然伸缩或截断说明文本，不改变固定卡片和抽屉尺寸；四种语言均需做视觉回归。
- **复数参数错误：** `.stringsdict` 的参数类型或顺序不一致会在运行时产生错误。测试必须解析全部资源并逐语言调用所有格式化 key。
- **遗漏隐藏入口：** 未接入的 `ClipListView`、辅助功能动作和服务错误也可能在未来重新出现，因此纳入迁移和硬编码扫描，不只处理当前首屏。
- **SwiftPM 与 App Bundle 差异：** `swift test` 的 `Bundle.main` 不是最终应用 Bundle。测试分为资源目录级验证和 `make app` 后的包内容验证，避免把单测环境误当发布环境。
- **现有 change 重叠：** `improve-clipboard-interactions` 仍处于 active 状态且涉及相同视图文件。本 change 只替换展示字符串与格式化，不改变其交互和布局契约。

## Migration Plan

1. 建立 `L10n` 及 app-locale 解析，先以英语资源覆盖全部 key。
2. 将所有用户可见字符串迁移到 key，并更新依赖展示字符串的测试。
3. 补齐简体中文、日语、俄语翻译及复数规则，运行 key/参数一致性测试。
4. 更新 Makefile 和 Info.plist 生成逻辑，构建 `.app` 并检查四套资源。
5. 分别以四种 `AppleLanguages` 启动应用，验证抽屉、设置、权限引导、菜单、卡片状态和无内容状态。

## Open Questions

无。当前范围明确采用系统/按 App 语言、四种语言和英语回退；应用内语言选择器留待独立需求评审。
