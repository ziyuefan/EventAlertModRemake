--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Locale/koKR
檔案: Locale\koKR.lua

理念:
- 韓文語系字串表，僅作字串覆蓋。
- 語系與邏輯分離。

責任:
- 透過 Locale.register("koKR") 覆蓋 L.* keys。

資料所有權:
- 擁有 koKR key/value。

可變狀態:
- 只在載入且目前語系為 koKR 時覆蓋 EAM.L。

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

Locale.register("koKR", function(L)

L.EA_SPELL_POWER_NAME = {
		Health 				= "생명",
		Mana 				= "마나",
		Happiness 			= "기쁨 값",
		Energy 				= "에너지",
		Rage 				= "분노",
		Focus 				= "집중",
		FocusPet 			= "애완동물 집중",
		RunicPower 			= "룬 마력",
		Runes 				= "룬",
		Pain 				= "고통",
		Fury 				= "분노",
		ComboPoints 		= "연계 점수",
		LunarPower 			= "달 에너지",
		HolyPower 			= "신성한 힘",
		ArcaneCharges 		= "비전 충전",
		Insanity 			= "광기",
		Maelstrom 			= "혼돈 에너지",
		SoulShards 			= "영혼 조각",
		Chi 				= "기",
		DemonicFury 		= "악마의 분노",
		BurningEmbers 		= "불꽃 잔여",
		LifeBloom 			= "생명의 꽃",
		Essence 			= "용의 기운",
		Vigor				= "활기",     
}

L.EA_TTIP_SPECFLAG_CHECK = {}
for k,v in pairs(L.EA_SPELL_POWER_NAME) do
L.EA_TTIP_SPECFLAG_CHECK[k] = v .. "을(를) 자신의 버프 프레임에 표시"
end

L.EA_XGRPALERT_POWERTYPE = "에너지 유형:"
L.EA_XGRPALERT_POWERTYPES = {}
for k,v in pairs(L.EA_SPELL_POWER_NAME) do
L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES + 1] = {}
L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES].text = v
L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES].value = Enum.PowerType[k]
end

L.EA_TTIP_DOALERTSOUND = "이벤트 발생 시 소리 알림 여부"
L.EA_TTIP_ALERTSOUNDSELECT = "이벤트 발생 시 재생될 소리 선택"
L.EA_TTIP_LOCKFRAME = "알림 프레임 고정하여 이동 방지"
L.EA_TTIP_SHARESETTINGS = "모든 직업에서 공유되는 프레임 위치 설정"
L.EA_TTIP_SHOWFRAME = "이벤트 발생 시 알림 프레임 표시/숨기기"
L.EA_TTIP_SHOWNAME = "이벤트 발생 시 주문 이름 표시/숨기기"
L.EA_TTIP_SHOWFLASH = "이벤트 발생 시 화면 전체 반짝임 표시/숨기기"
L.EA_TTIP_SHOWTIMER = "이벤트 발생 시 주문 지속시간 표시/숨기기"
L.EA_TTIP_CHANGETIMER = "주문 지속시간 폰트 크기 및 위치 변경"
L.EA_TTIP_ICONSIZE = "알림 아이콘 크기 변경"
-- L.EA_TTIP_ICONSPACE = "알림 아이콘 간격 변경."
-- L.EA_TTIP_ICONDROPDOWN = "提示 아이콘 확장 방향 변경."
L.EA_TTIP_ALLOWESC = "ESC 키를 사용하여 팝업 창을 닫을 수 있는지 여부 변경. (참고: UI를 다시 로드해야 함)"
L.EA_TTIP_ALTALERTS = "EventAlertMod의 추가 이벤트 트리거 알림(강화/약화 효과가 아님) 켜기/끄기."

L.EA_TTIP_ICONXOFFSET = "알림 창의 수평 간격 조정."
L.EA_TTIP_ICONYOFFSET = "알림 창의 수직 간격 조정."
L.EA_TTIP_ICONREDDEBUFF = "Debuff 아이콘의 빨간 색상 강도 조정."
L.EA_TTIP_ICONGREENDEBUFF = "대상 Debuff 아이콘의 녹색 색상 강도 조정."
L.EA_TTIP_ICONEXECUTION = "보스 체력 백분율에 따른 처형 단계 조정(0%는 처형 알림 끄기)"
L.EA_TTIP_PLAYERLV2BOSS = "플레이어 레벨보다 2레벨 높은 보스(5인 던전 보스 등)에게도 보스 레벨의 처형 알림 적용"
L.EA_TTIP_SCD_USECOOLDOWN = "스킬 쿨타임 사용 대기시간을 표시하는 그림자 효과 사용(재시작하여 적용)"
L.EA_TTIP_TAR_NEWLINE = "대상 Debuff를 별도의 줄에 표시할지 여부 조정"
L.EA_TTIP_TAR_ICONXOFFSET = "대상 Debuff 줄과 알림 창의 수평 간격 조정"
L.EA_TTIP_TAR_ICONYOFFSET = "대상 Debuff 줄과 알림 창의 수직 간격 조정"
L.EA_TTIP_TARGET_MYDEBUFF = "대상 Debuff 줄에서 플레이어가 시전한 Debuff만 표시할지 여부 조정"
L.EA_TTIP_SPELLCOND_STACK = "주문 스택이 몇 층 이상일 때 프레임을 표시할지 여부 켜기/끄기\n(최소 입력 가능 값은 2부터 시작)"
L.EA_TTIP_SPELLCOND_SELF = "플레이어가 시전한 주문만 모니터링하여 다른 플레이어가 시전한 동일한 주문을 방지하기 위해 켜기/끄기"
L.EA_TTIP_SPELLCOND_OVERGROW = "주문 스택이 몇 층 이상일 때 강조 표시하여 켜기/끄기\n(최소 입력 가능 값은 1부터 시작)"
L.EA_TTIP_SPELLCOND_REDSECTEXT = "카운트 다운 시간이 몇 초 이하일 때"
L.EA_TTIP_SPELLCOND_ORDERWTD = "온/오프, 표시 순서 우선 순위 설정, 숫자가 클수록 내부 원에서 우선적으로 표시됨(1에서 20까지 입력 가능)"

L.EA_TTIP_SPELLCOND_AURAVALUE1 = "활성화/비활성화, 오라 수치 1 (오른쪽에서 라벨 입력 가능)"
L.EA_TTIP_SPELLCOND_AURAVALUE2 = "활성화/비활성화, 오라 수치 2 (오른쪽에서 라벨 입력 가능)"
L.EA_TTIP_SPELLCOND_AURAVALUE3 = "활성화/비활성화, 오라 수치 3 (오른쪽에서 라벨 입력 가능)"
L.EA_TTIP_SPELLCOND_AURAVALUE4 = "활성화/비활성화, 오라 수치 4 (오른쪽에서 라벨 입력 가능)"

L.EA_TTIP_GRPCFG_ICONALPHA = "아이콘 투명도 변경"
L.EA_TTIP_GRPCFG_TALENT = "이 전문화에만 적용"
L.EA_TTIP_GRPCFG_HIDEONLEAVECOMBAT = "전투 종료 후 아이콘 숨기기"
L.EA_TTIP_GRPCFG_HIDEONLOSTTARGET = "대상 없을 시 아이콘 숨기기"
L.EA_TTIP_GRPCFG_GLOWWHENTRUE = "조건 충족 시 아이콘 강조"  

L.EA_TTIP_SCD_REMOVEWHENCOOLDOWN = "재사용 대기시간이 끝나면 주문 아이콘 제거"
L.EA_TTIP_SCD_GLOWWHENUSABLE = "사용 가능할 때 SCD 아이콘 빛나게 표시"
L.EA_TTIP_SCD_NOCOMBATSTILLKEEP = "전투 중이 아니어도 SCD 아이콘 유지"
L.EA_TTIP_SCD_ITEMCOOLDOWN = "아이템 재사용 대기시간 감지 전환 (성능에 영향, UI를 다시 불러와야 함)"

L.EA_TTIP_SHOWRUNESBAR = "룬 바를 버프 바 위에 표시"

L.EA_TTIP_SNAMEFONTSIZE = "주문 이름 글꼴 크기 조정 (오라 수치에 영향)"
L.EA_TTIP_TIMERFONTSIZE = "카운트다운 글꼴 크기 조정"
L.EA_TTIP_STACKFONTSIZE = "중첩 수 글꼴 크기 조정"


L.EA_XOPT_SCD_REMOVEWHENCOOLDOWN = "재사용 대기시간이 끝나면 주문 아이콘 제거"
L.EA_XOPT_SCD_GLOWWHENUSABLE = "사용 가능할 때 SCD 아이콘 빛나게 표시"
L.EA_XOPT_SCD_NOCOMBATSTILLKEEP = "전투 중이 아니어도 SCD 아이콘 유지"
L.EA_XOPT_SCD_ITEMCOOLDOWN = "아이템 재사용 대기시간 감지 전환"

L.EA_XOPT_SHOWRUNESBAR = "죽기 룬 바 표시"



L.EA_XOPT_ICONPOSOPT = "아이콘 위치 및 직업 특수 에너지"
L.EA_XOPT_SHOW_ALTFRAME = "기본 프레임 표시"
L.EA_XOPT_SHOW_BUFFNAME = "주문 이름 표시"
L.EA_XOPT_SHOW_TIMER = "카운트다운 시간 표시"
L.EA_XOPT_SHOW_OMNICC = "프레임 안에 시간 표시"
L.EA_XOPT_SHOW_FULLFLASH = "전체 화면 번쩍임 알림 표시"
L.EA_XOPT_PLAY_SOUNDALERT = "소리 알림 재생"
L.EA_XOPT_ESC_CLOSEALERT = "ESC로 알림 닫기"
L.EA_XOPT_SHOW_ALTERALERT = "추가 알림 표시"
L.EA_XOPT_SHOW_CHECKLISTALERT = "사용"
L.EA_XOPT_SHOW_CLASSALERT = "직업 - 버프 및 디버프 알림"
L.EA_XOPT_SHOW_OTHERALERT = "다른 직업 - 버프 및 디버프 알림"
L.EA_XOPT_SHOW_TARGETALERT = "대상 - 버프 및 디버프 알림"
L.EA_XOPT_SHOW_SCDALERT = "직업 - 기술 재사용 대기시간 알림"
L.EA_XOPT_SHOW_GROUPALERT = "직업 - 조건 기술 알림"
L.EA_XOPT_OKAY = "닫기"
L.EA_XOPT_SAVE = "저장"
L.EA_XOPT_CANCEL = "취소"
L.EA_XOPT_VERURLTEXT = "EAM 배포 주소:\nwww.curseforge.com/wow/addons/eventalertmod"
L.EA_XOPT_VERBTN1 = "CurseForge"
L.EA_XOPT_VERURL1 = "http://www.curseforge.com/wow/addons/eventalertmod"

L.EA_XOPT_SPELLCOND_STACK = "주문 중첩이 >= 몇층일 때 프레임 표시:"
L.EA_XOPT_SPELLCOND_SELF = "플레이어가 시전한 주문에만 제한"
L.EA_XOPT_SPELLCOND_OVERGROW = "주문 중첩이 >= 몇층일 때 강조 표시:"
L.EA_XOPT_SPELLCOND_REDSECTEXT = "카운트다운 시간이 <= 몇초일 때 빨간"
L.EA_XOPT_SPELLCOND_ORDERWTD = "순서 우선 비중 표시(1-20):" 

