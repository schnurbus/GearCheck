local _, GearCheck = ...

local UI = {}
GearCheck.UI = UI

local MAX_ROWS = 40
local ROW_HEIGHT = 22
local GEAR_ROW = 32
local GEAR_COL = 252
local GEAR_LEFT = 9
local SECTION_POOL = 6

local FRAME_WIDTH = 880
local FRAME_HEIGHT = 600
local LIST_WIDTH = 300

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ICON_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_NOT_READY = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_WAITING = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local ICON_ALERT = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"
local ICON_ENCHANT = "Interface\\Icons\\Trade_Engraving"
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local ROLE_ICONS = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local SOCKET_META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta"
local SOCKET_EMPTY = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"

local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.25, 1, 0.25 }
local RED = { 1, 0.3, 0.3 }
local YELLOW = { 1, 0.85, 0.3 }
local MUTED = { 0.55, 0.55, 0.55 }

local PANEL_BACKDROP = {
	bgFile = FLAT,
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function inlineIcon(path)
	return "|T" .. path .. ":12:12|t "
end

local function colorCode(color)
	return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

local function setColor(font, color)
	font:SetTextColor(color[1], color[2], color[3])
end

local function inset(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetBackdrop(PANEL_BACKDROP)
	panel:SetBackdropColor(0, 0, 0, 0.55)
	panel:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
	return panel
end

-- Rollen-Icon aus dem LFG-Bild (Raster 67 px auf 256 px).
local ROLE_GRID = { tank = { 1, 2 }, healer = { 2, 1 }, damage = { 2, 2 }, caster = { 2, 2 } }
local function setRoleIcon(texture, role)
	local cell = ROLE_GRID[role or ""]
	if not cell then
		texture:Hide()
		return
	end
	local size = 67 / 256
	texture:SetTexCoord((cell[1] - 1) * size, cell[1] * size, (cell[2] - 1) * size, cell[2] * size)
	texture:Show()
end

local function setClassIcon(texture, classToken)
	local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
	if not coords then
		texture:Hide()
		return
	end
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	texture:Show()
end

local function gemIcon(gemId)
	local icon = GetItemIcon and GetItemIcon(gemId)
	if not icon then
		icon = select(10, GetItemInfo(gemId))
	end
	return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Fenster ---------------------------------------------------------------

local frame = CreateFrame("Frame", "GearCheckFrame", UIParent)
frame:SetWidth(FRAME_WIDTH)
frame:SetHeight(FRAME_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop(PANEL_BACKDROP)
frame:SetBackdropColor(0.04, 0.04, 0.05, 0.94)
frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
frame:Hide()
UI.frame = frame

tinsert(UISpecialFrames, "GearCheckFrame")

local header = frame:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetWidth(300)
header:SetHeight(64)
header:SetPoint("TOP", frame, "TOP", 0, 12)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 8, -14)
title:SetText("GearCheck")

local titleIcon = frame:CreateTexture(nil, "OVERLAY")
titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
titleIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
titleIcon:SetWidth(16)
titleIcon:SetHeight(16)
titleIcon:SetPoint("RIGHT", title, "LEFT", -4, 0)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

-- Kopfzeile: Übersicht, Fortschritt, Filter ------------------------------

local overview = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
overview:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -30)
overview:SetWidth(560)
overview:SetJustifyH("LEFT")

local progress = CreateFrame("StatusBar", nil, frame)
progress:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -50)
progress:SetWidth(560)
progress:SetHeight(16)
progress:SetStatusBarTexture(BAR_TEXTURE)
progress:SetMinMaxValues(0, 1)
progress:SetValue(0)
local progressBack = progress:CreateTexture(nil, "BACKGROUND")
progressBack:SetAllPoints(progress)
progressBack:SetTexture(BAR_TEXTURE)
progressBack:SetVertexColor(0.15, 0.15, 0.15, 0.9)
local progressBorder = CreateFrame("Frame", nil, progress)
progressBorder:SetPoint("TOPLEFT", progress, "TOPLEFT", -3, 3)
progressBorder:SetPoint("BOTTOMRIGHT", progress, "BOTTOMRIGHT", 3, -3)
progressBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
progressBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

local status = progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("CENTER", progress, "CENTER", 0, 0)
status:SetWidth(550)
status:SetText(GearCheck:T("READY"))
UI.status = status

