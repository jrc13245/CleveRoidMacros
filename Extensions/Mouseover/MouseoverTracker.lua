--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
local Extension = CleveRoids.RegisterExtension("MouseoverTracker")

function Extension.OnUnitEnterFrame()
    if CleveRoids.hasSuperwow and SetMouseoverUnit then
        SetMouseoverUnit(this:GetAttribute("unit"))
    end
end

function Extension.OnUnitLeaveFrame()
    if CleveRoids.hasSuperwow and SetMouseoverUnit then
        SetMouseoverUnit()
    end
end

function Extension.OnLoad()
    if not CleveRoids.hasSuperwow or not SetMouseoverUnit then
        return
    end

    -- This single script handles the OnEnter event for all unit frames.
    local on_enter_script = function()
        local unit = this:GetAttribute("unit")

        -- Use the unit from the attribute if it's a valid, existing unit.
        if unit and UnitExists(unit) then
            SetMouseoverUnit(unit)
        end
    end

    local on_leave_script = function()
        SetMouseoverUnit()
    end

    -- Attach the unified scripts to all known unit frames, excluding the PlayerFrame.
    TargetFrame:SetScript("OnEnter", on_enter_script)
    TargetFrame:SetScript("OnLeave", on_leave_script)

    for i = 1, 4 do
        local partyFrame = _G["PartyMemberFrame"..i]
        if partyFrame then
            partyFrame:SetScript("OnEnter", on_enter_script)
            partyFrame:SetScript("OnLeave", on_leave_script)
        end
    end

    for i = 1, 40 do
        local raidFrame = _G["RaidFrame"..i]
        if raidFrame then
            raidFrame:SetScript("OnEnter", on_enter_script)
            raidFrame:SetScript("OnLeave", on_leave_script)
        end
    end
end

_G["CleveRoids"] = CleveRoids
