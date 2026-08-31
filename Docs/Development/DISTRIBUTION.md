# PasteDeck 分发指南

## 发布模型

PasteDeck 采用无 Apple 开发者账号的开源分发方式：

- GitHub Actions 构建 universal macOS app。
- 正式构建入口是 `PasteDeck.xcodeproj` 中的 macOS Application target。
- app 和内部 SwiftPM 资源 bundle 使用 ad-hoc 签名。
- GitHub Release 提供 ZIP、DMG 及各自的 SHA-256 文件。
- 不使用 Developer ID、Apple Distribution、App Store Connect、公证或 provisioning profile。

这一方案成本为零且构建过程完全可审计，但不能获得 Apple 的开发者身份背书。下载的应用会被 Gatekeeper 视为未知开发者且未经公证，用户首次运行时必须手动确认。

## 持续集成

`.github/workflows/ci.yml` 在以下场景运行：

- 推送到 `main`
- Pull Request
- 手动触发

CI 执行 `make test` 和 `make verify`。验证范围包括 Info.plist、主程序、应用图标、本地化资源、第三方 Swift Package resource bundle、版本号、目标架构和代码签名。

`project.yml` 是可审计的工程源配置，`PasteDeck.xcodeproj` 是提交到仓库、供 Xcode 和 CI 直接使用的生成结果。修改 target、资源、构建设置或依赖后，应运行 `xcodegen generate` 并同时提交两者。普通构建与 CI 不需要安装 XcodeGen。

## 创建发布

发布由 [Conventional Commits](https://www.conventionalcommits.org/) 驱动，无需手动创建或推送标签：

1. 确保 `main` 上的 CI 已通过。
2. 使用 Conventional Commits 规范提交变更（`fix` 触发 patch、`feat` 触发 minor、`BREAKING CHANGE` 触发 major）。
3. 推送到 `main`。存在可发布变更时，release-please 会生成或更新一个 Release PR，其中包含版本号、`CHANGELOG.md` 和 `VERSION` 文件的更新。
4. 合并 Release PR。release-please 会创建对应的 `vX.Y.Z` 标签和 GitHub Release。

`.github/workflows/release.yml` 在 `release_created` 后于同一次运行中自动：

1. 从 release-please 输出解析版本号。
2. 检出该版本对应的提交。
3. 运行完整测试。
4. 以 `arm64 x86_64` 架构构建 universal app。
5. 对嵌套 bundle 和外层 app 进行 ad-hoc 签名。
6. 验证 bundle、签名和架构。
7. 使用 macOS 自带的 `ditto` 与 `hdiutil` 生成 ZIP 和 DMG。
8. 生成 SHA-256 文件并上传到已创建的 GitHub Release。

release-please 任务申请 `contents`、`issues`、`pull-requests` 的写权限以创建 Release PR；构建任务仅申请 `contents: write` 权限。两者都通过 GitHub 自动提供、且仅限当前仓库的 `GITHUB_TOKEN` 工作。作为一次性前置条件，仓库需在 Settings → Actions → General 中允许 GitHub Actions 创建 Pull Request。无需配置 Secrets，也不需要 PAT 或 Apple 凭据。

如需重跑已存在标签的发布，可在 Actions 页面手动运行 Release 工作流并输入标签。已存在的 Release 会覆盖同名构建产物，不会创建重复 Release。这是恢复手段，不是常规发布路径。

## 本地复现

构建当前机器架构：

```bash
make dist
```

构建和 CI 相同的 universal 产物：

```bash
VERSION=1.2.3 ARCHS="arm64 x86_64" make dist
```

输出目录：

```text
dist/
|-- PasteDeck.app
|-- PasteDeck-1.2.3.zip
|-- PasteDeck-1.2.3.zip.sha256
|-- PasteDeck-1.2.3.dmg
`-- PasteDeck-1.2.3.dmg.sha256
```

验证命令：

```bash
EXPECTED_VERSION=1.2.3 EXPECTED_ARCHS="arm64 x86_64" \
  ./script/verify_app.sh dist/PasteDeck.app
hdiutil verify dist/PasteDeck-1.2.3.dmg
(cd dist && shasum -a 256 -c PasteDeck-1.2.3.dmg.sha256)
(cd dist && shasum -a 256 -c PasteDeck-1.2.3.zip.sha256)
```

## 签名与 Gatekeeper 边界

ad-hoc 签名由 `codesign --sign -` 生成。它能让系统校验 bundle 内容在签名后是否改变，但没有可验证的开发者身份，也无法用于 Apple 公证。

首次打开时，用户应先核对来源和 SHA-256。若决定信任该构建，可在第一次启动被拦截后进入“系统设置 -> 隐私与安全性”，使用“仍要打开”。不要通过全局关闭 Gatekeeper 来安装 PasteDeck。

如果将来获得 Apple Developer Program 资格，可以在现有打包脚本之后增加 Developer ID 签名、hardened runtime 和公证步骤；在此之前，CI 不应出现任何 Apple 账号、证书或公证相关 Secret。

## 故障定位

- `Missing architecture`：SwiftPM 没有生成要求的 universal binary。
- `resource bundle is missing`：打包未复制 SwiftPM 的运行时资源，公开发布会启动失败。
- `code object is not signed at all`：嵌套 bundle 或外层 app 未完成签名。
- `hdiutil verify` 失败：DMG 损坏，不得上传 Release。
- GitHub Release 返回 403：检查工作流是否保留 `permissions: contents: write`。

参考：

- [Apple：安全地打开 Mac 应用](https://support.apple.com/102445)
- [Apple：ad-hoc 签名定义](https://developer.apple.com/documentation/security/seccodesignatureflags/adhoc)
- [GitHub：GITHUB_TOKEN](https://docs.github.com/actions/concepts/security/github_token)
- [GitHub：工作流权限语法](https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax)
