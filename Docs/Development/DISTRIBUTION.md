# PasteDeck 分发指南

## 概述

PasteDeck 现已配置为通过 DMG 文件分发，无需 Apple Developer Account（$99/年）。

## 当前配置

### ✅ 已完成的设置

1. **Resources 目录**
   - 位置：`Resources/`
   - 用途：存放应用图标和 DMG 背景图
   - 状态：已创建，包含说明文档
   - 待办：添加实际的 `AppIcon.icns` 文件（参见 `Resources/README.md`）

2. **构建系统**
   - `Makefile`：统一的构建系统
     - `make app`：构建 .app bundle
     - `make sign`：Ad-hoc 签名
     - `make dmg`：完整的 DMG 构建流程
     - 版本号从 `VERSION` 文件读取

3. **自动化版本管理（release-please）**
   - 配置文件：
     - `.release-please-manifest.json`: 版本清单
     - `release-please-config.json`: 详细配置
   - Workflow: `.github/workflows/release-please.yml`
   - 触发：推送到 main 分支
   - 功能：
     - 分析 Conventional Commits 自动确定版本号
     - 自动生成/更新 CHANGELOG.md
     - 创建 Release PR 供人工审查
     - 合并 PR 后自动构建 DMG 并发布

4. **提交规范工具**
   - commitizen: 交互式创建 Conventional Commits
   - Git hooks: 强制验证提交信息格式
   - 安装脚本：`.githooks/install.sh`

5. **README.md 更新**
   - 添加详细的 DMG 安装说明
   - macOS Sequoia 专用的安装步骤
   - 解释为什么需要手动批准
   - 从源代码构建的说明

5. **签名验证**
   - ✅ Ad-hoc 签名正常工作
   - ✅ 签名验证通过
   - ✅ 应用可以正常运行

## 下一步操作

### 1. 安装 create-dmg 工具

```bash
brew install create-dmg
```

### 2. 创建应用图标（可选但推荐）

**方法一：使用在线工具**
- 访问 https://cloudconvert.com/png-to-icns
- 上传 1024x1024 PNG 图标
- 下载 .icns 文件到 `Resources/AppIcon.icns`

**方法二：使用 macOS 命令行**
参见 `Resources/README.md` 的详细说明

### 3. 测试 DMG 构建

```bash
make dmg
```

预期输出：
- ✅ 应用构建成功
- ✅ 资源复制（如果图标存在）
- ✅ Ad-hoc 签名成功
- ✅ DMG 创建成功
- 📦 生成 `PasteDeck-1.0.0.dmg`

### 4. 测试 DMG 安装

1. 双击打开生成的 DMG 文件
2. 拖拽应用到 Applications 文件夹
3. 测试首次运行和系统批准流程
4. 确认所有功能正常工作

### 5. 发布到 GitHub（自动化流程）

**日常开发流程**:

1. **使用 Conventional Commits 格式提交**
   ```bash
   # 推荐：使用 commitizen 辅助工具
   cz commit

   # 或手动编写规范提交
   git commit -m "feat(ui): 添加深色模式支持"
   git commit -m "fix(clipboard): 修复内存泄漏"
   ```

2. **推送到 main 分支**
   ```bash
   git push origin main
   ```

3. **release-please 自动化**
   - 自动分析提交历史
   - 自动创建/更新 Release PR
   - PR 包含：
     - 更新的 VERSION 文件
     - 生成的 CHANGELOG.md
     - 计算的新版本号

4. **审查并合并 Release PR**
   - 检查 CHANGELOG 准确性
   - 确认版本号符合预期
   - 合并 PR

5. **自动发布**
   - 创建 Git tag (如 v1.1.0)
   - 构建签名的 .app 和 DMG
   - 创建 GitHub Release
   - 上传 DMG 和 SHA256 文件

**版本号自动计算规则**:
- `feat:` → MINOR 版本递增 (1.0.0 → 1.1.0)
- `fix:` → PATCH 版本递增 (1.0.0 → 1.0.1)
- `BREAKING CHANGE:` → MAJOR 版本递增 (1.0.0 → 2.0.0)

## 分发选项对比

