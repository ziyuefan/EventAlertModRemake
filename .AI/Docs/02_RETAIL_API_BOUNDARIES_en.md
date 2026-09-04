<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# Retail API Boundaries & Taint Defense

## Retail 12.x Architectural Assumptions

This rewrite specifically targets the World of Warcraft: Retail 12.x / Midnight AddOn API.

Primary Namespaces in Use:
- `C_AddOns`
- `C_Spell`
- `C_Item`
- `C_UnitAuras`
- `C_TooltipInfo`
- `AuraUtil`
- `C_Timer` (restricted to central Scheduler or explicit non-hot paths)

---

## Taint Control & Combat Security Policy

In World of Warcraft FrameXML, AddOns and `/script` snippets are treated as untrusted execution states. Once execution taint infects a secure execution path, protected combat actions are blocked. EAM treats Taint Prevention as an inviolable architectural boundary rather than a mere bug.

### Mandatory Rules:
1. **Never Hook or Monkey-Patch Secure Functions**:
   Do not hook, overwrite, or replace Blizzard secure/protected functions, unit frames, nameplates, spellcasting execution, targeting, or action button pipelines.
2. **No Combat Structural Mutations**:
   Never modify properties, parentage, anchor points (`SetPoint`), size, visibility, or templates of protected frames during `InCombatLockdown()`.
3. **No Tainted References on Blizzard Frames**:
   Never store AddOn tables, callbacks, runtime caches, or debug closures directly onto Blizzard frames.
4. **Isolate EventRouter & Alert Frames**:
   Use orphan frames for `EventRouter`. Alert frames serve strictly display-only purposes with zero secure action attributes.
5. **No `forceinsecure` Bypasses**:
   Never attempt to force insecure states or bypass Blizzard protected action guards. Log any taint violation directly to `.AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md`.

---

## Aura API Generational Boundaries

The following legacy APIs are obsolete in 12.1 Native mode and must never be called in modern paths:
- `C_UnitAuras.GetBuffDataByIndex` / `GetDebuffDataByIndex` / `GetAuraDataByIndex`
- `C_UnitAuras.GetAuraDataByAuraInstanceID`
- `C_UnitAuras.GetAuraDuration` / `GetAuraBaseDuration` / `GetRefreshExtendedDuration`
- `AuraUtil.ForEachAura` / `FindAuraByName`
- `select(10, UnitAura(...))`

### 12.1 Native Aura Container Rules:
- AuraInstanceID is NOT guaranteed to be a `NeverSecret` scalar anchor. Never save raw `AuraData` tables.
- Tracking and rendering are delegated to native `CustomAuraContainer` / `AuraButton` contracts.
- EAM only binds authorized visual Regions during `initializeFrame`.
- Any Secret or protected value must never be stringified, compared, serialized, or used as a table key.

---

## Cooldown API Boundaries

- Use structured `C_Spell` APIs: `C_Spell.GetSpellCooldown`, `C_Spell.GetSpellCharges`, `C_Spell.GetSpellInfo`, `C_Spell.GetSpellTexture`.
- When cooldown info is secret or protected, treat cooldown facts as restricted.
- Never forge cooldown start, duration, or expiration timestamps.
- Avoid repetitive per-frame cooldown queries inside OnUpdate loops.

---

## Secret & Protected Values Policy

When data is restricted or inaccessible in combat:

1. **Four Core Safety Check APIs**:
   - `issecretvalue(value)`: Checks if a value is categorized as a Secret Value.
   - `canaccessvalue(value)`: Checks if the current context has read access.
   - `canaccesstable(table)`: Evaluates if table keys and values can be traversed.
   - `issecrettable(table)` / `hasanysecretvalues(table)`: Checks if table structure contains secret properties.
2. **Table Indexing Protection (CRITICAL)**:
   - AddOns MUST NOT use unverified keys that may be Secret Values to index standard Lua tables (e.g. `spellID` or `text` returned during combat restrictions).
   - Attempting to index with a secret key triggers a fatal Lua error:
     `attempted to index a table that cannot be indexed with Key Secrets`.
   - Always guard lookups: `if not issecretvalue(key) and canaccesstable(tbl) then ... end`.
3. **No `TooltipUtil.SurfaceArgs`**:
   - In 12.x / Midnight, `TooltipUtil.SurfaceArgs` has been completely removed. Calling it results in a fatal `nil value` error.
4. **C-Level Write-Only Sinks**:
   - For protected numbers, route them directly into native Blizzard C-Level sinks without Lua readback:
     - `FontString:SetFormattedText("%d", secretNum)` (AllowedWhenTainted = true, SecretAspect.Text).
     - `StatusBar:SetValue(secretNum)` (Write-only sink).
     - Native `DurationObject` for CooldownFrame widgets.

---

## Prohibited Patterns Summary

- Classic / MoP / TBC / Wrath backward-compatibility forks in the active mainline.
- `RegisterAllEvents`.
- Heavy tooltip scanning as a routine data source.
- Bulk item ID iteration during login or combat.
- Per-icon `SetScript("OnUpdate")` timer loops.
- Chained `C_Timer.After` closures in hot execution paths.

---

## Authoritative Community Reference Repositories

- **Ketho/WowDoc**: [https://github.com/Ketho/WowDoc](https://github.com/Ketho/WowDoc)
  The community's most exhaustive WoW Lua API documentation, FrameXML reference, and event signatures across versions.
- **Ketho/BlizzardInterfaceResources**: [https://github.com/Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources)
  Catalog of Blizzard UI textures, sound assets, fonts, atlases, and interface resources.
- **Ketho/wow-ui-source-midnight-ptr**: [https://github.com/Ketho/wow-ui-source-midnight-ptr](https://github.com/Ketho/wow-ui-source-midnight-ptr)
  Blizzard Midnight / Retail 12.x PTR UI source code (FrameXML) mirror repository, tracking API changes, AuraContainer implementation, and Secret/Taint internals.
