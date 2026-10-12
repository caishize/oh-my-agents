# oh-my-agents for Codex

专用于 Codex 的 `codex` 分支（`4.0.0-codex.1`）。Claude Code 版本保留在 `main`。
围绕架构约束、文档、可观测性和熵管理，提供 **11 个技能、原生 Hook 和质量决策信号**。

## 安装

需要支持插件的 Codex CLI（已验证 `0.162.1`）、Bash、Git、jq 和 Python 3.10+。
在 macOS 上还需要提供 `flock`，用于锁定 JSONL 日志写入。

先从本地分支安装，适用于尚未推送的开发版本：

```bash
cd /path/to/oh-my-agents
codex plugin marketplace add .
codex plugin add oh-my-agents@oh-my-agents-codex
codex plugin list --json
```

分支推送后，可从 GitHub 安装（本次迁移不自动推送）：

```bash
codex plugin marketplace add caishize/oh-my-agents --ref codex
codex plugin add oh-my-agents@oh-my-agents-codex
```

重新打开 Codex 会话，按主机的提示信任并启用插件 Hook。Hook 未启用时，技能仍可用，
但不会在编辑前自动拦截。安装、主机能力和云端限制见 [Codex 兼容性](docs/CODEX.md)。
也可将整个仓库放到项目 `.agents/skills/oh-my-agents/` 下，作为仅技能的备用安装；
必须保留完整目录，让技能中的共享脚本和模板引用有效。该方式不注册插件 Hook，
技能调用使用不带插件前缀的 `$harness-init`、`$verify` 等名称。

## 使用

在 Codex 消息中引用技能，参数写在技能名后：

```text
$oh-my-agents:harness-init --quick
$oh-my-agents:spec-to-task docs/product-specs/feature.md
$oh-my-agents:verify all
$oh-my-agents:harness-review
$oh-my-agents:harness-review --audit
$oh-my-agents:lifecycle next
```

| 技能 | 用途 |
|---|---|
| `$oh-my-agents:harness-init` | 保留已有内容，设置 AGENTS.md、项目配置和真实检查 |
| `$oh-my-agents:arch-guard` | 架构分层、Providers 边界和结构测试 |
| `$oh-my-agents:spec-to-task` | 需求转为带验收命令的执行计划 |
| `$oh-my-agents:verify` | 构建、测试、lint、架构检查与 GREEN/YELLOW/RED 信号 |
| `$oh-my-agents:harness-review` | 独立评审；`--audit` 执行四支柱治理审计 |
| `$oh-my-agents:encode-mistake` | 将明确错误或约定变成可测试的 TASTE 规则 |
| `$oh-my-agents:entropy-sweep` | 重复代码、死代码、文档和契约漂移扫描 |
| `$oh-my-agents:legibility-score` | 基于证据的项目就绪评分 |
| `$oh-my-agents:harness-dashboard` | 带来源说明的检查、评审和层级指标 |
| `$oh-my-agents:gstack-sync` | 可选的 gstack 只读产物集成 |
| `$oh-my-agents:lifecycle` | 读取计划和决策，给出下一步技能或修复项 |

初始化、规则编码和 gstack 设置默认只接受显式调用，避免隐式修改项目配置。
Codex 读取 `AGENTS.md`；项目配置、信号、日志位于 `.codex/`。既有 Claude 状态不会
被自动迁移或复用为通过证据。

## 质量门禁

原生 Hook 逐文件解析 `apply_patch`，在执行前检查导入方向、硬编码凭据和计划格式；
执行后记录层级指标。SessionStart/Stop 展示已有决策和下一步建议。
任意 shell 写文件不会被编辑 Hook 全面覆盖，必须配合项目测试和 CI。
独立评审不可用时返回 NEEDS_HUMAN；不把自评包装成独立通过。

发布前可以显式检查：

```bash
bash /path/to/oh-my-agents/scripts/gate.sh /path/to/project
```

门禁要求完整验证 GREEN、独立评审 APPROVE，以及契约规定的新鲜证据；它不执行发布。
见 [决策信号](docs/SIGNALS.md)。gstack 可选，读取其产物；不会调用 Claude 专属命令。

## 开发和验证

```bash
bash tests/test-hooks.sh
python3 -m unittest discover -s tests -p 'test_*.py'
bash tests/test-plugin-install.sh  # 需要 Codex CLI；隔离配置，不修改用户安装
```

[架构](docs/ARCHITECTURE.md) · [工作流](docs/WORKFLOW.md) · [测试](docs/TESTING.md) ·
[集成](docs/INTEGRATION.md) · [迁移说明](docs/CODEX.md)

历史 Claude 设计讨论保留于 `docs/history/`，用于追溯，不是 Codex 安装指南。
