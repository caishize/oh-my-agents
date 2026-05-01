# Team Discussion — gstack v1.21 时代的深度集成再校准

**日期**: 2026-04-30（上一次讨论 2026-04-16，间隔 14 天）
**议题**: oh-my-agents (v3.2.0) × gstack (v1.21.1.0) — 契约修复与 Brain 子系统对接
**目标**: 在不增加 skill 数量的前提下，把研发交付质量与效率再推一个台阶；
关闭由 gstack 飞速演进导致的集成漂移。

---

## 与会角色（沿用上次班底，便于决议传承）

| 角色 | 关注视角 |
|------|---------|
| **Claude Code Skill 专家 · 林舟** | Skills 规范、composition、progressive disclosure、token 预算 |
| **Harness Engineering 专家 · 方哲** | 四支柱、guides/sensors、context engineering、rippable 原则 |
| **研发效能专家 · 苏衡** | DORA、flow efficiency、AI-augmented DevEx、瓶颈识别 |
| **系统研发架构师 · 陈景** | 解耦、依赖契约、版本演进韧性、职责边界 |

---

## 一、现实校准（事实优先于观点）

### 1.1 集成契约严重漂移

| 项 | `.claude/integration.json` 记录 | gstack 实际 |
|---|---|---|
| 版本 | `0.18.0.0` | **`1.21.1.0`** |
| `min_supported` | `0.15.0.0` | 与之间至少经历 **11 次发版**（v1.9 → v1.21.1） |
| 上次契约复审 | `2026-Q3` | 实际已发生破坏性新增（GBrain、conductor workspaces） |

### 1.2 我们没接的 gstack 新能力（自 v0.18 起）

| 版本 | 关键新增 | 与 oh-my-agents 的关系 |
|------|---------|----|
| v1.9 | **Cross-machine brain sync**：`learnings-log` / `timeline-log` / `review-log` / `developer-profile` 写入器 | **直接竞品/互补**于 `/encode-mistake` |
| v1.11 | Workspace-aware `/ship`、`bin/gstack-next-version`、`/landing-report`、版本碰撞 CI gate | `/harness-dashboard` 该消费 `/landing-report` |
| v1.12 | `/setup-gbrain` 全套上线、`gbrain-repo-policy.json` (schema v2)、`/health` 加 GBrain 维度 | 我们对 GBrain 的存在性**完全不感知** |
| v1.13 | `/gstack-claude`（让非 Claude host 只读咨询 Claude） | 与本插件无关，忽略 |
| v1.14 | 侧边栏改为 Claude Code REPL；`tabs.json`/`active-tab.json` | 与本插件无关，忽略 |
| v1.15 | Real-PTY 测试 harness、preamble 压缩 –25% tokens | 启发：我们也该审视自己的 SKILL.md token 预算 |
| v1.17 | GBrain 通过 git worktree 联邦：`~/.gstack-brain-worktree/` | bridge 应感知，未感知 |
| v1.20 | `/scrape` + `/skillify` 把 Playwright 自动化编码为 skill | 与本插件无关，忽略 |
| v1.21 | Plan-mode 测试收紧、`plan_ready` 不再视为通过 | 启发：我们的 verify 通过判定也要审视边界 |

### 1.3 业界基线再校准（2026 Q2）

- **Martin Fowler（2026-04, 已发表）**：harness = guides (feedforward) + sensors (feedback) × computational + inferential。
  最大短板在 **behavior harness**——过度依赖 agent 自生成测试。
  推荐 *keep quality left*、*topology-based templates*、*approved fixtures*。**未涉及多 harness 之间的组合**。
- **Addy Osmani**：AGENTS.md 是 *load-bearing system component*。**核心警句**："Every line in a good `AGENTS.md` should be traceable back to a specific thing that went wrong"
  ——这正是我们 `/encode-mistake` 的设计精神，**但 Osmani 还强调"success silence, failure verbosity"**：通过则静默，失败则注入信号。我们当前 `harness-review` 输出过于啰嗦。
- **HumanLayer "Skill Issue"**：是配置问题，不是模型问题。
  ETH Zurich 实证：LLM 自生成的 agent 文件**反而拉低性能**且 +20% token。
  **关键警示**：MCP/skill 多即是慢；persona-based 角色分裂被点名为反模式（gstack 恰是 persona-based 设计）。
  推荐：progressive disclosure、subagent 作为 context firewall、**condensed responses with citations**。