local function checkbox(name, label, anchorY, key, default)
	local box = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
	box:SetWidth(22)
	box:SetHeight(22)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 600, anchorY)
	local text = _G[name .. "Text"]
	if text then
		text:SetText(label)
		text:SetFontObject(GameFontHighlightSmall)
	end
	box.key = key
	box.default = default
	box:SetScript("OnClick", function(self)
		GearCheckDB = GearCheckDB or {}
		GearCheckDB[self.key] = self:GetChecked() and true or false
		UI:Refresh()
	end)
	return box
end

local function option(key, default)
	local value = GearCheckDB and GearCheckDB[key]
	if value == nil then return default end
	return value
end

local onlyProblemsBox = checkbox("GearCheckOnlyProblems", GearCheck:T("FILTER_PROBLEMS"), -28, "onlyProblems", false)
local sortIssuesBox = checkbox("GearCheckSortIssues", GearCheck:T("SORT_ISSUES"), -48, "sortIssues", true)

-- Spielerliste ------------------------------------------------------------

local listPanel = inset(frame)
listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -76)
listPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 48)
listPanel:SetWidth(LIST_WIDTH)

local listScroll = CreateFrame("ScrollFrame", "GearCheckListScroll", listPanel, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 6, -6)
listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -27, 6)
UI.listScroll = listScroll

-- Leere Scrollleisten (nur Pfeile und grauer Knopf) ausblenden, solange alles hineinpasst.
function UI.HideIdleScrollBar(scroll)
	scroll.scrollBarHideable = 1
	if ScrollFrame_OnScrollRangeChanged then
		ScrollFrame_OnScrollRangeChanged(scroll)
	end
end
UI.HideIdleScrollBar(listScroll)

local ROW_WIDTH = LIST_WIDTH - 36

local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetWidth(ROW_WIDTH)
listContent:SetHeight(1)
listScroll:SetScrollChild(listContent)

local listEmpty = listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
listEmpty:SetPoint("TOP", listPanel, "TOP", 0, -16)
listEmpty:SetWidth(LIST_WIDTH - 24)

-- Details -----------------------------------------------------------------

local detailPanel = inset(frame)
detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 8, 0)
detailPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 48)

local detailScroll = CreateFrame("ScrollFrame", "GearCheckDetailScroll", detailPanel, "UIPanelScrollFrameTemplate")
detailScroll:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -8)
detailScroll:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -27, 8)

UI.HideIdleScrollBar(detailScroll)

local detailContent = CreateFrame("Frame", nil, detailScroll)
detailContent:SetWidth(GEAR_COL * 2)
detailContent:SetHeight(1)
detailScroll:SetScrollChild(detailContent)

local summary = detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
summary:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 4, -4)
summary:SetJustifyH("LEFT")
summary:SetJustifyV("TOP")
summary:SetText(GearCheck:T("PROMPT"))

-- Ausrüstungsslots --------------------------------------------------------

local function enchantState(entry, kinds)
	if kinds.enchant then return "missing" end
	if kinds.enchantSmall then return "small" end
	if entry.enchant and entry.enchant > 0 then return "ok" end
	return nil
end

local gearSlots = {}
for index = 1, #GearCheck.Data.slots do
	local widget = CreateFrame("Button", nil, detailContent)
	widget:SetWidth(GEAR_COL - 6)
	widget:SetHeight(GEAR_ROW - 2)
	widget:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	local highlight = widget:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
		highlight:SetAlpha(0.5)
	end
	widget.tint = widget:CreateTexture(nil, "BACKGROUND")
	widget.tint:SetAllPoints(widget)
	widget.tint:SetTexture(FLAT)
	widget.slot = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	widget.slot:SetPoint("LEFT", widget, "LEFT", 2, 0)
	widget.slot:SetWidth(72)
	widget.slot:SetJustifyH("RIGHT")
	widget.icon = widget:CreateTexture(nil, "ARTWORK")
	widget.icon:SetWidth(26)
	widget.icon:SetHeight(26)
	widget.icon:SetPoint("LEFT", widget, "LEFT", 80, 0)
	widget.border = widget:CreateTexture(nil, "OVERLAY")
	widget.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	widget.border:SetBlendMode("ADD")
	widget.border:SetWidth(48)
	widget.border:SetHeight(48)
	widget.border:SetPoint("CENTER", widget.icon, "CENTER", 0, 0)
	widget.level = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	widget.level:SetPoint("TOPLEFT", widget.icon, "TOPRIGHT", 5, 0)
	widget.level:SetWidth(28)
	widget.level:SetJustifyH("LEFT")
	widget.role = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	widget.role:SetPoint("LEFT", widget.level, "RIGHT", 2, 0)
	widget.role:SetPoint("RIGHT", widget, "RIGHT", -2, 0)
	widget.role:SetJustifyH("LEFT")
	widget.marks = {}
	for mark = 1, 5 do
		local texture = widget:CreateTexture(nil, "OVERLAY")
		texture:SetWidth(12)
		texture:SetHeight(12)
		if mark == 1 then
			texture:SetPoint("BOTTOMLEFT", widget.icon, "BOTTOMRIGHT", 5, 0)
		else
			texture:SetPoint("LEFT", widget.marks[mark - 1], "RIGHT", 2, 0)
		end
		texture:Hide()
		widget.marks[mark] = texture
	end
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
			if self.enchantText then
				GameTooltip:AddLine(self.enchantText, self.enchantR, self.enchantG, self.enchantB)
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

