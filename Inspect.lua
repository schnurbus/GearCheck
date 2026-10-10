local _, GearCheck = ...

local InspectView = {}
GearCheck.InspectView = InspectView

local PANEL_WIDTH = 260
local DOCK = 28
local TAB_WIDTH = 16
local TAB_HEIGHT = 54
local TAB_Y = -58
local TAB_OVERHANG = 10
local TAB_LINE = 2
local VISIBLE_RIGHT = 28
local VISIBLE_LEFT = 10

local watch = CreateFrame("Frame", nil, UIParent)
watch:SetWidth(1)
watch:SetHeight(1)
watch:SetAlpha(0)
watch:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
watch:Hide()
InspectView.watch = watch

local function headerText(record)
	if not record or record.status == "pending" or record.status == "scanning" then
		return GearCheck:T("SCANNING_DETAIL")
	end
	if record.status ~= "done" then
		return record.statusText or GearCheck:T("NOT_INSPECTABLE_DETAIL")
	end
	return GearCheck.UI:SummaryText(record)
end

function InspectView:CanWhisper(record)
	if not record or record.isPlayer or record.status ~= "done" then return false end
	if not record.issues or #record.issues == 0 then return false end
	if not record.name or record.name == "?" or record.name == UNKNOWN then return false end
	return true
end

function InspectView:Unit()
	local unit = InspectFrame and InspectFrame.unit
	if not unit or not UnitExists(unit) then return nil end
	if self.guid and UnitGUID(unit) ~= self.guid then return nil end
	return unit
end

function InspectView:TakeRecord(unit)
	local fresh = GearCheck.Scan:NewRecord(unit)
	if fresh.status == "unavailable" and fresh.statusText == GearCheck:T("OUT_OF_RANGE") then
		fresh.status = "pending"
		fresh.statusText = nil
	end
	return fresh
end

function InspectView:Attach()
	local record = self.record
	local results = GearCheck.results
	if not record or not results or self.following then return end
	for index = 1, #results do
		if results[index].key == record.key and results[index] ~= record then
			results[index] = record
			return
		end
	end
end

function InspectView:Unqueue(key)
	local queue = GearCheck.Scan.queue
	if not queue or not key then return end
	for index = #queue, 1, -1 do
		if queue[index].key == key then
			table.remove(queue, index)
		end
	end
end

function InspectView:StopWatch()
	self.phase = nil
	watch:UnregisterEvent("INSPECT_TALENT_READY")
	watch:Hide()
end

function InspectView:Fail(key)
	self:StopWatch()
	local record = self.record
	if record then
		record.status = "unavailable"
		record.statusText = GearCheck:T(key)
		record.issues = {}
	end
	self:Render()
end

function InspectView:Finish()
	if self.phase ~= "talent" and self.phase ~= "gems" then return end
	self:StopWatch()
	local unit = self:Unit()
	local record = self.record
	if not unit or not record then
		self:Fail("LEFT_RANGE")
		return
	end
	self:Attach()
	self:Unqueue(record.key)
	GearCheck.Scan:ApplyResult(record, unit, record.spec)
end

function InspectView:OnTalent()
	if self.phase ~= "talent" then return end
	if self.guid and GearCheck.Scan.lastGuid and GearCheck.Scan.lastGuid ~= self.guid then
		return
	end
	local unit = self:Unit()
	if not unit then
		self:Fail("LEFT_RANGE")
		return
	end
	local record = self.record
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
	self.phase = "gems"
	self.deadline = GetTime() + GearCheck.Scan.GEM_TIMEOUT
	if not GearCheck.Scan:NeedsGemWait(record) then
		self:Finish()
	end
end