L.EA_XOPT_SPELLCOND_AURAVALUE1 = "오라 수치 1 표시"
L.EA_XOPT_SPELLCOND_AURAVALUE2 = "오라 수치 2 표시"
L.EA_XOPT_SPELLCOND_AURAVALUE3 = "오라 수치 3 표시"
L.EA_XOPT_SPELLCOND_AURAVALUE4 = "오라 수치 4 표시"



L.EA_XICON_SNAMEFONTSIZE = "주문 이름 글꼴 크기"
L.EA_XICON_TIMERFONTSIZE = "카운트다운 글꼴 크기"
L.EA_XICON_STACKFONTSIZE = "중첩 수 글꼴 크기"



L.EA_XICON_LOCKFRAME = "프레임 잠금"
L.EA_XICON_LOCKFRAMETIP = "알림 프레임 이동 또는 위치 재설정을 원할 경우 '프레임 잠금' 체크를 해제하십시오."
L.EA_XICON_SHARESETTING = "프레임 위치 공유 설정"
L.EA_XICON_ICONSIZE = "아이콘 크기"
-- L.EA_XICON_ICONSIZE2 = "대상 아이콘 크기"
-- L.EA_XICON_ICONSIZE3 = "쿨다운 아이콘 크기"
L.EA_XICON_LARGE = "크게"
L.EA_XICON_SMALL = "작게"
L.EA_XICON_HORSPACE = "수평 간격"
L.EA_XICON_VERSPACE = "수직 간격"
-- L.EA_XICON_ICONSPACE1 = "자신 아이콘 간격"
-- L.EA_XICON_ICONSPACE2 = "대상 아이콘 간격"
-- L.EA_XICON_ICONSPACE3 = "쿨다운 아이콘 간격"
L.EA_XICON_MORE = "많이"
L.EA_XICON_LESS = "적게"
L.EA_XICON_REDDEBUFF = "자신의 Debuff 아이콘 색상 깊이"
L.EA_XICON_GREENDEBUFF = "대상의 Debuff 아이콘 색상 깊이"
L.EA_XICON_DEEP = "깊게"
L.EA_XICON_LIGHT = "연하게"
-- L.EA_XICON_DIRECTION = "확장 방향"
-- L.EA_XICON_DIRUP = "위"
-- L.EA_XICON_DIRDOWN = "아래"
-- L.EA_XICON_DIRLEFT = "왼쪽"
-- L.EA_XICON_DIRRIGHT = "오른쪽"
L.EA_XICON_TAR_NEWLINE = "대상 Debuff를 새 줄로 표시"
L.EA_XICON_TAR_HORSPACE = "알림 프레임과 수평 간격"
L.EA_XICON_TAR_VERSPACE = "알림 프레임과 수직 간격"
L.EA_XICON_TOGGLE_ALERTFRAME = "프레임 이동"
L.EA_XICON_RESET_FRAMEPOS = "프레임 위치 재설정"
L.EA_XICON_SELF_BUFF = "자신 버프"
L.EA_XICON_SELF_SPBUFF = "자신 DeBuff(1)\n또는 특수 프레임"
L.EA_XICON_SELF_DEBUFF = "자신 Debuff"
L.EA_XICON_TARGET_BUFF = "대상 버프"
L.EA_XICON_TARGET_SPBUFF = "대상 버프(1)\n또는 특수 프레임"
L.EA_XICON_TARGET_DEBUFF = "대상 Debuff"
L.EA_XICON_SCD = "스킬 쿨다운"
L.EA_XICON_EXECUTION = "보스 타겟 체력 퍼센트 알림"
L.EA_XICON_EXEFULL = "100%"
L.EA_XICON_EXECLOSE = "닫기"
L.EA_XICON_SCD_USECOOLDOWN = "쿨다운 사용 후 음"
EX_XCLSALERT_SELALL = "전체 선택"
EX_XCLSALERT_CLRALL = "전체 선택 해제"
EX_XCLSALERT_LOADDEFAULT = "기본값"
EX_XCLSALERT_REMOVEALL = "전체 삭제"
EX_XCLSALERT_SPELL = "주문 ID:"
EX_XCLSALERT_ADDSPELL = "추가"
EX_XCLSALERT_DELSPELL = "삭제"
EX_XCLSALERT_HELP1 = "위 목록은 [주문 ID]를 기준으로 정렬됩니다."
EX_XCLSALERT_HELP2 = "주문 ID를 찾으시려면 /eam help 명령어를 입력하세요."
EX_XCLSALERT_HELP3 = "게임에서 [주문 검색]에 대한 다양한 명령어를 알아보세요."
EX_XCLSALERT_HELP4 = "Buff 유형이 아닌 조건식 기술에 대한 추가적인 팁"
EX_XCLSALERT_HELP5 = "예 : 적 체력이 처형 구간에 진입하거나, 방패 막기 이후 사용"
EX_XCLSALERT_HELP6 = "Buff를 추가하지 않지만 사용할 수 있는 기술입니다."
EX_XCLSALERT_SPELLURL = "http://www.wowhead.com/spells"

L.EA_XTARALERT_TARGET_MYDEBUFF = "플레이어가 시전한 디버프만 대상"

L.EA_XGRPALERT_ICONALPHA = "아이콘 투명도"
L.EA_XGRPALERT_GRPID = "그룹 ID:"
L.EA_XGRPALERT_TALENT1 = "전문화 1"
L.EA_XGRPALERT_TALENT2 = "전문화 2"
L.EA_XGRPALERT_TALENT3 = "전문화 3"
L.EA_XGRPALERT_TALENT4 = "전문화 4"
L.EA_XGRPALERT_HIDEONLEAVECOMBAT = "전투 종료시 숨기기"
L.EA_XGRPALERT_HIDEONLOSTTARGET = "대상 없을 때 숨기기"

L.EA_XGRPALERT_GLOWWHENTRUE = "조건 충족시 강조"

L.EA_XGRPALERT_TALENTS = "전문화 무관"
L.EA_XGRPALERT_NEWSPELLBTN = "주문 추가"
L.EA_XGRPALERT_NEWCHECKBTN = "상위 조건 추가"
L.EA_XGRPALERT_NEWSUBCHECKBTN = "하위 조건 추가"
L.EA_XGRPALERT_SPELLNAME = "주문 이름:"
L.EA_XGRPALERT_SPELLICON = "주문 아이콘:"
L.EA_XGRPALERT_TITLECHECK = "상위 조건:"
L.EA_XGRPALERT_TITLESUBCHECK = "하위 조건:"
L.EA_XGRPALERT_TITLEORDERUP = "우선순위 상승"
L.EA_XGRPALERT_TITLEORDERDOWN = "우선순위 하락"

L.EA_XGRPALERT_LOGICS = {
	[1]={text="그리고", value=1},
	[2]={text="또는", value=0}, 
}

L.EA_XGRPALERT_EVENTTYPE = "이벤트 유형:"

L.EA_XGRPALERT_EVENTTYPES = {
	[1]={text="대상 에너지 변화", value="UNIT_POWER_UPDATE"},
	[2]={text="대상 체력 변화", value="UNIT_HEALTH"},
	[3]={text="대상 버프/디버프 변화", value="UNIT_AURA"},
	[4]={text="연계 점수 변화", value="UNIT_COMBO_POINTS"}, 
}

L.EA_XGRPALERT_UNITTYPE = "대상 유형:"

L.EA_XGRPALERT_UNITTYPES = {
	[1]={text="플레이어", value="player"},
	[2]={text="대상", value="target"},
	[3]={text="주시 대상", value="focus"},
	[4]={text="소환수", value="pet"},
	[5]={text="보스1", value="boss1"},
	[6]={text="보스2", value="boss2"},
	[7]={text="보스3", value="boss3"},
	[8]={text="보스4", value="boss4"},
	[9]={text="파티원1", value="party1"},
	[10]={text="파티원2", value="party2"},
	[11]={text="파티원3", value="party3"},
	[12]={text="파티원4", value="party4"},
	[13]={text="공격대원1", value="raid1"},
	[14]={text="공격대원2", value="raid2"},
	[15]={text="공격대원3", value="raid3"},
	[16]={text="공격대원4", value="raid4"},
	[17]={text="공격대원5", value="raid5"},
	[18]={text="공격대원6", value="raid6"},
	[19]={text="공격대원7", value="raid7"},
	[20]={text="공격대원8", value="raid8"},
	[21]={text="공격대원9", value="raid9"},
}

L.EA_XGRPALERT_CHECKCD = "스킬 CD 확인:"
L.EA_XGRPALERT_HEALTH = "체력:"
L.EA_XGRPALERT_COMPARES = {
[1]={text="<", value=1},
[2]={text="<=", value=2},
[3]={text="=", value=3},
[4]={text=">=", value=4},
[5]={text=">", value=5},
[6]={text="<>", value=6},
[7]={text="*", value=7}, -- 어떤 것이든
}
L.EA_XGRPALERT_COMPARETYPES = {
[1]={text="숫자", value=1},
[2]={text="백분율", value=2},
}
L.EA_XGRPALERT_CHECKAURA = "강화/약화 효과:"
L.EA_XGRPALERT_CHECKAURAS = {
[1]={text="있음", value=1},
[2]={text="없음", value=2},
}
L.EA_XGRPALERT_AURATIME = "시간:"
L.EA_XGRPALERT_AURASTACK = "중첩:"
L.EA_XGRPALERT_CASTBYPLAYER = "플레이어 시전한 경우"
L.EA_XGRPALERT_COMBOPOINT = "연계 점수:"
L.EA_XLOOKUP_START1 = "주문 이름 검색"
L.EA_XLOOKUP_START2 = "전체 일치"
L.EA_XLOOKUP_RESULT1 = "주문 검색 결과"
L.EA_XLOOKUP_RESULT2 = "개 일치"
L.EA_XLOAD_LOAD = "\124cffFFFF00EventAlertMod\124r: 주문 모니터링 트리거 알림, 로드된 버전: \124cff00FFFF"

L.EA_XGRPALERT_CHECKCD = "스킬 쿨타임 확인:"

L.EA_XGRPALERT_HEALTH = "체력:"

L.EA_XGRPALERT_COMPARETYPES = {
[1]={text="값", value=1},
[2]={text="백분율", value=2},
}
L.EA_XGRPALERT_CHECKAURA = "버프/디버프 확인:"
L.EA_XGRPALERT_CHECKAURAS = {
[1]={text="존재", value=1},
[2]={text="부재", value=2},
}
L.EA_XGRPALERT_AURATIME = "시간:"
L.EA_XGRPALERT_AURASTACK = "스택:"
L.EA_XGRPALERT_CASTBYPLAYER = "플레이어만 시전"
L.EA_XGRPALERT_COMBOPOINT = "연계 점수:"

L.EA_XLOOKUP_START1 = "스킬 이름 검색"
L.EA_XLOOKUP_START2 = "정확히 일치"
L.EA_XLOOKUP_RESULT1 = "검색 결과"
L.EA_XLOOKUP_RESULT2 = "개 일치"
L.EA_XLOAD_LOAD = "\124cffFFFF00EventAlertMod\124r: 스킬 모니터링 트리거 알림이 로드됨, 버전:\124cff00FFFF"

