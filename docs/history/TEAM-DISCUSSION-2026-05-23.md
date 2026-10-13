# Team Discussion — verify-signal 契约修复、原生 Agent Teams 让位、与 OpenAI 组件对齐

**日期**: 2026-05-23（上一次 2026-05-08，间隔 15 天）
**议题**: oh-my-agents (v3.4.0 → **v3.5.0**) × gstack (v1.28+) × Claude Code 原生能力
（Agent Teams / hook 类型 / monitors）—— 把"质量 + 效率 + 不臃肿"三目标在新平台基线下再校准
**目标**: 在 **0 新增 skill / hook / agent** 的前提下，(1) 修掉一个真实存在、位于交付主干道上的
契约 bug；(2) 清理对 gstack 当前命令面的漂移；(3) 把差异化锚点显式对齐到 OpenAI 公布的
harness-engineering 组件与 Claude Code 原生 Agent Teams——避免在平台原生化浪潮里重复造轮子。

---

## 与会角色（沿用班底，决议传承）

| 角色 | 关注视角 |
|------|---------|
| **Claude Code Skill / Plugin 专家 · 林舟** | 原生 Agent Teams / hook 类型 / monitors、与平台能力的重叠、bloat 审计 |
| **Harness Engineering 专家 · 方哲** | OpenAI 六组件保真度、隔离复现、反馈环紧致度、第四范式定位 |
| **研发效能专家 · 苏衡** | DORA / SPACE、flow efficiency、未决态、可机读交接契约、指标可计算性 |
| **系统研发架构师 · 陈景** | 集成契约韧性、耦合与可撕裂、taste 命名冲突、单一事实源、能力探测 |

> 方法论说明：本次每位角色以**独立证据为先**，先各自读源文件取证，再交锋。下文"事实校准"
> 中的每一条都标注了取证文件与行号，避免观点先于事实。

---

## 一、现实校准（事实优先于观点）

### 1.1 平台基线变了：Claude Code 原生化追上了我们的部分叙事

| 项 | 我们当前的表述 | 2026 平台事实 |
|---|---|---|
| 多代理协作 | `ARCHITECTURE.md` 把 11 skill 投影到 "InfoQ 三代理"，自述"仅叙事，不加第三套 agent" | **Agent Teams 已于 2026-02 原生发布**（团队 lead + peer mailbox + 共享任务列表，`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`）——三代理拓扑现在是平台特性 |
| hook 机制 | 6 个全部 shell `command` hook | hook 类型已扩展为 `command` / `http` / `mcp_tool` / `prompt` / `agent`；plugin 还可携带 **monitors / output styles / LSP** |
| 定位参照 | "harness engineering" | OpenAI 官方页 + InfoQ（2026-02）给出**规范六组件**；TechTimes（2026-05）称其为"AI 工程第四范式" |

### 1.2 gstack 命令面漂移（与 05-08 同源问题，但这次抓到了具体陈尸）

实测当前 gstack 命令面（取自仓库实况），与我们的 `integration.json` 对照：

| 项 | `.claude/integration.json` 旧值 | gstack 实况 | 证据 |
|---|---|---|---|
| UX 评审 | `ux_audit: "gstack:/ux-audit"` | **无 `/ux-audit`**；现为 `/design-review` + `/devex-review` | `integration.json:64`、`gstack-sync/SKILL.md:76,149`、`harness-review/SKILL.md:183,310`、`INTEGRATION.md:48,120,248` 共 **8 处** |
| 健康检查 | `gstack_owns` 含 `/health` | **无 `/health`**；其职能并入 `/canary` | `integration.json:70` |
| 观测层写入 | 仅 GBrain learnings | 新增 `/learn`、`/context-save`、`/context-restore`、`gstack-analytics` / `gstack-taste-update` binary | 未桥接 |
| 命令面真值源 | 手维护命令名清单 | v1.28+ 出 **`llms.txt`** 权威索引（47 skill / 75 command） | `gstack-sync/SKILL.md:99-101` 已探测但无人消费 |