-- Abschnitte unter der Ausrüstung: Überschrift, Linie, Text.
local sections = {}
for index = 1, SECTION_POOL do
	local block = {}
	block.title = detailContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	block.title:SetJustifyH("LEFT")
	block.rule = detailContent:CreateTexture(nil, "ARTWORK")
	block.rule:SetTexture(FLAT)
	block.rule:SetVertexColor(0.55, 0.45, 0.2, 0.85)
	block.rule:SetHeight(1)
	block.body = detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	block.body:SetJustifyH("LEFT")
	block.body:SetJustifyV("TOP")
	block.title:Hide()
	block.rule:Hide()
	block.body:Hide()
	sections[index] = block
end

-- Liste -------------------------------------------------------------------

local rows = {}
for index = 1, MAX_ROWS do
	local row = CreateFrame("Button", nil, listContent)
	row:SetHeight(ROW_HEIGHT)
	row:SetWidth(ROW_WIDTH)
	if index == 1 then
		row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, 0)
	else
		row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, 0)
	end
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.stripe = row:CreateTexture(nil, "BACKGROUND")
	row.stripe:SetAllPoints(row)
	row.stripe:SetTexture(FLAT)
	if index % 2 == 0 then
		row.stripe:SetVertexColor(1, 1, 1, 0.05)
	else
		row.stripe:SetVertexColor(0, 0, 0, 0)
	end
	row.selected = row:CreateTexture(nil, "BORDER")
	row.selected:SetAllPoints(row)
	row.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.selected:SetBlendMode("ADD")
	row.selected:Hide()
	row.state = row:CreateTexture(nil, "ARTWORK")
	row.state:SetWidth(16)
	row.state:SetHeight(16)
	row.state:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.class = row:CreateTexture(nil, "ARTWORK")
	row.class:SetTexture(CLASS_ICONS)
	row.class:SetWidth(16)
	row.class:SetHeight(16)
	row.class:SetPoint("LEFT", row.state, "RIGHT", 3, 0)
	row.role = row:CreateTexture(nil, "ARTWORK")
	row.role:SetTexture(ROLE_ICONS)
	row.role:SetWidth(16)
	row.role:SetHeight(16)
	row.role:SetPoint("LEFT", row.class, "RIGHT", 3, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.name:SetPoint("LEFT", row.role, "RIGHT", 5, 0)
	row.name:SetWidth(110)
	row.name:SetJustifyH("LEFT")
	row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.info:SetPoint("LEFT", row.name, "RIGHT", 2, 0)
	row.info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.info:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		UI.selectedKey = self.key
		UI:Refresh()
	end)
	row:Hide()
	rows[index] = row
end

-- Schaltflächen ----------------------------------------------------------

local function button(text, width)
	local widget = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	widget:SetWidth(width)
	widget:SetHeight(24)
	widget:SetText(text)
	return widget
end

local function findRecord(key)
	local results = GearCheck.results or {}
	for index = 1, #results do
		if results[index].key == key then
			return results[index]
		end
	end
	return nil
end

local targetButton = button(GearCheck:T("BUTTON_TARGET"), 150)
targetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)
targetButton:SetScript("OnClick", function()
	GearCheck.Scan:ScanTarget()
end)

local groupButton = button(GearCheck:T("BUTTON_GROUP"), 150)
groupButton:SetPoint("LEFT", targetButton, "RIGHT", 8, 0)
groupButton:SetScript("OnClick", function()
	GearCheck.Scan:ScanGroup()
end)

