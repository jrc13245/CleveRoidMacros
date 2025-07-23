--[[
	Author: Fondlez
	This extension has been updated to use SuperWoW's native SetMouseoverUnit()
    for robust mouseover support on default Blizzard frames.
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

local Extension = CleveRoids.RegisterExtension("Blizzard")

function Extension.RegisterMouseoverForFrame(frame, unit)
    if not frame then return end

    local onenter = frame:GetScript("OnEnter")
    local onleave = frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function()
        -- Use SuperWoW's function to set the game's mouseover unit
        if SetMouseoverUnit then SetMouseoverUnit(unit) end
        if onenter then onenter() end
    end)

    frame:SetScript("OnLeave", function()
        -- Use SuperWoW's function to clear the game's mouseover unit
        if SetMouseoverUnit then SetMouseoverUnit() end
        if onleave then onleave() end
    end)
end

do
    local frames = {
        ["PlayerFrame"] = "player",
        ["PetFrame"] = "pet",
        ["TargetFrame"] = "target",
        ["PartyMemberFrame1"] = "party1",
        ["PartyMemberFrame2"] = "party2",
        ["PartyMemberFrame3"] = "party3",
        ["PartyMemberFrame4"] = "party4",
        ["PartyMemberFrame1PetFrame"] = "party1pet", -- Corrected unit
        ["PartyMemberFrame2PetFrame"] = "party2pet", -- Corrected unit
        ["PartyMemberFrame3PetFrame"] = "party3pet", -- Corrected unit
        ["PartyMemberFrame4PetFrame"] = "party4pet", -- Corrected unit
    }

    local bars = {
        "HealthBar",
        "ManaBar",
    }

    local allFrames = {}
    for name, unit in pairs(frames) do
         allFrames[name] = unit
        for i, bar in ipairs(bars) do
            allFrames[name .. bar] = unit
        end
    end

    -- Inconsisent naming for TargetofTarget required
    allFrames["TargetofTargetFrame"] = "targettarget"
    allFrames["TargetofTargetHealthBar"] = "targettarget"
    allFrames["TargetofTargetManaBar"] = "targettarget"

    function Extension.OnLoad()
        local frame
        for name, unit in pairs(allFrames) do
          frame = _G[name]

          if frame then
              Extension.RegisterMouseoverForFrame(frame, unit)
          end
       end
    end
end
