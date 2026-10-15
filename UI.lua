local _, GearCheck = ...

local UI = {}
GearCheck.UI = UI

local MAX_ROWS = 40
local ROW_HEIGHT = 22
local GEAR_ROW = 28
local GEAR_COL = 240
local GEAR_LEFT = 10

local frame = CreateFrame("Frame", "GearCheckFrame", UIParent)
frame:SetWidth(840)
frame:SetHeight(560)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:Hide()
UI.frame = frame

tinsert(UISpecialFrames, "GearCheckFrame")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("GearCheck")

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", title, "BOTTOM", 0, -6)
status:SetWidth(780)
status:SetJustifyH("CENTER")
status:SetText(GearCheck:T("READY"))
UI.status = status

local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
listLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -58)
listLabel:SetText(GearCheck:T("PLAYERS"))

local detailLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 310, -58)
detailLabel:SetText(GearCheck:T("FINDINGS"))

local listScroll = CreateFrame("ScrollFrame", "GearCheckListScroll", frame, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)
listScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 52)
listScroll:SetWidth(270)
UI.listScroll = listScroll

local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetWidth(246)
listContent:SetHeight(1)
listScroll:SetScrollChild(listContent)

local detailScroll = CreateFrame("ScrollFrame", "GearCheckDetailScroll", frame, "UIPanelScrollFrameTemplate")
detailScroll:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 20, 0)
detailScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 52)

local detailContent = CreateFrame("Frame", nil, detailScroll)
detailContent:SetWidth(360)
detailContent:SetHeight(1)
detailScroll:SetScrollChild(detailContent)

local summary = detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
summary:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 4, -4)
summary:SetJustifyH("LEFT")
summary:SetJustifyV("TOP")
summary:SetText(GearCheck:T("PROMPT"))

local body = detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
body:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 4, -4)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")
body:SetText("")

local gearSlots = {}
for index = 1, #GearCheck.Data.slots do
	local widget = CreateFrame("Button", nil, detailContent)
	widget:SetWidth(GEAR_COL - 8)
	widget:SetHeight(GEAR_ROW - 2)
	widget:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	local highlight = widget:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
	end
	widget.slot = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	widget.slot:SetPoint("LEFT", widget, "LEFT", 0, 0)
	widget.slot:SetWidth(84)
	widget.slot:SetJustifyH("RIGHT")
	widget.slot:SetJustifyV("MIDDLE")
	widget.icon = widget:CreateTexture(nil, "ARTWORK")
	widget.icon:SetWidth(22)
	widget.icon:SetHeight(22)
	widget.icon:SetPoint("LEFT", widget, "LEFT", 88, 0)
	widget.shade = widget:CreateTexture(nil, "BACKGROUND")
	widget.shade:SetPoint("TOPLEFT", widget.icon, "TOPLEFT", -1, 1)
	widget.shade:SetPoint("BOTTOMRIGHT", widget.icon, "BOTTOMRIGHT", 1, -1)
	widget.shade:SetTexture(0, 0, 0, 0.8)
	widget.level = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	widget.level:SetPoint("LEFT", widget.icon, "RIGHT", 4, 0)
	widget.level:SetWidth(32)
	widget.level:SetJustifyH("LEFT")
	widget.role = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	widget.role:SetPoint("LEFT", widget.level, "RIGHT", 2, 0)
	widget.role:SetPoint("RIGHT", widget, "RIGHT", -2, 0)
	widget.role:SetJustifyH("LEFT")
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
	gearSlots[index] = widget
end

local rows = {}
for index = 1, MAX_ROWS do
	local row = CreateFrame("Button", nil, listContent)
	row:SetHeight(ROW_HEIGHT - 2)
	row:SetWidth(246)
	if index == 1 then
		row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, 0)
	else
		row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -2)
	end
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.selected = row:CreateTexture(nil, "BACKGROUND")
	row.selected:SetAllPoints(row)
	row.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.selected:SetBlendMode("ADD")
	row.selected:Hide()
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.name:SetPoint("LEFT", row, "LEFT", 6, 0)
	row.name:SetWidth(120)
	row.name:SetJustifyH("LEFT")
	row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.info:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
	row.info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.info:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		UI.selectedKey = self.key
		UI:Refresh()
	end)
	row:Hide()
	rows[index] = row
