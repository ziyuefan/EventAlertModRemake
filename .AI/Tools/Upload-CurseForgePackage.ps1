<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: .AI\Tools\Upload-CurseForgePackage.ps1

狀態:
- CurseForge／WoWInterface 自動上傳依使用者要求暫停。
- GitHub Release 使用 Deploy 下的本機封裝工具與 gh 手動流程，不能由本檔代理。
#>
[CmdletBinding()]
param()

throw "CurseForge 自動上傳已停用。請勿啟用此入口；改用 Deploy\Build-Package.ps1 建包後走 GitHub Release。"
