--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License

	This file has been updated to use SuperWoW's native SetMouseoverUnit()
    for robust mouseover support on pfUI unit frames.
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

local Extension = CleveRoids.RegisterExtension("pfUI")
Extension.RegisterEvent("PLAYER_ENTERING_WORLD", "PLAYER_ENTERING_WORLD")

function Extension.OnLoad()
end

local function RegisterPfUIFrame(frame)
    if not frame then return end

    local onEnterFunc = frame:GetScript("OnEnter")
    local onLeaveFunc = frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function()
        -- Use SuperWoW's function to set the game's mouseover unit
        if SetMouseoverUnit and this.unit and this.unit ~= "" and UnitExists(this.unit) then
            SetMouseoverUnit(this.unit)
        end
        if onEnterFunc then onEnterFunc(this) end
    end)

    frame:SetScript("OnLeave", function()
        -- Use SuperWoW's function to clear the game's mouseover unit
        if SetMouseoverUnit then
            SetMouseoverUnit()
        end
        if onLeaveFunc then onLeaveFunc(this) end
    end)
end

function Extension.RegisterScripts()
    -- Player, Target, and Target's Target
    if pfUI.uf.player then RegisterPfUIFrame(pfUI.uf.player) end
    if pfUI.uf.target then RegisterPfUIFrame(pfUI.uf.target) end
    if pfUI.uf.targettarget then RegisterPfUIFrame(pfUI.uf.targettarget) end

    -- Party Frames
    if pfUI.uf.group then
        for i = 0, 4 do
            if pfUI.uf.group[i] then RegisterPfUIFrame(pfUI.uf.group[i]) end
        end
    end

    -- Raid Frames
    if pfUI.uf.raid then
        for i = 1, 40 do
            if pfUI.uf.raid[i] then RegisterPfUIFrame(pfUI.uf.raid[i]) end
        end
    end
end

function Extension.PLAYER_ENTERING_WORLD()
    if not pfUI or not pfUI.uf then
        return
    end
    Extension.RegisterScripts()
end