### 1.4 自我审计发现

| 发现 | 严重度 | 证据 |
|---|---|---|
| `spec-to-task/SKILL.md = 465 行`，违反上次自定 ≤400 行的硬约束 | 🔴 P0 自打脸 | `wc -l` |
| `/encode-mistake` 不读 gstack `learnings-log` —— Investigate→Encode 闭环只走得通 gstack 一侧 | 🟠 P1 集成漏 | `encode-mistake/SKILL.md:36-37, 219-224` |
| `/harness-dashboard` 不消费 `/landing-report` —— DORA 代理指标缺真实部署数据 | 🟠 P1 集成漏 | `harness-dashboard/SKILL.md:45-74`，无 landing-report 探针 |
| `integration.json` 引用 v0.17/v0.18 老路径假设；GBrain 路径完全缺失 | 🟠 P1 契约漂移 | 上文 1.1 |
| `harness-review` 的 Slop 检查段落（30+ 行）即便已 delegate `/codex`，行文仍像本地要做完整对抗审 | 🟡 P2 冗余 | `harness-review/SKILL.md:33-61` |

---

## 二、四方观点交锋（新材料下）

### 林舟（Skill 专家）

> "上一次我们立了'composition over duplication'。两周后 gstack 自己长出了 GBrain，**我们的 `/encode-mistake` 和 gstack 的 learnings-log 现在功能上有重叠**。但语义不同：gstack 的 learnings-log 是 **observation**（什么发生过），我们的 LINTING.md TASTE 规则是 **mechanical enforcement**（永远不许再发生）。**两个层级不能合并**——但应该**单向贯通**：learnings-log 是上游观测，TASTE 是下游强制。"
>
> "Osmani 那句 'success silence, failure verbosity' 是给 `harness-review` 的当头棒喝。我们现在的输出格式是 **always verbose**，无论结论是 APPROVE 还是 REQUEST CHANGES。该改。"

**主张**：
- `/encode-mistake` 增加 `--from-gstack-learnings` 入口：扫 `~/.gstack-brain-worktree/` 或 fallback `~/.gstack/projects/$SLUG/*-learnings-*.jsonl`，每条未编码的 learning 提议一条 TASTE 规则。
- `harness-review` 通过部分应当折叠（一行 ✓ 即可）；Issues 段落保留 verbose，是失败信号。
- **不新增 skill**。

### 方哲（Harness Engineering 专家）

> "Fowler 把 harness 拆成 guides+sensors。我们的 hooks 是 *guides*，`/verify` 是 *sensor*。**我们当前的 sensor 网络只看自己的代码，看不到 gstack 已经生成的高价值信号**——比如 `/landing-report` 出来的部署后真实数据、`/canary` 的回归。这是 sensor 网络的盲区。"
>
> "gstack 的 GBrain 联邦（v1.17）通过 git worktree 同步——这是个**优雅的解耦**：我们不需要调任何 API，只读那个本地 worktree 就拿到 cross-machine 的所有学习。本插件的 rippable 原则在这里得到验证。"

**主张**：
- `/harness-dashboard` 的 sensor 输入扩到 gstack `/landing-report`、`/canary` 输出（已部分覆盖 canary，但未覆盖 landing-report）。
- **DORA proxy 改为 grounded**：`deployment_frequency` 用 `/landing-report` 真实计数，不再用估算。
- 把 GBrain worktree 列为一等 SoR：`~/.gstack-brain-worktree/` → `confusion`、`learnings` 双信号源。

### 苏衡（研发效能专家）

> "上一次我们做完了 Gate Failure Routing。两周看下来，**真正卡住交付的不是 gate 失败，而是 gate 通过后没人去把当次的教训沉淀**。Investigate→Encode 闭环上次只画了'gstack /investigate → 我方 /encode-mistake'这一向，但 gstack 现在已经主动写 learnings-log 了——**我们应该反向消费它**，让 `/lifecycle improve` 阶段自动列出未编码 learnings，而不是等用户手动触发 /encode-mistake。"
>
> "效率指标：现在 `/harness-dashboard` 的 DORA 是 'proxy'。如果接上 `/landing-report`，可以从 'proxy' 升级到 'grounded'——这是研发效能客观度量从虚到实的关键一步。"

