----------------------------------------------------
-- Translation ZamestoTV
-----------------------------------------------------
local _
local _G = _G
local addonName, G = ... 
_G[addonName] = _G[addonName] or G
-----------------------------------
if LibDebug then LibDebug() end
-----------------------------------

if GetLocale() == "ruRU" then 
EA_SPELL_POWER_NAME =	{
	Health			=	"Здоровье",
	Mana			=	"Мана",
	Happiness		=	"Настроение",
	Energy			=	"Энергия",
	Rage			=	"Ярость",
	Focus			=	"Концентрация",
	FocusPet		=	"Концентрация питомца",
	RunicPower		=	"Сила рун",
	Runes			=	"Руны",
	Pain			=	"Боль",
	Fury			=	"Энергия неистовства",
	ComboPoints		=	"Приёмы",
	LunarPower		=	"Астральная сила",
	HolyPower		=	"Сила Света",
	ArcaneCharges	=	"Чародейские заряды",
	Insanity		=	"Безумие",
	Maelstrom		=	"Энергия водоворота",
	SoulShards		=	"Осколки души",
	Chi				=	"Ци",	
	DemonicFury		=	"Демоническая ярость",
	BurningEmbers	=	"Пылающие угли",
	LifeBloom		=	"Жизнецвет",
	Essence			=	"Сущность",
	Vigor			=	"Бодрость",
	}
	
EA_TTIP_SPECFLAG_CHECK = {}
for k,v in pairs(EA_SPELL_POWER_NAME) do
	EA_TTIP_SPECFLAG_CHECK[k]="Вкл/Выкл отображение "..v.." рядом с фреймом собственных баффов"
end		

