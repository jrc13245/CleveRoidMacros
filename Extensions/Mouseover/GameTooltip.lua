--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
CleveRoids.mouseoverUnit = CleveRoids.mouseoverUnit or nil

local Extension = CleveRoids.RegisterExtension("BlizzardPartyFrame")

function Extension.SetUnit(_, unit)
    CleveRoids.mouseoverUnit = unit
end


function Extension.OnClose()
    CleveRoids.mouseoverUnit = nil
end

function Extension.OnLoad()
    Extension.HookMethod(_G["GameTooltip"], "SetUnit", "SetUnit")
    Extension.HookMethod(_G["GameTooltip"], "Hide", "OnClose")
    Extension.HookMethod(_G["GameTooltip"], "FadeOut", "OnClose")
end

_G["CleveRoids"] = CleveRoids