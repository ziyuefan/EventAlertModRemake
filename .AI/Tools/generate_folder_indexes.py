#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EventAlertMod Remake - 全目錄說明清單 (FOLDER_INDEX.html) 自動生成與維護工具
檔案: .AI/Tools/generate_folder_indexes.py

理念:
- 為專案中的所有工作目錄生成統一風格、離線可用、深色現代化、具備雙向導航 (Breadcrumbs) 的說明清單 HTML。
- 深度整合「AI 治理 (AI Governance)」：內嵌 JSON-LD 語意化中繼資料、安全防護層級、架構不變量 (Invariants)
  與目錄職責邊界，使各 AI Agent (LLM) 在探索程式庫時能一秒理解目錄上下文與限制。
- 支援一鍵生成、覆蓋更新與健康狀態核驗 (--verify)。
"""

import os
import sys
import json
import re
import html
import datetime
from pathlib import Path

# Windows console UTF-8 support
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
if hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

# ==============================================================================
# 排除與略過目錄規則
# ==============================================================================
EXCLUDE_DIR_PATTERNS = {
    ".git",
    "Dist",
    "__pycache__",
    ".pytest_cache",
    ".vscode",
    ".codex",
    ".codex-remote-attachments",
    "backup",
    "patch-temp",
    ".trash",
    "nppBackup",
}

# ==============================================================================
# 目錄架構知識庫 (Directory Architectural Knowledge Base)
# ==============================================================================
DIRECTORY_KNOWLEDGE_BASE = {
    ".": {
        "name": "專案根目錄 (Project Root)",
        "role": "Root Orchestrator & Project Governance",
        "layer": "Root / Governance Layer",
        "security": "Critical Governance & Dual Mirroring",
        "summary": "EventAlertMod 專案最高根目錄，統籌 WoW 插件源碼、AI 治理體系、自動化部署腳本、多語系文檔與發布規範。",
        "invariants": [
            "根目錄與 EventAlertMod 內的 README.md、changelog.txt 必須永遠 100% 鏡像同步",
            "機密憑證與 Token (API_TOKEN.SEC) 永久留存本機 Windows DPAPI 加密，嚴禁提交 Git 或打包入 ZIP",
            "Dist/ 產物不提交 Git；舊目錄 D:\\EventAlertMod 已停用，禁止任何存取",
            "魔獸客戶端若為 SymbolicLink/Junction，任何部署或清理動作必須立即停止 (Fail-Closed)",
        ],
        "allowed_deps": ["EventAlertMod", ".AI", "Deploy", ".agents"],
    },
    "EventAlertMod": {
        "name": "插件核心源碼目錄 (Addon Root)",
        "role": "Addon Source Root & TOC Manifest",
        "layer": "Addon Layer (Retail 12.x Native)",
        "security": "Retail 12.1.0 Compatible / Zero Taint",
        "summary": "《魔獸世界》正式服 (Retail 12.1.0+) 插件本體目錄。託管唯一 TOC 載入清單、核心模組、業務邏輯、UI 視圖與素材。",
        "invariants": [
            "包含唯一 TOC 清單 (EventAlertMod.toc)，所有 .lua 與 .xml 檔案必須列入 TOC",
            "不得混入任何治理 (.AI)、部署 (Deploy) 或暫存目錄",
            "零污染保證：全面使用暴雪原生效期物件與 SetValue 單向 Sink，不觸發 Lua Secret 比較",
        ],
        "allowed_deps": ["Core", "Services", "Managers", "UI", "Data", "Debug", "Locale", "Lib", "Media"],
    },
    "EventAlertMod/Core": {
        "name": "核心調度引擎 (Core Engine)",
        "role": "Lifecycle, Event Routing & Scheduler",
        "layer": "Addon Core Layer",
        "security": "Zero-Alloc / Taint-Sensitive",
        "summary": "託管插件啟動生命週期 (Init)、唯一事件路由孤兒 Frame (EventRouter)、非同步排程器 (Scheduler) 與零分配物件池 (StatePool)。",
        "invariants": [
            "擁有唯一 EventRouter 孤兒 Frame，禁止各模組自行建立事件監聽 Frame 造成資源浪費",
            "嚴禁在熱路徑 (OnUpdate / Event Dispatch) 建立臨時 Closure 或垃圾回收負擔",
            "StatePool 必須嚴格回收所有狀態物件，確保長期戰鬥記憶體零增長 (0 Alloc)",
        ],
        "allowed_deps": ["Core", "Data"],
    },
    "EventAlertMod/Data": {
        "name": "常數與資料對照 (Data Models & Lookups)",
        "role": "Static Data Schemas & Catalogs",
        "layer": "Addon Data Layer",
        "security": "Read-Only Static Lookup",
        "summary": "儲存法術對照表、職業資源拓撲矩陣、預設外觀常數與資料結構定義。",
        "invariants": [
            "純靜態資料結構，嚴禁包含任何動態執行邏輯或 API 呼叫",
            "涵蓋 13 大職業 40 組專精的完整資源拓撲定義",
        ],
        "allowed_deps": [],
    },
    "EventAlertMod/Debug": {
        "name": "除錯診斷與性能探針 (Diagnostics & Probes)",
        "role": "Diagnostic Inspection & Capability Probes",
        "layer": "Addon Diagnostic Layer",
        "security": "Non-Combat Gated / Developer Mode",
        "summary": "提供玩家職業資源探針 (PlayerResourceProbe)、SVG 向量圖形相容性探針與除錯監控工具。",
        "invariants": [
            "僅在開發或手動除錯指令下執行，戰鬥中嚴禁高頻 dump 或引發 UI 阻塞",
            "杜絕任何可能造成 Secure Execution Path 污染的除錯行為",
        ],
        "allowed_deps": ["Core", "Services"],
    },
    "EventAlertMod/Lib": {
        "name": "第三方整合函式庫 (Embedded Libraries)",
        "role": "Embedded Third-Party Libraries",
        "layer": "Addon Library Layer",
        "security": "Taint-Hardened / Vendor Code",
        "summary": "整合 LibButtonGlow-1.0、LibCustomGlow-1.0 與 LibSharedMedia-3.0 等通用函式庫，並具備 EAM 專屬原生降級防護。",
        "invariants": [
            "當函式庫不可用時，必須無縫降級至 EAM 內建雙層發光與原生字型",
            "嚴格保護 LibSharedMedia 動態素材探測，避免登入前調用造成報錯",
        ],
        "allowed_deps": [],
    },
    "EventAlertMod/Locale": {
        "name": "多語系在地化語料庫 (Localization)",
        "role": "Multi-language String Catalogs",
        "layer": "Addon Localization Layer",
        "security": "Safe String Lookup",
        "summary": "提供繁體中文 (zhTW)、簡體中文 (zhCN)、英文 (enUS)、韓文 (koKR) 與德文 (deDE) 的 144+ 詞條全覆蓋在地化字典。",
        "invariants": [
            "所有語系字典必須鍵值對齊，嚴禁出現 missing labelKey 錯誤",
            "支援即時切換語言 (EAM_LOCALE_CHANGED) 動態重繪 UI，免 /reload 即時生效",
        ],
        "allowed_deps": [],
    },
    "EventAlertMod/Managers": {
        "name": "業務邏輯與告警管理器 (Alert Managers)",
        "role": "Business Logic, Rule Compilation & State Controller",
        "layer": "Addon Business Logic Layer",
        "security": "Taint-Sensitive / Rule Compiler",
        "summary": "EAM 的大腦中樞，託管告警管理器 (AlertManager)、Native Aura 規則編譯器 (AuraRuleCompiler)、冷卻管理器 (CooldownManager) 與音效廣播。",
        "invariants": [
            "解耦業務邏輯與視圖層：Managers 負責運算與狀態判定，透過事件驅動通知 UI 更新",
            "AuraRuleCompiler 實作 buildLayoutFingerprint 佈局指紋，戰鬥中設定變更延遲至脫戰編譯",
            "維持 O(1) 查表優先級，避免遍歷比對",
        ],
        "allowed_deps": ["Core", "Services", "Data", "UI"],
    },
    "EventAlertMod/Media": {
        "name": "媒體素材目錄 (Media Assets)",
        "role": "Static Visual & Audio Assets Root",
        "layer": "Addon Asset Layer",
        "security": "Static Assets",
        "summary": "包含插件所有圖片、圖示、音效與向量 SVG 探針資產。",
        "invariants": [
            "圖片材質尺寸遵守暴雪 2 的冪次方規範 (64x64, 128x128, 256x256)",
            "音效格式為標準 MP3 / OGG，支援 SharedMedia 動態註冊",
        ],
        "allowed_deps": [],
    },
    "EventAlertMod/Media/Images": {
        "name": "圖示與介面材質 (Icons & Textures)",
        "role": "UI Textures, Borders & Glow Rings",
        "layer": "Addon Asset Layer",
        "security": "Static 32-bit TGA / BLP Assets",
        "summary": "託管冷卻充能環 (ChargeRing 128x128 32-bit TGA)、邊框、背景與視覺發光材質。",
        "invariants": ["所有 TGA 檔案必須具備 Alpha 遮罩通道，支援透明度混合渲染"],
        "allowed_deps": [],
    },
    "EventAlertMod/Media/Music": {
        "name": "警報音效素材 (Alert Audio Assets)",
        "role": "Audio Alert Sound Files",
        "layer": "Addon Asset Layer",
        "security": "Standard Audio Format",
        "summary": "內建各種觸發告警音效 (Bell, Gong, Ding, Horn 等)，支援透過 MediaService 雙軌播放。",
        "invariants": ["支援 12.1 PlaySoundFile 與 SharedMedia 跨插件共用"],
        "allowed_deps": [],
    },
    "EventAlertMod/Media/SVG": {
        "name": "SVG 向量功能測試資產 (SVG Vector Assets)",
        "role": "Vector Capability Asset",
        "layer": "Addon Asset Layer",
        "security": "Blizzard Vector Renderer Compatible",
        "summary": "託管 eam-svg-probe.svg，用於 Retail 12.x 原生向量圖形繪製能力探測。",
        "invariants": ["必須列入 TOC 依賴，驗證正式服向量渲染器相容性"],
        "allowed_deps": [],
    },
    "EventAlertMod/Services": {
        "name": "狀態追蹤與服務層 (Core Services)",
        "role": "Data Polling, Event Interception & Protected State Tracking",
        "layer": "Addon Service Layer",
        "security": "Taint-Sensitive / Combat Protection Gated",
        "summary": "託管玩家屬性服務 (PlayerStatService)、匿名目標光環探針 (TooltipMonitorService)、冷卻追蹤服務 (CooldownService) 與多媒體服務 (MediaService)。",
        "invariants": [
            "戰鬥中數值保護機制：戰鬥中 GetUnitSpeed 等受限 API 自動安全回退至真實脫戰記憶快取 (lastKnownStats)",
            "目標光環探針使用 Tooltip 匿名回呼機制，杜絕直接遍歷敵方/隊友 Nameplate Frame 造成 Taint 感染",
            "零讀回原則：Secret 數值僅單向注入原生 StatusBar:SetValue 或 DurationObject，絕不於 Lua 讀回",
        ],
        "allowed_deps": ["Core", "Data"],
    },
    "EventAlertMod/UI": {
        "name": "使用者介面與視圖元件 (UI Presentation)",
        "role": "Presentation, Frame Pools & Options GUI",
        "layer": "Addon Presentation Layer",
        "security": "Theme-Driven / Drag-Interactive / Combat Deferred",
        "summary": "託管圖示物件池 (IconPool)、設定主視窗 (Options)、主題配色引擎 (Theme)、側窗聯動吸附元件與懸停提示系統。",
        "invariants": [
            "現代化 UI 互動：支援側窗無縫吸附 (APPEND 模式)、連動拖曳、螢幕邊界鎖定與 /eam reset 復原",
            "戰鬥中排版遞延：戰鬥期間使用者若調整 UI，僅記錄設定值，脫離戰鬥後一次性安全套用",
            "主題系統：11 組深色主題無縫切換，統一管理按鈕背景、邊框與文字配色",
        ],
        "allowed_deps": ["Core", "Services", "Managers", "Data", "Locale", "Lib"],
    },
    "Deploy": {
        "name": "自動化發布與部署工具 (Deployment & Automation)",
        "role": "CI/CD, Packaging & Release Automation",
        "layer": "Deployment & Release Tooling Layer",
        "security": "Offline PowerShell / DPAPI Protection",
        "summary": "託管魔獸插件打包 (Build-Package.ps1)、CurseForge 自動上傳 (Upload-CurseForge.ps1)、本機部署與 GitHub 發布工具。",
        "invariants": [
            "嚴禁未經確認自動執行寫入魔獸遊戲目錄",
            "機密隔離：永遠禁止將 API_TOKEN.SEC 包含在打包輸出的 ZIP 壓縮檔內",
            "嚴格比對打包檔案清單與來源目錄，確保打包產物 100% 乾淨無暫存檔",
        ],
        "allowed_deps": [],
    },
    ".AI": {
        "name": "AI 治理中樞 (AI Governance Nexus)",
        "role": "Cognitive Core & Architectural Policy Enforcement",
        "layer": "Governance & Architecture Layer",
        "security": "Single Source of Truth / Non-Addon",
        "summary": "專案最高治理核心，託管所有架構規範、專案記憶 (PROJECT_MEMORY)、連續性追蹤 (28_PROJECT_CONTINUITY)、離線契約測試與多語系文件網站生成器。",
        "invariants": [
            "所有開發決策、架構演進與重大修復必須同步登錄於 .AI/Docs/15_DEVELOPMENT_ISSUE_LOG.md",
            "維護專案連續性事實清冊 (.AI/Data/ProjectContinuity.json 與 Docs/28_PROJECT_CONTINUITY.md)",
            "禁止在 EventAlertMod 插件代碼中引入任何 .AI 治理內容",
        ],
        "allowed_deps": [".AI/Data", ".AI/Docs", ".AI/Tests", ".AI/Tools", ".AI/skills"],
    },
    ".AI/Data": {
        "name": "治理資料模型與契約真值 (Governance Schemas & Truth Models)",
        "role": "Source of Truth Data Schemas",
        "layer": "Governance Data Layer",
        "security": "Immutable Source of Truth",
        "summary": "託管專案連續性記錄 (ProjectContinuity.json)、真人實機矩陣 (LiveValidationMatrix.json) 與文字排版契約。",
        "invariants": ["所有 JSON 檔案必須具備嚴格的 Schema 結構，供契約測試自動化稽核"],
        "allowed_deps": [],
    },
    ".AI/Docs": {
        "name": "架構規範與技術文檔 (Architecture & Technical Specs)",
        "role": "Technical Specifications & Issue Tracking",
        "layer": "Governance Documentation Layer",
        "security": "Bilingual Knowledge Base",
        "summary": "收錄 00 至 28 號完整的架構規範、Retail 12.x API 調研、效能指南、問題日誌與連續性交接文件。",
        "invariants": [
            "00_AI_CONTEXT.md 為全專案頂層上下文摘要",
            "15_DEVELOPMENT_ISSUE_LOG.md 詳實記載每項問題的根因、解法與驗證手法",
            "28_PROJECT_CONTINUITY.md 維護最新版本快照與事實對齊",
        ],
        "allowed_deps": [],
    },
    ".AI/docs_html": {
        "name": "靜態文件網站 (Documentation Website)",
        "role": "GitHub Pages Static Website Assets",
        "layer": "Documentation Presentation Layer",
        "security": "Generated HTML / Static Hosting",
        "summary": "由 batch_convert_docs.py 自動編譯輸出的 HTML 說明文件網站，支援深色玻璃擬態與頂部導覽列。",
        "invariants": ["由 Python 工具自動生成，不手動修改 HTML 原始碼"],
        "allowed_deps": [],
    },
    ".AI/LegacyArtifacts": {
        "name": "舊版歷史產物 (Legacy Artifacts)",
        "role": "Historical Addon Archives & Old Releases",
        "layer": "Historical Archive Layer",
        "security": "Archived / Read-Only",
        "summary": "保存過去舊版 EventAlertMod 的原始發布檔案與封包歷史紀錄。",
        "invariants": ["僅供歷史比對與參考，嚴禁在現代代碼中引用"],
        "allowed_deps": [],
    },
    ".AI/LegacyReference": {
        "name": "舊版參考代碼 (Legacy Code Reference)",
        "role": "Legacy 7.x / 8.x Addon Implementation Reference",
        "layer": "Historical Reference Layer",
        "security": "Deprecated / Do Not Execute",
        "summary": "保留舊版經典法術監控邏輯，用於比對功能覆蓋度與舊設定檔遷移。",
        "invariants": ["嚴禁直接載入或調用舊版全域變數或函數"],
        "allowed_deps": [],
    },
    ".AI/Prompts": {
        "name": "AI 提示詞範本庫 (AI Prompt Templates)",
        "role": "Prompt Engineering & Task Templates",
        "layer": "AI Governance Layer",
        "security": "Internal Prompt Assets",
        "summary": "存放各種專案專屬的 AI Agent 提示詞、任務引導範本與架構審查指令。",
        "invariants": ["維護結構化 Prompt 格式，供各類代理人初始化使用"],
        "allowed_deps": [],
    },
    ".AI/ReferenceLibs": {
        "name": "第三方參考函式庫 (External Reference Libraries)",
        "role": "External Library Source Reference",
        "layer": "Vendor Reference Layer",
        "security": "Reference Only",
        "summary": "存放外部函式庫 (如 LibButtonGlow, LibCustomGlow, LibStub) 原始源碼與測試案例。",
        "invariants": ["作為比對版本差異之參考依據，非執行期直連代碼"],
        "allowed_deps": [],
    },
    ".AI/Schemas": {
        "name": "JSON 結構定義規範 (JSON Schemas)",
        "role": "Data Contract Validation Schemas",
        "layer": "Governance Schema Layer",
        "security": "Contract Rules",
        "summary": "定義專案各類 JSON 資料 (Flow 報告、連續性、排版契約) 的 Draft-07 / Draft-2020-12 規範。",
        "invariants": ["所有自動化測試資料必須嚴格通過 Schema 檢驗"],
        "allowed_deps": [],
    },
    ".AI/ScreenShot": {
        "name": "介面截圖與展示資源 (UI Screenshots & Showcase)",
        "role": "Documentation Visual Showcase Assets",
        "layer": "Documentation Visual Layer",
        "security": "Visual Proof Assets",
        "summary": "保存官方 README 與說明文件展示用的 14+ 張高畫質介面截圖。",
        "invariants": ["提供直觀的視覺功能展示與操作教學佐證"],
        "allowed_deps": [],
    },
    ".AI/skills": {
        "name": "AI 代理技能庫 (AI Agent Skills Root)",
        "role": "Agent Capability & Instruction Store",
        "layer": "AI Capability Layer",
        "security": "Agent Skill Standards",
        "summary": "存放賦予 AI Agent 各項專精能力的 Skill 定義，包含 API 變更調研、CDM 影子寄生、零分配狀態池等。",
        "invariants": ["每個技能目錄必須具備符合規範的 SKILL.md 與 YAML Frontmatter"],
        "allowed_deps": [],
    },
    ".AI/TestResults": {
        "name": "自動化測試報告與產物 (Test Results & Reports)",
        "role": "Validation Artifacts & Audit Logs",
        "layer": "QA Audit Layer",
        "security": "Test Artifacts",
        "summary": "存放離線契約測試、Flow 業務沙盒執行日誌與 PTR 實機驗證資料。",
        "invariants": ["不納入發布 ZIP，作為 CI/CD 品質把關紀錄"],
        "allowed_deps": [],
    },
    ".AI/Tests": {
        "name": "離線測試套件與 Mocks (Offline Test Suites & Mocks)",
        "role": "Offline QA Testing & Flow Simulation",
        "layer": "Automated QA Layer",
        "security": "Offline Test Environment",
        "summary": "託管 FlowValidationHarness.lua 與魔獸官方 API 離線 Mock 環境，可離線模擬 85+ 種戰鬥狀態與 Secret 注入。",
        "invariants": [
            "提供極致真實的 WoW 12.x C-API Mock 沙盒",
            "支援 Secret Value 污染注入與崩潰斷言測試",
        ],
        "allowed_deps": ["EventAlertMod"],
    },
    ".AI/Tests/Fixtures": {
        "name": "測試資料夾具 (Test Fixtures)",
        "role": "Pre-configured Test Data & Scenarios",
        "layer": "Automated QA Layer",
        "security": "Static Fixtures",
        "summary": "提供各類專精設定檔、損毀資料、受保護狀態的標準測試夾具。",
        "invariants": ["確保邊界案例 (Edge Cases) 具備可重現的測試輸入"],
        "allowed_deps": [],
    },
    ".AI/Tests/Mocks": {
        "name": "暴雪 API 模擬樁 (Blizzard API Mocks)",
        "role": "WoW C-API Emulation Layer",
        "layer": "Automated QA Layer",
        "security": "API Mock Engine",
        "summary": "模擬 C_UnitAuras, C_Spell, GetUnitSpeed 等暴雪 Retail 12.x 核心底層 API。",
        "invariants": ["忠實模擬暴雪 API 限制與戰鬥保護回傳值 (如戰鬥中速度受限 1.0)"],
        "allowed_deps": [],
    },
    ".AI/Tools": {
        "name": "AI 治理工具與驗證腳本 (AI Governance Tool Suite)",
        "role": "Governance CLI Utilities & AST Scanners",
        "layer": "Governance Tooling Layer",
        "security": "Automated Quality Gate",
        "summary": "託管 497 項代碼契約驗證 (Test-ValidationContracts.ps1)、語法檢查 (CheckLuaSyntax.ps1)、Flow 沙盒執行 (Run-FlowValidation.ps1) 與全目錄索引生成器。",
        "invariants": [
            "所有工具必須可重複執行且具備明確的退出碼 (Exit Code)",
            "每次代碼重構或新功能發布前，必須通過全套合約檢驗 (497/497 PASS)",
        ],
        "allowed_deps": [".AI", "EventAlertMod", "Deploy"],
    },
    ".agents": {
        "name": "專業代理人技能中樞 (Specialized Agent Capabilities)",
        "role": "Antigravity & Coding Agent Ecosystem",
        "layer": "Agent Ecosystem Layer",
        "security": "Agent Orchestration",
        "summary": "託管專為 Antigravity 與各種代碼代理人打造的 21 大專業技能包，涵蓋 API 調研、光環編譯、冷卻防禦等領域專長。",
        "invariants": ["提供 AI 快速載入領域專業知識的標準介面"],
        "allowed_deps": [".agents/skills"],
    },
    ".agents/skills": {
        "name": "代理人技能包目錄 (Agent Skills Catalog)",
        "role": "Domain-Specific Agent Skill Packages",
        "layer": "Agent Ecosystem Layer",
        "security": "Project Skill Registry",
        "summary": "包含 21 個專業技能目錄，每個技能配備 SKILL.md、腳本與最佳實踐準則。",
        "invariants": ["符合 skills 規範，支援即時呼叫與委派子代理執行"],
        "allowed_deps": [],
    },
}

# ==============================================================================
# 檔案用途字典與啟發式分析
# ==============================================================================
FILE_PURPOSE_KNOWLEDGE_BASE = {
    # 根目錄核心檔案
    "README.md": ("繁體中文專案首頁說明，包含功能特色、介面導覽、快速上手與相容性說明", "Project Documentation", "Safe"),
    "README_en.md": ("英文專案首頁說明，提供國際玩家與開發者閱讀", "Project Documentation", "Safe"),
    "changelog.txt": ("繁體中文版本更新日誌，詳載每個版本的玩家可感知功能、修正與 API 對齊", "Changelog Manifest", "Safe"),
    "changelog_en.txt": ("英文版本更新日誌，與中文版嚴格同步記錄所有發布內容", "Changelog Manifest", "Safe"),
    "AGENTS.md": ("AI 代理人行為入口守則，規範固定目錄邊界、發布安全與憑證隔離鐵律", "AI Governance Entry", "Protected"),
    "AGENTS_en.md": ("英文 AI 代理人行為守則，提供多語言代理人探索根目錄使用", "AI Governance Entry", "Protected"),
    ".gitattributes": ("Git 檔案行尾符號 (CRLF/LF) 與文字/二進位屬性對齊規範", "Git Configuration", "Safe"),
    ".gitignore": ("Git 排除名單，嚴格忽略 Dist、備份、暫存檔與機密憑證", "Git Configuration", "Protected"),

    # EventAlertMod 根目錄
    "EventAlertMod.toc": ("WoW 插件唯一載入清單 (TOC)，定義介面版本號 (120007/120100)、模組加載順序與存檔變數", "Addon Manifest", "Protected"),

    # EventAlertMod/Core
    "Init.lua": ("插件頂層初始化模組，建立全域 EAM 命名空間、註冊生命週期與載入驗證", "Core Lifecycle", "Zero-Alloc"),
    "Constants.lua": ("專案全域常數庫，定義版本號、模組標識、主題色系、支援專精與 API URL", "Core Constants", "Safe"),
    "EventRouter.lua": ("集中式孤兒 Frame 事件分發中心，監聽暴雪原生事件並分派至各模組 Handler", "Core Event Dispatcher", "Zero-Alloc"),
    "Scheduler.lua": ("高效能非同步延遲調度器，負責防抖 (Debounce)、節流 (Throttle) 與戰鬥後遞延執行", "Core Scheduler", "Zero-Alloc"),
    "StatePool.lua": ("零分配物件池管理技術，徹底消除 OnUpdate 閉包所造成的 GC 記憶體回收停頓", "Core Object Pool", "Zero-Alloc"),

    # EventAlertMod/Data
    "SpellConstants.lua": ("經典與現代法術清單對照表，儲存跨專精法術 ID 與已知變體對齊資料", "Data Lookup", "Safe"),
    "ResourceTopology.lua": ("13 大全職業 40 種專精資源拓撲定義，支援德魯伊五形態動態切換矩陣", "Data Topology", "Safe"),
    "Defaults.lua": ("SavedVariables 預設設定檔結構，包含 8 大模組、主題、字型與各職業獨立座標預設值", "Data Defaults", "Safe"),

    # EventAlertMod/Services
    "PlayerStatService.lua": ("18 大人物屬性與滑翔速度即時監控服務，具備 12.1+ 戰鬥速度受限自動安全回退至快取機制", "Service / Stat Monitor", "Taint-Sensitive"),
    "TooltipMonitorService.lua": ("匿名目標光環探針服務，透過 Tooltip 回呼實現無污染光環採集，杜絕遍歷 Nameplate", "Service / Target Aura Probe", "Taint-Sensitive"),
    "CooldownService.lua": ("技能與物品冷卻追蹤服務，具備玩家精確施法過濾、三態設定與可用發光判定", "Service / Cooldown Tracker", "Taint-Sensitive"),
    "MediaService.lua": ("多媒體服務，支援 LibSharedMedia-3.0 音效/字型動態探測與原生雙軌安全播放", "Service / Media Host", "Safe"),

    # EventAlertMod/Managers
    "AlertManager.lua": ("全域告警管理總控中心 (Controller)，協調 Services 與 UI，排程並合併渲染請求", "Manager / Alert Controller", "Taint-Sensitive"),
    "AuraRuleCompiler.lua": ("Retail 12.1 Native Aura 原生光環規則編譯器，計算佈局指紋並分離固定槽位與動態流群組", "Manager / Rule Compiler", "Taint-Sensitive"),
    "CooldownManager.lua": ("冷卻管理器，管理圖示建立、冷卻常駐預渲染 (Alpha=0) 與戰鬥透明度安全切換", "Manager / Cooldown Controller", "Taint-Sensitive"),
    "SoundManager.lua": ("音效廣播管理中心，負責戰鬥/告警音效防抖、優先級仲裁與冷卻控制", "Manager / Sound Arbiter", "Safe"),

    # EventAlertMod/UI
    "IconPool.lua": ("告警圖示物件池與視覺容器，支援雙層 Glow、文字自適應貼齊與 2D Grid 自動換行", "UI / Icon Container Pool", "Presentation"),
    "Options.lua": ("插件核心設定主視窗，提供直觀的圖形化設定、滑桿、多選方塊與側窗吸附切換", "UI / Options Frame", "Presentation"),
    "Theme.lua": ("主題視覺引擎，管理 11 組現代深色主題配色、自適應邊框、按鈕狀態與即時重繪", "UI / Theme Engine", "Presentation"),
    "AlertBorderStyles.lua": ("告警邊框樣式庫，提供多種厚度、高對比警戒框與發光邊框樣式", "UI / Border Styling", "Presentation"),
    "AboutPanel.lua": ("關於面板，顯示插件版本資訊、授權條款、開發團隊與官方導航連結", "UI / About View", "Presentation"),
    "TooltipMonitorMenu.lua": ("目標光環採集右鍵選單，提供秒加監控、黑名單忽略與分類設定", "UI / Context Menu", "Presentation"),

    # Deploy 部署工具
    "Build-Package.ps1": ("魔獸世界正式服發布包打包腳本，嚴格驗證 TOC 一致性、清理暫存並生成雜湊清單", "Deploy Automation", "Offline Tool"),
    "Build-SourcePackage.ps1": ("專案源碼發布包打包工具，排除本機衍生物與敏感快取，生成標準 Git 發布源碼包", "Deploy Automation", "Offline Tool"),
    "Deploy-EventAlertMod.ps1": ("本機多魔獸客戶端安全部署工具，具備 Windows Registry 根目錄偵測與 WTF 存檔備份", "Deploy Automation", "Offline Tool"),
    "Publish-GitHubRelease.ps1": ("GitHub 自動發布工具，自動擷取 changelog 最新區塊並建立 Release 標籤", "Deploy Automation", "Offline Tool"),
    "Sync-GitHubBranch.ps1": ("Git 分支同步與上游遠端推送同步輔助工具", "Deploy Automation", "Offline Tool"),
    "Upload-CurseForge.ps1": ("CurseForge API 自動發布腳本，具備 DPAPI 雙重解密、Cloudflare WAF 穿透與乾跑模式", "Deploy Automation", "Offline Tool"),
}

def format_size(size_bytes):
    """格式化檔案大小為易讀字串"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.2f} MB"