local whisperAllButton = button(GearCheck:T("BUTTON_WHISPER_ALL"), 240)
whisperAllButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 14)
whisperAllButton:SetScript("OnClick", function()
	GearCheck.Whisper:Confirm()
end)
UI.whisperAllButton = whisperAllButton

local whisperOneButton = button(GearCheck:T("BUTTON_WHISPER_ONE"), 160)
whisperOneButton:SetPoint("RIGHT", whisperAllButton, "LEFT", -8, 0)
whisperOneButton:SetScript("OnClick", function()
	local record = findRecord(UI.selectedKey)
	if record then
		GearCheck.Whisper:ConfirmOne(record)
	end
end)
UI.whisperOneButton = whisperOneButton

frame:SetScript("OnDragStart", function(self)
	self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	UI:SavePosition()
end)
frame:SetScript("OnShow", function()
	onlyProblemsBox:SetChecked(option("onlyProblems", false))
	sortIssuesBox:SetChecked(option("sortIssues", true))
	UI:Refresh()
end)

-- Texte -------------------------------------------------------------------

local function isWaiting(record)
	return record.status == "pending" or record.status == "scanning"
end

local function rowInfo(record)
	if isWaiting(record) then
		return GearCheck:T("SCANNING_SHORT"), MUTED
	end
	if record.status ~= "done" then
		return record.statusText or GearCheck:T("NOT_INSPECTABLE"), MUTED
	end
	local loot, hints = GearCheck:CountIssues(record)
	local text
	if loot > 0 then
		text = colorCode(RED) .. GearCheck:T("LOOT_NO_SHORT", loot) .. "|r"
	else
		text = colorCode(GREEN) .. GearCheck:T("LOOT_OK_SHORT") .. "|r"
	end
	if hints > 0 then
		text = text .. " " .. colorCode(YELLOW) .. "+" .. hints .. "|r"
	end
	return text
end

local function stateIcon(texture, record)
	texture:SetVertexColor(1, 1, 1)
	texture:SetDesaturated(false)
	if isWaiting(record) then
		texture:SetTexture(ICON_WAITING)
	elseif record.status ~= "done" then
		texture:SetTexture(ICON_NOT_READY)
		texture:SetDesaturated(true)
		texture:SetVertexColor(0.6, 0.6, 0.6)
	elseif GearCheck:CountIssues(record) > 0 then
		texture:SetTexture(ICON_NOT_READY)
	else
		texture:SetTexture(ICON_READY)
	end
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

