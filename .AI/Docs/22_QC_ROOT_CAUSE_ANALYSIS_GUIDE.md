<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# EventAlertMod 品質控制與要因分析指引（QC 與根本原因分析指引）
少年欸！為確保EAM在重構與日後開發中的程序代碼質量，避免在同一個Bug上反覆栽種，本文件正式將企業管理學的控製品質（TQM）、新QC七大手段、5個為什麼（WHY-WHYDE）、魚圖要因分析、矩陣對策評估與甘特，圖時相分析的精神法。
後續所有子代理進行問題排查、方案設計（實施方案）與PR審查，均須遵循此QC指引。

---

## 1. 5 Whys (WHY-WHY要因分析) 實施規範

當 EAM 出現任何 Bug、Taint 爆發或 Lua 報錯時，主代理與子代理不得直接嘗試修改程序碼，必須先在 `Docs/15_DEVELOPMENT_ISSUE_LOG.md` 記錄中進行 **5 個為什麼分析**，連續追問 5 次「為什麼」，直到根本原因（Root Cause）。
### 範例：戰鬥中 IsZero() 布林危機崩潰分析
* **為什麼1（一問）**：為什麼OnUpdate執行時外掛程式並崩潰UI？
    * *答*：因為在`Renderer.lua:97`對`durationObj:IsZero()`的傳回值進行了直接布林判斷（`if durationObj:IsZero() then`）。
* **為什麼2（二問）**：為什麼 `IsZero()` 會引發崩潰？
* *答*：因為該 `DurationObject` 代表的光環在戰鬥中返回保密限制，其`IsZero()`方法是一個受保護的`Secret Boolean`。
* **為什麼3（三問）**：為什麼受保護的`秘密布爾`不能做布林判斷？
    * *答*：因為魔獸世界 12.x 引擎為了阻止 AddOn 水晶由 API 判定來輔助戰鬥決策，嚴禁在 Lua 中對 Secret Boolean 執行布林芥末指令（Boolean Test）。
* **為什麼4（四問）**：為什麼我們非要在OnUpdate中呼叫`IsZero()`？
    * *回答*：因為戰鬥中`UNIT_AURA`事件會被官方節流，且秘密狀態下我們無法取得剩餘時間以預排調度器，必須在渲染器輪詢該謂詞以便在光環消失時主動恢復圖示。
* **為什麼5（五問/根本原因）**：為什麼之前沒有防護？
* *答*：因為渲染器缺乏對Secret Value的前置檢測與安全包裹，且不知道`IsZero()`的傳回值和是Secret。
* **根本對策**：引入`safeCheckIsZero`，利用`Util.isSecretValue`過濾回傳值，若為Secret則本身進行布林測試。

---

## 2. 魚骨圖 (Ishikawa Diagram) 要因分析模板
在遇到複雜的系統性問題時（例如「一個 ICON 都沒有出現」或「戰鬥高層中 UI 嚴重卡頓」），必須使用魚骨圖從以下五個維度進行分析：
```text
  【人 (Agent)】                   【機 (Client/WoW API)】         【料 (SavedVariables/Data)】
  - 載入順序快取 nil 漏配           - 12.x Secrecy 加密與限制       - 舊 SavedVariables 資料遷移失效
  - 靜態變數被提早快取             - 事件節流與 CLEU 事件停用       - 預設 Alerts 表為空 (WTF遺失)
          \                             \                               \
           \                             \                               \
            --------------------------------------------------------------------> [ 系統異常/Bug ]
           /                             /                               /
          /                             /                               /
  - 戰鬥中 layout 頻繁重排         - 戰鬥中 InCombatLockdown 限制
  - 輪詢 pcall 產生 Heap 垃圾       - 脫戰後 defer 釋放機制
  【法 (Algorithm/邏輯)】          【環 (Environment/戰鬥狀態)】
```
* **人（代理/開發人員）**：AI代理的程式碼載入順序、快速取邏輯、靜態變數使用不當。
* ** 機器 (Client / WoW API)**：魔獸客戶端 API 的行為變更、加密限制、事件節流。
* **資料 (SavedVariables / Data)**：資料庫架構、預設設定檔、在地化字串。
* **法（演算法/邏輯流程）**：演算法費用、迴圈設計、事件註冊、GC垃圾產生率。
* **環（環境/遊戲狀態）**：戰鬥中/非戰鬥中、低FPS、大量Buff特殊恐懼。

