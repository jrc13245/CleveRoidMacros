--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
local Extension = CleveRoids.RegisterExtension("GameTooltipMouseover")

function Extension.SetUnit(_, unit)
-- Just store the unit, don't change mouseover state
CleveRoids.mouseoverUnit = unit
end

function Extension.OnClose()
-- Clear stored mouseover when tooltip closes
CleveRoids.mouseoverUnit = nil
end

function Extension.OnLoad()
Extension.HookMethod(GameTooltip, "SetUnit", "SetUnit")
Extension.HookMethod(GameTooltip, "Hide", "OnClose")
Extension.HookMethod(GameTooltip, "FadeOut", "OnClose")
end


_G["CleveRoids"] = CleveRoids
