--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Locale/zhTW
檔案: Locale\zhTW.lua

理念:
- 台灣繁體中文語系字串表，維持 EAM 原本主要使用者語境。
- 不得混入簡體中文字串。

責任:
- 透過 Locale.register("zhTW") 覆蓋 L.* keys。

資料所有權:
- 擁有 zhTW key/value。

可變狀態:
- 只在載入且目前語系為 zhTW 時覆蓋 EAM.L。

邊界:
- 不建立 EA_* globals。
- 不混入 UI 行為或 API 查詢。

效能注意:
- 載入期一次性賦值；不在 hot path 執行。

Retail API 注意:
- 保留舊 key 名稱供 migration，後續改名需同步 zhTW 對照。

]]
local _, EAM = ...

local Locale = EAM.Locale
if not Locale then
    return
end

Locale.register("zhTW", function(L)
L.EA_SPELL_POWER_NAME =	{
	Health			=	"生命",
	Mana			=	"法力",
	Happiness		=	"快樂值",
	Energy			=	"能量",
	Rage			=	"怒氣",
	Focus			=	"集中值",
	FocusPet		=	"寵物集中",
	RunicPower		=	"符能",
	Runes			=	"符文",
	Pain			=	"魔痛",
	Fury			=	"魔怒",
	ComboPoints		=	"連擊星數",
	LunarPower		=	"星能",
	HolyPower		=	"聖能",
	ArcaneCharges	=	"秘法充能",
	Insanity		=	"瘋狂值",
	Maelstrom		=	"元能",
	SoulShards		=	"靈魂裂片",
	Chi				=	"真氣",	
	DemonicFury		=	"惡魔之怒",
	BurningEmbers	=	"燃火餘燼",
	LifeBloom		=	"生命之花",
	Essence			=	"龍能",
	Vigor			=	"活力",
	}
		
L.EA_TTIP_SPECFLAG_CHECK = {}
for k,v in pairs(L.EA_SPELL_POWER_NAME) do
	L.EA_TTIP_SPECFLAG_CHECK[k]="開啟/關閉, 於本身BUFF框架側顯示"..v
end	
	
L.EA_XGRPALERT_POWERTYPE = "能量別:"
L.EA_XGRPALERT_POWERTYPES = {}
for k,v in pairs(L.EA_SPELL_POWER_NAME) do
	L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES + 1]={}
	L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES].text  = v
	L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES].value = Enum.PowerType[k]	
end

L.EA_TTIP_DOALERTSOUND = "事件發生時是否播放音效."
L.EA_TTIP_ALERTSOUNDSELECT = "選擇事件發生時所播放的音效."
L.EA_TTIP_LOCKFRAME = "鎖定提示框架，避免被滑鼠拖拉移動."
L.EA_TTIP_SHARESETTINGS = "所有職業共用相同的框架位置設定."
L.EA_TTIP_SHOWFRAME = "顯示/關閉 事件發生時的提示框架."
L.EA_TTIP_SHOWNAME = "顯示/關閉 事件發生時的法術名稱."
L.EA_TTIP_SHOWFLASH = "顯示/關閉 事件發生時的全螢幕閃爍."
L.EA_TTIP_SHOWTIMER = "顯示/關閉 事件發生時的法術剩餘時間."
L.EA_TTIP_CHANGETIMER = "變更法術剩餘時間的字體大小、位置."
L.EA_TTIP_ICONSIZE = "變更提示的圖示大小."
-- L.EA_TTIP_ICONSPACE = "變更提示的圖示間距."
-- L.EA_TTIP_ICONDROPDOWN = "變更提示的圖示延展方向."
L.EA_TTIP_ALLOWESC = "變更是否可用ESC鍵關閉提示框架. (附註: 需重新載入UI)"
L.EA_TTIP_ALTALERTS = "開啟/關閉 EventAlertMod 提示額外事件(非增減益的觸發型技能)."

L.EA_TTIP_ICONXOFFSET = "調整提示框架的水平間距."
L.EA_TTIP_ICONYOFFSET = "調整提示框架的垂直間距."
L.EA_TTIP_ICONREDDEBUFF = "調整本身 Debuff 圖示的紅色深度."
L.EA_TTIP_ICONGREENDEBUFF = "調整目標 Debuff 圖示的綠色深度."
L.EA_TTIP_ICONEXECUTION = "調整首領血量百分比的斬殺期(0%代表關閉斬殺提示)"
L.EA_TTIP_PLAYERLV2BOSS = "比玩家等級高2級者(如5人副本首領)也套用首領級斬殺提示"
L.EA_TTIP_SCD_USECOOLDOWN = "技能冷卻使用倒數陰影(需重載UI才會生效)"
L.EA_TTIP_TAR_NEWLINE = "調整目標Debuff，是否另以單獨一行顯示"
L.EA_TTIP_TAR_ICONXOFFSET = "調整目標Debuff行與提醒框架水平間距"
L.EA_TTIP_TAR_ICONYOFFSET = "調整目標Debuff行與提醒框架垂直間距"
L.EA_TTIP_TARGET_MYDEBUFF = "調整目標Debuff行，是否僅顯示玩家所施放之Debuff"
L.EA_TTIP_SPELLCOND_STACK = "開啟/關閉, 當法術堆疊大於等於幾層時才顯示框架\n(可以輸入的最小值由2開始)"
L.EA_TTIP_SPELLCOND_SELF = "開啟/關閉, 只限制為玩家施放的法術, 避免監控到他人施放的相同法術"
L.EA_TTIP_SPELLCOND_OVERGROW = "開啟/關閉, 當法術堆疊大於等於幾層時以高亮顯示\n(可以輸入的最小值由1開始)"
L.EA_TTIP_SPELLCOND_REDSECTEXT = "開啟/關閉, 當倒數秒數小於等於幾秒時，以加大紅色字體顯示\n(可以輸入的最小值由1開始)"
L.EA_TTIP_SPELLCOND_ORDERWTD = "開啟/關閉, 設定顯示順序的優先比重，數字越大者，越優先顯示於最內圈(可輸入1至20)"