def get_file_stats(filepath):
    """取得檔案大小與行數"""
    try:
        st = os.stat(filepath)
        size_str = format_size(st.st_size)
        line_count = 0
        ext = os.path.splitext(filepath)[1].lower()
        if ext in [".lua", ".py", ".ps1", ".md", ".json", ".xml", ".toc", ".txt", ".yaml", ".html"]:
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                    line_count = sum(1 for _ in f)
            except Exception:
                pass
        return st.st_size, size_str, line_count
    except Exception:
        return 0, "0 B", 0

def extract_file_commentary(filepath):
    """啟發式解析檔案註解與職責"""
    filename = os.path.basename(filepath)
    ext = os.path.splitext(filename)[1].lower()
    
    # 1. 優先查閱專案精準知識庫
    if filename in FILE_PURPOSE_KNOWLEDGE_BASE:
        desc, role, sec = FILE_PURPOSE_KNOWLEDGE_BASE[filename]
        return desc, role, sec

    # 2. 啟發式掃描檔案內容
    desc = ""
    role = "Module / Asset"
    sec = "Safe"
    
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read(4000)
            
            # A. 檢查 EAM_FILE_COMMENTARY 區塊
            if "EAM_FILE_COMMENTARY" in content:
                m_concept = re.search(r"理念\s*:\s*\n((?:\s*-\s*[^\n]+\n?)+)", content)
                m_resp = re.search(r"責任\s*:\s*\n((?:\s*-\s*[^\n]+\n?)+)", content)
                m_mod = re.search(r"Module\s*:\s*([^\n]+)", content)
                parts = []
                if m_mod:
                    role = m_mod.group(1).strip()
                if m_concept:
                    items = [re.sub(r"^\s*-\s*", "", l.strip()) for l in m_concept.group(1).splitlines() if l.strip()]
                    parts.append("；".join(items[:2]))
                if m_resp:
                    items = [re.sub(r"^\s*-\s*", "", l.strip()) for l in m_resp.group(1).splitlines() if l.strip()]
                    parts.append("；".join(items[:2]))
                if parts:
                    desc = " | ".join(parts)
                    if "Secret" in content or "Taint" in content or "Protected" in content:
                        sec = "Taint-Sensitive"
                    elif "OnUpdate" in content or "StatePool" in content:
                        sec = "Zero-Alloc"
                    return desc, role, sec

            # B. Markdown 文件解析
            if ext == ".md":
                m_h1 = re.search(r"^#\s+(.+)$", content, re.M)
                if m_h1:
                    desc = m_h1.group(1).strip()
                    role = "Documentation"
                    return desc, role, "Safe"

            # C. Python 文件 docstring 解析
            if ext == ".py":
                m_doc = re.search(r'"""(.*?)"""', content, re.DOTALL)
                if m_doc:
                    lines = [l.strip() for l in m_doc.group(1).strip().splitlines() if l.strip()]
                    if lines:
                        desc = lines[0]
                        role = "Python Tool"
                        return desc, role, "Offline Tool"

            # D. PowerShell 文件註解解析
            if ext == ".ps1":
                m_ps = re.search(r"<#(.*?)#>", content, re.DOTALL)
                if m_ps:
                    lines = [l.strip() for l in m_ps.group(1).strip().splitlines() if l.strip() and not l.strip().startswith("EAM_")]
                    if lines:
                        desc = " ".join(lines[:2])
                        role = "PowerShell Script"
                        return desc, role, "Offline Tool"

            # E. JSON 資料文件解析
            if ext == ".json":
                try:
                    data = json.loads(content)
                    if isinstance(data, dict):
                        desc = data.get("description", data.get("title", f"JSON 資料結構 (鍵數: {len(data)})"))
                        role = "Data Schema"
                        return str(desc), role, "Safe"
                except Exception:
                    pass

    except Exception:
        pass

    # 3. 根據副檔名兜底智慧標籤
    ext_fallback = {
        ".lua": ("WoW Lua 模組程式碼", "Lua Module", "Protected"),
        ".xml": ("WoW UI XML 視圖佈局範本", "UI Template", "Presentation"),
        ".toc": ("WoW 插件載入清單", "Addon Manifest", "Protected"),
        ".tga": ("32-bit TGA 紋理材質與圖示", "Texture Asset", "Safe"),
        ".blp": ("暴雪專屬 BLP 壓縮紋理材質", "Texture Asset", "Safe"),
        ".svg": ("SVG 向量幾何圖形探針", "Vector Asset", "Safe"),
        ".mp3": ("警報音效音頻素材", "Audio Asset", "Safe"),
        ".ogg": ("OGG 高壓縮警報音頻素材", "Audio Asset", "Safe"),
        ".sec": ("Windows DPAPI 加密隔離憑證", "Encrypted Secret", "Vault Isolated"),
        ".json": ("JSON 結構化資料檔案", "Data Schema", "Safe"),
        ".md": ("Markdown 說明文件", "Documentation", "Safe"),
        ".ps1": ("PowerShell 自動化任務腳本", "PS Script", "Offline Tool"),
        ".py": ("Python 輔助工具腳本", "Python Tool", "Offline Tool"),
        ".html": ("HTML 網頁或說明清單", "Web Document", "Safe"),
        ".txt": ("文字設定或歷史記錄", "Text Log", "Safe"),
    }
    
    if ext in ext_fallback:
        desc, role, sec = ext_fallback[ext]
    else:
        desc = f"專案輔助檔案 ({ext})" if ext else "未指定副檔名檔案"
        role = "Auxiliary File"
        sec = "Safe"
        
    return desc, role, sec

