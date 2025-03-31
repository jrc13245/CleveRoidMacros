--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}


local function And(t,func)
    if type(func) ~= "function" then return false end
    if type(t) ~= "table" then
        t = { [1] = t }
    end
    for k,v in pairs(t) do
        if not func(v) then
            return false
        end
    end
    return true
end

local function Or(t,func)
    if type(func) ~= "function" then return false end
    if type(t) ~= "table" then
        t = { [1] = t }
    end
    if type(t) ~= "table" then
        t = { [1] = t }
    end
    for k,v in pairs(t) do
        if func(v) then
            return true
        end
    end
    return false
end


-- Validates that the given target is either friend (if [help]) or foe (if [harm])
-- target: The unit id to check
-- help: Optional. If set to 1 then the target must be friendly. If set to 0 it must be an enemy.
-- remarks: Will always return true if help is not given
-- returns: Whether or not the given target can either be attacked or supported, depending on help
function CleveRoids.CheckHelp(target, help)
    if help == nil then return true end
    if help then
        return UnitCanAssist("player", target)
    else
        return UnitCanAttack("player", target)
    end
end

-- Ensures the validity of the given target
-- target: The unit id to check
-- help: Optional. If set to 1 then the target must be friendly. If set to 0 it must be an enemy
-- returns: Whether or not the target is a viable target
function CleveRoids.IsValidTarget(target, help)
    if target ~= "mouseover" then
        if not CleveRoids.CheckHelp(target, help) or not UnitExists(target) then
			return false
		end
		return true
	end

	if (not CleveRoids.mouseoverUnit) and not UnitName("mouseover") then
		return false
	end

	return CleveRoids.CheckHelp(target, help)
end

-- Returns the current shapeshift / stance index
-- returns: The index of the current shapeshift form / stance. 0 if in no shapeshift form / stance
function CleveRoids.GetCurrentShapeshiftIndex()
    if CleveRoids.playerClass == "PRIEST" then
        return CleveRoids.ValidatePlayerBuff(CleveRoids.Localized.Spells["Shadowform"]) and 1 or 0
    elseif CleveRoids.playerClass == "ROGUE" then
        return CleveRoids.ValidatePlayerBuff(CleveRoids.Localized.Spells["Stealth"]) and 1 or 0
    end
    for i=1, GetNumShapeshiftForms() do
        _, _, active = GetShapeshiftFormInfo(i)
        if active then
            return i
        end
    end

    return 0
end

function CleveRoids.CancelAura(auraName)
    local ix = 0
    auraName = string.lower(string.gsub(auraName, "_"," "))
    while true do
        local aura_ix = GetPlayerBuff(ix,"HELPFUL")
        ix = ix + 1
        if aura_ix == -1 then break end
        local bid = GetPlayerBuffID(aura_ix)
        bid = (bid < -1) and (bid + 65536) or bid
        if string.lower(SpellInfo(bid)) == auraName then
            CancelPlayerBuff(aura_ix)
            return true
        end
    end
    return false
end

-- Checks whether a given piece of gear is equipped is currently equipped
-- gearId: The name (or item id) of the gear (e.g. Badge_Of_The_Swam_Guard, etc.)
-- returns: True when equipped, otherwhise false
function CleveRoids.HasGearEquipped(gearId)
    local item = CleveRoids.GetItem(gearId)
    return item and item.inventoryID
end

-- Checks whether or not the given weaponType is currently equipped
-- weaponType: The name of the weapon's type (e.g. Axe, Shield, etc.)
-- returns: True when equipped, otherwhise false
function CleveRoids.HasWeaponEquipped(weaponType)
    if not CleveRoids.WeaponTypeNames[weaponType] then
        return false
    end

    local slotName = CleveRoids.WeaponTypeNames[weaponType].slot
    local localizedName = CleveRoids.WeaponTypeNames[weaponType].name
    local slotId = GetInventorySlotInfo(slotName)
    local slotLink = GetInventoryItemLink("player",slotId)
    if not slotLink then
        return false
    end

    local _,_,itemId = string.find(slotLink,"item:(%d+)")
    local _name,_link,_,_lvl,_type,subtype = GetItemInfo(itemId)
    -- just had to be special huh?
    local fist = string.find(subtype,"^Fist")
    -- drops things like the One-Handed prefix
    local _,_,subtype = string.find(subtype,"%s?(%S+)$")

    if subtype == localizedName or (fist and (CleveRoids.WeaponTypeNames[weaponType].name == CleveRoids.Localized.FistWeapon)) then
        return true
    end

    return false
