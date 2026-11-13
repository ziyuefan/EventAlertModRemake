<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod AI Agent Structured XML Governance Directive Manual

> 🤖 **Authoritative XML Structured Governance Directive Designed for LLM / Agentic AI Prompt Ingestion and Zero Cold-Start Anchoring**

---

## 🧭 1. Core Definition & Technical Positioning

The **.xml governance directive** established in this specification is fundamentally distinct from the FrameXML used in World of Warcraft AddOn UI layouts:

- ❌ **Not AddOn Runtime XML**: Does not render in-game frames; not loaded by `EventAlertMod.toc`.
- ✅ **Agentic AI Governance XML**: Serves as a high-fidelity, zero-ambiguity structured directive for Large Language Models (LLMs such as Claude, Gemini Pro, Codex) and Subagent clusters. The physical XML file is maintained at [`.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`](file:///d:/Project_EventAlertMod_AGY/.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml).

---

## 💡 2. Why Structured XML for AI Governance?

In multi-agent and cross-session collaboration, standard prose and markdown often suffer from **attention dilution (Lost-in-the-Middle), memory loss during model upgrades, and degradation of negative constraint adherence**.

Structured XML provides three decisive advantages:
1. **Hierarchical Scoping & Tag Boundaries**: Explicit tags such as `<iron_rules>` and `<secret_values_sentinel>` eliminate ambiguity and ensure strict boundary enforcement.
2. **Subtree Extraction for Subagents**: When calling `invoke_subagent`, the primary agent can extract relevant subtrees (e.g., `<secret_values_sentinel>`) and inject them directly into subagent prompts without cluttering context windows.
3. **Zero Cold-Start Continuity**: When switching model tiers or recovering from conversation truncation, ingesting `AI_GOVERNANCE_DIRECTIVE.xml` restores complete architectural awareness in milliseconds.

---

## ⚖️ 3. Decisional Matrix: When to Establish and Ingest AI Governance XML

The architecture framework delegates the timing and triggers for establishing and expanding AI governance XMLs to four distinct criteria:

| Trigger ID | Scenario | Required Action |
| :--- | :--- | :--- |
| **C1_CROSS_MODEL_CONTINUITY** | **Model Switch / Context Window Truncation** | **Mandatory Ingestion**. When an agent experiences memory reset or switches between Track A / Track B, ingesting `AI_GOVERNANCE_DIRECTIVE.xml` restores architectural alignment immediately. |
| **C2_SUBAGENT_PROMPT_INJECTION** | **Subagent Task Delegation** | **Dynamic Slicing**. Extract corresponding XML nodes based on subagent duties (including `<level3_closed_xml_ticket_standard>` for high-risk Level 3 tickets) and inject into prompts. |
| **C3_COMPLEX_MODULE_REFACTOR** | **Major Module Refactoring** | **Structured Expansion**. Update state machine and pool boundaries within `<architecture_contracts>` and issue a closed `<argon_ticket>` XML dispatch contract. |
| **C4_PROTECTED_API_INCIDENT** | **Blizzard API Change / Taint Incident** | **Immediate Lockdown**. Append forbidden operations into `<secret_values_sentinel>` as an unbreakable firewall. |
| **C5_DUAL_TRACK_SWITCH** | **Arbiter Quota Shift (Track A ↔ Track B)** | **Track State Synchronization**. Switch `active_track` (`TRACK_B`: `Gemini 4 Hydrogen (XHigh)` Arbiter + `Hydrogen` dynamic; `TRACK_A`: `Gemini 4 Argon (High)` Arbiter + `Hydrogen` dynamic) per explicit user directive and sync continuity docs + `eam-dual-track-orchestration`. |

---

## 🎯 4. Active Dual-Track Orchestration & Level 3 Closed XML Schema

- **Active Orchestration Track (`2026-11-13`)**: **Track B** (`Gemini 4 Hydrogen (XHigh)` Chief Arbiter & Cold-Context Drift Auditor + `Gemini 4 Hydrogen` 4-Tier Dynamic Workers `LOW / MEDIUM / HIGH / XHIGH`). Track A (`Gemini 4 Argon (High)` Chief Arbiter) remains on standby for explicit restoration.
- **4-Tier Self-Routing & Reply Header**: Every user response begins with `【任務階段：＜階段名稱＞｜建議模型與檔位：Hydrogen (LOW / MEDIUM / HIGH / EXTRA) 或 Argon｜治理模式：輕量 / L1+L2 / 完整 XML】`.
- **Level 3 Closed `<argon_ticket>` XML**: Node #13 defines the complete closed schema (`<meta>`, `<scope>/<allowed_files>`, `<immutable_files>`, `<invariants>`, `<execution_plan>`, `<verification>`, `<cold_context_review>`) for high-risk core engine or multi-module refactors.

---

## 📌 5. Physical File Reference

- **Physical AI Governance XML Directive**: [`.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`](file:///d:/Project_EventAlertMod_AGY/.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml) (`v1.4`, updated `2026-11-13`)
- **Related Skill**: [`.AI/skills/eam-dual-track-orchestration/SKILL.md`](file:///d:/Project_EventAlertMod_AGY/.AI/skills/eam-dual-track-orchestration/SKILL.md)
- **Validation**: Validated with Python `xml.etree.ElementTree` parser across all 13 top-level structural nodes (including `<dual_track_model_routing>` and `<level3_closed_xml_ticket_standard>`).
