# Team Discussion — gstack 深度集成优化

**日期**: 2026-04-16
**议题**: oh-my-agents (v3.1.0) × gstack (v0.18.0.0) 深度集成优化
**目标**: 提升 AI 研发交付质量与效率；保持插件精简，避免功能臃肿失效。

---

## 与会角色

| 角色 | 关注视角 |
|------|---------|
| **Claude Code Skill 专家 · 林舟** | Skills 规范、composition pattern、插件生态 |
| **Harness Engineering 专家 · 方哲** | 四支柱、context engineering、rippable 原则 |
| **研发效能专家 · 苏衡** | DORA 指标、交付流、瓶颈识别、AI-augmented DevEx |
| **系统研发架构师 · 陈景** | 职责边界、插件解耦、依赖契约、演进韧性 |

---

## 一、现状与外部基线

### 1.1 本插件现状（oh-my-agents v3.1.0）

- 11 skills / 2 agents / 6 hooks / ~8.5K LOC / 791KB — 当前**未臃肿**，仍处健康区间。
- 已有 gstack 集成层：`.claude/integration.json`（v0.17.0.0）、`/gstack-sync`、`/lifecycle`、`/harness-review` 双评审。

### 1.2 gstack 最新动态（v0.18.0.0，2026-04-16）

研究团队从 upstream 捕获到的**尚未对接**能力：

| 版本 | 关键新增 | 对本插件含义 |
|------|---------|-------------|
| v0.18 | **Confusion Protocol**（Agent 不确定性显式化）；Hermes/GBrain host | 可与 session-metrics.sh 打通为 legibility 信号 |
| v0.17 | `/ux-audit` + UX 行为基础 | review 阶段新维度，需进入 `/lifecycle review` |
| v0.16.4 | 安全修复第三波 | `/cso` 覆盖面更广 — 应让路而非重复 |
| v0.16.3 | **Cross-model quality review**（AI slop 消除） | 与 `/harness-review` Slop 检查语义重叠，需协调 |
| v0.16.0 | Browser data platform for agents | 暂不纳入（超出 harness 职责） |
| v0.15 系列 | `/codex`（OpenAI Codex 独立评审） | **关键**：可作为 `/harness-review` 的对抗验证通道 |
| 架构层 | `conductor.json` / `.gstack-worktrees/` 并行 sprint | `/verify`、hooks 需感知多 worktree 上下文 |

### 1.3 Harness Engineering 业界基线（2026 Q1）

- 四支柱仍为主流参照，但已被两种变体挑战：Anthropic 的"control-theoretic 四功能"（guides / sensors / verification / correction）；业界的"context architecture"替代"documentation as SoR"。
- **Context engineering** 被视为 harness engineering 的父学科（Karpathy / Lütke）。
- **Agent Skills**（Anthropic, 2025-10）成为默认组合单元；**Managed Agents**（2026-04-10）暗示 harness 基础能力正在被 API 层吸收 —— 这意味着本插件必须**聚焦差异化价值**，不要与平台能力正面竞争。
- 学界警告（Berkeley RDI）：主流 agent benchmark 可被 gamed；rubric-based 自评分（含我们的 Legibility Score）需要 trajectory 级证据支撑。

---

## 二、四方观点与交锋

### 林舟（Skill 专家）

> "Skills 的反模式是**把 gstack 的命令再写一遍**。我看到 `/harness-review` 里有一段 Slop 检查——但 gstack v0.16.3 已经上了 cross-model quality review，再加上 `/codex` 的对抗评审，我们的 Slop 检查如果不差异化，就是在浪费 context 和用户注意力。"

**主张**：
- 原则：**composition over duplication**。oh-my-agents 的 skill 只做 gstack 做不到、或 harness 视角更优的事。
- 建议引入 **skill ownership 矩阵**（文档化职责边界，供未来评审用）。
- 不要新增 skill。任何"我们也需要一个 /xxx"的冲动，都应先问"能不能改造现有 skill 或引用 gstack？"

### 方哲（Harness Engineering 专家）

> "原版四支柱没过时，但**'Documentation as System of Record'正在被 Context Engineering 覆盖**。gstack 的 DESIGN.md、conductor.json、worktree 状态都是 context 源。我们的 `/spec-to-task` 已经读 DESIGN.md，但还没处理 worktree 场景——并行 sprint 里，`/verify` 如果在错误的 worktree 跑，会误报一大片。"