**主张**：
- `/lifecycle improve` 自动扫 learnings-log，每条未编码项 → 弹 `/encode-mistake` 候选。
- `/harness-dashboard` 标识哪些指标已 grounded，哪些仍 proxy；用户能看清数据可信度。
- DORA 四指标接入路径定下来：deployment_frequency = `landing-report` 计数；lead_time = exec-plan created → 对应 landing-report 时间差；MTTR = `/canary` 报告中的 incident 修复时延；change_failure_rate = `/canary` 标 RED 的 ratio。

### 陈景（系统架构师）

> "我担心两个新风险：(1) gstack 11 个版本两周内涌进来，**我们的 'min_supported = 0.15' 等于裸奔**——v0.15 的 artifact 假设很多在 v1.11 已经变了。(2) gstack 出现了 conductor workspaces 概念（`$HOME/conductor/workspaces`），它和原来的 `.gstack-worktrees/` 是**两套 worktree 模型**。我们当前 hooks 的 worktree 感知只覆盖后者。"
>
> "结论：我们要做两件事——一是把 contract 检查机制**从季度改为持续探测**；二是**在 integration.json 里把 'min_supported' 升到一个真正还活着的版本**，并把感知模式从 'fixed paths' 拉到 'capability probe'，由 gstack-sync 在每次 status 时自动汇报漂移。"

**主张**：
- `min_supported` 从 `0.15.0.0` 升到 `1.9.0.0`（学习/记忆体系起点）。
- `/gstack-sync --contract-check` 降为**每次 --status 都自动跑轻量版**；季度版保持深度审计。
- conductor workspaces 路径加入 bridges 探测（`$HOME/conductor/workspaces/*`），但**不耦合**——只做存在性检测。
- **不引入** GBrain mutation 路径——我们读 worktree，绝不写。

---

## 三、一致结论

### 3.1 强化的"职责边界 + composition"

新增三条决议（对上次的增量，不是替换）：

| 能力 | 主责 | 我们的角色 | 实施 |
|------|------|------|------|
| **观测层学习捕获**（`learnings-log`） | gstack | 读取并提议为 TASTE 规则 | `/encode-mistake --from-gstack-learnings` |
| **部署后真实指标** | gstack `/landing-report` | 升级 DORA proxy 为 grounded | `/harness-dashboard` 探针 |
| **跨机记忆联邦** | gstack GBrain worktree | 仅作读源，不参与同步 | bridge 增加 `gbrain_worktree` |

### 3.2 防臃肿原则（强化第二版）

继承上次硬约束并补充：

1. **不新增 skill**（沿用）
2. **SKILL.md ≤ 400 行**（沿用）—— 本次发现 spec-to-task=465，**强制本次内修复**
3. **bridge read-only + glob + graceful-degrade**（沿用）
4. **每条规则要回答"明天 gstack 升级后是否还成立"**（沿用）
5. **季度复审改为：每次 --status 自动轻量探测 + 季度深度审计**（**新增**）
6. **min_supported 跟随 gstack 主要功能里程碑前移**（**新增**）—— 本次：0.15 → 1.9
7. **Osmani 准则**：**success silence, failure verbosity**（**新增**）—— 通过的 review 维度仅一行；失败维度 verbose
8. **不复刻 GBrain**（**新增**）—— 我们做 mechanical enforcement (TASTE)，gstack 做 observation (learnings-log)；两层贯通但不合并

### 3.3 交付契约（v1.2，扩展版）

新增/修改 bridges：

```
gstack_brain_worktree:   ~/.gstack-brain-worktree/                         (新增, 读)
gstack_learnings_log:    ~/.gstack-brain-worktree/learnings-*.jsonl
                         OR fallback ~/.gstack/projects/$SLUG/*-learnings-*.jsonl  (新增, 读)
gstack_timeline_log:     ~/.gstack-brain-worktree/timeline-*.jsonl         (新增, 读)
gstack_developer_profile:~/.gstack-brain-worktree/developer-profile-*.json (新增, 读)
gbrain_repo_policy:      ~/.gstack/gbrain-repo-policy.json                 (新增, 读)
gstack_landing_reports:  .gstack/landing-reports/*.json
                         OR ~/.gstack/projects/$SLUG/*-landing-*.md         (新增, 读)
conductor_workspaces:    $HOME/conductor/workspaces/                       (新增, 探针)
```

### 3.4 落地项

