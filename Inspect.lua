local _, GearCheck = ...

local InspectView = {}
GearCheck.InspectView = InspectView

local PANEL_WIDTH = 248
local DOCK = 28
local PANEL_OFFSET_Y = -18
local TAB_WIDTH = 16
local TAB_HEIGHT = 54
local TAB_Y = -58
local TAB_OVERHANG = 10
local TAB_LINE = 2
local VISIBLE_RIGHT = 28
local VISIBLE_LEFT = 10
local STATUS_ROWS = 8
local ROW_GAP = 2

local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.12, 1, 0.12 }
local RED = { 1, 0.2, 0.2 }
local MUTED = { 0.55, 0.55, 0.55 }
local WHITE = { 1, 1, 1 }
local RULE = { 0.55, 0.45, 0.2, 0.85 }

local PANEL_BACKDROP = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local watch = CreateFrame("Frame", nil, UIParent)
watch:SetWidth(1)
watch:SetHeight(1)
watch:SetAlpha(0)
watch:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
watch:Hide()
InspectView.watch = watch

local function setColor(font, color)
	font:SetTextColor(color[1], color[2], color[3])
end

local function makeRule(parent)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	rule:SetVertexColor(RULE[1], RULE[2], RULE[3], RULE[4])
	return rule
end

local function applyInsetStyle(frame)
	frame:SetBackdrop(PANEL_BACKDROP)
	frame:SetBackdropColor(0, 0, 0, 0.92)
	frame:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
end

local function averageLevel(gear)
	if not gear then return nil end
	local sum, count = 0, 0
	for index = 1, #gear do
		local level = gear[index].level
		if level and level > 0 then
			sum = sum + level
			count = count + 1
		end
	end
	if count == 0 then return nil end
	return math.floor(sum / count + 0.5)
end

