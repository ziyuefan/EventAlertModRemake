--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Locale/zhCN
檔案: Locale\zhCN.lua

理念:
- 簡體中文語系字串表，與 zhTW 嚴格分離。
- 避免簡體字串污染繁體中文檔。

責任:
- 透過 Locale.register("zhCN") 覆蓋 L.* keys。

資料所有權:
- 擁有 zhCN key/value。

可變狀態:
- 只在載入且目前語系為 zhCN 時覆蓋 EAM.L。

邊界:
- 不建立 EA_* globals。
- 不混入 UI 行為或 API 查詢。

效能注意:
- 載入期一次性賦值。

Retail API 注意:
- 保留舊 key 名稱供 migration。

]]
local _, EAM = ...

local Locale = EAM.Locale
if not Locale then
    return
end

Locale.register("zhCN", function(L)
L.EA_SPELL_POWER_NAME =	{
	Health			=	"生命",
	Mana			=	"法力",
	Happiness		=	"快乐值",
	Energy			=	"能量",
	Rage			=	"怒气",
	Focus			=	"集中值",
	FocusPet		=	"宠物集中",
	RunicPower		=	"符能",
	Runes			=	"符文",
	Pain			=	"痛苦值",
	Fury			=	"魔怒",
	ComboPoints		=	"连击数",
	LunarPower		=	"星界能量",
	HolyPower		=	"圣能",
	ArcaneCharges	=	"奥术充能",
	Insanity		=	"狂乱",
	Maelstrom		=	"漩涡值",
	SoulShards		=	"灵魂碎片",
	Chi				=	"真气",	
	DemonicFury		=	"恶魔之怒",
	BurningEmbers	=	"燃火餘燼",
	LifeBloom		=	"生命之花",
	Essence			=	"精华",
	Vigor			=	"精力",
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
		
L.EA_TTIP_DOALERTSOUND = "事件发生时是否播放音效."
L.EA_TTIP_ALERTSOUNDSELECT = "选择事件发生时所播放的音效."
L.EA_TTIP_LOCKFRAME = "锁定提示框架，避免被滑鼠拖拉移动."
L.EA_TTIP_SHARESETTINGS = "所有职业共用相同的框架位置设定."
L.EA_TTIP_SHOWFRAME = "显示/关闭 事件发生时的提示框架."
L.EA_TTIP_SHOWNAME = "显示/关闭 事件发生时的法术名称."
L.EA_TTIP_SHOWFLASH = "显示/关闭 事件发生时的全荧幕闪烁."
L.EA_TTIP_SHOWTIMER = "显示/关闭 事件发生时的法术剩余时间."
L.EA_TTIP_CHANGETIMER = "变更法术剩余时间的字体大小、位置."
L.EA_TTIP_ICONSIZE = "变更提示的图示大小."
-- L.EA_TTIP_ICONSPACE = "变更提示的图示间距."
-- L.EA_TTIP_ICONDROPDOWN = "变更提示的图示延展方向."
L.EA_TTIP_ALLOWESC = "变更是否可用ESC键关闭提示框架. (附注: 需重新载入UI)"
L.EA_TTIP_ALTALERTS = "开启/关闭 EventAlertMod 提示额外事件(非增减益的触发型技能)."

L.EA_TTIP_ICONXOFFSET = "调整提示框架的水平间距."
L.EA_TTIP_ICONYOFFSET = "调整提示框架的垂直间距."
L.EA_TTIP_ICONREDDEBUFF = "调整本身 Debuff 图示的红色深度."
L.EA_TTIP_ICONGREENDEBUFF = "调整目标 Debuff 图示的绿色深度."
L.EA_TTIP_ICONEXECUTION = "调整首领血量百分比的斩杀期(0%代表关闭斩杀提示)"
L.EA_TTIP_PLAYERLV2BOSS = "比玩家等级高2级者(如5人副本首领)也套用首领级斩杀提示"
L.EA_TTIP_SCD_USECOOLDOWN = "技能冷却使用倒数阴影（需重载UI才会生效）"
L.EA_TTIP_TAR_NEWLINE = "调整目标Debuff，是否另以单独一行显示"
L.EA_TTIP_TAR_ICONXOFFSET = "调整目标Debuff行与提醒框架水平间距"
L.EA_TTIP_TAR_ICONYOFFSET = "调整目标Debuff行与提醒框架垂直间距"
L.EA_TTIP_TARGET_MYDEBUFF = "调整目标Debuff行，是否仅显示玩家所施放之Debuff"
L.EA_TTIP_SPELLCOND_STACK = "开启/关闭, 当法术堆叠大于等于几层时才显示框架\n(可以输入的最小值由2开始)"
L.EA_TTIP_SPELLCOND_SELF = "开启/关闭, 只限制为玩家施放的法术, 避免监控到他人施放的相同法术"
L.EA_TTIP_SPELLCOND_OVERGROW = "开启/关闭, 当法术堆叠大于等于几层时以高亮显示\n(可以输入的最小值由1开始)"
L.EA_TTIP_SPELLCOND_REDSECTEXT = "开启/关闭, 当倒数秒数小于等于几秒时，以加大红色字体显示\n(可以输入的最小值由1开始)"
L.EA_TTIP_SPELLCOND_ORDERWTD = "开启/关闭, 设定显示顺序的优先比重，数字越大者，越优先显示于最内圈(可输入1至20)"

L.EA_TTIP_SPELLCOND_AURAVALUE1 = "开启/关闭，光环数值 1（右侧可输入标签）"
L.EA_TTIP_SPELLCOND_AURAVALUE2 = "开启/关闭，光环数值 2（右侧可输入标签）"
L.EA_TTIP_SPELLCOND_AURAVALUE3 = "开启/关闭，光环数值 3（右侧可输入标签）"
L.EA_TTIP_SPELLCOND_AURAVALUE4 = "开启/关闭，光环数值 4（右侧可输入标签）"  

L.EA_TTIP_GRPCFG_ICONALPHA = "变更图示的透明度"
L.EA_TTIP_GRPCFG_TALENT = "限定此專精时才作用"
L.EA_TTIP_GRPCFG_HIDEONLEAVECOMBAT = "离开战斗后,隐藏图示"
L.EA_TTIP_GRPCFG_HIDEONLOSTTARGET = "没有目标时,隐藏图示"
L.EA_TTIP_GRPCFG_GLOWWHENTRUE = "满足条件时,高亮图示"

L.EA_TTIP_SCD_REMOVEWHENCOOLDOWN = "冷却时移除法术图标"
L.EA_TTIP_SCD_GLOWWHENUSABLE = "当可用时发光显示 SCD 图标"
L.EA_TTIP_SCD_NOCOMBATSTILLKEEP = "即使未进入战斗仍显示 SCD 图标"   
L.EA_TTIP_SCD_ITEMCOOLDOWN = "切换物品冷却检测（影响性能，需要重新加载界面）"
L.EA_TTIP_SHOWRUNESBAR = "将符文条显示在BUFF栏上方"

L.EA_TTIP_SNAMEFONTSIZE = "调整法术技能名称字体大小（影响光环数值）"
L.EA_TTIP_TIMERFONTSIZE = "调整倒计时字体大小"
L.EA_TTIP_STACKFONTSIZE = "调整层数字体大小"


L.EA_XOPT_SCD_REMOVEWHENCOOLDOWN = "冷却时移除法术图标"
L.EA_XOPT_SCD_GLOWWHENUSABLE = "当可用时发光显示 SCD 图标"
L.EA_XOPT_SCD_NOCOMBATSTILLKEEP = "即使未进入战斗仍显示 SCD 图标"
L.EA_XOPT_SCD_ITEMCOOLDOWN = "切换物品冷却检测"                   

L.EA_XOPT_SHOWRUNESBAR = "是否显示DK符文列"


L.EA_XOPT_ICONPOSOPT = "图示位置&副资源"
L.EA_XOPT_SHOW_ALTFRAME = "显示主提示框架"
L.EA_XOPT_SHOW_BUFFNAME = "显示法术名称"
L.EA_XOPT_SHOW_TIMER = "显示倒数秒数"
L.EA_XOPT_SHOW_OMNICC = "秒数显示于框架内"
L.EA_XOPT_SHOW_FULLFLASH = "显示全荧幕闪烁提示"
L.EA_XOPT_PLAY_SOUNDALERT = "播放声音提示"
L.EA_XOPT_ESC_CLOSEALERT = "ESC 关闭提示"
L.EA_XOPT_SHOW_ALTERALERT = "显示额外提示"
L.EA_XOPT_SHOW_CHECKLISTALERT = "启用"
L.EA_XOPT_SHOW_CLASSALERT = "本职业-增减益提示"
L.EA_XOPT_SHOW_OTHERALERT = "跨职业-增减益提示"
L.EA_XOPT_SHOW_TARGETALERT = "目标的-增减益提示"
L.EA_XOPT_SHOW_SCDALERT = "本职业-技能CD提示"
L.EA_XOPT_SHOW_GROUPALERT = "本职业-条件技能提示"
L.EA_XOPT_OKAY = "关闭"
L.EA_XOPT_SAVE = "储存"
L.EA_XOPT_CANCEL = "取消"
L.EA_XOPT_VERURLTEXT = "EAM发布网址：\nwww.curseforge.com/wow/addons/eventalertmod"
L.EA_XOPT_VERBTN1 = "CorseForge"
L.EA_XOPT_VERURL1 = "http://www.curseforge.com/wow/addons/eventalertmod"

L.EA_XOPT_SPELLCOND_STACK = "法术堆叠>=几层时显示框架:"
L.EA_XOPT_SPELLCOND_SELF = "只限制为玩家施放的法术"
L.EA_XOPT_SPELLCOND_OVERGROW = "法术堆叠>=几层时显示高亮:"
L.EA_XOPT_SPELLCOND_REDSECTEXT = "倒数秒数<=几秒时显示红字:"
L.EA_XOPT_SPELLCOND_ORDERWTD   = "显示顺序的优先比重(1-20):"

L.EA_XOPT_SPELLCOND_AURAVALUE1 = "显示光环数值 1"
L.EA_XOPT_SPELLCOND_AURAVALUE2 = "显示光环数值 2"
L.EA_XOPT_SPELLCOND_AURAVALUE3 = "显示光环数值 3"
L.EA_XOPT_SPELLCOND_AURAVALUE4 = "显示光环数值 4"

L.EA_XICON_LOCKFRAME = "锁定范例框架"
L.EA_XICON_LOCKFRAMETIP = "若要移动‘提示框架’或‘重设框架位置’时，请将‘锁定范例框架’的打勾取消"
L.EA_XICON_SHARESETTING = "共用框架位置设定"
L.EA_XICON_ICONSIZE = "图示大小"
-- L.EA_XICON_ICONSIZE2 = "目标图示大小"
-- L.EA_XICON_ICONSIZE3 = "CD图示大小"
L.EA_XICON_LARGE = "大"
L.EA_XICON_SMALL = "小"
L.EA_XICON_HORSPACE = "水平间距"
L.EA_XICON_VERSPACE = "垂直间距"
-- L.EA_XICON_ICONSPACE1 = "自身图示间距"
-- L.EA_XICON_ICONSPACE2 = "目标图示间距"
-- L.EA_XICON_ICONSPACE3 = "CD图示间距"
L.EA_XICON_MORE = "多"
L.EA_XICON_LESS = "少"
L.EA_XICON_REDDEBUFF = "本身Debuff图示红色深度"
L.EA_XICON_GREENDEBUFF = "目标Debuff图示绿色深度"
L.EA_XICON_DEEP = "深"
L.EA_XICON_LIGHT = "淡"
-- L.EA_XICON_DIRECTION = "延展方向"
-- L.EA_XICON_DIRUP = "上"
-- L.EA_XICON_DIRDOWN = "下"
-- L.EA_XICON_DIRLEFT = "左"
-- L.EA_XICON_DIRRIGHT = "右"
L.EA_XICON_TAR_NEWLINE = "目标Debuff以另一行显示"
L.EA_XICON_TAR_HORSPACE = "与提醒框架水平间距"
L.EA_XICON_TAR_VERSPACE = "与提醒框架垂直间距"
L.EA_XICON_TOGGLE_ALERTFRAME = "移动框架"
L.EA_XICON_RESET_FRAMEPOS = "重设框架位置"
L.EA_XICON_SELF_BUFF = "本身Buff"
L.EA_XICON_SELF_SPBUFF = "本身DeBuff(1)\n或特殊框架"
L.EA_XICON_SELF_DEBUFF = "本身Debuff"
L.EA_XICON_TARGET_BUFF = "目标Buff"
L.EA_XICON_TARGET_SPBUFF = "目标Buff(1)\n或特殊框架"
L.EA_XICON_TARGET_DEBUFF = "目标Debuff"
L.EA_XICON_SCD = "技能CD"
L.EA_XICON_EXECUTION = "提示首领级目标血量斩杀期"
L.EA_XICON_EXEFULL = "100%"
L.EA_XICON_EXECLOSE = "关闭"
L.EA_XICON_SCD_USECOOLDOWN = "技能冷却使用倒数阴影（需重载UI）"

L.EA_XICON_SNAMEFONTSIZE = "法术名称字体大小"
L.EA_XICON_TIMERFONTSIZE = "倒计时字体大小"
L.EA_XICON_STACKFONTSIZE = "层数字体大小"


EX_XCLSALERT_SELALL = "全选"
EX_XCLSALERT_CLRALL = "全不选"
EX_XCLSALERT_LOADDEFAULT = "预设"
EX_XCLSALERT_REMOVEALL = "全删"
EX_XCLSALERT_SPELL = "法术ID:"
EX_XCLSALERT_ADDSPELL = "新增"
EX_XCLSALERT_DELSPELL = "删除"
EX_XCLSALERT_HELP1 = "上面列表以[法术ID]作为排列顺序"
EX_XCLSALERT_HELP2 = "若想查询法术ID，建议输入 /eam help 指令"
EX_XCLSALERT_HELP3 = "了解在游戏中[查询法术]的各种指令。"
EX_XCLSALERT_HELP4 = "额外提醒区为非Buff类型之条件式技能"
EX_XCLSALERT_HELP5 = "例如:敌人血量进入斩杀期,或招架后使用"
EX_XCLSALERT_HELP6 = ",不会额外显示Buff,却能使用的技能。"
EX_XCLSALERT_SPELLURL = "http://www.wowhead.com/spells"

L.EA_XTARALERT_TARGET_MYDEBUFF = "仅限玩家施放减益"

L.EA_XGRPALERT_ICONALPHA = "图示透明度"
L.EA_XGRPALERT_GRPID = "群组ID:"
L.EA_XGRPALERT_TALENT1 = "专精1"
L.EA_XGRPALERT_TALENT2 = "专精2"
L.EA_XGRPALERT_TALENT3 = "专精3"
L.EA_XGRPALERT_TALENT4 = "专精4"
L.EA_XGRPALERT_HIDEONLEAVECOMBAT = "无战斗时隐藏"
L.EA_XGRPALERT_HIDEONLOSTTARGET = "无目标时隐藏"

L.EA_XGRPALERT_GLOWWHENTRUE = "满足条件时高亮"

L.EA_XGRPALERT_TALENTS = "不限专精"
L.EA_XGRPALERT_NEWSPELLBTN = "新增法术"
L.EA_XGRPALERT_NEWCHECKBTN = "新增父条件"
L.EA_XGRPALERT_NEWSUBCHECKBTN = "新增子条件"
L.EA_XGRPALERT_SPELLNAME = "法术名称:"
L.EA_XGRPALERT_SPELLICON = "法术图示:"
L.EA_XGRPALERT_TITLECHECK = "父条件:"
L.EA_XGRPALERT_TITLESUBCHECK = "子条件:"
L.EA_XGRPALERT_TITLEORDERUP = "提升优先度"
L.EA_XGRPALERT_TITLEORDERDOWN = "降低优先度"
L.EA_XGRPALERT_LOGICS = {
	[1]={text="并且", value=1},
	[2]={text="或者", value=0}, }
L.EA_XGRPALERT_EVENTTYPE = "事件类型:"
L.EA_XGRPALERT_EVENTTYPES = {
	[1]={text="对象能量异动类", value="UNIT_POWER_UPDATE"},
	[2]={text="对象血量异动类", value="UNIT_HEALTH"},
	[3]={text="对象增减益异动类", value="UNIT_AURA"},
	[4]={text="连击数异动类", value="UNIT_COMBO_POINTS"}, }
L.EA_XGRPALERT_UNITTYPE = "对象别:"
L.EA_XGRPALERT_UNITTYPES = {
	[1]={text="玩家", value="player"},
	[2]={text="目标", value="target"},
	[3]={text="专注目标", value="focus"},
	[4]={text="宠物", value="pet"},
	[5]={text="首领1", value="boss1"},
	[6]={text="首领2", value="boss2"},
	[7]={text="首领3", value="boss3"},
	[8]={text="首领4", value="boss4"}, 
	[9]={text="队友1", value="party1"},
	[10]={text="队友2", value="party2"},
	[11]={text="队友3", value="party3"},
	[12]={text="队友4", value="party4"},
	[13]={text="团队1", value="raid1"},
	[14]={text="团队2", value="raid2"},
	[15]={text="团队3", value="raid3"},
	[16]={text="团队4", value="raid4"},
	[17]={text="团队5", value="raid5"},
	[18]={text="团队6", value="raid6"},
	[19]={text="团队7", value="raid7"},
	[20]={text="团队8", value="raid8"},
	[21]={text="团队9", value="raid9"},
}

L.EA_XGRPALERT_CHECKCD = "检测法术CD:"

L.EA_XGRPALERT_HEALTH = "血量:"

L.EA_XGRPALERT_COMPARETYPES = {
	[1]={text="数值", value=1},
	[2]={text="百分比", value=2},
}
L.EA_XGRPALERT_CHECKAURA = "增减益:"
L.EA_XGRPALERT_CHECKAURAS = {
	[1]={text="存在", value=1},
	[2]={text="不存在", value=2},
}
L.EA_XGRPALERT_AURATIME = "时间:"
L.EA_XGRPALERT_AURASTACK = "堆叠:"
L.EA_XGRPALERT_CASTBYPLAYER = "限玩家施放"
L.EA_XGRPALERT_COMBOPOINT = "连击数:"

L.EA_XLOOKUP_START1 = "查询法术名称"
L.EA_XLOOKUP_START2 = "完整符合"
L.EA_XLOOKUP_RESULT1 = "查询法术结果"
L.EA_XLOOKUP_RESULT2 = "项符合"
L.EA_XLOAD_LOAD = "\124cffFFFF00EventAlertMod\124r:法术监控触发提示,已载入版本:\124cff00FFFF"

L.EA_XLOAD_FIRST_LOAD = "\124cffFF0000首次载入 EventAlertMod 特效触发提示UI，载入预设参数\124r。\n\n"..
"请使用 \124cffFFFF00/eam opt\124r 来进行参数设定、监控法术设定、调整位置。\n\n"

L.EA_XLOAD_NEWVERSION_LOAD = "请使用 \124cffFFFF00/eam help\124r 查阅详细指令说明。\n\n\n"..
"\124cff00FFFF- 主要更新项目 -\124r\n\n"..
"*功能新增：群组式多判断条件的事件提示功能。\n\n"..
"目前支援侦测事件为：\n"..
"1.'对象'的'能量'，'大于等于'或'小于等于'一定'值或比例'时发动\n"..
"2.'对象'的'血量'，'大于等于'或'小于等于'一定'值或比例'时发动\n"..
"3.'对象'的'Buff/Debuff'，'含有特定法术ID'(可另以层数或秒数过滤)，或'不含有特定法术ID'时发动\n"..
"4.'玩家'对于'目标'的连击点数，'大于等于'或'小于等于'一定'值'时发动\n"..
"以上所有条件可以用 AND 或 OR，一个或以上的条件来筛选。\n"..
"筛选结果为真时，则提示所指定的图案。\n"..
"" -- END OF NEWVERSION



L.EA_XCMD_VER = " \124cff00FFFFBy Whitep@雷鳞\124r 版本: "
L.EA_XCMD_DEBUG = " 模式: "
L.EA_XCMD_SELFLIST = " 显示自身Buff/Debuff: "
L.EA_XCMD_TARGETLIST = " 显示目标Debuff: "
L.EA_XCMD_CASTSPELL = " 显示施放法术ID: "
L.EA_XCMD_AUTOADD_SELFLIST = " 自动新增本身全增减益: "
L.EA_XCMD_ENVADD_SELFLIST = " 自动新增本身环境增减益: "
L.EA_XCMD_DEBUG_P0 = "触发法术清单"
L.EA_XCMD_DEBUG_P1 = "法术"
L.EA_XCMD_DEBUG_P2 = "法术ID"
L.EA_XCMD_DEBUG_P3 = "堆叠"
L.EA_XCMD_DEBUG_P4 = "持续秒数"


L.EA_XCMD_CMDHELP = {
	["TITLE"] = "\124cffFFFF00EventAlertMod\124r \124cff00FF00指令\124r说明(/eventalertmod or /eam):",
	["OPT"] = "\124cff00FF00/eam options(或opt)\124r - 显示/关闭 主设定视窗.",
	["HELP"] = "\124cff00FF00/eam help\124r - 显示进一步指令说明.",
	["SHOW"] = {
		"\124cff00FF00/eam show [sec]\124r -",
		"开始/停止, 持续列出 >玩家< 身上所有 Buff/Debuff 的法术ID. 并且持续时间为 sec 秒之内的法术",
	},
	["SHOWT"] = {
		"\124cff00FF00/eam showtarget(或showt) [sec]\124r -",
		"开始/停止, 持续列出 >目标< 身上所有 Debuff 的法术ID. 并且持续时间为 sec 秒之内的法术",
	},
	["SHOWC"] = {
		"\124cff00FF00/eam showcast(或showc)\124r -",
		"开始/停止, 成功施放法术之后, 列出所施放的法术ID",
	},
	["SHOWA"] = {
		"\124cff00FF00/eam showautoadd(或showa) [sec]\124r -",
		"开始/停止, 自动将 >玩家< 身上所有 Buff/Debuff 的法术加入监测清单. 并且持续时间为 sec 秒(预设为60秒)之内的法术",
	},
	["SHOWE"] = {
		"\124cff00FF00/eam showenvadd(或showe) [sec]\124r -",
		"开始/停止, 自动将 >玩家< 身上 Buff/Debuff 的法术(但排除来自团队与队伍的)加入监测清单. 并且持续时间为 sec 秒(预设为60秒)之内的法术",
	},
	["LIST"] = {
		"\124cff00FF00/eam list\124r - 显示触发法术清单",
		"显示/隐藏 show, showc, showt, lookup, lookupfull 指令的输出结果",
	},
	["LOOKUP"] = {
		"\124cff00FF00/eam lookup(或l) 查询名称\124r - 部份名称查询法术ID",
		"查询游戏中所有法术，并列出所有[部份符合]查询名称的法术ID",
	},
	["LOOKUPFULL"] = {
		"\124cff00FF00/eam lookupfull(或lf) 查询名称\124r - 完整名称查询法术ID",
		"查询游戏中所有法术，并列出所有[完整符合]查询名称的法术ID",
	},
}
-- EAM Rewrite Additions (Auto-generated)
L.EAM_FRAME_SELF_AURA = "EAM - 自身光环框架"
L.EAM_FRAME_TARGET_AURA = "EAM - 目标光环框架"
L.EAM_FRAME_SPELL_COOLDOWN = "EAM - 技能冷却框架"
L.EAM_FRAME_ITEM_COOLDOWN = "EAM - 物品冷却框架"
L.EAM_FRAME_CLASS_POWER = "EAM - 职业能量框架"
L.EAM_FRAME_GROUND_EFFECT = "EAM - 地面效果框架"
L.EAM_FRAME_TOTEM = "EAM - 图腾监控框架"
L.EAM_FRAME_POS_SAVED = "位置已保存: %s, X: %.1f, Y: %.1f"
L.EAM_MOVE_MODE_ON = "已开启「多框架移动模式」！所有框架已亮起，请用鼠标左键拖拽移动它们，再次点击按钮可关闭。"
L.EAM_MOVE_MODE_OFF = "已关闭「多框架移动模式」并成功套用新排版。"
L.EAM_POWER_CLASS_POWER = "职业能量"
L.EAM_POWER_HOLY_POWER = "圣能"
L.EAM_POWER_SOUL_SHARDS = "灵魂碎片"
L.EAM_POWER_COMBO_POINTS = "连击点"
L.EAM_POWER_CHI = "真气"
L.EAM_POWER_ARCANE_CHARGES = "秘法充能"
L.EAM_POWER_RUNIC_POWER = "符文能量"
L.EAM_POWER_RAGE = "怒气"
L.EAM_POWER_FURY_PAIN = "狂怒/痛苦"
L.EAM_GROUND_SKILL_DEFAULT = "地面技能"
L.EAM_ITEM_PREFIX = "物品 "
L.EAM_OPT_POS_AND_POWER_BTN = "图标位置与能量设置"
L.EAM_OPT_ENABLE_FRAME = "启用提醒框架"
L.EAM_OPT_SHOW_SPELL_NAME = "显示法术名称"
L.EAM_OPT_SHOW_TIME_VAL = "显示倒数秒数"
L.EAM_OPT_SHOW_CHANGE_IN_OUT = "框架内外切换"
L.EAM_OPT_SHOW_FLASH = "启用全屏幕闪烁"
L.EAM_OPT_TEST_FLASH = "测试闪烁"
L.EAM_OPT_SHOW_SOUND = "启用音效警告"
L.EAM_OPT_SOUND_PREFIX = "音效: "
L.EAM_OPT_TEST_BTN = "测试"
L.EAM_OPT_ALLOW_ESC = "启用 ESC 键关闭"
L.EAM_OPT_SHOW_EXTRA_ALERT = "显示额外辅助提醒"
L.EAM_OPT_COOLDOWN_REMOVE = "冷却完成移除光环"
L.EAM_OPT_SHOW_SCD_OUTSIDE = "非战斗显示技能冷却"
L.EAM_OPT_GLOW_SCD = "可用时高亮技能冷却"
L.EAM_OPT_SHOW_DK_RUNE = "显示 DK 符文提醒"
L.EAM_OPT_ENABLE_ITEM_CD = "启用物品冷却监控"
L.EAM_OPT_ENABLE_CDM = "吸附官方冷却监控(CDM)"
L.EAM_OPT_CLOSE_BTN = "关闭设置 (Close)"
L.EAM_OPT_DEBUG_BTN = "除错诊断 (Debug)"
L.EAM_OPT_DEBUG_NOT_LOADED = "除错诊断模块尚未加载！"
L.EAM_OPT_SLIDER_ICON_SIZE = "图标大小 (Icon Size)"
L.EAM_OPT_SLIDER_ICON_SPACING = "水平间距 (Horizontal Spacing)"
L.EAM_OPT_SLIDER_VERT_SPACING = "垂直间距 (Vertical Spacing)"
L.EAM_OPT_SLIDER_DEBUFF_RED = "自身减益色度 (Self Debuff Red)"
L.EAM_OPT_SLIDER_DEBUFF_GREEN = "目标减益色度 (Target Debuff Green)"
L.EAM_OPT_SLIDER_EXECUTE_LIMIT = "斩杀血量阈值 (Execute Limit)"
L.EAM_OPT_ENABLE_EXECUTE = "启用斩杀线"
L.EAM_OPT_SLIDER_FONT_SPELL = "法术名称字型 (Spell Font)"
L.EAM_OPT_SLIDER_FONT_CD = "秒数倒数字型 (CD Font)"
L.EAM_OPT_SLIDER_FONT_STACK = "堆叠层数字型 (Stack Font)"
L.EAM_OPT_SLIDER_SHADOW_ALPHA = "倒数阴影透明度 (Shadow Alpha)"
L.EAM_OPT_DIR_TITLE = "告警框架图标成长方向设置"
L.EAM_OPT_DIR_RIGHT = "往右 (→)"
L.EAM_OPT_DIR_LEFT = "往左 (←)"
L.EAM_OPT_DIR_UP = "往上 (↑)"
L.EAM_OPT_DIR_DOWN = "往下 (↓)"
L.EAM_OPT_GROW_SELF_AURA = "自身光环成长"
L.EAM_OPT_GROW_TARGET_AURA = "目标光环成长"
L.EAM_OPT_GROW_SPELL_COOLDOWN = "技能冷却成长"
L.EAM_OPT_GROW_ITEM_COOLDOWN = "物品冷却成长"
L.EAM_OPT_GROW_GROUND_EFFECT = "地面效果成长"
L.EAM_OPT_GROW_TOTEM = "图腾监控成长"
L.EAM_OPT_GROW_CLASS_POWER = "职业能量成长"
L.EAM_OPT_TIMER_INSIDE = "秒数倒数显示在框内"
L.EAM_OPT_TIMER_ALIGN = "秒数倒数位置"
L.EAM_OPT_APPLICATIONS_ALIGN = "堆叠层数位置"
L.EAM_OPT_TEXT_LAYOUT_BTN = "倒数／堆叠位置设置"
L.EAM_OPT_POWER_MONITOR_TITLE = "职业特殊能量条件监控"
L.EAM_OPT_POWER_FRENZY = "狂暴值"
L.EAM_OPT_POWER_PET_ENERGY = "宠物能量"
L.EAM_OPT_MOVE_FRAME_BTN = "移动提醒框架"
L.EAM_OPT_MOVE_MODE_ON_PRINT = "移动模式已启动（请使用 /eam 拖拽）"
L.EAM_OPT_RESET_FRAME_BTN = "重设所有图标与位置"
L.EAM_OPT_RESET_FRAME_SUCCESS = "已将所有告警框架位置与成长方向重设为默认配置。"
L.EAM_OPT_LIST_TITLE = "法术提醒清单设置"
L.EAM_OPT_SELECT_ALL = "全部选择"
L.EAM_OPT_DESELECT_ALL = "全部取消"
L.EAM_OPT_DEFAULTS_BTN = "默认值"
L.EAM_OPT_DEFAULTS_SUCCESS = "成功加载当前职业的热门常用默认法术！"
L.EAM_OPT_DEFAULTS_FAIL = "未找到当前职业的默认法术配置。"
L.EAM_OPT_DELETE_ALL = "全部删除"
L.EAM_OPT_FILTER_ALL = "筛选: 全部法术"
L.EAM_OPT_FILTER_PREFIX = "筛选: "
L.EAM_OPT_FILTER_GENERAL = "通用技能/自定义"
L.EAM_OPT_ADD_SUCCESS = "成功新增监控提醒 [ID: %s]"
L.EAM_OPT_ADD_FAIL = "新增监控提醒失败: %s"
L.EAM_OPT_DEL_SUCCESS = "成功移除监控提醒 [ID: %s]"
L.EAM_OPT_DEL_FAIL = "移除监控提醒失败: %s"
L.EAM_OPT_ADD_BTN = "新增"
L.EAM_OPT_DEL_BTN = "删除"
L.EAM_OPT_ERR_INVALID_ID = "请输入正确的 ID！"
L.EAM_OPT_ADD_DEL_DESC = "请输入 SpellID 或 ItemID 并点击新增 / 删除。"
L.EAM_OPT_PROFILE_BTN = "Profile 导入／导出"
L.EAM_OPT_DEFAULTS_CROSS_EMPTY = "跨职业增益/减益不自动加入当前职业法术；请用批量输入加入已确认的 SpellID。"
L.EAM_OPT_DEFAULTS_EMPTY_CATEGORY = "这个分类没有可验证的职业默认法术。"
L.EAM_OPT_ADD_RECLASSIFIED = "[ID: %s] 不属于当前职业，已加入跨职业增益/减益列表。"
L.EAM_OPT_ERR_SPELL_NOT_FOUND = "找不到 SpellID %s；未加入且不会显示。"
L.EAM_OPT_BATCH_OPEN = "批量输入"
L.EAM_OPT_BATCH_TITLE = "EAM 批量法术／物品 ID"
L.EAM_OPT_BATCH_DESC = "每行或用分号分隔一个 ID；可加载当前列表复制，或粘贴后一次加入当前分类。"
L.EAM_OPT_BATCH_LOAD = "加载当前列表"
L.EAM_OPT_BATCH_SELECT = "全选复制"
L.EAM_OPT_BATCH_ADD = "一次加入"
L.EAM_OPT_BATCH_CLEAR = "清空"
L.EAM_OPT_BATCH_CLOSE = "关闭"
L.EAM_OPT_BATCH_LOADED = "已加载当前列表，可点击全选复制。"
L.EAM_OPT_BATCH_COPY_FAILED = "无法自动选择，请按 Ctrl+A、Ctrl+C。"
L.EAM_OPT_BATCH_EMPTY = "没有可加入的有效 ID。"
L.EAM_OPT_BATCH_RESULT = "完成：新增 %d、更新 %d、未更改 %d、无效 %d、移至跨职业 %d。"
L.EAM_OPT_BATCH_COMBAT = "战斗中不打开批量输入窗口。"
L.EAM_OPT_UNKNOWN = "未知"
L.EAM_OPT_COND_SPELL_ID_FORMAT = "法术 ID：%d"
L.EAM_OPT_COND_ITEM_ID_FORMAT = "物品 ID：%d"
L.EAM_OPT_COND_SPELL_NAME = "法术名称"
L.EAM_OPT_COND_STACK = "堆叠层数阈值"
L.EAM_OPT_COND_GLOW = "堆叠高亮阈值"
L.EAM_OPT_COND_CD_REMOVE = "完成后移除"
L.EAM_OPT_COND_CD_OUTSIDE = "非战斗显示"
L.EAM_OPT_COND_CD_GLOW = "可用时高亮"
L.EAM_OPT_COND_CD_GLOBAL = "全局"
L.EAM_OPT_COND_CD_OVERRIDE_ON = "覆盖：开"
L.EAM_OPT_COND_CD_OVERRIDE_OFF = "覆盖：关"
L.EAM_OPT_COND_RED_LIMIT = "倒数红字限制 (秒)"
L.EAM_OPT_COND_PRIORITY = "排序优先级 (Priority)"
L.EAM_OPT_COND_PLAYER_ONLY = "仅监控自己施放"
L.EAM_OPT_COND_VAL_TITLE = "显示光环细部数值:"
L.EAM_OPT_COND_VAL1 = "显示数值 1 (Value 1)"
L.EAM_OPT_COND_VAL2 = "显示数值 2 (Value 2)"
L.EAM_OPT_COND_VAL3 = "显示数值 3 (Value 3)"
L.EAM_OPT_COND_VAL4 = "显示数值 4 (Value 4)"
L.EAM_OPT_COND_TOOLTIP = "启用动态 Tooltip 抓取"
L.EAM_OPT_COND_MANUAL_DUR = "手动设定时间 (秒)"
L.EAM_OPT_COND_SCRAPE_BTN = "一键抓取"
L.EAM_OPT_AURA_SOUND_TITLE = "12.1 光环事件音效"
L.EAM_OPT_AURA_SOUND_ADDED = "光环新增"
L.EAM_OPT_AURA_SOUND_APPLICATIONS_INCREASED = "层数增加"
L.EAM_OPT_AURA_SOUND_REMOVED = "光环移除"
L.EAM_OPT_AURA_SOUND_INHERIT = "三项都未勾选时沿用全局音效；全局“启用音效警告”是总开关。试听只验证素材，实际触发需 PTR 真人验证。"
L.EAM_OPT_AURA_SOUND_DISABLED = "此客户端不支持 12.1 AuraSound；现有设置不会被改写。"
L.EAM_OPT_AURA_SOUND_TEST_ASSET_ONLY = "试听素材"
L.EAM_OPT_SCRAPE_SUCCESS = "成功抓取当前持续时间: %s 秒"
L.EAM_OPT_SCRAPE_FAIL = "未能在说明中解析出秒数，请手动输入。"
L.EAM_OPT_COND_SAVE_BTN = "储存设置 (Save)"
L.EAM_OPT_COND_SAVE_SUCCESS = "条件已储存。"
L.EAM_OPT_COND_CANCEL_BTN = "取消关闭 (Cancel)"
L.EAM_OPT_COMBAT_WARNING = "少年欸！战斗中暂不开启设置窗口，脱离战斗后会自动为你开启。"
L.EAM_OPT_MINIMAP_LCLICK = "左键点击: 开启/关闭设置面板"
L.EAM_OPT_MINIMAP_RCLICK = "右键点击: 开启系统除错诊断"
L.EAM_OPT_MINIMAP_MCLICK = "中键 / Shift+点击: 重置主视窗至屏幕中央"
L.EAM_OPT_MINIMAP_DRAG = "拖拽小图标可移动位置"
L.EAM_ALIGN_CENTER = "正中央"
L.EAM_ALIGN_TOP = "上方"
L.EAM_ALIGN_BOTTOM = "下方"
L.EAM_ALIGN_LEFT = "左方"
L.EAM_ALIGN_RIGHT = "右方"
L.EAM_ALIGN_TOPLEFT = "左上角"
L.EAM_ALIGN_TOPRIGHT = "右上角"
L.EAM_ALIGN_BOTTOMLEFT = "左下角"
L.EAM_ALIGN_BOTTOMRIGHT = "右下角"
L.EAM_OPT_CAT_SELF = "自身增益/减益提醒 (Self)"
L.EAM_OPT_CAT_CLASS = "跨职业增益/减益提醒 (Class)"
L.EAM_OPT_CAT_TARGET = "目标增益/减益提醒 (Target)"
L.EAM_OPT_CAT_SPELL_CD = "技能冷却监控设置 (Spell CD)"
L.EAM_OPT_CAT_ITEM_CD = "物品冷却监控设置 (Item CD)"
L.EAM_OPT_CAT_GROUND = "地面技能与效果设置 (Ground Effect)"
L.EAM_OPT_CAT_LAYOUT = "图标位置与能量设置 (Layout & Power)"
L.EAM_SLASH_HELP_OPT = "/eam opt - 开启设置"
L.EAM_SLASH_HELP_RESET = "/eam reset (或 /eam center / resetpos) - 将主视窗重置回屏幕中央"
L.EAM_SLASH_RESET_POS_SUCCESS = "已将 EAM 主视窗重置回屏幕中央。"
L.EAM_SLASH_HELP_DOCTOR = "/eam doctor - 显示 Retail/PTR API 边界诊断"
L.EAM_SLASH_HELP_VALIDATE = "/eam validate - 同 /eam doctor"
L.EAM_SLASH_HELP_DEBUG = "/eam debug - 显示除错摘要"
L.EAM_SLASH_HELP_EXPORT = "/eam export - 输出精简 AI debug 状态"
L.EAM_SLASH_HELP_ADD = "/eam add <spellID> - 新增 player aura"
L.EAM_SLASH_HELP_ADD_TARGET = "/eam add target [spellID] - 新增 target aura；无 ID 打开手动窗口"
L.EAM_SLASH_TARGET_POPUP_OPENED = "EAM：已打开目标光环手动加入窗口。"
L.EAM_SLASH_TARGET_POPUP_FAILED = "EAM：无法打开目标光环手动窗口："
L.EAM_SLASH_HELP_ADD_CD = "/eam add cd <spellID> - 新增 spell cooldown"
L.EAM_SLASH_HELP_ADD_ITEM = "/eam add item <itemID> - 新增 item cooldown"
L.EAM_SLASH_HELP_REMOVE = "/eam remove <spellID|target|cd|item> <id> - 移除 alert"
L.EAM_SLASH_NOT_INIT = "SavedVariables 尚未初始化。"
L.EAM_SLASH_OP_FAIL = "操作失败: "
L.EAM_SLASH_DEBUG_GROUND_START = "正在除错无光环地面技能 Tooltip 解析 (当前客户端语系: %s)..."
L.EAM_SLASH_DEBUG_GROUND_SUCCESS = "法术 [%d] 成功解析持续时间: |cff00ff00%s 秒|r"
L.EAM_SLASH_DEBUG_GROUND_FAIL = "法术 [%d] Tooltip 解析失败，将使用默认时间"
L.EAM_SLASH_GROUND_NOT_LOADED = "GroundEffectService 未加载！"
L.EAM_SLASH_SPECIFY_SPELLID = "请指定正确的法术 ID: /eam debug ground <spellID>"
L.EAM_OPT_FLOW_TEST_BTN = "流程测试"
L.EAM_SLASH_HELP_TEST = "/eam test [quick|core|boundary|all] - 打开或执行流程验证"
L.EAM_SLASH_HELP_UNITPOWER = "/eam unitpower background <RESOURCE_KEY> - 标记背景资源缺少事件，启用共享 sampler"
L.EAM_SLASH_RESOURCE_SAMPLER_MARKED = "EAM：已为背景资源 %s 启用共享 sampler。"
L.EAM_SLASH_RESOURCE_SAMPLER_FAILED = "EAM：无法启用资源 sampler："
L.EAM_FLOW_PANEL_TITLE = "EAM 流程验证与开发回灌"
L.EAM_FLOW_PANEL_DESC = "离线 Mock 与 Retail/PTR 实机共用案例。Mock 通过不代表实机通过。"
L.EAM_FLOW_BUTTON_QUICK = "快速流程"
L.EAM_FLOW_BUTTON_CORE = "核心流程"
L.EAM_FLOW_BUTTON_BOUNDARY = "边界流程"
L.EAM_FLOW_BUTTON_AURA121 = "12.1 Aura"
L.EAM_OPT_AURA_BACKEND = "Aura 后端: "
L.EAM_OPT_AURA_PENDING = "（等待脱战）"
L.EAM_OPT_AURA_REBUILD = "重建"
L.EAM_OPT_AURA_SETTINGS_DIRTY = "（待应用）"
L.EAM_OPT_AURA_APPLY = "应用"
L.EAM_FLOW_BUTTON_ALL = "执行全部"
L.EAM_FLOW_BUTTON_COPY = "全选开发报告"
L.EAM_FLOW_BUTTON_CLOSE = "关闭"
L.EAM_FLOW_STATUS_NO_REPORT = "暂无流程测试报告。"
L.EAM_FLOW_STATUS_SUMMARY = "完成：通过 %d、失败 %d、跳过 %d。"
L.EAM_FLOW_STATUS_COPIED = "报告已全选；请按 Ctrl+C 复制后回灌至开发环境。"
L.EAM_FLOW_STATUS_COMBAT = "战斗中不执行流程测试。"
L.EAM_FLOW_STATUS_UNAVAILABLE = "流程测试模块尚未加载。"
L.EAM_FLOW_STATUS_RUNNING = "流程测试执行中……"
L.EAM_FLOW_STATUS_START_FAILED = "无法启动流程测试：%s"
L.EAM_FLOW_STATUS_DEFERRED = "流程测试面板将在脱离战斗后打开。"
-- EAM Spec Filter Additions (Auto-generated)
L.EAM_OPT_FILTER_ALL_VAL = "全部法术"

L.EAM_TOOLTIP_SPELL_ID = "EAM 法术 ID"
L.EAM_TOOLTIP_ITEM_ID = "EAM 物品 ID"
L.EAM_TOOLTIP_MACRO_ID = "EAM 宏 ID"
L.EAM_TOOLTIP_OPEN_HINT = "按下 Ctrl+Alt 打开 EAM 监控菜单"
L.EAM_TOOLTIP_MACRO_MANUAL_HINT = "无法安全解析宏来源；按下 Ctrl+Alt 手动输入监控 ID"
L.EAM_TOOLTIP_AURA_HINT = "Aura ID 由暴雪显示；按下 Ctrl+Alt 打开 EAM"
L.EAM_TOOLTIP_AURA_MANUAL_HINT = "官方 Aura ID 显示不可用；按下 Ctrl+Alt 打开 EAM 手动输入"
L.EAM_POPUP_TITLE = "EAM 添加监控"
L.EAM_POPUP_ID_UNRESOLVED = "尚未解析"
L.EAM_POPUP_DESC_SPELL = "法术 ID：%s"
L.EAM_POPUP_DESC_ITEM = "物品 ID：%s"
L.EAM_POPUP_DESC_AURA = "请输入 Tooltip 显示的 Aura 法术 ID，再选择监控单位。"
L.EAM_POPUP_DESC_AURA_MANUAL = "暴雪官方 Aura ID 显示目前不可用。请输入已知的 Aura 法术 ID，再选择监控单位。"
L.EAM_POPUP_DESC_MACRO = "宏 ID：%s\n法术 ID：%s\n物品 ID：%s"
L.EAM_POPUP_ID_INPUT = "监控 ID"
L.EAM_POPUP_ADD_SPELL = "添加技能冷却监控"
L.EAM_POPUP_ADD_ITEM = "添加物品冷却监控"
L.EAM_POPUP_ADD_AURA_PLAYER = "添加玩家光环监控"
L.EAM_POPUP_ADD_AURA_TARGET = "添加目标光环监控"
L.EAM_POPUP_CANCEL = "取消"
L.EAM_POPUP_STATUS_ADDED = "已添加监控"
L.EAM_POPUP_STATUS_UPDATED = "已更新监控"
L.EAM_POPUP_STATUS_UNCHANGED = "已在监控列表"
L.EAM_POPUP_RESULT = "EAM：%s（ID %d）"
L.EAM_POPUP_RESULT_FAILED = "EAM：无法添加监控（%s）"

L.EAM_PLACEMENT_INSIDE_CENTER = "框内中央"
L.EAM_PLACEMENT_INSIDE_TOP = "框内上方"
L.EAM_PLACEMENT_INSIDE_TOP_RIGHT = "框内右上"
L.EAM_PLACEMENT_INSIDE_RIGHT = "框内右侧"
L.EAM_PLACEMENT_INSIDE_BOTTOM_RIGHT = "框内右下"
L.EAM_PLACEMENT_INSIDE_BOTTOM = "框内下方"
L.EAM_PLACEMENT_INSIDE_BOTTOM_LEFT = "框内左下"
L.EAM_PLACEMENT_INSIDE_LEFT = "框内左侧"
L.EAM_PLACEMENT_INSIDE_TOP_LEFT = "框内左上"
L.EAM_PLACEMENT_OUTSIDE_TOP_AT_LEFT = "左上外侧（上）"
L.EAM_PLACEMENT_OUTSIDE_LEFT_AT_TOP = "左上外侧（左）"
L.EAM_PLACEMENT_OUTSIDE_TOP = "框外上方"
L.EAM_PLACEMENT_OUTSIDE_TOP_AT_RIGHT = "右上外侧（上）"
L.EAM_PLACEMENT_OUTSIDE_RIGHT_AT_TOP = "右上外侧（右）"
L.EAM_PLACEMENT_OUTSIDE_RIGHT = "框外右侧"
L.EAM_PLACEMENT_OUTSIDE_RIGHT_AT_BOTTOM = "右下外侧（右）"
L.EAM_PLACEMENT_OUTSIDE_BOTTOM_AT_RIGHT = "右下外侧（下）"
L.EAM_PLACEMENT_OUTSIDE_BOTTOM = "框外下方"
L.EAM_PLACEMENT_OUTSIDE_BOTTOM_AT_LEFT = "左下外侧（下）"
L.EAM_PLACEMENT_OUTSIDE_LEFT_AT_BOTTOM = "左下外侧（左）"
L.EAM_PLACEMENT_OUTSIDE_LEFT = "框外左侧"

L.EAM_LIVE_CASE_AURA_SINGLE_COUNTDOWN = "光环正常模式仅一套倒计时"
L.EAM_LIVE_CASE_AURA_DUAL_COUNTDOWN = "光环双倒计时诊断同步"
L.EAM_LIVE_CASE_SPELL_COOLDOWN = "法术冷却图标与倒计时"
L.EAM_LIVE_CASE_ITEM_COOLDOWN = "物品冷却事件触发"
L.EAM_LIVE_CASE_GROUND_AUTO = "地面效果自动解析秒数"
L.EAM_LIVE_CASE_GROUND_FALLBACK = "地面效果手动秒数后备"
L.EAM_LIVE_CASE_SWIPE_ALPHA = "倒计时转圈透明度"
L.EAM_LIVE_CASE_TARGET_AURA_TRANSITION = "目标光环生命周期转换"
L.EAM_LIVE_CASE_NATIVE_BORDER = "12.1 原生光环边框能力"
L.EAM_LIVE_CASE_DURATION_ZERO = "PTR8 duration 0 修正"
L.EAM_LIVE_CASE_UNITPOWER_COMBAT = "UnitPower 战斗延后"
L.EAM_LIVE_CASE_CONTAINER_DISABLE_CLEAR = "12.1 停用容器清除"
L.EAM_LIVE_CASE_NATIVE_DISPEL_OPTIONS = "12.1 驱散边框 options"
L.EAM_LIVE_CASE_NATIVE_PANDEMIC = "12.1 Pandemic Region"
L.EAM_LIVE_CASE_UNITPOWER_SECONDARY = "次要职业资源数字显示"
L.EAM_LIVE_CASE_UNITPOWER_PRIMARY = "主要资源原生显示通道"
L.EAM_LIVE_CASE_AURA_SOUND_ADDED = "AuraSound 光环新增"
L.EAM_LIVE_CASE_AURA_SOUND_APPLICATIONS = "AuraSound 层数增加"
L.EAM_LIVE_CASE_AURA_SOUND_REMOVED = "AuraSound 光环移除"
L.EAM_FLOW_BUTTON_DUAL_COUNTDOWN = "双倒计时诊断"
L.EAM_FLOW_BUTTON_DUAL_COUNTDOWN_OFF = "关闭双倒计时"
L.EAM_FLOW_DUAL_COUNTDOWN_UNAVAILABLE = "双倒计时诊断设置当前不可用。"
L.EAM_FLOW_DUAL_COUNTDOWN_RELOAD = "诊断设置已保存；Native 容器已达到本次加载上限，请由玩家自行 /reload。"
L.EAM_FLOW_DUAL_COUNTDOWN_ENABLED = "双倒计时诊断已启用；仅供人工观察同步性，完成后请关闭。"
L.EAM_FLOW_DUAL_COUNTDOWN_DISABLED = "双倒计时诊断已关闭；正常模式只显示一套倒计时。"
L.EAM_FLOW_BUTTON_UNIT_POWER = "UnitPower 能力"
L.EAM_FLOW_BUTTON_UNIT_POWER_STOP = "停止并生成报告"
L.EAM_UNIT_POWER_PROBE_UNAVAILABLE = "UnitPower 能力探针尚未加载。"
L.EAM_UNIT_POWER_PROBE_START_FAILED = "UnitPower 测试无法启动；请先离开战斗再打开面板。"
L.EAM_UNIT_POWER_PROBE_RUNNING = "测试中：请由玩家生成／消耗资源，观察两种原生显示后标记结果。"
L.EAM_UNIT_POWER_PROBE_STOPPED = "UnitPower 能力报告已完成；请复制回传。"
L.EAM_UNIT_POWER_PROBE_TITLE = "UnitPower 原生显示能力测试"
L.EAM_UNIT_POWER_PROBE_PRIMARY = "当前主要资源"
L.EAM_UNIT_POWER_PROBE_SELECTED = "EAM 选定资源"
L.EAM_UNIT_POWER_PROBE_PASS = "显示正常"
L.EAM_UNIT_POWER_PROBE_FAIL = "显示异常"
L.EAM_UNIT_POWER_PROBE_BLOCKED = "无法测试"
L.EAM_UNIT_POWER_CLIENT_REQUIRED = "请先在真人实机回报面板选择当前实际运行的 PTR、XPTR 或正式服，再启动 UnitPower 测试。"
L.EAM_LIVE_CANCEL_SESSION = "取消当前 session"
L.EAM_LIVE_CANCEL_CONFIRM = "再次点击“取消当前 session”以确认清除本次进度。"
L.EAM_LIVE_CANCELLED = "当前 session 已取消，可以重新选择客户端。"
L.EAM_LIVE_CANCEL_FAILED = "无法取消 session：%s"
L.EAM_LIVE_CANCEL_NOT_ACTIVE = "当前没有进行中的实机 session。"
L.EAM_LIVE_COMPLETE_READY = "JSON 已完成；请按“全选实机 JSON”后再按 Ctrl+C。若要从游戏存档导入，请由玩家再次输入 /reload 或正常登出保存。"
L.EAM_PROMPT_COPY_SELECTED = "|cff20ff20诊断信息已全选；请按 Ctrl+C 复制后回报。|r"
L.EAM_COPY_SELECTION_FAILED = "无法全选报告文字；请手动点入文字框后按 Ctrl+A，再按 Ctrl+C。"
L.EAM_PROMPT_COPY_SELECT = "全选诊断信息"
L.EAM_LIVE_COPIED = "JSON 已全选；请按 Ctrl+C 复制，回报时附上 PTR／XPTR／正式服标签。"
L.EAM_LIVE_COPY = "全选实机 JSON"
L.EAM_LIVE_CASE_PROCEDURE = "测试条件／步骤：%s"
L.EAM_OPT_LANGUAGE_PREFIX = "语言："
L.EAM_OPT_LANGUAGE_RELOAD = "语言已立即应用并保存。"
L.EAM_OPT_THEME_PREFIX = "主题："
L.EAM_OPT_THEME_CHANGED = "主题已应用。"
L.EAM_OPT_THEME_COMBAT = "战斗结束后应用主题。"
L.EAM_OPT_ABOUT_BTN = "关于"
L.EAM_ABOUT_TITLE = "关于 EventAlertMod"
L.EAM_ABOUT_ADDON_VERSION = "插件版本："
L.EAM_ABOUT_AUTHOR = "作者："
L.EAM_ABOUT_API_BASELINE = "API 基准："
L.EAM_ABOUT_COMPATIBILITY = "兼容轨："
L.EAM_ABOUT_CLIENT_FORMAT = "当前客户端：%s %s (Build %s, Interface %s)"
L.EAM_ABOUT_REPOSITORY = "GitHub："
L.EAM_ABOUT_PAGES = "项目页面："
L.EAM_ABOUT_CLOSE = "关闭"
L.EAM_ABOUT_COMBAT_BLOCKED = "战斗中不打开关于窗口。"
L.EAM_ABOUT_CHANNEL_UNCONFIRMED = "未确认通道"
L.EAM_ABOUT_UNKNOWN = "未知"

L.EAM_FLOW_BUTTON_SVG = "SVG 能力"
L.EAM_FLOW_BUTTON_SVG_STOP = "停止 SVG 测试"
L.EAM_SVG_CLIENT_REQUIRED = "请先在“真人实机回报”选择当前客户端，再启动 SVG 测试。"
L.EAM_SVG_PROBE_UNAVAILABLE = "SVG 能力探针尚未加载。"
L.EAM_SVG_PROBE_START_FAILED = "SVG 测试无法启动；请先离开战斗。"
L.EAM_SVG_PROBE_RUNNING = "请确认两格 SVG 图案并分别标记目视结果。"
L.EAM_SVG_PROBE_STOPPED = "SVG 能力报告已完成；请全选后按 Ctrl+C 回灌。"
L.EAM_SVG_PROBE_TITLE = "SVG／VectorGraphics 能力测试"
L.EAM_SVG_PROBE_DESC = "两格应显示相同的青框、黄紫三角图案；请分别标记目视结果。"
L.EAM_SVG_PROBE_VECTOR = "VectorGraphics:SetSVG"
L.EAM_SVG_PROBE_TEXTURE = "Texture:SetSVG"
L.EAM_SVG_PROBE_PASS = "显示正常"
L.EAM_SVG_PROBE_FAIL = "显示异常"
L.EAM_SVG_PROBE_BLOCKED = "无法测试"
L.EAM_SVG_PROBE_FINISH = "完成并生成报告"
L.EAM_OPT_MODULES_BTN = "功能模块"
L.EAM_MODULE_PANEL_TITLE = "功能模块开关"
L.EAM_MODULE_PANEL_DESC = "停用后保留单次事件注册，但停止该模块 API 读取并清除现有提醒。"
L.EAM_MODULE_PLAYER_AURA = "玩家光环"
L.EAM_MODULE_TARGET_AURA = "目标光环"
L.EAM_MODULE_SPELL_COOLDOWN = "技能冷却"
L.EAM_MODULE_ITEM_COOLDOWN = "物品冷却"
L.EAM_MODULE_GROUND_EFFECT = "地面效果"
L.EAM_MODULE_CLASS_POWER = "职业资源"
L.EAM_MODULE_TOTEM = "图腾"
L.EAM_MODULE_TOOLTIP_MONITOR = "Tooltip 加入监控"
L.EAM_MODULE_ENABLED = "已启用"
L.EAM_MODULE_DISABLED = "已停用"
L.EAM_MODULE_STATUS_FORMAT = "%s：%s"
L.EAM_MODULE_STATUS_READY = "模块设置已就绪。"
L.EAM_MODULE_STATUS_FAILED = "应用失败："
L.EAM_MODULE_COMBAT_BLOCKED = "战斗中不打开功能模块面板。"
L.EAM_SLASH_HELP_LIST = "/eam list - 显示当前职业监控清单"
L.EAM_SLASH_HELP_LOOKUP = "/eam lookup <名称> - 查询当前职业候选"
L.EAM_SLASH_HELP_LOOKUPFULL = "/eam lookupfull <完整名称> - 精确查询当前职业候选"
L.EAM_SLASH_HELP_SHOWCAST = "/eam showcast - 开始或停止本次登录施法记录"
L.EAM_SLASH_HELP_SHOW = "/eam show/showtarget - 显示 Retail 12.1 安全替代说明"
L.EAM_SLASH_UNKNOWN_NAME = "名称尚不可用"
L.EAM_SLASH_ITEM_LABEL = "物品"
L.EAM_SLASH_LIST_HEADER = "%s 职业当前监控清单"
L.EAM_SLASH_LIST_LINE = "%s | %s | ID：%d"
L.EAM_SLASH_LIST_EMPTY = "当前职业没有监控项目。"
L.EAM_SLASH_CAST_LINE = "%s | Spell ID：%d"
L.EAM_SLASH_SHOWCAST_EMPTY = "本次登录尚未记录到玩家施法。"
L.EAM_SLASH_DISCOVERY_UNAVAILABLE = "经典探索服务尚未加载。"
L.EAM_SLASH_SHOWCAST_ENABLED = "已开始记录玩家成功施放的法术。"
L.EAM_SLASH_SHOWCAST_DISABLED = "已停止记录玩家施法。"
L.EAM_SLASH_LOOKUP_USAGE = "用法：/eam lookup <法术名称>"
L.EAM_SLASH_LOOKUP_LINE = "%s | Spell ID：%d"
L.EAM_SLASH_LOOKUP_NONE = "当前职业的有限候选中没有符合项目。"
L.EAM_SLASH_SHOW_UNSUPPORTED = "Retail 12.1 不使用旧式 UnitAura 扫描完整光环；请将鼠标移到光环图标后按 Ctrl+Alt 加入监控。"
L.EAM_SLASH_AUTOADD_UNSUPPORTED = "Retail 12.1 不自动写入扫描结果；请通过 Tooltip 的 Ctrl+Alt 窗口确认后加入。"

L.EAM_SLASH_HELP_PROFILE = "/eam profile [export|import] - 打开职业 profile JSON/Base64 分享"
L.EAM_PROFILE_CODEC_TITLE = "EAM 职业 Profile 分享"
L.EAM_PROFILE_CODEC_DESC = "粘贴 EAMAP1: payload，先预览，再选择合并或替换。Base64 不是加密。"
L.EAM_PROFILE_CODEC_EXPORT = "导出当前职业"
L.EAM_PROFILE_CODEC_PREVIEW = "预览导入"
L.EAM_PROFILE_CODEC_MERGE = "合并应用"
L.EAM_PROFILE_CODEC_REPLACE = "替换应用"
L.EAM_PROFILE_CODEC_SELECT = "全选复制"
L.EAM_PROFILE_CODEC_CLOSE = "关闭"
L.EAM_PROFILE_CODEC_COMBAT = "战斗中无法打开 profile 分享。"
L.EAM_PROFILE_CODEC_STATUS_UNAVAILABLE = "Profile codec 尚未加载。"
L.EAM_PROFILE_CODEC_STATUS_SELECTED = "已全选 payload；请按 Ctrl+C 复制。"
L.EAM_PROFILE_CODEC_STATUS_SELECT_FAILED = "无法自动全选，请按 Ctrl+A、Ctrl+C。"
L.EAM_PROFILE_CODEC_STATUS_FAILED = "Profile 操作失败：%s"
L.EAM_PROFILE_CODEC_STATUS_EXPORTED = "已导出 %s 个监控；编码后端：%s。请全选并复制 payload。"
L.EAM_PROFILE_CODEC_STATUS_APPLIED = "已应用：新增 %d、更新 %d、未变更 %d、移除 %d。"
L.EAM_PROFILE_SEC_SELF = "自身光环"
L.EAM_PROFILE_SEC_TARGET = "目标光环"
L.EAM_PROFILE_SEC_SPELL_CD = "技能冷却"
L.EAM_PROFILE_SEC_ITEM_CD = "物品冷却"
L.EAM_PROFILE_SEC_GROUND = "地面效果"
L.EAM_PROFILE_SEC_LAYOUT = "框架排版位置"
L.EAM_PROFILE_SEC_RESOURCE = "职业资源设置"
L.EAM_PROFILE_SEC_CONFIG = "一般偏好设置"
L.EAM_PROFILE_BTN_SELECT_ALL = "全选"
L.EAM_PROFILE_BTN_ALERTS_ONLY = "仅告警清单"
L.EAM_PROFILE_BTN_LAYOUT_ONLY = "仅排版设置"

L.EAM_OPT_FONT_PREFIX = "字体："
L.EAM_OPT_FONT_STANDARD = "客户端标准字体"
L.EAM_OPT_FONT_ARIALN = "Arial Narrow"
L.EAM_OPT_FONT_MORPHEUS = "Morpheus"
L.EAM_OPT_FONT_SKURRI = "Skurri"


L.EAM_THEME_EAM = "EAM"
L.EAM_THEME_FF7 = "FF7"
L.EAM_THEME_WINXP = "Windows XP"
L.EAM_THEME_WIN7 = "Windows 7"
L.EAM_THEME_WIN10 = "Windows 10"
L.EAM_THEME_WIN31 = "Windows 3.1"
L.EAM_THEME_BORLAND = "Borland C++ IDE"
L.EAM_THEME_DOSCRT = "DOS CRT"
L.EAM_THEME_ETEN = "倚天中文"
L.EAM_THEME_REDALERT = "红色警戒"
L.EAM_THEME_AQUA = "macOS Aqua"
L.EAM_RESOURCE_PANEL_TITLE = "玩家职业资源"
L.EAM_RESOURCE_PANEL_DESC = "每种资源独立设置；Secret 资源只送入原生视觉，不显示 Lua 数字。"
L.EAM_RESOURCE_OPTIONS_ENTRY_DESC = "各资源可按职业／专精独立设置；Secret 资源只使用原生视觉。"
L.EAM_RESOURCE_OPEN = "打开玩家资源设置"
L.EAM_CHARGE_BAR_TITLE = "充能技能剩余次数条"
L.EAM_CHARGE_BAR_LAYOUT = "显示位置／样式"
L.EAM_CHARGE_BAR_BOTTOM = "图标下方"
L.EAM_CHARGE_BAR_TOP = "图标上方"
L.EAM_CHARGE_BAR_LEFT = "图标左侧（纵向）"
L.EAM_CHARGE_BAR_RIGHT = "图标右侧（纵向）"
L.EAM_CHARGE_BAR_RING = "环形"
L.EAM_CHARGE_BAR_LENGTH = "长度／环径（图标 %）"
L.EAM_CHARGE_BAR_THICKNESS = "厚度（px）"
L.EAM_CHARGE_BAR_HINT = "分段代表剩余可用次数；恢复时间只显示在冷却转圈。"
L.EAM_RESOURCE_OPTIONS_STATUS = "当前追踪 %d 种玩家资源。"
L.EAM_RESOURCE_SCOPE_SPEC = "当前专精覆盖"
L.EAM_RESOURCE_SCOPE_CLASS = "职业默认"
L.EAM_RESOURCE_CAPABILITY_NUMERIC = "NUMERIC：可安全显示数字"
L.EAM_RESOURCE_CAPABILITY_SECRET = "SECRET_DISPLAY：仅原生视觉"
L.EAM_RESOURCE_CAPABILITY_UNAVAILABLE = "UNAVAILABLE：当前不可用"
L.EAM_RESOURCE_NONE = "没有可设置的玩家资源"
L.EAM_RESOURCE_ENABLED = "启用此资源"
L.EAM_RESOURCE_SHOW_FOREGROUND = "作为前景时显示"
L.EAM_RESOURCE_SHOW_BACKGROUND = "作为背景时显示"
L.EAM_RESOURCE_SHOW_VALUE = "显示安全数字"
L.EAM_RESOURCE_VALUE_FONT_SIZE = "数字文字大小"
L.EAM_RESOURCE_VALUE_OFFSET_X = "数字文字水平偏移"
L.EAM_RESOURCE_VALUE_OFFSET_Y = "数字文字垂直偏移"
L.EAM_RESOURCE_FONT_SIZE = "资源名称文字大小"
L.EAM_RESOURCE_FONT_FAMILY = "字型"
L.EAM_RESOURCE_ORIENTATION = "方向"
L.EAM_RESOURCE_ORIENTATION_HORIZONTAL = "水平"
L.EAM_RESOURCE_ORIENTATION_VERTICAL = "垂直"
L.EAM_RESOURCE_DISPLAY_MODE = "显示模式"
L.EAM_RESOURCE_MODE_AUTO = "自动"
L.EAM_RESOURCE_MODE_BAR = "资源条"
L.EAM_RESOURCE_MODE_POINTS = "资源点"
L.EAM_RESOURCE_OFFSET_X = "水平位置"
L.EAM_RESOURCE_OFFSET_Y = "垂直位置"
L.EAM_RESOURCE_ANCHOR = "父框架锚点"
L.EAM_RESOURCE_POSITION = "资源框架定位点"
L.EAM_RESOURCE_SCALE = "缩放"
L.EAM_RESOURCE_ALPHA = "整体透明度"
L.EAM_RESOURCE_FOREGROUND_ALPHA = "前景透明度"
L.EAM_RESOURCE_BACKGROUND_ALPHA = "背景资源透明度"
L.EAM_RESOURCE_BAR_WIDTH = "资源条宽度"
L.EAM_RESOURCE_BAR_HEIGHT = "资源条高度"
L.EAM_RESOURCE_ICON_SIZE = "图标大小"
L.EAM_RESOURCE_SPACING = "图标与资源条间距"
L.EAM_RESOURCE_ORDER = "显示顺序"
L.EAM_RESOURCE_STATUS_READY = "玩家资源设置已就绪。"
L.EAM_RESOURCE_STATUS_UPDATED = "资源设置已更新。"
L.EAM_RESOURCE_STATUS_UNCHANGED = "设置没有变化。"
L.EAM_RESOURCE_STATUS_FAILED = "应用失败："
L.EAM_RESOURCE_APPLY = "应用"
L.EAM_RESOURCE_RESET_SPEC = "清除专精覆盖"
L.EAM_RESOURCE_COMBAT_BLOCKED = "战斗中不打开玩家资源设置。"
L.EAM_RESOURCE_MANA = "法力"
L.EAM_RESOURCE_RAGE = "怒气"
L.EAM_RESOURCE_FOCUS = "集中值"
L.EAM_RESOURCE_ENERGY = "能量"
L.EAM_RESOURCE_COMBO_POINTS = "连击点"
L.EAM_RESOURCE_RUNES = "符文"
L.EAM_RESOURCE_RUNIC_POWER = "符文能量"
L.EAM_RESOURCE_SOUL_SHARDS = "灵魂碎片"
L.EAM_RESOURCE_LUNAR_POWER = "星界能量"
L.EAM_RESOURCE_HOLY_POWER = "圣能"
L.EAM_RESOURCE_MAELSTROM = "漩涡值"
L.EAM_RESOURCE_CHI = "真气"
L.EAM_RESOURCE_INSANITY = "狂乱值"
L.EAM_RESOURCE_ARCANE_CHARGES = "奥术充能"
L.EAM_RESOURCE_FURY = "恶魔之怒"
L.EAM_RESOURCE_PAIN = "痛苦值"
L.EAM_RESOURCE_ESSENCE = "精华"
L.EAM_PROMPT_TITLE = "EAM 系统诊断与调试信息导出"
L.EAM_PROMPT_REFRESH = "刷新"
L.EAM_PROMPT_CLOSE = "关闭窗口"
L.EAM_OPT_CAT_RESOURCE = "★ 玩家职业资源设置 (Player Resource)"
L.EAM_OPT_DEBUG_CENTER_BTN = "除错与测试诊断中心"
L.EAM_DEBUG_CENTER_TITLE = "除错与测试诊断中心"
L.EAM_DEBUG_TAB_RUNTIME = "实时后端状态"
L.EAM_DEBUG_TAB_RUNE = "DK 符文诊断"
L.EAM_DEBUG_TAB_FLOW = "流程测试运行"
L.EAM_DEBUG_TAB_EXPORT = "系统诊断导出"
L.EAM_DEBUG_STATUS_REFRESHED = "已更新实时后端状态。"
L.EAM_DEBUG_STATUS_RUNE_REFRESHED = "已更新 DK 符文诊断数据。"
L.EAM_DEBUG_STATUS_RUNNING_TESTS = "正在执行流程与单元测试..."
L.EAM_DEBUG_STATUS_EXPORTING = "正在生成诊断报告..."
L.EAM_DEBUG_BTN_REFRESH = "刷新状态"
L.EAM_DEBUG_BTN_RUNE_PROBE = "实时探针检测"
L.EAM_DEBUG_BTN_RUN_TESTS = "执行流程测试"
L.EAM_DEBUG_BTN_GENERATE_EXPORT = "生成诊断报告"
L.EAM_DEBUG_BTN_SELECT_ALL = "全选复制"
L.EAM_OPT_CAT_STAT = "★ 角色属性与吸收量监控 (Player Stats)"
L.EAM_STAT_OPEN = "★ 角色属性与吸收量监控 (Player Stats)"
L.EAM_STAT_PANEL_TITLE = "★ 角色属性与吸收量监控 (Player Stats & Absorbs)"
L.EAM_MODULE_PLAYER_STAT = "角色属性与吸收量监控"
L.EAM_FRAME_PLAYER_STAT = "EAM - 角色属性与吸收量框架"
L.EAM_STAT_ENABLE = "启用此属性监控"
L.EAM_STAT_SHOW_ICON = "显示图标"
L.EAM_STAT_SHOW_STATUSBAR = "进度条"
L.EAM_STAT_ICON_SIZE = "图标大小 (Icon Size)"
L.EAM_STAT_FONT_VALUE = "数值字号大小"
L.EAM_STAT_FONT_LABEL = "名称字号大小"
L.EAM_STAT_CUSTOM_LABEL = "名称替代文本 (自定义):"
L.EAM_STAT_DECIMALS = "小数位数 (0 ~ 2):"
L.EAM_STAT_SHORT_NUMBER = "大数值简写 (k/M)"
L.EAM_STAT_MIN_THRESH = "低于此值红框警戒:"
L.EAM_STAT_MAX_THRESH = "高于此值红框警戒:"
L.EAM_STAT_MOVE_BTN = "移动属性框架"
L.EAM_STAT_SAVED = "已保存 [%s] 属性监控设置。"
L.EAM_STAT_COMBAT_BLOCKED = "战斗中不开启属性监控设置面板。"
L.EAM_STAT_STRENGTH = "力量"
L.EAM_STAT_AGILITY = "敏捷"
L.EAM_STAT_STAMINA = "耐力"
L.EAM_STAT_INTELLECT = "智力"
L.EAM_STAT_CRIT = "爆击"
L.EAM_STAT_HASTE = "急速"
L.EAM_STAT_MASTERY = "精通"
L.EAM_STAT_VERSATILITY = "全能"
L.EAM_STAT_AVOIDANCE = "闪避"
L.EAM_STAT_LEECH = "吸血"
L.EAM_STAT_SPEED_RATING = "速度 (属性)"
L.EAM_STAT_RUN_SPEED = "跑速"
L.EAM_STAT_SWIM_SPEED = "泳速"
L.EAM_STAT_FLIGHT_SPEED = "飞速"
L.EAM_STAT_SKYRIDING_SPEED = "驭龙模式飞速"
L.EAM_STAT_TOTAL_ABSORB = "总吸收盾量"
L.EAM_STAT_HEAL_ABSORB = "治疗吸收量"
L.EAM_STAT_ARMOR = "护甲值"
L.EAM_OPT_CUSTOM_ICON_LABEL = "自定义替代图标 (代码或材质路径):"
L.EAM_OPT_CUSTOM_ICON_HINT = "可在 WoW.tools / Wago Tools 查询图标代码与路径:"
end)
