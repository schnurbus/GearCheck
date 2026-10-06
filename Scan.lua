local _, GearCheck = ...

local Scan = {}
GearCheck.Scan = Scan

-- 3.3.5 lässt etwa 6 Inspects in 10 Sekunden zu. Eine Sekunde Puffer, damit fremde AddOns die Grenze nicht sprengen.
local INSPECT_LIMIT = 6
local INSPECT_WINDOW = 11
local TALENT_TIMEOUT = 2
local GEM_TIMEOUT = 2.5

Scan.status = GearCheck:T("READY")
Scan.inspectsLeft = INSPECT_LIMIT
Scan.resetAt = 0
Scan.queue = {}
Scan.running = false

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetWidth(1)
frame:SetHeight(1)
frame:SetAlpha(0)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
frame:Hide()
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
Scan.frame = frame

local accumulator = 0
frame:SetScript("OnUpdate", function(self, elapsed)
	accumulator = accumulator + elapsed
	if accumulator < 0.15 then return end
	accumulator = 0
	Scan:Tick()
end)

frame:SetScript("OnEvent", function(self, event)
	if event == "INSPECT_TALENT_READY" then
		Scan:OnTalentReady()
	elseif event == "PLAYER_REGEN_DISABLED" and Scan.running then
		Scan:SetStatus(GearCheck:T("PAUSE_COMBAT"))
	elseif event == "PLAYER_REGEN_ENABLED" then
		Scan:Tick()
	end
end)

function Scan:SetStatus(text)
	if self.status == text then return end
	self.status = text
	self:UpdateUI()
end

function Scan:UpdateUI()
	if GearCheck.UI and GearCheck.UI.Refresh then
		GearCheck.UI:Refresh()
	end
end

function Scan:Wake()
	self.frame:Show()
end

function Scan:NoteInspect(unit)
	if type(unit) ~= "string" then return end
	if UnitIsUnit(unit, "player") then return end
	if UnitIsDeadOrGhost(unit) then return end
	if not CanInspect(unit) then return end
	local now = GetTime()
	if not self.resetAt or self.resetAt < now then
		self.resetAt = now + INSPECT_WINDOW
		self.inspectsLeft = INSPECT_LIMIT
	end
	self.inspectsLeft = self.inspectsLeft - 1
end

hooksecurefunc("NotifyInspect", function(unit)
	Scan:NoteInspect(unit)
end)

function Scan:HasBudget()
	if self.inspectsLeft <= 0 and self.resetAt and self.resetAt > GetTime() then
		return false
	end
	return true
end

function Scan:FindByGuid(guid)
	if not guid then return nil end
	if UnitGUID("player") == guid then return "player" end
	if GetNumRaidMembers() > 0 then
		for index = 1, GetNumRaidMembers() do
			local unit = "raid" .. index
			if UnitGUID(unit) == guid then return unit end
		end
	else
		for index = 1, GetNumPartyMembers() do
			local unit = "party" .. index
			if UnitGUID(unit) == guid then return unit end
		end
	end
	if UnitExists("target") and UnitGUID("target") == guid then
		return "target"
	end
	return nil
end

function Scan:Resolve(record)
	if not record then return nil end
	if record.isPlayer then return "player" end
	if record.unit and UnitExists(record.unit) and UnitGUID(record.unit) == record.guid then
		return record.unit
	end
	local found = self:FindByGuid(record.guid)
	if found then
		record.unit = found
		return found
	end
	return nil
end

function Scan:UnavailableReason(unit, isPlayer)
	if isPlayer then return nil end
	if not UnitExists(unit) then return GearCheck:T("NO_TARGET") end
	if not UnitIsPlayer(unit) then return GearCheck:T("NO_PLAYER") end
	if not UnitIsFriend("player", unit) then return GearCheck:T("FRIENDLY_ONLY") end
	if not UnitIsConnected(unit) then return GearCheck:T("OFFLINE") end
	if UnitIsDeadOrGhost(unit) then return GearCheck:T("DEAD") end
	if not CanInspect(unit) then return GearCheck:T("OUT_OF_RANGE") end
	return nil
end

