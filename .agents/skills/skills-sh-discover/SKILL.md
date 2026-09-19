---
name: skills-sh-discover
description: 搜尋、評估與一鍵安裝 skills.sh (Open Agent Skills Directory) 社群技能包的專用工具。當需要擴充新功能（如特殊框架維護、特定數據庫操作、UI設計指南或軟體測試流程）時調用。
---

# skills.sh Agent Skills 搜尋與安裝 SOP

本 Skill 提供全自動化與互動式的 `skills.sh`（The Agent Skills Directory）檢索與套用流程。

---

## 🔍 一、 搜尋社群技能 (Search Skills)

當使用者提議搜尋某些領域的 Skill，或目前的工具不足以高效完成任務時：

1. **CLI 關鍵字搜尋**：
   執行終端機指令尋找 `skills.sh` 上的熱門技能：
   ```bash
   npx -y skills find <關鍵字>
   ```
   例如：
   - 搜尋 React 相關：`npx -y skills find react`
   - 搜尋 Docker 部署：`npx -y skills find docker`
   - 搜尋 SQLite / Prisma：`npx -y skills find prisma`
   - 指定特定擁有者：`npx -y skills find --owner vercel-labs`

2. **讀取技能詳情與代碼**：
   對於搜尋到的特定熱門技能，可呼叫 `read_url_content` 或 `view_file` 讀取 `https://skills.sh/<owner>/<repo>/<skill-name>` 之內容評估可行性。

---

## 📦 二、 一鍵安裝技能 (Install Skills)

1. **安裝至全域 (Global)**：
   若該技能屬於跨專案通用工具（如 UI 設計指南、通用 Commit 規範）：
   ```bash
   npx -y skills add <owner/repo@skill-name> -g -y
   ```

2. **安裝至當前專案 (Project)**：
   若該技能僅專屬於特定專案（如專屬 Deployment、專屬數據庫微調）：
   ```bash
   npx -y skills add <owner/repo@skill-name> -p -y
   ```

---

## 🛠️ 三、 列表與維護技能 (List & Maintenance)

1. **檢視已安裝之 Skill 列表**：
   ```bash
   npx -y skills list --json
   ```
2. **升級技能至最新版**：
   ```bash
   npx -y skills update
   ```
3. **移除不適用的技能**：
   ```bash
   npx -y skills remove <skill-name> -y
   ```

---

## 🧭 四、 雙軌技能庫協同 (Dual-Warehouse Strategy)

本技能與 `lobehub-skills-discover`（https://lobehub.com/zh-TW/skills）共同組成 Antigravity 官方雙軌技能發現庫：
- **`skills.sh`**：通用工程規範、CLI 工具與開源生態庫。
- **`lobehub.com`**：特化領域深度知識庫（如 WoW API 系列手冊、架構模組與專家級 Agent Skills）。
