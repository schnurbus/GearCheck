local _, GearCheck = ...

local Score = {}
GearCheck.Score = Score

-- Dieselbe Rechnung wie GearScore_GetItemScore / GearScore_GetScore:
-- Gegenstandsstufe, Seltenheit, Slot-Faktor, danach Titan's Grip und die Jäger-Faktoren.
local SCALE = 1.8618

local FORMULA = {
	A = {
		[4] = { A = 91.4500, B = 0.6500 },
		[3] = { A = 81.3750, B = 0.8125 },
		[2] = { A = 73.0000, B = 1.0000 },
	},
	B = {
		[4] = { A = 26.0000, B = 1.2000 },
		[3] = { A = 0.7500, B = 1.8000 },
		[2] = { A = 8.0000, B = 2.0000 },
		[1] = { A = 0.0000, B = 2.2500 },
	},
}

local SLOT_MOD = {
	INVTYPE_RELIC = 0.3164,
	INVTYPE_TRINKET = 0.5625,
	INVTYPE_2HWEAPON = 2.000,
	INVTYPE_WEAPONMAINHAND = 1.0000,
	INVTYPE_WEAPONOFFHAND = 1.0000,
	INVTYPE_RANGED = 0.3164,
	INVTYPE_THROWN = 0.3164,
	INVTYPE_RANGEDRIGHT = 0.3164,
	INVTYPE_SHIELD = 1.0000,
	INVTYPE_WEAPON = 1.0000,
	INVTYPE_HOLDABLE = 1.0000,
	INVTYPE_HEAD = 1.0000,
	INVTYPE_NECK = 0.5625,
	INVTYPE_SHOULDER = 0.7500,
	INVTYPE_CHEST = 1.0000,
	INVTYPE_ROBE = 1.0000,
	INVTYPE_WAIST = 0.7500,
	INVTYPE_LEGS = 1.0000,
	INVTYPE_FEET = 0.75,
	INVTYPE_WRIST = 0.5625,
	INVTYPE_HAND = 0.7500,
	INVTYPE_FINGER = 0.5625,
	INVTYPE_CLOAK = 0.5625,
}

local QUALITY = {
	[6000] = {
		red = { A = 0.94, B = 5000, C = 0.00006, D = 1 },
		green = { A = 0.47, B = 5000, C = 0.00047, D = -1 },
		blue = { A = 0, B = 0, C = 0, D = 0 },
	},
	[5000] = {
		red = { A = 0.69, B = 4000, C = 0.00025, D = 1 },
		green = { A = 0.28, B = 4000, C = 0.00019, D = 1 },
		blue = { A = 0.97, B = 4000, C = 0.00096, D = -1 },
	},
	[4000] = {
		red = { A = 0.0, B = 3000, C = 0.00069, D = 1 },
		green = { A = 0.5, B = 3000, C = 0.00022, D = -1 },
		blue = { A = 1, B = 3000, C = 0.00003, D = -1 },
	},
	[3000] = {
		red = { A = 0.12, B = 2000, C = 0.00012, D = -1 },
		green = { A = 1, B = 2000, C = 0.00050, D = -1 },
		blue = { A = 0, B = 2000, C = 0.001, D = 1 },
	},
	[2000] = {
		red = { A = 1, B = 1000, C = 0.00088, D = -1 },
		green = { A = 1, B = 0, C = 0.00000, D = 0 },
		blue = { A = 1, B = 1000, C = 0.001, D = -1 },
	},
	[1000] = {
		red = { A = 0.55, B = 0, C = 0.00045, D = 1 },
		green = { A = 0.55, B = 0, C = 0.00045, D = 1 },
		blue = { A = 0.55, B = 0, C = 0.00045, D = 1 },
	},
}

local function clamp(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

local function mix(part, score)
	return part.A + (((score - part.B) * part.C) * part.D)
end

function Score.Item(quality, itemLevel, equipLoc)
	if quality == nil or itemLevel == nil then return nil end
	local qualityScale = 1
	if quality == 5 then
		qualityScale = 1.3
		quality = 4
	elseif quality == 1 or quality == 0 then
		qualityScale = 0.005
		quality = 2
	end
	if quality == 7 then
		quality = 3
		itemLevel = 187.05
	end
	local slotMod = SLOT_MOD[equipLoc]
	if not slotMod then return -1 end
	if quality < 2 or quality > 4 then return -1 end
	local band = (itemLevel > 120 and FORMULA.A or FORMULA.B)[quality]
	if not band then return -1 end
	local gearScore = math.floor(((itemLevel - band.A) / band.B) * slotMod * SCALE * qualityScale)
	if gearScore < 0 then gearScore = 0 end
	return gearScore
end

function Score.Color(score)
	if not score then return 0, 0, 0 end
	if score > 5999 then score = 5999 end
	for index = 0, 5 do
		local cap = (index + 1) * 1000
		if score > index * 1000 and score <= cap then
			local band = QUALITY[cap]
			return clamp(mix(band.red, score)), clamp(mix(band.green, score)), clamp(mix(band.blue, score))
		end
	end
	return 0.1, 0.1, 0.1
end

function Score.Text(score)
	local r, g, b = Score.Color(score)
	local text = GearCheck:T("GEARSCORE", score)
	return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

local function remember(entry)
	if not entry.link then return true end
	if entry.level and entry.quality ~= nil and entry.equip ~= nil then return true end
	local name, _, quality, itemLevel, _, _, _, _, equip, texture = GetItemInfo(entry.link)
	if not itemLevel then return false end
	entry.itemName = entry.itemName or name
	if entry.quality == nil then entry.quality = quality end
	entry.level = entry.level or itemLevel
	if entry.equip == nil then entry.equip = equip or "" end
	entry.texture = entry.texture or texture
	return true
end

local function contribute(total, entry, slotId, classToken, titan)
	if not entry or not entry.link then return total end
	local gearScore = Score.Item(entry.quality, entry.level, entry.equip)
	if not gearScore then return total end
	if slotId == 16 or slotId == 17 then
		if classToken == "HUNTER" then gearScore = gearScore * 0.3164 end
		gearScore = gearScore * titan
	elseif slotId == 18 and classToken == "HUNTER" then
		gearScore = gearScore * 5.3224
	end
	return total + gearScore
end

function Score.FromGear(gear, classToken)
	if not gear then return nil end
	local bySlot = {}
	for index = 1, #gear do
		local entry = gear[index]
		if not remember(entry) then return nil end
		bySlot[GearCheck.Data.SlotId(entry.key)] = entry
	end

	local mainHand = bySlot[16]
	local offHand = bySlot[17]
	local titan = 1
	if mainHand and mainHand.link and offHand and offHand.link and mainHand.equip == "INVTYPE_2HWEAPON" then
		titan = 0.5
	end
	if offHand and offHand.link and offHand.equip == "INVTYPE_2HWEAPON" then
		titan = 0.5
	end

	local total = 0
	total = contribute(total, offHand, 17, classToken, titan)
	for slotId = 1, 18 do
		if slotId ~= 4 and slotId ~= 17 then
			total = contribute(total, bySlot[slotId], slotId, classToken, titan)
		end
	end
	if total <= 0 then return 0 end
	return math.floor(total)
end
