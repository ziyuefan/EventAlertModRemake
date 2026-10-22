---
name: proactive-failure-prediction
description: 強制規定在 EventAlertMod (EAM) 完成任何功能開發、程式碼重構或 Bug 修復後，交付報告必須主動包含四大維度之深度故障預測與威脅推論。
---

# EAM 開發完成主動執行故障預測與威脅推論原則 (Proactive Failure Prediction & Threat Inference)

在 EventAlertMod 專案中，每次完成任何功能開發、程式碼重構或 Bug 修復時，**嚴禁**僅回報「代碼已修改、離線測試通過」即收尾。

在最終交付報告中，必須強制主動執行**深度故障預測與威脅推論**，從魔獸世界正式服極端戰鬥環境、延遲與暴雪底層引擎邊界出發，完整分析以下四大維度：

1. **高機率邊緣異常（High-Probability Edge Cases）**：
   - 法術彈道時間差（如 40 碼長距離冰槍飛行時間超過採樣視窗）。
   - 時序競態與施法延遲（如 GCD 延遲、引導法術提前中斷時序衝突）。
   - 目標狀態突變（如碎冰凍結判定與目標提前解除凍結）。

2. **中機率引擎與視覺邊界異常（Medium-Probability Engine & Visual Anomalies）**：
   - 次像素（Subpixel）外框縫隙與抖動、2K/4K 視窗縮放比例對齊。
   - 音效節流超過暴雪引擎容許上限（如 12.1.5 PTR 4 限制 `throttleSeconds` > 5.0s 拋錯拒絕）。
   - 元表嚴格模式屬性存取崩潰（如 `hasButtonMethod` 探針未防護直接調用未定義方法）。

3. **低機率致命風險（Low-Probability Lethal Risks）**：
   - 戰鬥中 Taint 擴散與受保護 UI 方法調用引發 `ADDON_ACTION_BLOCKED`。
   - 戰鬥中數值為 Secret 時進行 Lua 大小比較崩潰。
   - 狀態物件池（StatePool）洩漏導致長時間遊戲記憶體暴增。

4. **實機排查手法與立即對策指引（Live Troubleshooting & Immediate Mitigation）**：
   - 提供玩家在遊戲內快速驗證（例如木樁距離切換測試、極速連按測試、頻繁切換目標測試）之具體操作與降級排查手法。

## 溝通與格式規範
- 全程保持台灣慣用繁體中文（`zh-TW`）。
- 親切稱呼使用者為「少年欸」。
- 絕不讀取、寫入或存取 `D:\World of Warcraft` 或 `D:\EventAlertMod`。