L.EA_XLOAD_FIRST_LOAD = "\124cffFF0000 EventAlertMod 효과 트리거 팁 UI를 처음으로 로드하고 기본 매개변수를로드합니다. \124r.\n\n"..
"매개변수 설정, 주문 모니터링, 위치 조정을위한 \124cffFFFF00/eam opt\124r를 사용하십시오.\n\n"

L.EA_XLOAD_NEWVERSION_LOAD = "\124cffFFFF00/eam help\124r를 사용하여 자세한 명령어 지침을 확인하십시오.\n\n\n"..
"\124cff00FFFF- 주요 업데이트 항목 -\124r\n\n"..
"*기능 추가: 그룹 단위의 다중 판단 조건 이벤트 트리거 기능.\n\n"..
"현재 감지 이벤트 지원:\n"..
"1. '대상'의 '에너지', '이상 또는 이하'시 특정 '값 또는 비율' 트리거\n"..
"2. '대상'의 '체력', '이상 또는 이하'시 특정 '값 또는 비율' 트리거\n"..
"3. '대상'의 'Buff/Debuff', '특정 주문 ID가 포함'될 경우 (층 수 또는 초 단위로 필터링 가능), 또는 '특정 주문 ID가 포함되지 않은' 경우 트리거\n"..
"4. '플레이어'가 '대상'에 대해 '연속 횟수'가 특정 '값 이상 또는 이하'시 트리거\n"..
"위 모든 조건은 AND 또는 OR로 사용할 수 있으며 하나 이상의 조건으로 필터링 할 수 있습니다.\n"..
"필터링 결과가 참이면 지정된 패턴을 알립니다.\n"..
"" -- END OF NEWVERSION

L.EA_XCMD_VER = " \124cff00FFFF By Whitep@雷鱗\124r 버전: "
L.EA_XCMD_DEBUG = " 모드: "
L.EA_XCMD_SELFLIST = " 자신의 Buff/Debuff 표시: "
L.EA_XCMD_TARGETLIST = " 대상의 Debuff 표시: "
L.EA_XCMD_CASTSPELL = " 시전 주문 ID 표시: "
L.EA_XCMD_AUTOADD_SELFLIST = " 자동으로 자신의 전체 상승/하강 효과 추가: "
L.EA_XCMD_ENVADD_SELFLIST = " 자동으로 자신의 환경 상승/하강 효과 추가: "
L.EA_XCMD_DEBUG_P0 = "트리거 주문 목록"
L.EA_XCMD_DEBUG_P1 = "주문"
L.EA_XCMD_DEBUG_P2 = "주문 ID"
L.EA_XCMD_DEBUG_P3 = "층"
L.EA_XCMD_DEBUG_P4 = "지속 시간 (초)"