local function isReady(record)
	return record and record.status == "done" and (not record.issues or #record.issues == 0)
end

local function readyLabel(record)
	if not record or record.status == "pending" or record.status == "scanning" then
		return GearCheck:T("SCANNING_DETAIL"), MUTED
	end
	if record.status ~= "done" then
		return record.statusText or GearCheck:T("NOT_INSPECTABLE_DETAIL"), RED
	end
	if isReady(record) then
		return GearCheck:T("READY_YES"), GREEN
	end
	return GearCheck:T("READY_NO"), RED
end

local function headerText(record)
	if not record or record.status == "pending" or record.status == "scanning" then
		return GearCheck:T("SCANNING_DETAIL")
	end
	if record.status ~= "done" then
		return record.statusText or GearCheck:T("NOT_INSPECTABLE_DETAIL")
	end
	return GearCheck.UI:SummaryText(record)
end

local function createStatusRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(14)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetJustifyH("LEFT")
	setColor(row.label, GOLD)
	row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value:SetJustifyH("RIGHT")
	setColor(row.value, WHITE)
	row:Hide()
	return row
end

local function paintStatusRow(row, label, value, color, width)
	row:SetWidth(width)
	row.label:SetWidth(math.floor(width * 0.48))
	row.value:SetWidth(math.floor(width * 0.5))
	row.label:SetText(label or "")
	row.value:SetText(value or "")
	setColor(row.value, color or WHITE)
	row:Show()
end

local function fillStatusRows(rows, record, width)
	local shown = 0
	local function add(label, value, color)
		shown = shown + 1
		if shown > #rows then return end
		paintStatusRow(rows[shown], label, value, color, width)
	end

	local readyText, readyColor = readyLabel(record)
	add(GearCheck:T("LABEL_READY"), readyText, readyColor)

	if record and record.status == "done" then
		add(GearCheck:T("LABEL_ROLE"), record.roleLabel or GearCheck:T("ROLE_UNKNOWN"), WHITE)
		local average = averageLevel(record.gear)
		if average then
			add(GearCheck:T("LABEL_ILVL"), tostring(average), WHITE)
		end
		local score = GearCheck:GearScoreFor(record)
		if score then
			add(GearCheck:T("LABEL_GS"), tostring(score), WHITE)
		end
		if record.defense and record.defense.summary then
			local color = MUTED
			if record.defense.immune == true then
				color = GREEN
			elseif record.defense.immune == false then
				color = RED
			end
			add(GearCheck:T("DEFENSE"), record.defense.summary, color)
		end
		local count = record.issues and #record.issues or 0
		add(GearCheck:T("LABEL_ISSUES"), tostring(count), count > 0 and RED or GREEN)
	end

	for index = shown + 1, #rows do
		rows[index]:Hide()
	end
	return shown
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
	applyInsetStyle(panel)
	panel:Hide()

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
	title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -10)
	title:SetJustifyH("CENTER")
	title:SetText("GearCheck")
	setColor(title, GOLD)
	self.title = title

	local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	name:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
	name:SetJustifyH("CENTER")
	self.nameText = name

	local ruleTop = makeRule(panel)
	ruleTop:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
	ruleTop:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -6)
	self.ruleTop = ruleTop

	local statusHost = CreateFrame("Frame", nil, panel)
	statusHost:SetPoint("TOPLEFT", ruleTop, "BOTTOMLEFT", 0, -6)
	statusHost:SetPoint("TOPRIGHT", ruleTop, "BOTTOMRIGHT", 0, -6)
	statusHost:SetHeight(STATUS_ROWS * (14 + ROW_GAP))
	self.statusHost = statusHost

	local statusRows = {}
	for index = 1, STATUS_ROWS do
		local row = createStatusRow(statusHost)
		if index == 1 then
			row:SetPoint("TOPLEFT", statusHost, "TOPLEFT", 0, 0)
		else
			row:SetPoint("TOPLEFT", statusRows[index - 1], "BOTTOMLEFT", 0, -ROW_GAP)
		end
		statusRows[index] = row
	end
	self.statusRows = statusRows

	local ruleMid = makeRule(panel)
	ruleMid:SetPoint("TOPLEFT", statusHost, "BOTTOMLEFT", 0, -4)
	ruleMid:SetPoint("TOPRIGHT", statusHost, "BOTTOMRIGHT", 0, -4)
	self.ruleMid = ruleMid

	local findings = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	findings:SetPoint("TOPLEFT", ruleMid, "BOTTOMLEFT", 0, -6)
	findings:SetText(GearCheck:T("SECTION_FINDINGS"))
	setColor(findings, GOLD)
	self.findingsLabel = findings

	-- Kept for collapse show/hide compatibility with previous layout.
	local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summary:Hide()
	self.summary = summary

	local scroll = CreateFrame("ScrollFrame", "GearCheckInspectScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", findings, "BOTTOMLEFT", -2, -4)
	self.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(200)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	self.content = content

	local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")
	self.body = body

	local function fitPanelButton(widget)
		local width = (widget:GetTextWidth() or 0) + 28
		if width < 48 then
			width = 48
		end
		widget:SetWidth(width)
	end
	self.fitPanelButton = fitPanelButton

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetHeight(22)
	button:SetPoint("BOTTOM", panel, "BOTTOM", 0, 10)
	button:SetText(GearCheck:T("BUTTON_WHISPER"))
	fitPanelButton(button)
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
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = true,
		tileSize = 16,
	})
	toggle:SetBackdropColor(0, 0, 0, 0.85)
	local function tabLine()
		local line = toggle:CreateTexture(nil, "ARTWORK")
		line:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		line:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
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
		self.lineTop:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
		self.lineBottom:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
		self.lineOuter:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
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
	panel:SetHeight(math.floor((parent:GetHeight() or 512) * 0.62))
	if side == "left" then
		panel:SetPoint("TOPRIGHT", parent, "TOPLEFT", DOCK, PANEL_OFFSET_Y)
	else
		panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", -DOCK, PANEL_OFFSET_Y)
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
		if self.ruleTop then self.ruleTop:Hide() end
		if self.statusHost then self.statusHost:Hide() end
		if self.ruleMid then self.ruleMid:Hide() end
		if self.findingsLabel then self.findingsLabel:Hide() end
		self.scroll:Hide()
		self.button:Hide()
		panel:Hide()
	else
		panel:SetWidth(PANEL_WIDTH)
		self.title:Show()
		self.nameText:Show()
		if self.ruleTop then self.ruleTop:Show() end
		if self.statusHost then self.statusHost:Show() end
		if self.ruleMid then self.ruleMid:Show() end
		if self.findingsLabel then self.findingsLabel:Show() end
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

