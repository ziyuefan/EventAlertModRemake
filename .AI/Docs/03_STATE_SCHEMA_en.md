<!-- EAM_DOCUMENTATION_SOURCE: enUS -->
# State Schema & Data Models

## SavedVariables Schema & Governance

The modernized EventAlertMod declares the following `SavedVariables` in its TOC:
```lua
EAM_DB
EAM_FLOW_TEST_REPORT_JSON
EAM_VALIDATION_PROFILE
EAM_LIVE_TEST_SESSION
EAM_LIVE_TEST_REPORT_JSON
```

Legacy tables preserved solely for migration backups:
```lua
EA_Config, EA_Position, EA_Items, EA_AltItems, EA_TarItems, EA_ScdItems, EA_GrpItems, EA_Pos
```

---

## Schema Versions & Migration Contracts

- **Current Schema**: `EAM_DB.schemaVersion = 4` (with class-isolated player resources, per-class stat profiles, tactical groups, and cooldown order).
- **Transient Memory Isolation**: Frames, script callbacks, `DurationObject` pointers, and `CustomAuraContainer` instances must NEVER be written to `SavedVariables`.
- **Idempotency**: Submitting an unchanged setting returns `unchanged` without incrementing the database revision.
- **Future Schema Fallback**: If `schemaVersion` on disk is newer than the running AddOn code understands, the AddOn must NOT overwrite or normalize it; it safely falls back to a clean in-memory defaults copy marked with `futureSchemaPreserved`.

### Normalized Text Layout Schema
```lua
EAM_DB.config.textLayout = {
    schema = 1,
    timer = {
        placement = "OUTSIDE_TOP",
        fontSize = 14,
    },
    applications = {
        placement = "INSIDE_BOTTOM_RIGHT",
        fontSize = 12,
    },
}
```
- `placement` accepts one of the 21 canonical IDs defined in `Data/TextPlacementContract.json`.
- `fontSize` is strictly normalized between 8 and 32.

---

## Core Runtime State Models

### 1. `AlertState`
```typescript
interface AlertState {
  id: string;
  kind: "selfAura" | "targetAura" | "spellCooldown" | "itemCooldown" | "groundEffect";
  spellID?: number;
  itemID?: number;
  order?: number;
  unit?: "player" | "pet" | "target";
  icon?: number | string;
  name?: string;
  stacks?: number;
  absorbAmount?: number;
  timer?: TimerState;
  isPlaceholder?: boolean;
  isDesaturated?: boolean;
  usableGlow?: boolean;
  factsSafe: boolean;
  boundaryWarnings?: string[];
}
```

### 2. `TimerState`
```typescript
interface TimerState {
  mode: "none" | "numeric" | "displayOnly" | "protected" | "unknown";
  startTime?: number;
  duration?: number;
  expirationTime?: number;
  timeLeft?: number;
  displayText?: string;
}
```

### 3. `IconRenderState`
```typescript
interface IconRenderState {
  alertID: string;
  visible: boolean;
  texture?: number | string;
  stackText?: string;
  timerText?: string;
  nameText?: string;
  cooldown?: {
    start?: number;
    duration?: number;
    enabled?: boolean;
    durationObject?: any;
  };
  glow: "none" | "active" | "usable" | "pandemic" | "warning";
  alpha?: number;
  layoutKey: string;
  isPlaceholder?: boolean;
  isDesaturated?: boolean;
}
```
