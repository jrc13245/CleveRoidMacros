local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

local Extension = CleveRoids.RegisterExtension("Compatibility_pfUI")
Extension.RegisterEvent("ADDON_LOADED", "OnLoad")
Extension.Debug = false

function Extension.RunMacro(name)
    CleveRoids.ExecuteMacroByName(name)
end

function Extension.DLOG(msg)
    if Extension.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffcccc33[R]: |cffffff55" .. ( msg ))
    end
end

--
-- This is the new, corrected hook function for GetFocusName
--
function Extension.FocusNameHook()
    -- First, try to get the focus name directly from pfUI's data structure.
    -- This is the primary purpose of this compatibility hook.
    if pfUI and pfUI.uf and pfUI.uf.focus and pfUI.uf.focus.unitname and pfUI.uf.focus.unitname ~= "" then
        return pfUI.uf.focus.unitname
    end

    -- If the pfUI focus is not found, fall back to the original GetFocusName function.
    -- This allows CleveRoids to work with other focus addons if the pfUI focus isn't set.
    local hook = Extension.internal.memberHooks[CleveRoids]["GetFocusName"]

    -- The original function is stored in the 'original' field by the hook framework.
    -- The typo 'origininal' in the original file would have caused a Lua error.
    if hook and hook.original then
        return hook.original()
    end

    -- If all else fails, return nil.
    return nil
end


--
-- This is the new, corrected OnLoad function
--
function Extension.OnLoad(addon)
    -- Only apply the hook after pfUI itself has finished loading. This prevents a race condition.
    if addon == "pfUI" then
        Extension.DLOG("pfUI has loaded. Applying compatibility hook for GetFocusName.")
        Extension.HookMethod(CleveRoids, "GetFocusName", "FocusNameHook", true)

        -- The hook is now active. We can stop listening for ADDON_LOADED events.
        Extension.UnregisterEvent("ADDON_LOADED", "OnLoad")
    end
end


_G["CleveRoids"] = CleveRoids
