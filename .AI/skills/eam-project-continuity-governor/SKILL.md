---
name: eam-project-continuity-governor
description: >-
  專案記憶、連續性與上下文交接治理技能。涵蓋 Docs/28_PROJECT_CONTINUITY.md、Data/ProjectContinuity.json 與 Docs/15_DEVELOPMENT_ISSUE_LOG.md 的維護與 Fact-of-Truth 守護。
---

# EAM Project Continuity Governor (專案記憶與連續性治理)

本技能規範在多 Agent 協作、上下文截斷或長時間交接時的專案記憶與試錯治理標準。

## 1. 核心維護文件
1. **`Data/ProjectContinuity.json`**：機器可讀的當前快照唯一事實來源（Single Fact-of-Truth）。
2. **`.AI/Docs/28_PROJECT_CONTINUITY.md`**：人類可讀的重大架構快照與交接指南。
3. **`.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`**：完整試錯時間線、根因分析與決策脈絡。

## 2. 治理守則與雙軌切換同步
- **不重蹈覆轍**：遭遇問題前先檢索 `15_DEVELOPMENT_ISSUE_LOG.md` 避免重複試錯。
- **及時同步快照**：完成重大模組重構或發布後，立即同步更新連續性 JSON (`Data/ProjectContinuity.json`) 與雙語 Markdown 快照 (`Docs/28_PROJECT_CONTINUITY.md`、`Docs/28_PROJECT_CONTINUITY_en.md`)。
- **雙軌模型切換同步 (Track A ↔ Track B)**：切換主架構軌道（如現行因 Argon 額度受限啟用之 **Track B：`Gemini 4 Hydrogen (XHigh)` 仲裁 ＋ `Hydrogen` 四階動態強度**）時，必須同步更新 `.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml` (`active_track`)、`.AI/AGENTS.md`、`.AI/PROJECT_MEMORY.md`、`.AI/Docs/17_SUBAGENT_WORKFLOW.md` 與 `eam-dual-track-orchestration/SKILL.md`。