L.EA_XCMD_CMDHELP = {
["TITLE"] = "\124cffFFFF00EventAlertMod\124r \124cff00FF00명령어\124r 설명(/eventalertmod or /eam):",
["OPT"] = "\124cff00FF00/eam options(또는 opt)\124r - 메인 설정 창 표시/숨기기.",
["HELP"] = "\124cff00FF00/eam help\124r - 추가 명령어 설명 표시.",
["SHOW"] = {
"\124cff00FF00/eam show [sec]\124r -",
">플레이어<가 가진 모든 버프/디버프의 주문 ID를 지속적으로 열거합니다. 그리고 지속 시간이 sec초 이내인 주문",
},
["SHOWT"] = {
"\124cff00FF00/eam showtarget(또는 showt) [sec]\124r -",
">대상<이 가진 모든 디버프의 주문 ID를 지속적으로 열거합니다. 그리고 지속 시간이 sec초 이내인 주문",
},
["SHOWC"] = {
"\124cff00FF00/eam showcast(또는 showc)\124r -",
"주문 시전에 성공한 후 시전한 주문 ID를 나열합니다.",
},
["SHOWA"] = {
"\124cff00FF00/eam showautoadd(또는 showa) [sec]\124r -",
">플레이어<가 가진 모든 버프/디버프의 주문을 자동으로 모니터링 목록에 추가합니다. 그리고 지속 시간이 sec초(기본값은 60초) 이내인 주문",
},
["SHOWE"] = {
"\124cff00FF00/eam showenvadd(또는 showe) [sec]\124r -",
">플레이어<가 가진 버프/디버프의 주문(단, 공격대 및 파티원에서 온 것은 제외)을 자동으로 모니터링 목록에 추가합니다. 그리고 지속 시간이 sec초(기본값은 60초) 이내인 주문",
},
["LIST"] = {
"\124cff00FF00/eam list\124r - 트리거 주문 목록 표시",
"show, showc, showt, lookup, lookupfull 명령어의 출력 결과 표시/숨기기",
},
["LOOKUP"] = {
"\124cff00FF00/eam lookup(또는 l) 검색어\124r - 일부 검색어로 주문 ID를 검색합니다.",
"게임에서 사용 가능한 모든 주문을 검색하고 검색어와 일치하는 주문 ID를 열거합니다.",
},

["LOOKUPFULL"] = {
"\124cff00FF00/eam lookupfull(또는 lf) 이름\124r - 전체 이름으로 주문 ID 검색",
"모든 주문을 검색하고 이름과 정확히 일치하는 주문 ID를 모두 나열합니다.",
},
}
-- EAM Rewrite Additions (Auto-generated)
L.EAM_FRAME_SELF_AURA = "EAM - 자신 오라 프레임"
L.EAM_FRAME_TARGET_AURA = "EAM - 대상 오라 프레임"
L.EAM_FRAME_SPELL_COOLDOWN = "EAM - 주문 재사용 대기시간 프레임"
L.EAM_FRAME_ITEM_COOLDOWN = "EAM - 아이템 재사용 대기시간 프레임"
L.EAM_FRAME_CLASS_POWER = "EAM - 직업 자원 프레임"
L.EAM_FRAME_GROUND_EFFECT = "EAM - 지면 효과 프레임"
L.EAM_FRAME_TOTEM = "EAM - 토템 프레임"
L.EAM_FRAME_POS_SAVED = "위치 저장됨: %s, X: %.1f, Y: %.1f"
L.EAM_MOVE_MODE_ON = "다중 프레임 이동 모드 켜짐! 프레임을 드래그하여 이동하고, 버튼을 다시 클릭하면 잠급니다."
L.EAM_MOVE_MODE_OFF = "다중 프레임 이동 모드 꺼짐. 레이아웃 적용 완료."
L.EAM_POWER_CLASS_POWER = "직업 자원"
L.EAM_POWER_HOLY_POWER = "신성한 힘"
L.EAM_POWER_SOUL_SHARDS = "영혼의 조각"
L.EAM_POWER_COMBO_POINTS = "연계 점수"
L.EAM_POWER_CHI = "공력"
L.EAM_POWER_ARCANE_CHARGES = "비전 충전물"
L.EAM_POWER_RUNIC_POWER = "룬 마력"
L.EAM_POWER_RAGE = "분노"
L.EAM_POWER_FURY_PAIN = "분노/고통"
L.EAM_GROUND_SKILL_DEFAULT = "지면 기술"
L.EAM_ITEM_PREFIX = "아이템 "
L.EAM_OPT_POS_AND_POWER_BTN = "아이콘 위치 및 자원 설정"
L.EAM_OPT_ENABLE_FRAME = "경고 프레임 활성화"
L.EAM_OPT_SHOW_SPELL_NAME = "주문 이름 표시"
L.EAM_OPT_SHOW_TIME_VAL = "남은 시간 표시"
L.EAM_OPT_SHOW_CHANGE_IN_OUT = "프레임 안/밖 전환"
L.EAM_OPT_SHOW_FLASH = "전체화면 깜빡임 활성화"
L.EAM_OPT_TEST_FLASH = "깜빡임 테스트"
L.EAM_OPT_SHOW_SOUND = "경고음 활성화"
L.EAM_OPT_SOUND_PREFIX = "경고음: "
L.EAM_OPT_TEST_BTN = "테스트"
L.EAM_OPT_ALLOW_ESC = "ESC 키로 닫기 허용"
L.EAM_OPT_SHOW_EXTRA_ALERT = "추가 경고 표시"
L.EAM_OPT_COOLDOWN_REMOVE = "쿨타임 종료 시 오라 제거"
L.EAM_OPT_SHOW_SCD_OUTSIDE = "비전투 중 주문 쿨 표시"
L.EAM_OPT_GLOW_SCD = "사용 가능 시 주문 쿨 강조"
L.EAM_OPT_SHOW_DK_RUNE = "죽기 룬 경고 표시"
L.EAM_OPT_ENABLE_ITEM_CD = "아이템 쿨 모니터링 활성화"
L.EAM_OPT_ENABLE_CDM = "블리자드 재사용 대기시간 뷰어 흡착"
L.EAM_OPT_CLOSE_BTN = "설정 닫기 (Close)"
L.EAM_OPT_DEBUG_BTN = "디버그 진단 (Debug)"
L.EAM_OPT_DEBUG_NOT_LOADED = "디버그 진단 모듈이 아직 로드되지 않았습니다!"
L.EAM_OPT_SLIDER_ICON_SIZE = "아이콘 크기 (Icon Size)"
L.EAM_OPT_SLIDER_ICON_SPACING = "가로 간격 (Horizontal Spacing)"
L.EAM_OPT_SLIDER_VERT_SPACING = "세로 간격 (Vertical Spacing)"
L.EAM_OPT_SLIDER_DEBUFF_RED = "자신 디버프 적색도 (Self Debuff Red)"
L.EAM_OPT_SLIDER_DEBUFF_GREEN = "대상 디버프 녹색도 (Target Debuff Green)"
L.EAM_OPT_SLIDER_EXECUTE_LIMIT = "생명력 조건 조건 (Execute Limit)"
L.EAM_OPT_ENABLE_EXECUTE = "생명력 조건 경고 활성화"
L.EAM_OPT_SLIDER_FONT_SPELL = "주문 이름 글꼴 크기 (Spell Font)"
L.EAM_OPT_SLIDER_FONT_CD = "재사용 대기시간 글꼴 크기 (CD Font)"
L.EAM_OPT_SLIDER_FONT_STACK = "중첩 글꼴 크기 (Stack Font)"
L.EAM_OPT_SLIDER_SHADOW_ALPHA = "대기시간 음영 투명도 (Shadow Alpha)"
L.EAM_OPT_DIR_TITLE = "경고 프레임 아이콘 정렬 방향 설정"
L.EAM_OPT_DIR_RIGHT = "오른쪽 (→)"
L.EAM_OPT_DIR_LEFT = "왼쪽 (←)"
L.EAM_OPT_DIR_UP = "위로 (↑)"
L.EAM_OPT_DIR_DOWN = "아래로 (↓)"
L.EAM_OPT_GROW_SELF_AURA = "자신 오라 정렬"
L.EAM_OPT_GROW_TARGET_AURA = "대상 오라 정렬"
L.EAM_OPT_GROW_SPELL_COOLDOWN = "주문 쿨 정렬"
L.EAM_OPT_GROW_ITEM_COOLDOWN = "아이템 쿨 정렬"
L.EAM_OPT_GROW_GROUND_EFFECT = "지면 효과 정렬"
L.EAM_OPT_GROW_TOTEM = "토템 정렬"
L.EAM_OPT_GROW_CLASS_POWER = "직업 자원 정렬"
L.EAM_OPT_TIMER_INSIDE = "대기시간 아이콘 내부에 표시"
L.EAM_OPT_TIMER_ALIGN = "대기시간 위치"
L.EAM_OPT_APPLICATIONS_ALIGN = "중첩 수 위치"
L.EAM_OPT_TEXT_LAYOUT_BTN = "대기시간 / 중첩 위치"
L.EAM_OPT_POWER_MONITOR_TITLE = "직업 특수 자원 조건 모니터링"
L.EAM_OPT_POWER_FRENZY = "광란"
L.EAM_OPT_POWER_PET_ENERGY = "소환수 기력"
L.EAM_OPT_MOVE_FRAME_BTN = "경고 프레임 이동"
L.EAM_OPT_MOVE_MODE_ON_PRINT = "이동 모드 켜짐 (/eam 을 사용하여 프레임 드래그)"
L.EAM_OPT_RESET_FRAME_BTN = "모든 아이콘 및 위치 초기화"
L.EAM_OPT_RESET_FRAME_SUCCESS = "모든 경고 프레임 위치 및 정렬 방향을 기본값으로 초기화했습니다."
L.EAM_OPT_LIST_TITLE = "경고 주문 리스트 설정"
L.EAM_OPT_SELECT_ALL = "모두 선택"
L.EAM_OPT_DESELECT_ALL = "모두 해제"
L.EAM_OPT_DEFAULTS_BTN = "기본값"
L.EAM_OPT_DEFAULTS_SUCCESS = "현재 직업의 기본 주문 설정을 성공적으로 로드했습니다!"
L.EAM_OPT_DEFAULTS_FAIL = "현재 직업의 기본 주문 설정을 찾을 수 없습니다."
L.EAM_OPT_DELETE_ALL = "모두 삭제"
L.EAM_OPT_FILTER_ALL = "필터: 모든 주문"
L.EAM_OPT_FILTER_PREFIX = "필터: "
L.EAM_OPT_FILTER_GENERAL = "공용 기술 / 사용자 정의"
L.EAM_OPT_ADD_SUCCESS = "경고 추가 성공 [ID: %s]"
L.EAM_OPT_ADD_FAIL = "경고 추가 실패: %s"
L.EAM_OPT_DEL_SUCCESS = "경고 제거 성공 [ID: %s]"
L.EAM_OPT_DEL_FAIL = "경고 제거 실패: %s"
L.EAM_OPT_ADD_BTN = "추가"
L.EAM_OPT_DEL_BTN = "삭제"
L.EAM_OPT_ERR_INVALID_ID = "올바른 ID를 입력하십시오!"
L.EAM_OPT_ADD_DEL_DESC = "SpellID 또는 ItemID를 입력하고 추가/삭제를 누르십시오."
L.EAM_OPT_PROFILE_BTN = "프로필 가져오기/내보내기"
L.EAM_OPT_DEFAULTS_CROSS_EMPTY = "타직업 효과에는 현재 직업 기본값을 넣지 않습니다. 확인한 SpellID를 일괄 입력으로 추가하십시오."
L.EAM_OPT_DEFAULTS_EMPTY_CATEGORY = "이 분류에는 검증된 직업 기본 주문이 없습니다."
L.EAM_OPT_ADD_RECLASSIFIED = "[ID: %s]은 현재 직업 주문이 아니므로 타직업 효과 목록에 추가했습니다."
L.EAM_OPT_ERR_SPELL_NOT_FOUND = "SpellID %s을 찾을 수 없어 추가하거나 표시하지 않았습니다."
L.EAM_OPT_BATCH_OPEN = "일괄 입력"
L.EAM_OPT_BATCH_TITLE = "EAM 주문/아이템 ID 일괄 입력"
L.EAM_OPT_BATCH_DESC = "한 줄에 하나씩 또는 세미콜론으로 ID를 구분하십시오. 현재 목록을 불러와 복사하거나 붙여넣은 뒤 한 번에 추가할 수 있습니다."
L.EAM_OPT_BATCH_LOAD = "현재 목록 불러오기"
L.EAM_OPT_BATCH_SELECT = "전체 선택/복사"
L.EAM_OPT_BATCH_ADD = "모두 추가"
L.EAM_OPT_BATCH_CLEAR = "지우기"
L.EAM_OPT_BATCH_CLOSE = "닫기"
L.EAM_OPT_BATCH_LOADED = "현재 목록을 불러왔습니다. 전체 선택/복사를 누르십시오."
L.EAM_OPT_BATCH_COPY_FAILED = "자동 선택에 실패했습니다. Ctrl+A와 Ctrl+C를 누르십시오."
L.EAM_OPT_BATCH_EMPTY = "추가할 유효한 ID가 없습니다."
L.EAM_OPT_BATCH_RESULT = "완료: 추가 %d, 갱신 %d, 변경 없음 %d, 무효 %d, 타직업 이동 %d."
L.EAM_OPT_BATCH_COMBAT = "전투 중에는 일괄 입력 창을 열 수 없습니다."
L.EAM_OPT_UNKNOWN = "알 수 없음"
L.EAM_OPT_COND_SPELL_ID_FORMAT = "주문 ID: %d"
L.EAM_OPT_COND_ITEM_ID_FORMAT = "아이템 ID: %d"
L.EAM_OPT_COND_SPELL_NAME = "주문 이름"
L.EAM_OPT_COND_STACK = "중첩 임계값"
L.EAM_OPT_COND_GLOW = "강조 중첩 임계값"
L.EAM_OPT_COND_CD_REMOVE = "사용 가능 시 제거"
L.EAM_OPT_COND_CD_OUTSIDE = "비전투 중 표시"
L.EAM_OPT_COND_CD_GLOW = "사용 가능 시 강조"
L.EAM_OPT_COND_CD_GLOBAL = "전역"
L.EAM_OPT_COND_CD_OVERRIDE_ON = "덮어쓰기: 켜짐"
L.EAM_OPT_COND_CD_OVERRIDE_OFF = "덮어쓰기: 꺼짐"
L.EAM_OPT_COND_RED_LIMIT = "대기시간 빨간색 텍스트 제한 (초)"
L.EAM_OPT_COND_PRIORITY = "정렬 우선순위 (Priority)"
L.EAM_OPT_COND_PLAYER_ONLY = "자신이 시전한 것만 감시"
L.EAM_OPT_COND_VAL_TITLE = "오라 상세 수치 표시:"
L.EAM_OPT_COND_VAL1 = "수치 1 표시 (Value 1)"
L.EAM_OPT_COND_VAL2 = "수치 2 표시 (Value 2)"
L.EAM_OPT_COND_VAL3 = "수치 3 표시 (Value 3)"
L.EAM_OPT_COND_VAL4 = "수치 4 표시 (Value 4)"
L.EAM_OPT_COND_TOOLTIP = "동적 툴팁 가져오기 활성화"
L.EAM_OPT_COND_MANUAL_DUR = "수동 시간 설정 (초)"
L.EAM_OPT_COND_SCRAPE_BTN = "가져오기"
L.EAM_OPT_AURA_SOUND_TITLE = "12.1 오라 이벤트 소리"
L.EAM_OPT_AURA_SOUND_ADDED = "오라 추가"
L.EAM_OPT_AURA_SOUND_APPLICATIONS_INCREASED = "중첩 증가"
L.EAM_OPT_AURA_SOUND_REMOVED = "오라 제거"
L.EAM_OPT_AURA_SOUND_INHERIT = "세 항목을 모두 선택하지 않으면 전역 소리를 사용합니다. 소리 알림 사용이 전체 스위치입니다. 미리 듣기는 소리 파일만 검증하며 실제 트리거는 PTR에서 사람이 확인해야 합니다."
L.EAM_OPT_AURA_SOUND_DISABLED = "이 클라이언트는 12.1 AuraSound를 지원하지 않습니다. 기존 설정은 덮어쓰지 않습니다."
L.EAM_OPT_AURA_SOUND_TEST_ASSET_ONLY = "소리 미리 듣기"
L.EAM_OPT_SCRAPE_SUCCESS = "동적 시간 가져오기 성공: %s 초"
L.EAM_OPT_SCRAPE_FAIL = "툴팁설명에서 초단위를 찾지 못했습니다. 수동으로 입력해주십시오."
L.EAM_OPT_COND_SAVE_BTN = "설정 저장 (Save)"
L.EAM_OPT_COND_SAVE_SUCCESS = "조건 저장 완료."
L.EAM_OPT_COND_CANCEL_BTN = "취소하고 닫기 (Cancel)"
L.EAM_OPT_COMBAT_WARNING = "전투 중에는 설정 창을 열 수 없습니다. 전투가 종료되면 자동으로 열립니다."
L.EAM_OPT_MINIMAP_LCLICK = "좌클릭: 설정 창 열기/닫기"
L.EAM_OPT_MINIMAP_RCLICK = "우클릭: 시스템 디버г 열기"
L.EAM_OPT_MINIMAP_MCLICK = "가운데 클릭 / Shift+클릭: 기본 창을 화면 중앙으로 재설정"
L.EAM_OPT_MINIMAP_DRAG = "드래그로 아이콘 이동 가능"
L.EAM_ALIGN_CENTER = "가운데"
L.EAM_ALIGN_TOP = "위"
L.EAM_ALIGN_BOTTOM = "아래"
L.EAM_ALIGN_LEFT = "왼쪽"
L.EAM_ALIGN_RIGHT = "오른쪽"
L.EAM_ALIGN_TOPLEFT = "왼쪽 위"
L.EAM_ALIGN_TOPRIGHT = "오른쪽 위"
L.EAM_ALIGN_BOTTOMLEFT = "왼쪽 아래"
L.EAM_ALIGN_BOTTOMRIGHT = "오른쪽 아래"
L.EAM_OPT_CAT_SELF = "자신 버프/디버프 경고 (Self)"
L.EAM_OPT_CAT_CLASS = "타직업 버프/디버프 경고"
L.EAM_OPT_CAT_TARGET = "대상 버프/디버프 경고 (Target)"
L.EAM_OPT_CAT_SPELL_CD = "주문 쿨다운 모니터링 (Spell CD)"
L.EAM_OPT_CAT_ITEM_CD = "아이템 쿨다운 모니터링 (Item CD)"
L.EAM_OPT_CAT_GROUND = "지면 기술 설정 (Ground Effect)"
L.EAM_OPT_CAT_LAYOUT = "아이콘 위치 및 자원 설정 (Layout & Power)"
L.EAM_SLASH_HELP_OPT = "/eam opt - 설정 창 열기/닫기"
L.EAM_SLASH_HELP_RESET = "/eam reset (또는 /eam center / resetpos) - 기본 창을 화면 중앙으로 재설정"
L.EAM_SLASH_RESET_POS_SUCCESS = "EAM 기본 창이 화면 중앙으로 재설정되었습니다."
L.EAM_SLASH_HELP_DOCTOR = "/eam doctor - API 진단 실행"
L.EAM_SLASH_HELP_VALIDATE = "/eam validate - /eam doctor 와 동일"
L.EAM_SLASH_HELP_DEBUG = "/eam debug - 디버그 요약 표시"
L.EAM_SLASH_HELP_EXPORT = "/eam export - AI 디버그 프롬프트 내보내기"
L.EAM_SLASH_HELP_ADD = "/eam add <spellID> - 플레이어 오라 경고 추가"
L.EAM_SLASH_HELP_ADD_TARGET = "/eam add target [spellID] - 대상 오라 추가; ID가 없으면 수동 창 열기"
L.EAM_SLASH_TARGET_POPUP_OPENED = "EAM: 대상 오라 수동 추가 창을 열었습니다."
L.EAM_SLASH_TARGET_POPUP_FAILED = "EAM: 대상 오라 수동 창을 열 수 없습니다: "
L.EAM_SLASH_HELP_ADD_CD = "/eam add cd <spellID> - 주문 재사용 대기시간 경고 추가"
L.EAM_SLASH_HELP_ADD_ITEM = "/eam add item <itemID> - 아이템 재사용 대기시간 경고 추가"
L.EAM_SLASH_HELP_REMOVE = "/eam remove <spellID|target|cd|item> <id> - 경고 제거"
L.EAM_SLASH_NOT_INIT = "SavedVariables가 아직 초기화되지 않았습니다."
L.EAM_SLASH_OP_FAIL = "작업 실패: "
L.EAM_SLASH_DEBUG_GROUND_START = "오라 없는 지면 기술 툴팁 파싱 디버깅 중 (현재 언어 설정: %s)..."
L.EAM_SLASH_DEBUG_GROUND_SUCCESS = "주문 [%d] 지속 시간 파싱 성공: |cff00ff00%s 초|r"
L.EAM_SLASH_DEBUG_GROUND_FAIL = "주문 [%d] 툴팁 파싱 실패, 기본 시간 사용"
L.EAM_SLASH_GROUND_NOT_LOADED = "GroundEffectService가 로드되지 않았습니다!"
L.EAM_SLASH_SPECIFY_SPELLID = "올바른 주문 ID를 입력하십시오: /eam debug ground <spellID>"
L.EAM_OPT_FLOW_TEST_BTN = "흐름 테스트"
L.EAM_SLASH_HELP_TEST = "/eam test [quick|core|boundary|all] - 흐름 검증 열기 또는 실행"
L.EAM_SLASH_HELP_UNITPOWER = "/eam unitpower background <RESOURCE_KEY> - 배경 자원 이벤트 누락을 표시하여 공유 sampler 활성화"
L.EAM_SLASH_RESOURCE_SAMPLER_MARKED = "EAM: 배경 자원 %s에 공유 sampler를 활성화했습니다."
L.EAM_SLASH_RESOURCE_SAMPLER_FAILED = "EAM: 자원 sampler를 활성화할 수 없습니다: "
L.EAM_FLOW_PANEL_TITLE = "EAM 흐름 검증 및 개발 피드백"
L.EAM_FLOW_PANEL_DESC = "오프라인 Mock과 Retail/PTR은 동일한 사례를 사용합니다. Mock 통과는 실기 통과가 아닙니다."
L.EAM_FLOW_BUTTON_QUICK = "빠른 흐름"
L.EAM_FLOW_BUTTON_CORE = "핵심 흐름"
L.EAM_FLOW_BUTTON_BOUNDARY = "경계 흐름"
L.EAM_FLOW_BUTTON_AURA121 = "12.1 Aura"
L.EAM_OPT_AURA_BACKEND = "Aura 백엔드: "
L.EAM_OPT_AURA_PENDING = " (전투 종료 대기)"
L.EAM_OPT_AURA_REBUILD = "재구성"
L.EAM_OPT_AURA_SETTINGS_DIRTY = " (적용 대기)"
L.EAM_OPT_AURA_APPLY = "적용"
L.EAM_FLOW_BUTTON_ALL = "전체 실행"
L.EAM_FLOW_BUTTON_COPY = "개발 보고서 전체 선택"
L.EAM_FLOW_BUTTON_CLOSE = "닫기"
L.EAM_FLOW_STATUS_NO_REPORT = "흐름 검증 보고서가 없습니다."
L.EAM_FLOW_STATUS_SUMMARY = "완료: 통과 %d, 실패 %d, 건너뜀 %d."
L.EAM_FLOW_STATUS_COPIED = "보고서를 전체 선택했습니다. Ctrl+C를 눌러 복사한 뒤 개발 환경으로 전달하세요."
L.EAM_FLOW_STATUS_COMBAT = "전투 중에는 흐름 검증을 실행하지 않습니다."
L.EAM_FLOW_STATUS_UNAVAILABLE = "흐름 검증 모듈을 사용할 수 없습니다."
L.EAM_FLOW_STATUS_RUNNING = "흐름 검증 실행 중..."
L.EAM_FLOW_STATUS_START_FAILED = "흐름 검증을 시작할 수 없습니다: %s"
L.EAM_FLOW_STATUS_DEFERRED = "전투 종료 후 흐름 검증 창을 엽니다."
-- EAM Spec Filter Additions (Auto-generated)
L.EAM_OPT_FILTER_ALL_VAL = "모든 주문"

