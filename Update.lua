local _, GearCheck = ...

local Update = {}
GearCheck.Update = Update

local ADDON_PREFIX = "GCVer"
local BROADCAST_GAP = 90
local RELEASE_URL = "https://github.com/schnurbus/GearCheck/releases"

local lastBroadcast = 0
local started = false
local replied = {}

local frame = CreateFrame("Frame")

local function parseVersion(value)
	if type(value) ~= "string" then return nil end
	local major, minor, patch = value:match("^(%d+)%.(%d+)%.(%d+)$")
	if not major then
		major, minor = value:match("^(%d+)%.(%d+)$")
		patch = "0"
	end
	if not major then
		major = value:match("^(%d+)$")
		minor, patch = "0", "0"
	end
	if not major then return nil end
	return tonumber(major), tonumber(minor) or 0, tonumber(patch) or 0
end

local function compareVersions(left, right)
	local l1, l2, l3 = parseVersion(left)
	local r1, r2, r3 = parseVersion(right)
	if not l1 or not r1 then return nil end
	if l1 ~= r1 then return l1 < r1 and -1 or 1 end
	if l2 ~= r2 then return l2 < r2 and -1 or 1 end
	if l3 ~= r3 then return l3 < r3 and -1 or 1 end
	return 0
end

local function isOwnSender(sender)
	if type(sender) ~= "string" or sender == "" then return true end
	local name = sender:match("^([^%-]+)") or sender
	return name == UnitName("player")
end

local function notify(remoteVersion)
	GearCheckDB = GearCheckDB or {}
	local seen = GearCheckDB.updateNotified
	if type(seen) == "string" then
		local vsSeen = compareVersions(remoteVersion, seen)
		if vsSeen and vsSeen <= 0 then return end
	end
	GearCheckDB.updateNotified = remoteVersion
	GearCheck:Print(GearCheck:T("UPDATE_AVAILABLE", remoteVersion, GearCheck.version, RELEASE_URL))
end

local function handleRemote(sender, version)
	if isOwnSender(sender) then return end
	if not parseVersion(version) then return end

	local vsLocal = compareVersions(version, GearCheck.version)
	if vsLocal and vsLocal > 0 then
		notify(version)
	end

	if not replied[sender] then
		replied[sender] = true
		SendAddonMessage(ADDON_PREFIX, GearCheck.version, "WHISPER", sender)
	end
end

local function broadcast(force)
	local now = GetTime()
	if not force and (now - lastBroadcast) < BROADCAST_GAP then return end
	lastBroadcast = now

	if IsInGuild() then
		SendAddonMessage(ADDON_PREFIX, GearCheck.version, "GUILD")
	end
	if GetNumRaidMembers() > 0 then
		SendAddonMessage(ADDON_PREFIX, GearCheck.version, "RAID")
	elseif GetNumPartyMembers() > 0 then
		SendAddonMessage(ADDON_PREFIX, GearCheck.version, "PARTY")
	end
end

local function onEvent(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		broadcast(true)
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, message, _, sender = ...
		if prefix ~= ADDON_PREFIX then return end
		if parseVersion(message) then
			handleRemote(sender, message)
		end
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
		broadcast(false)
	end
end

frame:SetScript("OnEvent", onEvent)

function Update:Start()
	if started then return end
	started = true

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	frame:RegisterEvent("RAID_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_GUILD_UPDATE")
end