function InspectView:OnWatch(elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	if self.phase == "talent" then
		if GetTime() > (self.deadline or 0) then
			self:Fail("INSPECT_FAILED")
		end
	elseif self.phase == "gems" then
		if not self:Unit() then
			self:Fail("LEFT_RANGE")
		elseif GetTime() >= (self.deadline or 0) or not GearCheck.Scan:NeedsGemWait(self.record) then
			self:Finish()
		end
	end
end

function InspectView:BeginRead(unit)
	self:StopWatch()
	self.following = false
	local record = self:TakeRecord(unit)
	self.record = record
	if record.status == "unavailable" then
		self:Render()
		return
	end
	record.status = "scanning"
	self.phase = "talent"
	self.deadline = GetTime() + GearCheck.Scan.TALENT_TIMEOUT
	watch:RegisterEvent("INSPECT_TALENT_READY")
	watch:Show()
	self:Render()
end

function InspectView:EnsurePanel()
	if self.panel then return end
	local panel = CreateFrame("Frame", "GearCheckInspectPanel", InspectFrame)
	panel:SetWidth(PANEL_WIDTH)
	panel:SetFrameStrata("HIGH")
	panel:EnableMouse(true)
	panel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	panel:Hide()

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
	title:SetText("GearCheck")
	self.title = title

	local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	name:SetJustifyH("LEFT")
	self.nameText = name

	local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
	summary:SetJustifyH("LEFT")
	summary:SetJustifyV("TOP")
	self.summary = summary

	local scroll = CreateFrame("ScrollFrame", "GearCheckInspectScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", -2, -8)
	self.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(240)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	self.content = content

	local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")
	self.body = body

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetHeight(24)
	button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 14)
	button:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 14)
	button:SetText(GearCheck:T("BUTTON_WHISPER"))
	button:SetScript("OnClick", function()
		if InspectView.record then
			GearCheck.Whisper:ConfirmOne(InspectView.record)
		end
	end)
	button:Hide()
	self.button = button

	local toggle = CreateFrame("Button", nil, InspectFrame)
	toggle:SetWidth(TAB_WIDTH)
	toggle:SetHeight(TAB_HEIGHT)
	toggle:SetFrameStrata("HIGH")
	toggle:SetHitRectInsets(-6, -6, -4, -4)
	toggle:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		tile = true,
		tileSize = 32,
	})
	local function tabLine()
		local line = toggle:CreateTexture(nil, "ARTWORK")
		line:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		line:SetVertexColor(0.78, 0.64, 0.32, 1)
		return line
	end
	toggle.lineTop = tabLine()
	toggle.lineBottom = tabLine()
	toggle.lineOuter = tabLine()
	local label = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER", toggle, "CENTER", 0, 1)
	toggle:SetFontString(label)
	toggle:SetText("<")
	local highlight = toggle:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	highlight:SetBlendMode("ADD")
	highlight:SetAlpha(0.2)
	highlight:SetPoint("TOPLEFT", toggle, "TOPLEFT", 1, -TAB_LINE)
	highlight:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", -1, TAB_LINE)
	toggle:SetScript("OnClick", function()
		InspectView:SetCollapsed(not InspectView:IsCollapsed())
	end)
	toggle:SetScript("OnEnter", function(self)
		self.lineTop:SetVertexColor(1, 0.88, 0.5, 1)
		self.lineBottom:SetVertexColor(1, 0.88, 0.5, 1)
		self.lineOuter:SetVertexColor(1, 0.88, 0.5, 1)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(InspectView:IsCollapsed() and GearCheck:T("EXPAND") or GearCheck:T("COLLAPSE"))
		GameTooltip:Show()
	end)
	toggle:SetScript("OnLeave", function(self)
		self.lineTop:SetVertexColor(0.78, 0.64, 0.32, 1)
		self.lineBottom:SetVertexColor(0.78, 0.64, 0.32, 1)
		self.lineOuter:SetVertexColor(0.78, 0.64, 0.32, 1)
		GameTooltip:Hide()
	end)
	toggle:Hide()
	self.toggle = toggle

	local accum = 0
	panel:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + elapsed
		if accum < 0.2 then return end
		accum = 0
		InspectView:Place()
		InspectView:Polish()
	end)

	self.panel = panel
end

function InspectView:Place()
	local parent = InspectFrame
	local panel = self.panel
	if not parent or not panel or not panel:IsShown() then return end
	local right = parent:GetRight()
	local screen = UIParent:GetWidth() or 0
	local side = "right"
	if right and right + PANEL_WIDTH - DOCK > screen then
		side = "left"
	end
	if side == self.side then return end
	self.side = side
	panel:ClearAllPoints()
	panel:SetHeight(math.floor((parent:GetHeight() or 512) * 0.5))
	if side == "left" then
		panel:SetPoint("TOPRIGHT", parent, "TOPLEFT", DOCK, 0)
	else
		panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", -DOCK, 0)
	end
	panel:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
	self:ApplyCollapse()
end

function InspectView:IsCollapsed()
	return GearCheckDB and GearCheckDB.inspectCollapsed or false
end

