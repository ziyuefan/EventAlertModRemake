--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Animation.lua

理念:
- 保留舊版 EAM 行為參考，供 Retail rewrite migration 對照。
- 此檔不屬正式載入路徑；重寫時只取行為語意，不沿用舊架構。

責任:
- 說明此檔案在目前架構中的責任、資料所有權與維護定位。

邊界:
- 不得繞過 Secret/Protected Data。
- 不得在熱路徑製造不必要 table、closure 或字串配置。
- 若屬 LegacyReference，只能作為行為參考，不得直接成為新架構依賴。
]]
----------------------------------------------------
-- Assign addon space to local G var.  
-- For sync addon space to each lua fils
-----------------------------------------------------
local _
local _G = _G
local addonName, G = ... 
_G[addonName] = _G[addonName] or G
-----------------------------------
if LibDebug then LibDebug() end
-----------------------------------
-------------------------------------------
-- Package Animation Object for EASCDFrame
-------------------------------------------
local EAEXF 
EAEXF = {
	AlreadyAlert = false,
	FrameCount = 0,
	Prefraction = 0,
	totalTime = 0.6,		--動畫持續時間
	MaxCount = 19,			--最大張數
	FrameAnimTable = {},
	maxWidth = 256,
}
function EAEXF:AnimAlpha(fraction)
	
	local bgFilePath
	G.Image_Path = "Interface/AddOns/EventAlertMod/images/"	
	
	local o = EAEXF	
	local iAlpha = self:GetAlpha()	
	local iSize = self:GetWidth()	
	local maxWidth = o.maxWidth
	local stepSize = maxWidth / o.MaxCount
	
	if o.Prefraction == 0 then 
		o.Prefraction = fraction 
	end
		
	if o.Prefraction >= fraction + (o.totalTime) / o.MaxCount then
		o.FrameCount = o.FrameCount + 1
		if o.FrameCount >= o.MaxCount then o.FrameCount = o.MaxCount end
		local extName = "BLP"
		-- local extName = "TGA"
		
		bgFilePath = G.Image_Path.."Seed"..o.FrameCount.."."..extName		
		
		Lib_ZYF:SetBackdrop(self, {bgFile = bgFilePath })		
		iAlpha = iAlpha - (1 / o.MaxCount)		
		self:SetSize(iSize + stepSize, iSize + stepSize)
		o.Prefraction = fraction
	end
	
	if iAlpha < 0 then iAlpha = 0 end
	return iAlpha
end
function EAEXF:AnimFinished()
	local o = EAEXF	
	self:SetSize(o.maxWidth, o.maxWidth)
	self:Hide()
end
function EAEXF:AnimateOut(frame)	
	local o = EAEXF
	self.FrameAnimTable = {
				totalTime = o.totalTime,				
				updateFunc = "SetAlpha",
				getPosFunc = self.AnimAlpha,
				}	
	SetUpAnimation(frame, self.FrameAnimTable, self.AnimFinished, true)
end

G.EAEXF = EAEXF

-------------------------------------------
-- Package Animation Object for EASCDFrame 
-------------------------------------------
local EASCDFrame

EASCDFrame = {
		FrameAnimTable = {},
}
function EASCDFrame:AnimSize(fraction)
	local iAlpha = self:GetAlpha()
	local iSize = self:GetWidth()
	self:SetSize(iSize + 1, iSize + 1)
	return iAlpha - 0.02
end
-----------------------------------------------------------------
function EASCDFrame:AnimFinished()
	self:Hide()
end
-----------------------------------------------------------------
function EASCDFrame:AnimateOut(frame)
	self.FrameAnimTable = {
				totalTime = 0.5,
				updateFunc = "SetAlpha",
				getPosFunc = self.AnimSize
				}
	SetUpAnimation(frame, self.FrameAnimTable, self.AnimFinished, true)
end

G.EASCDFrame = EASCDFrame