| # | 动作 | 文件 | Anti-bloat 检查 |
|---|---|---|---|
| A | 升级集成宣言：版本号 1.21、min_supported 1.9、新增 7 条 bridge | `.claude/integration.json` | 仅扩字段，无新文件 |
| B | `/gstack-sync` 探测新 artifact、`--status` 默认输出漂移行 | `skills/gstack-sync/SKILL.md` | 当前 178 行，预算 +30 行 |
| C | `/encode-mistake` 增加 `--from-gstack-learnings` 入口 | `skills/encode-mistake/SKILL.md` | 当前 226 行，预算 +20 行 |
| D | `/harness-dashboard` 消费 `/landing-report`，DORA proxy 标 grounded/proxy | `skills/harness-dashboard/SKILL.md` | 当前 255 行，预算 +25 行 |
| E | **强制**：`spec-to-task/SKILL.md` 瘦身到 ≤400 行（当前 465） | `skills/spec-to-task/SKILL.md` | 净减少 ≥65 行 |
| F | 刷新职责矩阵 + bridges + 防臃肿条款 | `docs/INTEGRATION.md` | 替换性更新 |
| G | 同步本讨论纪要 | `docs/TEAM-DISCUSSION-2026-04-30.md` | 新增 1 个 doc，与上次一致 |
| H | 版本号 3.2.0 → 3.3.0 + 描述同步 | `.claude-plugin/plugin.json` | 仅元数据 |

**总文件改动 = 8（其中 1 个新增 doc，0 个新增 skill / hook / agent）**。

### 3.5 否决项（讨论后明确不做）

- ❌ 不新增 `/gbrain-bridge` / `/landings` / `/dora-report` 等独立 skill
- ❌ 不写入 GBrain（`~/.gstack-brain-worktree/` 严格只读）
- ❌ 不监听 `/pair-agent` / `/scrape` / `/skillify`（与本插件使命无关）
- ❌ 不为 gstack v1.21 的 conductor workspaces 做主动管理（仅探针）
- ❌ 不做 trajectory-eval 改造 Legibility Score（继续延期，未到时机）
- ❌ Osmani "success silence" 本次只在 `harness-review` 实施 P0 改造，其他 skill 留待下次

---

## 四、给"AI 自动化开发"的解释

为什么这次集成方向能直接放大 AI 自动化交付：

1. **改善 sensor 信号网**：把 gstack 已有的 `learnings-log`、`/landing-report`、GBrain
   worktree 接入我们的 sensor 系统。Agent 在执行 `/lifecycle improve` 时，**不再只看
   本次会话的 stdout**，而能看到跨会话、跨机器的学习沉淀，更接近真正的 *continuous learning*。

2. **关闭闭环**：上次只做了 `/investigate → /encode-mistake`（一向）。这次接上
   `learnings-log → /encode-mistake`（反向自动入口）。Agent 自己能在 `improve` 阶段
   提议哪些 learnings 该硬化为 TASTE，**减少人工触发频次**。

3. **DORA 从 proxy 升级到 grounded**：deployment_frequency / change_failure_rate
   不再是估算，而是基于 `/landing-report` 真实计数。研发效能客观度量从此能用。

4. **降 token、提速**：
   - spec-to-task 瘦身（–65 行 ≈ –1300 tokens／load）
   - harness-review 通过维度收敛（Osmani 准则）
   - integration.json bridges 用 glob 而非命令调用，**0 token 探测**

5. **抗衰减**：契约校验从季度变持续；min_supported 跟随 gstack 主要里程碑前移；
   gstack 下一次大版本不再让我们盲飞。

---

## 五、留待下次（议程已锁定）

1. **Legibility Score → trajectory-eval**（连续第二次延期，应在 Q3 启动）
2. **`harness-review` 全面应用 "success silence, failure verbosity"**（本次仅启动）
3. **Anthropic Managed Agents 适配**（继续观察，不投机）
4. **Agent Teams shared task list 与 exec-plan 关系**（继续延期，等 Anthropic 接口稳）
5. **session-observer-agent / doc-gardening-agent 的输出是否也该接入 GBrain learnings-log**
   ——交叉污染风险待评估

---

**结论**：把 gstack 11 个版本里出现的 GBrain / landing-report / conductor workspaces
**作为只读的高价值 sensor 源**接入我们的 sensor 网络；用 8 个文件的修改完成；零新增
skill；强制把 spec-to-task 瘦回 ≤400 行——以此回应"质量 + 效率 + 不臃肿"的三重目标。
