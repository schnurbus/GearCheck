local _, GearCheck = ...

local Whisper = {}
GearCheck.Whisper = Whisper

local PREFIX = "GearCheck: "
local MAX_LENGTH = 255
local INTERVAL = 1.5

Whisper.queue = {}

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetWidth(1)
frame:SetHeight(1)
frame:SetAlpha(0)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
frame:Hide()
Whisper.frame = frame

local accumulator = 0
frame:SetScript("OnUpdate", function(self, elapsed)
	accumulator = accumulator + elapsed
	if accumulator < 0.1 then return end
	accumulator = 0
	Whisper:Tick()
end)

StaticPopupDialogs["GEARCHECK_WHISPER"] = {
	text = GearCheck:T("WHISPER_MANY"),
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		GearCheck.Whisper:Start()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

local function splitBody(body)
	local messages = {}
	local budget = MAX_LENGTH - #PREFIX
	local rest = body or ""
	while #rest > 0 do
		if #rest <= budget then
			messages[#messages + 1] = PREFIX .. rest
			break
		end
		local slice = string.sub(rest, 1, budget)
		local breakAt
		for index = #slice, 1, -1 do
			if string.sub(slice, index, index) == " " then
				breakAt = index
				break
			end
		end
		if not breakAt or breakAt < 20 then
			breakAt = budget
		end
		local chunk = string.sub(rest, 1, breakAt)
		messages[#messages + 1] = PREFIX .. chunk
		rest = strtrim(string.sub(rest, breakAt + 1))
	end
	return messages
end

function Whisper:Body(record)
	local parts = {}
	parts[#parts + 1] = GearCheck:T("WHISPER_ROLE", record.roleLabel or GearCheck:T("ROLE_UNKNOWN"))
	local issues = record.issues or {}
	for index = 1, #issues do
		local issue = issues[index]
		parts[#parts + 1] = issue.slot .. ": " .. issue.text .. "."
	end
	return table.concat(parts, " ")
end

function Whisper:Collect()
	local targets = {}
	local results = GearCheck.results or {}
	for index = 1, #results do
		local record = results[index]
		local issues = record.issues
		if record.status == "done" and not record.isPlayer and issues and #issues > 0 and record.name and record.name ~= "?" and record.name ~= UNKNOWN then
			targets[#targets + 1] = record
		end
	end
	return targets
end

function Whisper:Count()
	return #self:Collect()
end

function Whisper:IsBusy()
	return self.queue and #self.queue > 0
end

function Whisper:Confirm()
	if self:IsBusy() then
		GearCheck:Print(GearCheck:T("WHISPER_BUSY"))
		return
	end
	local targets = self:Collect()
	if #targets == 0 then
		GearCheck:Print(GearCheck:T("WHISPER_NONE"))
		return
	end
	self.pending = targets
	local dialog = StaticPopupDialogs["GEARCHECK_WHISPER"]
	if #targets == 1 then
		dialog.text = GearCheck:T("WHISPER_ONE")
		StaticPopup_Show("GEARCHECK_WHISPER")
	else
		dialog.text = GearCheck:T("WHISPER_MANY")
		StaticPopup_Show("GEARCHECK_WHISPER", tostring(#targets))
	end
end

function Whisper:ConfirmOne(record)
	if self:IsBusy() then
		GearCheck:Print(GearCheck:T("WHISPER_BUSY"))
		return
	end
	local issues = record and record.issues
	if not record or record.isPlayer or record.status ~= "done" or not issues or #issues == 0 then
		GearCheck:Print(GearCheck:T("WHISPER_NONE"))
		return
	end
	if not record.name or record.name == "?" or record.name == UNKNOWN then
		GearCheck:Print(GearCheck:T("WHISPER_NONE"))
		return
	end
	self.pending = { record }
	StaticPopupDialogs["GEARCHECK_WHISPER"].text = GearCheck:T("WHISPER_ONE")
	if StaticPopup_Visible("GEARCHECK_WHISPER") then
		StaticPopup_Hide("GEARCHECK_WHISPER")
	end
	StaticPopup_Show("GEARCHECK_WHISPER")
end

function Whisper:Start()
	local targets = self.pending or {}
	self.pending = nil
	self.queue = {}
	for index = 1, #targets do
		local record = targets[index]
		if record.name and not record.isPlayer then
			local messages = splitBody(self:Body(record))
			for messageIndex = 1, #messages do
				self.queue[#self.queue + 1] = { name = record.name, text = messages[messageIndex] }
			end
		end
	end
	if #self.queue == 0 then
		GearCheck:Print(GearCheck:T("WHISPER_NONE"))
		return
	end
	GearCheck:Print(GearCheck:T("WHISPER_SENDING", #self.queue))
	self.nextAt = 0
	self.frame:Show()
	self:Tick()
end

function Whisper:Tick()
	if not self.queue or #self.queue == 0 then
		self.frame:Hide()
		return
	end
	if GetTime() < (self.nextAt or 0) then return end
	local entry = table.remove(self.queue, 1)
	SendChatMessage(entry.text, "WHISPER", nil, entry.name)
	self.nextAt = GetTime() + INTERVAL
	if GearCheck.UI then
		GearCheck.UI:Refresh()
	end
	if GearCheck.InspectView and GearCheck.InspectView.Refresh then
		GearCheck.InspectView:Refresh()
	end
	if #self.queue == 0 then
		self.frame:Hide()
		GearCheck:Print(GearCheck:T("WHISPER_DONE"))
	end
end