> **关键观察（陈景）**：`/ux-audit` 这个名字是 2026-04 讨论按 gstack v0.17 写进去的，跨越了
> 整个 v1.x 演进还活着——因为它被**手抄进了 4 个文件的 8 处 prose**，而 prose 各自独立漂移。
> 这正是"手维护命令清单是漂移源"的活体证据。

### 1.3 自我审计：一个真实 bug 坐在交付主干道上

| 发现 | 严重度 | 证据 |
|---|---|---|
| **verify→ship 信号是死指针**：`/verify` 写 `.claude/metrics/verify-readiness.json`（且 4 个 pass 字段恒为 `false` 占位），但全链路（lifecycle、INTEGRATION、ARCHITECTURE、integration.json）读的是 `.claude/signals/verify-latest.json`。**写的文件没人读，读的文件没人写**——verify gate 实际退化为 no-op | 🔴 **P0 真 bug** | `verify/SKILL.md:144,154`（旧）vs `lifecycle/SKILL.md:93,128`、`INTEGRATION.md:43,115,250`、`integration.json:53` |
| verify 信号无 `decision` 枚举（review 有 APPROVE/REQUEST_CHANGES/NEEDS_HUMAN，verify 只吐裸 bool），`/ship` gate 得自己再判一次 | 🟠 P1 | `verify/SKILL.md`（旧）无枚举 |
| `verify.jsonl` 被两个消费者假设存在（recurring-failure 检测 `verify/SKILL.md:202`、dashboard velocity `harness-dashboard/SKILL.md:121`），但**无任何写入者**——dashboard 报的 first-pass-GREEN / verify→review 是凭空数 | 🟠 P1 | 仅 prose 声称 |
| `ARCHITECTURE.md` 三代理映射引"InfoQ 2026-04"，**早于原生 Agent Teams**，读起来像在自造协作层 | 🟡 P2 | `ARCHITECTURE.md:66-85`（旧） |
| gstack `gstack-taste-update`（软、衰减的设计偏好）与本插件 `TASTE-NNN`（硬、永久、人闸的机械规则）**同名异义** | 🟡 P2 语义危险 | `encode-mistake/SKILL.md:127,281` |

### 1.4 OpenAI 规范六组件（取自 openai.com + InfoQ, 2026-02）

文档即事实源 · 架构约束（机械规则 + 结构测试，Types→Config→Repo→Service→Runtime→UI）·
结构化反馈环（PR / CI）· 可观测性集成（logs / metrics / spans）· **隔离测试（在隔离环境复现 bug）**
· 工程师角色转变（从写代码 → 设计环境、指定意图、给结构化反馈）。

> **方哲**：我们的四支柱直接覆盖其中四个。剩下两个——**隔离测试**与**结构化反馈环**——
> 不是缺失，而是**该显式说明**：隔离复现按 composition 原则归 gstack `/investigate` + `/qa`，
> 反馈环就是我们的 decision signal + CI 模板。把这层映射写进 docs，空格子自证边界。

---

## 二、四方观点（独立取证后的交锋）

### 林舟（Skill / Plugin 专家）

> "最该改的是叙事：`ARCHITECTURE.md` 的三代理映射现在像在卖一个我们没做的协作层——而
> Agent Teams 2026-02 已经原生发了一模一样的拓扑。我们要做的不是再画一遍 Planner/Generator/
> Evaluator，而是把自己**重定位成团队*跑在里面*的约束面 + 证据面**：Generator 端的 PreToolUse
> hook、Evaluator 端的 `verify-latest.json` / `review-latest.json`——那正是 team-lead 路由所读的工件。"
>
> "bloat 审计上我点三处冗余：`session-metrics.sh` 蹲在 Edit/Write/Bash 三个 PostToolUse 热路径上，
> 这是 **monitor** 的活；`doc-gardening-agent` 与 `doc-drift-check` hook、`entropy-sweep --docs`
> **三重覆盖**文档漂移。但——这些是*行为迁移*，monitor 是较新特性，贸然换会引入风险。本次先
> **文档重定位 + 标注为后续项**，不在修 bug 的同一刀里动机制。"