end

local function button(text, width)
	local widget = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	widget:SetWidth(width)
	widget:SetHeight(24)
	widget:SetText(text)
	return widget
end

local targetButton = button(GearCheck:T("BUTTON_TARGET"), 150)
targetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 16)
targetButton:SetScript("OnClick", function()
	GearCheck.Scan:ScanTarget()
end)

local groupButton = button(GearCheck:T("BUTTON_GROUP"), 150)
groupButton:SetPoint("LEFT", targetButton, "RIGHT", 8, 0)
groupButton:SetScript("OnClick", function()
	GearCheck.Scan:ScanGroup()
end)

local whisperButton = button(GearCheck:T("BUTTON_WHISPER"), 210)
whisperButton:SetPoint("LEFT", groupButton, "RIGHT", 8, 0)
whisperButton:SetScript("OnClick", function()
	GearCheck.Whisper:Confirm()
end)
UI.whisperButton = whisperButton

frame:SetScript("OnDragStart", function(self)
	self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	UI:SavePosition()
end)
frame:SetScript("OnShow", function()
	UI:Refresh()
end)

local function findRecord(key)
	local results = GearCheck.results or {}
	for index = 1, #results do
		if results[index].key == key then
			return results[index]
		end
	end
	return nil
end

local function rowInfo(record)
	if record.status == "pending" or record.status == "scanning" then
		return GearCheck:T("SCANNING_SHORT")
	end
	if record.status ~= "done" then
		return record.statusText or GearCheck:T("NOT_INSPECTABLE")
	end
	if record.role == "unknown" then
		return GearCheck:T("ROLE_UNKNOWN")
	end
	local count = record.issues and #record.issues or 0
	if count > 0 then
		return string.format("%s |cffff8080%d|r", record.roleLabel or "", count)
	end
	return (record.roleLabel or "") .. " |cff80ff80OK|r"
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

local function channelByte(value)
	if value < 0 then value = 0 end
	if value > 1 then value = 1 end
	return math.floor(value * 255 + 0.5)
end

local function gearScoreText(score)
	local text = GearCheck:T("GEAR_SCORE", score)
	if type(GearScore_GetQuality) ~= "function" then
		return text
	end
	local ok, first, second, third = pcall(GearScore_GetQuality, score)
	if not ok or type(first) ~= "number" or type(second) ~= "number" or type(third) ~= "number" then
		return text
	end
	return string.format(
		"|cff%02x%02x%02x%s|r",
		channelByte(first),
		channelByte(third),
		channelByte(second),
		text
	)
end