**主张**：
- 四支柱保留，但把"Documentation as SoR"**运营**为 Context Engineering 的子集：凡外部插件产出且能稳定被消费的 artifact，都是 SoR 的一等公民。
- **Rippable 原则**对本次集成同样适用 —— 集成点要假设 gstack 升级会变。所有 bridge 读路径用 glob 而非固定文件名；版本号宽松比对；detection 失败时 graceful degrade，不要 hard-fail。
- **Confusion Protocol 是免费的 legibility 信号**：gstack 检测到 agent 困惑，本该进入 session-metrics 和 `/harness-dashboard`。

### 苏衡（研发效能专家）

> "交付效率的真问题不是'多少个 skill'，是**环节之间的交接摩擦**。目前 /verify → /ship 已经有 readiness signal，但 /ux-audit、/cso、/canary 这三个 gate 还没进管线。AI 自动化开发要走通，必须让 `/lifecycle next` 在 gate 失败时**精准告知该调哪个 skill 修复**，而不是让用户自己查。"

**主张**：
- `/lifecycle` 要成为**流效率**（flow efficiency）的编排中枢，而非手册导航。
- 引入 **gate 回退路径表**：每个阶段的失败模式对应明确的修复 skill（harness or gstack）。
- DORA 四指标接入：`/harness-dashboard` 应从 `.claude/metrics/` + `~/.gstack/analytics/` 折算出 **deployment frequency / lead time / MTTR / change failure rate** 的近似值，作为效能客观指标，替代 rubric 自评。

### 陈景（系统架构师）

> "我担心**两个耦合风险**：(1) gstack 升级节奏极快（几乎每日），如果我们对特定命令/路径硬依赖，会脆；(2) Managed Agents 公开后，底层能力下沉，我们不能变成'又一个 harness 层'。必须让 oh-my-agents 的**价值锚定在'约束与质量保证'**，而不是'工作流编排'本身——工作流可以让 gstack 主导。"

**主张**：
- **依赖契约**：不调 gstack skill 内部逻辑；只读 artifact 路径（glob），只感知存在性（version 字符串松匹配）。
- **职责边界**：
  - gstack 主：生命周期编排、交付动作、角色扮演、跨模型对抗评审
  - oh-my-agents 主：机械强制（hooks）、层/架构约束、熵管理、permanent guardrails
  - 双方共有：review（维度互补）、observability（来源互补）
- **不新增 skill**；本次改造只修改既有 3 个 skill + 1 个 config + 1 个文档。

---

## 三、一致结论

### 3.1 Skill Ownership 矩阵（最终版）

| 能力域 | 主责方 | 副/协作 | 去重规则 |
|--------|-------|--------|---------|
| Ideate / Plan | gstack | — | oh-my-agents 不做 |
| Decompose (层感知执行计划) | oh-my-agents | 读 DESIGN.md + test plan | 保留 |
| Execute-time 约束 | oh-my-agents (hooks) | gstack `/guard` 并存 | 已并存 |
| Verify (build/test/lint/arch) | oh-my-agents | emit signal | 保留 |
| **Slop 检查** | **gstack** `/codex` + cross-model | oh-my-agents 仅做**架构/层向**的 slop | 改造：harness-review 不再独占 Slop，delegate 对抗性判断给 `/codex` |
| **安全评审** | **gstack** `/cso` | oh-my-agents hooks（secrets / bash） | 改造：harness-review 不深度 STRIDE，只做快速 secrets + delegate |
| **UX 评审** | **gstack** `/ux-audit` | — | 改造：lifecycle review 阶段把它纳入 |
| Ship / Deploy / Canary | gstack | 读 verify signal | 保留 |
| Retro (velocity) | gstack `/retro` | — | 保留 |
| Retro (governance) | oh-my-agents `/harness-dashboard` | — | 保留 |
| Improve (encode rules) | oh-my-agents | 读 `/investigate` 产物 | 保留 |
| Multi-session 并行 | gstack (conductor + worktrees) | oh-my-agents **感知并降级** | 新增：verify/hooks worktree-aware |

### 3.2 交付物衔接契约（强化版）