function Scan:NewRecord(unit)
	local name = UnitName(unit)
	local className, classToken = UnitClass(unit)
	local isPlayer = UnitIsUnit(unit, "player") and true or false
	local record = {
		unit = isPlayer and "player" or unit,
		key = UnitGUID(unit) or (name or unit),
		guid = UnitGUID(unit),
		name = (name and name ~= UNKNOWN) and name or "?",
		class = classToken,
		className = className,
		level = UnitLevel(unit) or 0,
		isPlayer = isPlayer,
		status = "pending",
		issues = {},
	}
	local problem = self:UnavailableReason(unit, isPlayer)
	if problem then
		record.status = "unavailable"
		record.statusText = problem
	end
	return record
end

function Scan:ApplyResult(record, unit, spec)
	local level = UnitLevel(unit)
	if level and level > 0 then
		record.level = level
	end
	spec = spec or { role = "unknown", label = GearCheck.Data.RoleLabel("unknown"), trees = "0/0/0" }
	record.role = spec.role
	record.roleLabel = spec.label
	record.trees = spec.trees
	record.status = "done"
	record.statusText = nil
	record.gear = GearCheck.Classify.Gear(unit, {
		role = spec.role,
		class = record.class,
		level = record.level,
	})
	if spec.role == "unknown" then
		record.issues = {}
		record.note = GearCheck:T("SPEC_UNCLEAR")
	else
		local issues, note = GearCheck.Classify.Unit(unit, {
			role = spec.role,
			class = record.class,
			level = record.level,
		})
		record.issues = issues or {}
		record.note = note
	end
	self:UpdateUI()
end

function Scan:Evaluate(record)
	local spec = GearCheck.Roles.Read(record.class, false)
	self:ApplyResult(record, "player", spec)
end

function Scan:BeginSession()
	self.running = false
	self.queue = {}
	self.active = nil
	self.frame:UnregisterEvent("INSPECT_TALENT_READY")
	self.scanId = (self.scanId or 0) + 1
	GearCheck.scanId = self.scanId
	GearCheck.results = {}
end

function Scan:NeedsGemWait(record)
	local unit = self:Resolve(record)
	if not unit then return false end
	for index = 1, #GearCheck.Data.slots do
		local slot = GearCheck.Data.slots[index]
		local link = GetInventoryItemLink(unit, GearCheck.Data.SlotId(slot.key))
		local parsed = GearCheck.Classify.ParseLink(link)
		if parsed and GearCheck.Classify.GemCount(parsed) == 0 then
			local info = GearCheck.Classify.SocketInfo(link)
			if info and info.total > 0 then
				return true
			end
		end
	end
	return false
end

function Scan:ClearWatch()
	self.frame:UnregisterEvent("INSPECT_TALENT_READY")
	self.active = nil
end

function Scan:FailActive(text)
	local record = self.active and self.active.record
	self:ClearWatch()
	if not record then return end
	record.status = "unavailable"
	record.statusText = text
	record.issues = {}
	self:UpdateUI()
end

function Scan:FinishActive()
	local record = self.active and self.active.record
	local spec = record and record.spec
	self:ClearWatch()
	if not record then return end
	local unit = self:Resolve(record)
	if not unit then
		record.status = "unavailable"
		record.statusText = GearCheck:T("LEFT_RANGE")
		record.issues = {}
		self:UpdateUI()
		return
	end
	self:ApplyResult(record, unit, spec)
end

function Scan:OnTalentReady()
	local active = self.active
	if not active or active.phase ~= "talent" then return end
	local record = active.record
	local unit = self:Resolve(record)
	if not unit then
		self:FailActive(GearCheck:T("LEFT_RANGE"))
		return
	end
	local level = UnitLevel(unit)
	if level and level > 0 then
		record.level = level
	end
	if not record.class then
		local className, classToken = UnitClass(unit)
		record.className = className
		record.class = classToken
	end
	record.spec = GearCheck.Roles.Read(record.class, true)
	active.phase = "gems"
	active.deadline = GetTime() + GEM_TIMEOUT
	if not self:NeedsGemWait(record) then
		self:FinishActive()
	end
end

