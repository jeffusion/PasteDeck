## ADDED Requirements

### Requirement: 支持四种应用语言

PasteDeck MUST 支持英语、简体中文、日语和俄语，并 MUST 使用英语作为开发语言和最终回退语言。

#### Scenario: 系统首选语言受支持

- **WHEN** macOS 为 PasteDeck 选择 `en`、`zh-Hans`、`ja` 或 `ru`
- **THEN** 应用在下次启动时使用对应语言显示全部产品文案

#### Scenario: 系统首选语言不受支持

- **WHEN** macOS 为 PasteDeck 提供的首选语言不属于四种支持语言
- **THEN** 应用使用英语显示全部产品文案
- **AND** 界面不得显示本地化 key

#### Scenario: 用户通过 macOS 修改单个 App 的语言

- **WHEN** 用户在 macOS 的按 App 语言设置中修改 PasteDeck 的语言并重新启动应用
- **THEN** 抽屉、设置窗口、权限引导和菜单使用新语言

### Requirement: 用户可见文案完整本地化

应用 MUST 将所有产品提供的可见或可听文本通过同一套本地化资源呈现，并 MUST 避免在任一支持语言界面中混入其他支持语言的硬编码产品文案。

#### Scenario: 用户浏览主要界面

- **WHEN** 用户打开抽屉并浏览搜索、筛选、数量、卡片、菜单和空状态
- **THEN** 所有产品文案使用当前 App 语言
- **AND** 用户复制的内容、文件名和来源 App 名称保持原样

#### Scenario: 用户打开辅助界面

- **WHEN** 用户打开设置、快捷键编辑、确认对话框或辅助功能权限引导
- **THEN** 标题、说明、按钮、状态和用户可见错误使用当前 App 语言

#### Scenario: 辅助技术读取界面

- **WHEN** VoiceOver 或其他辅助技术读取按钮、卡片状态、提示和自定义动作
- **THEN** accessibility label、value、hint 和 action 名称使用当前 App 语言

### Requirement: 动态内容按当前语言格式化

应用 MUST 使用当前 App 语言对应的 locale 格式化产品生成的数量、复数、相对时间、字节大小和时间单位。

#### Scenario: 数量发生变化

- **WHEN** 条目数、文件数、字符数或保留时间取值为目标语言的不同复数类别
- **THEN** 应用使用该语言的正确复数形式和词序
- **AND** 不通过拼接固定中文或英文后缀生成结果

#### Scenario: 卡片显示时间和大小

- **WHEN** 卡片显示相对时间、图片尺寸或文件大小
- **THEN** 相对时间、数字和单位使用当前 App 语言的格式规则
- **AND** 技术格式、文件扩展名和用户内容保持不变

### Requirement: 本地化资源完整且可回退

四个 locale 的资源 MUST 具有一致的 key 和兼容的格式参数，且单个目标翻译缺失时 MUST 回退到英语。

#### Scenario: 校验资源完整性

- **WHEN** 测试扫描四套 `Localizable.strings` 和 `Localizable.stringsdict`
- **THEN** 每套资源包含 canonical 英语资源的全部 key
- **AND** 不存在重复 key、空翻译或不兼容的格式参数

#### Scenario: 目标语言缺少单个 key

- **WHEN** 本地化访问层无法在当前语言资源中找到某个 key
- **THEN** 返回该 key 的英语翻译
- **AND** 不返回裸 key 或另一种非英语语言

### Requirement: 发布包包含本地化资源

应用构建流程 MUST 将四套语言资源嵌入最终 macOS App Bundle，并 MUST 在 App 元数据中声明支持的语言。

#### Scenario: 构建发布 App

- **WHEN** 开发者运行标准 `make app` 构建 PasteDeck
- **THEN** `.app/Contents/Resources` 包含 `en.lproj`、`zh-Hans.lproj`、`ja.lproj` 和 `ru.lproj`
- **AND** 每个目录包含运行所需的字符串资源
- **AND** `Info.plist` 声明四种 `CFBundleLocalizations` 和英语开发语言

### Requirement: 本地化不得改变既有交互和布局契约

本地化迁移 MUST 保持现有抽屉、搜索、筛选、卡片、快捷键、设置和权限流程行为，并 MUST 在四种语言下维持可读布局。

#### Scenario: 长文本语言显示界面

- **WHEN** 应用使用日语或俄语显示抽屉、设置和权限引导
- **THEN** 文字不得与相邻控件重叠或被不可恢复地裁切
- **AND** 固定尺寸按钮和卡片中的内容使用现有截断或换行规则

#### Scenario: 用户执行既有操作

- **WHEN** 用户搜索、切换类型、复制、粘贴、置顶、收藏、删除或编辑快捷键
- **THEN** 操作结果与本地化改造前一致