L.EAM_TOOLTIP_SPELL_ID = "EAM 주문 ID"
L.EAM_TOOLTIP_ITEM_ID = "EAM 아이템 ID"
L.EAM_TOOLTIP_MACRO_ID = "EAM 매크로 ID"
L.EAM_TOOLTIP_OPEN_HINT = "Ctrl+Alt: EAM 감시 메뉴 열기"
L.EAM_TOOLTIP_MACRO_MANUAL_HINT = "매크로 출처를 안전하게 확인할 수 없습니다. Ctrl+Alt로 ID 직접 입력"
L.EAM_TOOLTIP_AURA_HINT = "오라 ID는 Blizzard가 표시합니다. Ctrl+Alt로 EAM 열기"
L.EAM_TOOLTIP_AURA_MANUAL_HINT = "공식 오라 ID 표시를 사용할 수 없습니다. Ctrl+Alt로 EAM 수동 입력 열기"
L.EAM_POPUP_TITLE = "EAM 감시 추가"
L.EAM_POPUP_ID_UNRESOLVED = "확인되지 않음"
L.EAM_POPUP_DESC_SPELL = "주문 ID: %s"
L.EAM_POPUP_DESC_ITEM = "아이템 ID: %s"
L.EAM_POPUP_DESC_AURA = "툴팁에 표시된 오라 주문 ID를 입력하고 감시할 대상을 선택하십시오."
L.EAM_POPUP_DESC_AURA_MANUAL = "Blizzard 오라 ID 표시를 사용할 수 없습니다. 알고 있는 오라 주문 ID를 입력하고 감시할 대상을 선택하십시오."
L.EAM_POPUP_DESC_MACRO = "매크로 ID: %s\n주문 ID: %s\n아이템 ID: %s"
L.EAM_POPUP_ID_INPUT = "감시 ID"
L.EAM_POPUP_ADD_SPELL = "주문 재사용 대기시간 추가"
L.EAM_POPUP_ADD_ITEM = "아이템 재사용 대기시간 추가"
L.EAM_POPUP_ADD_AURA_PLAYER = "플레이어 오라 추가"
L.EAM_POPUP_ADD_AURA_TARGET = "대상 오라 추가"
L.EAM_POPUP_CANCEL = "취소"
L.EAM_POPUP_STATUS_ADDED = "감시 목록에 추가됨"
L.EAM_POPUP_STATUS_UPDATED = "감시 항목 갱신됨"
L.EAM_POPUP_STATUS_UNCHANGED = "이미 감시 중"
L.EAM_POPUP_RESULT = "EAM: %s (ID %d)"
L.EAM_POPUP_RESULT_FAILED = "EAM: 감시를 추가할 수 없음 (%s)"

L.EAM_PLACEMENT_INSIDE_CENTER = "내부 중앙"
L.EAM_PLACEMENT_INSIDE_TOP = "내부 위"
L.EAM_PLACEMENT_INSIDE_TOP_RIGHT = "내부 오른쪽 위"
L.EAM_PLACEMENT_INSIDE_RIGHT = "내부 오른쪽"
L.EAM_PLACEMENT_INSIDE_BOTTOM_RIGHT = "내부 오른쪽 아래"
L.EAM_PLACEMENT_INSIDE_BOTTOM = "내부 아래"
L.EAM_PLACEMENT_INSIDE_BOTTOM_LEFT = "내부 왼쪽 아래"
L.EAM_PLACEMENT_INSIDE_LEFT = "내부 왼쪽"
L.EAM_PLACEMENT_INSIDE_TOP_LEFT = "내부 왼쪽 위"
L.EAM_PLACEMENT_OUTSIDE_TOP_AT_LEFT = "왼쪽 위 바깥(위)"
L.EAM_PLACEMENT_OUTSIDE_LEFT_AT_TOP = "왼쪽 위 바깥(왼쪽)"
L.EAM_PLACEMENT_OUTSIDE_TOP = "외부 위"
L.EAM_PLACEMENT_OUTSIDE_TOP_AT_RIGHT = "오른쪽 위 바깥(위)"
L.EAM_PLACEMENT_OUTSIDE_RIGHT_AT_TOP = "오른쪽 위 바깥(오른쪽)"
L.EAM_PLACEMENT_OUTSIDE_RIGHT = "외부 오른쪽"
L.EAM_PLACEMENT_OUTSIDE_RIGHT_AT_BOTTOM = "오른쪽 아래 바깥(오른쪽)"
L.EAM_PLACEMENT_OUTSIDE_BOTTOM_AT_RIGHT = "오른쪽 아래 바깥(아래)"
L.EAM_PLACEMENT_OUTSIDE_BOTTOM = "외부 아래"
L.EAM_PLACEMENT_OUTSIDE_BOTTOM_AT_LEFT = "왼쪽 아래 바깥(아래)"
L.EAM_PLACEMENT_OUTSIDE_LEFT_AT_BOTTOM = "왼쪽 아래 바깥(왼쪽)"
L.EAM_PLACEMENT_OUTSIDE_LEFT = "외부 왼쪽"

