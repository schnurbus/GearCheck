local _, GearCheck = ...
_G.GearCheck = GearCheck

GearCheck.version = "1.0.0"
GearCheck.results = {}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
	if name ~= "GearCheck" then return end
	GearCheckDB = GearCheckDB or {}
	if GearCheck.UI then
		GearCheck.UI:RestorePosition()
	end
	self:UnregisterEvent("ADDON_LOADED")
end)

function GearCheck:Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GearCheck|r: " .. tostring(message))
end

SLASH_GEARCHECK1 = "/gearcheck"
SLASH_GEARCHECK2 = "/gc"
SlashCmdList["GEARCHECK"] = function(message)
	message = strtrim(string.lower(message or ""))
	if message == "" or message == "show" or message == "fenster" then
		GearCheck.UI:Toggle()
	elseif message == "ziel" or message == "target" then
		GearCheck.UI:Show()
		GearCheck.Scan:ScanTarget()
	elseif message == "gruppe" or message == "group" or message == "raid" then
		GearCheck.UI:Show()
		GearCheck.Scan:ScanGroup()
	elseif message == "whisper" or message == "fluestern" or message == "flüstern" then
		GearCheck.Whisper:Confirm()
	else
		GearCheck:Print(GearCheck:T("HELP"))
	end
end