end

-- Checks whether or not the given UnitId is in your party or your raid
-- target: The UnitId of the target to check
-- groupType: The name of the group type your target has to be in ("party" or "raid")
-- returns: True when the given target is in the given groupType, otherwhise false
function CleveRoids.IsTargetInGroupType(target, groupType)
    local groupSize = (groupType == "raid") and 40 or 5

    for i = 1, groupSize do
        if UnitIsUnit(groupType..i, target) then
            return true
        end
    end

    return false
end

function CleveRoids.GetSpammableConditional(name)
    return CleveRoids.spamConditions[name] or "nomybuff"
end

-- Checks whether or not we're currently casting a channeled spell
function CleveRoids.CheckChanneled(channeledSpell)
    if not channeledSpell then return false end

    -- Remove the "(Rank X)" part from the spells name in order to allow downranking
    local spellName = string.gsub(CleveRoids.CurrentSpell.spellName, "%(.-%)%s*", "")
    local channeled = string.gsub(channeledSpell, "%(.-%)%s*", "")

    if CleveRoids.CurrentSpell.type == "channeled" and spellName == channeled then
        return false
    end

    if channeled == CleveRoids.Localized.Attack then
        return not CleveRoids.CurrentSpell.autoAttack
    end

    if channeled == CleveRoids.Localized.AutoShot then
        return not CleveRoids.CurrentSpell.autoShot
    end

    if channeled == CleveRoids.Localized.Shoot then
        return not CleveRoids.CurrentSpell.wand
    end

    CleveRoids.CurrentSpell.spellName = channeled
    return true
end

function CleveRoids.ValidateComboPoints(operator, amount)
    if not operator or not amount then return false end
    local points = GetComboPoints()

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](points, amount)
    end

    return false
end

function CleveRoids.ValidateKnown(args)
    if not args then return false end
    if table.getn(CleveRoids.Talents) == 0 then CleveRoids.IndexTalents() end

    if type(args) ~= "table" then
        args = { name = args }
    end

    local spell, talent = CleveRoids.GetSpell(args.name), nil
    if not spell then
        talent = CleveRoids.GetTalent(args.name)
    end

    if not spell and not talent then return false end
    local rank = spell and string.gsub(spell.rank, "Rank ", "") or talent

    if rank and not args.amount and not args.operator then
        return true
    elseif args.amount and CleveRoids.operators[args.operator] then
        return CleveRoids.comparators[args.operator](tonumber(rank), args.amount)
    else
        return false
    end
end

function CleveRoids.ValidateResting()
    return IsResting()
end


-- TODO: refactor numeric comparisons...

-- Checks whether or not the given unit has power in percent vs the given amount
-- unit: The unit we're checking
-- operator: valid comparitive operator symbol
-- amount: The required amount
-- returns: True or false
function CleveRoids.ValidatePower(unit, operator, amount)
    if not unit or not operator or not amount then return false end
    local powerPercent = 100 / UnitManaMax(unit) * UnitMana(unit)

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](powerPercent, amount)
    end

    return false
end

-- Checks whether or not the given unit has current power vs the given amount
-- unit: The unit we're checking
-- operator: valid comparitive operator symbol
-- amount: The required amount
-- returns: True or false
function CleveRoids.ValidateRawPower(unit, operator, amount)
    if not unit or not operator or not amount then return false end
    local power = UnitMana(unit)

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](power, amount)
    end

    return false
end

-- Checks whether or not the given unit has a power deficit vs the amount specified
-- unit: The unit we're checking
-- operator: valid comparitive operator symbol
-- amount: The required amount
-- returns: True or false
function CleveRoids.ValidatePowerLost(unit, operator, amount)
    if not unit or not operator or not amount then return false end
    local powerLost = UnitManaMax(unit) - UnitMana(unit)

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](powerLost, amount)
    end

    return false
