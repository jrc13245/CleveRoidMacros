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
    -- This frame is just for holding the event handlers. We'll attach the scripts to a temporary frame.
    local tempFrame = CreateFrame("Frame")
    tempFrame:SetScript("OnEnter", Extension.OnUnitEnterFrame)
    tempFrame:SetScript("OnLeave", Extension.OnUnitLeaveFrame)
end

_G["CleveRoids"] = CleveRoids