**主张**：① 三代理映射改写为引用原生 Agent Teams，让出协作权；② monitor 迁移 / agent 去重
列入"留待下次"，不本次落地（避免一次动太多）；③ plugin.json 描述从 600 字 run-on 收敛成一句。

### 方哲（Harness Engineering 专家）

> "保真度上最大的洞不是缺功能，是**没把隔离测试和反馈环显式归位**。OpenAI 把这俩列为一等组件。
> 我们有 `/verify` 和 CI 模板，但隔离复现确实没有——而且**不该自己做**：gstack `/investigate` +
> `/qa` 就是干这个的。正确动作是 composition——在 verify 的 recurring-failure 分支指向
> `/investigate`，在 ARCHITECTURE 的组件映射表里把'隔离测试 → gstack 委派'写明。"
>
> "定位上**别推翻四支柱**——它在 legibility-score / harness-review / dashboard 里是承重墙，
> 拆了违反防臃肿。加一张'四支柱 ↔ OpenAI 六组件'映射表即可，两个空格子（隔离测试、反馈环）
> 自己把边界讲清楚。角色转变那条——`/spec-to-task`（指定意图）+ decision signal（结构化反馈）
> 就是它的落地，补一句话点破。"

**主张**：① 加四支柱 ↔ OpenAI 六组件映射表（纯文档）；② 隔离复现走 gstack 委派，verify 加一行
路由指向 `/investigate`；③ 不重写四支柱、不新增 skill。

### 苏衡（研发效能专家）

> "我只认可机读的交接。verify→ship 这个 bug 是**伪装成自动化的正确性故障**，坐在每一次 ship 的
> 主干道上——这是本次最高杠杆。修法不是发明，是**对齐**：让 `/verify` 写规范的 `verify-latest.json`、
> 带 `decision` 枚举，并补上 review gate 已有的'信号缺失 = 不前进'对称校验。把单向假设变成双向契约，
> 0 新增 skill。"
>
> "dashboard 报了它算不出的指标——`verify.jsonl` 没人写。对 AI 自动化开发，最高信号的三个量是：
> **首过 verify GREEN 率**（最早的质量先行指标）、**每阶段 gate 失败 / 返工环数**（直接量化浪费的
> AI 轮次）、**spec→merge 前置时间**（真正映射交付效率的 flow 指标）。这三个只要让 `/verify` 与
> `/harness-review` **各自每次 gate 追加一行 typed jsonl** 就全可导出——不要往 per-tool-call 的
> session hook 上加字段，那是错的粒度，会把 hook 撑肿。"
>
> "NEEDS_HUMAN 的'信号缺失即停'方向对（利于质量），但对*自动化*目标偏保守：分不清'架构歧义'
> （真要人）和'写信号的脚本崩了'（该重试）。但这是调参，本次先把信号写对，校准留观测数据后再做。"

**主张**：① 修 verify 信号契约（P0，最高杠杆）；② `/verify` 真正写 `verify.jsonl` gate 事件行
（首过率 / 返工 / 前置时间皆可算），替换原 prose；③ NEEDS_HUMAN 细分（ambiguous vs signal_error）
**列入留待下次**，先攒观测数据。

### 陈景（系统架构师）