function Scan:Begin(record, unit)
	record.status = "scanning"
	record.unit = unit
	self.active = {
		record = record,
		phase = "talent",
		deadline = GetTime() + TALENT_TIMEOUT,
	}
	self.frame:RegisterEvent("INSPECT_TALENT_READY")
	self:SetStatus(GearCheck:T("SCANNING", record.name or "?", #self.queue))
	NotifyInspect(unit)
end

function Scan:Tick()
	if self.active then
		if self.active.phase == "talent" and GetTime() > self.active.deadline then
			self:FailActive(GearCheck:T("INSPECT_FAILED"))
		elseif self.active.phase == "gems" then
			if not self:Resolve(self.active.record) then
				self:FailActive(GearCheck:T("LEFT_RANGE"))
			elseif GetTime() >= self.active.deadline or not self:NeedsGemWait(self.active.record) then
				self:FinishActive()
			end
		end
		return
	end

	if InCombatLockdown() and #self.queue > 0 then
		self:SetStatus(GearCheck:T("PAUSE_COMBAT"))
		return
	end

	local skipped = false
	while #self.queue > 0 do
		local record = self.queue[1]
		local unit = self:Resolve(record)
		local problem
		if not unit then
			problem = GearCheck:T("OUT_OF_RANGE")
		else
			problem = self:UnavailableReason(unit, record.isPlayer)
		end
		if problem then
			table.remove(self.queue, 1)
			record.status = "unavailable"
			record.statusText = problem
			skipped = true
		else
			if not self:HasBudget() then
				if skipped then
					self:UpdateUI()
				end
				local remain = math.max(0, (self.resetAt or 0) - GetTime())
				self:SetStatus(GearCheck:T("INSPECT_WAIT", remain))
				return
			end
			table.remove(self.queue, 1)
			self:Begin(record, unit)
			return
		end
	end

	if skipped then
		self:UpdateUI()
	end
	if self.running then
		self:Complete()
	end
end

function Scan:Complete()
	if not self.running then return end
	self.running = false
	self:ClearWatch()
	local checked, problems, blocked = 0, 0, 0
	for index = 1, #GearCheck.results do
		local record = GearCheck.results[index]
		if record.status == "done" then
			checked = checked + 1
			if record.issues and #record.issues > 0 then
				problems = problems + 1
			end
		else
			blocked = blocked + 1
		end
	end
	local text = GearCheck:T("DONE", checked, problems, blocked)
	self.status = text
	self:UpdateUI()
	self.frame:Hide()
	GearCheck:Print(text)
end

function Scan:ScanTarget()
	self:BeginSession()
	self.running = true
	if not UnitExists("target") then
		GearCheck.results[1] = {
			key = "no-target",
			name = GearCheck:T("TARGET_NAME"),
			status = "unavailable",
			statusText = GearCheck:T("NO_TARGET"),
			issues = {},
		}
		self:Complete()
		return
	end
	local record = self:NewRecord("target")
	GearCheck.results[1] = record
	self:SetStatus(GearCheck:T("SCAN_TARGET"))
	if record.isPlayer then
		self:Evaluate(record)
		self:Complete()
	elseif record.status == "unavailable" then
		self:Complete()
	else
		self.queue[1] = record
		self:Wake()
		self:Tick()
	end
end

function Scan:ScanGroup()
	self:BeginSession()
	self.running = true
	local units = {}
	if GetNumRaidMembers() > 0 then
		for index = 1, GetNumRaidMembers() do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		for index = 1, GetNumPartyMembers() do
			units[#units + 1] = "party" .. index
		end
	end

	for index = 1, #units do
		local unit = units[index]
		if UnitExists(unit) then
			local record = self:NewRecord(unit)
			GearCheck.results[#GearCheck.results + 1] = record
			if record.isPlayer then
				self:Evaluate(record)
			elseif record.status == "pending" then
				self.queue[#self.queue + 1] = record
			end
		end
	end

	self:SetStatus(GearCheck:T("SCAN_GROUP", #GearCheck.results))
	if #self.queue == 0 then
		self:Complete()
	else
		self:Wake()
		self:Tick()
	end
end