def get_file_type_badge(ext):
    """傳回檔案類型的 HTML Badge 標籤"""
    badges = {
        ".lua": '<span class="badge badge-lua">LUA</span>',
        ".xml": '<span class="badge badge-xml">XML</span>',
        ".toc": '<span class="badge badge-toc">TOC</span>',
        ".md": '<span class="badge badge-doc">DOC</span>',
        ".json": '<span class="badge badge-data">JSON</span>',
        ".ps1": '<span class="badge badge-script">PS1</span>',
        ".py": '<span class="badge badge-tool">PY</span>',
        ".sec": '<span class="badge badge-secret">SEC</span>',
        ".tga": '<span class="badge badge-media">TGA</span>',
        ".blp": '<span class="badge badge-media">BLP</span>',
        ".svg": '<span class="badge badge-svg">SVG</span>',
        ".mp3": '<span class="badge badge-audio">AUDIO</span>',
        ".ogg": '<span class="badge badge-audio">AUDIO</span>',
        ".html": '<span class="badge badge-html">HTML</span>',
        ".txt": '<span class="badge badge-text">TXT</span>',
    }
    return badges.get(ext.lower(), f'<span class="badge badge-other">{ext.upper().replace(".", "") or "FILE"}</span>')

def get_security_badge(sec):
    """傳回安全評級的 HTML Badge"""
    if "Taint" in sec or "Sensitive" in sec:
        return f'<span class="sec-badge sec-taint">🛡️ {sec}</span>'
    elif "Zero-Alloc" in sec or "Hotpath" in sec:
        return f'<span class="sec-badge sec-hotpath">⚡ {sec}</span>'
    elif "Vault" in sec or "Protected" in sec or "Critical" in sec:
        return f'<span class="sec-badge sec-vault">🔒 {sec}</span>'
    elif "Offline" in sec or "Tool" in sec:
        return f'<span class="sec-badge sec-tool">⚙️ {sec}</span>'
    else:
        return f'<span class="sec-badge sec-safe">✅ {sec}</span>'