> "最高杠杆的*架构*改动是：**让 `llms.txt` 成为能力真值源，把 integration.json 里的命令名从'钉死'
> 降级为'能力绑定'**。`/ux-audit`、`/health` 的漂移就是手抄命令清单的必然结果。`gstack-sync` 已经
> 探测到 `llms.txt` 却没人消费它——`--contract-check` 应该拿它来 diff 命令绑定。这一刀同时让集成
> *更紧*（自动对齐 gstack 真实命令面）和*更韧*（按构造扛住下次改名）。"
>
> "taste 命名冲突是真语义危险，但**正确处理后反而强化双层模型**：gstack-taste = 软、衰减的*偏好*
> （观测层），harness TASTE-NNN = 硬、永久、人闸的*机械规则*（强制层），前者是后者的*候选喂料*。
> 只要在日志 / prose 里绝不等同即可——grep token `TASTE-NNN` 本身已够独特。"
>
> "双值 glob（brain ⇄ artifacts）现在是恰当防御，但'永远 glob 两条'是无界熵——违反我们自己的
> 反熵使命。该给它一个 sunset：写进 policies，等 `min_supported` 越过 v1.27 改名地板就删 legacy。"

**主张**：① 修死/缺漂移 + 命令名降级为能力绑定（带 `_command_binding_note`）；② `--contract-check`
拿 `llms.txt` diff；③ taste 冲突在 encode-mistake Step 0 + INTEGRATION 双层段落消歧；④ 加
`legacy_sunset` 标记，把"删 legacy"变成被追踪的决策而非遗忘的腐肉。

---

## 三、一致结论

### 3.1 差异化锚点（在平台原生化压力下再确认）

| 锚点 | 状态 | 举证 |
|---|---|---|
| 仓内可机械验证的质量约束（hooks + arch-guard + TASTE） | **保留并强化** | Managed Agents 通用层无源码访问，不可替代 |
| 双层模型：observation（gstack/GBrain/taste）→ enforcement（TASTE-NNN） | **保留并消歧** | ETH Zurich + Osmani 背书；taste 同名异义已澄清 |
| 反 slop / 反 entropy 长期视角 | **保留** | Chroma context rot 实验支撑 |
| **多代理协作 / 协作编排** | **明确让位原生 Agent Teams + gstack Conductor** | 2026-02 平台原生化；我们做"跑在里面的约束 + 证据层" |
| Workflow orchestration | **不做** / 让位 gstack | 已商品化；`/lifecycle` 仅 route |
| 隔离测试（bug 隔离复现） | **委派 gstack `/investigate` + `/qa`** | composition over duplication |
| 自动生成规则 | **明确不做** | ETH Zurich：–20% token |

### 3.2 防臃肿原则（v3.5，本次新增两条；见 INTEGRATION.md 第 15、16 条）

继承上次 14 条并补充：

15. **`llms.txt` 是能力真值源**——integration.json 里的命令名是*能力绑定*而非*钉死*；
    `--contract-check` 对照 `llms.txt`；手抄命令清单是漂移源。
16. **按计划 sunset legacy 双值路径**——`legacy_sunset` 钉地板（v1.27）；`min_supported`
    越过即删 `*_legacy` 桥；永远 glob 两条是无界熵。

### 3.3 落地项（编辑 13 个文件，**0 新增 skill / hook / agent**，+1 doc 即本纪要）

