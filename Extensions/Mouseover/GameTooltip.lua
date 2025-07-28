--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
local Extension = CleveRoids.RegisterExtension("GameTooltipMouseover")

function Extension.SetUnit(_, unit)
	-- When GameTooltip is shown for a unit, set the game's mouseover
	if CleveRoids.hasSuperwow and SetMouseoverUnit then
		SetMouseoverUnit(unit)
	else 
		CleveRoids.mouseoverUnit = unit
	end
end

function Extension.OnClose()
	-- When GameTooltip is hidden, clear the game's mouseover
	if CleveRoids.hasSuperwow and SetMouseoverUnit then
		SetMouseoverUnit()
	else 
		CleveRoids.mouseoverUnit = unit
	end
end	

function Extension.OnLoad()
	Extension.HookMethod(_G["GameTooltip"], "SetUnit", "SetUnit")
	Extension.HookMethod(_G["GameTooltip"], "Hide", "OnClose")
	Extension.HookMethod(_G["GameTooltip"], "FadeOut", "OnClose")
end

_G["CleveRoids"] = CleveRoids
