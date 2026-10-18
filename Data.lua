local _, GearCheck = ...

local Data = {}
GearCheck.Data = Data

-- Reihenfolge entspricht dem Charakterfenster, ohne Hemd und Wappenrock.
Data.slots = {
	{ key = "HeadSlot", name = GearCheck:T("SLOT_HEAD"), enchant = "always" },
	{ key = "NeckSlot", name = GearCheck:T("SLOT_NECK") },
	{ key = "ShoulderSlot", name = GearCheck:T("SLOT_SHOULDER"), enchant = "always" },
	{ key = "BackSlot", name = GearCheck:T("SLOT_BACK"), enchant = "always" },
	{ key = "ChestSlot", name = GearCheck:T("SLOT_CHEST"), enchant = "always" },
	{ key = "WristSlot", name = GearCheck:T("SLOT_WRIST"), enchant = "always" },
	{ key = "HandsSlot", name = GearCheck:T("SLOT_HANDS"), enchant = "always" },
	{ key = "WaistSlot", name = GearCheck:T("SLOT_WAIST"), buckle = true },
	{ key = "LegsSlot", name = GearCheck:T("SLOT_LEGS"), enchant = "always" },
	{ key = "FeetSlot", name = GearCheck:T("SLOT_FEET"), enchant = "always" },
	{ key = "Finger0Slot", name = GearCheck:T("SLOT_FINGER0") },
	{ key = "Finger1Slot", name = GearCheck:T("SLOT_FINGER1") },
	{ key = "Trinket0Slot", name = GearCheck:T("SLOT_TRINKET0") },
	{ key = "Trinket1Slot", name = GearCheck:T("SLOT_TRINKET1") },
	{ key = "MainHandSlot", name = GearCheck:T("SLOT_MAINHAND"), enchant = "always" },
	{ key = "SecondaryHandSlot", name = GearCheck:T("SLOT_OFFHAND"), enchant = "offhand" },
	{ key = "RangedSlot", name = GearCheck:T("SLOT_RANGED"), enchant = "hunter" },
}

Data.treeRole = {
	WARRIOR = { "damage", "damage", "tank" },
	PALADIN = { "healer", "tank", "damage" },
	HUNTER = { "damage", "damage", "damage" },
	ROGUE = { "damage", "damage", "damage" },
	PRIEST = { "healer", "healer", "caster" },
	DEATHKNIGHT = { "damage", "damage", "damage" },
	SHAMAN = { "caster", "damage", "healer" },
	MAGE = { "caster", "caster", "caster" },
	WARLOCK = { "caster", "caster", "caster" },
	DRUID = { "caster", "damage", "healer" },
}

-- Blut-DK und Bär teilen sich den Baum mit der Schadens-Skillung.
Data.tankTalents = {
	DEATHKNIGHT = {
		required = 2,
		talents = {
			{ id = 16271, rank = 5 }, -- Antizipation
			{ id = 49042, rank = 5 }, -- Zähigkeit
			{ id = 55225, rank = 5 }, -- Klingeabwehr
		},
	},
	DRUID = {
		required = 3,
		talents = {
			{ id = 57881, rank = 2 }, -- Natürliche Reaktion
			{ id = 16929, rank = 3 }, -- Dickes Fell
			{ id = 61336, rank = 1 }, -- Überlebensinstinkte
			{ id = 57877, rank = 3 }, -- Beschützer des Rudels
		},
	},
}