end

-- Checks whether or not the given unit has hp in percent vs the given amount
-- unit: The unit we're checking
-- operator: valid comparitive operator symbol
-- amount: The required amount
-- returns: True or false
function CleveRoids.ValidateHp(unit, operator, amount)
    if not unit or not operator or not amount then return false end
    local hpPercent = 100 / UnitHealthMax(unit) * UnitHealth(unit)

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](hpPercent, amount)
    end

    return false
end

-- Checks whether or not the given unit has hp vs the given amount
-- unit: The unit we're checking
-- operator: valid comparitive operator symbol
-- amount: The required amount
-- returns: True or false
function CleveRoids.ValidateRawHp(unit, operator, amount)
    if not unit or not operator or not amount then return false end
    local rawhp = UnitHealth(unit)

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](rawhp, amount)
    end

    return false
end

-- Checks whether or not the given unit has an hp deficit vs the amount specified
-- unit: The unit we're checking
-- operator: valid comparitive operator symbol
-- amount: The required amount
-- returns: True or false
function CleveRoids.ValidateHpLost(unit, operator, amount)
    if not unit or not operator or not amount then return false end
    local hpLost = UnitHealthMax(unit) - UnitHealth(unit)

    if CleveRoids.operators[operator] then
        return CleveRoids.comparators[operator](hpLost, amount)
    end

    return false
end

-- Checks whether the given creatureType is the same as the target's creature type
-- creatureType: The type to check
-- target: The target's unitID
-- returns: True or false
-- remarks: Allows for both localized and unlocalized type names
function CleveRoids.ValidateCreatureType(creatureType, target)
    if not target then return false end
    local targetType = UnitCreatureType(target)
    if not targetType then return false end -- ooze or silithid etc
    local ct = string.lower(creatureType)
    local cl = UnitClassification(target)
    if (ct == "boss" and "worldboss" or ct) == cl then
        return true
    end
    if string.lower(creatureType) == "boss" then creatureType = "worldboss" end
    local englishType = CleveRoids.Localized.CreatureTypes[targetType]
    return ct == string.lower(targetType) or creatureType == englishType
end

-- TODO: Look into https://github.com/Stanzilla/WoWUIBugs/issues/47 if needed
function CleveRoids.ValidateCooldown(args, ignoreGCD)
    if not args then return false end
    if type(args) ~= "table" then
        args = {name = args}
    end

    local expires = CleveRoids.GetCooldown(args.name, ignoreGCD)

    if not args.operator and not args.amount then
        return expires > 0
    elseif CleveRoids.operators[args.operator] then
        return CleveRoids.comparators[args.operator](expires - GetTime(), args.amount)
    end
end

function CleveRoids.GetPlayerAura(index, isbuff)
    if not index then return false end

    local buffType = isbuff and "HELPFUL" or "HARMFUL"
    local bid = GetPlayerBuff(index, buffType)
    if bid < 0 then return end

    local spellID = CleveRoids.hasSuperwow and GetPlayerBuffID(bid)

    return GetPlayerBuffTexture(bid), GetPlayerBuffApplications(bid), spellID, GetPlayerBuffTimeLeft(bid)
end

function CleveRoids.ValidateAura(unit, args, isbuff)
    if not args or not UnitExists(unit) then return false end

    if type(args) ~= "table" then
        args = {name = args}
    end

    local isPlayer = (unit == "player")
    local found = false
    local texture, stacks, spellID, remaining
    local i = isPlayer and 0 or 1

    while true do
        if isPlayer then
            texture, stacks, spellID, remaining = CleveRoids.GetPlayerAura(i, isbuff)
        else
            if isbuff then
                texture, stacks, spellID = UnitBuff(unit, i)
            else
                texture, stacks, _, spellID = UnitDebuff(unit, i)
            end
        end

        if (CleveRoids.hasSuperwow and not spellID) or not texture then break end
        if (CleveRoids.hasSuperwow and args.name == SpellInfo(spellID))
            or (not CleveRoids.hasSuperwow and texture == CleveRoids.auraTextures[args.name])
        then
            found = true
            break
        end

        i = i + 1
    end

    local ops = CleveRoids.operators
    if not args.amount and not args.operator and not args.checkStacks then
        return found
    elseif isPlayer and not args.checkStacks and args.amount and ops[args.operator] then
        return CleveRoids.comparators[args.operator](remaining or -1, args.amount)
    elseif args.amount and args.checkStacks and ops[args.operator] then
        return CleveRoids.comparators[args.operator](stacks or -1, args.amount)
    else
        return false
    end