### 当前方案：Ad-hoc 签名 DMG

**成本**：$0/年

**优点**：
- 免费
- 专业的 DMG 安装体验
- 适合开源项目
- 通过 GitHub 分发

**缺点**：
- 用户首次运行需要手动批准
- 无法自动更新
- 无法进入 Mac App Store

**用户体验**：
- 下载和安装：简单（拖拽）
- 首次运行：需要 6 步手动批准（2-3 分钟）
- 后续使用：完全正常

### 未来选项：Developer ID 签名

**成本**：$99/年（Apple Developer Program）

**优点**：
- 用户可以直接运行
- 无需手动批准
- 可以公证（Notarization）
- 专业可信度
- 可以上架 Mac App Store

**缺点**：
- 需要年费
- 需要公证流程

**建议时机**：
- 当用户数超过 100
- 准备商业化
- 需要上架 App Store

## 技术细节

### Ad-hoc 签名

```bash
codesign --force --deep -s - PasteDeck.app
```

- `-s -`：使用 ad-hoc 签名（无证书）
- `--force`：替换现有签名
- `--deep`：递归签名所有内容

### DMG 创建选项

```bash
create-dmg \
  --volname "PasteDeck" \          # DMG 卷标名称
  --window-size 660 400 \           # 窗口大小
  --icon-size 100 \                 # 图标大小
  --app-drop-link 500 185 \         # Applications 快捷方式位置
  --volicon "Resources/AppIcon.icns" \  # DMG 图标
  --background "Resources/dmg-background.png" \  # 背景图（可选）
  "PasteDeck-1.0.0.dmg" \          # 输出文件名
  ".build/PasteDeck.app"           # 输入应用
```

### GitHub Actions 环境

- 运行环境：`macos-latest`（macOS 14+ Sonoma）
- Swift 版本：5.9
- 自动安装 create-dmg
- 从 Git 标签提取版本号
- 自动生成 SHA256 校验和

## 用户安装体验（macOS Sequoia）

### 完整流程

1. **下载**：GitHub Releases → 下载 DMG（5-10 秒）
2. **安装**：打开 DMG → 拖拽到 Applications（30 秒）
3. **首次运行**：
   - 双击应用 → 警告对话框
   - 系统设置 → 隐私与安全性
   - 点击"仍要打开"
   - 输入密码
   - 确认打开
   - 总计：2-3 分钟（仅一次）
4. **后续使用**：正常打开，无任何提示

### 关键说明点

向用户强调：
- ✅ 这是正常的安全流程
- ✅ 完全安全（开源软件）
- ✅ 仅需一次操作
- ✅ 不是病毒或恶意软件

## 常见问题

### Q: 为什么不购买 Developer Account？

A: 对于早期开源项目：
- 年费 $99 对个人开发者负担
- Ad-hoc 签名完全够用
- 可以随时升级

### Q: 用户会不会觉得麻烦？

A: 技术用户（开源项目的主要受众）：
- 熟悉这个流程
- 能理解技术原因
- 愿意多几步操作支持开源

### Q: 能否用 Homebrew 分发？

A: 可以，但：
- Homebrew 2024+ 不支持未签名应用
- 用户仍需手动批准
- 限制在技术用户群体
- DMG 更通用

### Q: 如何更新应用？

A: 当前手动更新：
1. 下载新版本 DMG
2. 替换 Applications 中的旧版本

未来可以添加 Sparkle 自动更新框架。

## 成功指标

分发方案成功的标志：
- ✅ 构建流程自动化
- ✅ GitHub Actions 成功运行
- ✅ DMG 文件可以正常安装
- ✅ 用户能够成功运行应用
- ✅ 收到用户反馈和 bug 报告

## 参考资源

- [create-dmg 文档](https://github.com/create-dmg/create-dmg)
- [macOS 代码签名指南](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Gatekeeper 工作原理](https://support.apple.com/en-us/HT202491)
- 类似项目：
  - [Maccy](https://github.com/p0deje/Maccy)
  - [Rectangle](https://github.com/rxhanson/Rectangle)
  - [AltTab](https://github.com/lwouis/alt-tab-macos)

---

最后更新：2025-11-30