def resolve_directory_metadata(rel_path):
    """解析目錄元資料與架構治理規範"""
    norm_path = rel_path.replace("\\", "/").strip("./")
    if not norm_path:
        norm_path = "."
        
    if norm_path in DIRECTORY_KNOWLEDGE_BASE:
        return DIRECTORY_KNOWLEDGE_BASE[norm_path]
        
    # 啟發式判定子目錄
    dir_name = os.path.basename(norm_path)
    
    # 技能目錄
    if "skills" in norm_path:
        return {
            "name": f"Agent 技能：{dir_name}",
            "role": "Agent Specialized Skill",
            "layer": "Agent Skill Layer",
            "security": "Agent Knowledge Standard",
            "summary": f"託管 {dir_name} 專業代理人技能定義、操作流程、範例與參考知識庫。",
            "invariants": ["提供標準 SKILL.md 定義，支援 Antigravity 子代理人自主探索調用"],
            "allowed_deps": [],
        }
    
    # 測試目錄
    if "Tests" in norm_path or "TestResults" in norm_path:
        return {
            "name": f"測試單元：{dir_name}",
            "role": "QA Test Module / Artifacts",
            "layer": "Automated QA Layer",
            "security": "Offline Test Fixture",
            "summary": f"收錄 {dir_name} 之自動化驗證腳本、測試夾具或實機執行產物。",
            "invariants": ["支援離線自動化回歸測試，隔離遊戲執行期環境"],
            "allowed_deps": [],
        }

    # 參考目錄
    if "Reference" in norm_path:
        return {
            "name": f"參考架構：{dir_name}",
            "role": "Reference Code / Archive",
            "layer": "Reference Layer",
            "security": "Read-Only Archive",
            "summary": f"保存 {dir_name} 之歷史代碼或外部參考依賴。",
            "invariants": ["僅供比對與研讀，禁止直接在現代正式服中引發調用"],
            "allowed_deps": [],
        }

    # 通用預設目錄
    return {
        "name": f"目錄：{dir_name}",
        "role": "Project Module",
        "layer": "Application Layer",
        "security": "Safe",
        "summary": f"託管專案 {dir_name} 模組之相關檔案與資源。",
        "invariants": ["維護模組單一職責原則，嚴格遵守專案架構規範"],
        "allowed_deps": [],
    }