end

function CleveRoids.ValidateUnitBuff(unit, args)
    return CleveRoids.ValidateAura(unit, args, true)
end
function CleveRoids.ValidateUnitDebuff(unit, args)
    return CleveRoids.ValidateAura(unit, args, false)
end

function CleveRoids.ValidatePlayerBuff(args)
    return CleveRoids.ValidateAura("player", args, true)
end

function CleveRoids.ValidatePlayerDebuff(args)
    return CleveRoids.ValidateAura("player", args, false)
end

-- TODO: Look into https://github.com/Stanzilla/WoWUIBugs/issues/47 if needed
function CleveRoids.GetCooldown(name, ignoreGCD)
    
    if not name then return 0 end
    local expires = CleveRoids.GetSpellCooldown(name, ignoreGCD)
    local spell = CleveRoids.GetSpell(name)
    if not spell then expires = CleveRoids.GetItemCooldown(name, ignoreGCD) end

    if expires > GetTime() then
        -- CleveRoids.Cooldowns[name] = expires
        return expires
    end

    return 0
end

-- TODO: Look into https://github.com/Stanzilla/WoWUIBugs/issues/47 if needed
-- Returns the cooldown of the given spellName or nil if no such spell was found
function CleveRoids.GetSpellCooldown(spellName, ignoreGCD)
    if not spellName then return 0 end

    local spell = CleveRoids.GetSpell(spellName)
    if not spell then return 0 end

    local start, cd = GetSpellCooldown(spell.spellSlot, spell.bookType)
    if ignoreGCD and cd and cd > 0 and cd == 1.5 then
        return 0
    else
        return (start + cd)
    end
end

-- TODO: Look into https://github.com/Stanzilla/WoWUIBugs/issues/47 if needed
function CleveRoids.GetItemCooldown(itemName, ignoreGCD)
    if not itemName then return 0 end

    local item = CleveRoids.GetItem(itemName)
    if not item then return 0 end

    local start, cd, expires
    if item.inventoryID then
        start, cd = GetInventoryItemCooldown("player", item.inventoryID)
    elseif item.bagID then
        start, cd = GetContainerItemCooldown(item.bagID, item.slot)
    end

    if ignoreGCD and cd and cd > 0 and cd == 1.5 then
        return 0
    else
        return (start + cd)
    end
end

function CleveRoids.IsReactive(name)
    return CleveRoids.reactiveSpells[spellName] ~= nil
end

function CleveRoids.GetActionButtonInfo(slot)
    local macroName, actionType, id = GetActionText(slot)
    if actionType == "MACRO" then
        return actionType, id, macroName
    elseif actionType == "SPELL" and id then
        local spellName, rank = SpellInfo(id)
        return actionType, id, spellName, rank
    elseif actionType == "ITEM" and id then
        local item = CleveRoids.GetItem(id)
        return actionType, id, (item and item.name), (item and item.id)
    end
end

function CleveRoids.IsReactiveUsable(spellName)
    if not CleveRoids.reactiveSlots[spellName] then return false end
    local actionSlot = CleveRoids.reactiveSlots[spellName]

    local isUsable, oom = IsUsableAction(actionSlot)
    local start, duration = GetActionCooldown(actionSlot)

    if isUsable and (start == 0 or duration == 1.5) then -- 1.5 just means gcd is active
        return 1
    else
        return nil, oom
    end
end

