<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# Module Contracts & Ownership Rules

## Ownership Principles

- **`SavedVariables`**: Owns persisted configuration schemas, validation, and migration backups.
- **Data Services**: Own runtime facts (auras, cooldowns, resources, stats, ground spells).
- **`Renderer`**: Owns rendered visual state and layout positioning.
- **`IconPool`**: Owns recyclable UI frame objects, textures, and font strings.
- **`Scheduler`**: Owns frame-budgeted and throttled background jobs.
- **`DebugState`**: Owns diagnostic and live-test session snapshots.
- Static constants may be frozen (`table.freeze`); runtime state tables and `SavedVariables` must NEVER be frozen.

---

## 1. Core Subsystem Contracts

### `Core/Env.lua`
- **Inputs**: AddOn namespace table from Blizzard loading arguments.
- **Outputs**: Initialized `EAM` namespace, local Blizzard API aliases, client build validation, and Retail-only execution guards.
- **Boundary**: Never modifies `SavedVariables` directly.

### `Core/Util.lua`
- **Inputs**: Raw Lua tables, numbers, strings, and Blizzard objects.
- **Outputs**: Defensive helpers (`isSafeNumber`, `isSafePositiveNumber`, `isSecretValue`, `canAccessValue`, `readSafeField`), object pool helpers, and table wiping.
- **Boundary**: Does not hold domain state; purely utility functions.

### `Core/Constants.lua`
- **Inputs**: None.
- **Outputs**: Immutable constants (`ALERT_KINDS`, `ALERT_FRAME_TYPES`, `LAYOUT_OFFSETS`, `SCHEMA_VERSION`, `CANONICAL_THEMES`).
- **Boundary**: Frozen upon initialization.

### `Core/EventRouter.lua`
- **Inputs**: Blizzard FrameXML events.
- **Outputs**: Dispatches filtered event payloads to registered listener services.
- **Boundary**: Uses a single isolated dummy frame. Never registers `RegisterAllEvents`.

### `Core/Scheduler.lua`
- **Inputs**: Single central `OnUpdate` ticker.
- **Outputs**: Executes deferred tasks, throttled background samplers, and combat-deferred replays.
- **Boundary**: Enforces frame-budgeted processing to prevent combat FPS degradation.

### `Core/SavedVariables.lua`
- **Inputs**: Raw `EAM_DB` table from disk.
- **Outputs**: Normalized, validated, and migrated configuration; provides transactional getters and setters.
- **Boundary**: Emits change events (e.g. `EAM_COOLDOWN_CONFIG_CHANGED`) to notify runtime services.

---

## 2. Services Subsystem Contracts

### `Services/AuraService.lua`
- **Inputs**: `UNIT_AURA`, target change events.
- **Outputs**: Manages player/target aura states, tracks shield absorb amounts (`points`), and passes normalized states to `Renderer`.

### `Services/CooldownService.lua`
- **Inputs**: `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `UNIT_SPELLCAST_SUCCEEDED`.
- **Outputs**: Exact player-cast activation gating, charge tracking via safe `SpellChargeInfo`, and pre-render desaturated placeholder management.

### `Services/PlayerResourceService.lua`
- **Inputs**: `UNIT_POWER_UPDATE`, `RUNE_POWER_UPDATE`, `UPDATE_SHAPESHIFT_FORM`.
- **Outputs**: 17 power types across 40 specs; routes secret resource numbers directly into native `StatusBar` sinks.

### `Services/PlayerStatService.lua`
- **Inputs**: Stat change events, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`.
- **Outputs**: 18 core stats, 4-in-1 speed tracking, C-level `FontString:SetFormattedText` zero-GC rendering, and combat cache fallbacks.

---

## 3. UI Subsystem Contracts

### `UI/IconPool.lua`
- **Contract**: Recycles icon buttons, textures, border layers, and cooldown sweeps.
- **Rules**: Never instantiates new frames during combat; uses prewarmed pools.

### `UI/Renderer.lua`
- **Contract**: Purely consumes normalized `AlertState` records; never reads Blizzard game data APIs directly.
- **Rules**: Layout mutations (`SetPoint`) are restricted to out-of-combat; during combat, state changes modify only text, alpha, vertex color, and cooldown sweeps.

### `UI/Options.lua`
- **Contract**: Multi-panel configuration UI with 3-level APPEND docking, live drag-and-drop reordering, and hover tooltips.
- **Rules**: All mutations write strictly through `SavedVariables` setters.