local function roleColor(entry, playerRole)
	if not entry.role then
		return 0.55, 0.55, 0.55
	end
	if entry.fit == false then
		return 1, 0.45, 0.45
	end
	if playerRole and playerRole ~= "unknown" then
		if entry.role == playerRole then
			return 0.5, 1, 0.5
		end
		if entry.fit then
			return 1, 0.82, 0.35
		end
		return 1, 0.45, 0.45
	end
	return 0.9, 0.9, 0.9
end

local function issuesBySlot(record)
	local grouped = {}
	local issues = record and record.issues
	if not issues then return grouped end
	for index = 1, #issues do
		local issue = issues[index]
		local list = grouped[issue.slot]
		if not list then
			list = {}
			grouped[issue.slot] = list
		end
		list[#list + 1] = issue.text
	end
	return grouped
end

local function paintIcon(widget, entry)
	if entry.texture then
		widget.icon:SetTexture(entry.texture)
	elseif entry.link then
		widget.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	else
		widget.icon:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	end
	if entry.link then
		widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		widget.icon:SetVertexColor(1, 1, 1)
	else
		widget.icon:SetTexCoord(0, 1, 0, 1)
		widget.icon:SetVertexColor(0.15, 0.15, 0.15)
	end
end

function InspectView:EnsureTab()
	if self.tab or not InspectFrame then return end
	local id = (InspectFrame.numTabs or 3) + 1
	local previous = _G["InspectFrameTab" .. (id - 1)]
	if not previous or not InspectFrameTab_OnClick then return end

	local tab = CreateFrame("Button", "InspectFrameTab" .. id, InspectFrame, "CharacterFrameTabButtonTemplate")
	tab:SetID(id)
	tab:SetText("GearCheck")
	tab:SetPoint("LEFT", previous, "RIGHT", -15, 0)
	tab:SetScript("OnClick", function(self)
		InspectFrameTab_OnClick(self)
	end)
	PanelTemplates_SetNumTabs(InspectFrame, id)
	PanelTemplates_TabResize(tab, 0)
	local highlight = _G[tab:GetName() .. "HighlightTexture"]
	if highlight then
		highlight:SetWidth(tab:GetTextWidth() + 30)
	end
	self.tab = tab
	self.tabId = id

	local page = CreateFrame("Frame", "GearCheckInspectPage", InspectFrame, "GearCheckInspectTemplate")
	page:Hide()
	self.page = page
	local inset = _G[page:GetName() .. "Inset"]
	self.pageInset = inset
	if inset then
		applyInsetStyle(inset)
	end
	self.pageSummary = _G[page:GetName() .. "InsetSummary"]
	self.pageReady = _G[page:GetName() .. "InsetReady"]
	self.pageScroll = _G[page:GetName() .. "InsetScroll"]
	self.pageButton = _G[page:GetName() .. "InsetWhisper"]
	self.portrait = _G[page:GetName() .. "Portrait"]
	local function fitWhisperButton(button)
		local width = (button:GetTextWidth() or 0) + 28
		if width < 48 then
			width = 48
		end
		button:SetWidth(width)
	end
	self.fitWhisperButton = fitWhisperButton
	self.pageButton:SetText(GearCheck:T("BUTTON_WHISPER"))
	fitWhisperButton(self.pageButton)
	self.pageButton:SetScript("OnClick", function()
		if InspectView.record then
			GearCheck.Whisper:ConfirmOne(InspectView.record)
		end
	end)

	local scroll = self.pageScroll
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(240)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	self.pageContent = content

	local gearHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	gearHeader:SetJustifyH("LEFT")
	gearHeader:SetText(GearCheck:T("SECTION_GEAR"))
	setColor(gearHeader, GOLD)
	self.pageGearHeader = gearHeader

	local gearRule = makeRule(content)
	self.pageGearRule = gearRule

	local rows = {}
	local count = #GearCheck.Data.slots
	for index = 1, count do
		local widget = CreateFrame("Button", nil, content)
		widget:SetHeight(36)
		widget:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		local rowHighlight = widget:GetHighlightTexture()
		if rowHighlight then
			rowHighlight:SetBlendMode("ADD")
		end
		widget.slot = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		widget.slot:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -6)
		widget.slot:SetWidth(84)
		widget.slot:SetJustifyH("RIGHT")
		widget.icon = widget:CreateTexture(nil, "ARTWORK")
		widget.icon:SetWidth(22)
		widget.icon:SetHeight(22)
		widget.icon:SetPoint("TOPLEFT", widget, "TOPLEFT", 88, -2)
		widget.shade = widget:CreateTexture(nil, "BACKGROUND")
		widget.shade:SetPoint("TOPLEFT", widget.icon, "TOPLEFT", -1, 1)
		widget.shade:SetPoint("BOTTOMRIGHT", widget.icon, "BOTTOMRIGHT", 1, -1)
		widget.shade:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		widget.shade:SetVertexColor(0, 0, 0, 0.9)
		widget.border = widget:CreateTexture(nil, "OVERLAY")
		widget.border:SetPoint("TOPLEFT", widget.icon, "TOPLEFT", -1, 1)
		widget.border:SetPoint("BOTTOMRIGHT", widget.icon, "BOTTOMRIGHT", 1, -1)
		widget.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		widget.border:SetBlendMode("ADD")
		widget.border:SetAlpha(0.35)
		widget.name = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		widget.name:SetPoint("TOPLEFT", widget, "TOPLEFT", 114, -1)
		widget.name:SetHeight(14)
		widget.name:SetJustifyH("LEFT")
		widget.name:SetJustifyV("MIDDLE")
		widget.level = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		widget.level:SetPoint("TOPLEFT", widget, "TOPLEFT", 114, -16)
		widget.level:SetWidth(32)
		widget.level:SetJustifyH("LEFT")
		widget.role = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		widget.role:SetPoint("TOPLEFT", widget.level, "TOPRIGHT", 4, 0)
		widget.role:SetJustifyH("LEFT")
		widget.issues = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		widget.issues:SetPoint("TOPLEFT", widget, "TOPLEFT", 114, -32)
		widget.issues:SetJustifyH("LEFT")
		widget.issues:SetJustifyV("TOP")
		setColor(widget.issues, RED)
		widget.rule = makeRule(widget)
		widget.rule:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 0, 0)
		widget.rule:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", 0, 0)
		widget.rule:SetVertexColor(1, 1, 1, 0.08)
		widget:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.link then
				local shown = pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
				if not shown then
					GameTooltip:ClearLines()
					GameTooltip:SetText(self.itemName or self.slotName or "")
				end
				if self.roleLabel then
					GameTooltip:AddLine(self.roleLabel, self.roleR or 1, self.roleG or 1, self.roleB or 1)
				end
			else
				GameTooltip:ClearLines()
				GameTooltip:SetText(self.slotName or "")
				GameTooltip:AddLine(GearCheck:T("EMPTY"), 0.7, 0.7, 0.7)
			end
			GameTooltip:Show()
		end)
		widget:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		widget:SetScript("OnClick", function(self)
			if self.link and IsModifiedClick("CHATLINK") then
				ChatEdit_InsertLink(self.link)
			end
		end)
		widget:Hide()
		rows[index] = widget
	end
	self.gearRows = rows

	local findingsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	findingsHeader:SetJustifyH("LEFT")
	findingsHeader:SetText(GearCheck:T("SECTION_FINDINGS"))
	setColor(findingsHeader, GOLD)
	self.pageFindingsHeader = findingsHeader

	local findingsRule = makeRule(content)
	self.pageFindingsRule = findingsRule

	local leftover = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leftover:SetJustifyH("LEFT")
	leftover:SetJustifyV("TOP")
	leftover:SetText("")
	self.pageLeftover = leftover

	local accum = 0
	page:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + elapsed
		if accum < 0.2 then return end
		accum = 0
		InspectView:PolishPage()
	end)