function InspectView:SetCollapsed(collapsed)
	GearCheckDB = GearCheckDB or {}
	GearCheckDB.inspectCollapsed = collapsed and true or false
	if not self.panel or not InspectFrame or not InspectFrame:IsShown() then
		self:ApplyCollapse()
		return
	end
	self.panel:Show()
	self:Place()
	self:Render()
end

function InspectView:ApplyCollapse()
	local panel = self.panel
	local toggle = self.toggle
	if not panel or not toggle then return end
	local parent = InspectFrame
	local collapsed = self:IsCollapsed()
	local leftward = (self.side == "left") == collapsed
	toggle:SetText(leftward and "<" or ">")
	if collapsed then
		self.title:Hide()
		self.nameText:Hide()
		self.summary:Hide()
		self.scroll:Hide()
		self.button:Hide()
		panel:Hide()
	else
		panel:SetWidth(PANEL_WIDTH)
		self.title:Show()
		self.nameText:Show()
		self.summary:Show()
		self.scroll:Show()
		if parent and parent:IsShown() then
			panel:Show()
		end
	end
	if not parent then
		toggle:Hide()
		return
	end
	local anchor = parent
	local level = (parent:GetFrameLevel() or 1) + 20
	if not collapsed then
		anchor = panel
		level = (panel:GetFrameLevel() or 1) + 10
	end
	toggle:SetParent(anchor)
	toggle:ClearAllPoints()
	toggle:SetFrameStrata("HIGH")
	toggle:SetFrameLevel(level)
	local lineTop = toggle.lineTop
	local lineBottom = toggle.lineBottom
	local lineOuter = toggle.lineOuter
	lineTop:ClearAllPoints()
	lineBottom:ClearAllPoints()
	lineOuter:ClearAllPoints()
	lineTop:SetHeight(TAB_LINE)
	lineBottom:SetHeight(TAB_LINE)
	lineOuter:SetWidth(TAB_LINE)
	lineTop:SetPoint("TOPLEFT", toggle, "TOPLEFT", 0, 0)
	lineTop:SetPoint("TOPRIGHT", toggle, "TOPRIGHT", 0, 0)
	lineBottom:SetPoint("BOTTOMLEFT", toggle, "BOTTOMLEFT", 0, 0)
	lineBottom:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", 0, 0)
	local leftInset = collapsed and VISIBLE_LEFT or 0
	local rightInset = collapsed and VISIBLE_RIGHT or 0
	if self.side == "left" then
		toggle:SetPoint("TOPLEFT", anchor, "TOPLEFT", leftInset - TAB_OVERHANG, TAB_Y)
		lineOuter:SetPoint("TOPLEFT", toggle, "TOPLEFT", 0, 0)
		lineOuter:SetPoint("BOTTOMLEFT", toggle, "BOTTOMLEFT", 0, 0)
	else
		toggle:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", TAB_OVERHANG - rightInset, TAB_Y)
		lineOuter:SetPoint("TOPRIGHT", toggle, "TOPRIGHT", 0, 0)
		lineOuter:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", 0, 0)
	end
	if parent:IsShown() then
		toggle:Show()
	else
		toggle:Hide()
	end
end

local function countedLevels(record)
	local count = 0
	local gear = record and record.gear
	if not gear then return 0 end
	for index = 1, #gear do
		if gear[index].level then
			count = count + 1
		end
	end
	return count
end

function InspectView:Polish()
	local record = self.record
	if not record or record.status ~= "done" or not GearCheck.Classify.Complete then return end
	local before = countedLevels(record)
	GearCheck.Classify.Complete(record)
	if countedLevels(record) ~= before then
		self:Render()
	end
end