L.EA_TTIP_SPELLCOND_AURAVALUE1 = "開啟/關閉, 光環數值 1 (右側可輸入標籤)"
L.EA_TTIP_SPELLCOND_AURAVALUE2 = "開啟/關閉, 光環數值 2 (右側可輸入標籤)"
L.EA_TTIP_SPELLCOND_AURAVALUE3 = "開啟/關閉, 光環數值 3 (右側可輸入標籤)"
L.EA_TTIP_SPELLCOND_AURAVALUE4 = "開啟/關閉, 光環數值 4 (右側可輸入標籤)"

L.EA_TTIP_SNAMEFONTSIZE =	"調整法術技能名稱字體大小(影響光環數值)"
L.EA_TTIP_TIMERFONTSIZE =	"調整倒數字體大小"
L.EA_TTIP_STACKFONTSIZE =	"調整層數字體大小"


L.EA_TTIP_GRPCFG_ICONALPHA = "變更圖示的透明度"
L.EA_TTIP_GRPCFG_TALENT = "限定此專精時才作用"
L.EA_TTIP_GRPCFG_HIDEONLEAVECOMBAT = "離開戰鬥後,隱藏圖示"
L.EA_TTIP_GRPCFG_HIDEONLOSTTARGET = "沒有目標時,隱藏圖示"
L.EA_TTIP_GRPCFG_GLOWWHENTRUE = "滿足條件時,高亮圖示"

L.EA_TTIP_SCD_REMOVEWHENCOOLDOWN = "冷卻時移除法術圖示"
L.EA_TTIP_SCD_GLOWWHENUSABLE = "當可用時高亮顯示 SCD 圖示"
L.EA_TTIP_SCD_NOCOMBATSTILLKEEP = "即使未進入戰鬥仍顯示 SCD 圖示"
L.EA_TTIP_SCD_ITEMCOOLDOWN = "開關物品冷卻偵測(影響效能,需重新載入UI)"
L.EA_TTIP_SHOWRUNESBAR = "將符文列顯示在BUFF列上方"

L.EA_XOPT_SCD_REMOVEWHENCOOLDOWN 	= "冷卻時移除法術圖示"
L.EA_XOPT_SCD_GLOWWHENUSABLE 		= "當可用時高亮顯示 SCD 圖示"
L.EA_XOPT_SCD_NOCOMBATSTILLKEEP	= "即使未進入戰鬥仍顯示 SCD 圖示"
L.EA_XOPT_SCD_ITEMCOOLDOWN 		= "開關物品冷卻偵測"
L.EA_XOPT_SHOWRUNESBAR = "是否顯示DK符文列"


L.EA_XOPT_ICONPOSOPT = "圖示位置&職業特殊能量"
L.EA_XOPT_SHOW_ALTFRAME = "顯示主提示框架"
L.EA_XOPT_SHOW_BUFFNAME = "顯示法術名稱"
L.EA_XOPT_SHOW_TIMER = "顯示倒數秒數"
L.EA_XOPT_SHOW_OMNICC = "秒數顯示於框架內"
L.EA_XOPT_SHOW_FULLFLASH = "顯示全螢幕閃爍提示"
L.EA_XOPT_PLAY_SOUNDALERT = "播放聲音提示"
L.EA_XOPT_ESC_CLOSEALERT = "ESC 關閉提示"
L.EA_XOPT_SHOW_ALTERALERT = "顯示額外提示"
L.EA_XOPT_SHOW_CHECKLISTALERT = "啟用"
L.EA_XOPT_SHOW_CLASSALERT = "本職業-增減益提示"
L.EA_XOPT_SHOW_OTHERALERT = "跨職業-增減益提示"
L.EA_XOPT_SHOW_TARGETALERT = "目標的-增減益提示"
L.EA_XOPT_SHOW_SCDALERT = "本職業-技能CD提示"
L.EA_XOPT_SHOW_GROUPALERT = "本職業-條件技能提示"

L.EA_XOPT_OKAY = "關閉"
L.EA_XOPT_SAVE = "儲存"
L.EA_XOPT_CANCEL = "取消"
L.EA_XOPT_VERURLTEXT = "EAM發布網址：\nwww.curseforge.com/wow/addons/eventalertmod"
L.EA_XOPT_VERBTN1 = "CurseForge"
L.EA_XOPT_VERURL1 = "http://www.curseforge.com/wow/addons/eventalertmod"

L.EA_XOPT_SPELLCOND_STACK = "法術堆疊>=幾層時顯示框架:"
L.EA_XOPT_SPELLCOND_SELF = "只限制為玩家施放的法術"
L.EA_XOPT_SPELLCOND_OVERGROW = "法術堆疊>=幾層時顯示高亮:"
L.EA_XOPT_SPELLCOND_REDSECTEXT = "倒數秒數<=幾秒時顯示紅字:"
L.EA_XOPT_SPELLCOND_ORDERWTD   = "顯示順序的優先比重(1-20):"