| # | 动作 | 文件 | Anti-bloat 检查 |
|---|---|---|---|
| A | **修 verify 信号契约**：写规范 `signals/verify-latest.json` + `decision` 枚举；删恒-false 占位；真正写 `verify.jsonl` gate 行；recurring 分支指向 `/investigate` | `skills/verify/SKILL.md` | 净精简（删冗余 readiness 探测块） |
| B | lifecycle verify 阶段**读**信号（与 review 对称，缺失 = 重跑）；`/ux-audit`→`/design-review` | `skills/lifecycle/SKILL.md` | 替换式 |
| C | 修死/缺漂移：`/ux-audit`→`/design-review`(+`/devex-review`)、删 `/health`、加 `/learn`/`/context-save`/`/context-restore`；命令名降级为能力绑定 + `_command_binding_note`；加 `legacy_sunset`、`capability_oracle`；版本 3.5.0；anchor 指向本纪要 | `.claude/integration.json` | 仅改/扩字段 |
| D | `/ux-audit`→`/design-review`；`--contract-check` 拿 `llms.txt` diff 命令绑定 | `skills/gstack-sync/SKILL.md` | +小，远低于 400 |
| E | composition 矩阵 + Rules 的 `/ux-audit`→`/design-review` | `skills/harness-review/SKILL.md` | 替换式 |
| F | taste 同名异义消歧（Step 0 一段） | `skills/encode-mistake/SKILL.md` | +一段，远低于 400 |
| G | 三代理映射改写为引用**原生 Agent Teams**；新增四支柱 ↔ OpenAI 六组件映射表；角色转变点破 | `docs/ARCHITECTURE.md` | 纯文档 |
| H | `/ux-audit`→`/design-review`(+DX)（3 表）；taste 冲突写入双层段；新增防臃肿第 15、16 条 | `docs/INTEGRATION.md` | 替换 + 2 条 |
| I | 描述收敛成一句；版本 3.5.0 | `.claude-plugin/plugin.json` | 仅元数据 |
| J | 版本 3.5.0；`/ux-audit`→`/design-review`；anchor 指向本纪要；让位 Agent Teams 一句 | `CLAUDE.md` | 仅元数据 |
| K | 版本 3.5.0；`/ux-audit`→`/design-review`；新增 verify 信号 handoff 条目；纪要链接 | `README.md` | 替换式 |
| L | 同步本讨论纪要 | `docs/TEAM-DISCUSSION-2026-05-23.md` | 唯一 +1 doc |

**总文件改动 = 13（其中 1 新增 doc，0 新增 skill / hook / agent）**。

### 3.4 否决 / 延期项（讨论后明确不本次做）

- ⏸ **`session-metrics.sh` hook → monitor 迁移**（林舟 P1）：monitor 是较新机制，行为迁移有风险；
  先记入议程，攒一个稳定窗口再迁。
- ⏸ **删 `doc-gardening-agent`（三重覆盖文档漂移）**（林舟 P1）：删 agent 是有主张的破坏性动作，
  且 05-08 议程 #4 已挂"是否接 GBrain 只读消费"——一并在下次评估去留，本次不擅自删。
- ⏸ **`/encode-mistake --from-ci`**（方哲 P1）：CI 反馈回流是真价值，但 full 实现要定义 CI 输出位置 /
  解析，易膨胀；本次先用 verify 信号修复把反馈环收紧，`--from-ci` 列议程。
- ⏸ **NEEDS_HUMAN 细分 ambiguous / signal_error + 重试**（苏衡 P2）：先把信号写对、攒观测数据，
  按 halt-rate 经验校准，避免拍脑袋。
- ❌ **不新增任何 skill / hook / agent**（如 `/agent-team`、`/llms-index`、独立隔离复现 skill）。
- ❌ **不重写四支柱**——承重墙，拆了违反防臃肿。
- ❌ **不自己实现 bug 隔离复现**——委派 gstack `/investigate` + `/qa`。
- ❌ **不写入任何 gstack 路径**——只读桥不变。

---

## 四、给"AI 自动化开发"的解释

为什么这次方向直接放大 AI 自动化交付的**质量 × 效率**：

1. **修死指针 = 让 verify gate 真的存在**：过去 `/ship` 预检读一个永不被写的文件，gate 静默 no-op；
   现在 `/verify` 写带 `decision` 的规范信号，`/lifecycle` 与 `/ship` 做*查表*而非*再判断*。这是把
   "看起来自动、其实裸奔"的环节，变成真正机读的双向契约——AI 链条不再在错误的绿灯下前进。
2. **未决态对称收缩**：review gate 已有"信号缺失 = NEEDS_HUMAN"；本次给 verify 补上对称的
   "信号缺失 = 重跑 /verify"。两个 gate 同构后，`/lifecycle next --auto` 的每一步都有确定的机读出口。
