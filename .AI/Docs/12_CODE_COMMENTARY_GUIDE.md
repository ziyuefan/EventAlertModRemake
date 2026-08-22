<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 計劃檔解與理念規範

本文件是 EventAlertMod Retail rewrite 的開發相依性。所有正式載入的方案文件都必須包含「檔案系統註解」，用於保存模組理念、責任邊界與日後衡量標準。

## 核心規則

- 每個正式載入的 `.lua` 檔案都要在檔案底部放置模組註解。
- 註解需說明「這個文件為什麼存在」，不只描述「這個文件做什麼」。
- 註解要記錄資料、可變狀態、不可跨越的模組邊界。
- 熱路徑、Secret Values、Protected Data、SavedVariables、UI框架變更相關文件，必須明確寫出限制。
- 註解應保持簡潔、可維護；不要寫成與計畫脫節的長篇宣言。
- 當模組責任變更時，必須同步更新檔案註解與`Docs/04_MODULE_CONTRACTS.md`。

## 建議格式
```lua
--[[
EventAlertMod Retail Rewrite
Module: Core/EventRouter

理念:
- 集中管理 Blizzard event dispatch，避免各模組自行建立事件 frame。
- 使用孤兒 frame，降低 UIParent 與戰鬥保護互動風險。

責任:
- 擁有唯一事件 frame。
- 將 event 分派給已註冊 module handler。

邊界:
- 不讀取 aura/cooldown API。
- 不建立 UI icon。
- 不寫入 SavedVariables。

維護注意:
- 不在註冊熱路徑配置 closure。
- 不使用 RegisterAllEvents。
]]
```
## 必須記錄的項目

- `Module`：模組名稱與路徑。
- `理念`：設計理由與取捨。
- `責任`：該檔案擁有哪些狀態與行為。
- `邊界`：此檔案不能做什麼。
- `完成註意`：若在熱路徑上，說明指派、循環、字串、UI寫入門控策略。
- `正式服API注意`：若使用WoW API，記錄版本假設與實機驗證需求。
- `Secret/Protected數據注意`：若接觸aura/cooldown/unit數據，記錄安全讀取與降級策略。
- `Taint注意`：若接觸UI框架、暴雪框架、戰鬥封鎖、保護路線，如何記錄避免污染 secure/protected路徑。

## 所需的註解

- 不要註解主要的單行屬性。
- 不要在熱路徑加入大量記述註解解。
- 不要用註解解承諾尚未實現或尚未驗證的功能。
- 不要提供WoW正式服實機驗證，除非確實已載入測試。

## 對未來開發的要求

新增或需重構任何載入正式文件時，先補齊文件體系註解，再實作邏輯。若某個文件只是 `LegacyReference`、`ReferenceLibs` 或外部保留數據，可保留原類型，但不得作為新架構風格範本。

## 修改前備份規則
任何檔案在刪除、移移、覆寫或修改前，都必須先備份到專案根目錄的 `backup/` 資料夾。 備份檔案名稱使用原始檔案名稱加上 `__yyyyMMddHHmmss` 後綴，例如 `Renderer.lua__20260526122904`。
此規則的目的不是取代版本控制，而是提供本專案在未建立完整提交歷史前的恢復來源。批次作業相關時，應先完成所有檔案備份，再開始修改實際；若原始檔案不存在，需先返回，不得建立空白備份。

## 開發問題記錄規則
開發過程遇到瓶頸、限制、錯誤、工具失敗、API 不確定性與解決方式，都必須追加記錄到`Docs/15_DEVELOPMENT_ISSUE_LOG.md`。此記錄用於減少日後重複試錯，並在 AI 交接時節省上下文/token。
記錄時應保留足夠的判斷資訊：日期、症狀、原因判斷、已嘗試方法、有效解法與後續注意事項。未解決問題需明確標示為「未解決」，避免未來代理判斷為已完成。

## 專案專屬技能規則
若開發流程中發現某個流程反復出現，且已流程穩定到可描述觸發條件、前置檢查、操作步驟、風險與驗證方式，應產生EventAlertMod專案專用SKILL。此類SKILL用於降低重複指令說明、減少上下文/token，並讓未來代理人能夠一致執行專案這些。
適合轉成 SKILL 的流程包含預算發佈、Lua靜態驗證、WoW API 查詢、SavedVariables遷移檢查、秘密邊界審查、檔案同步與語系檔案同步。尚未驗證、仍需大量人工判斷或涉及敏感資訊的流程，不適用於硬體自動化SKILL。

## Taint 控制註解規則
涉及UI框架、暴雪框架、戰鬥鎖定、secure/protected路線的檔案，檔案系統註解必須說明污染避免風險與方式。常見重點包括：是否使用孤兒框架、是否接觸UIParent、是否會在戰鬥中改anchor/visibility/attribute、是否可能存在secret/protected值、是否會hook暴雪框架。

若程式碼刻意避免某些Blizzard API或hook方式，應在註解中保留原因，未來重構時將污染重新避免引入。