L.EA_XOPT_SPELLCOND_AURAVALUE1   = "顯示光環數值 1"
L.EA_XOPT_SPELLCOND_AURAVALUE2   = "顯示光環數值 2"
L.EA_XOPT_SPELLCOND_AURAVALUE3   = "顯示光環數值 3"
L.EA_XOPT_SPELLCOND_AURAVALUE4   = "顯示光環數值 4"


L.EA_XICON_LOCKFRAME = "鎖定範例框架"
L.EA_XICON_LOCKFRAMETIP = "若要移動『提示框架』或『重設框架位置』時，請將『鎖定範例框架』的打勾取消"
L.EA_XICON_SHARESETTING = "共用框架位置設定"
L.EA_XICON_ICONSIZE = "圖示大小"
-- L.EA_XICON_ICONSIZE2 = "目標圖示大小"
-- L.EA_XICON_ICONSIZE3 = "CD圖示大小"
L.EA_XICON_LARGE = "大"
L.EA_XICON_SMALL = "小"
L.EA_XICON_HORSPACE = "水平間距"
L.EA_XICON_VERSPACE = "垂直間距"
-- L.EA_XICON_ICONSPACE1 = "自身圖示間距"
-- L.EA_XICON_ICONSPACE2 = "目標圖示間距"
-- L.EA_XICON_ICONSPACE3 = "CD圖示間距"
L.EA_XICON_MORE = "多"
L.EA_XICON_LESS = "少"
L.EA_XICON_REDDEBUFF = "本身Debuff圖示紅色深度"
L.EA_XICON_GREENDEBUFF = "目標Debuff圖示綠色深度"
L.EA_XICON_DEEP = "深"
L.EA_XICON_LIGHT = "淡"
-- L.EA_XICON_DIRECTION = "延展方向"
-- L.EA_XICON_DIRUP = "上"
-- L.EA_XICON_DIRDOWN = "下"
-- L.EA_XICON_DIRLEFT = "左"
-- L.EA_XICON_DIRRIGHT = "右"
L.EA_XICON_TAR_NEWLINE = "目標Debuff以另一行顯示"
L.EA_XICON_TAR_HORSPACE = "與提醒框架水平間距"
L.EA_XICON_TAR_VERSPACE = "與提醒框架垂直間距"
L.EA_XICON_TOGGLE_ALERTFRAME = "移動框架"
L.EA_XICON_RESET_FRAMEPOS = "重設框架位置"
L.EA_XICON_SELF_BUFF = "本身Buff"
L.EA_XICON_SELF_SPBUFF = "本身DeBuff(1)\n或特殊框架"
L.EA_XICON_SELF_DEBUFF = "本身Debuff"
L.EA_XICON_TARGET_BUFF = "目標Buff"
L.EA_XICON_TARGET_SPBUFF = "目標Buff(1)\n或特殊框架"
L.EA_XICON_TARGET_DEBUFF = "目標Debuff"
L.EA_XICON_SCD = "技能CD"
L.EA_XICON_EXECUTION = "提示首領級目標血量斬殺期"
L.EA_XICON_EXEFULL = "100%"
L.EA_XICON_EXECLOSE = "關閉"
L.EA_XICON_SCD_USECOOLDOWN = "技能冷卻使用倒數陰影(需重載UI)"

L.EA_XICON_SNAMEFONTSIZE = "法術名稱字體大小"
L.EA_XICON_TIMERFONTSIZE = "倒數時間字體大小"
L.EA_XICON_STACKFONTSIZE = "層數字體大小"



EX_XCLSALERT_SELALL = "全選"
EX_XCLSALERT_CLRALL = "全不選"
EX_XCLSALERT_LOADDEFAULT = "預設"
EX_XCLSALERT_REMOVEALL = "全刪"
EX_XCLSALERT_SPELL = "法術ID:"
EX_XCLSALERT_ADDSPELL = "新增"
EX_XCLSALERT_DELSPELL = "刪除"
EX_XCLSALERT_HELP1 = "上面列表以[法術ID]作為排列順序"
EX_XCLSALERT_HELP2 = "若想查詢法術ID，建議輸入 /eam help 指令"
EX_XCLSALERT_HELP3 = "瞭解在遊戲中[查詢法術]的各種指令。"
EX_XCLSALERT_HELP4 = "額外提醒區為非Buff類型之條件式技能"
EX_XCLSALERT_HELP5 = "例如:敵人血量進入斬殺期,或招架後使用"
EX_XCLSALERT_HELP6 = ",不會額外顯示Buff,卻能使用的技能。"
EX_XCLSALERT_SPELLURL = "http://www.wowhead.com/spells"

L.EA_XTARALERT_TARGET_MYDEBUFF = "僅限玩家施放減益"

L.EA_XGRPALERT_ICONALPHA = "圖示透明度"
L.EA_XGRPALERT_GRPID = "群組ID:"
L.EA_XGRPALERT_TALENT1 = "專精1"
L.EA_XGRPALERT_TALENT2 = "專精2"
L.EA_XGRPALERT_TALENT3 = "專精3"
L.EA_XGRPALERT_TALENT4 = "專精4"
L.EA_XGRPALERT_HIDEONLEAVECOMBAT = "無戰鬥時隱藏"
L.EA_XGRPALERT_HIDEONLOSTTARGET = "無目標時隱藏"