function CleveRoids.CheckSpellCast(unit, spell)
    if not CleveRoids.hasSuperwow then return false end

    local spell = spell or ""
    local _,guid = UnitExists(unit)
    if not guid or (guid and not CleveRoids.spell_tracking[guid]) then
        return false
    else
        -- are we casting a specific spell, or any spell
        if spell == SpellInfo(CleveRoids.spell_tracking[guid].spell_id) or (spell == "") then
            return true
        end
        return false
    end
end

-- A list of Conditionals and their functions to validate them
CleveRoids.Keywords = {
    exists = function(conditionals)
        return UnitExists(conditionals.target)
    end,

    help = function(conditionals)
        return CleveRoids.CheckHelp(conditionals.target, conditionals.help)
    end,

    harm = function(conditionals)
        return CleveRoids.CheckHelp(conditionals.target, conditionals.help)
    end,

    stance = function(conditionals)
        local i = CleveRoids.GetCurrentShapeshiftIndex()
        return Or(conditionals.stance, function (v)
            return (i == tonumber(v))
        end)
    end,

    form = function(conditionals)
        local i = CleveRoids.GetCurrentShapeshiftIndex()
        return Or(conditionals.form, function (v)
            return (i == tonumber(v))
        end)
    end,

    mod = function(conditionals)
        if type(conditionals.mod) ~= "table" then
            return CleveRoids.kmods.mod()
        end
        return Or(conditionals.mod, function(mod)
            return CleveRoids.kmods[mod]()
        end)
    end,

    nomod = function(conditionals)
        if type(conditionals.nomod) ~= "table" then
            return CleveRoids.kmods.nomod()
        end
        return And(conditionals.nomod, function(mod)
            return not CleveRoids.kmods[mod]()
        end)
    end,

    target = function(conditionals)
        return CleveRoids.IsValidTarget(conditionals.target, conditionals.help)
    end,

    combat = function(conditionals)
        return UnitAffectingCombat("player")
    end,

    nocombat = function(conditionals)
        return not UnitAffectingCombat("player")
    end,

    stealth = function(conditionals)
        return (
            (CleveRoids.playerClass == "ROGUE" and CleveRoids.ValidatePlayerBuff(CleveRoids.Localized.Spells["Stealth"]))
            or (CleveRoids.playerClass == "DRUID" and CleveRoids.ValidatePlayerBuff(CleveRoids.Localized.Spells["Prowl"]))
        )
    end,

    nostealth = function(conditionals)
        return (
            (CleveRoids.playerClass == "ROGUE" and not CleveRoids.ValidatePlayerBuff(CleveRoids.Localized.Spells["Stealth"]))
            or (CleveRoids.playerClass == "DRUID" and not CleveRoids.ValidatePlayerBuff(CleveRoids.Localized.Spells["Prowl"]))
        )
    end,

    casting = function(conditionals)
        if type(conditionals.casting) ~= "table" then return CleveRoids.CheckSpellCast(conditionals.target, "") end
        return Or(conditionals.casting, function (spell)
            return CleveRoids.CheckSpellCast(conditionals.target, spell)
        end)
    end,

    nocasting = function(conditionals)
        if type(conditionals.nocasting) ~= "table" then return CleveRoids.CheckSpellCast(conditionals.target, "") end
        return And(conditionals.nocasting, function (spell)
            return not CleveRoids.CheckSpellCast(conditionals.target, spell)
        end)
    end,

    zone = function(conditionals)
        local zone = GetRealZoneText()
        local sub_zone = GetSubZoneText()
        return Or(conditionals.zone, function (v)
            return (sub_zone ~= "" and (v == sub_zone) or (v == zone))
        end)
    end,

    nozone = function(conditionals)
        local zone = GetRealZoneText()
        local sub_zone = GetSubZoneText()
        return And(conditionals.nozone, function (v)
            return not ((sub_zone ~= "" and v == sub_zone)) or (v == zone)
        end)
    end,

    equipped = function(conditionals)
        return Or(conditionals.equipped, function (v)
            return (CleveRoids.HasWeaponEquipped(v) or CleveRoids.HasGearEquipped(v))
        end)
    end,

    noequipped = function(conditionals)
        return And(conditionals.noequipped, function (v)
            return not (CleveRoids.HasWeaponEquipped(v) or CleveRoids.HasGearEquipped(v))
        end)
    end,

    dead = function(conditionals)
        return UnitIsDeadOrGhost(conditionals.target)
    end,

    alive = function(conditionals)
        return not UnitIsDeadOrGhost(conditionals.target)
    end,

    reactive = function(conditionals)
        return Or(conditionals.reactive, function (v)
            return CleveRoids.IsReactiveUsable(v)
        end)
    end,

    noreactive = function(conditionals)
        return And(conditionals.noreactive,function (v)
            return not CleveRoids.IsReactiveUsable(v)
        end)
    end,

    member = function(conditionals)
        return Or(conditionals.member, function(v)
            return
                CleveRoids.IsTargetInGroupType(conditionals.target, "party")
                or CleveRoids.IsTargetInGroupType(conditionals.target, "raid")
        end)
    end,

    party = function(conditionals)
        return CleveRoids.IsTargetInGroupType(conditionals.target, "party")
    end,

    noparty = function(conditionals)
        return not CleveRoids.IsTargetInGroupType(conditionals.target, "party")
    end,

    raid = function(conditionals)
        return CleveRoids.IsTargetInGroupType(conditionals.target, "raid")
    end,

    noraid = function(conditionals)
        return not CleveRoids.IsTargetInGroupType(conditionals.target, "raid")
    end,

    group = function(conditionals)
        if type(conditionals.group) ~= "table" then
            conditionals.group = { "party", "raid" }
        end
        return Or(conditionals.group, function(groups)
            if group == "party" then
                return GetNumPartyMembers() > 0
            elseif group == "raid" then
                return GetNumRaidMembers() > 0
            end
        end)
    end,

    checkchanneled = function(conditionals)
        return Or(conditionals.checkchanneled, function(channeledSpells)
            return CleveRoids.CheckChanneled(channeledSpells)
        end)
    end,

    buff = function(conditionals)
        return Or(conditionals.buff, function(v)
            return CleveRoids.ValidateUnitBuff(conditionals.target, v)
        end)
    end,

    nobuff = function(conditionals)
        return And(conditionals.nobuff, function(v)
            return not CleveRoids.ValidateUnitBuff(conditionals.target, v)
        end)
    end,

    debuff = function(conditionals)
        return Or(conditionals.debuff, function(v)
            return CleveRoids.ValidateUnitDebuff(conditionals.target, v)
        end)
    end,

    nodebuff = function(conditionals)
        return And(conditionals.nodebuff, function(v)
            return not CleveRoids.ValidateUnitDebuff(conditionals.target, v)
        end)
    end,

    mybuff = function(conditionals)
        return Or(conditionals.mybuff, function(v)
            return CleveRoids.ValidatePlayerBuff(v)
        end)
    end,

    nomybuff = function(conditionals)
        return And(conditionals.nomybuff, function(v)
            return not CleveRoids.ValidatePlayerBuff(v)
        end)
    end,

    mydebuff = function(conditionals)
        return Or(conditionals.mydebuff, function(v)
            return CleveRoids.ValidatePlayerDebuff(v)
        end)
    end,

    nomydebuff = function(conditionals)
        return And(conditionals.nomydebuff, function(v)
            return not CleveRoids.ValidatePlayerDebuff(v)
        end)
    end,

    power = function(conditionals)
        return And(conditionals.power, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidatePower(conditionals.target, args.operator, args.amount)
        end)
    end,

    mypower = function(conditionals)
        return And(conditionals.mypower, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidatePower("player", args.operator, args.amount)
        end)
    end,

    rawpower = function(conditionals)
        return And(conditionals.rawpower, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateRawPower(conditionals.target, args.operator, args.amount)
        end)
    end,

    myrawpower = function(conditionals)
        return And(conditionals.myrawpower, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateRawPower("player", args.operator, args.amount)
        end)
    end,

    powerlost = function(conditionals)
        return And(conditionals.powerlost, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidatePowerLost(conditionals.target, args.operator, args.amount)
        end)
    end,

    mypowerlost = function(conditionals)
        return And(conditionals.mypowerlost, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidatePowerLost("player", args.operator, args.amount)
        end)
    end,

    hp = function(conditionals)
        return And(conditionals.hp, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateHp(conditionals.target, args.operator, args.amount)
        end)
    end,

    myhp = function(conditionals)
        return And(conditionals.myhp, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateHp("player", args.operator, args.amount)
        end)
    end,

    rawhp = function(conditionals)
        return And(conditionals.rawphp, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateRawHp(conditionals.target, args.operator, args.amount)
        end)
    end,

    myrawhp = function(conditionals)
        return And(conditionals.myrawhp, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateRawHp("player", args.operator, args.amount)
        end)
    end,

    hplost = function(conditionals)
        return And(conditionals.hplost, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateHpLost(conditionals.target, args.operator, args.amount)
        end)
    end,

    myhplost = function(conditionals)
        return And(conditionals.myhplost, function(args)
            if type(args) ~= "table" then return false end
            return CleveRoids.ValidateHpLost("player", args.operator, args.amount)
        end)
    end,

    type = function(conditionals)
        return Or(conditionals.type, function(unittype)
            return CleveRoids.ValidateCreatureType(unittype, conditionals.target)
        end)
    end,

    notype = function(conditionals)
        return And(conditionals.type, function(unittype)
            return not CleveRoids.ValidateCreatureType(unittype, conditionals.target)
        end)
    end,

    cooldown = function(conditionals)
        return Or(conditionals.cooldown,function (v)
            return CleveRoids.ValidateCooldown(v, true)
        end)
    end,

    nocooldown = function(conditionals)
        return And(conditionals.nocooldown,function (v)
            return not CleveRoids.ValidateCooldown(v, true)
        end)
    end,

    cdgcd = function(conditionals)
        return Or(conditionals.cdgcd,function (v)
            return CleveRoids.ValidateCooldown(v, false)
        end)
    end,

    nocdgcd = function(conditionals)
        return And(conditionals.nocdgcd,function (v)
            return not CleveRoids.ValidateCooldown(v, false)
        end)
    end,

    channeled = function(conditionals)
        return CleveRoids.CurrentSpell.type == "channeled"
    end,

    nochanneled = function(conditionals)
        return CleveRoids.CurrentSpell.type ~= "channeled"
    end,

    targeting = function(conditionals)
        return And(conditionals.targeting, function (unit)
            return (UnitIsUnit("targettarget", unit) == 1)
        end)
    end,

    notargeting = function(conditionals)
        return And(conditionals.notargeting, function (unit)
            return UnitIsUnit("targettarget", unit) ~= 1
        end)
    end,

    isplayer = function(conditionals)
        return UnitIsPlayer(conditionals.target)
    end,

    isnpc = function(conditionals)
        return not UnitIsPlayer(conditionals.target)
    end,

    inrange = function(conditionals)
        if not IsSpellInRange then return end
        return Or(conditionals.inrange, function(spellName)
            return IsSpellInRange(spellName or conditionals.action, conditionals.target) == 1
        end)
    end,

    noinrange = function(conditionals)
        if not IsSpellInRange then return end
        return And(conditionals.inrange, function(spellName)
            return IsSpellInRange(spellName or conditionals.action, conditionals.target) == 0
        end)
    end,

    combo = function(conditionals)
        return Or(conditionals.combo, function(args)
            return CleveRoids.ValidateComboPoints(args.operator, args.amount)
        end)
    end,

    nocombo = function(conditionals)
        return And(conditionals.nocombo, function(args)
            return CleveRoids.ValidateComboPoints(args.operator, args.amount)
        end)
    end,

    known = function(conditionals)
        return Or(conditionals.known, function(args)
            return CleveRoids.ValidateKnown(args)
        end)
    end,

    noknown = function(conditionals)
        return And(conditionals.noknown, function(args)
            return not CleveRoids.ValidateKnown(args)
        end)
    end,

    resting = function()
        return IsResting() == 1
    end,

    noresting = function()
        return IsResting() == nil
    end,
}