EA_XGRPALERT_POWERTYPE = "Тип энергии:"
EA_XGRPALERT_POWERTYPES = {}
for k,v in pairs(EA_SPELL_POWER_NAME) do
	EA_XGRPALERT_POWERTYPES[#EA_XGRPALERT_POWERTYPES + 1]={}
	EA_XGRPALERT_POWERTYPES[#EA_XGRPALERT_POWERTYPES].text  = v
	EA_XGRPALERT_POWERTYPES[#EA_XGRPALERT_POWERTYPES].value = Enum.PowerType[k]	
end
		
EA_TTIP_DOALERTSOUND = "Воспроизводить звук при срабатывании события."
EA_TTIP_ALERTSOUNDSELECT = "Выбрать звук, проигрываемый при срабатывании события."
EA_TTIP_LOCKFRAME = "Заблокировать фрейм оповещений от перемещения мышкой."
EA_TTIP_SHARESETTINGS = "Использовать одинаковые позиции фреймов для всех классов."
EA_TTIP_SHOWFRAME = "Показать/скрыть фрейм оповещений при срабатывании события."
EA_TTIP_SHOWNAME = "Показать/скрыть название заклинания при срабатывании события."
EA_TTIP_SHOWFLASH = "Показать/скрыть полноэкранную вспышку при срабатывании события."
EA_TTIP_SHOWTIMER = "Показать/скрыть оставшееся время заклинания при срабатывании события."
EA_TTIP_CHANGETIMER = "Изменить размер и положение шрифта оставшегося времени."
EA_TTIP_ICONSIZE = "Изменить размер иконок оповещений."
-- EA_TTIP_ICONSPACE = "变更提示的图示间距."
-- EA_TTIP_ICONDROPDOWN = "变更提示的图示延展方向."
EA_TTIP_ALLOWESC = "Разрешить закрывать фрейм оповещений клавишей ESC (требует перезагрузки UI)."
EA_TTIP_ALTALERTS = "Включить/отключить оповещения EventAlertMod о дополнительных событиях (не баффы/дебаффы)."

EA_TTIP_ICONXOFFSET = "Настройка горизонтального расстояния фрейма оповещений."
EA_TTIP_ICONYOFFSET = "Настройка вертикального расстояния фрейма оповещений."
EA_TTIP_ICONREDDEBUFF = "Настройка насыщенности красного цвета иконок собственных дебаффов."
EA_TTIP_ICONGREENDEBUFF = "Настройка насыщенности зелёного цвета иконок дебаффов цели."
EA_TTIP_ICONEXECUTION = "Настройка порога добивания для боссов (0% — отключить)."
EA_TTIP_PLAYERLV2BOSS = "Применять порог добивания к мобам на 2 уровня выше (например, боссы 5-перс. подземелий)."
EA_TTIP_SCD_USECOOLDOWN = "Использовать тень перезарядки для отката способностей (требует перезагрузки UI)."
EA_TTIP_TAR_NEWLINE = "Отображать дебаффы цели отдельной строкой."
EA_TTIP_TAR_ICONXOFFSET = "Горизонтальное расстояние строки дебаффов цели от фрейма оповещений."
EA_TTIP_TAR_ICONYOFFSET = "Вертикальное расстояние строки дебаффов цели от фрейма оповещений."
EA_TTIP_TARGET_MYDEBUFF = "Показывать в строке дебаффов цели только те, что наложены игроком."
EA_TTIP_SPELLCOND_STACK = "Вкл/Выкл отображение фрейма только при достижении указанного количества стаков (мин. 2)."
EA_TTIP_SPELLCOND_SELF = "Вкл/Выкл — отслеживать только заклинания, наложенные игроком."
EA_TTIP_SPELLCOND_OVERGROW = "Вкл/Выкл — подсвечивать иконку при достижении указанного количества стаков (мин. 1)."
EA_TTIP_SPELLCOND_REDSECTEXT = "Вкл/Выкл — увеличивать и красить текст таймера, когда осталось ≤ указанных секунд (мин. 1)."
EA_TTIP_SPELLCOND_ORDERWTD = "Вкл/Выкл — приоритет отображения (чем выше число, тем ближе к центру, 1–20)."

EA_TTIP_SPELLCOND_AURAVALUE1 = "Вкл/Выкл отображение значения ауры 1 (можно задать метку справа)."
EA_TTIP_SPELLCOND_AURAVALUE2 = "Вкл/Выкл отображение значения ауры 2 (можно задать метку справа)."
EA_TTIP_SPELLCOND_AURAVALUE3 = "Вкл/Выкл отображение значения ауры 3 (можно задать метку справа)."
EA_TTIP_SPELLCOND_AURAVALUE4 = "Вкл/Выкл отображение значения ауры 4 (можно задать метку справа)."  

EA_TTIP_GRPCFG_ICONALPHA = "Изменить прозрачность иконок."
EA_TTIP_GRPCFG_TALENT = "Действует только для выбранной специализации."
EA_TTIP_GRPCFG_HIDEONLEAVECOMBAT = "Скрывать иконки после выхода из боя."
EA_TTIP_GRPCFG_HIDEONLOSTTARGET = "Скрывать иконки без цели."
EA_TTIP_GRPCFG_GLOWWHENTRUE = "Подсвечивать иконку при выполнении условия."

EA_TTIP_SCD_REMOVEWHENCOOLDOWN = "Убирать иконку способности на откате."
EA_TTIP_SCD_GLOWWHENUSABLE = "Подсвечивать иконку SCD, когда способность готова."
EA_TTIP_SCD_NOCOMBATSTILLKEEP = "Показывать иконки SCD даже вне боя."   
EA_TTIP_SCD_ITEMCOOLDOWN = "Включить отслеживание перезарядки предметов (влияет на производительность, требуется перезагрузка UI)."
EA_TTIP_SHOWRUNESBAR = "Показывать панель рун над баффами."

EA_TTIP_SNAMEFONTSIZE = "Размер шрифта названия заклинания (влияет на значения аур)."
EA_TTIP_TIMERFONTSIZE = "Размер шрифта таймера."
EA_TTIP_STACKFONTSIZE = "Размер шрифта количества стаков."


EA_XOPT_SCD_REMOVEWHENCOOLDOWN = "Убирать иконку способности на откате."
EA_XOPT_SCD_GLOWWHENUSABLE = "Подсвечивать иконку SCD, когда способность готова."
EA_XOPT_SCD_NOCOMBATSTILLKEEP = "Показывать иконки SCD даже вне боя."
EA_XOPT_SCD_ITEMCOOLDOWN = "Включить отслеживание перезарядки предметов."                   

EA_XOPT_SHOWRUNESBAR = "Показывать панель рун DK."


EA_XOPT_ICONPOSOPT = "Позиция иконок и второстепенные ресурсы"
EA_XOPT_SHOW_ALTFRAME = "Показать основной фрейм оповещений"
EA_XOPT_SHOW_BUFFNAME = "Показать название заклинания"
EA_XOPT_SHOW_TIMER = "Показать таймер"
EA_XOPT_SHOW_OMNICC = "Таймер внутри фрейма"
EA_XOPT_SHOW_FULLFLASH = "Полноэкранная вспышка"
EA_XOPT_PLAY_SOUNDALERT = "Звуковое оповещение"
EA_XOPT_ESC_CLOSEALERT = "ESC закрывает оповещение"
EA_XOPT_SHOW_ALTERALERT = "Дополнительные оповещения"
EA_XOPT_SHOW_CHECKLISTALERT = "Включить"
EA_XOPT_SHOW_CLASSALERT = "Текущий класс — баффы/дебаффы"
EA_XOPT_SHOW_OTHERALERT = "Другие классы — баффы/дебаффы"
EA_XOPT_SHOW_TARGETALERT = "Цель — баффы/дебаффы"
EA_XOPT_SHOW_SCDALERT = "Текущий класс — откат способностей"
EA_XOPT_SHOW_GROUPALERT = "Текущий класс — условные способности"
EA_XOPT_OKAY = "Закрыть"
EA_XOPT_SAVE = "Сохранить"
EA_XOPT_CANCEL = "Отмена"
EA_XOPT_VERURLTEXT = "Страница EAM:\nwww.curseforge.com/wow/addons/eventalertmod"
EA_XOPT_VERBTN1 = "CurseForge"
EA_XOPT_VERURL1 = "http://www.curseforge.com/wow/addons/eventalertmod"

EA_XOPT_SPELLCOND_STACK = "Показывать фрейм при стаках ≥:"
EA_XOPT_SPELLCOND_SELF = "Только заклинания, наложенные игроком"
EA_XOPT_SPELLCOND_OVERGROW = "Подсвечивать при стаках ≥:"
EA_XOPT_SPELLCOND_REDSECTEXT = "Красный таймер при остатке ≤ сек:"
EA_XOPT_SPELLCOND_ORDERWTD   = "Приоритет отображения (1-20):"

EA_XOPT_SPELLCOND_AURAVALUE1 = "Показать значение ауры 1"
EA_XOPT_SPELLCOND_AURAVALUE2 = "Показать значение ауры 2"
EA_XOPT_SPELLCOND_AURAVALUE3 = "Показать значение ауры 3"
EA_XOPT_SPELLCOND_AURAVALUE4 = "Показать значение ауры 4"

EA_XICON_LOCKFRAME = "Заблокировать пример фрейма"
EA_XICON_LOCKFRAMETIP = "Чтобы перемещать фрейм оповещений или сбросить его позицию, снимите галочку «Заблокировать пример фрейма»."
EA_XICON_SHARESETTING = "Общие позиции фреймов"
EA_XICON_ICONSIZE = "Размер иконок"
-- EA_XICON_ICONSIZE2 = "目标图示大小"
-- EA_XICON_ICONSIZE3 = "CD图示大小"
EA_XICON_LARGE = "Большой"
EA_XICON_SMALL = "Маленький"
EA_XICON_HORSPACE = "Горизонтальный отступ"
EA_XICON_VERSPACE = "Вертикальный отступ"
-- EA_XICON_ICONSPACE1 = "自身图示间距"
-- EA_XICON_ICONSPACE2 = "目标图示间距"
-- EA_XICON_ICONSPACE3 = "CD图示间距"
EA_XICON_MORE = "Больше"
EA_XICON_LESS = "Меньше"
EA_XICON_REDDEBUFF = "Насыщенность красного для собственных дебаффов"
EA_XICON_GREENDEBUFF = "Насыщенность зелёного для дебаффов цели"
EA_XICON_DEEP = "Глубокий"
EA_XICON_LIGHT = "Светлый"
-- EA_XICON_DIRECTION = "延展方向"
-- EA_XICON_DIRUP = "上"
-- EA_XICON_DIRDOWN = "下"
-- EA_XICON_DIRLEFT = "左"
-- EA_XICON_DIRRIGHT = "右"
EA_XICON_TAR_NEWLINE = "Дебаффы цели отдельной строкой"
EA_XICON_TAR_HORSPACE = "Горизонтальный отступ строки дебаффов цели"
EA_XICON_TAR_VERSPACE = "Вертикальный отступ строки дебаффов цели"
EA_XICON_TOGGLE_ALERTFRAME = "Перемещение фрейма"
EA_XICON_RESET_FRAMEPOS = "Сбросить позиции фреймов"
EA_XICON_SELF_BUFF = "Собственные баффы"
EA_XICON_SELF_SPBUFF = "Собственные дебаффы(1)\nили особый фрейм"
EA_XICON_SELF_DEBUFF = "Собственные дебаффы"
EA_XICON_TARGET_BUFF = "Баффы цели"
EA_XICON_TARGET_SPBUFF = "Баффы цели(1)\nили особый фрейм"
EA_XICON_TARGET_DEBUFF = "Дебаффы цели"
EA_XICON_SCD = "Откат способностей"
EA_XICON_EXECUTION = "Порог добивания для боссов"
EA_XICON_EXEFULL = "100%"
EA_XICON_EXECLOSE = "Откл"
EA_XICON_SCD_USECOOLDOWN = "Тень перезарядки для отката (требует перезагрузки UI)"

EA_XICON_SNAMEFONTSIZE = "Размер шрифта названия заклинания"
EA_XICON_TIMERFONTSIZE = "Размер шрифта таймера"
EA_XICON_STACKFONTSIZE = "Размер шрифта стаков"


EX_XCLSALERT_SELALL = "Выделить все"
EX_XCLSALERT_CLRALL = "Снять всё"
EX_XCLSALERT_LOADDEFAULT = "По умолчанию"
EX_XCLSALERT_REMOVEALL = "Удалить всё"
EX_XCLSALERT_SPELL = "ID заклинания:"
EX_XCLSALERT_ADDSPELL = "Добавить"
EX_XCLSALERT_DELSPELL = "Удалить"
EX_XCLSALERT_HELP1 = "Список выше сортируется по [ID заклинания]."
EX_XCLSALERT_HELP2 = "Для поиска ID заклинания используйте команду /eam help."
EX_XCLSALERT_HELP3 = "Подробности о командах поиска заклинаний в игре."
EX_XCLSALERT_HELP4 = "Дополнительная зона — для условных способностей, не являющихся баффами."
EX_XCLSALERT_HELP5 = "Например: добивание цели или использование после парирования."
EX_XCLSALERT_HELP6 = ", способности, не отображающие бафф, но готовые к использованию."
EX_XCLSALERT_SPELLURL = "http://www.wowhead.com/spells"

EA_XTARALERT_TARGET_MYDEBUFF = "Только наложенные игроком дебаффы"

EA_XGRPALERT_ICONALPHA = "Прозрачность иконок"
EA_XGRPALERT_GRPID = "ID группы:"
EA_XGRPALERT_TALENT1 = "Спек 1"
EA_XGRPALERT_TALENT2 = "Спек 2"
EA_XGRPALERT_TALENT3 = "Спек 3"
EA_XGRPALERT_TALENT4 = "Спек 4"
EA_XGRPALERT_HIDEONLEAVECOMBAT = "Скрывать вне боя"
EA_XGRPALERT_HIDEONLOSTTARGET = "Скрывать без цели"

EA_XGRPALERT_GLOWWHENTRUE = "Подсветка при выполнении условия"

EA_XGRPALERT_TALENTS = "Любой спек"
EA_XGRPALERT_NEWSPELLBTN = "Новое заклинание"
EA_XGRPALERT_NEWCHECKBTN = "Новое родительское условие"
EA_XGRPALERT_NEWSUBCHECKBTN = "Новое дочернее условие"
EA_XGRPALERT_SPELLNAME = "Название заклинания:"
EA_XGRPALERT_SPELLICON = "Иконка заклинания:"
EA_XGRPALERT_TITLECHECK = "Родительское условие:"
EA_XGRPALERT_TITLESUBCHECK = "Дочернее условие:"
EA_XGRPALERT_TITLEORDERUP = "Повысить приоритет"
EA_XGRPALERT_TITLEORDERDOWN = "Понизить приоритет"
EA_XGRPALERT_LOGICS = {
	[1]={text="И", value=1},
	[2]={text="ИЛИ", value=0}, }
EA_XGRPALERT_EVENTTYPE = "Тип события:"
EA_XGRPALERT_EVENTTYPES = {
	[1]={text="Изменение энергии объекта", value="UNIT_POWER_UPDATE"},
	[2]={text="Изменение здоровья объекта", value="UNIT_HEALTH"},
	[3]={text="Изменение аур объекта", value="UNIT_AURA"},
	[4]={text="Изменение комбо-очков", value="UNIT_COMBO_POINTS"}, }
EA_XGRPALERT_UNITTYPE = "Объект:"
EA_XGRPALERT_UNITTYPES = {
	[1]={text="Игрок", value="player"},
	[2]={text="Цель", value="target"},
	[3]={text="Фокус", value="focus"},
	[4]={text="Питомец", value="pet"},
	[5]={text="Босс 1", value="boss1"},
	[6]={text="Босс 2", value="boss2"},
	[7]={text="Босс 3", value="boss3"},
	[8]={text="Босс 4", value="boss4"}, 
	[9]={text="Участник 1", value="party1"},
	[10]={text="Участник 2", value="party2"},
	[11]={text="Участник 3", value="party3"},
	[12]={text="Участник 4", value="party4"},
	[13]={text="Рейд 1", value="raid1"},
	[14]={text="Рейд 2", value="raid2"},
	[15]={text="Рейд 3", value="raid3"},
	[16]={text="Рейд 4", value="raid4"},
	[17]={text="Рейд 5", value="raid5"},
	[18]={text="Рейд 6", value="raid6"},
	[19]={text="Рейд 7", value="raid7"},
	[20]={text="Рейд 8", value="raid8"},
	[21]={text="Рейд 9", value="raid9"},
}

EA_XGRPALERT_CHECKCD = "Проверять откат заклинания:"

EA_XGRPALERT_HEALTH = "Здоровье:"

EA_XGRPALERT_COMPARETYPES = {
	[1]={text="Значение", value=1},
	[2]={text="Процент", value=2},
}
EA_XGRPALERT_CHECKAURA = "Аура:"
EA_XGRPALERT_CHECKAURAS = {
	[1]={text="Присутствует", value=1},
	[2]={text="Отсутствует", value=2},
}
EA_XGRPALERT_AURATIME = "Время:"
EA_XGRPALERT_AURASTACK = "Стаки:"
EA_XGRPALERT_CASTBYPLAYER = "Только наложенные игроком"
EA_XGRPALERT_COMBOPOINT = "Комбо-очки:"

EA_XLOOKUP_START1 = "Поиск названия заклинания"
EA_XLOOKUP_START2 = "Полное совпадение"
EA_XLOOKUP_RESULT1 = "Результаты поиска заклинаний"
EA_XLOOKUP_RESULT2 = "совпадений"
EA_XLOAD_LOAD = "\124cffFFFF00EventAlertMod\124r: загружено, версия:\124cff00FFFF"

EA_XLOAD_FIRST_LOAD = "\124cffFF0000Первый запуск EventAlertMod — загружены настройки по умолчанию\124r。\n\n".. 
"Используйте \124cffFFFF00/eam opt\124r для настройки параметров, заклинаний и позиций фреймов。\n\n"

EA_XLOAD_NEWVERSION_LOAD = "Используйте \124cffFFFF00/eam help\124r для подробного списка команд。\n\n\n"..
"\124cff00FFFF- Основные обновления -\124r\n\n"..
"*Новая функция: групповые оповещения с множественными условиями。\n\n"..
"Поддерживаемые события:\n"..
"1. Энергия объекта ≥ или ≤ заданного значения/процента\n"..
"2. Здоровье объекта ≥ или ≤ заданного значения/процента\n"..
"3. Наличие/отсутствие конкретного ID ауры (можно фильтровать по стакам или времени)\n"..
"4. Комбо-очки игрока по цели ≥ или ≤ заданного значения\n"..
"Все условия можно комбинировать через AND или OR。\n"..
"При выполнении условий отображается указанная иконка。\n"..
"" -- END OF NEWVERSION



EA_XCMD_VER = " \124cff00FFFFАвтор: Whitep@雷鳞\124r версия: "
EA_XCMD_DEBUG = " режим: "
EA_XCMD_SELFLIST = " Отображать собственные баффы/дебаффы: "
EA_XCMD_TARGETLIST = " Отображать дебаффы цели: "
EA_XCMD_CASTSPELL = " Отображать ID кастуемых заклинаний: "
EA_XCMD_AUTOADD_SELFLIST = " Автодобавление всех собственных баффов/дебаффов: "
EA_XCMD_ENVADD_SELFLIST = " Автодобавление собственных баффов/дебаффов (без групповых): "
EA_XCMD_DEBUG_P0 = "Список срабатывающих заклинаний"
EA_XCMD_DEBUG_P1 = "Заклинание"
EA_XCMD_DEBUG_P2 = "ID заклинания"
EA_XCMD_DEBUG_P3 = "Стаки"
EA_XCMD_DEBUG_P4 = "Осталось сек"


EA_XCMD_CMDHELP = {
	["TITLE"] = "\124cffFFFF00EventAlertMod\124r \124cff00FF00Команды\124r (/eventalertmod или /eam):",
	["OPT"] = "\124cff00FF00/eam options(или opt)\124r — открыть/закрыть окно настроек.",
	["HELP"] = "\124cff00FF00/eam help\124r — подробная справка по командам.",
	["SHOW"] = {
		"\124cff00FF00/eam show [сек]\124r —",
		"Начать/остановить вывод ID всех баффов/дебаффов на игроке, действующих ≤ указанных секунд",
	},
	["SHOWT"] = {
		"\124cff00FF00/eam showtarget(или showt) [сек]\124r —",
		"Начать/остановить вывод ID всех дебаффов на цели, действующих ≤ указанных секунд",
	},
	["SHOWC"] = {
		"\124cff00FF00/eam showcast(или showc)\124r —",
		"Начать/остановить вывод ID успешно применённых заклинаний",
	},
	["SHOWA"] = {
		"\124cff00FF00/eam showautoadd(или showa) [сек]\124r —",
		"Автодобавление в список всех баффов/дебаффов игрока, действующих ≤ указанных секунд (по умолчанию 60)",
	},
	["SHOWE"] = {
		"\124cff00FF00/eam showenvadd(или showe) [сек]\124r —",
		"Автодобавление в список баффов/дебаффов игрока (исключая групповые), действующих ≤ указанных секунд (по умолчанию 60)",
	},
	["LIST"] = {
		"\124cff00FF00/eam list\124r — показать список срабатывающих заклинаний",
		"Показать/скрыть вывод команд show, showc, showt, lookup, lookupfull",
	},
	["LOOKUP"] = {
		"\124cff00FF00/eam lookup(или l) запрос\124r — частичный поиск ID заклинаний",
		"Поиск всех заклинаний, частично совпадающих с запросом",
	},
	["LOOKUPFULL"] = {
		"\124cff00FF00/eam lookupfull(или lf) запрос\124r — полный поиск ID заклинаний",
		"Поиск всех заклинаний, полностью совпадающих с запросом",
	},
}

end