L.EA_XGRPALERT_GLOWWHENTRUE = "滿足條件時高亮"

L.EA_XGRPALERT_TALENTS = "不限專精"
L.EA_XGRPALERT_NEWSPELLBTN = "新增法術"
L.EA_XGRPALERT_NEWCHECKBTN = "新增父條件"
L.EA_XGRPALERT_NEWSUBCHECKBTN = "新增子條件"
L.EA_XGRPALERT_SPELLNAME = "法術名稱:"
L.EA_XGRPALERT_SPELLICON = "法術圖示:"
L.EA_XGRPALERT_TITLECHECK = "父條件:"
L.EA_XGRPALERT_TITLESUBCHECK = "子條件:"
L.EA_XGRPALERT_TITLEORDERUP = "提升優先度"
L.EA_XGRPALERT_TITLEORDERDOWN = "降低優先度"
L.EA_XGRPALERT_LOGICS = {
	[1]={text="並且", value=1},
	[2]={text="或者", value=0}, }
L.EA_XGRPALERT_EVENTTYPE = "事件類型:"
L.EA_XGRPALERT_EVENTTYPES = {
	[1]={text="對象能量異動類", value="UNIT_POWER_UPDATE"},
	[2]={text="對象血量異動類", value="UNIT_HEALTH"},
	[3]={text="對象增減益異動類", value="UNIT_AURA"},
	[4]={text="連擊數異動類", value="UNIT_COMBO_POINTS"}, }
L.EA_XGRPALERT_UNITTYPE = "對象別:"
L.EA_XGRPALERT_UNITTYPES = {
	[1]={text="玩家", value="player"},
	[2]={text="目標", value="target"},
	[3]={text="專注目標", value="focus"},
	[4]={text="寵物", value="pet"},
	[5]={text="首領1", value="boss1"},
	[6]={text="首領2", value="boss2"},
	[7]={text="首領3", value="boss3"},
	[8]={text="首領4", value="boss4"}, 
	[9]={text="隊友1", value="party1"},
	[10]={text="隊友2", value="party2"},
	[11]={text="隊友3", value="party3"},
	[12]={text="隊友4", value="party4"},
	[13]={text="團隊1", value="raid1"},
	[14]={text="團隊2", value="raid2"},
	[15]={text="團隊3", value="raid3"},
	[16]={text="團隊4", value="raid4"},
	[17]={text="團隊5", value="raid5"},
	[18]={text="團隊6", value="raid6"},
	[19]={text="團隊7", value="raid7"},
	[20]={text="團隊8", value="raid8"},
	[21]={text="團隊9", value="raid9"},
}

L.EA_XGRPALERT_CHECKCD = "檢測法術CD:"
	
L.EA_XGRPALERT_HEALTH = "血量:"

L.EA_XGRPALERT_COMPARETYPES = {
	[1]={text="數值", value=1},
	[2]={text="百分比", value=2},
}
L.EA_XGRPALERT_CHECKAURA = "增減益:"
L.EA_XGRPALERT_CHECKAURAS = {
	[1]={text="存在", value=1},
	[2]={text="不存在", value=2},
}
L.EA_XGRPALERT_AURATIME = "時間:"
L.EA_XGRPALERT_AURASTACK = "堆疊:"
L.EA_XGRPALERT_CASTBYPLAYER = "限玩家施放"
L.EA_XGRPALERT_COMBOPOINT = "連擊數:"

L.EA_XLOOKUP_START1 = "查詢法術名稱"
L.EA_XLOOKUP_START2 = "完整符合"
L.EA_XLOOKUP_RESULT1 = "查詢法術結果"
L.EA_XLOOKUP_RESULT2 = "項符合"
L.EA_XLOAD_LOAD = "\124cffFFFF00EventAlertMod\124r:法術監控觸發提示,已載入版本:\124cff00FFFF"

L.EA_XLOAD_FIRST_LOAD = "\124cffFF0000首次載入 EventAlertMod 特效觸發提示UI，載入預設參數\124r。\n\n"..
"請使用 \124cffFFFF00/eam opt\124r 來進行參數設定、監控法術設定、調整位置。\n\n"

L.EA_XLOAD_NEWVERSION_LOAD = "請使用 \124cffFFFF00/eam help\124r 查閱詳細指令說明。\n\n\n"..
"\124cff00FFFF- 主要更新項目 -\124r\n\n"..
"*功能新增：群組式多判斷條件的事件提示功能。\n\n"..
"目前支援偵測事件為：\n"..
"1.'對象'的'能量'，'大於等於'或'小於等於'一定'值或比例'時發動\n"..
"2.'對象'的'血量'，'大於等於'或'小於等於'一定'值或比例'時發動\n"..
"3.'對象'的'Buff/Debuff'，'含有特定法術ID'(可另以層數或秒數過濾)，或'不含有特定法術ID'時發動\n"..
"4.'玩家'對於'目標'的連擊點數，'大於等於'或'小於等於'一定'值'時發動\n"..
"以上所有條件可以用 AND 或 OR，一個或以上的條件來篩選。\n"..
"篩選結果為真時，則提示所指定的圖案。\n"..
"" -- END OF NEWVERSION

