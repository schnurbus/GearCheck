local _, GearCheck = ...

local Classify = {}
GearCheck.Classify = Classify

local Data = GearCheck.Data

local scanTip
local needles
local enchantStats
local relicCache
local classificationStats

local function tooltipFrame()
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "GearCheckScanTooltip", UIParent, "GameTooltipTemplate")
		scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	return scanTip
end

local function readTooltipLines()
	local lines = {}
	local tip = tooltipFrame()
	for index = 1, tip:NumLines() do
		local left = _G["GearCheckScanTooltipTextLeft" .. index]
		if left then
			local text = left:GetText()
			if text and text ~= "" then
				local r, g, b = left:GetTextColor()
				lines[#lines + 1] = { text = text, r = r or 1, g = g or 1, b = b or 1 }
			end
		end
	end
	tip:Hide()
	return lines
end

function Classify.Lines(link)
	if not link then return {} end
	local tip = tooltipFrame()
	tip:ClearLines()
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok = pcall(tip.SetHyperlink, tip, link)
	if not ok then
		tip:Hide()
		return {}
	end
	return readTooltipLines()
end

function Classify.InventoryLines(unit, slotId)
	if not unit or not slotId then return {} end
	local tip = tooltipFrame()
	tip:ClearLines()
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok = pcall(tip.SetInventoryItem, tip, unit, slotId)
	if not ok then
		tip:Hide()
		return {}
	end
	return readTooltipLines()
end

function Classify.ParseLink(link)
	if not link then return nil end
	local id, enchant, gem1, gem2, gem3, gem4 = string.match(link, "item:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)")
	if not id then return nil end
	return {
		id = tonumber(id),
		enchant = tonumber(enchant) or 0,
		gems = {
			tonumber(gem1) or 0,
			tonumber(gem2) or 0,
			tonumber(gem3) or 0,
			tonumber(gem4) or 0,
		},
	}
end

local function gemIdAt(link, parsed, gemIndex)
	local gemId = parsed and parsed.gems and parsed.gems[gemIndex] or 0
	if link and GetItemGem then
		local _, gemLink = GetItemGem(link, gemIndex)
		if gemLink then
			local fromLink = tonumber(string.match(gemLink, "item:(%d+)"))
			if fromLink and fromLink > 0 then
				return fromLink
			end
		end
	end
	return gemId
end

function Classify.GemCount(parsed, link)
	if not parsed then return 0 end
	local count = 0
	for index = 1, 4 do
		if gemIdAt(link, parsed, index) > 0 then
			count = count + 1
		end
	end
	return count
end

local function socketKind(text)
	if EMPTY_SOCKET_META and string.find(text, EMPTY_SOCKET_META, 1, true) then
		return "meta"
	end
	if EMPTY_SOCKET_RED and string.find(text, EMPTY_SOCKET_RED, 1, true) then
		return "normal"
	end
	if EMPTY_SOCKET_YELLOW and string.find(text, EMPTY_SOCKET_YELLOW, 1, true) then
		return "normal"
	end
	if EMPTY_SOCKET_BLUE and string.find(text, EMPTY_SOCKET_BLUE, 1, true) then
		return "normal"
	end
	if EMPTY_SOCKET_NO_COLOR and string.find(text, EMPTY_SOCKET_NO_COLOR, 1, true) then
		return "normal"
	end
	return nil
end

local function rawStat(raw, global)
	if not global then return 0 end
	local value = raw[global]
	if value == nil and _G[global] then
		value = raw[_G[global]]
	end
	if type(value) ~= "number" or value < 0 then return 0 end
	return value
end

-- GetItemStats zählt die Sockel des Gegenstands, auch wenn ein Edelstein drin sitzt.
local function apiSocketCounts(link)
	local raw = {}
	if link then
		pcall(GetItemStats, link, raw)
	end
	local meta = rawStat(raw, "EMPTY_SOCKET_META")
	local normal = rawStat(raw, "EMPTY_SOCKET_RED")
		+ rawStat(raw, "EMPTY_SOCKET_YELLOW")
		+ rawStat(raw, "EMPTY_SOCKET_BLUE")
		+ rawStat(raw, "EMPTY_SOCKET_NO_COLOR")
	return { meta = meta, normal = normal, total = meta + normal }
end

function Classify.SocketInfo(link)
	local tipped = { meta = 0, normal = 0, total = 0 }
	local lines = Classify.Lines(link)
	for index = 1, #lines do
		local kind = socketKind(lines[index].text)
		if kind == "meta" then
			tipped.meta = tipped.meta + 1
		elseif kind == "normal" then
			tipped.normal = tipped.normal + 1
		end
	end
	tipped.total = tipped.meta + tipped.normal

	local api = apiSocketCounts(link)
	local parsed = Classify.ParseLink(link)
	local filled, metaFilled = 0, 0
	if parsed then
		for gemIndex = 1, 4 do
			local gemId = gemIdAt(link, parsed, gemIndex)
			if gemId > 0 then
				filled = filled + 1
				if Data.metaGems[gemId] then
					metaFilled = metaFilled + 1
				end
			end
		end
	end

	local info = { meta = 0, normal = 0, total = 0 }
	if api.total > 0 then
		local emptyTotal = api.total - filled
		if emptyTotal < 0 then emptyTotal = 0 end
		local emptyMeta = api.meta - metaFilled
		if emptyMeta < 0 then emptyMeta = 0 end
		-- Tooltip zeigt nur leere Sockel. Zeigt er mehr leere als übrig sind,
		-- wurden gefasste Edelsteine nicht gezeichnet.
		if tipped.total > 0 and tipped.total <= emptyTotal then
			emptyMeta = tipped.meta
			emptyTotal = tipped.total
		elseif filled > 0 and tipped.meta == 0 then
			emptyMeta = 0
		end
		if emptyMeta > emptyTotal then emptyMeta = emptyTotal end
		info.meta = emptyMeta
		info.normal = emptyTotal - emptyMeta
		info.total = emptyTotal
	else
		info.meta = tipped.meta
		info.normal = tipped.normal
		info.total = tipped.total
		if filled > 0 and info.total > 0 and filled >= info.total then
			info.meta, info.normal, info.total = 0, 0, 0
		elseif filled > 0 and info.total > filled then
			local drop = filled
			if info.meta > 0 and metaFilled > 0 then
				local used = math.min(info.meta, metaFilled, drop)
				info.meta = info.meta - used
				drop = drop - used
			end
			info.normal = math.max(0, info.normal - drop)
			info.total = info.meta + info.normal
		end
	end

	if #lines == 0 and api.total == 0 then return nil end
	return info
end

local function statNeedles()
	if needles then return needles end
	needles = {}
	for index = 1, #Data.statGlobals do
		local entry = Data.statGlobals[index]
		local text = _G[entry.global]
		if text and text ~= "" then
			text = string.gsub(text, "%%%.?%d*[dfs]", " ")
			text = string.gsub(text, "^%s+", "")
			text = string.gsub(text, "%s+$", "")
			text = string.gsub(text, "^%+", "")
			text = string.lower(text)
			if #text >= 4 then
				needles[#needles + 1] = { key = entry.key, needle = text }
			end
		end
	end
	table.sort(needles, function(a, b)
		return #a.needle > #b.needle
	end)
	return needles
end

local function amountNear(text, startPos, stopPos)
	local prefix = string.sub(text, math.max(1, startPos - 8), math.max(0, startPos - 1))
	local before = tonumber(string.match(prefix, "(%d+)%s*$"))
	if before then return before end
	-- „Verteidigungswertung um 63“ und „defense rating by 63“: Zahl steht dahinter.
	local suffix = string.sub(text, stopPos + 1, math.min(#text, stopPos + 16))
	return tonumber(string.match(suffix, "^%s*[+:%a]*%s*(%d+)"))
end

local function harvest(text, into, requireAmount, prefixOnly)
	if not text or text == "" then return end
	text = string.lower(text)
	local list = statNeedles()
	for index = 1, #list do
		local entry = list[index]
		local start, stop = string.find(text, entry.needle, 1, true)
		if start then
			local amount
			if prefixOnly then
				local prefix = string.sub(text, math.max(1, start - 8), math.max(0, start - 1))
				amount = tonumber(string.match(prefix, "(%d+)%s*$"))
			else
				amount = amountNear(text, start, stop)
			end
			if amount then
				into[entry.key] = (into[entry.key] or 0) + amount
			elseif not requireAmount then
				into[entry.key] = (into[entry.key] or 0) + 1
			end
			text = string.sub(text, 1, start - 1) .. string.sub(text, stop + 1)
		end
	end
end

local function hasStats(stats)
	for _, value in pairs(stats) do
		if value and value > 0 then
			return true
		end
	end
	return false
end

local function isTriggeredLine(text)
	if ITEM_SPELL_TRIGGER_ONEQUIP and string.find(text, ITEM_SPELL_TRIGGER_ONEQUIP, 1, true) then
		return true
	end
	if ITEM_SPELL_TRIGGER_ONUSE and string.find(text, ITEM_SPELL_TRIGGER_ONUSE, 1, true) then
		return true
	end
	return false
end

local function isGreenLine(line)
	return line.g > 0.85 and line.r < 0.25 and line.b < 0.25
end

-- Procs stehen auch hinter „Anlegen:“, tragen die Wertung aber nur zeitweise.
local function isProcLine(text)
	if not text then return false end
	local lower = string.lower(text)
	if string.find(lower, "chance", 1, true) then return true end
	if string.find(lower, "%d+%s*sek") or string.find(lower, "%d+%s*sec") then return true end
	return false
end

local function isEquipLine(text)
	return ITEM_SPELL_TRIGGER_ONEQUIP and text and string.find(text, ITEM_SPELL_TRIGGER_ONEQUIP, 1, true)
end

-- Dauerhafte Anlegen-Zeilen wie „Erhöht die Verteidigungswertung um 63“.
local function passiveEquipStats(link)
	local stats = {}
	local lines = Classify.Lines(link)
	for index = 1, #lines do
		local line = lines[index]
		if isGreenLine(line) and isEquipLine(line.text) and not isProcLine(line.text) then
			harvest(line.text, stats, true)
		end
	end
	return stats
end

local function addEquipStats(stats, equip)
	for key, amount in pairs(equip) do
		local current = stats[key] or 0
		if amount > current then
			stats[key] = current + amount
		end
	end
end

local function readApiStats(link)
	local raw = {}
	pcall(GetItemStats, link, raw)
	local stats = {}
	for index = 1, #Data.statGlobals do
		local entry = Data.statGlobals[index]
		local localized = _G[entry.global]
		local value = raw[entry.global]
		if value == nil and localized then
			value = raw[localized]
		end
		if type(value) == "number" and value > 0 then
			stats[entry.key] = (stats[entry.key] or 0) + value
		end
	end
	return stats
end

local function itemStats(link)
	local stats = readApiStats(link)
	local lines = Classify.Lines(link)
	if not hasStats(stats) then
		for index = 1, #lines do
			local line = lines[index]
			if isGreenLine(line) and not isProcLine(line.text) and not isEquipLine(line.text) then
				harvest(line.text, stats)
			end
		end
	else
		for index = 1, #lines do
			local text = lines[index].text
			if isTriggeredLine(text) and not isEquipLine(text) and not isProcLine(text) then
				harvest(text, stats, false, true)
			end
		end
	end
	addEquipStats(stats, passiveEquipStats(link))
	return stats
end

local function usesStrength(classToken, role)
	if role ~= "tank" and role ~= "damage" then return false end
	return classToken == "WARRIOR" or classToken == "PALADIN" or classToken == "DEATHKNIGHT"
end

local function usesAgility(classToken, role)
	if role ~= "tank" and role ~= "damage" then return false end
	if classToken == "HUNTER" or classToken == "ROGUE" then return true end
	if classToken == "DRUID" then return true end
	if classToken == "SHAMAN" and role == "damage" then return true end
	return false
end

local CHECK_ROLES = { "tank", "damage", "caster", "healer" }

local function scoreRole(stats, classToken, role, forEnchant)
	local function value(key)
		return stats[key] or 0
	end

	local good, bad = 0, 0
	local badRole, badAmount = nil, 0
	local function add(amount, ok, roleName)
		if not amount or amount <= 0 then return end
		if ok then
			good = good + amount
		else
			bad = bad + amount
			if amount > badAmount then
				badAmount = amount
				badRole = roleName
			end
		end
	end

	local dkTank = classToken == "DEATHKNIGHT" and role == "tank"
	local physical = role == "damage" or role == "tank"
	local spellUser = role == "caster" or role == "healer"
	-- Nur Verzauberungen: Beweglichkeit gibt Krit (bei Tanks auch Ausweichen), auch auf Platte.
	-- Paladin-Heiler dürfen Trefferwertung (Richturteil), auf Ausrüstung und Verzauberungen.
	local agiEnchant = forEnchant and (role == "tank" or role == "damage")
	local paladinHeal = role == "healer" and classToken == "PALADIN"

	add(value("stamina"), true)
	add(value("strength"), usesStrength(classToken, role), "damage")
	add(value("agility"), usesAgility(classToken, role) or agiEnchant, "damage")
	add(value("intellect"), spellUser, "caster")
	add(value("spirit"), spellUser, "healer")
	add(value("spellPower"), spellUser, "caster")
	add(value("spellDamage"), spellUser, "caster")
	add(value("healing"), spellUser, "healer")
	add(value("spellPen"), role == "caster", "caster")
	add(value("mp5"), spellUser, "healer")
	add(value("attackPower"), role == "damage" or (role == "tank" and (usesStrength(classToken, role) or usesAgility(classToken, role) or dkTank)), "damage")
	add(value("meleeAP"), role == "damage" or dkTank or (role == "tank" and (usesStrength(classToken, role) or usesAgility(classToken, role))), "damage")
	add(value("rangedAP"), role == "damage" and usesAgility(classToken, role), "damage")
	add(value("armorPen"), role == "damage" or dkTank, "damage")
	add(value("expertise"), physical, "damage")
	add(value("hit"), role ~= "healer" or paladinHeal, "caster")
	add(value("spellHit"), role == "caster" or paladinHeal, "caster")
	add(value("meleeHit"), physical or paladinHeal, "damage")
	add(value("rangedHit"), role == "damage", "damage")
	add(value("crit"), role ~= "tank" or dkTank, "damage")
	add(value("spellCrit"), spellUser, "caster")
	add(value("meleeCrit"), role == "damage" or dkTank, "damage")
	add(value("rangedCrit"), role == "damage", "damage")
	add(value("haste"), role ~= "tank" or dkTank, "damage")
	add(value("spellHaste"), spellUser, "caster")
	add(value("defense"), role == "tank", "tank")
	add(value("dodge"), role == "tank", "tank")
	add(value("parry"), role == "tank", "tank")
	add(value("block"), role == "tank", "tank")
	add(value("blockValue"), role == "tank", "tank")
	add(value("resilience"), false, "pvp")

	return good, bad, badRole
end

local function healerIsCaster(stats)
	local function value(key)
		return stats[key] or 0
	end
	local hit = value("hit") + value("spellHit") + value("meleeHit") + value("rangedHit")
	local physical = value("strength") + value("agility") + value("attackPower") + value("armorPen") + value("defense") + value("dodge") + value("parry") + value("block")
	return hit > 0 and value("spirit") == 0 and value("mp5") == 0 and physical == 0
end

local function isPvp(stats)
	return stats ~= nil and (stats.resilience or 0) > 0
end

local function itemPermitted(itemId, role)
	local allowed = itemId and Data.items[itemId]
	return allowed and (allowed.any or allowed[role]) or false
end

local function mismatch(stats, classToken, role, forEnchant, itemId)
	if itemPermitted(itemId, role) then return nil end
	if not stats or not hasStats(stats) then return nil end
	if isPvp(stats) then return "pvp" end
	local paladinHeal = role == "healer" and classToken == "PALADIN"
	if role == "healer" and not paladinHeal and healerIsCaster(stats) then
		return "caster"
	end
	local good, bad, badRole = scoreRole(stats, classToken, role, forEnchant)
	if bad > 0 and bad >= good then
		return badRole or "damage"
	end
	return nil
end

local function mismatchText(kind, reason, itemName)
	if reason == "pvp" then
		if kind == "gem" or kind == "meta" then return GearCheck:T("PVP_GEM") end
		if kind == "enchant" then return GearCheck:T("PVP_ENCHANT") end
		return GearCheck:T("PVP_GEAR")
	end
	local label = Data.RoleLabel(reason)
	if kind == "meta" then
		return GearCheck:T("META_MISMATCH", label)
	end
	if kind == "gem" then
		if itemName and itemName ~= "" then
			return GearCheck:T("GEM_MISMATCH_NAMED", itemName, label)
		end
		return GearCheck:T("GEM_MISMATCH", label)
	end
	if kind == "enchant" then
		return GearCheck:T("ENCHANT_MISMATCH", label)
	end
	return GearCheck:T("STATS_MISMATCH", label)
end

local function relicEntries()
	if relicCache and #relicCache > 0 then return relicCache end
	local built = {}
	for index = 1, #Data.relics do
		local entry = Data.relics[index]
		local name = GetSpellInfo(entry.id)
		if name and name ~= "" then
			built[#built + 1] = { name = string.lower(name), roles = entry.roles }
		end
	end
	table.sort(built, function(a, b)
		return #a.name > #b.name
	end)
	if #built > 0 then
		relicCache = built
	end
	return built
end

local function relicRoles(link)
	local lines = Classify.Lines(link)
	local equipText
	for index = #lines, 1, -1 do
		if ITEM_SPELL_TRIGGER_ONEQUIP and string.find(lines[index].text, ITEM_SPELL_TRIGGER_ONEQUIP, 1, true) then
			equipText = string.lower(lines[index].text)
			break
		end
	end
	if not equipText then return nil end
	local matched = {}
	local any = false
	local text = equipText
	local entries = relicEntries()
	for index = 1, #entries do
		local entry = entries[index]
		local start, stop = string.find(text, entry.name, 1, true)
		if start then
			any = true
			for key, allowed in pairs(entry.roles) do
				if allowed then
					matched[key] = true
				end
			end
			text = string.sub(text, 1, start - 1) .. " " .. string.sub(text, stop + 1)
		end
	end
	if not any then return nil end
	return matched
end

local function relicMismatch(link, role)
	if isPvp(itemStats(link)) then return "pvp" end
	local matched = relicRoles(link)
	if not matched or matched[role] then return nil end
	return Data.FirstRole(matched)
end

local function dominantRole(stats, classToken, playerRole, itemId)
	if not stats or not hasStats(stats) then return nil, nil end
	if isPvp(stats) then
		local fit
		if playerRole then fit = false end
		return "pvp", fit
	end

	local best, bestMargin
	local margins = {}
	for index = 1, #CHECK_ROLES do
		local role = CHECK_ROLES[index]
		local good, bad = scoreRole(stats, classToken, role)
		local margin = good - bad
		if role == "healer" and healerIsCaster(stats) then
			margin = math.min(margin, -1)
		end
		margins[role] = margin
		if not bestMargin or margin > bestMargin or (margin == bestMargin and role == playerRole) then
			best = role
			bestMargin = margin
		end
	end

	local same = true
	local first = margins[CHECK_ROLES[1]]
	for index = 2, #CHECK_ROLES do
		if margins[CHECK_ROLES[index]] ~= first then
			same = false
			break
		end
	end

	if same then
		if not playerRole then return nil, nil end
		local reason = mismatch(stats, classToken, playerRole, nil, itemId)
		if reason then return reason, false end
		return playerRole, true
	end

	if not bestMargin or bestMargin <= 0 then
		if playerRole then
			local reason = mismatch(stats, classToken, playerRole, nil, itemId)
			if reason then return reason, false end
		end
		return nil, nil
	end

	local fit
	if playerRole then
		fit = not mismatch(stats, classToken, playerRole, nil, itemId)
	end
	return best, fit
end

local function classifyLink(link, classToken, playerRole, equip, slotKey)
	if playerRole == "unknown" then playerRole = nil end
	if slotKey == "RangedSlot" or equip == "INVTYPE_RELIC" then
		local matched = relicRoles(link)
		if matched then
			if isPvp(itemStats(link)) then
				local fit
				if playerRole then fit = false end
				return "pvp", fit, true
			end
			if playerRole and matched[playerRole] then
				return playerRole, true, true
			end
			local fit
			if playerRole then fit = false end
			return Data.FirstRole(matched), fit, true
		end
	end
	local stats = classificationStats(link, classToken, playerRole)
	if hasStats(stats) then
		local itemId = tonumber(string.match(link, "item:(%d+)"))
		local role, fit = dominantRole(stats, classToken, playerRole, itemId)
		return role, fit, true
	end
	if #Classify.Lines(link) > 0 then
		return nil, nil, true
	end
	return nil, nil, false
end

local function playerRoleOf(role)
	if role == "unknown" then return nil end
	return role
end

function Classify.Gear(unit, context)
	local gear = {}
	if not unit then return gear end
	local classToken = context and context.class
	local playerRole = playerRoleOf(context and context.role)
	for index = 1, #Data.slots do
		local slot = Data.slots[index]
		local slotId = Data.SlotId(slot.key)
		local link = GetInventoryItemLink(unit, slotId)
		local entry = {
			key = slot.key,
			name = slot.name,
			link = link,
		}
		if link then
			local name, _, quality, itemLevel, _, _, _, _, equip, texture = GetItemInfo(link)
			entry.itemName = name
			entry.quality = quality
			entry.level = itemLevel
			entry.texture = texture or GetInventoryItemTexture(unit, slotId)
			local role, fit, decided = classifyLink(link, classToken, playerRole, equip, slot.key)
			entry.role = role
			entry.fit = fit
			entry.classified = decided or itemLevel ~= nil
		else
			entry.empty = true
			entry.classified = true
		end
		gear[#gear + 1] = entry
	end
	return gear
end

function Classify.Complete(record)
	local gear = record and record.gear
	if not gear then return end
	local now = GetTime()
	local playerRole = playerRoleOf(record.role)
	for index = 1, #gear do
		local entry = gear[index]
		if entry.link and not entry.level then
			local name, _, quality, itemLevel, _, _, _, _, _, texture = GetItemInfo(entry.link)
			if itemLevel then
				entry.itemName = entry.itemName or name
				entry.quality = entry.quality or quality
				entry.level = itemLevel
				entry.texture = entry.texture or texture
			end
		end
		if entry.link and not entry.classified and (not entry.retryAt or entry.retryAt <= now) then
			entry.retryAt = now + 1
			local _, _, quality, itemLevel, _, _, _, _, equip, texture = GetItemInfo(entry.link)
			if itemLevel then
				entry.quality = entry.quality or quality
				entry.level = entry.level or itemLevel
				entry.texture = entry.texture or texture
			end
			local role, fit, decided = classifyLink(entry.link, record.class, playerRole, equip, entry.key)
			if decided or itemLevel then
				entry.role = role
				entry.fit = fit
				entry.classified = true
			end
		end
	end
end

local function enchantTooltipStats(enchantId)
	if enchantStats and enchantStats[enchantId] ~= nil then
		return enchantStats[enchantId] or nil
	end
	enchantStats = enchantStats or {}
	local stats = {}
	local lines = Classify.Lines("item:6948:" .. enchantId)
	local text
	for index = 1, #lines do
		local line = lines[index]
		if line.g > 0.85 and line.r < 0.25 and line.b < 0.25 then
			text = line.text
			break
		end
		if ITEM_SPELL_TRIGGER_ONUSE and string.find(line.text, ITEM_SPELL_TRIGGER_ONUSE, 1, true) and lines[index + 1] then
			text = lines[index + 1].text
			break
		end
	end
	if text then
		harvest(text, stats)
	end
	if not hasStats(stats) then
		enchantStats[enchantId] = false
		return nil
	end
	enchantStats[enchantId] = stats
	return stats
end

local function linkWithoutEnchant(link)
	local stripped, count = string.gsub(link, "(|Hitem:%d+):%d*", "%1:0", 1)
	if count == 0 then
		stripped = string.gsub(link, "(item:%d+):%d*", "%1:0", 1)
	end
	return stripped
end

local function isSocketBonus(text)
	local pattern = ITEM_SOCKET_BONUS
	if not pattern or not text then return false end
	local prefix = string.match(pattern, "^(.-)%%s")
	if not prefix or prefix == "" then return false end
	return string.sub(text, 1, #prefix) == prefix
end

local function addSocketBonus(link, into)
	local lines = Classify.Lines(link)
	for index = 1, #lines do
		local line = lines[index]
		if line.g > 0.85 and line.r < 0.25 and line.b < 0.25 and isSocketBonus(line.text) then
			harvest(line.text, into)
		end
	end
end

-- Dauerhafte Werte: Grundwerte, Anlegen-Wertungen, Edelsteine, Sockelbonus. Procs zählen nicht.
local function passiveStats(link)
	local stats = readApiStats(link)
	if not hasStats(stats) then
		local lines = Classify.Lines(link)
		for index = 1, #lines do
			local line = lines[index]
			if isGreenLine(line) and not isTriggeredLine(line.text) and not isProcLine(line.text) and not isSocketBonus(line.text) then
				harvest(line.text, stats)
			end
		end
	end
	addEquipStats(stats, passiveEquipStats(link))
	addSocketBonus(link, stats)
	return stats
end

local function enchantAllowed(enchantId, classToken, role)
	local override = enchantId and Data.enchants[enchantId]
	if not override then return false end
	local excluded = override.exclude and classToken and override.exclude[classToken]
	if excluded and (excluded == true or (role and excluded[role])) then
		return false
	end
	return override.any or (role and override[role]) or false
end

local function enchantRatings(enchantId)
	local defense, resilience = 0, 0
	local tipped = enchantTooltipStats(enchantId)
	if tipped then
		defense = tipped.defense or 0
		resilience = tipped.resilience or 0
	end
	local override = Data.enchants[enchantId]
	if override then
		if (override.defense or 0) > defense then
			defense = override.defense
		end
		if (override.resilience or 0) > resilience then
			resilience = override.resilience
		end
	end
	return defense, resilience
end

-- Runen erhöhen die Verteidigung direkt. GetItemStats liefert dafür keine Wertung.
local function enchantDefenseSkill(enchantId)
	local override = enchantId and Data.enchants[enchantId]
	if not override then return 0 end
	return override.defenseSkill or 0
end

local function linkWithoutGems(link)
	local stripped, count = string.gsub(link, "(|Hitem:%d+:%d*):%d*:%d*:%d*:%d*", "%1:0:0:0:0", 1)
	if count == 0 then
		stripped = string.gsub(link, "(item:%d+:%d*):%d*:%d*:%d*:%d*", "%1:0:0:0:0", 1)
	end
	return stripped
end

-- Mehrwert-Edelsteine wie „+10 Verteidigungswertung und +15 Ausdauer“ stehen in einer Zeile.
-- GetItemStats am Gegenstand lässt die Verteidigung daraus weg.
local function tooltipStats(link)
	local stats = {}
	local lines = Classify.Lines(link)
	for index = 1, #lines do
		local line = lines[index]
		if not isSocketBonus(line.text) and not socketKind(line.text) then
			harvest(line.text, stats)
		end
	end
	return stats
end

local function gemStat(gemId, key)
	local link = "item:" .. gemId
	local api = readApiStats(link)
	local tipped = tooltipStats(link)
	return math.max(api[key] or 0, tipped[key] or 0)
end

-- Anteil, den GetItemStats am gefassten Gegenstand noch nicht enthält.
local function missingGemRatings(link, parsed)
	local defense, resilience = 0, 0
	if parsed then
		for gemIndex = 1, 4 do
			local gemId = gemIdAt(link, parsed, gemIndex)
			if gemId > 0 then
				defense = defense + gemStat(gemId, "defense")
				resilience = resilience + gemStat(gemId, "resilience")
			end
		end
	end
	local bare = linkWithoutEnchant(link)
	local withGems = readApiStats(bare)
	local withoutGems = readApiStats(linkWithoutGems(bare))
	local apiDefense = (withGems.defense or 0) - (withoutGems.defense or 0)
	local apiResilience = (withGems.resilience or 0) - (withoutGems.resilience or 0)
	if apiDefense < 0 then apiDefense = 0 end
	if apiResilience < 0 then apiResilience = 0 end
	local extraDefense = defense - apiDefense
	local extraResilience = resilience - apiResilience
	if extraDefense < 0 then extraDefense = 0 end
	if extraResilience < 0 then extraResilience = 0 end
	return extraDefense, extraResilience, defense
end

-- Differenz aus vollem Link und Link ohne Verzauberung. Fehlt sie, kommt der Wert aus dem Tooltip.
local function splitEnchantRatings(link, parsed)
	if not parsed or parsed.enchant == 0 then
		return 0, 0, false
	end
	local full = readApiStats(link)
	local bare = readApiStats(linkWithoutEnchant(link))
	local defense = (full.defense or 0) - (bare.defense or 0)
	local resilience = (full.resilience or 0) - (bare.resilience or 0)
	if defense < 0 then defense = 0 end
	if resilience < 0 then resilience = 0 end
	if defense > 0 or resilience > 0 then
		return defense, resilience, true
	end
	defense, resilience = enchantRatings(parsed.enchant)
	return defense, resilience, false
end

local function copyStats(stats)
	local copy = {}
	for key, value in pairs(stats) do
		copy[key] = value
	end
	return copy
end

classificationStats = function(link, classToken, role)
	local stats = itemStats(link)
	local parsed = Classify.ParseLink(link)
	if not stats or not parsed or not stats.resilience or stats.resilience <= 0 then
		return stats
	end
	if not enchantAllowed(parsed.enchant, classToken, role) then
		return stats
	end
	local _, enchantResilience = splitEnchantRatings(link, parsed)
	if not enchantResilience or enchantResilience <= 0 then
		return stats
	end
	local bare = readApiStats(linkWithoutEnchant(link))
	local kept = math.max(bare.resilience or 0, stats.resilience - enchantResilience)
	local copy = copyStats(stats)
	if kept > 0 then
		copy.resilience = kept
	else
		copy.resilience = nil
	end
	return copy
end

local function defenseSummary(skill, resilience, talentRank, talentMax)
	local text = GearCheck:T("DEFENSE_LINE", skill)
	if resilience > 0 then
		text = text .. GearCheck:T("DEFENSE_RESILIENCE", resilience)
	end
	if talentMax then
		text = text .. GearCheck:T("DEFENSE_TALENT", talentRank or 0, talentMax)
	end
	return text
end

local function tankDefense(unit, context, gemsIncomplete)
	local cap = Data.critCap
	local defenseRating, resilienceRating, defenseSkill = 0, 0, 0
	for index = 1, #Data.slots do
		local slotId = Data.SlotId(Data.slots[index].key)
		local link = GetInventoryItemLink(unit, slotId)
		local parsed = Classify.ParseLink(link)
		if link and parsed then
			local bare = passiveStats(linkWithoutEnchant(link))
			defenseRating = defenseRating + (bare.defense or 0)
			resilienceRating = resilienceRating + (bare.resilience or 0)
			local enchantDefense, enchantResilience = splitEnchantRatings(link, parsed)
			defenseRating = defenseRating + enchantDefense
			resilienceRating = resilienceRating + enchantResilience
			local gemDefense, gemResilience = missingGemRatings(link, parsed)
			defenseRating = defenseRating + gemDefense
			resilienceRating = resilienceRating + gemResilience
			defenseSkill = defenseSkill + enchantDefenseSkill(parsed.enchant)
		end
	end

	local talentPercent = 0
	local talentRank, talentMax
	local talentKnown = true
	local reduction = Data.critTalents[context.class]
	if reduction then
		local inspect = not UnitIsUnit(unit, "player")
		local spent = GearCheck.Roles.TalentSpent(inspect, reduction.id)
		if spent == nil then
			talentKnown = false
		else
			if spent > reduction.max then
				spent = reduction.max
			end
			talentRank = spent
			talentMax = reduction.max
			talentPercent = spent * reduction.perRank
		end
	end

	local skillFromRating = defenseRating / cap.defenseRatingPerSkill
	local skill = math.floor(cap.baseDefense + skillFromRating + defenseSkill)
	local resilience = math.floor(resilienceRating + 0.5)
	local fromDefense = (skillFromRating + defenseSkill) * 0.04
	local fromResilience = resilienceRating / cap.resilienceRatingPerPercent
	local total = fromDefense + fromResilience + talentPercent
	local covered = total >= cap.bossCrit - 1e-6
	local immune
	if covered then
		immune = true
	elseif not talentKnown or gemsIncomplete then
		immune = nil
	else
		immune = false
	end

	local detail = tostring(skill)
	if resilience > 0 then
		detail = detail .. GearCheck:T("DEFENSE_RESILIENCE", resilience)
	end
	if talentMax then
		detail = detail .. GearCheck:T("DEFENSE_TALENT", talentRank or 0, talentMax)
	end
	return {
		skill = skill,
		resilience = resilience,
		immune = immune,
		talentRank = talentRank,
		talentMax = talentMax,
		summary = defenseSummary(skill, resilience, talentRank, talentMax),
		issue = GearCheck:T("CRIT_CAP", detail),
	}
end

function Classify.DefenseDebug(unit)
	if not unit or not UnitExists(unit) then
		GearCheck:Print(GearCheck:T("DEBUG_NO_UNIT"))
		return
	end
	local cap = Data.critCap
	local totalPassive, totalEnchant, totalGems, totalSkill = 0, 0, 0, 0
	GearCheck:Print(GearCheck:T("DEBUG_DEFENSE_FOR", UnitName(unit) or unit))
	for index = 1, #Data.slots do
		local slot = Data.slots[index]
		local slotId = Data.SlotId(slot.key)
		local link = GetInventoryItemLink(unit, slotId)
		local parsed = Classify.ParseLink(link)
		if link and parsed then
			local bareLink = linkWithoutEnchant(link)
			local bare = passiveStats(bareLink)
			local apiFull = readApiStats(link)
			local apiBare = readApiStats(bareLink)
			local socket = {}
			addSocketBonus(bareLink, socket)
			local equip = passiveEquipStats(bareLink)
			local gemIds = {}
			for gemIndex = 1, 4 do
				local gemId = gemIdAt(link, parsed, gemIndex)
				if gemId > 0 then
					gemIds[#gemIds + 1] = tostring(gemId)
				end
			end
			local gemText = #gemIds > 0 and table.concat(gemIds, "+") or "-"
			local defenseDelta = (apiFull.defense or 0) - (apiBare.defense or 0)
			if defenseDelta < 0 then defenseDelta = 0 end
			local enchantDefense, _, fromApi = splitEnchantRatings(link, parsed)
			local gemExtra, _, gemDefense = missingGemRatings(link, parsed)
			local skill = enchantDefenseSkill(parsed.enchant)
			local passive = bare.defense or 0
			local enchantText = "-"
			if parsed.enchant > 0 then
				if fromApi then
					enchantText = GearCheck:T("DEBUG_DEFENSE_ENCHANT_API", parsed.enchant, defenseDelta, enchantDefense)
				else
					local tipped = enchantTooltipStats(parsed.enchant)
					local override = Data.enchants[parsed.enchant]
					enchantText = GearCheck:T(
						"DEBUG_DEFENSE_ENCHANT_FALLBACK",
						parsed.enchant,
						tipped and tipped.defense or 0,
						override and override.defense or 0,
						enchantDefense
					)
				end
			end
			if passive > 0 or parsed.enchant > 0 or skill > 0 or gemDefense > 0 or gemText ~= "-" then
				local itemName = string.match(link, "%[(.-)%]") or "?"
				GearCheck:Print(GearCheck:T(
					"DEBUG_DEFENSE_SLOT",
					slot.name,
					itemName,
					passive,
					apiBare.defense or 0,
					socket.defense or 0,
					equip.defense or 0,
					gemDefense,
					gemExtra,
					gemText,
					enchantText,
					skill
				))
			end
			totalPassive = totalPassive + passive
			totalEnchant = totalEnchant + enchantDefense
			totalGems = totalGems + gemExtra
			totalSkill = totalSkill + skill
		end
	end
	local rating = totalPassive + totalEnchant + totalGems
	local skill = math.floor(cap.baseDefense + rating / cap.defenseRatingPerSkill + totalSkill)
	GearCheck:Print(GearCheck:T("DEBUG_DEFENSE_SUM", totalPassive, totalEnchant, totalGems, rating, totalSkill, skill))
	if UnitIsUnit(unit, "player") then
		local base, modifier = UnitDefense("player")
		local ratingId = CR_DEFENSE_SKILL or 2
		local combat = GetCombatRating(ratingId) or 0
		local bonus = GetCombatRatingBonus(ratingId) or 0
		local sheet = (base or 0) + (modifier or 0)
		GearCheck:Print(GearCheck:T("DEBUG_DEFENSE_SHEET", sheet, base or 0, modifier or 0, combat, bonus))
		GearCheck:Print(GearCheck:T("DEBUG_DEFENSE_GAP", combat - rating, sheet - skill))
	end
end

local function enchantMismatch(enchantId, classToken, role)
	local override = Data.enchants[enchantId]
	if override then
		local excluded = override.exclude and override.exclude[classToken]
		if excluded and (excluded == true or excluded[role]) then
			if override.damage and role ~= "damage" then return "damage" end
			return Data.FirstRole(override)
		end
		if override.any or override[role] then return nil end
		return Data.FirstRole(override)
	end
	local stats = enchantTooltipStats(enchantId)
	if not stats then return nil end
	return mismatch(stats, classToken, role, true)
end

local function enchantRequired(slot, equipLoc, classToken)
	if slot.enchant == "always" then return true end
	if slot.enchant == "offhand" then
		return equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND"
	end
	if slot.enchant == "hunter" and classToken == "HUNTER" then
		return equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
	end
	return false
end

local function addIssue(issues, slotName, text)
	issues[#issues + 1] = { slot = slotName, text = text }
end

local function shortName(name)
	if not name or name == "" then return nil end
	if #name > 48 then
		return string.sub(name, 1, 45) .. "..."
	end
	return name
end

-- Numerische Gem-Subklassen (WotLK); auf neueren Clients zusätzlich verfügbar.
local SUBCLASS_COLOR = {
	[0] = "red",
	[1] = "blue",
	[2] = "yellow",
	[3] = "purple",
	[4] = "green",
	[5] = "orange",
	[6] = "meta",
	[7] = "simple",
	[8] = "prismatic",
}

local SUBTYPE_COLOR = {
	Red = "red",
	Rot = "red",
	Yellow = "yellow",
	Gelb = "yellow",
	Blue = "blue",
	Blau = "blue",
	Orange = "orange",
	Purple = "purple",
	Violett = "purple",
	Green = "green",
	["Grün"] = "green",
	Prismatic = "prismatic",
	Prismatisch = "prismatic",
	Meta = "meta",
}

local gemColorCache = {}

local function socketWordStem(global)
	if not global or global == "" then return nil end
	local word = string.match(global, "^(%S+)")
	if not word then return nil end
	word = string.lower(word)
	-- "Roter"/"Blauer"/"Gelber" -> rot/blau/gelb; "Red" bleibt.
	if #word > 4 and string.sub(word, -2) == "er" then
		word = string.sub(word, 1, -3)
	end
	return word
end

local function gemColorFromTooltip(gemId)
	local lines = Classify.Lines("item:" .. gemId)
	if #lines == 0 then return nil end
	local blob = ""
	for index = 1, #lines do
		blob = blob .. "\n" .. string.lower(lines[index].text)
	end
	local function mentioned(global)
		local stem = socketWordStem(global)
		return stem and string.find(blob, stem, 1, true)
	end
	local red = mentioned(EMPTY_SOCKET_RED)
	local yellow = mentioned(EMPTY_SOCKET_YELLOW)
	local blue = mentioned(EMPTY_SOCKET_BLUE)
	local meta = mentioned(EMPTY_SOCKET_META) or string.find(blob, "meta", 1, true)
	if meta and not red and not yellow and not blue then
		return "meta"
	end
	if red and yellow and blue then return "prismatic" end
	if red and yellow then return "orange" end
	if red and blue then return "purple" end
	if yellow and blue then return "green" end
	if red then return "red" end
	if yellow then return "yellow" end
	if blue then return "blue" end
	return nil
end

local function gemColor(gemId)
	if not gemId or gemId <= 0 then return nil end
	local cached = gemColorCache[gemId]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	if Data.metaGems[gemId] then
		gemColorCache[gemId] = "meta"
		return "meta"
	end
	local name, _, _, _, _, _, subType, _, _, _, _, classID, subclassID = GetItemInfo(gemId)
	if not name then
		return nil
	end
	local color
	if classID == 3 and subclassID and SUBCLASS_COLOR[subclassID] then
		color = SUBCLASS_COLOR[subclassID]
	elseif subType and SUBTYPE_COLOR[subType] then
		color = SUBTYPE_COLOR[subType]
	else
		local refs = Data.gemColorRefs
		if refs and subType then
			for refColor, itemId in pairs(refs) do
				if select(7, GetItemInfo(itemId)) == subType then
					color = refColor
					break
				end
			end
		end
	end
	if not color then
		color = gemColorFromTooltip(gemId)
	end
	if color then
		gemColorCache[gemId] = color
	else
		gemColorCache[gemId] = false
	end
	return color
end

local function addGemColor(counts, color)
	if color == "red" then
		counts.red = counts.red + 1
	elseif color == "yellow" then
		counts.yellow = counts.yellow + 1
	elseif color == "blue" then
		counts.blue = counts.blue + 1
	elseif color == "orange" then
		counts.red = counts.red + 1
		counts.yellow = counts.yellow + 1
	elseif color == "purple" then
		counts.red = counts.red + 1
		counts.blue = counts.blue + 1
	elseif color == "green" then
		counts.yellow = counts.yellow + 1
		counts.blue = counts.blue + 1
	elseif color == "prismatic" then
		counts.red = counts.red + 1
		counts.yellow = counts.yellow + 1
		counts.blue = counts.blue + 1
	end
end

local function countGemColors(unit)
	local counts = { red = 0, yellow = 0, blue = 0 }
	local unknown = 0
	for index = 1, #Data.slots do
		local slotId = Data.SlotId(Data.slots[index].key)
		local link = GetInventoryItemLink(unit, slotId)
		local parsed = Classify.ParseLink(link)
		if parsed then
			for gemIndex = 1, 4 do
				local gemId = gemIdAt(link, parsed, gemIndex)
				if gemId > 0 then
					local color = gemColor(gemId)
					if not color then
						unknown = unknown + 1
					elseif color ~= "meta" and color ~= "simple" then
						addGemColor(counts, color)
					end
				end
			end
		end
	end
	return counts, unknown
end

local function metaRequirementMet(req, counts)
	if not req then return nil end
	if req.more then
		local first = req.more[1]
		local second = req.more[2]
		return (counts[first] or 0) > (counts[second] or 0)
	end
	if (counts.red or 0) < (req.red or 0) then return false end
	if (counts.yellow or 0) < (req.yellow or 0) then return false end
	if (counts.blue or 0) < (req.blue or 0) then return false end
	return true
end

local function isGrayLine(line)
	local r, g, b = line.r, line.g, line.b
	local maxc = math.max(r, g, b)
	local minc = math.min(r, g, b)
	return maxc < 0.6 and (maxc - minc) < 0.08
end

-- Fallback: Effektzeilen hinter dem Meta-Namen im Inventar-Tooltip.
local function metaActiveFromTooltip(unit, slotId, gemId)
	local gemName = GetItemInfo(gemId)
	if not gemName then return nil end
	local lines = Classify.InventoryLines(unit, slotId)
	if #lines == 0 then
		local link = GetInventoryItemLink(unit, slotId)
		lines = Classify.Lines(link)
	end
	local startAt
	for index = 1, #lines do
		if string.find(lines[index].text, gemName, 1, true) then
			startAt = index
			break
		end
	end
	if not startAt then return nil end
	local saw, active = false, true
	for index = startAt + 1, math.min(startAt + 4, #lines) do
		local line = lines[index]
		local text = line.text
		if socketKind(text) or isSocketBonus(text) then
			break
		end
		if string.find(text, "%+") or string.find(text, "%%") then
			saw = true
			if isGrayLine(line) then
				active = false
			end
		elseif saw then
			break
		end
	end
	if not saw then return nil end
	return active
end

local function metaResult(active, slotName)
	return {
		active = active,
		slot = slotName,
		summary = active and GearCheck:T("META_ACTIVE") or GearCheck:T("META_INACTIVE"),
	}
end

local function metaStatus(unit)
	for index = 1, #Data.slots do
		local slot = Data.slots[index]
		local slotId = Data.SlotId(slot.key)
		local link = GetInventoryItemLink(unit, slotId)
		local parsed = Classify.ParseLink(link)
		if link and parsed then
			for gemIndex = 1, 4 do
				local gemId = gemIdAt(link, parsed, gemIndex)
				if gemId > 0 then
					local meta = Data.metaGems[gemId]
					local color = gemColor(gemId)
					if meta or color == "meta" then
						if meta and meta.req then
							local counts, unknown = countGemColors(unit)
							local met = metaRequirementMet(meta.req, counts)
							if met == true then
								return metaResult(true, slot.name)
							end
							if met == false and unknown == 0 then
								return metaResult(false, slot.name)
							end
						end
						local active = metaActiveFromTooltip(unit, slotId, gemId)
						if active ~= nil then
							return metaResult(active, slot.name)
						end
						if meta and meta.req then
							local counts, unknown = countGemColors(unit)
							local met = metaRequirementMet(meta.req, counts)
							if met == true then
								return metaResult(true, slot.name)
							end
							if unknown == 0 then
								return metaResult(false, slot.name)
							end
						end
						return metaResult(false, slot.name)
					end
				end
			end
		end
	end
	return nil
end

local PRISMATIC_STATS = { "strength", "agility", "stamina", "intellect", "spirit" }

local function budgetAmount(stats, keys)
	local amount = 0
	for index = 1, #keys do
		local value = stats[keys[index]] or 0
		if value > amount then
			amount = value
		end
	end
	return amount
end

local function budgetShare(stats, budget)
	if not budget then return nil end
	local share, matched = 0, false
	for index = 1, #budget do
		local entry = budget[index]
		local amount = budgetAmount(stats, entry.keys)
		if amount > 0 and entry.cap and entry.cap > 0 then
			share = share + amount / entry.cap
			matched = true
		end
	end
	if not matched then return nil end
	return share
end

local function isAllStatGem(stats)
	for index = 1, #PRISMATIC_STATS do
		if (stats[PRISMATIC_STATS[index]] or 0) <= 0 then
			return false
		end
	end
	return true
end

-- Kleiner als die höchste Fassung: epische Werte, darüber Drachenaugen.
-- Prismatisch zählt die Alptraumträne. Metas ohne Wertung (nur Effekt) bleiben,
-- solange ihre Gegenstandsstufe die volle Fassung ist.
local function gemIsSmall(gemLink, gemId)
	local stats = itemStats(gemLink)
	local meta = Data.metaGems[gemId] ~= nil or gemColor(gemId) == "meta"
	if meta then
		local itemLevel = select(4, GetItemInfo(gemLink))
		if itemLevel and itemLevel < 80 then
			return true
		end
		if not hasStats(stats) then
			return false
		end
		local share = budgetShare(stats, Data.metaGemBudget)
		return share ~= nil and share < 1
	end
	if not hasStats(stats) then
		return false
	end
	if isAllStatGem(stats) then
		local full = Data.prismaticAllStat or 10
		for index = 1, #PRISMATIC_STATS do
			if stats[PRISMATIC_STATS[index]] < full then
				return true
			end
		end
		return false
	end
	local share = budgetShare(stats, Data.gemBudget)
	return share ~= nil and share < 1
end

function Classify.Unit(unit, context)
	local issues = {}
	if not unit or not context or context.role == "unknown" then
		return issues, nil, nil
	end

	local strict = (context.level or 0) >= 80
	local socketedItems, gemsFound = 0, 0

	for index = 1, #Data.slots do
		local slot = Data.slots[index]
		local slotId = Data.SlotId(slot.key)
		local link = GetInventoryItemLink(unit, slotId)
		local parsed = Classify.ParseLink(link)
		if link and parsed then
			local equip = select(9, GetItemInfo(link))
			if equip == "INVTYPE_RELIC" then
				local reason = relicMismatch(link, context.role)
				if reason == "pvp" then
					addIssue(issues, slot.name, GearCheck:T("PVP_RELIC"))
				elseif reason then
					addIssue(issues, slot.name, GearCheck:T("RELIC_MISMATCH", Data.RoleLabel(reason)))
				end
			else
				local reason = mismatch(classificationStats(link, context.class, context.role), context.class, context.role, nil, parsed.id)
				if reason then
					addIssue(issues, slot.name, mismatchText("item", reason))
				end
			end

			local filled = Classify.GemCount(parsed, link)
			gemsFound = gemsFound + filled
			if strict then
				local sockets = Classify.SocketInfo(link)
				if sockets and (sockets.total > 0 or filled > 0) then
					socketedItems = socketedItems + 1
				elseif filled > 0 then
					socketedItems = socketedItems + 1
				end
				if sockets then
					if sockets.meta > 0 then
						addIssue(issues, slot.name, GearCheck:T("META_SOCKET_EMPTY"))
					end
					if sockets.normal == 1 then
						addIssue(issues, slot.name, GearCheck:T("SOCKET_EMPTY"))
					elseif sockets.normal > 1 then
						addIssue(issues, slot.name, GearCheck:T("SOCKETS_EMPTY", sockets.normal))
					end
				end

				if slot.buckle then
					local baseLink = string.format("item:%d:0:0:0:0:0:0:0:0", parsed.id)
					if GetItemInfo(link) then
						local baseInfo = Classify.SocketInfo(baseLink)
						local wornInfo = Classify.SocketInfo(link)
						if baseInfo and wornInfo and (wornInfo.total + filled) <= baseInfo.total then
							addIssue(issues, slot.name, GearCheck:T("BUCKLE_MISSING"))
						end
					end
				end
			elseif filled > 0 then
				socketedItems = socketedItems + 1
			end

			for gemIndex = 1, 4 do
				local gemId = gemIdAt(link, parsed, gemIndex)
				if gemId > 0 then
					local _, gemLink = GetItemGem(link, gemIndex)
					if not gemLink then
						gemLink = "item:" .. gemId
					end
					local name = shortName(GetItemInfo(gemLink))
					local meta = Data.metaGems[gemId]
					if meta then
						if not meta[context.role] then
							addIssue(issues, slot.name, mismatchText("meta", Data.FirstRole(meta), name))
						end
					else
						local reason = mismatch(itemStats(gemLink), context.class, context.role)
						if reason then
							addIssue(issues, slot.name, mismatchText("gem", reason, name))
						end
					end
					if strict and gemIsSmall(gemLink, gemId) then
						if name then
							addIssue(issues, slot.name, GearCheck:T("GEM_SMALL", name))
						else
							addIssue(issues, slot.name, GearCheck:T("GEM_SMALL_UNNAMED"))
						end
					end
				end
			end

			if strict and enchantRequired(slot, equip, context.class) and parsed.enchant == 0 then
				addIssue(issues, slot.name, GearCheck:T("ENCHANT_MISSING"))
			elseif parsed.enchant > 0 then
				local reason = enchantMismatch(parsed.enchant, context.class, context.role)
				if reason then
					addIssue(issues, slot.name, mismatchText("enchant", reason))
				end
			end
		end
	end

	if context.role == "tank" and (context.class == "WARRIOR" or context.class == "PALADIN") then
		local offLink = GetInventoryItemLink(unit, Data.SlotId("SecondaryHandSlot"))
		local offEquip = offLink and select(9, GetItemInfo(offLink))
		if not (offLink and not offEquip) and offEquip ~= "INVTYPE_SHIELD" then
			addIssue(issues, GearCheck:T("SLOT_OFFHAND"), GearCheck:T("SHIELD_MISSING"))
		end
	end

	if context.class == "HUNTER" then
		local rangedLink = GetInventoryItemLink(unit, Data.SlotId("RangedSlot"))
		local rangedEquip = rangedLink and select(9, GetItemInfo(rangedLink))
		local valid = rangedEquip == "INVTYPE_RANGED" or rangedEquip == "INVTYPE_RANGEDRIGHT" or rangedEquip == "INVTYPE_THROWN"
		if not rangedLink or (rangedEquip and not valid) then
			if not (rangedLink and not rangedEquip) then
				addIssue(issues, GearCheck:T("SLOT_RANGED"), GearCheck:T("RANGED_MISSING"))
			end
		end
	end

	local note
	local gemsIncomplete = strict and socketedItems > 0 and gemsFound == 0
	if gemsIncomplete then
		note = GearCheck:T("GEM_NOTE")
	end

	local defense
	if context.role == "tank" and strict then
		defense = tankDefense(unit, context, gemsIncomplete)
		if defense.immune == false then
			addIssue(issues, GearCheck:T("DEFENSE"), defense.issue)
		end
	end

	local meta
	if not gemsIncomplete then
		meta = metaStatus(unit)
		if meta and not meta.active then
			addIssue(issues, meta.slot, GearCheck:T("META_INACTIVE"))
		end
	end

	return issues, note, defense, meta
end
