--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License

	This file has been updated to fix a 'nil self' error by using
    the 'this' keyword to correctly reference the script's frame.
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

CleveRoids.mouseoverUnit = CleveRoids.mouseoverUnit or nil

local Extension = CleveRoids.RegisterExtension("pfUI")
Extension.RegisterEvent("PLAYER_ENTERING_WORLD", "PLAYER_ENTERING_WORLD")

function Extension.OnLoad()
end

function Extension.RegisterPlayerScripts()
    if not pfUI.uf.player then return end
    local onEnterFunc = pfUI.uf.player:GetScript("OnEnter")
    local onLeaveFunc = pfUI.uf.player:GetScript("OnLeave")

    pfUI.uf.player:SetScript("OnEnter", function()
        CleveRoids.mouseoverUnit = "player"
        if onEnterFunc then onEnterFunc(this) end
    end)

    pfUI.uf.player:SetScript("OnLeave", function()
        if CleveRoids.mouseoverUnit == "player" then CleveRoids.mouseoverUnit = nil end
        if onLeaveFunc then onLeaveFunc(this) end
    end)
end

function Extension.RegisterTargetScripts()
    if not pfUI.uf.target then return end
    local onEnterFunc = pfUI.uf.target:GetScript("OnEnter")
    local onLeaveFunc = pfUI.uf.target:GetScript("OnLeave")

    pfUI.uf.target:SetScript("OnEnter", function()
        CleveRoids.mouseoverUnit = "target"
        if onEnterFunc then onEnterFunc(this) end
    end)

    pfUI.uf.target:SetScript("OnLeave", function()
        if CleveRoids.mouseoverUnit == "target" then CleveRoids.mouseoverUnit = nil end
        if onLeaveFunc then onLeaveFunc(this) end
    end)
end

function Extension.RegisterTargetTargetScripts()
    if not pfUI.uf.targettarget then return end
    local onEnterFunc = pfUI.uf.targettarget:GetScript("OnEnter")
    local onLeaveFunc = pfUI.uf.targettarget:GetScript("OnLeave")

    pfUI.uf.targettarget:SetScript("OnEnter", function()
        CleveRoids.mouseoverUnit = "targettarget"
        if onEnterFunc then onEnterFunc(this) end
    end)

    pfUI.uf.targettarget:SetScript("OnLeave", function()
        if CleveRoids.mouseoverUnit == "targettarget" then CleveRoids.mouseoverUnit = nil end
        if onLeaveFunc then onLeaveFunc(this) end
    end)
end

function Extension.RegisterPartyScripts()
    if not pfUI.uf.group then return end

    -- Loop from 0 to 4 to cover player-in-party and all party members
    for i = 0, 4 do
        local frame = pfUI.uf.group[i]
        if frame then
            local onEnterFunc = frame:GetScript("OnEnter")
            local onLeaveFunc = frame:GetScript("OnLeave")

            frame:SetScript("OnEnter", function()
                if this.unit then
                    CleveRoids.mouseoverUnit = this.unit
                end
                if onEnterFunc then onEnterFunc(this) end
            end)

            frame:SetScript("OnLeave", function()
                if this.unit and CleveRoids.mouseoverUnit == this.unit then
                    CleveRoids.mouseoverUnit = nil
                end
                if onLeaveFunc then onLeaveFunc(this) end
            end)
        end
    end
end

function Extension.RegisterRaidScripts()
    if not pfUI.uf.raid then return end

    -- Loop to the maximum possible raid size (40) and safely check if a frame exists.
    for i = 1, 40 do
        local frame = pfUI.uf.raid[i]
        if frame then
            local onEnterFunc = frame:GetScript("OnEnter")
            local onLeaveFunc = frame:GetScript("OnLeave")

            frame:SetScript("OnEnter", function()
                -- Check if the frame has a valid unit assigned before setting
                if this.unit and this.unit ~= "" and UnitExists(this.unit) then
                    CleveRoids.mouseoverUnit = this.unit
                end
                if onEnterFunc then onEnterFunc(this) end
            end)

            frame:SetScript("OnLeave", function()
                if this.unit and CleveRoids.mouseoverUnit == this.unit then
                    CleveRoids.mouseoverUnit = nil
                end
                if onLeaveFunc then onLeaveFunc(this) end
            end)
        end
    end
end

local function SafeHookFrameMouseover(frame, unit, onenter, onleave)
    if not frame or frame._cleveroid_mouseover_hooked then return end
    frame._cleveroid_mouseover_hooked = true

    frame:SetScript("OnEnter", function()
        CleveRoids.mouseoverUnit = unit
        if onenter then onenter() end
    end)
    frame:SetScript("OnLeave", function()
        if CleveRoids.mouseoverUnit == unit then
            CleveRoids.mouseoverUnit = nil
        end
        if onleave then onleave() end
    end)
end


function Extension.PLAYER_ENTERING_WORLD()
    if not pfUI or not pfUI.uf then
        return
    end
    Extension.RegisterPlayerScripts()
    Extension.RegisterTargetScripts()
    Extension.RegisterTargetTargetScripts()
    Extension.RegisterPartyScripts()
    Extension.RegisterRaidScripts()
end