end

function InspectView:OnTab(newID)
	if not self.page then return end
	if newID ~= self.tabId then
		self.page:Hide()
		self.page:SetFrameLevel(1)
		return
	end
	local level = (InspectFrame:GetFrameLevel() or 1) + 1
	self.page:SetFrameLevel(level)
	if InspectNameFrame then
		InspectNameFrame:SetFrameLevel(level + 3)
	end
	if InspectFrameCloseButton then
		InspectFrameCloseButton:SetFrameLevel(level + 4)
	end
	local tabs = InspectFrame.numTabs or 4
	for index = 1, tabs do
		local tab = _G["InspectFrameTab" .. index]
		if tab then
			tab:SetFrameLevel(level + 5)
		end
	end
	self.page:Show()
	self:RenderPage()
end

local function paintGearRow(widget, entry, issueText, playerRole)
	widget.link = entry.link
	widget.slotName = entry.name
	widget.itemName = entry.itemName
	widget.slot:SetText(entry.name or "")
	if issueText ~= "" then
		setColor(widget.slot, RED)
		if widget.border then
			widget.border:SetVertexColor(RED[1], RED[2], RED[3])
			widget.border:SetAlpha(0.55)
		end
	else
		setColor(widget.slot, GOLD)
		if widget.border then
			widget.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
			widget.border:SetAlpha(0.3)
		end
	end
	paintIcon(widget, entry)
	if entry.itemName then
		widget.name:SetText(entry.itemName)
		local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality or 1]
		if color then
			widget.name:SetTextColor(color.r, color.g, color.b)
		else
			setColor(widget.name, WHITE)
		end
	elseif entry.link then
		widget.name:SetText("...")
		setColor(widget.name, WHITE)
	else
		widget.name:SetText(GearCheck:T("EMPTY"))
		setColor(widget.name, MUTED)
	end
	if entry.level then
		widget.level:SetText(entry.level)
		local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality or 1]
		if color then
			widget.level:SetTextColor(color.r, color.g, color.b)
		else
			setColor(widget.level, WHITE)
		end
	else
		widget.level:SetText("")
	end
	if entry.role then
		local label = GearCheck.Data.RoleLabel(entry.role)
		local r, g, b = roleColor(entry, playerRole)
		widget.role:SetText(label)
		widget.role:SetTextColor(r, g, b)
		widget.roleLabel = label
		widget.roleR, widget.roleG, widget.roleB = r, g, b
	else
		widget.role:SetText(entry.empty and "" or "—")
		setColor(widget.role, MUTED)
		widget.roleLabel = nil
	end
	widget.issues:SetText(issueText)
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

