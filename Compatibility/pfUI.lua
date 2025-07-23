local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

local Extension = CleveRoids.RegisterExtension("Compatibility_pfUI")

-- This function becomes the new GetFocusName.
-- It prioritizes pfUI's focus data and falls back to the original function if not found.
function Extension.FocusNameHook()
    if pfUI and pfUI.uf and pfUI.uf.focus and pfUI.uf.focus.unitname then
        return pfUI.uf.focus.unitname --
    end

    -- If pfUI focus doesn't exist, call the original GetFocusName for other focus addons
    local hook = Extension.internal.memberHooks[CleveRoids]["GetFocusName"] --
    if hook and hook.original then
        return hook.original() --
    end
end

-- This is the "pfUI Focus Fix" logic, moved from Core.lua.
-- It hooks the /pffocus slash command to determine the exact UnitID of the focused player.
function Extension.ApplyFocusUnitIDHook()
    -- Ensure both pfUI and its focus module are loaded before attempting to hook.
    if pfUI and pfUI.uf and pfUI.uf.focus and SlashCmdList.PFFOCUS then
        local original_PFFOCUS_Handler = SlashCmdList.PFFOCUS
        SlashCmdList.PFFOCUS = function(msg)
            -- First, execute the original /focus command from pfUI to set the unit name.
            original_PFFOCUS_Handler(msg)

            -- Now, if a focus name was set, find the corresponding UnitID.
            if pfUI.uf.focus.unitname then
                local focusName = string.lower(pfUI.uf.focus.unitname)
                local found_label, found_id = nil, nil

                -- This function iterates through all known friendly units to find a
                -- name match and return its specific UnitID components.
                local function findUnitID()
                    -- Check party members and their pets
                    for i = 1, GetNumPartyMembers() do
                        if string.lower(UnitName("party"..i) or "") == focusName then return "party", i end
                        if UnitExists("partypet"..i) and string.lower(UnitName("partypet"..i) or "") == focusName then return "partypet", i end
                    end

                    -- Check raid members and their pets
                    for i = 1, GetNumRaidMembers() do
                        if string.lower(UnitName("raid"..i) or "") == focusName then return "raid", i end
                        if UnitExists("raidpet"..i) and string.lower(UnitName("raidpet"..i) or "") == focusName then return "raidpet", i end
                    end

                    -- Check player and pet
                    if string.lower(UnitName("player") or "") == focusName then return "player", nil end
                    if UnitExists("pet") and string.lower(UnitName("pet") or "") == focusName then return "pet", nil end

                    return nil, nil
                end

                found_label, found_id = findUnitID()

                -- Store the found label and ID. CleveRoids' Core.lua will use this
                -- for a direct, reliable cast without needing to change your target.
                pfUI.uf.focus.label = found_label
                pfUI.uf.focus.id = found_id
            else
                -- Focus was cleared (e.g., via /clearfocus), so ensure our cached data is cleared too.
                pfUI.uf.focus.label = nil
                pfUI.uf.focus.id = nil
            end
        end
    end
end

function Extension.OnLoad()
    if _G["pfUI"] then
        -- Hook the GetFocusName function to add pfUI support. The 'true' flag replaces the original function.
        Extension.HookMethod(CleveRoids, "GetFocusName", "FocusNameHook", true) --

        -- Apply the more advanced hook for determining the focus UnitID.
        Extension.ApplyFocusUnitIDHook()
    end
end

-- We wait until the player is fully in the world to ensure pfUI has been loaded and initialized.
Extension.internal.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
function Extension.internal.OnEvent()
    if event == "PLAYER_ENTERING_WORLD" then
        Extension.OnLoad()
        Extension.internal.frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

_G["CleveRoids"] = CleveRoids