L.EAM_LIVE_CASE_AURA_SINGLE_COUNTDOWN = "일반 모드 오라 단일 카운트다운"
L.EAM_LIVE_CASE_AURA_DUAL_COUNTDOWN = "오라 이중 카운트다운 진단 동기화"
L.EAM_LIVE_CASE_SPELL_COOLDOWN = "주문 재사용 대기시간 아이콘 및 숫자"
L.EAM_LIVE_CASE_ITEM_COOLDOWN = "아이템 재사용 대기시간 이벤트"
L.EAM_LIVE_CASE_GROUND_AUTO = "지면 효과 지속시간 자동 분석"
L.EAM_LIVE_CASE_GROUND_FALLBACK = "지면 효과 수동 지속시간 대체"
L.EAM_LIVE_CASE_SWIPE_ALPHA = "재사용 대기시간 회전 투명도"
L.EAM_LIVE_CASE_TARGET_AURA_TRANSITION = "대상 오라 수명 주기 전환"
L.EAM_LIVE_CASE_NATIVE_BORDER = "12.1 기본 오라 테두리 기능"
L.EAM_LIVE_CASE_DURATION_ZERO = "PTR8 duration 0 수정"
L.EAM_LIVE_CASE_UNITPOWER_COMBAT = "UnitPower 전투 지연"
L.EAM_LIVE_CASE_CONTAINER_DISABLE_CLEAR = "12.1 컨테이너 비활성화 정리"
L.EAM_LIVE_CASE_NATIVE_DISPEL_OPTIONS = "12.1 Dispel options"
L.EAM_LIVE_CASE_NATIVE_PANDEMIC = "12.1 Pandemic Region"
L.EAM_LIVE_CASE_UNITPOWER_SECONDARY = "보조 직업 자원 숫자 표시"
L.EAM_LIVE_CASE_UNITPOWER_PRIMARY = "주요 자원 기본 표시 수신기"
L.EAM_LIVE_CASE_AURA_SOUND_ADDED = "AuraSound 오라 추가"
L.EAM_LIVE_CASE_AURA_SOUND_APPLICATIONS = "AuraSound 중첩 증가"
L.EAM_LIVE_CASE_AURA_SOUND_REMOVED = "AuraSound 오라 제거"
L.EAM_FLOW_BUTTON_DUAL_COUNTDOWN = "이중 카운트다운 진단"
L.EAM_FLOW_BUTTON_DUAL_COUNTDOWN_OFF = "이중 카운트다운 끄기"
L.EAM_FLOW_DUAL_COUNTDOWN_UNAVAILABLE = "이중 카운트다운 진단 설정을 사용할 수 없습니다."
L.EAM_FLOW_DUAL_COUNTDOWN_RELOAD = "진단 설정이 저장되었지만 Native 컨테이너 한도에 도달했습니다. 플레이어가 /reload를 실행하십시오."
L.EAM_FLOW_DUAL_COUNTDOWN_ENABLED = "이중 카운트다운 진단이 켜졌습니다. 시각적 동기화 확인 후 끄십시오."
L.EAM_FLOW_DUAL_COUNTDOWN_DISABLED = "이중 카운트다운 진단이 꺼졌습니다. 일반 모드는 하나만 표시합니다."
L.EAM_FLOW_BUTTON_UNIT_POWER = "UnitPower 기능"
L.EAM_FLOW_BUTTON_UNIT_POWER_STOP = "중지하고 보고서 생성"
L.EAM_UNIT_POWER_PROBE_UNAVAILABLE = "UnitPower 기능 탐색기가 로드되지 않았습니다."
L.EAM_UNIT_POWER_PROBE_START_FAILED = "UnitPower 테스트를 시작할 수 없습니다. 전투를 종료한 뒤 패널을 여십시오."
L.EAM_UNIT_POWER_PROBE_RUNNING = "테스트 중: 플레이어가 자원을 생성하고 소비한 뒤 두 기본 표시를 관찰하고 결과를 선택하십시오."
L.EAM_UNIT_POWER_PROBE_STOPPED = "UnitPower 기능 보고서가 완료되었습니다. 복사하여 전달하십시오."
L.EAM_UNIT_POWER_PROBE_TITLE = "UnitPower 기본 표시 기능 테스트"
L.EAM_UNIT_POWER_PROBE_PRIMARY = "현재 주요 자원"
L.EAM_UNIT_POWER_PROBE_SELECTED = "EAM 선택 자원"
L.EAM_UNIT_POWER_PROBE_PASS = "표시 정상"
L.EAM_UNIT_POWER_PROBE_FAIL = "표시 이상"
L.EAM_UNIT_POWER_PROBE_BLOCKED = "테스트 불가"
L.EAM_UNIT_POWER_CLIENT_REQUIRED = "UnitPower 테스트를 시작하기 전에 실기 검증 패널에서 현재 실행 중인 PTR, XPTR 또는 정식 클라이언트를 선택하십시오."
L.EAM_LIVE_CANCEL_SESSION = "현재 세션 취소"
L.EAM_LIVE_CANCEL_CONFIRM = "이번 진행을 지우려면 현재 세션 취소를 한 번 더 누르십시오."
L.EAM_LIVE_CANCELLED = "현재 세션이 취소되었습니다. 클라이언트를 다시 선택할 수 있습니다."
L.EAM_LIVE_CANCEL_FAILED = "세션을 취소할 수 없습니다: %s"
L.EAM_LIVE_CANCEL_NOT_ACTIVE = "진행 중인 실기 검증 세션이 없습니다."
L.EAM_LIVE_COMPLETE_READY = "JSON이 준비되었습니다. 실기 JSON 전체 선택을 누른 뒤 Ctrl+C를 누르세요. 게임 저장 파일에서 가져오려면 플레이어가 /reload 또는 정상 로그아웃으로 저장해야 합니다."
L.EAM_PROMPT_COPY_SELECTED = "|cff20ff20진단 정보를 전체 선택했습니다. Ctrl+C로 복사해 보고하세요.|r"
L.EAM_COPY_SELECTION_FAILED = "보고서 텍스트를 선택하지 못했습니다. 텍스트 상자를 클릭하고 Ctrl+A, Ctrl+C를 누르세요."
L.EAM_PROMPT_COPY_SELECT = "진단 정보 전체 선택"
L.EAM_LIVE_COPIED = "JSON을 전체 선택했습니다. Ctrl+C로 복사하고 PTR, XPTR 또는 Retail 표기를 함께 보내세요."
L.EAM_LIVE_COPY = "실기 JSON 전체 선택"
L.EAM_LIVE_CASE_PROCEDURE = "테스트 조건/절차: %s"
L.EAM_OPT_LANGUAGE_PREFIX = "언어: "
L.EAM_OPT_LANGUAGE_RELOAD = "언어가 즉시 적용되고 저장되었습니다."
L.EAM_OPT_THEME_PREFIX = "테마: "
L.EAM_OPT_THEME_CHANGED = "테마가 적용되었습니다."
L.EAM_OPT_THEME_COMBAT = "전투 종료 후 테마가 적용됩니다."
L.EAM_OPT_ABOUT_BTN = "정보"
L.EAM_ABOUT_TITLE = "EventAlertMod 정보"
L.EAM_ABOUT_ADDON_VERSION = "애드온 버전: "
L.EAM_ABOUT_AUTHOR = "제작자: "
L.EAM_ABOUT_API_BASELINE = "API 기준: "
L.EAM_ABOUT_COMPATIBILITY = "호환 트랙: "
L.EAM_ABOUT_CLIENT_FORMAT = "현재 클라이언트: %s %s (Build %s, Interface %s)"
L.EAM_ABOUT_REPOSITORY = "GitHub: "
L.EAM_ABOUT_PAGES = "프로젝트 페이지: "
L.EAM_ABOUT_CLOSE = "닫기"
L.EAM_ABOUT_COMBAT_BLOCKED = "전투 중에는 정보 창을 열 수 없습니다."
L.EAM_ABOUT_CHANNEL_UNCONFIRMED = "확인되지 않은 채널"
L.EAM_ABOUT_UNKNOWN = "알 수 없음"

L.EAM_FLOW_BUTTON_SVG = "SVG 기능"
L.EAM_FLOW_BUTTON_SVG_STOP = "SVG 테스트 중지"
L.EAM_SVG_CLIENT_REQUIRED = "실기 검증에서 현재 클라이언트를 선택한 뒤 SVG 테스트를 시작하세요."
L.EAM_SVG_PROBE_UNAVAILABLE = "SVG 기능 프로브가 로드되지 않았습니다."
L.EAM_SVG_PROBE_START_FAILED = "SVG 테스트를 시작할 수 없습니다. 먼저 전투를 종료하세요."
L.EAM_SVG_PROBE_RUNNING = "두 SVG 그림을 확인하고 각각 시각 결과를 표시하세요."
L.EAM_SVG_PROBE_STOPPED = "SVG 기능 보고서가 완료되었습니다. 전체 선택 후 Ctrl+C를 누르세요."
L.EAM_SVG_PROBE_TITLE = "SVG / VectorGraphics 기능 테스트"
L.EAM_SVG_PROBE_DESC = "두 패널에 청록색 테두리와 노랑/보라 삼각형이 동일하게 보여야 합니다."
L.EAM_SVG_PROBE_VECTOR = "VectorGraphics:SetSVG"
L.EAM_SVG_PROBE_TEXTURE = "Texture:SetSVG"
L.EAM_SVG_PROBE_PASS = "정상 표시"
L.EAM_SVG_PROBE_FAIL = "비정상 표시"
L.EAM_SVG_PROBE_BLOCKED = "테스트 불가"
L.EAM_SVG_PROBE_FINISH = "완료 및 보고서 생성"
L.EAM_OPT_MODULES_BTN = "기능 모듈"
L.EAM_MODULE_PANEL_TITLE = "기능 모듈 설정"
L.EAM_MODULE_PANEL_DESC = "비활성화된 모듈은 이벤트를 한 번만 등록한 채 API 읽기를 중지하고 기존 알림을 지웁니다."
L.EAM_MODULE_PLAYER_AURA = "플레이어 오라"
L.EAM_MODULE_TARGET_AURA = "대상 오라"
L.EAM_MODULE_SPELL_COOLDOWN = "주문 재사용 대기시간"
L.EAM_MODULE_ITEM_COOLDOWN = "아이템 재사용 대기시간"
L.EAM_MODULE_GROUND_EFFECT = "지면 효과"
L.EAM_MODULE_CLASS_POWER = "직업 자원"
L.EAM_MODULE_TOTEM = "토템"
L.EAM_MODULE_TOOLTIP_MONITOR = "툴팁 감시 메뉴"
L.EAM_MODULE_ENABLED = "활성화"
L.EAM_MODULE_DISABLED = "비활성화"
L.EAM_MODULE_STATUS_FORMAT = "%s: %s"
L.EAM_MODULE_STATUS_READY = "모듈 설정 준비 완료."
L.EAM_MODULE_STATUS_FAILED = "적용 실패: "
L.EAM_MODULE_COMBAT_BLOCKED = "전투 중에는 모듈 창을 열 수 없습니다."
L.EAM_SLASH_HELP_LIST = "/eam list - 현재 직업 감시 목록 표시"
L.EAM_SLASH_HELP_LOOKUP = "/eam lookup <이름> - 현재 직업 후보 검색"
L.EAM_SLASH_HELP_LOOKUPFULL = "/eam lookupfull <정확한 이름> - 현재 직업 후보 정확히 검색"
L.EAM_SLASH_HELP_SHOWCAST = "/eam showcast - 이번 접속의 주문 시전 기록 시작/중지"
L.EAM_SLASH_HELP_SHOW = "/eam show/showtarget - Retail 12.1 안전 대안 안내"
L.EAM_SLASH_UNKNOWN_NAME = "이름을 사용할 수 없음"
L.EAM_SLASH_ITEM_LABEL = "아이템"
L.EAM_SLASH_LIST_HEADER = "%s 직업 감시 목록"
L.EAM_SLASH_LIST_LINE = "%s | %s | ID: %d"
L.EAM_SLASH_LIST_EMPTY = "현재 직업에 설정된 경고가 없습니다."
L.EAM_SLASH_CAST_LINE = "%s | 주문 ID: %d"
L.EAM_SLASH_SHOWCAST_EMPTY = "이번 접속에서 기록된 플레이어 시전이 없습니다."
L.EAM_SLASH_DISCOVERY_UNAVAILABLE = "기존 탐색 서비스가 로드되지 않았습니다."
L.EAM_SLASH_SHOWCAST_ENABLED = "플레이어의 성공한 주문 시전 기록을 시작했습니다."
L.EAM_SLASH_SHOWCAST_DISABLED = "플레이어 주문 시전 기록을 중지했습니다."
L.EAM_SLASH_LOOKUP_USAGE = "사용법: /eam lookup <주문 이름>"
L.EAM_SLASH_LOOKUP_LINE = "%s | 주문 ID: %d"
L.EAM_SLASH_LOOKUP_NONE = "현재 직업의 제한된 후보에서 일치 항목을 찾지 못했습니다."
L.EAM_SLASH_SHOW_UNSUPPORTED = "Retail 12.1에서는 기존 UnitAura 전체 검색을 사용하지 않습니다. 오라 아이콘에 마우스를 올리고 Ctrl+Alt를 눌러 추가하십시오."
L.EAM_SLASH_AUTOADD_UNSUPPORTED = "Retail 12.1에서는 검색 결과를 자동 저장하지 않습니다. Tooltip의 Ctrl+Alt 창에서 확인 후 추가하십시오."