- **Design → Plan**：`~/.gstack/projects/{slug}/*-design-*.md` → `/spec-to-task` 自动发现（已有，保留）
- **Plan → Exec**：`~/.gstack/projects/{slug}/*-test-plan-*.md` → 注入 exec plan 的 test constraints（已有，保留）
- **Exec → Verify**：`docs/exec-plans/active/*.json` → `/verify --plan`（已有，保留）
- **Verify → Ship (新)**：`.claude/signals/verify-latest.json` 精简可读 readiness 信号，`/ship` 预检消费。
- **Review 联合 (新)**：`/harness-review` 可条件触发 gstack `/codex` 与 `/cso`，合并结果并打 `[HARNESS]/[STRUCTURAL]/[CROSS-MODEL]/[SECURITY]/[BOTH+]` 标签。
- **UX Gate (新)**：`/lifecycle review` 在 UI 变更时建议 `/ux-audit`。
- **Confusion (新)**：gstack Confusion Protocol 信号 → `.claude/metrics/confusion.jsonl` → `/harness-dashboard` 聚合。
- **Canary 回路 (新)**：`/canary` 报告 → `/harness-dashboard` 质量趋势视图。
- **Worktree 感知 (新)**：存在 `.gstack-worktrees/` 时，`/verify`、hooks 只针对当前 worktree scope。

### 3.3 防臃肿原则（硬约束）

1. **本次及未来任何集成，禁止新增 skill 目录**；只修改既有 skill/config/docs。
2. 任何 bridge 必须 **read-only + glob-based + graceful-degrade**；禁止硬编码 gstack 版本。
3. skill SKILL.md 单文件 ≤ 400 行；超过即触发 `/entropy-sweep` 建议拆分或瘦身。
4. 每条集成规则必须能回答："**这条规则明天 gstack 升级后还成立吗？**" — 否则用 glob / 能力检测替代。
5. 每 90 天回顾集成契约：对 gstack 当前版本的假设是否仍然成立；不成立即修订。
6. **不复刻 gstack 已有能力**；只能以"不同视角、不同阶段、不同粒度"切入。

---

## 四、本次落地项

| # | 动作 | 文件 |
|---|------|------|
| A | 升级集成宣言 | `.claude/integration.json`：gstack 0.17→0.18；新增 codex/cso/ux-audit/canary/conductor/worktrees/confusion bridges |
| B | `/gstack-sync` 识别 v0.18 新 artifact 并纳入 status/metrics 报告 | `skills/gstack-sync/SKILL.md` |
| C | `/harness-review` delegate 给 gstack `/codex`（对抗性 Slop）+ `/cso`（深度安全）；本地只做架构向 slop + 快速 secrets | `skills/harness-review/SKILL.md` |
| D | `/lifecycle` 加入 UX gate、cross-model gate、canary、worktree 感知；gate 失败显式告知修复 skill | `skills/lifecycle/SKILL.md` |
| E | `docs/INTEGRATION.md` 更新职责矩阵、交付契约、防臃肿原则 | `docs/INTEGRATION.md` |

不做的事（已讨论并否决）：

- ❌ 新增 `/confusion-track` / `/worktree-verify` / `/dora-report` 独立 skill —— 统一进既有 skill。
- ❌ 复制 gstack `/codex` 能力做"自家对抗评审"—— 改为调用。
- ❌ 为 Managed Agents 做前瞻适配 —— 等 API 稳定后再谈，现在做就是投机。
- ❌ 改动 Legibility Score 算法 —— trajectory-eval 改造超出本次范围，列入下季议程。

---

## 五、未决事项（列入下一次议程）

1. **Legibility Score 升级**：从 rubric 自评 → trajectory-level eval（引用 `.claude/metrics/session-*.jsonl`），需设计采样与打分机制。
2. **DORA 四指标**：`/harness-dashboard` 接入公式；需确认数据源口径。
3. **Managed Agents 适配**：观察 Anthropic API 形态，等接口稳定后评估是否要做 compat layer。
4. **Agent Teams**（Claude Code shared task list）与本插件 exec-plan 是否合并。

---

**结论**：本次集成以"**composition 不重复、bridge 要 rippable、流效率显式化、工作流主导权让给 gstack、质量锚定权留在 oh-my-agents**"为轴心，代码改动控制在 5 个文件内，不新增任何 skill。
