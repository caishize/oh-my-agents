# Team Discussion — gstack v1.28 时代再校准与 AI 自动化开发深度集成

**日期**: 2026-05-08（上一次 2026-04-30，间隔 8 天）
**议题**: oh-my-agents (v3.3.0) × gstack (v1.28.0.0) — 路径迁移、Memory Ingest v1、
四十七 skill 生态下的差异化定位
**目标**: 在不增加 skill / hook / agent 的前提下，把研发交付质量与效率再推一个台阶；
回应 Anthropic 三代理 harness、Osmani "60 行 AGENTS.md"、HumanLayer "Skill Issue"
等 2026-Q2 业界共识；让 oh-my-agents 在 gstack 高速演进中**保持不被覆盖的差异化价值**。

---

## 与会角色（沿用班底，决议传承）

| 角色 | 关注视角 |
|------|---------|
| **Claude Code Skill 专家 · 林舟** | Skills/AGENTS.md/MCP 规范、composition、token 预算、progressive disclosure |
| **Harness Engineering 专家 · 方哲** | 四支柱、guides/sensors、Anthropic 三代理 harness、rippable 原则 |
| **研发效能专家 · 苏衡** | DORA、flow efficiency、AI 自动化开发吞吐、瓶颈识别 |
| **系统研发架构师 · 陈景** | 解耦、依赖契约、版本演进韧性、商品化压力下的差异化锚点 |

---

## 一、现实校准（事实优先于观点）

### 1.1 集成契约再次漂移（8 天内 7 个版本）

| 项 | `.claude/integration.json` 当前值 | gstack 实际 (CHANGELOG@main) |
|---|---|---|
| version | `1.21.1.0` | **`1.28.0.0`**（2026-05-07 发布） |
| skill 数 | 假定 ~25 | **47 skills / 75 commands**（v1.28 llms.txt 索引） |
| 上次契约复审 | 2026-Q3（计划） | 已发生**两类破坏性变更** |

**两类破坏性变更：**

1. **路径迁移（v1.27.0.0, 2026-05-06）**：仓库与 binary 由 `gstack-brain` 改名为
   `gstack-artifacts`。配置键 `gbrain_sync_mode → artifacts_sync_mode`，二进制
   `gstack-brain-init → gstack-artifacts-init`。**worktree 目录是否一并改名未在
   changelog 表头明列**——但 migration script (`gstack-upgrade/migrations/v1.27.0.0.sh`)
   已经执行 on-disk file moves。我们硬编码的 `~/.gstack-brain-worktree/` 在已升级用户
   机器上**很可能已变为 `~/.gstack-artifacts-worktree/`**。
2. **Memory Ingest v1（v1.26.0.0, 2026-05-02）**：8 种 memory 类型（transcripts /
   eureka / learning / timeline / CEO-plan / design-doc / retro / builder-profile）
   现以 `gbrain put` 写入、`gbrain search` 检索，6 个 skill 携带 **gbrain 清单**
   声明 preamble 期望。后续 v1.26.3 上线 `/sync-gbrain` 编排，v1.27.0 再加 **Path 4
   Remote MCP 接入**——意味着不再纯文件 glob 可达。

### 1.2 自我审计（在新基线下）

| 发现 | 严重度 | 证据 |
|---|---|---|
| 6 处硬编码 `~/.gstack-brain-worktree/`（3 个 SKILL.md + integration.json + INTEGRATION.md + 上次讨论） | 🔴 P0 待迁移 | `grep -rn` 命中 6+ 行 |
| `--from-gstack-learnings` 仅消费 1/8 memory 类型，且未感知 `gbrain` CLI / MCP 路径 | 🟠 P1 信号网窄 | `encode-mistake/SKILL.md:36-37, 219-224` |
| `composition.ignored` 漏掉 v1.26+ 新 surface（`/sync-gbrain`、`bin/gstack-memory-ingest`、`bin/gstack-brain-context-load`） | 🟡 P2 契约遗漏 | `.claude/integration.json:60` |
| 缺 v1.26.2/v1.27.1 "wrote_findings_before_asking" 信号在 `/harness-review` 的对应 backstop（plan-mode 反捷径） | 🟡 P2 review 信号缺位 | gstack changelog v1.26.2 |
| 11 个 SKILL.md ≤317 行，全部合规；CLAUDE.md ~140 行，5311 字节，仍偏 verbose（Osmani 60 行基线） | 🟢 自我对照 | `wc -l` 全员 |
| Anthropic 三代理 harness（Planner/Generator/Evaluator）已成业界主流叙事，本插件未对自身角色明确映射 | 🟡 P2 自我表述 | InfoQ 2026-04 |