L.EAM_SLASH_HELP_PROFILE = "/eam profile [export|import] - 직업 profile JSON/Base64 공유 열기"
L.EAM_PROFILE_CODEC_TITLE = "EAM 직업 Profile 공유"
L.EAM_PROFILE_CODEC_DESC = "EAMAP1: payload를 붙여 넣고 미리 본 뒤 병합 또는 교체를 선택하세요. Base64는 암호화가 아닙니다."
L.EAM_PROFILE_CODEC_EXPORT = "현재 직업 내보내기"
L.EAM_PROFILE_CODEC_PREVIEW = "가져오기 미리보기"
L.EAM_PROFILE_CODEC_MERGE = "병합 적용"
L.EAM_PROFILE_CODEC_REPLACE = "교체 적용"
L.EAM_PROFILE_CODEC_SELECT = "복사할 내용 선택"
L.EAM_PROFILE_CODEC_CLOSE = "닫기"
L.EAM_PROFILE_CODEC_COMBAT = "전투 중에는 profile 공유를 열 수 없습니다."
L.EAM_PROFILE_CODEC_STATUS_UNAVAILABLE = "Profile codec을 사용할 수 없습니다."
L.EAM_PROFILE_CODEC_STATUS_SELECTED = "payload를 선택했습니다. Ctrl+C를 누르세요."
L.EAM_PROFILE_CODEC_STATUS_SELECT_FAILED = "자동 선택 실패. Ctrl+A 후 Ctrl+C를 누르세요."
L.EAM_PROFILE_CODEC_STATUS_FAILED = "Profile 작업 실패: %s"
L.EAM_PROFILE_CODEC_STATUS_EXPORTED = "%s개 알림을 내보냈습니다. 인코더: %s. payload를 선택해 복사하세요."
L.EAM_PROFILE_CODEC_STATUS_APPLIED = "적용 완료: 추가 %d, 변경 %d, 동일 %d, 제거 %d."
L.EAM_PROFILE_SEC_SELF = "자신 오라"
L.EAM_PROFILE_SEC_TARGET = "대상 오라"
L.EAM_PROFILE_SEC_SPELL_CD = "주문 재사용 대기시간"
L.EAM_PROFILE_SEC_ITEM_CD = "아이템 재사용 대기시간"
L.EAM_PROFILE_SEC_GROUND = "바닥 효과"
L.EAM_PROFILE_SEC_LAYOUT = "프레임 배치"
L.EAM_PROFILE_SEC_RESOURCE = "직업 자원 설정"
L.EAM_PROFILE_SEC_CONFIG = "일반 설정"
L.EAM_PROFILE_BTN_SELECT_ALL = "모두 선택"
L.EAM_PROFILE_BTN_ALERTS_ONLY = "알림만 선택"
L.EAM_PROFILE_BTN_LAYOUT_ONLY = "배치 설정만"

L.EAM_OPT_FONT_PREFIX = "글꼴: "
L.EAM_OPT_FONT_STANDARD = "클라이언트 기본 글꼴"
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
L.EAM_THEME_ETEN = "ETen Chinese"
L.EAM_THEME_REDALERT = "레드 얼럿"
L.EAM_THEME_AQUA = "macOS Aqua"
L.EAM_RESOURCE_PANEL_TITLE = "플레이어 직업 자원"
L.EAM_RESOURCE_PANEL_DESC = "각 자원을 독립적으로 설정합니다. 비밀 자원은 Lua 숫자를 노출하지 않고 기본 시각 요소만 사용합니다."
L.EAM_RESOURCE_OPTIONS_ENTRY_DESC = "직업 및 전문화별로 자원을 설정합니다. 비밀 자원은 기본 시각 요소만 사용합니다."
L.EAM_RESOURCE_OPEN = "자원 설정 열기"
L.EAM_CHARGE_BAR_TITLE = "남은 충전 횟수 막대"
L.EAM_CHARGE_BAR_LAYOUT = "위치 / 스타일"
L.EAM_CHARGE_BAR_BOTTOM = "아이콘 아래"
L.EAM_CHARGE_BAR_TOP = "아이콘 위"
L.EAM_CHARGE_BAR_LEFT = "아이콘 왼쪽 (세로)"
L.EAM_CHARGE_BAR_RIGHT = "아이콘 오른쪽 (세로)"
L.EAM_CHARGE_BAR_RING = "원형"
L.EAM_CHARGE_BAR_LENGTH = "길이 / 원 지름 (아이콘 %)"
L.EAM_CHARGE_BAR_THICKNESS = "두께 (px)"
L.EAM_CHARGE_BAR_HINT = "구간은 남은 사용 가능 충전 수를 나타내며, 재충전 시간은 재사용 대기시간 회전에만 사용됩니다."
L.EAM_RESOURCE_OPTIONS_STATUS = "플레이어 자원 %d개 추적 중."
L.EAM_RESOURCE_SCOPE_SPEC = "현재 전문화 재정의"
L.EAM_RESOURCE_SCOPE_CLASS = "직업 기본값"
L.EAM_RESOURCE_CAPABILITY_NUMERIC = "NUMERIC: 안전한 숫자 표시"
L.EAM_RESOURCE_CAPABILITY_SECRET = "SECRET_DISPLAY: 기본 시각 요소만"
L.EAM_RESOURCE_CAPABILITY_UNAVAILABLE = "UNAVAILABLE: 현재 사용할 수 없음"
L.EAM_RESOURCE_NONE = "설정 가능한 플레이어 자원이 없습니다"
L.EAM_RESOURCE_ENABLED = "이 자원 활성화"
L.EAM_RESOURCE_SHOW_FOREGROUND = "주 자원일 때 표시"
L.EAM_RESOURCE_SHOW_BACKGROUND = "보조 자원일 때 표시"
L.EAM_RESOURCE_SHOW_VALUE = "안전한 숫자 표시"
L.EAM_RESOURCE_VALUE_FONT_SIZE = "숫자 글꼴 크기"
L.EAM_RESOURCE_VALUE_OFFSET_X = "숫자 가로 오프셋"
L.EAM_RESOURCE_VALUE_OFFSET_Y = "숫자 세로 오프셋"
L.EAM_RESOURCE_FONT_SIZE = "자원 이름 글꼴 크기"
L.EAM_RESOURCE_FONT_FAMILY = "글꼴"
L.EAM_RESOURCE_ORIENTATION = "방향"
L.EAM_RESOURCE_ORIENTATION_HORIZONTAL = "가로"
L.EAM_RESOURCE_ORIENTATION_VERTICAL = "세로"
L.EAM_RESOURCE_DISPLAY_MODE = "표시 방식"
L.EAM_RESOURCE_MODE_AUTO = "자동"
L.EAM_RESOURCE_MODE_BAR = "자원 바"
L.EAM_RESOURCE_MODE_POINTS = "자원 점"
L.EAM_RESOURCE_OFFSET_X = "가로 위치"
L.EAM_RESOURCE_OFFSET_Y = "세로 위치"
L.EAM_RESOURCE_ANCHOR = "상위 프레임 앵커"
L.EAM_RESOURCE_POSITION = "자원 프레임 지점"
L.EAM_RESOURCE_SCALE = "크기"
L.EAM_RESOURCE_ALPHA = "전체 투명도"
L.EAM_RESOURCE_FOREGROUND_ALPHA = "주 자원 투명도"
L.EAM_RESOURCE_BACKGROUND_ALPHA = "보조 자원 투명도"
L.EAM_RESOURCE_BAR_WIDTH = "자원 바 너비"
L.EAM_RESOURCE_BAR_HEIGHT = "자원 바 높이"
L.EAM_RESOURCE_ICON_SIZE = "아이콘 크기"
L.EAM_RESOURCE_SPACING = "아이콘과 바 간격"
L.EAM_RESOURCE_ORDER = "표시 순서"
L.EAM_RESOURCE_STATUS_READY = "플레이어 자원 설정 준비 완료."
L.EAM_RESOURCE_STATUS_UPDATED = "자원 설정이 업데이트되었습니다."
L.EAM_RESOURCE_STATUS_UNCHANGED = "변경된 설정이 없습니다."
L.EAM_RESOURCE_STATUS_FAILED = "적용 실패: "
L.EAM_RESOURCE_APPLY = "적용"
L.EAM_RESOURCE_RESET_SPEC = "전문화 재정의 지우기"
L.EAM_RESOURCE_COMBAT_BLOCKED = "전투 중에는 플레이어 자원 설정을 열 수 없습니다."
L.EAM_RESOURCE_MANA = "마나"
L.EAM_RESOURCE_RAGE = "분노"
L.EAM_RESOURCE_FOCUS = "집중"
L.EAM_RESOURCE_ENERGY = "기력"
L.EAM_RESOURCE_COMBO_POINTS = "연계 점수"
L.EAM_RESOURCE_RUNES = "룬"
L.EAM_RESOURCE_RUNIC_POWER = "룬 마력"
L.EAM_RESOURCE_SOUL_SHARDS = "영혼의 조각"
L.EAM_RESOURCE_LUNAR_POWER = "천공의 힘"
L.EAM_RESOURCE_HOLY_POWER = "신성한 힘"
L.EAM_RESOURCE_MAELSTROM = "소용돌이"
L.EAM_RESOURCE_CHI = "기"
L.EAM_RESOURCE_INSANITY = "광기"
L.EAM_RESOURCE_ARCANE_CHARGES = "비전 충전물"
L.EAM_RESOURCE_FURY = "격노"
L.EAM_RESOURCE_PAIN = "고통"
L.EAM_RESOURCE_ESSENCE = "정수"
L.EAM_PROMPT_TITLE = "EAM 진단 및 디버그 내보내기"
L.EAM_PROMPT_REFRESH = "새로 고침"
L.EAM_PROMPT_CLOSE = "창 닫기"
L.EAM_OPT_CAT_RESOURCE = "★ 플레이어 직업 자원 설정"
L.EAM_OPT_DEBUG_CENTER_BTN = "디버그 및 진단 센터"
L.EAM_DEBUG_CENTER_TITLE = "디버그 및 진단 센터"
L.EAM_DEBUG_TAB_RUNTIME = "실시간 런타임 상태"
L.EAM_DEBUG_TAB_RUNE = "죽음의 기사 룬 진단"
L.EAM_DEBUG_TAB_FLOW = "플로우 테스트 실행"
L.EAM_DEBUG_TAB_EXPORT = "시스템 진단 내보내기"
L.EAM_DEBUG_STATUS_REFRESHED = "실시간 런타임 상태가 업데이트되었습니다."
L.EAM_DEBUG_STATUS_RUNE_REFRESHED = "죽음의 기사 룬 진단 데이터가 업데이트되었습니다."
L.EAM_DEBUG_STATUS_RUNNING_TESTS = "플로우 및 단위 테스트 실행 중..."
L.EAM_DEBUG_STATUS_EXPORTING = "진단 보고서 생성 중..."
L.EAM_DEBUG_BTN_REFRESH = "상태 새로고침"
L.EAM_DEBUG_BTN_RUNE_PROBE = "룬 즉시 진단"
L.EAM_DEBUG_BTN_RUN_TESTS = "플로우 테스트 실행"
L.EAM_DEBUG_BTN_GENERATE_EXPORT = "진단 보고서 생성"
L.EAM_DEBUG_BTN_SELECT_ALL = "모두 선택"
L.EAM_OPT_CAT_STAT = "★ 플레이어 능력치 및 흡수량 모니터링"
L.EAM_STAT_OPEN = "★ 플레이어 능력치 및 흡수량 모니터링"
L.EAM_STAT_PANEL_TITLE = "★ 플레이어 능력치 및 흡수량 모니터링"
L.EAM_MODULE_PLAYER_STAT = "능력치 및 흡수량 모니터링"
L.EAM_FRAME_PLAYER_STAT = "EAM - 플레이어 능력치 프레임"
L.EAM_STAT_ENABLE = "능력치 모니터링 활성화"
L.EAM_STAT_SHOW_ICON = "아이콘 표시"
L.EAM_STAT_SHOW_STATUSBAR = "진행 바"
L.EAM_STAT_ICON_SIZE = "아이콘 크기"
L.EAM_STAT_FONT_VALUE = "수치 글꼴 크기"
L.EAM_STAT_FONT_LABEL = "이름 글꼴 크기"
L.EAM_STAT_CUSTOM_LABEL = "이름 대체 텍스트 (사용자 지정):"
L.EAM_STAT_DECIMALS = "소수점 자리수 (0 ~ 2):"
L.EAM_STAT_SHORT_NUMBER = "큰 수치 축약 (k/M)"
L.EAM_STAT_MIN_THRESH = "이 수치 이하 시 경고:"
L.EAM_STAT_MAX_THRESH = "이 수치 이상 시 경고:"
L.EAM_STAT_MOVE_BTN = "프레임 이동"
L.EAM_STAT_SAVED = "[%s] 능력치 모니터링 설정이 저장되었습니다."
L.EAM_STAT_COMBAT_BLOCKED = "전투 중에는 능력치 모니터링 패널을 열 수 없습니다."
L.EAM_STAT_STRENGTH = "힘"
L.EAM_STAT_AGILITY = "민첩성"
L.EAM_STAT_STAMINA = "체력"
L.EAM_STAT_INTELLECT = "지능"
L.EAM_STAT_CRIT = "치명타 및 극대화"
L.EAM_STAT_HASTE = "가속"
L.EAM_STAT_MASTERY = "특화"
L.EAM_STAT_VERSATILITY = "유연성"
L.EAM_STAT_AVOIDANCE = "광역 회피"
L.EAM_STAT_LEECH = "생기 흡수"
L.EAM_STAT_SPEED_RATING = "이동 속도 (능력치)"
L.EAM_STAT_RUN_SPEED = "달리기 속도"
L.EAM_STAT_SWIM_SPEED = "수영 속도"
L.EAM_STAT_FLIGHT_SPEED = "비행 속도"
L.EAM_STAT_SKYRIDING_SPEED = "용 조련술 비행 속도"
L.EAM_STAT_TOTAL_ABSORB = "총 흡수량"
L.EAM_STAT_HEAL_ABSORB = "치유 흡수량"
L.EAM_STAT_ARMOR = "방어도"
L.EAM_OPT_CUSTOM_ICON_LABEL = "사용자 지정 대체 아이콘 (ID 또는 경로):"
L.EAM_OPT_CUSTOM_ICON_HINT = "WoW.tools / Wago Tools 에서 아이콘을 검색할 수 있습니다:"
L.EAM_WEAPON_ENCHANT_MH = "주무기 마법부여"
L.EAM_WEAPON_ENCHANT_OH = "보조무기 마법부여"
L.EAM_OPT_ENABLE_WEAPON_ENCHANT = "무기 임시 마법부여 알림 사용"
L.EAM_OPT_PET_AURA_TAG = "[소환수]"
L.EAM_OPT_SOUND_NONE = "없음 (음소거)"
L.EAM_OPT_SOUND_ALARM1 = "경보 1"
L.EAM_OPT_SOUND_ALARM2 = "경보 2"
L.EAM_OPT_SOUND_BELL = "종소리"
L.EAM_OPT_SOUND_DRUM = "북소리"
L.EAM_OPT_SOUND_WHISTLE = "호루라기"
L.EAM_OPT_BAR_DEFAULT = "블리자드 기본 바"
L.EAM_OPT_BAR_FLAT = "단색 플랫 텍스처"
L.EAM_OPT_BAR_SMOOTH = "부드러운 그라데이션"
L.EAM_OPT_RADIAL_GAUGE = "12.1 기본 원형 오라 카운트다운 게이지 활성화"
L.EAM_STAT_VALUE_PLACEMENT = "아이콘 없을 시 수치 위치:"
L.EAM_STAT_VAL_TOP = "위쪽 (Top)"
L.EAM_STAT_VAL_BOTTOM = "아래쪽 (Bottom)"
L.EAM_STAT_VAL_LEFT = "왼쪽 (Left)"
L.EAM_STAT_ENABLE_ALL = "모두 활성화"
L.EAM_STAT_DISABLE_ALL = "모두 비활성화"
L.EAM_STAT_GROW_DIR = "배열 방향:"
L.EAM_STAT_DIR_RIGHT = "오른쪽 (Right)"
L.EAM_STAT_DIR_LEFT = "왼쪽 (Left)"
L.EAM_STAT_DIR_UP = "위쪽 (Up)"
L.EAM_STAT_DIR_DOWN = "아래쪽 (Down)"
L.EAM_STAT_USE_CUSTOM_POS = "개별 독립 위치 활성화 (자유 드래그)"
L.EAM_STAT_OFFSET_X = "수평 위치 (X)"
L.EAM_STAT_OFFSET_Y = "수직 위치 (Y)"
L.EAM_STAT_MOVE_SINGLE_BTN = "이 항목 이동"
L.EAM_STAT_MOVE_ALL_BTN = "모든 속성 이동"
L.EAM_STAT_POS_SAVED = "[%s] 개별 위치 저장됨: X: %.1f, Y: %.1f"