function InspectView:PolishPage()
	if not self.page or not self.page:IsShown() then return end
	local record = self.record
	if not record or record.status ~= "done" or not GearCheck.Classify.Complete then return end
	local before = countedLevels(record)
	GearCheck.Classify.Complete(record)
	if countedLevels(record) ~= before then
		self:RenderPage()
	end
end

function InspectView:RenderPage()
	local page = self.page
	if not page or not page:IsShown() then return end
	local record = self.record
	if record and record.status == "done" and GearCheck.Classify.Complete then
		GearCheck.Classify.Complete(record)
	end

	local unit = InspectFrame and InspectFrame.unit
	if unit and UnitExists(unit) and self.portrait then
		SetPortraitTexture(self.portrait, unit)
	end

	local inset = self.pageInset
	local textWidth = math.max(((inset and inset:GetWidth()) or (page:GetWidth() or 384) - 52) - 20, 150)
	local summary = self.pageSummary
	summary:SetWidth(textWidth)
	summary:SetText(headerText(record))

	local ready = self.pageReady
	if ready then
		local readyText, readyColor = readyLabel(record)
		ready:SetText(GearCheck:T("LABEL_READY") .. ": " .. readyText)
		setColor(ready, readyColor)
	end

	local showButton = self:CanWhisper(record)
	local button = self.pageButton
	if showButton then
		button:Show()
		if GearCheck.Whisper and GearCheck.Whisper:IsBusy() then
			button:Disable()
			button:SetText(GearCheck:T("WHISPERING"))
		else
			button:Enable()
			button:SetText(GearCheck:T("BUTTON_WHISPER"))
		end
		if self.fitWhisperButton then
			self.fitWhisperButton(button)
		end
		if ready then
			ready:ClearAllPoints()
			ready:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 10, 8)
			ready:SetPoint("RIGHT", button, "LEFT", -8, 0)
		end
	else
		button:Hide()
		if ready then
			ready:ClearAllPoints()
			ready:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 10, 8)
			ready:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 8)
		end
	end

	local scroll = self.pageScroll
	local offset = scroll:GetVerticalScroll() or 0
	if self.pageGuid ~= self.guid then
		self.pageGuid = self.guid
		offset = 0
	end

	local rowWidth = math.max((scroll:GetWidth() or textWidth) - 4, 140)
	local nameWidth = math.max(rowWidth - 116, 40)
	local gear = record and record.status == "done" and record.gear
	local grouped = issuesBySlot(record)
	local used = {}
	local playerRole = record and record.role
	local y = 0
	local content = self.pageContent

	local gearHeader = self.pageGearHeader
	local gearRule = self.pageGearRule
	if gear then
		gearHeader:ClearAllPoints()
		gearHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		gearHeader:SetWidth(rowWidth)
		gearHeader:Show()
		y = y + (gearHeader:GetStringHeight() or 14) + 2
		gearRule:ClearAllPoints()
		gearRule:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		gearRule:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
		gearRule:Show()
		y = y + 6
	else
		gearHeader:Hide()
		gearRule:Hide()
	end

	for index = 1, #self.gearRows do
		local widget = self.gearRows[index]
		local entry = gear and gear[index]
		if not entry then
			widget:Hide()
		else
			local slotIssues = grouped[entry.name]
			local issueText = slotIssues and table.concat(slotIssues, "\n") or ""
			used[entry.name] = true
			widget.name:SetWidth(nameWidth)
			widget.role:SetWidth(math.max(nameWidth - 36, 40))
			widget.issues:SetWidth(nameWidth)
			paintGearRow(widget, entry, issueText, playerRole)
			local issueHeight = 0
			if issueText ~= "" then
				issueHeight = widget.issues:GetStringHeight() or 0
				if issueHeight < 1 then
					issueHeight = #slotIssues * 12
				end
			end
			local height = issueHeight > 0 and (34 + issueHeight) or 36
			widget:SetWidth(rowWidth)
			widget:SetHeight(height)
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
			y = y + height + 2
			widget:Show()
		end
	end

	local findingsHeader = self.pageFindingsHeader
	local findingsRule = self.pageFindingsRule
	y = y + 6
	findingsHeader:ClearAllPoints()
	findingsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	findingsHeader:SetWidth(rowWidth)
	findingsHeader:Show()
	y = y + (findingsHeader:GetStringHeight() or 14) + 2
	findingsRule:ClearAllPoints()
	findingsRule:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	findingsRule:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
	findingsRule:Show()
	y = y + 6

	local findings = {}
	if record and record.status == "done" then
		if not record.issues or #record.issues == 0 then
			findings[1] = "|cff1eff1e" .. GearCheck:T("NO_ISSUES") .. "|r"
		else
			for index = 1, #record.issues do
				local issue = record.issues[index]
				findings[#findings + 1] = "|cffff3333" .. issue.slot .. ":|r " .. issue.text
			end
		end
	end
	for name, list in pairs(grouped) do
		if not used[name] then
			for index = 1, #list do
				findings[#findings + 1] = "|cffff3333" .. name .. ":|r " .. list[index]
			end
		end
	end

	local leftover = self.pageLeftover
	leftover:ClearAllPoints()
	leftover:SetWidth(rowWidth)
	leftover:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	if #findings > 0 then
		leftover:SetText(table.concat(findings, "\n"))
		local extraHeight = leftover:GetStringHeight() or 0
		if extraHeight < 1 then
			extraHeight = #findings * 12
		end
		y = y + extraHeight + 4
	else
		leftover:SetText("")
	end

	content:SetWidth(rowWidth)
	content:SetHeight(math.max(y, 1))
	scroll:UpdateScrollChildRect()
	local range = scroll:GetVerticalScrollRange() or 0
	if offset > range then
		offset = range
	end
	scroll:SetVerticalScroll(offset)
end

function InspectView:Render()
	self:RenderPage()
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
	local textWidth = math.max((panel:GetWidth() or PANEL_WIDTH) - 24, 140)
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
		setColor(name, WHITE)
	end
	name:SetText(record and record.name or "")

	local shown = fillStatusRows(self.statusRows, record, textWidth)
	local hostHeight = math.max(shown, 1) * (14 + ROW_GAP)
	self.statusHost:SetHeight(hostHeight)

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
		if self.fitPanelButton then
			self.fitPanelButton(self.button)
		end
	else
		self.button:Hide()
	end

	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", self.findingsLabel, "BOTTOMLEFT", -2, -4)
	if showButton then
		self.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 36)
	else
		self.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 12)
	end

	self.body:SetWidth(textWidth)
	if record and record.status == "done" then
		self.body:SetText(GearCheck.UI:IssuesText(record))
	elseif record and (record.status == "pending" or record.status == "scanning") then
		self.body:SetText("|cff888888" .. GearCheck:T("SCANNING_DETAIL") .. "|r")
	elseif record then
		self.body:SetText("|cffff3333" .. (record.statusText or GearCheck:T("NOT_INSPECTABLE_DETAIL")) .. "|r")
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
	local pageShown = self.page and self.page:IsShown()
	local panelShown = self.panel and self.panel:IsShown()
	if panelShown then
		self:Render()
	elseif pageShown then
		self:RenderPage()
	end
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
	self.pageGuid = nil
	self.side = nil
	self:StopWatch()
	if self.panel then
		self.panel:Hide()
	end
	if self.page then
		self.page:Hide()
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
	self:EnsureTab()
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
	self:EnsureTab()

	if not self.switchHooked and InspectSwitchTabs then
		self.switchHooked = true
		local originalSwitch = InspectSwitchTabs
		InspectSwitchTabs = function(newID)
			if newID == InspectView.tabId then
				if INSPECTFRAME_SUBFRAMES then
					for index = 1, #INSPECTFRAME_SUBFRAMES do
						local sub = _G[INSPECTFRAME_SUBFRAMES[index]]
						if sub then
							sub:Hide()
						end
					end
				end
				PanelTemplates_SetTab(InspectFrame, newID)
				InspectView:OnTab(newID)
				return
			end
			if PanelTemplates_GetSelectedTab(InspectFrame) == InspectView.tabId then
				PanelTemplates_SetTab(InspectFrame, 1)
			end
			originalSwitch(newID)
			InspectView:OnTab(newID)
		end
	end

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
