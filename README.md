# PasteDeck

PasteDeck 是一个使用 SwiftUI 和 AppKit 编写的开源 macOS 剪贴板历史工具。

## 功能

- 记录文本、图片和文件类型的剪贴板内容
- 使用全局快捷键 `Command+Shift+V` 打开面板
- 搜索、收藏、置顶和删除历史记录
- 支持列表与网格视图
- 支持排除指定应用
- 数据保存在本机 Core Data 数据库中，不包含遥测

当前版本不提供 iCloud 同步，也没有对本地数据库进行额外加密。路线图中的功能不应被视为已实现能力。

## 系统要求

- macOS 13 Ventura 或更高版本
- 从源码构建需要 Xcode 16 或更高版本
- 支持 Apple Silicon 和 Intel Mac

## 安装发布版

从 [GitHub Releases](../../releases/latest) 下载对应版本的 DMG 或 ZIP。发布产物包含 universal binary，可同时运行在 `arm64` 与 `x86_64` Mac 上。

DMG 安装方式：

1. 打开 `PasteDeck-x.y.z.dmg`。
2. 将 `PasteDeck.app` 拖入 `Applications`。
3. 第一次尝试打开应用。
4. 如果 macOS 阻止启动，进入“系统设置 -> 隐私与安全性”，在安全性区域确认来源和校验值后选择“仍要打开”。

PasteDeck 没有使用 Developer ID 证书，也没有经过 Apple 公证。应用使用 ad-hoc 签名来保证 app bundle 内部结构完整，但该签名不能证明开发者身份，macOS 因此会要求用户手动确认。请只从本仓库的 Releases 下载，并在运行前核对同版本 `.sha256` 文件。

校验示例：

```bash
shasum -a 256 -c PasteDeck-1.2.3.dmg.sha256
```

## 本地开发

```bash
git clone <repository-url>
cd PasteDeck
make test
make app
make run
```

常用命令：

```bash
make test       # 运行 Swift 测试
make app        # 生成并 ad-hoc 签名 dist/PasteDeck.app
make verify     # 验证 Info.plist、资源、架构和代码签名
make dist       # 生成 ZIP、DMG 和 SHA-256 文件
make clean      # 清理本地产物
```

也可以直接运行 `./script/build_and_run.sh --verify`，或使用 Codex 项目环境中的 Run 操作。

## 项目结构

```text
PasteDeck/
|-- PasteDeck.xcodeproj/           标准 Xcode macOS 应用工程
|-- project.yml                    XcodeGen 工程源配置
|-- Config/Info.plist              应用 bundle 元数据
|-- Sources/PasteDeck/             应用源码
|-- Sources/Resources/             本地化资源
|-- Tests/PasteDeckTests/          单元测试
|-- Resources/                     应用图标
|-- script/                        构建、打包、验证与运行脚本
|-- .github/workflows/ci.yml       持续集成
`-- .github/workflows/release.yml  自动发布
```

## 发布

推送语义化版本标签会触发 GitHub Actions：

```bash
git tag v1.2.3
git push origin v1.2.3
```

工作流会运行 Xcode 测试，构建 `arm64 + x86_64` universal app，执行 ad-hoc 签名与结构校验，生成 ZIP/DMG 及 SHA-256 文件，最后创建或更新 GitHub Release。整个流程只使用仓库内置的 `GITHUB_TOKEN`，不需要 Apple 开发者账号或任何 Apple 凭据。

完整说明见 [分发指南](Docs/Development/DISTRIBUTION.md)，贡献方式见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 路线图

- iCloud 同步
- 导入与导出
- 自动更新
- 可选的 Developer ID 签名与公证（仅在未来具备开发者账号时）

## 许可证

[MIT](LICENSE)