-- Next-Gen Group & Catalog Presets (koKR)
L.EAM_OPT_CAT_GROUP = "★ 그룹 관리 및 다중 태깅"
L.EAM_GROUP_OPEN = "★ 그룹 관리 및 다중 태깅"
L.EAM_OPT_CAT_CATALOG = "★ 주문 카탈로그 및 스마트 프리셋"
L.EAM_CATALOG_OPEN = "★ 주문 카탈로그 및 스마트 프리셋"
L.GROUP_BURST = "주요 폭딜"
L.GROUP_DEFENSIVE = "주요 생존기"
L.GROUP_CC = "군중 제어 및 차단"
L.GROUP_GROUND = "바닥 효과"
L.EAM_GROUP_MANAGER_TITLE = "★ 그룹 관리 및 다중 태깅"
L.EAM_GROUP_MANAGER_SUBTITLE = "전술 범주 및 사용자 지정 태그 관리, 다중 그룹 할당 및 상황별 필터링 지원"
L.EAM_GROUP_NAME_LABEL = "그룹 이름:"
L.EAM_GROUP_ENABLE_ALL = "이 그룹 활성화"
L.EAM_GROUP_IN_COMBAT_ONLY = "전투 중에만 표시"
L.EAM_GROUP_SPELLS_HEADER = "이 그룹에 할당된 주문 목록 (다중 선택):"
L.EAM_GROUP_ADD_CUSTOM = "+ 그룹 추가"
L.EAM_GROUP_DELETE = "- 그룹 삭제"
L.EAM_NEW_GROUP_DEFAULT_NAME = "사용자 지정 그룹"
L.EAM_GROUP_COMBAT_BLOCKED = "전투 중에는 그룹 관리 패널을 열 수 없습니다."
L.EAM_CATALOG_TREE_TITLE = "★ 주문 카탈로그 및 스마트 프리셋"
L.EAM_CATALOG_TREE_SUBTITLE = "3단계 토글 및 특성 자동 동기화 기능이 있는 직업 핵심 능력의 계층적 트리 보기"
L.EAM_SEARCH_LABEL = "검색:"
L.EAM_AUTO_SYNC_TALENTS = "활성 특성 자동 동기화"
L.EAM_TALENT_SYNC_SUCCESS = "활성 특성에 맞는 핵심 능력이 성공적으로 동기화되었습니다!"
L.EAM_TOGGLE_ALL = "확장/축소"
L.EAM_CATALOG_COMBAT_BLOCKED = "전투 중에는 주문 카탈로그 패널을 열 수 없습니다."

L.EAM_GROUP_ASSIGN_LABEL = "소속 그룹 (다중 선택):"
L.EAM_GROUP_NONE = "(지정되지 않음)"
L.EAM_GROUP_SELECTED_COUNT = "%d개 그룹 선택됨"
L.EAM_CATALOG_TARGET_MODULE = "대상 모듈 목록:"
L.EAM_CATALOG_MOD_COOLDOWNS = "주문 재사용 대기시간"
L.EAM_CATALOG_MOD_PLAYER_AURAS = "자신 효과 (오라)"
L.EAM_CATALOG_MOD_TARGET_AURAS = "대상 효과 (오라)"
L.EAM_CATALOG_MOD_SPECIAL_AURAS = "특수 효과 (오라)"
L.EAM_CATALOG_MOD_GROUND = "바닥 효과"


-- Cooldown Reordering and Pre-rendering Placeholders
L.EAM_OPT_COOLDOWN_PRERENDER = "재사용 대기시간 사전 렌더링 자리표시자 (비활성 시 회색 마스크)"
L.EAM_OPT_COOLDOWN_PRERENDER_TIP = "비전투 상태에서 모든 재사용 대기시간 아이콘 슬롯을 미리 생성하고 배치합니다. 대기시간 중이 아닌 스킬은 흑백 마스크로 표시되어 전투 중 첫 시전 시 레이아웃 지연 문제를 완전히 해결합니다."
L.EAM_OPT_MOVE_UP = "위로 이동"
L.EAM_OPT_MOVE_DOWN = "아래로 이동"
L.EAM_OPT_ORDER_HINT = "▲/▼를 클릭하거나 드래그하여 화면 표시 순서를 조정할 수 있습니다."
L.EAM_OPT_PRERENDER_PLACEHOLDER = "사전 렌더링 자리표시자"

end)