function InspectView:Render()
	local panel = self.panel
	if not panel then return end
	if self:IsCollapsed() then
		self:ApplyCollapse()
		return
	end
	local record = self.record
	if record and record.status == "done" and GearCheck.Classify.Complete then
		GearCheck.Classify.Complete(record)
	end
	local textWidth = math.max((panel:GetWidth() or PANEL_WIDTH) - 52, 140)
	local offset = 0
	if self.scroll then
		offset = self.scroll:GetVerticalScroll() or 0
		if self.renderedGuid ~= self.guid then
			self.renderedGuid = self.guid
			offset = 0
		end
	end
	local name = self.nameText
	name:SetWidth(textWidth)
	if record and record.class and RAID_CLASS_COLORS[record.class] then
		local color = RAID_CLASS_COLORS[record.class]
		name:SetTextColor(color.r, color.g, color.b)
	else
		name:SetTextColor(1, 1, 1)
	end
	name:SetText(record and record.name or "")

	self.summary:SetWidth(textWidth)
	self.summary:SetText(headerText(record))

	local showButton = self:CanWhisper(record)
	if showButton then
		self.button:Show()
		if GearCheck.Whisper and GearCheck.Whisper:IsBusy() then
			self.button:Disable()
			self.button:SetText(GearCheck:T("WHISPERING"))
		else
			self.button:Enable()
			self.button:SetText(GearCheck:T("BUTTON_WHISPER"))
		end
	else
		self.button:Hide()
	end

	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", self.summary, "BOTTOMLEFT", -2, -8)
	if showButton then
		self.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 46)
	else
		self.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 16)
	end

	self.body:SetWidth(textWidth)
	if record and record.status == "done" then
		self.body:SetText(GearCheck.UI:IssuesText(record))
	else
		self.body:SetText("")
	end
	local text = self.body:GetText()
	local height = self.body:GetStringHeight() or 0
	if type(text) == "string" and text ~= "" and height < 1 then
		local lines = 1
		for _ in string.gmatch(text, "\n") do
			lines = lines + 1
		end
		height = lines * 12
	end
	self.content:SetWidth(textWidth)
	self.content:SetHeight(math.max(height + 4, 1))
	self.scroll:UpdateScrollChildRect()
	local range = self.scroll:GetVerticalScrollRange() or 0
	if offset > range then
		offset = range
	end
	self.scroll:SetVerticalScroll(offset)
	self:ApplyCollapse()
end

function InspectView:Refresh()
	if not self.panel or not self.panel:IsShown() then return end
	self:Render()
end

function InspectView:Shutdown()
	local scan = GearCheck.Scan
	if self.following and scan and scan.active and scan.active.record == self.record then
		local record = self.record
		local queued = false
		for index = 1, #scan.queue do
			if scan.queue[index] == record then
				queued = true
				break
			end
		end
		if not queued then
			record.status = "pending"
			table.insert(scan.queue, 1, record)
		end
		scan:ClearWatch()
	end
	self.guid = nil
	self.record = nil
	self.following = false
	self.renderedGuid = nil
	self.side = nil
	self:StopWatch()
	if self.panel then
		self.panel:Hide()
	end
	if self.toggle then
		self.toggle:Hide()
	end
	if GearCheck.Scan then
		GearCheck.Scan:ReleaseInspect()
	end
end

function InspectView:Open()
	if not InspectFrame or not InspectFrame:IsShown() then return end
	local unit = InspectFrame.unit
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
		self:Shutdown()
		return
	end

	local guid = UnitGUID(unit)
	self:EnsurePanel()
	GearCheck.Scan:HoldInspect(guid)
	self.guid = guid
	self.panel:Show()
	self.side = nil
	self:Place()

	local active = GearCheck.Scan.active
	if active and active.record and active.record.guid == guid then
		self:StopWatch()
		self.following = true
		self.record = active.record
		self:Render()
		return
	end

	self:BeginRead(unit)
end

local function holdFor(unit)
	if unit and not UnitIsUnit(unit, "player") then
		GearCheck.Scan:HoldInspect(UnitGUID(unit))
	end
end

function InspectView:Install()
	if self.installed then return end
	self.installed = true
	self:EnsurePanel()

	local originalShow = InspectFrame_Show
	InspectFrame_Show = function(unit)
		holdFor(unit)
		originalShow(unit)
		if InspectFrame:IsShown() then
			InspectView:Open()
		else
			GearCheck.Scan:ReleaseInspect()
		end
	end

	if InspectFrame_UnitChanged then
		local originalChanged = InspectFrame_UnitChanged
		InspectFrame_UnitChanged = function(self, ...)
			holdFor(self and self.unit)
			originalChanged(self, ...)
			InspectView:Open()
		end
	end

	InspectFrame:HookScript("OnHide", function()
		InspectView:Shutdown()
	end)

	if InspectFrame:IsShown() then
		InspectView:Open()
	end
end

watch:SetScript("OnEvent", function()
	InspectView:OnTalent()
end)
watch:SetScript("OnUpdate", function(_, elapsed)
	InspectView:OnWatch(elapsed)
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
	if name ~= "Blizzard_InspectUI" then return end
	InspectView:Install()
	loader:UnregisterEvent("ADDON_LOADED")
end)

if IsAddOnLoaded("Blizzard_InspectUI") then
	InspectView:Install()
end
