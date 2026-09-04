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
| **C1_CROSS_MODEL_CONTINUITY** | **Model Switch / Context Window Truncation** | **Mandatory Ingestion**. When an agent experiences memory reset, ingesting `AI_GOVERNANCE_DIRECTIVE.xml` is the first required step. |
| **C2_SUBAGENT_PROMPT_INJECTION** | **Subagent Task Delegation** | **Dynamic Slicing**. Extract corresponding XML nodes based on subagent duties and inject into prompts. |
| **C3_COMPLEX_MODULE_REFACTOR** | **Major Module Refactoring** | **Structured Expansion**. Update state machine and pool boundaries within `<architecture_contracts>`. |
| **C4_PROTECTED_API_INCIDENT** | **Blizzard API Change / Taint Incident** | **Immediate Lockdown**. Append forbidden operations into `<secret_values_sentinel>` as an unbreakable firewall. |

---

## 📌 4. Physical File Reference

- **Physical AI Governance XML Directive**: [`.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml`](file:///d:/Project_EventAlertMod_AGY/.AI/Docs/AI_GOVERNANCE_DIRECTIVE.xml)
- **Validation**: Fully validated with Python `xml.etree.ElementTree` parser with 8 top-level structural modules intact.