L.EA_XCMD_VER = " \124cff00FFFFBy Whitep@雷鱗\124r 版本: "
L.EA_XCMD_DEBUG = " 模式: "
L.EA_XCMD_SELFLIST = " 顯示自身Buff/Debuff: "
L.EA_XCMD_TARGETLIST = " 顯示目標Debuff: "
L.EA_XCMD_CASTSPELL = " 顯示施放法術ID: "
L.EA_XCMD_AUTOADD_SELFLIST = " 自動新增本身全增減益: "
L.EA_XCMD_ENVADD_SELFLIST = " 自動新增本身環境增減益: "
L.EA_XCMD_DEBUG_P0 = "觸發法術清單"
L.EA_XCMD_DEBUG_P1 = "法術"
L.EA_XCMD_DEBUG_P2 = "法術ID"
L.EA_XCMD_DEBUG_P3 = "堆疊"
L.EA_XCMD_DEBUG_P4 = "持續秒數"

L.EA_XCMD_CMDHELP = {
	["TITLE"] = "\124cffFFFF00EventAlertMod\124r \124cff00FF00指令\124r說明(/eventalertmod or /eam):",
	["OPT"] = "\124cff00FF00/eam options(或opt)\124r - 顯示/關閉 主設定視窗.",
	["HELP"] = "\124cff00FF00/eam help\124r - 顯示進一步指令說明.",
	["SHOW"] = {
		"\124cff00FF00/eam show [sec]\124r -",
		"開始/停止, 持續列出 >玩家< 身上所有 Buff/Debuff 的法術ID. 並且持續時間為 sec 秒之內的法術",
	},
	["SHOWT"] = {
		"\124cff00FF00/eam showtarget(或showt) [sec]\124r -",
		"開始/停止, 持續列出 >目標< 身上所有 Debuff 的法術ID. 並且持續時間為 sec 秒之內的法術",
	},
	["SHOWC"] = {
		"\124cff00FF00/eam showcast(或showc)\124r -",
		"開始/停止, 成功施放法術之後, 列出所施放的法術ID",
	},
	["SHOWA"] = {
		"\124cff00FF00/eam showautoadd(或showa) [sec]\124r -",
		"開始/停止, 自動將 >玩家< 身上所有 Buff/Debuff 的法術加入監測清單. 並且持續時間為 sec 秒(預設為60秒)之內的法術",
	},
	["SHOWE"] = {
		"\124cff00FF00/eam showenvadd(或showe) [sec]\124r -",
		"開始/停止, 自動將 >玩家< 身上 Buff/Debuff 的法術(但排除來自團隊與隊伍的)加入監測清單. 並且持續時間為 sec 秒(預設為60秒)之內的法術",
	},
	["LIST"] = {
		"\124cff00FF00/eam list\124r - 顯示觸發法術清單",
		"顯示/隱藏 show, showc, showt, lookup, lookupfull 指令的輸出結果",
	},
	["LOOKUP"] = {
		"\124cff00FF00/eam lookup(或l) 查詢名稱\124r - 部份名稱查詢法術ID",
		"查詢遊戲中所有法術，並列出所有[部份符合]查詢名稱的法術ID",
	},
	["LOOKUPFULL"] = {
		"\124cff00FF00/eam lookupfull(或lf) 查詢名稱\124r - 完整名稱查詢法術ID",
		"查詢遊戲中所有法術，並列出所有[完整符合]查詢名稱的法術ID",
	},
}
-- EAM Rewrite Additions (Auto-generated)
L.EAM_FRAME_SELF_AURA = "EAM - 自身光環框架"
L.EAM_FRAME_TARGET_AURA = "EAM - 目標光環框架"
L.EAM_FRAME_SPELL_COOLDOWN = "EAM - 技能冷卻框架"
L.EAM_FRAME_ITEM_COOLDOWN = "EAM - 物品冷卻框架"
L.EAM_FRAME_CLASS_POWER = "EAM - 職業能量框架"
L.EAM_FRAME_GROUND_EFFECT = "EAM - 地面效果框架"
L.EAM_FRAME_TOTEM = "EAM - 圖騰監控框架"
L.EAM_FRAME_POS_SAVED = "位置已保存: %s, X: %.1f, Y: %.1f"
L.EAM_MOVE_MODE_ON = "已開啟「多框架移動模式」！所有框架已亮起，請用滑鼠左鍵拖曳移動它們，再次點擊按鈕可關閉。"
L.EAM_MOVE_MODE_OFF = "已關閉「多框架移動模式」並成功套用新排版。"
L.EAM_POWER_CLASS_POWER = "職業能量"
L.EAM_POWER_HOLY_POWER = "聖能"
L.EAM_POWER_SOUL_SHARDS = "靈魂碎片"
L.EAM_POWER_COMBO_POINTS = "連擊點"
L.EAM_POWER_CHI = "真氣"
L.EAM_POWER_ARCANE_CHARGES = "秘法充能"
L.EAM_POWER_RUNIC_POWER = "符文能量"
L.EAM_POWER_RAGE = "怒氣"
L.EAM_POWER_FURY_PAIN = "狂怒/痛苦"
L.EAM_GROUND_SKILL_DEFAULT = "地面技能"
L.EAM_ITEM_PREFIX = "物品 "
L.EAM_OPT_POS_AND_POWER_BTN = "圖示位置與能量設定"
L.EAM_OPT_ENABLE_FRAME = "啟用提醒框架"
L.EAM_OPT_SHOW_SPELL_NAME = "顯示法術名稱"
L.EAM_OPT_SHOW_TIME_VAL = "顯示倒數秒數"
L.EAM_OPT_SHOW_CHANGE_IN_OUT = "框架內外切換"
L.EAM_OPT_SHOW_FLASH = "啟用全螢幕閃爍"
L.EAM_OPT_SHOW_SOUND = "啟用音效警告"
L.EAM_OPT_SOUND_PREFIX = "音效: "
L.EAM_OPT_TEST_BTN = "測試"
L.EAM_OPT_ALLOW_ESC = "啟用 ESC 鍵關閉"
L.EAM_OPT_SHOW_EXTRA_ALERT = "顯示額外輔助提醒"
L.EAM_OPT_COOLDOWN_REMOVE = "冷卻完成移除光環"
L.EAM_OPT_SHOW_SCD_OUTSIDE = "非戰鬥顯示技能冷卻"
L.EAM_OPT_GLOW_SCD = "可用時高亮技能冷卻"
L.EAM_OPT_SHOW_DK_RUNE = "顯示 DK 符文提醒"
L.EAM_OPT_ENABLE_ITEM_CD = "啟用物品冷卻監控"
L.EAM_OPT_ENABLE_CDM = "吸附官方冷卻監控(CDM)"
L.EAM_OPT_CLOSE_BTN = "關閉設定 (Close)"
L.EAM_OPT_DEBUG_BTN = "除錯診斷 (Debug)"
L.EAM_OPT_DEBUG_NOT_LOADED = "除錯診斷模組尚未加載！"
L.EAM_OPT_SLIDER_ICON_SIZE = "圖示大小 (Icon Size)"
L.EAM_OPT_SLIDER_ICON_SPACING = "水平間距 (Horizontal Spacing)"
L.EAM_OPT_SLIDER_VERT_SPACING = "垂直間距 (Vertical Spacing)"
L.EAM_OPT_SLIDER_DEBUFF_RED = "自端減益色度 (Self Debuff Red)"
L.EAM_OPT_SLIDER_DEBUFF_GREEN = "目標減益色度 (Target Debuff Green)"
L.EAM_OPT_SLIDER_EXECUTE_LIMIT = "斬殺血量閾值 (Execute Limit)"
L.EAM_OPT_ENABLE_EXECUTE = "啟用斬殺線"
L.EAM_OPT_SLIDER_FONT_SPELL = "法術名稱字型 (Spell Font)"
L.EAM_OPT_SLIDER_FONT_CD = "秒數倒數字型 (CD Font)"
L.EAM_OPT_SLIDER_FONT_STACK = "堆疊層數字型 (Stack Font)"
L.EAM_OPT_SLIDER_SHADOW_ALPHA = "倒數陰影透明度 (Shadow Alpha)"
L.EAM_OPT_DIR_TITLE = "告警框架圖示成長方向設定"
L.EAM_OPT_DIR_RIGHT = "往右 (→)"
L.EAM_OPT_DIR_LEFT = "往左 (←)"
L.EAM_OPT_DIR_UP = "往上 (↑)"
L.EAM_OPT_DIR_DOWN = "往下 (↓)"
L.EAM_OPT_GROW_SELF_AURA = "自身光環成長"
L.EAM_OPT_GROW_TARGET_AURA = "目標光環成長"
L.EAM_OPT_GROW_SPELL_COOLDOWN = "技能冷卻成長"
L.EAM_OPT_GROW_ITEM_COOLDOWN = "物品冷卻成長"
L.EAM_OPT_GROW_GROUND_EFFECT = "地面效果成長"
L.EAM_OPT_GROW_TOTEM = "圖騰監控成長"
L.EAM_OPT_GROW_CLASS_POWER = "職業能量成長"
L.EAM_OPT_TIMER_INSIDE = "秒數倒數顯示在框內"
L.EAM_OPT_TIMER_ALIGN = "秒數倒數對齊位置"
L.EAM_OPT_POWER_MONITOR_TITLE = "職業特殊能量條件監控"
L.EAM_OPT_MOVE_FRAME_BTN = "移動提醒框架"
L.EAM_OPT_MOVE_MODE_ON_PRINT = "移動模式已啟動（請使用 /eam 拖曳）"
L.EAM_OPT_RESET_FRAME_BTN = "重設所有圖示與位置"
L.EAM_OPT_RESET_FRAME_SUCCESS = "已將所有告警框架位置與成長方向重設為預設配置。"
L.EAM_OPT_LIST_TITLE = "法術提醒清單設定"
L.EAM_OPT_SELECT_ALL = "全部選擇"
L.EAM_OPT_DESELECT_ALL = "全部取消"
L.EAM_OPT_DEFAULTS_BTN = "預設值"
L.EAM_OPT_DEFAULTS_SUCCESS = "成功加載當前職業的熱門常用預設法術！"
L.EAM_OPT_DEFAULTS_FAIL = "未找到當前職業的預設法術配置。"
L.EAM_OPT_DELETE_ALL = "全部刪除"
L.EAM_OPT_FILTER_ALL = "篩選: 全部法術"
L.EAM_OPT_FILTER_PREFIX = "篩選: "
L.EAM_OPT_FILTER_GENERAL = "通用技能/自訂"
L.EAM_OPT_ADD_SUCCESS = "成功新增監控提醒 [ID: %s]"
L.EAM_OPT_ADD_FAIL = "新增監控提醒失敗: %s"
L.EAM_OPT_DEL_SUCCESS = "成功移除監控提醒 [ID: %s]"
L.EAM_OPT_DEL_FAIL = "移除監控提醒失敗: %s"
L.EAM_OPT_ADD_BTN = "新增"
L.EAM_OPT_DEL_BTN = "刪除"
L.EAM_OPT_ERR_INVALID_ID = "請輸入正確的 ID！"
L.EAM_OPT_ADD_DEL_DESC = "請輸入 SpellID 或 ItemID 並點擊新增 / 刪除。"
L.EAM_OPT_COND_SPELL_NAME = "法術名稱"
L.EAM_OPT_COND_STACK = "堆疊層數閾值"
L.EAM_OPT_COND_GLOW = "堆疊高亮閾值"
L.EAM_OPT_COND_RED_LIMIT = "倒數紅字限制 (秒)"
L.EAM_OPT_COND_PRIORITY = "排序優先級 (Priority)"
L.EAM_OPT_COND_PLAYER_ONLY = "僅監控自己施放"
L.EAM_OPT_COND_VAL_TITLE = "顯示光環細部數值:"
L.EAM_OPT_COND_VAL1 = "顯示數值 1 (Value 1)"
L.EAM_OPT_COND_VAL2 = "顯示數值 2 (Value 2)"
L.EAM_OPT_COND_VAL3 = "顯示數值 3 (Value 3)"
L.EAM_OPT_COND_VAL4 = "顯示數值 4 (Value 4)"
L.EAM_OPT_COND_TOOLTIP = "啟用動態 Tooltip 擷取"
L.EAM_OPT_COND_MANUAL_DUR = "手動設定時間 (秒)"
L.EAM_OPT_COND_SCRAPE_BTN = "一鍵擷取"
L.EAM_OPT_SCRAPE_SUCCESS = "成功擷取當前持續時間: %s 秒"
L.EAM_OPT_SCRAPE_FAIL = "未能在說明中解析出秒數，請手動輸入。"
L.EAM_OPT_COND_SAVE_BTN = "儲存設定 (Save)"
L.EAM_OPT_COND_SAVE_SUCCESS = "條件已儲存。"
L.EAM_OPT_COND_CANCEL_BTN = "取消關閉 (Cancel)"
L.EAM_OPT_COMBAT_WARNING = "少年欸！戰鬥中暫不開啟設定視窗，脫離戰鬥後會自動為你開啟。"
L.EAM_OPT_MINIMAP_LCLICK = "左鍵點擊: 開啟/關閉設定面板"
L.EAM_OPT_MINIMAP_RCLICK = "右鍵點擊: 開啟系統除錯診斷"
L.EAM_OPT_MINIMAP_DRAG = "拖曳小圖示可移動位置"
L.EAM_ALIGN_CENTER = "正中央"
L.EAM_ALIGN_TOP = "上方"
L.EAM_ALIGN_BOTTOM = "下方"
L.EAM_ALIGN_LEFT = "左方"
L.EAM_ALIGN_RIGHT = "右方"
L.EAM_ALIGN_TOPLEFT = "左上角"
L.EAM_ALIGN_TOPRIGHT = "右上角"
L.EAM_ALIGN_BOTTOMLEFT = "左下角"
L.EAM_ALIGN_BOTTOMRIGHT = "右下角"
L.EAM_OPT_CAT_SELF = "自端增益/減益提醒 (Self)"
L.EAM_OPT_CAT_CLASS = "跨職業增益/減益提醒 (Class)"
L.EAM_OPT_CAT_TARGET = "目標增益/減益提醒 (Target)"
L.EAM_OPT_CAT_SPELL_CD = "技能冷卻監控設定 (Spell CD)"
L.EAM_OPT_CAT_ITEM_CD = "物品冷卻監控設定 (Item CD)"
L.EAM_OPT_CAT_GROUND = "地面技能與效果設定 (Ground Effect)"
L.EAM_OPT_CAT_LAYOUT = "圖示位置與能量設定 (Layout & Power)"
L.EAM_SLASH_HELP_OPT = "/eam opt - 開啟設定"
L.EAM_SLASH_HELP_DOCTOR = "/eam doctor - 顯示 Retail/PTR API 邊界診斷"
L.EAM_SLASH_HELP_VALIDATE = "/eam validate - 同 /eam doctor"
L.EAM_SLASH_HELP_DEBUG = "/eam debug - 顯示除錯摘要"
L.EAM_SLASH_HELP_EXPORT = "/eam export - 輸出精簡 AI debug 狀態"
L.EAM_SLASH_HELP_ADD = "/eam add <spellID> - 新增 player aura"
L.EAM_SLASH_HELP_ADD_TARGET = "/eam add target <spellID> - 新增 target aura"
L.EAM_SLASH_HELP_ADD_CD = "/eam add cd <spellID> - 新增 spell cooldown"
L.EAM_SLASH_HELP_ADD_ITEM = "/eam add item <itemID> - 新增 item cooldown"
L.EAM_SLASH_HELP_REMOVE = "/eam remove <spellID|target|cd|item> <id> - 移除 alert"
L.EAM_SLASH_NOT_INIT = "SavedVariables 尚未初始化。"
L.EAM_SLASH_OP_FAIL = "操作失敗: "
L.EAM_SLASH_DEBUG_GROUND_START = "正在除錯無光環地面技能 Tooltip 解析 (當前客戶端語系: %s)..."
L.EAM_SLASH_DEBUG_GROUND_SUCCESS = "法術 [%d] 成功解析持續時間: |cff00ff00%s 秒|r"
L.EAM_SLASH_DEBUG_GROUND_FAIL = "法術 [%d] Tooltip 解析失敗，將使用預設時間"
L.EAM_SLASH_GROUND_NOT_LOADED = "GroundEffectService 未加載！"
L.EAM_SLASH_SPECIFY_SPELLID = "請指定正確的法術 ID: /eam debug ground <spellID>"
L.EAM_OPT_FLOW_TEST_BTN = "流程測試"
L.EAM_SLASH_HELP_TEST = "/eam test [quick|core|boundary|all] - 開啟或執行流程驗證"
L.EAM_FLOW_PANEL_TITLE = "EAM 流程驗證與開發回灌"
L.EAM_FLOW_PANEL_DESC = "離線 Mock 與 Retail/PTR 實機共用案例。Mock 通過不代表實機通過。"
L.EAM_FLOW_BUTTON_QUICK = "快速流程"
L.EAM_FLOW_BUTTON_CORE = "核心流程"
L.EAM_FLOW_BUTTON_BOUNDARY = "邊界流程"
L.EAM_FLOW_BUTTON_AURA121 = "12.1 Aura"
L.EAM_OPT_AURA_BACKEND = "Aura 後端: "
L.EAM_OPT_AURA_PENDING = "（等待脫戰）"
L.EAM_OPT_AURA_REBUILD = "重建"
L.EAM_FLOW_BUTTON_ALL = "執行全部"
L.EAM_FLOW_BUTTON_COPY = "複製開發報告"
L.EAM_FLOW_BUTTON_CLOSE = "關閉"
L.EAM_FLOW_STATUS_NO_REPORT = "尚無流程測試報告。"
L.EAM_FLOW_STATUS_SUMMARY = "完成：通過 %d、失敗 %d、略過 %d。"
L.EAM_FLOW_STATUS_COPIED = "報告已複製，可回灌至開發環境。"
L.EAM_FLOW_STATUS_COMBAT = "戰鬥中不執行流程測試。"
L.EAM_FLOW_STATUS_UNAVAILABLE = "流程測試模組尚未載入。"
L.EAM_FLOW_STATUS_RUNNING = "流程測試執行中……"
L.EAM_FLOW_STATUS_START_FAILED = "無法啟動流程測試：%s"
L.EAM_FLOW_STATUS_DEFERRED = "流程測試面板將於脫離戰鬥後開啟。"
-- EAM Spec Filter Additions (Auto-generated)
L.EAM_OPT_FILTER_ALL_VAL = "全部法術"

