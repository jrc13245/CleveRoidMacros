--[[
	CleveRoidsMacros - pfUI Compatibility File (Final Version with 1.12.1 Fix)
	This file replaces the /focus command, hijacks [@focus] macro execution,
	and uses a 1.12.1-compatible method to restore the original target state.
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

-- Do not run if pfUI or CleveRoids are missing
if not pfUI or not CleveRoids then return end

local Extension = CleveRoids.RegisterExtension("Compatibility_pfUI")
Extension.RegisterEvent("PLAYER_LOGIN", "OnLoad")

--------------------------------
-- EVENT HANDLER FOR TARGET SWAP (1.12.1 CORRECTED)
--------------------------------

-- This function now uses our saved boolean to restore the exact previous state.
function Extension.OnUnitCastEvent(caster, target, action, spell_id, cast_time)
    if not CleveRoids.focusRetargetNeeded or caster ~= CleveRoids.playerGuid then
        return
    end

    if action == "CAST" or action == "FAIL" or action == "INTERRUPTED" then
        -- If we had a target before, use TargetLastTarget.
        if CleveRoids.focusHadOriginalTarget then
            TargetLastTarget() --
        else
            -- If we had no target before, explicitly clear the current target.
            ClearTarget() --
        end

        -- Clean up our state variables so this doesn't run again.
        CleveRoids.focusRetargetNeeded = nil
        CleveRoids.focusHadOriginalTarget = nil
    end
end

--------------------------------
-- THE [@focus] HIJACK HOOK (1.12.1 CORRECTED)
--------------------------------

-- This hook now saves a simple boolean about the original target's existence.
function Extension.DoWithConditionals_Hook(msg, hook, fixEmptyTargetFunc, targetBeforeAction, action)
    local spellName, conditionals = CleveRoids.GetParsedMsg(msg)

    if not conditionals or conditionals.target ~= "focus" then
        return Extension.internal.memberHooks[CleveRoids]["DoWithConditionals"].origininal(msg, hook, fixEmptyTargetFunc, targetBeforeAction, action)
    end

    -- ** CORRECTION: Save whether a target exists *before* we change targets.
    -- UnitExists() is fully compatible with 1.12.1.
    CleveRoids.focusHadOriginalTarget = UnitExists("target")

    -- 1. Find and target the focus.
    local focusUnit = nil
    if pfUI and pfUI.uf and pfUI.uf.focus and pfUI.uf.focus.label and pfUI.uf.focus.id then
        local focusUnitId = pfUI.uf.focus.label .. pfUI.uf.focus.id
        if UnitExists(focusUnitId) then
            focusUnit = focusUnitId
        end
    end

    if not focusUnit and pfUI.uf.focus.unitname then
        TargetByName(pfUI.uf.focus.unitname, true)
        if UnitExists("target") and strlower(UnitName("target")) == strlower(pfUI.uf.focus.unitname) then
            focusUnit = "target"
        end
    end

    if not focusUnit then
        UIErrorsFrame:AddMessage(SPELL_FAILED_BAD_TARGETS, 1.0, 0.0, 0.0, 1.0)
        return false
    end

    TargetUnit(focusUnit) --
    conditionals.target = "target"

    -- 2. Check other conditionals.
    for k, v in pairs(conditionals) do
        if k ~= "target" and not CleveRoids.ignoreKeywords[k] then
            if not CleveRoids.Keywords[k] or not CleveRoids.Keywords[k](conditionals) then
                return false
            end
        end
    end

    -- 3. All conditions passed. Cast the spell.
    action(spellName)

    -- 4. Set the flag to tell our event handler to swap the target back.
    CleveRoids.focusRetargetNeeded = true

    return true
end

--------------------------------
-- The /focus Command Replacement
--------------------------------

function Extension.New_PFFOCUS_Handler(msg)
    if not (pfUI and pfUI.uf and pfUI.uf.focus) then return end
    local focusTargetName = nil
    local cleanMsg = msg and CleveRoids.Trim(msg) or ""
    if cleanMsg ~= "" then
        focusTargetName = cleanMsg
    elseif UnitExists("target") then
        focusTargetName = UnitName("target")
    end
    if focusTargetName then
        pfUI.uf.focus.unitname = strlower(focusTargetName)
        local focusName = pfUI.uf.focus.unitname
        local found_label, found_id = nil, nil
        local function findUnitID()
            for i=1, GetNumPartyMembers() do if strlower(UnitName("party"..i))==focusName then return"party",i end end
            for i=1, GetNumRaidMembers() do if strlower(UnitName("raid"..i))==focusName then return"raid",i end end
            if strlower(UnitName("player"))==focusName then return"player","" end
            if UnitExists("pet") and strlower(UnitName("pet"))==focusName then return"pet","" end
            return nil,nil
        end
        found_label, found_id = findUnitID()
        pfUI.uf.focus.label = found_label
        pfUI.uf.focus.id = found_id
    else
        pfUI.uf.focus.unitname, pfUI.uf.focus.label, pfUI.uf.focus.id = nil, nil, nil
    end
end

--------------------------------
-- INITIALIZATION
--------------------------------

function Extension.OnLoad()
    Extension.HookMethod(CleveRoids, "DoWithConditionals", "DoWithConditionals_Hook")

    if SlashCmdList and SlashCmdList.PFFOCUS then
        SlashCmdList.PFFOCUS = Extension.New_PFFOCUS_Handler
    end

    Extension.RegisterEvent("UNIT_CASTEVENT", "OnUnitCastEvent")
    Extension.UnregisterEvent("PLAYER_LOGIN", "OnLoad")
end
