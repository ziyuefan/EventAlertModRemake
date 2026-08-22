<!-- EAM_DOCUMENTATION_SOURCE: zh-TW -->
# 遷移注意事項

## 舊行為映射

費用保留：

- 取得自我/debuff警報圖示；
- 目標增益/減益警報圖示；
- 動動冷卻時間警報圖示；
- itemID 的工件冷卻圖示；
- 簡單的spellID加入/刪除工作流程；
- `/eam opt` 設定入口點；
- `/eam show`、`/eam showt`、`/eam showc`、`/eam showa`探測流程工作；
- 冷卻行為切換：
  - 冷卻完成後移除；
  - 讓冷卻圖示遠離戰鬥；
- 使用時發光；
- 圖示顯示切換：
  - 顯示框架；
  - 顯示姓名；
  - 顯示計時器；
  - 顯示 flash/glow;
  - 工具提示附加輔助/item ID；
- 名稱、計時器和所在的字體大小控制；
- 小地圖選項按鈕語意；
- 本地化字串，特別是存在的 zhTW、enUS、koKR、zhCN；
- 正式服驗證後可使用預設/物品表。
## 舊 SavedVariables 遷移

舊版輸入：
```lua
EA_Config
EA_Position
EA_Items
EA_AltItems
EA_TarItems
EA_ScdItems
EA_GrpItems
EA_Pos
```
目標遷移：
```js
EventAlertModDB = {
  schemaVersion: 1,
  profile: {
    display: {},
    behavior: {},
    alerts: {
      playerAuras: [],
      targetAuras: [],
      spellCooldowns: [],
      itemCooldowns: [],
      groupAlerts: []
    },
    layout: {}
  },
  migration: {
    fromLegacy: true,
    sourceKeys: [],
    warnings: []
  }
}
```
確信的目標變數名稱被重寫決定。如果舊變數名稱
為了相容性，它們仍然需要架構標記和遷移狀態。

遷移規則：

- 永遠不會凍結遷移的 SavedVariables；
- 模組將運行時狀態儲存在 SavedVariables 中；
- 在遷移安全性互補表下保留未知的遺傳欄位或
  警告名單；
- 驗證spellID/itemID數字欄位；
- 將刪除的唯一經典的欄位記錄為遷移預警；
- 在備份或遷移設定信件策略生效之前不要刪除舊字段
  定義的。

## 刪除舊行為

從Active的正式伺服器架構中刪除：

- Classic、TBC、Wrath、Cata、Mists TOC 和負載根；
- `G.WOW_VERSION` 分支的經典行為；
- 經典API的舊解壓縮傳回相內容層；
- 老獵人寵物幸福/焦點只存在於經典時代的分支
  行為；
- 大量正常運行時物品ID掃描；
- 每個圖示計時器和每個繪圖計時器刷新鏈；
- 工具提示掃描作為正常事實來源；
- 核心操作的外部依賴要求。

## 相容性中斷

預計休息時間：

- 舊的經典目錄不再載入；
- 依賴傳統特定資源的使用者會忽略這些警告；
- 事件腳本/配置可能需要簡化；
- import/export 原型必須重新設計或刪除，除非是簡單的安全
  需要路徑；
- `Lib_ZYF` 助手應該被替換或隔離；不要假設它存在於
  新的核心。

## 本地化遷移

現有的語言環境文件：

- `locale/localization.comm.lua`
- `locale/localization.en.lua`
- `locale/localization.tw.lua`
- `locale/localization.cn.lua`
- `locale/localization.kr.lua`
- `locale/localization.ru.lua`
保持本地化隔離。不要將字串混合到邏輯模組中。請勿添加
簡體中文字串為zhTW。

## 繼承來源處理

目前的舊原始碼保留用於審計/reference：

- `Classic/`
- `TBC/`
- `Wrath/`

它們不應該由 Retail 重寫載入。如果保留在儲存庫中，
將它們標記為已文檔/unsupported。

## 2026-07-26：Aura schema v1 -> v2

- 遷移前保存 `migrationBackups.auraSchemaV1` 的 player/target Aura 純資料。
- 既有 alert 增補 `nativeBackend=AUTO` 與顯示偏好，不移除未知欄位或舊 `EA_*` globals。
- 遷移失敗會還原遷移前可序列化 DB，並記錄靜態 warning code。
- 12.0.7 使用 Legacy backend；12.1 使用 Native 或 Unsupported，不能以 Legacy Secret 掃描補洞。
