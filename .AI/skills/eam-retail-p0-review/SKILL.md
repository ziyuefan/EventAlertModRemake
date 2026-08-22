<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
---
name: eam-retail-p0-review
description: EventAlertMod Retail rewrite P0 review workflow. Use when Codex needs to modify EAM core code, audit Secret Values or taint risk, update WoW Retail 12.x API assumptions, run Lua/static validation, or prepare a rewrite pass for Core, Services, UI, Debug, TOC, or Docs.
---

# EventAlertMod Retail P0 Review

Use this skill before and after any EventAlertMod Retail rewrite pass that touches loaded Lua, TOC, XML, or API-facing docs.

## Required Inputs

- Workspace root: `D:\EventAlertMod`.
- Read `AGENTS.md` first.
- Read current API and roadmap anchors:
  - `Docs/02_RETAIL_API_BOUNDARIES.md`
  - `Docs/10_WARCRAFT_WIKI_12X_API_NOTES.md`
  - `Docs/16_RETAIL_ADDON_OPTIMIZATION_ROADMAP.md`

## Pre-Edit Workflow

1. Identify every file that may be modified.
2. Back up each existing file to `backup/原始檔名__yyyyMMddHHmmss`.
3. Do not create fake backups for missing files.
4. For WoW API facts, verify current Warcraft Wiki API change data when the answer depends on latest Retail behavior.

## P0 Checks

- No Classic/MOP/Cata/Wrath/TBC/Era support in active load.
- No secret/protected value bypass.
- No `forceinsecure` or taint workaround.
- No Blizzard secure/protected function monkey patch.
- No combat-time protected frame mutation.
- No old global `UnitAura`, `GetSpellCooldown`, `GetSpellInfo`, or `GetItemCooldown` as active architecture.
- No tooltip `string.match` before secret-safe text checks.
- No cooldown widget getter readback as facts.
- No per-icon / per-spell timers.
- No repeated `C_Timer.After(function() ...)` hot-path chains.
- No `table.freeze` on SavedVariables, runtime state, pools, scheduler queues, icon state, or debug snapshots.

## Preferred Fix Pattern

- Put safe reads in `Core/Util.lua`.
- Keep data ownership in `Services/*`.
- Keep UI ownership in `UI/Renderer.lua` and `UI/IconPool.lua`.
- Use `DurationObject` or display-only mode when numeric time is unsafe.
- Mark unsafe state with `boundaryWarnings`.
- Defer structural UI changes in combat.
- Keep debug/profiling/export on demand only.

## Validation

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\CheckLuaSyntax.ps1
```

Then scan active Lua for:

```powershell
UnitAura\b|GetSpellCooldown\b|GetSpellInfo\b|GetItemCooldown\b|C_Timer\.After|SetScript\("OnUpdate"|string\.match|:GetCooldown|forceinsecure|RegisterAllEvents
```

Also scan for `table.freeze` misuse against SavedVariables/runtime state.

## Reporting

Final report must state:

- changed files;
- preserved behavior;
- removed/avoided behavior;
- Secret / Protected Data policy;
- taint policy;
- Lua syntax result;
- static scan result;
- what still needs WoW Retail/PTR validation;
- next task.

## SVG／邊框增量檢查

當變更包含 SVG、VectorGraphics 或分類邊框時，額外確認：

- Frame:CreateVectorGraphics、VectorGraphics:SetSVG 與 Texture:SetSVG 必須以固定 PTR 生成文件分開查證。
- SVG 報告不得輸出 raw file ID；只允許 positive-number、zero、inaccessible 等分類。
- strict mock 必須覆蓋 SetSVG、HasSVG、ClearSVG、reload；12.0.7 必須安全 unsupported。
- Build-CurseForgePackage.ps1 白名單含 .svg，Release ZIP 實際含 Media/SVG/eam-svg-probe.svg。
- AlertBorderStyles 固定 3px anchor；IconPool 與 NativeAuraRenderer 使用 WHITE8X8 的 BORDER layer。
- 執行 CheckLuaSyntax、Run-FlowValidation all 與 Test-ValidationContracts；離線 pass 不得宣稱 PTR pass。
