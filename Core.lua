local _, GearCheck = ...
_G.GearCheck = GearCheck

GearCheck.version = GetAddOnMetadata("GearCheck", "Version") or "0.0.0"
GearCheck.results = {}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
	if name ~= "GearCheck" then return end
	GearCheckDB = GearCheckDB or {}
	if GearCheck.UI then
		GearCheck.UI:RestorePosition()
	end
	if GearCheck.Update then
		GearCheck.Update:Start()
	end
	self:UnregisterEvent("ADDON_LOADED")
end)

function GearCheck:Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GearCheck|r: " .. tostring(message))
end

local function scoreNumber(value)
	if type(value) ~= "number" or value <= 0 then return nil end
	return math.floor(value + 0.5)
end

local function scoreFromEntry(entry)
	if type(entry) ~= "table" then return nil end
	return scoreNumber(entry.GearScore)
end

function GearCheck:ReadGearScore(unit)
	if type(GearScore_GetScore) ~= "function" then return nil end
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
	local name = UnitName(unit)
	if not name or name == "" or name == UNKNOWN then return nil end
	local hasItem = false
	for slot = 1, 18 do
		if GetInventoryItemLink(unit, slot) then
			hasItem = true
			break
		end
	end
	if not hasItem then return nil end
	local ok, score = pcall(GearScore_GetScore, name, unit)
	if not ok then return nil end
	return scoreNumber(score)
end

function GearCheck:StoredGearScore(name)
	if type(name) ~= "string" or name == "" or name == "?" then return nil end
	if type(GS_Data) ~= "table" then return nil end
	local realm = GS_Data[GetRealmName()]
	if type(realm) ~= "table" then return nil end
	local players = realm.Players
	if type(players) == "table" then
		local score = scoreFromEntry(players[name])
		if score then return score end
	end
	return scoreFromEntry(realm[name])
end

function GearCheck:GearScoreFor(record)
	if not record or record.status ~= "done" then return nil end
	local unit = GearCheck.Scan and GearCheck.Scan:Resolve(record)
	local score = self:ReadGearScore(unit)
	if not score and record.gearScore then
		score = scoreNumber(record.gearScore)
	end
	if not score then
		score = self:StoredGearScore(record.name)
	end
	if score then
		record.gearScore = score
	end
	return score
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