function UI:SummaryText(record)
	if not record then
		return GearCheck:T("PROMPT")
	end
	if record.status == "pending" or record.status == "scanning" then
		return (record.name or "?") .. "\n" .. GearCheck:T("SCANNING_DETAIL")
	end
	if record.status ~= "done" then
		return (record.name or "?") .. "\n" .. (record.statusText or GearCheck:T("NOT_INSPECTABLE_DETAIL"))
	end
	local lines = {}
	local header = record.className or record.class or ""
	local color = record.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.class]
	if header ~= "" and color then
		header = string.format(
			"|cff%02x%02x%02x%s|r",
			math.floor(color.r * 255 + 0.5),
			math.floor(color.g * 255 + 0.5),
			math.floor(color.b * 255 + 0.5),
			header
		)
	end
	if record.level and record.level > 0 then
		header = header .. "  " .. GearCheck:T("LEVEL", record.level)
	end
	local average = averageLevel(record.gear)
	if average then
		header = header .. "  " .. GearCheck:T("AVG_ILVL", average)
	end
	local gearScore = GearCheck:GearScoreFor(record)
	if gearScore then
		header = header .. "  " .. gearScoreText(gearScore)
	end
	if header ~= "" then
		lines[#lines + 1] = header
	end
	local active = (record.roleLabel or GearCheck:T("ROLE_UNKNOWN")) .. "  " .. (record.trees or "")
	if record.secondary then
		local second = record.secondary
		lines[#lines + 1] = GearCheck:T("ACTIVE_SPEC") .. "  " .. active
		lines[#lines + 1] = GearCheck:T("SECOND_SPEC") .. "  " .. (second.label or GearCheck:T("ROLE_UNKNOWN")) .. "  " .. (second.trees or "")
	else
		lines[#lines + 1] = active
	end
	if record.defense and record.defense.summary then
		local defense = record.defense.summary
		if record.defense.immune == true then
			defense = "|cff80ff80" .. defense .. "|r"
		elseif record.defense.immune == false then
			defense = "|cffff8080" .. defense .. "|r"
		else
			defense = "|cffffff80" .. defense .. "|r"
		end
		lines[#lines + 1] = defense
	end
	if record.note then
		lines[#lines + 1] = "|cffffff80" .. record.note .. "|r"
	end
	return table.concat(lines, "\n")
end

function UI:IssuesText(record)
	if not record or record.status ~= "done" then
		return ""
	end
	if not record.issues or #record.issues == 0 then
		return "|cff80ff80" .. GearCheck:T("NO_ISSUES") .. "|r"
	end
	local lines = {}
	for index = 1, #record.issues do
		local issue = record.issues[index]
		lines[#lines + 1] = "|cffff8080" .. issue.slot .. ":|r " .. issue.text
	end
	return table.concat(lines, "\n")
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

local function issueSlots(record)
	local set = {}
	if record and record.issues then
		for index = 1, #record.issues do
			set[record.issues[index].slot] = true
		end
	end
	return set
end

local function placeGear(record, top)
	local gear = record and record.status == "done" and record.gear
	if not gear then
		for index = 1, #gearSlots do
			gearSlots[index]:Hide()
		end
		return 0
	end
	local issues = issueSlots(record)
	local playerRole = record.role
	for index = 1, #gearSlots do
		local widget = gearSlots[index]
		local entry = gear[index]
		local column = index <= GEAR_LEFT and 0 or 1
		local row = index <= GEAR_LEFT and (index - 1) or (index - GEAR_LEFT - 1)
		widget:ClearAllPoints()
		widget:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 2 + column * GEAR_COL, -(top + row * GEAR_ROW))
		if not entry then
			widget.link = nil
			widget:Hide()
		else
			widget.link = entry.link
			widget.slotName = entry.name
			widget.itemName = entry.itemName
			widget.slot:SetText(entry.name or "")
			if issues[entry.name] then
				widget.slot:SetTextColor(1, 0.45, 0.45)
			else
				widget.slot:SetTextColor(0.9, 0.8, 0.45)
			end
			if entry.texture then
				widget.icon:SetTexture(entry.texture)
			elseif entry.link then
				widget.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			else
				local _, empty = GetInventorySlotInfo(entry.key)
				widget.icon:SetTexture(empty or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head")
			end
			if entry.link then
				widget.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				widget.icon:SetVertexColor(1, 1, 1)
			else
				widget.icon:SetTexCoord(0, 1, 0, 1)
				widget.icon:SetVertexColor(0.45, 0.45, 0.45)
			end
			if entry.level then
				widget.level:SetText(entry.level)
				local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality or 1]
				if color then
					widget.level:SetTextColor(color.r, color.g, color.b)
				else
					widget.level:SetTextColor(1, 1, 1)
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
				widget.role:SetTextColor(0.55, 0.55, 0.55)
				widget.roleLabel = nil
			end
			widget:Show()
		end
	end
	return GEAR_LEFT * GEAR_ROW
end

function UI:SavePosition()
	if not GearCheckDB then return end
	local point, _, relativePoint, x, y = self.frame:GetPoint(1)
	if not point then return end
	GearCheckDB.point = point
	GearCheckDB.relativePoint = relativePoint
	GearCheckDB.x = x
	GearCheckDB.y = y
end

function UI:RestorePosition()
	if not GearCheckDB or not GearCheckDB.point then return end
	self.frame:ClearAllPoints()
	self.frame:SetPoint(GearCheckDB.point, UIParent, GearCheckDB.relativePoint or "CENTER", GearCheckDB.x or 0, GearCheckDB.y or 0)
end

function UI:Show()
	self.frame:Show()
end

function UI:Toggle()
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
	end
end

function UI:Refresh()
	local results = GearCheck.results or {}
	if self.seenScan ~= GearCheck.scanId then
		self.seenScan = GearCheck.scanId
		self.selectedKey = results[1] and results[1].key or nil
		if self.listScroll then
			self.listScroll:SetVerticalScroll(0)
		end
	elseif self.selectedKey and not findRecord(self.selectedKey) then
		self.selectedKey = results[1] and results[1].key or nil
	end

	local shown = math.min(#results, MAX_ROWS)
	for index = 1, MAX_ROWS do
		local row = rows[index]
		local record = results[index]
		if record and index <= shown then
			row.key = record.key
			row.name:SetText(record.name or "?")
			local color = record.class and RAID_CLASS_COLORS[record.class]
			if color then
				row.name:SetTextColor(color.r, color.g, color.b)
			else
				row.name:SetTextColor(1, 1, 1)
			end
			row.info:SetText(rowInfo(record))
			if record.key == self.selectedKey then
				row.selected:Show()
			else
				row.selected:Hide()
			end
			row:Show()
		else
			row.key = nil
			row:Hide()
			row.selected:Hide()
		end
	end
	listContent:SetHeight(math.max(shown * ROW_HEIGHT, 1))
	listScroll:UpdateScrollChildRect()

	local record = findRecord(self.selectedKey)
	if record and record.status == "done" and GearCheck.Classify.Complete then
		GearCheck.Classify.Complete(record)
	end
	local scrollPos = detailScroll:GetVerticalScroll() or 0
	if self.detailKey ~= self.selectedKey then
		self.detailKey = self.selectedKey
		scrollPos = 0
	end
	local textWidth = math.max((detailScroll:GetWidth() or 480) - 28, 160)
	summary:SetWidth(textWidth)
	local summaryString = self:SummaryText(record)
	summary:SetText(summaryString)
	local summaryHeight = summary:GetStringHeight() or 0
	if summaryString ~= "" and summaryHeight < 1 then
		local lines = 1
		for _ in string.gmatch(summaryString, "\n") do
			lines = lines + 1
		end
		summaryHeight = lines * 12
	end
	local gearTop = 4 + summaryHeight + (summaryHeight > 0 and 8 or 0)
	local gearHeight = placeGear(record, gearTop)
	local issuesTop = gearTop + gearHeight
	if gearHeight > 0 then
		issuesTop = issuesTop + 6
	end
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 4, -issuesTop)
	body:SetWidth(textWidth)
	body:SetText(self:IssuesText(record))
	local issuesHeight = body:GetStringHeight() or 0
	detailContent:SetWidth(math.max(textWidth + 8, GEAR_COL * 2 + 4))
	detailContent:SetHeight(math.max(issuesTop + issuesHeight + 12, 1))
	detailScroll:UpdateScrollChildRect()
	local range = detailScroll:GetVerticalScrollRange() or 0
	if scrollPos > range then
		scrollPos = range
	end
	detailScroll:SetVerticalScroll(scrollPos)

	status:SetText(GearCheck.Scan and GearCheck.Scan.status or GearCheck:T("READY"))

	if GearCheck.Whisper and GearCheck.Whisper:IsBusy() then
		whisperButton:Disable()
		whisperButton:SetText(GearCheck:T("WHISPERING"))
	else
		local count = GearCheck.Whisper and GearCheck.Whisper:Count() or 0
		if count > 0 then
			whisperButton:Enable()
			whisperButton:SetText(GearCheck:T("BUTTON_WHISPER_COUNT", count))
		else
			whisperButton:Disable()
			whisperButton:SetText(GearCheck:T("BUTTON_WHISPER"))
		end
	end
end

if GearCheckDB and GearCheckDB.point then
	UI:RestorePosition()
end