---

## 3.對策擬定與評估矩陣（Countermeasure Matrix）

在`implementation_plan.md`中設計複雜方案時，必須提出至少**兩個創業方案**，並以矩陣圖的形式進行量化評分評估（1~5分，5分割最），最終得出一些綜合得分最高者。
### 例：解決戰鬥中秘密倒數問題的對策評估
| 對策方案 | 效果（效果）| 呼吸（呼吸）| 足夠的飢餓 (Low GC/CPU) | 安全風險（低污染/Secret）| 綜合分數 | 決策 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **對策 A：強行利用 Tooltip Scraping 在每幀 OnUpdate 爬取時間** | 2 | 4 | 1 (絕壁字符串GC) | 2（極易被污染）| **9** | 淘汰 |
| **對策B：使用Shadow Host 吸附生吸附官方CooldownViewer** | 5 | 3 | 5（100%避讓佈局）| 4（安全隔離）| **17** | **（採納備用）** |
| **對策 C：AuraService 說明解析 + 渲染器雙軌 IsZero 替代品回收** | 5 | 5 | 4（僅在倒數時輪詢）| 5（利用safeCheck爆炸）| **19** | **最佳採納** |

---

## 4.甘特圖排程與依賴精神（Gantt Spirit）
在 `task.md` 中，必須反映甘特圖的**依賴關係（Dependency）**與**關鍵路徑（Critical Path）**，以防止工具開發的子代理發生「因前置方案碼未就緒而空轉」或「高關聯方案碼衝突」。

### 程排原則：
1. **Dependency Guard (依賴)**：在 `task.md` 中明確標誌依賴關係。例如：
    * `[ ] 任務 C (AuraService 重構) [依賴：任務 A (EventRouter 改版)]`
2. **關鍵路徑優先（關鍵路徑優先）**：將決定架構穩定性（如Core, SavedVariables）的任務排在最前面，與一級審查專家分配最昂貴的資源。
3. **Milestone Gate (里程碑關卡)**：每個階段結束時，必須設定 Milestone 進行品質查核（如：`luac -p`檢查，`/eam doctor`診斷通過），否則無法進入階段。

---

## 5. 新的 QC 七大手段在 EAM 的落地
1. **關係圖法（RelationsDiagram）**：
    * *應用*：釐清EAM內部事件（如`EAM_AURA_STATE_CHANGED`）與WoW事件（如`UNIT_AURA`）之間的因果傳播網絡，防止事件風暴與無限傳回。
2. **系統圖法（Systematic Chart）**：
    * *應用*：將巨集大的重構目標（如「12.1.0 零分配」）分層分層為子模組變更（AuraService池化、CooldownService池化、AlertManager重複、渲染器多型渲染）。
3. ** 矩陣圖法（Matrix Diagram）**：
    * *應用*：即本案已落地的**[Docs/21_RACI_EXPERTS_MATRIX.md](file:///d:/EventAlertMod/Docs/21_RACI_EXPERTS_MATRIX.md)**，用於釐清專家與開發任務的責任對照。
4. **PDPC法 (Process Decision Program Chart / 流程決定計畫畫圖)**：
* *應用*：在程式碼編寫前，預測所有可能的異常路徑（如：官方API返回nil、資料未快取、戰鬥中設定限制），並在程式碼中預先準備`pcall`故障隔離、`safeCheckIsZero`和`Util.isSecretValue`等後備備用對策。
5. **箭條圖法（箭頭圖）**：
* *應用*：理清子代理的工件工作順序，避免多個代理同時寫入同一個文件，確保版本分支的平滑合併。