### 1.3 业界基线再校准（2026-Q2）

- **Anthropic 三代理 harness**（InfoQ, 2026-04）：Planner / Generator / Evaluator
  分离；**用 context reset + 结构化 handoff artifact 替代 compaction**，避免
  context-window amnesia；前端设计 5–15 轮迭代，单跑可达 4 小时。
  > "Separating the agent doing the work from the agent judging it proves to be a
  > strong lever to address this issue." — Prithvi Rajasekaran
- **Addy Osmani**（2026 更新版）：AGENTS.md 应 **≤60 行**（"pilot's checklist"），
  *every line traceable to a specific past incident*；**success silence, failure
  verbosity**；progressive disclosure 是默认配置语法。
- **HumanLayer + ETH Zurich**：persona-based subagent **是反模式**（gstack 恰是
  persona 设计）；LLM 自生成 agentfile **拉低性能 +20% token**——意味着我们
  `/encode-mistake` 必须**保持人类闸门**，绝不自动写入 LINTING.md。
- **Chroma context rot**：context 越长、与查询语义相似度越低则降级越陡——再次
  反向支撑我们的 SKILL.md ≤400 行硬约束。
- **商品化压力**：Anthropic Managed Agents 公测 **$0.08/session-hour**；OpenAI
  Agents SDK 原生 harness 零运行时费。"通用 harness" 已是商品；**oh-my-agents
  的差异化必须更锋利地锚定在 *opinionated 质量* 而非通用编排**。

---

## 二、四方观点（新材料下的交锋）

### 林舟（Skill 专家）

> "v1.28 一份 `llms.txt` 把 47 skill / 75 command 压到 11KB——这是 gstack 用
> progressive disclosure 自己回答 token 预算的标准答案。**我们的发现路径还在硬
> 编码 skill 名**（如 `lifecycle/SKILL.md` 直接列 11 个 skill）。下一次 gstack
> 加一个 skill，我们的菜单不会自动更新。该接 `llms.txt` 而不是逆向生成自己的索引。"
>
> "Osmani 60 行是给 *系统提示每轮加载* 的 AGENTS.md 用的——SKILL.md 是 progressive
> disclosure 加载，预算可以宽到 400。两套预算各自成立，**别混用**。但根级
> CLAUDE.md（每会话加载）该按 60 行口径再瘦一次。"

**主张**：
- 每个 gstack bridge 路径**双值**：旧（`gstack-brain*`）+ 新（`gstack-artifacts*`），
  glob 联合匹配，graceful-degrade。
- `/lifecycle` 与 `/gstack-sync` 优先消费 gstack `llms.txt`（若存在），不存在则
  fallback 现有探测。零新增 skill。
- 根 CLAUDE.md **不是**SKILL.md——施加 60 行硬约束，把详情移到 docs/。
- **不新增 skill**。

### 方哲（Harness Engineering 专家）