3. **指标从凭空变可算**：`/verify` 真正写 `verify.jsonl` gate 行后，首过 GREEN 率 / 返工环数 /
   spec→merge 前置时间皆可导出——dashboard 不再报它算不出的数，效能优化第一次有了可信基线。
4. **抗 churn = 抗减速**：命令名降级为能力绑定 + `llms.txt` 真值源，gstack 下次改命令名不再让我们
   盲飞；`legacy_sunset` 让兼容代码有退场计划，不积无界熵。漂移每被自动 diff 出来一次，就少一次
   人工排查的停顿。
5. **不与平台争 = 不浪费**：协作让位原生 Agent Teams、隔离复现委派 gstack——我们把全部预算压在
   *别人替代不了的*仓内机械约束 + 决策证据上。这是"不臃肿"的本质：不是少写代码，是不写平台已经
   提供的代码。

---

## 五、留待下次（议程已锁定）

1. **session-metrics hook → monitor 迁移**（评估稳定性后落地，砍 2 个热路径 hook 绑定）。
2. **doc-gardening-agent 去留**（三重覆盖文档漂移；与 05-08 议程 #4 合并评估）。
3. **`/encode-mistake --from-ci`**（CI 失败回流为候选 TASTE，复用现有 ingest→人闸机制）。
4. **NEEDS_HUMAN 细分 + 自动重试**（按 halt-rate 观测数据校准 APPROVE/NEEDS_HUMAN 比）。
5. **harness-review 全面 success-silence / failure-verbosity 收敛**（05-08 续延项）。
6. **Legibility Score → trajectory-eval**（连续第四次延期，**Q3 必启动，否则下架该 metric**）。
7. **若 gstack 引入原生 Evaluator skill，`/harness-review` 是否退场为薄壳**（05-08 #5 续议）。

---

**结论**：本次不追加任何能力面，做四件事——**(1)** 修掉 verify→ship 死指针这个坐在交付主干道上的
真 bug，把伪自动化变成机读双向契约；**(2)** 清掉 `/ux-audit`、`/health` 等命令面漂移，并把命令名
降级为由 `llms.txt` 校准的能力绑定，从根上掐断漂移源；**(3)** 把协作让位原生 Agent Teams、隔离测试
委派 gstack，并将四支柱显式对齐到 OpenAI 六组件——锐化"做约束、不造轮子"的差异化；**(4)** 让
dashboard 指标真正可算。13 个文件、0 新增 skill / hook / agent——以此回应"质量 + 效率 + 不臃肿"
的三重目标。

---

## 附：参考资料

- [OpenAI — Harness Engineering: Leveraging Codex in an Agent-First World](https://openai.com/index/harness-engineering/)
- [OpenAI Introduces Harness Engineering: Codex Agents Power Large-Scale Software Development — InfoQ, 2026-02](https://www.infoq.com/news/2026/02/openai-harness-engineering-codex/)
- ["Harness Engineering" Emerges as the Fourth Paradigm of AI Engineering — TechTimes, 2026-05](https://www.techtimes.com/articles/316587/20260513/harness-engineering-emerges-fourth-paradigm-ai-engineering.htm)
- [Orchestrate teams of Claude Code sessions (Agent Teams) — Claude Code Docs](https://code.claude.com/docs/en/agent-teams)
- [Plugins reference (skills / hooks / monitors / output styles) — Claude Code Docs](https://code.claude.com/docs/en/plugins-reference)
- [gstack — github.com/garrytan/gstack](https://github.com/garrytan/gstack)
- 前序纪要：[2026-04](TEAM-DISCUSSION-2026-04.md) · [2026-04-30](TEAM-DISCUSSION-2026-04-30.md) · [2026-05-08](TEAM-DISCUSSION-2026-05-08.md)
