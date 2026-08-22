<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# AI提示匯出架構

## 目的

主要是進行除錯導出。它的存在是為了幫助用戶或人工智慧代理進行檢查
EAM 狀態，消耗轉儲大量日誌。

型號：

- `debug-min`：結構緊湊，可快速支援。
- `analysis-full`：用於架構/debug 分析的詳細但有限的狀態。
- `github-issue`：使用者可讀取的問題負載。

## 需要分離

導出必須分開：
- 事實：直接、安全的 API 資料；
- 匯出：計算UI/渲染狀態；
- 人工註記：使用者最重要的註解；
- boundaryWarnings：秘密/protected/不安全資料限制；
- 環境：建造、區域設定、戰鬥狀態、FPS、外掛程式版本。

不要將猜測值與事實混為一談。

## 簡潔模式
```js
{
  schema: 1,
  mode: "debug-min|analysis-full|github-issue",
  environment: {
    addon: "EventAlertMod",
    addonVersion: "string?",
    interface: "number?",
    build: "string?",
    locale: "string?",
    inCombat: "boolean",
    fps: "number?",
    retailOnly: true
  },
  facts: {
    alertCount: "number",
    alerts: [
      {
        id: "string",
        kind: "aura|spellCooldown|itemCooldown",
        spellID: "number?",
        itemID: "number?",
        unit: "string?",
        name: "string?",
        icon: "number|string?",
        stacks: "number?",
        timerMode: "none|numeric|displayOnly|protected|unknown",
        active: "boolean",
        sourceAPI: "string?"
      }
    ]
  },
  derived: {
    visibleIcons: "number",
    dirtyQueues: { aura: "number", cooldown: "number", item: "number" },
    schedulerJobs: "number"
  },
  boundaryWarnings: [
    { id: "string?", code: "string", note: "string" }
  ],
  humanNotes: ["string"]
}
```
＃＃例子
```js
{
  schema: 1,
  mode: "debug-min",
  environment: {
    addon: "EventAlertMod",
    interface: 120000,
    locale: "zhTW",
    inCombat: false,
    fps: 118,
    retailOnly: true
  },
  facts: {
    alertCount: 2,
    alerts: [
      {
        id: "aura:player:12345",
        kind: "aura",
        spellID: 12345,
        unit: "player",
        name: "Example Buff",
        timerMode: "numeric",
        active: true,
        sourceAPI: "C_UnitAuras"
      },
      {
        id: "spellCooldown:67890",
        kind: "spellCooldown",
        spellID: 67890,
        timerMode: "protected",
        active: true,
        sourceAPI: "C_Spell"
      }
    ]
  },
  derived: {
    visibleIcons: 2,
    dirtyQueues: { aura: 0, cooldown: 0, item: 0 },
    schedulerJobs: 1
  },
  boundaryWarnings: [
    {
      id: "spellCooldown:67890",
      code: "SPELL_COOLDOWN_SECRET",
      note: "Timer details unavailable; icon-only render used."
    }
  ],
  humanNotes: []
}
```
## 出口限制

- 沒有自動導出。
- 沒有無限制的光環列表。
- 預設沒有完整的 SavedVariables 轉儲。
- 沒有戰鬥日誌垃圾/無用。
- 沒有大型專案倉儲轉儲。
- 字串僅在發生時建構明確的匯出指令。
## 流程驗證報告

流程測試使用獨立 schema，不與一般 DebugSnapshot 混合：

```js
{
  schema: 1,
  type: "EAM_FLOW_VALIDATION_REPORT",
  suite: "quick|core|boundary|all",
  status: "pass|fail",
  environment: {
    source: "offline-mock|retail-client",
    interface: "number",
    initialized: "boolean",
    inCombat: "boolean",
    locale: "string"
  },
  summary: {
    total: "number",
    passed: "number",
    failed: "number",
    skipped: "number",
    pending: "number"
  },
  cases: [
    {
      id: "string",
      suite: "string",
      status: "pass|fail|skip|pending",
      durationMs: "number",
      message: "safe string"
    }
  ],
  boundaryWarnings: []
}
```

限制：

- 不輸出 Secret／Protected 值、完整 SavedVariables 或原始 Aura／Cooldown facts。
- `source` 必須保留，不能把 Offline Mock 改寫成 Retail／PTR。
- 遊戲內最後報告以字串保存於 `EAM_FLOW_TEST_REPORT_JSON`，僅供使用者回灌。

## EAMAP1 Profile 分享格式

Profile 分享不是除錯報告，也不是可執行程式。正式字串為：

EAMAP1:<base64(canonical UTF-8 JSON envelope)>

Envelope 最少包含 type=EAM_ALERT_PROFILE、schema=1、addonSchema=5、scope、payload、payloadBytes 與 Adler-32 checksum。payload.modules 是陣列，不接受外部 map key；每筆 alert 的 derived ID 由 module 與安全的 SpellID／ItemID 重算。

解析器拒絕寬鬆 Base64、duplicate JSON key、trailing data、NaN／Infinity、未知 schema／class／module、過深／過大節點、重複 derived ID 與任何 Lua 程式碼。previewImport 必須零 revision／零事件；applyImport 只接受 fingerprint 未變的 plan，戰鬥中拒絕或延後。Base64 不提供加密或作者驗證。
