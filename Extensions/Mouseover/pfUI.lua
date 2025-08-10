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

-- PLAYER
function Extension.RegisterPlayerScripts()
  if not pfUI or not pfUI.uf or not pfUI.uf.player then return end
  local frame = pfUI.uf.player
  local onEnterFunc = frame:GetScript("OnEnter")
  local onLeaveFunc = frame:GetScript("OnLeave")

  frame:SetScript("OnEnter", function()
    CleveRoids.SetMouseoverFrom("pfui", "player")
    if onEnterFunc then onEnterFunc(this) end
  end)

  frame:SetScript("OnLeave", function()
    CleveRoids.ClearMouseoverFrom("pfui", "player")
    if onLeaveFunc then onLeaveFunc(this) end
  end)
end

-- TARGET
function Extension.RegisterTargetScripts()
  if not pfUI or not pfUI.uf or not pfUI.uf.target then return end
  local frame = pfUI.uf.target
  local onEnterFunc = frame:GetScript("OnEnter")
  local onLeaveFunc = frame:GetScript("OnLeave")

  frame:SetScript("OnEnter", function()
    CleveRoids.SetMouseoverFrom("pfui", "target")
    if onEnterFunc then onEnterFunc(this) end
  end)

  frame:SetScript("OnLeave", function()
    CleveRoids.ClearMouseoverFrom("pfui", "target")
    if onLeaveFunc then onLeaveFunc(this) end
  end)
end

-- TARGETTARGET
function Extension.RegisterTargetTargetScripts()
  if not pfUI or not pfUI.uf or not pfUI.uf.targettarget then return end
  local frame = pfUI.uf.targettarget
  local onEnterFunc = frame:GetScript("OnEnter")
  local onLeaveFunc = frame:GetScript("OnLeave")

  frame:SetScript("OnEnter", function()
    CleveRoids.SetMouseoverFrom("pfui", "targettarget")
    if onEnterFunc then onEnterFunc(this) end
  end)

  frame:SetScript("OnLeave", function()
    CleveRoids.ClearMouseoverFrom("pfui", "targettarget")
    if onLeaveFunc then onLeaveFunc(this) end
  end)
end

-- PARTY (covers pfUI.uf.group[0..4])
function Extension.RegisterPartyScripts()
  if not pfUI or not pfUI.uf or not pfUI.uf.group then return end

  for i = 0, 4 do
    local frame = pfUI.uf.group[i]
    if frame then
      local onEnterFunc = frame:GetScript("OnEnter")
      local onLeaveFunc = frame:GetScript("OnLeave")

      frame:SetScript("OnEnter", function()
        if this.unit and this.unit ~= "" then
          CleveRoids.SetMouseoverFrom("pfui", this.unit)
        end
        if onEnterFunc then onEnterFunc(this) end
      end)

      frame:SetScript("OnLeave", function()
        if this.unit and this.unit ~= "" then
          CleveRoids.ClearMouseoverFrom("pfui", this.unit)
        end
        if onLeaveFunc then onLeaveFunc(this) end
      end)
    end
  end
end

-- RAID (covers pfUI.uf.raid[1..40])
function Extension.RegisterRaidScripts()
  if not pfUI or not pfUI.uf or not pfUI.uf.raid then return end

  for i = 1, 40 do
    local frame = pfUI.uf.raid[i]
    if frame then
      local onEnterFunc = frame:GetScript("OnEnter")
      local onLeaveFunc = frame:GetScript("OnLeave")

      frame:SetScript("OnEnter", function()
        if this.unit and this.unit ~= "" then
          CleveRoids.SetMouseoverFrom("pfui", this.unit)
        end
        if onEnterFunc then onEnterFunc(this) end
      end)

      frame:SetScript("OnLeave", function()
        if this.unit and this.unit ~= "" then
          CleveRoids.ClearMouseoverFrom("pfui", this.unit)
        end
        if onLeaveFunc then onLeaveFunc(this) end
      end)
    end
  end
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