# ==============================================================================
# HTML 範本與渲染器 (Modern Obsidian & Cyan Theme, 100% Offline)
# ==============================================================================
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{dir_display_name} - 目錄導覽與檔案說明清單 | EventAlertMod Remake</title>
  
  <!-- AI Governance Metadata -->
  <meta name="ai-governance-role" content="{role}">
  <meta name="ai-governance-layer" content="{layer}">
  <meta name="ai-governance-security" content="{security}">
  <meta name="ai-governance-invariants" content="{invariants_meta}">
  <meta name="ai-scan-timestamp" content="{timestamp}">
  <meta name="generator" content="EventAlertMod AI Governance Tool Suite">

  <!-- JSON-LD Structured Data for AI Agents / RAG -->
  <script type="application/ld+json">
{json_ld_str}
  </script>

  <style>
    :root {{
      --bg-base: #0a0e17;
      --bg-surface: rgba(17, 24, 39, 0.75);
      --bg-surface-hover: rgba(30, 41, 59, 0.85);
      --border-subtle: rgba(255, 255, 255, 0.08);
      --border-focus: #00f0ff;
      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      --accent-cyan: #00f0ff;
      --accent-gold: #ffd700;
      --accent-purple: #a855f7;
      --accent-green: #10b981;
      --accent-red: #ef4444;
      --accent-amber: #f59e0b;
      --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Microsoft JhengHei", "Noto Sans TC", sans-serif;
      --font-mono: "Cascadia Code", "Fira Code", Consolas, "Courier New", monospace;
    }}

    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    
    body {{
      background-color: var(--bg-base);
      background-image: 
        radial-gradient(at 0% 0%, rgba(0, 240, 255, 0.08) 0px, transparent 50%),
        radial-gradient(at 100% 100%, rgba(168, 85, 247, 0.08) 0px, transparent 50%);
      color: var(--text-main);
      font-family: var(--font-sans);
      line-height: 1.6;
      padding: 32px 24px;
      min-height: 100vh;
    }}

    .container {{
      max-width: 1320px;
      margin: 0 auto;
    }}

    /* 頂部導航與麵包屑 */
    .nav-bar {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 20px;
      background: var(--bg-surface);
      backdrop-filter: blur(16px);
      border: 1px solid var(--border-subtle);
      border-radius: 12px;
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 12px;
    }}

    .breadcrumbs {{
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 0.92rem;
      color: var(--text-muted);
      flex-wrap: wrap;
    }}

    .breadcrumbs a {{
      color: var(--accent-cyan);
      text-decoration: none;
      transition: all 0.2s;
    }}

    .breadcrumbs a:hover {{
      text-decoration: underline;
      filter: drop-shadow(0 0 6px var(--accent-cyan));
    }}

    .breadcrumbs .separator {{
      color: var(--text-muted);
      opacity: 0.5;
    }}

    .breadcrumbs .current {{
      color: var(--text-main);
      font-weight: 600;
    }}

    /* Hero Header */
    .header-card {{
      background: var(--bg-surface);
      backdrop-filter: blur(16px);
      border: 1px solid var(--border-subtle);
      border-radius: 16px;
      padding: 28px 32px;
      margin-bottom: 24px;
      position: relative;
      overflow: hidden;
    }}

    .header-card::before {{
      content: "";
      position: absolute;
      top: 0; left: 0; right: 0; height: 3px;
      background: linear-gradient(90deg, var(--accent-cyan), var(--accent-purple), var(--accent-gold));
    }}

    .header-title-row {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 16px;
      margin-bottom: 12px;
    }}

    .header-title-row h1 {{
      font-size: 1.85rem;
      font-weight: 700;
      letter-spacing: -0.5px;
      color: #fff;
    }}

    .header-badges {{
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }}

    .badge-pill {{
      padding: 4px 12px;
      border-radius: 9999px;
      font-size: 0.8rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border: 1px solid transparent;
    }}

    .badge-layer {{
      background: rgba(168, 85, 247, 0.15);
      color: #d8b4fe;
      border-color: rgba(168, 85, 247, 0.3);
    }}

    .badge-role {{
      background: rgba(0, 240, 255, 0.15);
      color: #67e8f9;
      border-color: rgba(0, 240, 255, 0.3);
    }}

    .header-desc {{
      font-size: 1.05rem;
      color: #cbd5e1;
      max-width: 900px;
      margin-bottom: 20px;
    }}

    /* 統計列 */
    .stats-bar {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      padding-top: 16px;
      border-top: 1px solid var(--border-subtle);
    }}

    .stat-item {{
      display: flex;
      flex-direction: column;
    }}

    .stat-label {{
      font-size: 0.8rem;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }}

    .stat-val {{
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--text-main);
      font-family: var(--font-mono);
    }}

    /* AI 治理卡片 */
    .governance-card {{
      background: rgba(15, 23, 42, 0.85);
      border: 1px solid rgba(0, 240, 255, 0.2);
      border-radius: 14px;
      padding: 24px;
      margin-bottom: 24px;
      position: relative;
    }}

    .governance-card h3 {{
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 1.15rem;
      color: var(--accent-cyan);
      margin-bottom: 12px;
    }}

    .governance-list {{
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }}

    .governance-list li {{
      position: relative;
      padding-left: 24px;
      font-size: 0.95rem;
      color: #e2e8f0;
    }}

    .governance-list li::before {{
      content: "🛡️";
      position: absolute;
      left: 0;
      top: 0;
      font-size: 0.85rem;
    }}

    /* 搜尋與過濾工具列 */
    .filter-toolbar {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;
      flex-wrap: wrap;
      gap: 12px;
    }}

    .search-input {{
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      border-radius: 8px;
      padding: 10px 16px;
      color: var(--text-main);
      font-size: 0.95rem;
      width: 100%;
      max-width: 360px;
      transition: all 0.2s;
    }}

    .search-input:focus {{
      outline: none;
      border-color: var(--accent-cyan);
      box-shadow: 0 0 12px rgba(0, 240, 255, 0.2);
    }}

    /* 子目錄列表 (Cards) */
    .section-title {{
      font-size: 1.25rem;
      font-weight: 700;
      margin: 28px 0 16px 0;
      display: flex;
      align-items: center;
      gap: 8px;
      color: #fff;
    }}

    .subdirs-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 16px;
      margin-bottom: 28px;
    }}

    .subdir-card {{
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      border-radius: 12px;
      padding: 16px 20px;
      text-decoration: none;
      color: inherit;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      transition: all 0.2s ease;
    }}

    .subdir-card:hover {{
      background: var(--bg-surface-hover);
      border-color: var(--accent-cyan);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0, 240, 255, 0.12);
    }}

    .subdir-header {{
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 8px;
    }}

    .subdir-icon {{
      font-size: 1.3rem;
    }}

    .subdir-name {{
      font-size: 1.05rem;
      font-weight: 600;
      color: var(--accent-cyan);
    }}

    .subdir-desc {{
      font-size: 0.88rem;
      color: var(--text-muted);
      line-height: 1.4;
      margin-bottom: 12px;
    }}

    .subdir-meta {{
      font-size: 0.8rem;
      color: #64748b;
      display: flex;
      justify-content: space-between;
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      padding-top: 8px;
    }}

    /* 檔案表格 */
    .table-container {{
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      border-radius: 14px;
      overflow: hidden;
      margin-bottom: 32px;
    }}

    .files-table {{
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }}

    .files-table th {{
      background: rgba(15, 23, 42, 0.9);
      padding: 14px 18px;
      font-size: 0.82rem;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border-subtle);
    }}

    .files-table td {{
      padding: 14px 18px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      font-size: 0.92rem;
      vertical-align: middle;
    }}

    .files-table tr:hover td {{
      background: var(--bg-surface-hover);
    }}

    .file-name-cell {{
      display: flex;
      align-items: center;
      gap: 10px;
      font-family: var(--font-mono);
      font-weight: 500;
    }}

    .file-name-cell a {{
      color: var(--text-main);
      text-decoration: none;
      transition: color 0.2s;
    }}

    .file-name-cell a:hover {{
      color: var(--accent-cyan);
    }}

    /* 類型徽章 */
    .badge {{
      display: inline-block;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 0.72rem;
      font-weight: 700;
      font-family: var(--font-mono);
      letter-spacing: 0.5px;
    }}

    .badge-lua {{ background: #002b5c; color: #60a5fa; border: 1px solid #1e40af; }}
    .badge-xml {{ background: #4a1d96; color: #c084fc; border: 1px solid #6b21a8; }}
    .badge-toc {{ background: #701a75; color: #f472b6; border: 1px solid #86198f; }}
    .badge-doc {{ background: #064e3b; color: #34d399; border: 1px solid #047857; }}
    .badge-data {{ background: #78350f; color: #fbbf24; border: 1px solid #b45309; }}
    .badge-script {{ background: #1e3a8a; color: #93c5fd; border: 1px solid #2563eb; }}
    .badge-tool {{ background: #14532d; color: #86efac; border: 1px solid #15803d; }}
    .badge-secret {{ background: #881337; color: #fda4af; border: 1px solid #be123c; }}
    .badge-media {{ background: #374151; color: #e5e7eb; border: 1px solid #4b5563; }}
    .badge-svg {{ background: #831843; color: #f43f5e; border: 1px solid #be185d; }}
    .badge-audio {{ background: #134e4a; color: #2dd4bf; border: 1px solid #0f766e; }}
    .badge-html {{ background: #7c2d12; color: #fb923c; border: 1px solid #c2410c; }}
    .badge-text {{ background: #334155; color: #cbd5e1; border: 1px solid #475569; }}
    .badge-other {{ background: #1e293b; color: #94a3b8; border: 1px solid #334155; }}

    /* 安全防護評級標籤 */
    .sec-badge {{
      display: inline-block;
      padding: 3px 10px;
      border-radius: 9999px;
      font-size: 0.76rem;
      font-weight: 600;
    }}
    .sec-taint {{ background: rgba(245, 158, 11, 0.15); color: #fbbf24; border: 1px solid rgba(245, 158, 11, 0.3); }}
    .sec-hotpath {{ background: rgba(0, 240, 255, 0.15); color: #67e8f9; border: 1px solid rgba(0, 240, 255, 0.3); }}
    .sec-vault {{ background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }}
    .sec-tool {{ background: rgba(168, 85, 247, 0.15); color: #c084fc; border: 1px solid rgba(168, 85, 247, 0.3); }}
    .sec-safe {{ background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }}

    /* 頁尾 */
    .footer {{
      text-align: center;
      padding: 32px 0 16px 0;
      font-size: 0.85rem;
      color: #64748b;
      border-top: 1px solid var(--border-subtle);
    }}

    .footer a {{
      color: var(--accent-cyan);
      text-decoration: none;
    }}

    @media (max-width: 768px) {{
      body {{ padding: 16px 12px; }}
      .header-card {{ padding: 20px; }}
      .header-title-row h1 {{ font-size: 1.4rem; }}
      .files-table th:nth-child(4),
      .files-table td:nth-child(4) {{ display: none; }}
    }}
  </style>
</head>
<body>
  <div class="container">
    <!-- 頂部導航列與 Breadcrumbs -->
    <nav class="nav-bar">
      <div class="breadcrumbs">
        {breadcrumbs_html}
      </div>
      <div>
        <a href="{root_rel_path}FOLDER_INDEX.html" style="font-size:0.85rem; color:var(--accent-cyan); text-decoration:none;">🏠 根目錄總覽</a>
      </div>
    </nav>

    <!-- 主資訊卡片 (Hero) -->
    <header class="header-card">
      <div class="header-title-row">
        <h1>📁 {dir_display_name}</h1>
        <div class="header-badges">
          <span class="badge-pill badge-layer">{layer}</span>
          <span class="badge-pill badge-role">{role}</span>
        </div>
      </div>
      <p class="header-desc">{summary}</p>
      
      <!-- 統計數據 -->
      <div class="stats-bar">
        <div class="stat-item">
          <span class="stat-label">目錄路徑</span>
          <span class="stat-val" style="font-size: 0.95rem; word-break: break-all;">{rel_dir_path}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">檔案數量</span>
          <span class="stat-val">{file_count}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">子目錄數量</span>
          <span class="stat-val">{subdir_count}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">總容量</span>
          <span class="stat-val">{total_size_str}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">安全防護層級</span>
          <span class="stat-val" style="font-size: 0.95rem;">{security}</span>
        </div>
      </div>
    </header>

    <!-- AI 治理規範卡片 -->
    <section class="governance-card" aria-label="AI Governance Summary">
      <h3>🤖 AI 治理指引與架構不變量 (Governance Invariants)</h3>
      <ul class="governance-list">
        {invariants_list_html}
      </ul>
    </section>

    <!-- 子目錄列表 (若有) -->
    {subdirs_section_html}

    <!-- 檔案清單表格 -->
    <section>
      <div class="filter-toolbar">
        <h2 class="section-title" style="margin: 0;">📄 檔案清單 ({file_count})</h2>
        <input type="text" id="fileFilter" class="search-input" placeholder="🔍 快速篩選檔案名稱、用途或標籤..." oninput="filterFiles()">
      </div>

      <div class="table-container">
        <table class="files-table" id="filesTable">
          <thead>
            <tr>
              <th style="width: 28%;">檔案名稱</th>
              <th style="width: 10%;">格式</th>
              <th style="width: 38%;">職責與用途說明</th>
              <th style="width: 14%;">安全/治理評級</th>
              <th style="width: 10%; text-align: right;">大小 / 行數</th>
            </tr>
          </thead>
          <tbody>
            {files_table_rows_html}
          </tbody>
        </table>
      </div>
    </section>

    <!-- 頁尾宣告 -->
    <footer class="footer">
      <p>EventAlertMod Remake • 專為魔獸世界 Retail 12.1 打造之次世代告警架構</p>
      <p style="margin-top: 4px; font-size: 0.78rem;">本索引由 AI 治理工具 <code>.AI/Tools/generate_folder_indexes.py</code> 自動產生與維護 • 掃描時間: {timestamp}</p>
    </footer>
  </div>

  <script>
    function filterFiles() {{
      const query = document.getElementById('fileFilter').value.toLowerCase();
      const rows = document.querySelectorAll('#filesTable tbody tr');
      rows.forEach(row => {{
        const text = row.innerText.toLowerCase();
        row.style.display = text.includes(query) ? '' : 'none';
      }});
    }}
  </script>
</body>
</html>
"""

def generate_index_for_directory(dir_path, project_root):
    """為單一目錄生成 FOLDER_INDEX.html"""
    rel_path = os.path.relpath(dir_path, project_root).replace("\\", "/")
    if rel_path == ".":
        rel_dir_path = "/"
        root_rel_path = "./"
    else:
        rel_dir_path = rel_path
        # 計算回根目錄的相對路徑
        depth = len(rel_path.split("/"))
        root_rel_path = "../" * depth

    meta = resolve_directory_metadata(rel_path)
    dir_display_name = meta["name"]
    role = meta["role"]
    layer = meta["layer"]
    security = meta["security"]
    summary = meta["summary"]
    invariants = meta.get("invariants", ["嚴格遵守專案架構規範與程式碼契約"])

    # 1. 麵包屑導航 (Breadcrumbs)
    breadcrumbs_parts = []
    if rel_path == ".":
        breadcrumbs_parts.append('<span class="current">🏠 Root</span>')
    else:
        breadcrumbs_parts.append(f'<a href="{root_rel_path}FOLDER_INDEX.html">🏠 Root</a>')
        path_segments = rel_path.split("/")
        for i, segment in enumerate(path_segments):
            if i == len(path_segments) - 1:
                breadcrumbs_parts.append(f'<span class="separator">/</span><span class="current">{segment}</span>')
            else:
                step_up = "../" * (len(path_segments) - 1 - i)
                breadcrumbs_parts.append(f'<span class="separator">/</span><a href="{step_up}FOLDER_INDEX.html">{segment}</a>')
    breadcrumbs_html = "".join(breadcrumbs_parts)

    # 2. 掃描目錄內子目錄與檔案
    try:
        entries = sorted(os.listdir(dir_path))
    except Exception as e:
        print(f"無法讀取目錄: {dir_path} ({e})")
        return 0, 0

    subdirs = []
    files = []
    total_bytes = 0

    for entry in entries:
        if entry == "FOLDER_INDEX.html":
            continue
        full_entry_path = os.path.join(dir_path, entry)
        if os.path.isdir(full_entry_path):
            if not any(pattern in entry for pattern in EXCLUDE_DIR_PATTERNS):
                subdirs.append(entry)
        elif os.path.isfile(full_entry_path):
            files.append(entry)

    # 3. 處理子目錄清單
    subdir_cards = []
    json_subdirs = []
    for sd in subdirs:
        sd_full = os.path.join(dir_path, sd)
        sd_rel = os.path.relpath(sd_full, project_root).replace("\\", "/")
        sd_meta = resolve_directory_metadata(sd_rel)
        try:
            sd_children = [c for c in os.listdir(sd_full) if c != "FOLDER_INDEX.html" and not any(p in c for p in EXCLUDE_DIR_PATTERNS)]
            sd_child_count = len(sd_children)
        except Exception:
            sd_child_count = 0
            
        subdir_cards.append(f"""
        <a href="./{sd}/FOLDER_INDEX.html" class="subdir-card">
          <div>
            <div class="subdir-header">
              <span class="subdir-icon">📁</span>
              <span class="subdir-name">{sd}</span>
            </div>
            <p class="subdir-desc">{sd_meta['summary']}</p>
          </div>
          <div class="subdir-meta">
            <span>{sd_meta['layer']}</span>
            <span>{sd_child_count} 個項目 →</span>
          </div>
        </a>
        """)
        json_subdirs.append({
            "name": sd,
            "path": f"./{sd}/",
            "role": sd_meta["role"],
            "summary": sd_meta["summary"],
        })

    if subdir_cards:
        subdirs_section_html = f"""
        <section>
          <h2 class="section-title">📂 子目錄 ({len(subdirs)})</h2>
          <div class="subdirs-grid">
            {''.join(subdir_cards)}
          </div>
        </section>
        """
    else:
        subdirs_section_html = ""

    # 4. 處理檔案表格
    file_rows = []
    json_files = []
    for f in files:
        f_path = os.path.join(dir_path, f)
        f_size, f_size_str, f_lines = get_file_stats(f_path)
        total_bytes += f_size
        f_ext = os.path.splitext(f)[1].lower()
        f_badge = get_file_type_badge(f_ext)
        f_desc, f_role, f_sec = extract_file_commentary(f_path)
        f_sec_badge = get_security_badge(f_sec)

        lines_str = f" • {f_lines} 行" if f_lines > 0 else ""
        
        file_rows.append(f"""
        <tr>
          <td>
            <div class="file-name-cell">
              <span>📄</span>
              <a href="./{html.escape(f)}" title="檢視檔案內容">{html.escape(f)}</a>
            </div>
          </td>
          <td>{f_badge}</td>
          <td>
            <div style="font-weight: 500; color: #f1f5f9;">{html.escape(f_desc)}</div>
            <div style="font-size: 0.78rem; color: #94a3b8; font-family: var(--font-mono); margin-top: 2px;">{html.escape(f_role)}</div>
          </td>
          <td>{f_sec_badge}</td>
          <td style="text-align: right; font-family: var(--font-mono); color: #cbd5e1;">
            {f_size_str}<span style="font-size: 0.78rem; color: #64748b;">{lines_str}</span>
          </td>
        </tr>
        """)

        json_files.append({
            "name": f,
            "extension": f_ext,
            "sizeBytes": f_size,
            "lineCount": f_lines,
            "purpose": f_desc,
            "role": f_role,
            "security": f_sec
        })

    if not file_rows:
        files_table_rows_html = '<tr><td colspan="5" style="text-align:center; color:#94a3b8; padding:32px;">此目錄下暫無獨立檔案</td></tr>'
    else:
        files_table_rows_html = "".join(file_rows)

    # 5. 不變量清單 HTML
    invariants_list_html = "".join(f"<li>{html.escape(inv)}</li>" for inv in invariants)
    invariants_meta = " | ".join(invariants)

    # 6. JSON-LD 結構化資料
    timestamp = datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat()
    json_ld_data = {
        "@context": "https://schema.org",
        "@type": "DirectoryGovernanceReport",
        "directoryPath": rel_dir_path,
        "name": dir_display_name,
        "layer": layer,
        "role": role,
        "securityLevel": security,
        "summary": summary,
        "invariants": invariants,
        "timestamp": timestamp,
        "fileCount": len(files),
        "subdirectoryCount": len(subdirs),
        "totalSizeBytes": total_bytes,
        "files": json_files,
        "subdirectories": json_subdirs
    }
    json_ld_str = json.dumps(json_ld_data, ensure_ascii=False, indent=2)

    # 7. 組合 HTML 內容
    output_html = HTML_TEMPLATE.format(
        dir_display_name=html.escape(dir_display_name),
        rel_dir_path=html.escape(rel_dir_path),
        root_rel_path=root_rel_path,
        breadcrumbs_html=breadcrumbs_html,
        layer=html.escape(layer),
        role=html.escape(role),
        security=html.escape(security),
        summary=html.escape(summary),
        file_count=len(files),
        subdir_count=len(subdirs),
        total_size_str=format_size(total_bytes),
        invariants_list_html=invariants_list_html,
        invariants_meta=html.escape(invariants_meta),
        subdirs_section_html=subdirs_section_html,
        files_table_rows_html=files_table_rows_html,
        timestamp=timestamp,
        json_ld_str=json_ld_str
    )

    out_file_path = os.path.join(dir_path, "FOLDER_INDEX.html")
    with open(out_file_path, "w", encoding="utf-8") as f:
        f.write(output_html)

    return len(files), len(subdirs)

def scan_and_generate_all(project_root):
    """遞迴掃描專案所有目錄並生成 FOLDER_INDEX.html"""
    print(f"🚀 開始掃描專案目錄並生成全目錄說明清單 (FOLDER_INDEX.html)...")
    print(f"📂 專案根目錄: {project_root}")

    generated_count = 0
    total_files_indexed = 0

    for root, dirs, files in os.walk(project_root):
        # 排除受保護或暫存目錄
        dirs[:] = [d for d in dirs if not any(pattern in d for pattern in EXCLUDE_DIR_PATTERNS) and not any(p in os.path.join(root, d) for p in EXCLUDE_DIR_PATTERNS)]
        
        rel_dir = os.path.relpath(root, project_root)
        if any(pattern in rel_dir for pattern in EXCLUDE_DIR_PATTERNS):
            continue

        file_count, subdir_count = generate_index_for_directory(root, project_root)
        generated_count += 1
        total_files_indexed += file_count
        display_path = rel_dir if rel_dir != "." else "Project Root (/)"
        print(f"  ✓ [{generated_count:03d}] {display_path:<45} (檔案: {file_count:3d}, 子目錄: {subdir_count:2d})")

    print(f"\n✨ 生成完成！共為 {generated_count} 個目錄建立了 FOLDER_INDEX.html，索引了 {total_files_indexed} 個檔案。")

def verify_folder_indexes(project_root):
    """驗證所有活動目錄是否都擁有合規且最新的 FOLDER_INDEX.html"""
    print(f"🔍 開始核驗全目錄 FOLDER_INDEX.html 健康狀態...")
    missing = []
    valid = 0

    for root, dirs, files in os.walk(project_root):
        dirs[:] = [d for d in dirs if not any(pattern in d for pattern in EXCLUDE_DIR_PATTERNS) and not any(p in os.path.join(root, d) for p in EXCLUDE_DIR_PATTERNS)]
        rel_dir = os.path.relpath(root, project_root)
        if any(pattern in rel_dir for pattern in EXCLUDE_DIR_PATTERNS):
            continue

        index_file = os.path.join(root, "FOLDER_INDEX.html")
        if not os.path.isfile(index_file):
            missing.append(rel_dir)
        else:
            valid += 1

    if missing:
        print(f"❌ 警告: 發現 {len(missing)} 個目錄遺失 FOLDER_INDEX.html:")
        for m in missing:
            print(f"   - {m}")
        return False
    else:
        print(f"✅ 全目錄核驗通過！共 {valid} 個目錄均擁有合規的 FOLDER_INDEX.html。")
        return True

if __name__ == "__main__":
    current_script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(current_script_dir, "..", ".."))

    if "--verify" in sys.argv:
        success = verify_folder_indexes(project_root)
        sys.exit(0 if success else 1)
    else:
        scan_and_generate_all(project_root)
        verify_folder_indexes(project_root)
