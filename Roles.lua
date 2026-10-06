local _, GearCheck = ...

local Roles = {}
GearCheck.Roles = Roles

local Data = GearCheck.Data

local function talentPoints(tab, inspect, group)
	local points = select(3, GetTalentTabInfo(tab, inspect, false, group))
	return points or 0
end

local function tankTalentNames(classToken)
	local definition = Data.tankTalents[classToken]
	if not definition then return nil end
	if not definition.resolved then
		local ready = true
		for index = 1, #definition.talents do
			local talent = definition.talents[index]
			if not talent.name then
				talent.name = GetSpellInfo(talent.id)
				if not talent.name then
					ready = false
				end
			end
		end
		definition.resolved = ready
	end
	return definition
end

local function countTankMatches(classToken, inspect, group)
	local definition = tankTalentNames(classToken)
	if not definition then return 0 end
	local found = 0
	local tabs = GetNumTalentTabs(inspect) or 0
	for tab = 1, tabs do
		local talents = GetNumTalents(tab, inspect) or 0
		for index = 1, talents do
			local name, _, _, _, spent = GetTalentInfo(tab, index, inspect, false, group)
			if name and spent and spent > 0 then
				for talentIndex = 1, #definition.talents do
					local talent = definition.talents[talentIndex]
					if talent.name and name == talent.name and spent >= talent.rank then
						found = found + 1
						break
					end
				end
			end
		end
	end
	return found
end

function Roles.Read(classToken, inspect)
	local result = {
		role = "unknown",
		label = Data.RoleLabel("unknown"),
		trees = "0/0/0",
		class = classToken,
	}
	if not classToken or not Data.treeRole[classToken] then
		return result
	end

	inspect = inspect and true or false
	local group = GetActiveTalentGroup(inspect) or 1
	local first = talentPoints(1, inspect, group)
	local second = talentPoints(2, inspect, group)
	local third = talentPoints(3, inspect, group)
	local unspent = GetUnspentTalentPoints(inspect, false, group) or 0
	result.trees = string.format("%d/%d/%d", first, second, third)
	if unspent > 0 then
		result.trees = result.trees .. GearCheck:T("UNSPENT", unspent)
	end

	local matches = countTankMatches(classToken, inspect, group)
	local definition = Data.tankTalents[classToken]
	if definition and matches >= definition.required then
		result.role = "tank"
		result.label = Data.RoleLabel("tank")
		return result
	end

	local highest = math.max(first, second, third)
	local leaders = 0
	if first == highest then leaders = leaders + 1 end
	if second == highest then leaders = leaders + 1 end
	if third == highest then leaders = leaders + 1 end
	if highest < 10 or leaders ~= 1 then
		return result
	end

	local treeIndex = first == highest and 1 or second == highest and 2 or 3
	result.role = Data.treeRole[classToken][treeIndex] or "unknown"
	result.label = Data.RoleLabel(result.role)
	return result
end