-- Kopf der Details: Klasse, Stufe, Gegenstandsstufe, GearScore, Skillung.
local function headerLines(record)
	local lines = {}
	local name = record.name or "?"
	local color = record.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.class]
	local line = record.className or record.class or ""
	if color then
		name = string.format("|cff%02x%02x%02x%s|r", channelByte(color.r), channelByte(color.g), channelByte(color.b), name)
	end
	if line ~= "" then
		line = name .. "  " .. line
	else
		line = name
	end
	if record.level and record.level > 0 then
		line = line .. "  " .. GearCheck:T("LEVEL", record.level)
	end
	local average = averageLevel(record.gear)
	if average then
		line = line .. "  " .. GearCheck:T("AVG_ILVL", average)
	end
	local gearScore = GearCheck:GearScoreFor(record)
	if gearScore then
		line = line .. "  " .. gearScoreText(gearScore)
	end
	lines[#lines + 1] = line
	local active = (record.roleLabel or GearCheck:T("ROLE_UNKNOWN")) .. "  " .. (record.trees or "")
	if record.secondary then
		local second = record.secondary
		lines[#lines + 1] = GearCheck:T("ACTIVE_SPEC") .. "  " .. active
		lines[#lines + 1] = GearCheck:T("SECOND_SPEC") .. "  " .. (second.label or GearCheck:T("ROLE_UNKNOWN")) .. "  " .. (second.trees or "")
	else
		lines[#lines + 1] = active
	end
	return lines
end

local function defenseLine(record)
	local defense = record.defense and record.defense.summary
	if not defense then return nil end
	if record.defense.immune == true then
		return colorCode(GREEN) .. defense .. "|r"
	elseif record.defense.immune == false then
		return colorCode(RED) .. defense .. "|r"
	end
	return colorCode(YELLOW) .. defense .. "|r"
end

local function metaLine(record)
	local meta = record.meta and record.meta.summary
	if not meta then return nil end
	if record.meta.active then
		return inlineIcon(ICON_READY) .. colorCode(GREEN) .. meta .. "|r"
	end
	return inlineIcon(ICON_NOT_READY) .. colorCode(RED) .. meta .. "|r"
end

-- Vollständiger Kopftext; das Seitenfenster am Betrachten-Fenster nutzt ihn auch.
function UI:SummaryText(record)
	if not record then
		return GearCheck:T("PROMPT")
	end
	if isWaiting(record) then
		return (record.name or "?") .. "\n" .. GearCheck:T("SCANNING_DETAIL")
	end
	if record.status ~= "done" then
		return (record.name or "?") .. "\n" .. (record.statusText or GearCheck:T("NOT_INSPECTABLE_DETAIL"))
	end
	local lines = headerLines(record)
	local defense = defenseLine(record)
	if defense then
		lines[#lines + 1] = defense
	end
	local meta = record.meta and record.meta.summary
	if meta then
		lines[#lines + 1] = (record.meta.active and colorCode(GREEN) or colorCode(RED)) .. meta .. "|r"
	end
	if record.note then
		lines[#lines + 1] = colorCode(YELLOW) .. record.note .. "|r"
	end
	return table.concat(lines, "\n")
end

local function issueLines(record, wantLoot, skipMeta)
	local lines = {}
	local issues = record.issues or {}
	local inactiveText = GearCheck:T("META_INACTIVE")
	for index = 1, #issues do
		local issue = issues[index]
		local skip = skipMeta and issue.text == inactiveText
		if not skip and (issue.loot and true or false) == wantLoot then
			local icon = wantLoot and ICON_NOT_READY or ICON_ALERT
			local color = wantLoot and RED or YELLOW
			lines[#lines + 1] = inlineIcon(icon) .. colorCode(color) .. issue.slot .. ":|r " .. issue.text
		end
	end
	return lines
end

-- Befundtext als ein Block (Seitenfenster am Betrachten-Fenster).
-- showMeta: Meta-Status oben melden; dann entfällt der doppelte Befund „Meta inaktiv“.
function UI:IssuesText(record, showMeta)
	if not record or record.status ~= "done" then
		return ""
	end
	local lines = {}
	local skipMeta = showMeta and record.meta and not record.meta.active
	if showMeta then
		local meta = metaLine(record)
		if meta then lines[#lines + 1] = meta end
	end
	local loot = issueLines(record, true, skipMeta)
	if #loot == 0 then
		lines[#lines + 1] = inlineIcon(ICON_READY) .. colorCode(GREEN) .. GearCheck:T("LOOT_OK") .. "|r"
	else
		lines[#lines + 1] = colorCode(RED) .. GearCheck:T("SECTION_LOOT") .. "|r"
		for index = 1, #loot do lines[#lines + 1] = loot[index] end
	end
	local hints = issueLines(record, false, skipMeta)
	if #hints > 0 then
		lines[#lines + 1] = colorCode(YELLOW) .. GearCheck:T("SECTION_HINTS") .. "|r"
		for index = 1, #hints do lines[#lines + 1] = hints[index] end
	end
	return table.concat(lines, "\n")
end

-- Abschnitte im Hauptfenster.
local function buildSections(record)
	local list = {}
	if not record or record.status ~= "done" then return list end
	local skipMeta = record.meta and not record.meta.active
	local loot = issueLines(record, true, skipMeta)
	if #loot == 0 then
		loot[1] = inlineIcon(ICON_READY) .. colorCode(GREEN) .. GearCheck:T("LOOT_OK") .. "|r"
	end
	list[#list + 1] = { title = GearCheck:T("SECTION_LOOT_TITLE"), lines = loot }
	local hints = issueLines(record, false, skipMeta)
	if #hints > 0 then
		list[#list + 1] = { title = GearCheck:T("SECTION_HINTS_TITLE"), lines = hints }
	end
	local meta = metaLine(record)
	if meta then
		list[#list + 1] = { title = GearCheck:T("SECTION_META"), lines = { meta } }
	end
	local defense = defenseLine(record)
	if defense then
		list[#list + 1] = { title = GearCheck:T("DEFENSE"), lines = { defense } }
	end
	if record.note then
		list[#list + 1] = { title = GearCheck:T("SECTION_NOTE"), lines = { colorCode(YELLOW) .. record.note .. "|r" } }
	end
	return list
end

local function placeSections(list, top, width)
	local y = top
	for index = 1, SECTION_POOL do
		local block = sections[index]
		local data = list[index]
		if data then
			block.title:ClearAllPoints()
			block.title:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 4, -y)
			block.title:SetWidth(width)
			block.title:SetText(data.title)
			setColor(block.title, GOLD)
			block.title:Show()
			y = y + (block.title:GetStringHeight() or 12) + 3
			block.rule:ClearAllPoints()
			block.rule:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 4, -y)
			block.rule:SetWidth(width)
			block.rule:Show()
			y = y + 5
			block.body:ClearAllPoints()
			block.body:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 8, -y)
			block.body:SetWidth(width - 4)
			block.body:SetText(table.concat(data.lines, "\n"))
			block.body:Show()
			y = y + (block.body:GetStringHeight() or 12) + 12
		else
			block.title:Hide()
			block.rule:Hide()
			block.body:Hide()
		end
	end
	return y - top
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

-- Pro Slot: gibt es Loot-Befunde, Hinweise, und welcher Art.
function UI.SlotFindings(record)
	local bySlot = {}
	local issues = record and record.issues
	if not issues then return bySlot end
	for index = 1, #issues do
		local issue = issues[index]
		local entry = bySlot[issue.slot]
		if not entry then
			entry = { kinds = {} }
			bySlot[issue.slot] = entry
		end
		if issue.loot then
			entry.loot = true
		else
			entry.hint = true
		end
		if issue.kind then
			entry.kinds[issue.kind] = true
		end
	end
	return bySlot
end

-- Kleine Icons am Slot: Verzauberung, dann Edelsteine, dann leere Sockel.
-- Das Seitenfenster am Betrachten-Fenster nutzt dieselbe Liste.
function UI.SlotMarks(entry, kinds)
	local marks = {}
	local enchant
	local state = enchantState(entry, kinds or {})
	if state == "ok" then
		enchant = { text = GearCheck:T("ENCHANT_STATE_OK"), color = GREEN }
		marks[#marks + 1] = { texture = ICON_ENCHANT, color = { 1, 1, 1 }, crop = true }
	elseif state == "small" then
		enchant = { text = GearCheck:T("ENCHANT_SMALL"), color = YELLOW }
		marks[#marks + 1] = { texture = ICON_ENCHANT, color = YELLOW, crop = true }
	elseif state == "missing" then
		enchant = { text = GearCheck:T("ENCHANT_MISSING"), color = RED }
		marks[#marks + 1] = { texture = ICON_ENCHANT, color = RED, crop = true }
	end
	local gems = entry.gems or {}
	for index = 1, #gems do
		marks[#marks + 1] = { texture = gemIcon(gems[index]), crop = true }
	end
	for _ = 1, entry.emptyMeta or 0 do
		marks[#marks + 1] = { texture = SOCKET_META }
	end
	for _ = 1, entry.emptyNormal or 0 do
		marks[#marks + 1] = { texture = SOCKET_EMPTY }
	end
	return marks, enchant
end

function UI.PaintMark(texture, mark)
	texture:SetTexture(mark.texture)
	if mark.crop then
		texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	else
		texture:SetTexCoord(0, 1, 0, 1)
	end
	local color = mark.color or { 1, 1, 1 }
	texture:SetVertexColor(color[1], color[2], color[3])
	texture:Show()
end

local function paintMarks(widget, entry, kinds)
	local marks, enchant = UI.SlotMarks(entry, kinds)
	for index = 1, #widget.marks do
		if marks[index] then
			UI.PaintMark(widget.marks[index], marks[index])
		else
			widget.marks[index]:Hide()
		end
	end
	if enchant then
		widget.enchantText = enchant.text
		widget.enchantR, widget.enchantG, widget.enchantB = enchant.color[1], enchant.color[2], enchant.color[3]
	else
		widget.enchantText = nil
	end
end

local function placeGear(record, top)
	local gear = record and record.status == "done" and record.gear
	if not gear then
		for index = 1, #gearSlots do
			gearSlots[index]:Hide()
		end
		return 0
	end
	local findings = UI.SlotFindings(record)
	local playerRole = record.role
	local rowsUsed = 0
	for index = 1, #gearSlots do
		local widget = gearSlots[index]
		local entry = gear[index]
		local column = index <= GEAR_LEFT and 0 or 1
		local row = index <= GEAR_LEFT and (index - 1) or (index - GEAR_LEFT - 1)
		if row + 1 > rowsUsed then rowsUsed = row + 1 end
		widget:ClearAllPoints()
		widget:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 2 + column * GEAR_COL, -(top + row * GEAR_ROW))
		if not entry then
			widget.link = nil
			widget:Hide()
		else
			local found = findings[entry.name]
			widget.link = entry.link
			widget.slotName = entry.name
			widget.itemName = entry.itemName
			widget.slot:SetText(entry.name or "")
			if found and found.loot then
				widget.tint:SetVertexColor(1, 0.1, 0.1, 0.2)
				setColor(widget.slot, RED)
			elseif found and found.hint then
				widget.tint:SetVertexColor(1, 0.8, 0, 0.12)
				setColor(widget.slot, YELLOW)
			else
				widget.tint:SetVertexColor(1, 1, 1, 0.03)
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

			local quality = entry.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality]
			if entry.link and quality and entry.quality >= 2 then
				widget.border:SetVertexColor(quality.r, quality.g, quality.b)
				widget.border:Show()
			else
				widget.border:Hide()
			end

			if entry.level then
				widget.level:SetText(entry.level)
				if quality then
					widget.level:SetTextColor(quality.r, quality.g, quality.b)
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
				widget.role:SetText(entry.empty and "" or "-")
				widget.role:SetTextColor(0.55, 0.55, 0.55)
				widget.roleLabel = nil
			end

			if entry.link then
				paintMarks(widget, entry, found and found.kinds or {})
			else
				widget.enchantText = nil
				for mark = 1, #widget.marks do
					widget.marks[mark]:Hide()
				end
			end
			widget:Show()
		end
	end
	return rowsUsed * GEAR_ROW
end

-- Reihenfolge und Filter der Liste --------------------------------------

local function rank(record)
	if record.status == "done" then
		if GearCheck:CountIssues(record) > 0 then return 1 end
		local _, hints = GearCheck:CountIssues(record)
		if hints > 0 then return 4 end
		return 5
	end
	if isWaiting(record) then return 3 end
	return 2
end

local function buildView(results)
	local view = {}
	local onlyProblems = option("onlyProblems", false)
	for index = 1, #results do
		local record = results[index]
		local r = rank(record)
		if not onlyProblems or r <= 2 then
			view[#view + 1] = { record = record, rank = r, order = index }
		end
	end
	if option("sortIssues", true) then
		table.sort(view, function(a, b)
			if a.rank ~= b.rank then return a.rank < b.rank end
			local la = GearCheck:CountIssues(a.record)
			local lb = GearCheck:CountIssues(b.record)
			if la ~= lb then return la > lb end
			return a.order < b.order
		end)
	end
	return view
end

local function updateOverview(results)
	local total = #results
	local ok, issues, blocked, waiting = 0, 0, 0, 0
	for index = 1, total do
		local record = results[index]
		local r = rank(record)
		if r == 1 then
			issues = issues + 1
		elseif r == 2 then
			blocked = blocked + 1
		elseif r == 3 then
			waiting = waiting + 1
		else
			ok = ok + 1
		end
	end
	if total == 0 then
		overview:SetText(GearCheck:T("PROMPT"))
		progress:SetMinMaxValues(0, 1)
		progress:SetValue(0)
		return
	end
	local parts = {
		colorCode(ok == total and GREEN or GOLD) .. GearCheck:T("OVERVIEW_OK", ok, total) .. "|r",
	}
	if issues > 0 then
		parts[#parts + 1] = colorCode(RED) .. GearCheck:T("OVERVIEW_ISSUES", issues) .. "|r"
	end
	if blocked > 0 then
		parts[#parts + 1] = colorCode(MUTED) .. GearCheck:T("OVERVIEW_BLOCKED", blocked) .. "|r"
	end
	if waiting > 0 then
		parts[#parts + 1] = colorCode(MUTED) .. GearCheck:T("OVERVIEW_WAITING", waiting) .. "|r"
	end
	overview:SetText(table.concat(parts, "  |cff808080·|r  "))
	progress:SetMinMaxValues(0, total)
	progress:SetValue(total - waiting)
	if waiting > 0 then
		progress:SetStatusBarColor(GOLD[1], GOLD[2], GOLD[3])
	elseif issues > 0 then
		progress:SetStatusBarColor(0.75, 0.2, 0.2)
	else
		progress:SetStatusBarColor(0.15, 0.7, 0.15)
	end
end

-- Position ----------------------------------------------------------------

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

-- Neu zeichnen ------------------------------------------------------------

function UI:Refresh()
	-- Geschlossen gibt es nichts zu zeichnen; OnShow holt das nach.
	if not self.frame:IsShown() then return end
	local results = GearCheck.results or {}
	local view = buildView(results)

	local function inView(key)
		for index = 1, #view do
			if view[index].record.key == key then return true end
		end
		return false
	end

	if self.seenScan ~= GearCheck.scanId then
		self.seenScan = GearCheck.scanId
		self.selectedKey = view[1] and view[1].record.key or nil
		listScroll:SetVerticalScroll(0)
	elseif not self.selectedKey or not inView(self.selectedKey) then
		self.selectedKey = view[1] and view[1].record.key or nil
	end

	updateOverview(results)
	status:SetText(GearCheck.Scan and GearCheck.Scan.status or GearCheck:T("READY"))

	local shown = math.min(#view, MAX_ROWS)
	for index = 1, MAX_ROWS do
		local row = rows[index]
		local item = view[index]
		if item and index <= shown then
			local record = item.record
			row.key = record.key
			row.name:SetText(record.name or "?")
			local color = record.class and RAID_CLASS_COLORS[record.class]
			if color then
				row.name:SetTextColor(color.r, color.g, color.b)
			else
				row.name:SetTextColor(1, 1, 1)
			end
			stateIcon(row.state, record)
			setClassIcon(row.class, record.class)
			setRoleIcon(row.role, record.status == "done" and record.role or nil)
			local text, textColor = rowInfo(record)
			row.info:SetText(text)
			if textColor then
				setColor(row.info, textColor)
			else
				row.info:SetTextColor(1, 1, 1)
			end
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
	if shown == 0 and #results > 0 then
		listEmpty:SetText(GearCheck:T("FILTER_EMPTY"))
		listEmpty:Show()
	else
		listEmpty:Hide()
	end

	local record = self.selectedKey and findRecord(self.selectedKey)
	if record and record.status == "done" and GearCheck.Classify.Complete then
		GearCheck.Classify.Complete(record)
	end
	local scrollPos = detailScroll:GetVerticalScroll() or 0
	if self.detailKey ~= self.selectedKey then
		self.detailKey = self.selectedKey
		scrollPos = 0
	end
	local textWidth = GEAR_COL * 2 - 12
	summary:SetWidth(textWidth)
	local summaryString
	if record and record.status == "done" then
		summaryString = table.concat(headerLines(record), "\n")
	else
		summaryString = self:SummaryText(record)
	end
	summary:SetText(summaryString)
	local summaryHeight = summary:GetStringHeight() or 0
	if summaryString ~= "" and summaryHeight < 1 then
		local lines = 1
		for _ in string.gmatch(summaryString, "\n") do
			lines = lines + 1
		end
		summaryHeight = lines * 12
	end
	local gearTop = 4 + summaryHeight + (summaryHeight > 0 and 10 or 0)
	local gearHeight = placeGear(record, gearTop)
	local sectionTop = gearTop + gearHeight + (gearHeight > 0 and 10 or 0)
	local sectionHeight = placeSections(buildSections(record), sectionTop, textWidth)
	detailContent:SetHeight(math.max(sectionTop + sectionHeight + 8, 1))
	detailScroll:UpdateScrollChildRect()
	local range = detailScroll:GetVerticalScrollRange() or 0
	if scrollPos > range then
		scrollPos = range
	end
	detailScroll:SetVerticalScroll(scrollPos)

	local whisper = GearCheck.Whisper
	local busy = whisper and whisper:IsBusy()
	if busy then
		whisperOneButton:Disable()
		whisperOneButton:SetText(GearCheck:T("WHISPERING"))
		whisperAllButton:Disable()
		whisperAllButton:SetText(GearCheck:T("WHISPERING"))
	else
		if whisper and whisper:CanSend(record) then
			whisperOneButton:Enable()
		else
			whisperOneButton:Disable()
		end
		whisperOneButton:SetText(GearCheck:T("BUTTON_WHISPER_ONE"))

		local count = whisper and whisper:Count() or 0
		if count > 0 then
			whisperAllButton:Enable()
			whisperAllButton:SetText(GearCheck:T("BUTTON_WHISPER_ALL_COUNT", count))
		else
			whisperAllButton:Disable()
			whisperAllButton:SetText(GearCheck:T("BUTTON_WHISPER_ALL"))
		end
	end
end

if GearCheckDB and GearCheckDB.point then
	UI:RestorePosition()
end
