--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

SLASH_PETATTACK1 = "/petattack"

SlashCmdList.PETATTACK = function(msg) CleveRoids.DoPetAttack(msg); end

SLASH_RELOAD1 = "/rl"

SlashCmdList.RELOAD = function() ReloadUI(); end

SLASH_USE1 = "/use"

SlashCmdList.USE = CleveRoids.DoUse

SLASH_EQUIP1 = "/equip"

SlashCmdList.EQUIP = CleveRoids.DoUse
-- take back supermacro and pfUI /equip
SlashCmdList.SMEQUIP = CleveRoids.DoUse
SlashCmdList.PFEQUIP = CleveRoids.DoUse

SLASH_EQUIPMH1 = "/equipmh"
SlashCmdList.EQUIPMH = CleveRoids.DoEquipMainhand

SLASH_EQUIPOH1 = "/equipoh"
SlashCmdList.EQUIPOH = CleveRoids.DoEquipOffhand

SLASH_UNSHIFT1 = "/unshift"

SlashCmdList.UNSHIFT = CleveRoids.DoUnshift

-- TODO make this conditional too
SLASH_CANCELAURA1 = "/cancelaura"
SLASH_CANCELAURA2 = "/unbuff"

SlashCmdList.CANCELAURA = CleveRoids.DoConditionalCancelAura

SLASH_STARTATTACK1 = "/startattack"

SlashCmdList.STARTATTACK = function(msg)
    CleveRoids.DoStartAttack(msg or "")
end

SLASH_STOPATTACK1 = "/stopattack"

SlashCmdList.STOPATTACK = function(msg)
    CleveRoids.DoStopAttack(msg or "")
end

SLASH_STOPCASTING1 = "/stopcasting"

SlashCmdList.STOPCASTING = function(msg)
    CleveRoids.DoStopCasting(msg or "")
end

SlashCmdList.CAST = CleveRoids.CAST_SlashCmd

CleveRoids.Hooks.TARGET_SlashCmd = SlashCmdList.TARGET
CleveRoids.TARGET_SlashCmd = function(msg)
    tmsg = CleveRoids.Trim(msg)

    if tmsg ~= "" and not string.find(tmsg, "%[") and not string.find(tmsg, "@") then
        CleveRoids.Hooks.TARGET_SlashCmd(tmsg)
        return
    end

    if CleveRoids.DoTarget(tmsg) then
        if UnitExists("target") then
            return
        end
    end
    CleveRoids.Hooks.TARGET_SlashCmd(msg)
end
SlashCmdList.TARGET = CleveRoids.TARGET_SlashCmd


SLASH_CASTSEQUENCE1 = "/castsequence"
SlashCmdList.CASTSEQUENCE = function(msg)
    msg = CleveRoids.Trim(msg)
    local sequence = CleveRoids.GetSequence(msg)
    if not sequence then return end
    -- if not sequence.active then return end

    CleveRoids.DoCastSequence(sequence)
end


SLASH_RUNMACRO1 = "/runmacro"
SlashCmdList.RUNMACRO = function(msg)
    return CleveRoids.ExecuteMacroByName(CleveRoids.Trim(msg))
end

SLASH_RETARGET1 = "/retarget"
SlashCmdList.RETARGET = function(msg)
    CleveRoids.DoRetarget()
end

SLASH_STOPMACRO1 = "/stopmacro"
SlashCmdList.STOPMACRO = function(msg)
    CleveRoids.DoStopMacro(msg)
end