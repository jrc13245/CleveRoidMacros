--[[
	Author: Fondlez

    This extension adds improved support for mouseover macros in Roid-Macros
    for the default Blizzard frames.
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
CleveRoids.mouseoverUnit = CleveRoids.mouseoverUnit or nil

local Extension = CleveRoids.RegisterExtension("Blizzard")

function Extension.RegisterMouseoverForFrame(frame, unit)
    if not frame then return end

    local onenter = frame:GetScript("OnEnter")
    local onleave = frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function()
        CleveRoids.mouseoverUnit = unit
         CleveRoids.QueueActionUpdate()
        if onenter then
            onenter()
        end
    end)

    frame:SetScript("OnLeave", function()
        CleveRoids.mouseoverUnit = nil
        CleveRoids.QueueActionUpdate()
        if onleave then
            onleave()
        end
    end)
end

local function SafeHookFrameMouseover(frame, unit, onenter, onleave)
    if not frame or frame._cleveroid_mouseover_hooked then return end
    frame._cleveroid_mouseover_hooked = true

    frame:SetScript("OnEnter", function()
        CleveRoids.mouseoverUnit = unit
        CleveRoids.QueueActionUpdate()
        if onenter then onenter() end
    end)
    frame:SetScript("OnLeave", function()
        if CleveRoids.mouseoverUnit == unit then
            CleveRoids.mouseoverUnit = nil
            CleveRoids.QueueActionUpdate()
        end
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
        ["PartyMemberFrame1PetFrame"] = "party1",
        ["PartyMemberFrame2PetFrame"] = "party2",
        ["PartyMemberFrame3PetFrame"] = "party3",
        ["PartyMemberFrame4PetFrame"] = "party4",
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