L.EAM_TOOLTIP_SPELL_ID = "EAM 法術 ID"
L.EAM_TOOLTIP_ITEM_ID = "EAM 物品 ID"
L.EAM_TOOLTIP_MACRO_ID = "EAM 巨集 ID"
L.EAM_TOOLTIP_OPEN_HINT = "按下 Ctrl+Alt 開啟 EAM 監控選單"
L.EAM_TOOLTIP_MACRO_MANUAL_HINT = "無法安全解析巨集來源；按下 Ctrl+Alt 手動輸入監控 ID"
L.EAM_TOOLTIP_AURA_HINT = "Aura ID 由暴雪顯示；按下 Ctrl+Alt 開啟 EAM"
L.EAM_TOOLTIP_AURA_MANUAL_HINT = "官方 Aura ID 顯示不可用；按下 Ctrl+Alt 開啟 EAM 手動輸入"
L.EAM_POPUP_TITLE = "EAM 加入監控"
L.EAM_POPUP_ID_UNRESOLVED = "尚未解析"
L.EAM_POPUP_DESC_SPELL = "法術 ID：%s"
L.EAM_POPUP_DESC_ITEM = "物品 ID：%s"
L.EAM_POPUP_DESC_AURA = "請輸入 Tooltip 顯示的 Aura 法術 ID，再選擇監控單位。"
L.EAM_POPUP_DESC_AURA_MANUAL = "暴雪官方 Aura ID 顯示目前不可用。請輸入已知的 Aura 法術 ID，再選擇監控單位。"
L.EAM_POPUP_DESC_MACRO = "巨集 ID：%s\n法術 ID：%s\n物品 ID：%s"
L.EAM_POPUP_ID_INPUT = "監控 ID"
L.EAM_POPUP_ADD_SPELL = "加入技能冷卻監控"
L.EAM_POPUP_ADD_ITEM = "加入物品冷卻監控"
L.EAM_POPUP_ADD_AURA_PLAYER = "加入玩家光環監控"
L.EAM_POPUP_ADD_AURA_TARGET = "加入目標光環監控"
L.EAM_POPUP_CANCEL = "取消"
L.EAM_POPUP_STATUS_ADDED = "已加入監控"
L.EAM_POPUP_STATUS_UPDATED = "已更新監控"
L.EAM_POPUP_STATUS_UNCHANGED = "已在監控清單"
L.EAM_POPUP_RESULT = "EAM：%s（ID %d）"
L.EAM_POPUP_RESULT_FAILED = "EAM：無法加入監控（%s）"



end)

