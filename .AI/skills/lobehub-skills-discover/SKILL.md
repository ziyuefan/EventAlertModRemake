---
name: lobehub-skills-discover
description: 搜尋、評估與一鍵安裝 LobeHub (https://lobehub.com/zh-TW/skills) 社群開放 Agent Skills 的專用工具。支援依關鍵字檢索、直接下載完整套件（含 references）、讀取 SKILL.md 並快速部署至 Antigravity 全域與專案技能庫。
---

# LobeHub Agent Skills 搜尋與安裝 SOP

本 Skill 提供檢索、評估與安裝 **LobeHub Skills 市集**（https://lobehub.com/zh-TW/skills）開源技能包的完整流程。與 `skills.sh` 並列為 Antigravity 官方雙軌社群技能倉庫。

---

## 🔍 一、 搜尋 LobeHub 技能 (Search Skills)

當任務需要引入新領域技能（如特定 API 手冊、工作流模組、軟體除錯指南）時：

### 1. 網頁端搜尋與檢索
- 搜尋網址：`https://lobehub.com/zh-TW/skills?q=<關鍵字>&page=<頁數>`
- 使用 `read_url_content` 抓取目標搜尋頁，或透過 Python 腳本檢索網頁中的技能標識符（格式通常為 `<owner>-<repo>-<skill-name>` 或自訂 identifier）。

### 2. CLI 檢索（需註冊設備）
- 若本機已透過 `npx -y @lobehub/market-cli register` 註冊：
  ```bash
  npx -y @lobehub/market-cli skills search --q <關鍵字>
  ```

---

## 📖 二、 讀取與評估技能內容 (Inspect & Audit)

在安裝前，需評估該技能之品質、結構與安全性：

1. **直接讀取原始 Markdown**：
   ```text
   https://lobehub.com/skills/<skill-identifier>/skill.md
   ```
   可使用 `read_url_content` 預覽其 YAML frontmatter（`name`、`description`）與規範內文。

2. **安全審查標準**：
   - 檢查是否包含惡意腳本、未經授權的網路傳輸或危險指令。
   - 審查是否符合 Antigravity 技能規範（標準 YAML frontmatter、清晰的調用時機與步驟）。
   - 保留「不予安裝」或「改由本機自訂專屬技能」的選項。

---

## 📦 三、 一鍵下載與安裝技能 (Download & Install)

LobeHub 提供免登入的標準 ZIP 套件下載端點：

```text
https://market.lobehub.com/api/v1/skills/<skill-identifier>/download
```

### 標準安裝 Python 範例：
```python
import urllib.request, zipfile, io, os

skill_id = "<skill-identifier>"
folder_name = "<short-skill-name>" # 提取簡潔名稱或以 skill_id 為名

url = f"https://market.lobehub.com/api/v1/skills/{skill_id}/download"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as resp:
    data = resp.read()

# 同步安裝至全域與專案目錄
targets = [
    os.path.expanduser(rf"~/.gemini/config/skills/{folder_name}"),
    rf".agents/skills/{folder_name}",
    rf".AI/skills/{folder_name}"
]

with zipfile.ZipFile(io.BytesIO(data)) as zf:
    for target in targets:
        os.makedirs(target, exist_ok=True)
        zf.extractall(target)
```

---

## 🧭 四、 雙軌技能倉庫協同原則 (Dual-Warehouse Strategy)

| 倉庫 | 適用情境 | 主要特色 |
| :--- | :--- | :--- |
| **`skills.sh`** | 通用工程流程、前端/後端框架、通用 CLI 工具 | 全球開源生態、`npx -y skills` 命令列高度整合 |
| **`lobehub.com`** | 領域專精手冊（如 WoW API、特化遊戲架構）、結構化多文檔技能包（含完整 references 目錄） | 直覺網頁目錄、內建繁體中文索引、官方 ZIP 打包下載端點 |