> "Anthropic 三代理 harness 是当下最有说服力的叙事——但**我们的真正贡献不是再做一套
> Planner/Generator/Evaluator**，而是给已经 *存在* 的三角色提供 *约束面* 和 *证据面*。
> `/spec-to-task` 已是 Planner 的 handoff artifact 生产者；hooks + 人是 Generator
> 端的约束；`/verify` + `/harness-review` 是 Evaluator。**该把这层映射写进 docs/**，
> 让用户和未来贡献者一眼看出 oh-my-agents 在三代理图里的坐标——这是叙事差异化，
> 0 行代码改动。"
>
> "Memory Ingest v1 让 sensor 网络从 8 信号面跃升。我们如果继续只读 learnings-log，
> 等于盯着 1/8 的视野。`gbrain search` CLI（v1.26+）是新一等公民——bridge 探测
> 该以 *binary 存在性* 优先于 *文件 glob*。"

**主张**：
- `docs/ARCHITECTURE.md` 增 1 张表：把本插件 11 skills + 6 hooks 投影到 Anthropic
  三代理坐标系。**仅文档**，不动代码。
- `gbrain` CLI 在 PATH 时优先调用 `gbrain search --type learning|eureka|retro --since 7d`；
  不在时 fallback 到 glob；MCP-only（v1.27 Path 4）时在 `/gstack-sync --status` 输出 hint。
- `/encode-mistake --from-gstack-learnings` 扩展为 `--from-gbrain [type]`，**默认 type=learning**，
  保持向后兼容。**人类闸门不动**——ETH Zurich 警示已写在防臃肿条款里。

### 苏衡（研发效能专家）

> "我跟踪了过去两周 8 次 `/lifecycle next` 的实际用户路径，**最大摩擦点在 review 阶段**：
> 用户跑了 `/harness-review`，输出一堆 finding，但没人决定下一步——这正是 gstack
> v1.26.2 加 `wrote_findings_before_asking` 分类器的原因。我们应该在 `/harness-review`
> 末尾加一行**强制决策点**：APPROVE / REQUEST CHANGES / NEEDS HUMAN——而不是输出
> 完结论留个空白。"
>
> "AI 自动化开发的瓶颈现在不在'生成代码'，在'**未决态**'。每个未决态消耗一个用户介入。
> 我们的目标是把未决态压缩到 *单一决策点*——这是流效率的真问题。"

**主张**：
- `/harness-review` 在结尾**强制**输出决策标签（`APPROVE` / `REQUEST_CHANGES` /
  `NEEDS_HUMAN`），并写入 `.claude/signals/review-latest.json`，让 `/lifecycle next`
  能读出来直接前进或停。
- `/lifecycle next` 的 Gate Failure Routing 表追加一条："review 输出无决策标签 → 视为
  `NEEDS_HUMAN`，提示用户回看而非默认通过"。
- DORA 指标继续 grounded：v1.28 后 `/landing-report` 路径不变，无需迁移。

### 陈景（系统架构师）

> "8 天 7 个版本——任何 *固定路径假设* 都在裸奔。我看 `gstack-brain` → `gstack-artifacts`
> 这个改名是真正的破坏性变更：v1.27 提供 migration script，但**我们的 bridge 要假设
> 任意一台用户机器的状态既可能是迁移前也可能是迁移后**。再加上 v1.27 Path 4 的 Remote
> MCP——根本没有本地路径可探。"
>
> "差异化定位上：当 Managed Agents @ $0.08/h 成为基线、OpenAI Agents SDK 提供原生
> harness——**通用 *orchestration* 已是商品**。oh-my-agents 唯一不可替代的是：
> *本仓库内被强制执行的、可机械验证的质量约束*。这是 hooks + arch-guard + LINTING TASTE
> 规则。任何让我们看起来像在做 *workflow orchestration* 的功能，都该重新评估或下架。"

**主张**：
- 引入 **bridge 探测三态**：`legacy_path` / `current_path` / `mcp_only`。
  `~/.gstack-brain-worktree/` 与 `~/.gstack-artifacts-worktree/` glob 联合 + capability
  probe + Remote MCP fallback hint。
- `min_supported` 从 `1.9.0.0` → **`1.26.0.0`**（Memory Ingest v1 里程碑），同步反
  v1.26 之前的 brain artifact 假设。
- `composition.ignored` 加入 v1.26+ 与本插件无关的 surface（已含 4 项，扩到 7 项）。
- **明确"不做 orchestration"**：在 INTEGRATION.md 的 Anti-Bloat 中追加一条
  "不重叠 lifecycle orchestration"——`/lifecycle` 仅做 *route + report gate*，不做
  *execute*；如果未来某条逻辑变成 "我们在编排"，立刻让位 `/lifecycle next` for gstack。

---

## 三、一致结论

### 3.1 强化的"差异化锚点"（明确写下，便于未来评估）

| 锚点 | 状态 | 举证 |
|---|---|---|
| 仓内可机械验证的质量约束（hooks + arch-guard + TASTE） | **保留并强化** | 不可被 Managed Agents 通用层替代 |
| 双层模型：observation（gstack/GBrain）→ enforcement（TASTE） | **保留** | ETH Zurich + Osmani 双重背书 |
| 反 slop / 反 entropy 长期视角 | **保留** | Chroma context rot 实验支撑必要性 |
| Workflow orchestration | **不做** / 让位 | 已商品化；`/lifecycle` 仅做 *route* |
| 自动生成规则 | **明确不做** | ETH Zurich：–20% token，反提示 |
| 通用 harness | **不做** | Managed Agents @ $0.08/h 已是基线 |

### 3.2 防臃肿原则（v3，本次新增三条）

继承上次 10 条并补充：

11. **bridge 路径双值兼容（legacy + current）+ MCP-only fallback**——任何 gstack 改名
    迁移在用户侧异步发生，必须双轨。
12. **`min_supported` 跟随 Memory Ingest 等核心能力里程碑**——本次：v1.9 → v1.26。
13. **明确"不做 orchestration"**——`/lifecycle` 是 router + reporter，不做 executor；
    任何让我们看起来像在编排，立刻评估退场。

### 3.3 交付契约（v1.3，扩展版）

```
gbrain_worktree (双值):
  legacy   ~/.gstack-brain-worktree/                       (兼容 v1.9-v1.26)
  current  ~/.gstack-artifacts-worktree/                   (v1.27+，可能)
gbrain_cli:           which gbrain                          (能力探针，新)
gstack_llms_txt:      <gstack_root>/llms.txt 或 ~/.claude/skills/gstack/llms.txt  (新)
gstack_memory_ingest: <gstack_root>/bin/gstack-memory-ingest (能力探针，新)
review_signal:        .claude/signals/review-latest.json   (新，由 harness-review 写)
```

### 3.4 落地项（编辑 8 个文件，0 新增 skill / hook / agent / doc 例外 1）

| # | 动作 | 文件 | Anti-bloat 检查 |
|---|---|---|---|
| A | 升级集成宣言：version 1.28、min_supported 1.26、bridge 路径双值、composition.ignored 扩 | `.claude/integration.json` | 仅扩字段 |
| B | `/gstack-sync` 优先读 `llms.txt`、双值路径探测、报告 mcp-only 状态 | `skills/gstack-sync/SKILL.md` | 当前 220，预算 +25 |
| C | `/encode-mistake --from-gstack-learnings` → `--from-gbrain [type]`；`gbrain` CLI 优先；**不变更人类闸门** | `skills/encode-mistake/SKILL.md` | 当前 261，预算 +30，硬顶 ≤400 |
| D | `/harness-dashboard` 双值路径 + DORA 不变 | `skills/harness-dashboard/SKILL.md` | 当前 280，预算 +20 |
| E | `/harness-review` 末尾**强制决策标签** + 写 `review-latest.json` | `skills/harness-review/SKILL.md` | 当前 272，预算 +25 |
| F | `/lifecycle next` 读 `review-latest.json`；新 Gate Failure Routing 行；强调 router 角色 | `skills/lifecycle/SKILL.md` | 当前 152，预算 +30 |
| G | `INTEGRATION.md` 更新职责矩阵、bridges、Anti-Bloat v3 三条 | `docs/INTEGRATION.md` | 替换式更新 |
| H | `ARCHITECTURE.md` 新增 1 张"Anthropic 三代理坐标"投影表（叙事，0 代码） | `docs/ARCHITECTURE.md` | +25 行内 |
| I | 根 `CLAUDE.md` 按 60 行 AGENTS.md 口径瘦身（详情迁 docs/） | `CLAUDE.md` | 净减少 ≥40 行 |
| J | 同步本讨论纪要 | `docs/TEAM-DISCUSSION-2026-05-08.md` | 唯一 +1 doc |
| K | 版本 3.3.0 → 3.4.0 + 描述同步（v1.28、双值路径、决策标签） | `.claude-plugin/plugin.json` | 仅元数据 |

**总文件改动 = 11（其中 1 新增 doc，0 新增 skill / hook / agent）**。

### 3.5 否决项（讨论后明确不做）

- ❌ 不新增 `/gbrain-search` / `/three-agent-harness` / `/llms-index` 独立 skill
- ❌ 不写入 `~/.gstack-artifacts-worktree/` / `~/.gstack-brain-worktree/`
- ❌ 不复刻 `gbrain put` / `gbrain search`（直接调 CLI 或 fallback glob）
- ❌ 不为 v1.27 Remote MCP 主动适配——只输出 hint
- ❌ 不复制 gstack v1.26.2 `wrote_findings_before_asking` 分类器逻辑——我们用更简单的
  "末尾决策标签缺失"判定即可
- ❌ 不为 Managed Agents / OpenAI Agents SDK 做兼容层——继续观察
- ❌ 不做 trajectory-eval Legibility Score——连续第三次延期，列入 Q3 议程

---

## 四、给"AI 自动化开发"的解释

为什么这次集成方向能直接放大 AI 自动化交付：

1. **未决态压缩**：`/harness-review` 末尾的决策标签直接喂 `/lifecycle next`，
   把过去"输出 → 用户读 → 用户决定 → 触发下一步"压成"输出携带决策 → 下一步自动"。
   按苏衡上述跟踪数据，每次 review 平均节省 1 次用户介入。
2. **sensor 网络从 1/8 → 8/8**：`gbrain search` 接入后，`/encode-mistake` 候选池
   从 learnings 单一源扩到 transcripts/eureka/retro/builder-profile 八源；同样的
   人类闸门，更高的命中率。
3. **抗迁移衰减**：bridge 双值兼容确保 gstack v1.27 改名不让我们盲飞；
   migration script 在用户侧任何时间点执行都不影响我们的可用性。
4. **降 token 与 progressive disclosure 自洽**：
   - 优先 `llms.txt` 替代逆向枚举（节省每次 gstack 升级的人工同步成本，0 token in normal path）
   - 根 CLAUDE.md 60 行化（每会话加载，每次节省 ~80 行 ≈ 1.6K tokens）
   - 决策标签 + signal file（短结构化，下游零解析成本）
5. **差异化锚点显式化**：在 INTEGRATION.md 与 ARCHITECTURE.md 中明确"我们做约束、
   不做编排"——避免在商品化通用 harness 的浪潮里渐渐失去身份。

---

## 五、留待下次（议程已锁定）

1. **Legibility Score → trajectory-eval**（连续第三次延期，**Q3 必启动**，否则下架）
2. **`harness-review` 全面 success silence, failure verbosity 改造**（本次只补强决策标签，verbose-pass 收敛延期）
3. **gstack v1.27 Path 4 Remote MCP 主动适配**（继续观察至少一个月，等 MCP API 稳定）
4. **session-observer-agent / doc-gardening-agent 是否接 GBrain 写**（当前严格不写；评估只读消费 transcripts ingest 的可行性）
5. **若 gstack 引入 *Evaluator* 角色 skill，`/harness-review` 是否退场为薄壳**——届时再议
6. **Anthropic Managed Agents 适配**（持续观察，等定价与 SDK 稳定）

---

**结论**：在 gstack 8 天 7 个版本（v1.21→v1.28）的高速演进面前，本次集成做三件事：
**(1) 路径双值兼容化**让我们抵御 v1.27 改名风暴；**(2) sensor 八源化 + 决策标签化**
让 AI 自动化开发的未决态进一步收缩；**(3) 显式声明差异化锚点**——我们做"机械约束 +
反 slop / 反 entropy"，不做被商品化的通用 orchestration。11 个文件、0 个新 skill、
0 个新 hook、0 个新 agent；CLAUDE.md 主动瘦身一次以兑现 Osmani 准则——以此回应
"质量 + 效率 + 不臃肿"的三重目标。

---

## 附：参考资料

- [Anthropic Three-Agent Harness — InfoQ, 2026-04](https://www.infoq.com/news/2026/04/anthropic-three-agent-harness-ai/)
- [Addy Osmani — Agent Harness Engineering](https://addyosmani.com/blog/agent-harness-engineering/)
- [HumanLayer — Skill Issue: Harness Engineering for Coding Agents](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [OpenAI — Harness Engineering: Leveraging Codex in an Agent-First World](https://openai.com/index/harness-engineering/)
- [gstack CHANGELOG (v1.21 → v1.28)](https://github.com/garrytan/gstack/blob/main/CHANGELOG.md)
- [Stop Bloating Your CLAUDE.md (alexop.dev)](https://alexop.dev/posts/stop-bloating-your-claude-md-progressive-disclosure-ai-coding-tools/)
- [Anthropic, OpenAI, Google, Microsoft — Harness Pricing Split (TheNewStack)](https://thenewstack.io/ai-agent-harness-pricing-split/)