-- Werte, deren lokalisierter Name im Tooltip und in GetItemStats vorkommt.
Data.statGlobals = {
	{ key = "stamina", global = "ITEM_MOD_STAMINA_SHORT" },
	{ key = "strength", global = "ITEM_MOD_STRENGTH_SHORT" },
	{ key = "agility", global = "ITEM_MOD_AGILITY_SHORT" },
	{ key = "intellect", global = "ITEM_MOD_INTELLECT_SHORT" },
	{ key = "spirit", global = "ITEM_MOD_SPIRIT_SHORT" },
	{ key = "spellPower", global = "ITEM_MOD_SPELL_POWER_SHORT" },
	{ key = "spellDamage", global = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
	{ key = "healing", global = "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
	{ key = "attackPower", global = "ITEM_MOD_ATTACK_POWER_SHORT" },
	{ key = "meleeAP", global = "ITEM_MOD_MELEE_ATTACK_POWER_SHORT" },
	{ key = "rangedAP", global = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
	{ key = "armorPen", global = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
	{ key = "hit", global = "ITEM_MOD_HIT_RATING_SHORT" },
	{ key = "spellHit", global = "ITEM_MOD_HIT_SPELL_RATING_SHORT" },
	{ key = "meleeHit", global = "ITEM_MOD_HIT_MELEE_RATING_SHORT" },
	{ key = "rangedHit", global = "ITEM_MOD_HIT_RANGED_RATING_SHORT" },
	{ key = "crit", global = "ITEM_MOD_CRIT_RATING_SHORT" },
	{ key = "spellCrit", global = "ITEM_MOD_CRIT_SPELL_RATING_SHORT" },
	{ key = "meleeCrit", global = "ITEM_MOD_CRIT_MELEE_RATING_SHORT" },
	{ key = "rangedCrit", global = "ITEM_MOD_CRIT_RANGED_RATING_SHORT" },
	{ key = "haste", global = "ITEM_MOD_HASTE_RATING_SHORT" },
	{ key = "spellHaste", global = "ITEM_MOD_HASTE_SPELL_RATING_SHORT" },
	{ key = "expertise", global = "ITEM_MOD_EXPERTISE_RATING_SHORT" },
	{ key = "defense", global = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
	{ key = "dodge", global = "ITEM_MOD_DODGE_RATING_SHORT" },
	{ key = "parry", global = "ITEM_MOD_PARRY_RATING_SHORT" },
	{ key = "block", global = "ITEM_MOD_BLOCK_RATING_SHORT" },
	{ key = "blockValue", global = "ITEM_MOD_BLOCK_VALUE_SHORT" },
	{ key = "resilience", global = "ITEM_MOD_RESILIENCE_RATING_SHORT" },
	{ key = "mp5", global = "ITEM_MOD_POWER_REGEN0_SHORT" },
	{ key = "mp5", global = "ITEM_MOD_MANA_REGENERATION_SHORT" },
	{ key = "spellPen", global = "ITEM_MOD_SPELL_PENETRATION_SHORT" },
}

-- Meta-Edelsteine, deren Effekt über den reinen Attributtext hinausgeht.
-- req = Mindestanzahl je Farbe; more = { a, b } bedeutet Farbe a > Farbe b (TBC).
Data.metaGems = {
	[41285] = { damage = true, caster = true, req = { blue = 2 } }, -- Chaotischer Polarlichtdiamant
	[34220] = { damage = true, caster = true, req = { more = { "red", "yellow" } } }, -- Chaotischer Himmelsfeuerdiamant
	[41376] = { healer = true, req = { red = 2 } }, -- Belebender Polarlichtdiamant
	[41333] = { caster = true, healer = true, req = { red = 3 } }, -- Glutpolarlichtdiamant
	[41377] = { caster = true, healer = true, req = { red = 1, blue = 2 } }, -- Strahlender Polarlichtdiamant (Effulgent)
	[41380] = { tank = true, req = { red = 1, blue = 2 } }, -- Strenger Erdspalterdiamant (Austere)
	[41395] = { tank = true, caster = true, healer = true, req = { red = 2, blue = 1 } }, -- Stärkender Erdspalterdiamant (Bracing)
	[41396] = { tank = true, req = { red = 2, blue = 1 } }, -- Ewiger Erdspalterdiamant (Eternal)
	[41397] = { tank = true, req = { blue = 3 } }, -- Mächtiger Erdspalterdiamant (Powerful)
	[41401] = { caster = true, healer = true, req = { red = 1, yellow = 1, blue = 1 } }, -- Bemerkenswerter Erdspalterdiamant (Insightful)
	[41385] = { caster = true, healer = true, req = { red = 1, blue = 2 } }, -- Belebender Erdspalterdiamant (Invigorating)
	[41389] = { damage = true, caster = true, healer = true, req = { red = 2, yellow = 1 } }, -- Strahlender Erdspalterdiamant (Beaming)
	[41381] = { damage = true, req = { yellow = 2, blue = 1 } }, -- Beständiger Erdspalterdiamant (Persistent)
	[41382] = { damage = true, req = { red = 1, yellow = 1, blue = 1 } }, -- Energischer Erdspalterdiamant (Trenchant)
	[41398] = { damage = true, req = { red = 1, yellow = 1, blue = 1 } }, -- Unerbittlicher Erdspalterdiamant (Relentless)
	[41400] = { damage = true, req = { red = 1, yellow = 1, blue = 1 } }, -- Donnernder Polarlichtdiamant (Thundering)
	[41307] = { damage = true, caster = true, req = { red = 1, yellow = 1, blue = 1 } }, -- Zerstörerischer Polarlichtdiamant
	[41339] = { damage = true, req = { red = 1, yellow = 2 } }, -- Flüchtiger Polarlichtdiamant (Swift)
	[41375] = { caster = true, healer = true, req = { red = 1, yellow = 1, blue = 1 } }, -- Unermüdlicher Polarlichtdiamant (Tireless)
	[41335] = { damage = true, caster = true, req = { red = 2, yellow = 1 } }, -- Rätselhafter Polarlichtdiamant (Enigmatic)
}

-- Referenz-IDs für GetItemInfo-Subtypen (locale-unabhängig).
Data.gemColorRefs = {
	red = 40111, -- Fetter Scharlachrubin
	yellow = 40124, -- Glatter Königsbernstein
	blue = 40119, -- Solider Fürstenzirkon
	orange = 40142, -- Gravierter Ametrin
	purple = 40129, -- Stattlicher Schreckensstein
	green = 40167, -- Robuster Auge von Zul
	prismatic = 49110, -- Alptraumträne
}

-- Proc-Verzauberungen, deren Tooltip keine eindeutige Wertung trägt oder in die Irre führt.
Data.enchants = {
	[3368] = { damage = true, tank = true }, -- Rune des gefallenen Kreuzfahrers
	[3369] = { damage = true, caster = true }, -- Rune des schwarzen Gletschers
	[3370] = { damage = true }, -- Rune des schneidenden Eises
	[3365] = { tank = true }, -- Rune des Schwertbrechens
	[3594] = { tank = true }, -- Rune des Schwertzerbrechens
	[3367] = { pvp = true }, -- Rune des Zauberbrechens
	[3595] = { pvp = true }, -- Rune des Zauberzerbrechens
	[3883] = { tank = true }, -- Rune des nerubischen Panzers
	[3847] = { tank = true }, -- Rune des Steinhautgargoyles
	[2673] = { tank = true, damage = true, exclude = { DEATHKNIGHT = { tank = true } } }, -- Mungo
	[3225] = { damage = true }, -- Henker
	[3789] = { damage = true }, -- Berserker
	[3790] = { damage = true, caster = true }, -- Schwarzmagie
	[3731] = { tank = true, damage = true }, -- Titanwaffenkette
	[3748] = { tank = true }, -- Titanspitze
	[3849] = { tank = true }, -- Titanbeschlag
	[3728] = { caster = true, healer = true }, -- Dunkelglühende Stickerei
	[3730] = { damage = true }, -- Schwertwallstickerei
	[3722] = { caster = true, healer = true }, -- Lichtgewebe-Stickerei
	[3606] = { any = true }, -- Nitrobeschleuniger
	[3860] = { tank = true }, -- Netzförmige Rüstungsverstärkung
	[3859] = { caster = true, healer = true }, -- Federnde Arachnodrahthose
	[3878] = { tank = true }, -- Gedankenverstärkungsschüssel
	[3603] = { damage = true, tank = true }, -- Handmontierte Pyrorakete
	[3604] = { damage = true, caster = true, healer = true }, -- Hyperspeed-Beschleuniger
	[3869] = { tank = true }, -- Klingenwall
	[3870] = { tank = true }, -- Blutsauger
	[3232] = { any = true }, -- Vitalität der Tuskarr
	[3852] = { tank = true, resilience = 15 }, -- Große Inschrift des Gladiators
}

-- Stufe 80 gegen Bosse der Stufe 83 (5,6 % Crit). Verteidigungswertung und Abhärtung rechnen zusammen.
Data.critCap = {
	bossCrit = 5.6,
	baseDefense = 400,
	defenseRatingPerSkill = 4.918498039245605,
	resilienceRatingPerPercent = 94.27164459228516,
}

-- Crit-Reduktion aus Talenten, in Prozent pro Rang.
Data.critTalents = {
	DRUID = { id = 33853, perRank = 2, max = 3 }, -- Überleben des Stärkeren
}

-- Gegenstände, die trotz Schadenswerten für die genannten Rollen erlaubt sind.
Data.items = {
	[50012] = { tank = true, damage = true }, -- Chaosruf (25)
	[50737] = { tank = true, damage = true }, -- Chaosruf (25 heroisch)
}

Data.relics = {
	{ id = 2912, roles = { caster = true } }, -- Sternenfeuer
	{ id = 5176, roles = { caster = true } }, -- Zorn
	{ id = 8921, roles = { caster = true } }, -- Mondfeuer
	{ id = 5570, roles = { caster = true } }, -- Insektenschwarm
	{ id = 6807, roles = { tank = true } }, -- Zermalmen
	{ id = 779, roles = { tank = true, damage = true } }, -- Zerschmettern
	{ id = 50256, roles = { tank = true, damage = true } }, -- Zerschmettern (Bär)
	{ id = 33745, roles = { tank = true } }, -- Aufschlitzen
	{ id = 33878, roles = { tank = true, damage = true } }, -- Zermalmen (Bär)
	{ id = 33876, roles = { tank = true, damage = true } }, -- Zermalmen (Katze)
	{ id = 33917, roles = { tank = true, damage = true } }, -- Zermalmen
	{ id = 5221, roles = { damage = true } }, -- Schreddern
	{ id = 1079, roles = { damage = true } }, -- Zerfetzen
	{ id = 1822, roles = { damage = true } }, -- Krallenhieb
	{ id = 22568, roles = { damage = true } }, -- Wilder Biss
	{ id = 774, roles = { healer = true } }, -- Verjüngung
	{ id = 8936, roles = { healer = true } }, -- Nachwachsen
	{ id = 33763, roles = { healer = true } }, -- Blühendes Leben
	{ id = 48438, roles = { healer = true } }, -- Wildwuchs
	{ id = 50464, roles = { healer = true } }, -- Nähren
	{ id = 5185, roles = { healer = true } }, -- Heilende Berührung
	{ id = 635, roles = { healer = true } }, -- Heiliges Licht
	{ id = 19750, roles = { healer = true } }, -- Lichtblitz
	{ id = 20473, roles = { healer = true } }, -- Heiliger Schock
	{ id = 35395, roles = { damage = true } }, -- Kreuzfahrerstoß
	{ id = 53385, roles = { damage = true } }, -- Göttlicher Sturm
	{ id = 53600, roles = { tank = true } }, -- Schild der Rechtschaffenheit
	{ id = 53595, roles = { tank = true } }, -- Hammer der Rechtschaffenheit
	{ id = 20925, roles = { tank = true } }, -- Heiliger Schild
	{ id = 31935, roles = { tank = true } }, -- Schild des Rächers
	{ id = 26573, roles = { tank = true, damage = true } }, -- Weihe
	{ id = 403, roles = { caster = true } }, -- Blitzschlag
	{ id = 421, roles = { caster = true } }, -- Kettenblitzschlag
	{ id = 51505, roles = { caster = true } }, -- Lavaeruption
	{ id = 8050, roles = { caster = true } }, -- Flammenschock
	{ id = 331, roles = { healer = true } }, -- Heilende Welle
	{ id = 8004, roles = { healer = true } }, -- Geringe heilende Welle
	{ id = 1064, roles = { healer = true } }, -- Kettenheilung
	{ id = 61295, roles = { healer = true } }, -- Springflut
	{ id = 974, roles = { healer = true } }, -- Erdschild
	{ id = 17364, roles = { damage = true } }, -- Sturmschlag
	{ id = 60103, roles = { damage = true } }, -- Lavapeitsche
	{ id = 8232, roles = { damage = true } }, -- Windfurorwaffe
	{ id = 56815, roles = { tank = true } }, -- Runenschlag
	{ id = 49998, roles = { tank = true, damage = true } }, -- Todesstoß
	{ id = 45477, roles = { tank = true, damage = true } }, -- Eisige Berührung
	{ id = 45902, roles = { damage = true } }, -- Blutstoß
	{ id = 55050, roles = { damage = true } }, -- Herzstoß
	{ id = 49020, roles = { damage = true } }, -- Auslöschen
	{ id = 55090, roles = { damage = true } }, -- Geißelstoß
	{ id = 47541, roles = { damage = true } }, -- Todesmantel
	{ id = 49143, roles = { damage = true } }, -- Froststoß
	{ id = 49184, roles = { damage = true } }, -- Heulende Böe
}

function Data.RoleLabel(role)
	return GearCheck:T("ROLE_" .. string.upper(role or "unknown"))
end

function Data.SlotId(key)
	Data.slotIds = Data.slotIds or {}
	if not Data.slotIds[key] then
		Data.slotIds[key] = GetInventorySlotInfo(key)
	end
	return Data.slotIds[key]
end

function Data.FirstRole(set)
	if not set or set.pvp then return "pvp" end
	if set.tank then return "tank" end
	if set.healer then return "healer" end
	if set.caster then return "caster" end
	if set.damage then return "damage" end
	return "pvp"
end
