--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny / brian / Mewtiny
	License: MIT License
]]

-- Setup to wrap our stuff in a table so we don't pollute the global environment
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
_G.CleveRoids = CleveRoids
CleveRoids.lastItemIndexTime = 0
CleveRoids.initializationTimer = nil
CleveRoids.isActionUpdateQueued = true -- Flag to check if a full action update is needed

-- Queues a full update of all action bars.
-- This is called by game event handlers to avoid running heavy logic inside the event itself.
function CleveRoids.QueueActionUpdate()
    CleveRoids.isActionUpdateQueued = true
end

function CleveRoids.GetSpellCost(spellSlot, bookType)
    CleveRoids.Frame:SetOwner(WorldFrame, "ANCHOR_NONE")
    CleveRoids.Frame:SetSpell(spellSlot, bookType)
    local _, _, cost = string.find(CleveRoids.Frame.costFontString:GetText() or "", "^(%d+) [^ys]")
    local _, _, reagent = string.find(CleveRoids.Frame.reagentFontString:GetText() or "", "^Reagents: (.*)")
    if reagent and string.sub(reagent, 1, 2) == "|c" then
        reagent = string.sub(reagent, 11, -3)
    end

    return (cost and tonumber(cost) or 0), (reagent and tostring(reagent) or nil)
end

function CleveRoids.GetProxyActionSlot(slot)
    if not slot then return end
    return CleveRoids.actionSlots[slot] or CleveRoids.actionSlots[slot.."()"]
end

function CleveRoids.TestForActiveAction(actions)
    if not actions then return end
    local currentActive = actions.active
    local currentSequence = actions.sequence
    local hasActive = false
    local newActiveAction = nil
    local newSequence = nil

    if actions.tooltip and table.getn(actions.list) == 0 then
        if CleveRoids.TestAction(actions.cmd or "", actions.args or "") then

            hasActive = true
            actions.active = actions.tooltip
        end
    else
        for _, action in actions.list do
            -- break on first action that passes tests
            if CleveRoids.TestAction(action.cmd, action.args) then
                hasActive = true
                if action.sequence then
                    newSequence = action.sequence
                    newActiveAction = CleveRoids.GetCurrentSequenceAction(newSequence)
                    if not newActiveAction then hasActive = false end
                else
                    newActiveAction = action
                end
                if hasActive then break end
            end
        end
    end

    local changed = false
    if currentActive ~= newActiveAction or currentSequence ~= newSequence then
        actions.active = newActiveAction
        actions.sequence = newSequence
        changed = true
    end

    if not hasActive then
        if actions.active ~= nil or actions.sequence ~= nil then
             actions.active = nil
             actions.sequence = nil
             changed = true
        end
        return changed
    end

    if actions.active then
        local previousUsable = actions.active.usable
        local previousOom = actions.active.oom
        local previousInRange = actions.active.inRange

        if actions.active.spell then
            actions.active.inRange = 1

            -- nampower range check
            if IsSpellInRange then
                actions.active.inRange = IsSpellInRange(actions.active.action)
            end

            actions.active.oom = (UnitMana("player") < actions.active.spell.cost)

            local start, duration = GetSpellCooldown(actions.active.spell.spellSlot, actions.active.spell.bookType)
            local onCooldown = (start > 0 and duration > 0)

            if actions.active.isReactive then
                if not CleveRoids.IsReactiveUsable(actions.active.action) then
                    actions.active.oom = false
                    actions.active.usable = nil
                else
                    actions.active.usable = (pfUI and pfUI.bars) and nil or 1
                end
            elseif actions.active.inRange ~= 0 and not actions.active.oom and not onCooldown then
                actions.active.usable = 1

            -- pfUI:actionbar.lua -- update usable [out-of-range = 1, oom = 2, not-usable = 3, default = 0]
            elseif pfUI and pfUI.bars and actions.active.oom then
                actions.active.usable = 2
            else
                actions.active.usable = nil
            end
        else
            actions.active.inRange = 1
            actions.active.usable = 1
        end
        if actions.active.usable ~= previousUsable or
           actions.active.oom ~= previousOom or
           actions.active.inRange ~= previousInRange then
            changed = true
        end
    end
    return changed
end

function CleveRoids.TestForAllActiveActions()
    for slot, actions in CleveRoids.Actions do
        local stateChanged = CleveRoids.TestForActiveAction(actions)
        if stateChanged then
            CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
        end
    end
end

function CleveRoids.ClearAction(slot)
    if not CleveRoids.Actions[slot] then return end
    CleveRoids.Actions[slot].active = nil
    CleveRoids.Actions[slot] = nil
end

function CleveRoids.GetAction(slot)
    if not slot or not CleveRoids.ready then return end

    local actions = CleveRoids.Actions[slot]
    if actions then return actions end

    local text = GetActionText(slot)

    if text then
        local macro = CleveRoids.GetMacro(text)
        if macro then
            actions = macro.actions

            CleveRoids.TestForActiveAction(actions)
            CleveRoids.Actions[slot] = actions
            CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
            return actions
        end
    end
end

function CleveRoids.GetActiveAction(slot)
    local action = CleveRoids.GetAction(slot)
    return action and action.active
end

function CleveRoids.SendEventForAction(slot, event, ...)
    local old_this = this

    local original_global_args = {}
    for i = 1, 10 do
        original_global_args[i] = _G["arg" .. i]
    end

    if type(arg) == "table" then

        local n_varargs_from_arg_table = arg.n or 0
        for i = 1, 10 do
            if i <= n_varargs_from_arg_table then
                _G["arg" .. i] = arg[i]
            else
                _G["arg" .. i] = nil
            end
        end
    else
        for i = 1, 10 do
            _G["arg" .. i] = nil
        end
    end

    local button_to_call_event_on
    local page = floor((slot - 1) / NUM_ACTIONBAR_BUTTONS) + 1
    local pageSlot = slot - (page - 1) * NUM_ACTIONBAR_BUTTONS

    if slot >= 73 then
        button_to_call_event_on = _G["BonusActionButton" .. pageSlot]
    elseif slot >= 61 then
        button_to_call_event_on = _G["MultiBarBottomLeftButton" .. pageSlot]
    elseif slot >= 49 then
        button_to_call_event_on = _G["MultiBarBottomRightButton" .. pageSlot]
    elseif slot >= 37 then
        button_to_call_event_on = _G["MultiBarLeftButton" .. pageSlot]
    elseif slot >= 25 then
        button_to_call_event_on = _G["MultiBarRightButton" .. pageSlot]
    end

    if button_to_call_event_on then
        this = button_to_call_event_on
        ActionButton_OnEvent(event)
    end

    if page == CURRENT_ACTIONBAR_PAGE then
        local main_bar_button = _G["ActionButton" .. pageSlot]
        if main_bar_button and main_bar_button ~= button_to_call_event_on then
            this = main_bar_button
            ActionButton_OnEvent(event)
        elseif not button_to_call_event_on and main_bar_button then
             this = main_bar_button
             ActionButton_OnEvent(event)
        end
    end

    this = old_this

    for i = 1, 10 do
        _G["arg" .. i] = original_global_args[i]
    end

    if type(arg) == "table" and arg.n then

        if arg.n == 0 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event) end
        elseif arg.n == 1 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1]) end
        elseif arg.n == 2 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1], arg[2]) end
        elseif arg.n == 3 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1], arg[2], arg[3]) end
        elseif arg.n == 4 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1], arg[2], arg[3], arg[4]) end
        elseif arg.n == 5 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1], arg[2], arg[3], arg[4], arg[5]) end
        elseif arg.n == 6 then
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1], arg[2], arg[3], arg[4], arg[5], arg[6]) end
        else
            for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do fn_h(slot, event, arg[1], arg[2], arg[3], arg[4], arg[5], arg[6], arg[7]) end
        end
    else

        for _, fn_h in ipairs(CleveRoids.actionEventHandlers) do
            fn_h(slot, event)
        end
    end
end

-- Executes the given Macro's body
-- body: The Macro's body
function CleveRoids.ExecuteMacroBody(body,inline)
    local lines = CleveRoids.splitString(body, "\n")
    if inline then lines = CleveRoids.splitString(body, "\\n"); end

    for k,v in pairs(lines) do
        if CleveRoids.stopmacro then
            CleveRoids.stopmacro = false
            return true
        end
        ChatFrameEditBox:SetText(v)
        ChatEdit_SendText(ChatFrameEditBox)
    end
    return true
end

-- Gets the body of the Macro with the given name
-- name: The name of the Macro
-- returns: The body of the macro
function CleveRoids.GetMacroBody(name)
    local macro = CleveRoids.GetMacro(name)
    return macro and macro.body
end

-- Attempts to execute a macro by the given name
-- name: The name of the macro
-- returns: Whether the macro was executed or not
function CleveRoids.ExecuteMacroByName(name)
    local body = CleveRoids.GetMacroBody(name)
    if not body then
        return false
    end

    CleveRoids.ExecuteMacroBody(body)
    return true
end

function CleveRoids.SetHelp(conditionals)
    if conditionals.harm then
        conditionals.help = false
    end
end

function CleveRoids.FixEmptyTarget(conditionals)
    if not conditionals.target then
        if UnitExists("target") then
            conditionals.target = "target"
        elseif GetCVar("autoSelfCast") == "1" then
            conditionals.target = "player"
        end
    end

    return false
end

-- Fixes the conditionals' target by targeting the target with the given name
-- conditionals: The conditionals containing the current target
-- name: The name of the player to target
-- hook: The target hook
-- returns: Whether or not we've changed the player's current target
function CleveRoids.FixEmptyTargetSetTarget(conditionals, name, hook)
    if not conditionals.target then
        hook(name)
        conditionals.target = "target"
        return true
    end
    return false
end

-- Returns the name of the focus target or nil
function CleveRoids.GetFocusName()
    -- 1. Add specific compatibility for pfUI.
    -- pfUI stores its focus unit information in a table.
    if pfUI and pfUI.uf and pfUI.uf.focus and pfUI.uf.focus.unitname then
        return pfUI.uf.focus.unitname
    end

    -- Fallback for other focus addons
    if ClassicFocus_CurrentFocus then
        return ClassicFocus_CurrentFocus
    elseif CURR_FOCUS_TARGET then
        return CURR_FOCUS_TARGET
    end

    return nil
end

-- Attempts to target the focus target.
-- returns: Whether or not it succeeded
function CleveRoids.TryTargetFocus()
    local name = CleveRoids.GetFocusName()

    if not name then
        return false
    end

    TargetByName(name, true)

    if not UnitExists("target") or (string.lower(UnitName("target")) ~= name) then
        -- The target switch failed (out of range, LoS, etc.)
        return false
    end

    return true
end

function CleveRoids.GetMacroNameFromAction(text)
    if string.sub(text, 1, 1) == "{" and string.sub(text, -1) == "}" then
        local name
        if string.sub(text, 2, 2) == "\"" and string.sub(text, -2, -2) == "\"" then
            return string.sub(text, 3, -3)
        else
            return string.sub(text, 2, -2)
        end
    end
end

function CleveRoids.CreateActionInfo(action, conditionals)
    local _, _, text = string.find(action, "!?%??~?(.*)")
    local spell = CleveRoids.GetSpell(text)
    local item, macroName, macro, macroTooltip, actionType, texture

    -- NEW: Check if the action is a slot number
    local slotId = tonumber(text)
    if slotId and slotId >= 1 and slotId <= 19 then
        actionType = "item"
        -- Use the most reliable method first to get the texture for an equipped item.
        local itemTexture = GetInventoryItemTexture("player", slotId)

        -- Check if the texture was successfully found.
        if itemTexture then
            texture = itemTexture
        else
            -- If the primary method fails, fall back to the unknown texture.
            -- This prevents errors if the slot is empty or the item data is unusual.
            texture = CleveRoids.unknownTexture
        end
    else
        -- Original logic for named items and spells
        if not spell then
            item = CleveRoids.GetItem(text)
        end
        if not item then
            macroName = CleveRoids.GetMacroNameFromAction(text)
            macro = CleveRoids.GetMacro(macroName)
            macroTooltip = (macro and macro.actions) and macro.actions.tooltip
        end

        if spell then
            actionType = "spell"
            texture = spell.texture or CleveRoids.unknownTexture
        elseif item then
            actionType = "item"
            texture = (item and item.texture) or CleveRoids.unknownTexture
        elseif macro then
            actionType = "macro"
            texture = (macro.actions and macro.actions.tooltip and macro.actions.tooltip.texture)
                        or (macro and macro.texture)
                        or CleveRoids.unknownTexture
        end
    end

    local info = {
        action = text,
        item = item,
        spell = spell,
        macro = macroTooltip,
        type = actionType,
        texture = texture,
        conditionals = conditionals,
    }

    return info
end

function CleveRoids.SplitCommandAndArgs(text)
    local _, _, cmd, args = string.find(text, "(/%w+%s?)(.*)")
    if cmd and args then
        cmd = CleveRoids.Trim(cmd)
        text = CleveRoids.Trim(args)
    end
    return cmd, args
end

function CleveRoids.ParseSequence(text)
    local args = string.gsub(text, "(%s*,%s*)", ",")
    local _, c, cond = string.find(args, "(%[.*%])")
    local _, r, reset, resetVal = string.find(args, "(%s*%]*%s*reset=([%w/]+)%s+)")

    actionSeq = CleveRoids.Trim((r and string.sub(args, r+1)) or (c and string.sub(args, c+1)) or args)
    args = (cond or "") .. actionSeq

    if not actionSeq then
        return
    end

    local sequence = {
        index = 1,
        reset = {},
        status = 0,
        list = {},
        lastUpdate = 0,
        cond = cond,
        args = args,
        cmd = "/castsequence"
    }
    if resetVal then
        for _, rule in ipairs(CleveRoids.Split(resetVal, "/")) do
            local secs = tonumber(rule)
            if secs and secs > 0 then
                sequence.reset.secs = secs
            else
                sequence.reset[string.lower(rule)] = true
            end
        end
    end

    for _, a in ipairs(CleveRoids.Split(actionSeq, ",")) do
        local sa = CleveRoids.CreateActionInfo(CleveRoids.GetParsedMsg(a))
        table.insert(sequence.list, sa)
    end
    CleveRoids.Sequences[text] = sequence

    return sequence
end

function CleveRoids.ParseMacro(name)
    if not name then return end

    local macroID = GetMacroIndexByName(name)
    if not macroID then return end

    local _, texture, body = GetMacroInfo(macroID)

    if not body and GetSuperMacroInfo then
        _, texture, body = GetSuperMacroInfo(name)
    end

    if not texture or not body then return end


    local macro = {
        id = macroId,
        name = name,
        texture = texture,
        body = body,
        actions = {},
    }
    macro.actions.list = {}

    -- build a list of testable actions for the macro
    for i, line in CleveRoids.splitString(body, "\n") do
        line = CleveRoids.Trim(line)
        local cmd, args = CleveRoids.SplitCommandAndArgs(line)

        -- check for #showtooltip
        if i == 1 then
            local _, _, st, _, tt = string.find(line, "(#showtooltip)(%s?(.*))")

            -- if no #showtooltip, nothing to keep track of
            if not st then
                break
            end
            tt = CleveRoids.Trim(tt)

            -- #showtooltip and item/spell/macro specified, only use this tooltip
            if st and tt ~= "" then
                macro.actions.tooltip = CleveRoids.CreateActionInfo(tt)
                macro.actions.cmd = cmd
                macro.actions.args = tt
                break
            end
        else
            -- make sure we have a testable action
            if line ~= "" and args ~= "" and CleveRoids.dynamicCmds[cmd] then
                for _, arg in CleveRoids.splitStringIgnoringQuotes(args) do
                    local action = CleveRoids.CreateActionInfo(CleveRoids.GetParsedMsg(arg))

                    if cmd == "/castsequence" then
                        local sequence = CleveRoids.GetSequence(args)
                        if sequence then
                            action.sequence = sequence
                        end
                    end

                    action.cmd = cmd
                    action.args = arg
                    action.isReactive = CleveRoids.reactiveSpells[action.action]
                    table.insert(macro.actions.list, action)
                end
            end
        end
    end

    CleveRoids.Macros[name] = macro
    return macro
end

function CleveRoids.ParseMsg(msg)
    if not msg then return end
    local conditionals = {}

    msg, conditionals.ignoretooltip = string.gsub(CleveRoids.Trim(msg), "^%?", "")
    local _, cbEnd, conditionBlock = string.find(msg, "%[(.+)%]")
    local _, _, noSpam, cancelAura, action = string.find(string.sub(msg, (cbEnd or 0) + 1), "^%s*(!?)(~?)([^!~]+.*)")
    action = CleveRoids.Trim(action or "")

    -- Store the action along with the conditionals incase it's needed
    conditionals.action = action
    action = string.gsub(action, "%(Rank %d+%)", "")

    if noSpam and noSpam ~= "" then
        local spamCond = CleveRoids.GetSpammableConditional(action)
        if spamCond then
            conditionals[spamCond] = { action }
        end
    end
    if cancelAura and cancelAura ~= "" then
        conditionals.cancelaura = action
    end

    if not conditionBlock then
        return conditionals.action, conditionals
    end

    -- Set the action's target to @unitid if found
    local _, _, target = string.find(conditionBlock, "(@[^%s,]+)")
    if target then
        conditionBlock = CleveRoids.Trim(string.gsub(conditionBlock, target, ""))
        conditionals.target = string.sub(target, 2)
    end

    if conditionBlock and action then
        -- Split the conditional block by comma or space
        for _, conditionGroups in CleveRoids.splitStringIgnoringQuotes(conditionBlock, {",", " "}) do
            if conditionGroups ~= "" then
                -- Split conditional groups by colon
                local conditionGroup = CleveRoids.splitStringIgnoringQuotes(conditionGroups, ":")
                local condition, args = conditionGroup[1], conditionGroup[2]

                -- No args, just set the conditional
                if not args or args == "" then
                    if conditionals[condition] and type(conditionals) ~= "table" then
                        conditionals[condition] = { conditionals[condition] }
                        table.insert(conditionals[condition], action)
                    else
                        conditionals[condition] = action
                    end
                else
                    if not conditionals[condition] then
                        conditionals[condition] = {}
                    end

                    -- Split the args by / for multiple values
                    for _, arg_item in CleveRoids.splitString(args, "/") do
                        local processed_arg = CleveRoids.Trim(arg_item)

                        processed_arg = string.gsub(processed_arg, '"', "")
                        processed_arg = string.gsub(processed_arg, "_", " ")
                        processed_arg = CleveRoids.Trim(processed_arg)

                        local arg_for_find = processed_arg
                        arg_for_find = string.gsub(arg_for_find, "^#(%d+)$", "=#%1")
                        arg_for_find = string.gsub(arg_for_find, "([^>~=<]+)#(%d+)", "%1=#%2")

                        -- FIXED: This regex now accepts decimal numbers
                        local _, _, name, operator, amount = string.find(arg_for_find, "([^>~=<]*)([>~=<]+)(#?%d*%.?%d+)")
                        if not operator or not amount then
                            table.insert(conditionals[condition], processed_arg)
                        else
                            local name_to_use = (name and name ~= "") and name or conditionals.action

                            local final_amount_str, num_replacements = string.gsub(amount, "#", "")
                            local should_check_stacks = (num_replacements == 1)

                            table.insert(conditionals[condition], {
                                name = CleveRoids.Trim(name_to_use),
                                operator = operator,
                                amount = tonumber(final_amount_str),
                                checkStacks = should_check_stacks
                            })
                        end
                    end
                end
            end
        end
        return conditionals.action, conditionals
    end
end

-- Get previously parsed or parse, store and return
function CleveRoids.GetParsedMsg(msg)
    if not msg then return end

    if CleveRoids.ParsedMsg[msg] then
        return CleveRoids.ParsedMsg[msg].action, CleveRoids.ParsedMsg[msg].conditionals
    end

    CleveRoids.ParsedMsg[msg] = {}
    CleveRoids.ParsedMsg[msg].action, CleveRoids.ParsedMsg[msg].conditionals = CleveRoids.ParseMsg(msg)

    return CleveRoids.ParsedMsg[msg].action, CleveRoids.ParsedMsg[msg].conditionals
end

function CleveRoids.GetMacro(name)
    return CleveRoids.Macros[name] or CleveRoids.ParseMacro(name)
end

function CleveRoids.GetSequence(args)
    return CleveRoids.Sequences[args] or CleveRoids.ParseSequence(args)
end

function CleveRoids.GetCurrentSequenceAction(sequence)
    return sequence.list[sequence.index]
end

function CleveRoids.ResetSequence(sequence)
    sequence.index = 1
end

function CleveRoids.AdvanceSequence(sequence)
    if sequence.index < table.getn(sequence.list) then
        sequence.index = sequence.index + 1
    else
        CleveRoids.ResetSequence(sequence)
    end
end

function CleveRoids.TestAction(cmd, args)
    local msg, conditionals = CleveRoids.GetParsedMsg(args)

    if string.find(msg, "#showtooltip") or conditionals.ignoretooltip == 1 then
        return
    end

    if not conditionals then
        if not msg then
            return
        else
            -- action is a {macro} or item/spell
            return CleveRoids.GetMacroNameFromAction(msg) or msg
        end
    end

    local origTarget = conditionals.target
    if cmd == "" or not CleveRoids.dynamicCmds[cmd] then
        -- untestables
        return
    end

    if conditionals.target == "focus" then
        if not CleveRoids.GetFocusName() then
            return
        end
        conditionals.target = "target"
    end


    if conditionals.target == "mouseover" then
        if not CleveRoids.IsValidTarget("mouseover", conditionals.help) then
            return false
        end
    end

    CleveRoids.FixEmptyTarget(conditionals)
    -- CleveRoids.SetHelp(conditionals)

    for k, v in pairs(conditionals) do
        if not CleveRoids.ignoreKeywords[k] then
            if not CleveRoids.Keywords[k] or not CleveRoids.Keywords[k](conditionals) then
                -- failed test
                conditionals.target = origTarget
                return
            end
        end
    end

    -- tests passed
    conditionals.target = origTarget
    return CleveRoids.GetMacroNameFromAction(msg) or msg
end

-- Does the given action with a set of conditionals provided by the given msg
-- msg: The conditions followed by the action's parameters
-- hook: The hook of the function we've intercepted
-- fixEmptyTargetFunc: A function setting the player's target if the player has none. Required to return true if we need to re-target later or false if not
-- targetBeforeAction: A boolean value that determines whether or not we need to target the target given in the conditionals before performing the given action
-- action: A function that is being called when everything checks out
function CleveRoids.DoWithConditionals(msg, hook, fixEmptyTargetFunc, targetBeforeAction, action)
    local msg, conditionals = CleveRoids.GetParsedMsg(msg)

    -- No conditionals. Just exit.
    if not conditionals then
        if not msg then -- if not even an empty string
            return false
        else
            if string.sub(msg, 1, 1) == "{" and string.sub(msg, -1) == "}" then
                if string.sub(msg, 2, 2) == "\"" and string.sub(msg, -2, -2) == "\"" then
                    return CleveRoids.ExecuteMacroBody(string.sub(msg, 3, -3), true)
                else
                    return CleveRoids.ExecuteMacroByName(string.sub(msg, 2, -2))
                end
            end

            if hook then
                hook(msg)
            end
            return true
        end
    end

    if conditionals.cancelaura then
        if CleveRoids.CancelAura(conditionals.cancelaura) then
            return true
        end
    end

    local origTarget = conditionals.target
    if conditionals.target == "mouseover" then
        if UnitExists("mouseover") then
            conditionals.target = "mouseover"
        elseif CleveRoids.mouseoverUnit and UnitExists(CleveRoids.mouseoverUnit) then
            conditionals.target = CleveRoids.mouseoverUnit
        else
            conditionals.target = "mouseover"
        end
    end

    local needRetarget = false
    if fixEmptyTargetFunc then
        needRetarget = fixEmptyTargetFunc(conditionals, msg, hook)
    end

    -- CleveRoids.SetHelp(conditionals)

    if conditionals.target == "focus" then
        local focusUnitId = nil

        -- Attempt to get the direct UnitID from pfUI's focus frame data. This is more reliable.
        if pfUI and pfUI.uf and pfUI.uf.focus and pfUI.uf.focus.label and pfUI.uf.focus.id and UnitExists(pfUI.uf.focus.label .. pfUI.uf.focus.id) then
            focusUnitId = pfUI.uf.focus.label .. pfUI.uf.focus.id
        end

        if focusUnitId then
                -- If we found a valid UnitID, we will use it for all subsequent checks and the final cast.
                -- This avoids changing the player's actual target.
            conditionals.target = focusUnitId
            needRetarget = false
        else
            -- If the direct UnitID isn't found, fall back to the original (but likely failing) method of targeting by name.
            if not CleveRoids.TryTargetFocus() then
                UIErrorsFrame:AddMessage(SPELL_FAILED_BAD_TARGETS, 1.0, 0.0, 0.0, 1.0)
                conditionals.target = origTarget
                return false
            end
            conditionals.target = "target"
            needRetarget = true
        end
    end

    for k, v in pairs(conditionals) do
        if not CleveRoids.ignoreKeywords[k] then
            if not CleveRoids.Keywords[k] or not CleveRoids.Keywords[k](conditionals) then
                if needRetarget then
                    TargetLastTarget()
                    needRetarget = false
                end
                conditionals.target = origTarget
                return false
            end
        end
    end

    if conditionals.target ~= nil and targetBeforeAction and not (CleveRoids.hasSuperwow and action == CastSpellByName) then
        if not UnitIsUnit("target", conditionals.target) then
            if SpellIsTargeting() then
                SpellStopCasting()
            end
            TargetUnit(conditionals.target)
            needRetarget = true
        else
             if needRetarget then needRetarget = false end
        end
    elseif needRetarget then
        TargetLastTarget()
        needRetarget = false
    end

    if action == "STOPMACRO" then
        CleveRoids.stopmacro = true
        return true
    end

    local result = true
    if string.sub(msg, 1, 1) == "{" and string.sub(msg, -1) == "}" then
        if string.sub(msg, 2, 2) == "\"" and string.sub(msg, -2,-2) == "\"" then
            result = CleveRoids.ExecuteMacroBody(string.sub(msg, 3, -3), true)
        else
            result = CleveRoids.ExecuteMacroByName(string.sub(msg, 2, -2))
        end
    else -- This 'else' corresponds to 'if string.sub(msg, 1, 1) == "{"...'
        if CleveRoids.hasSuperwow and action == CastSpellByName and conditionals.target then
            CastSpellByName(msg, conditionals.target) -- SuperWoW handles targeting via argument
        elseif action == CastSpellByName then
             -- For standard CastSpellByName, targeting is handled by the TargetUnit call above.
             -- Pass only the spell name.
            action(msg)
        else
            -- For other actions like UseContainerItem etc.
            action(msg)
        end
    end

    if needRetarget then
        TargetLastTarget()
    end

    conditionals.target = origTarget
    return result
end

-- Attempts to cast a single spell from the given set of conditional spells
-- msg: The player's macro text
function CleveRoids.DoCast(msg)
    local handled = false

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        if CleveRoids.DoWithConditionals(v, CleveRoids.Hooks.CAST_SlashCmd, CleveRoids.FixEmptyTarget, not CleveRoids.hasSuperwow, CastSpellByName) then
            handled = true -- we parsed at least one command
            break
        end
    end
    return handled
end

-- Attempts to target a unit by its name using a set of conditionals
-- msg: The raw message intercepted from a /target command
function CleveRoids.DoTarget(msg)
    local handled = false

    local action = function(msg)
        if string.sub(msg, 1, 1) == "@" then
            local unit = string.sub(msg, 2)
            if CleveRoids.hasSuperwow then
                local _, guid = UnitExists(unit)
                if guid then TargetUnit(guid) end
            else
                CleveRoids.Hooks.TARGET_SlashCmd(UnitName(unit))
            end
        end
    end

    for k, v in CleveRoids.splitStringIgnoringQuotes(msg) do
        local _, cPos, anyCond = string.find(v, "(%[.*%])")
        local _, _, atTarget = string.find(v, "%s*@([^%s]+)%s*$", (cPos and cPos+1 or 1))
        if atTarget then handled = true end
        if atTarget and not anyCond then
            v = "[@"..atTarget.."] "..v
        end
        if CleveRoids.DoWithConditionals(v, CleveRoids.Hooks.TARGET_SlashCmd, CleveRoids.FixEmptyTargetSetTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to attack a unit by a set of conditionals
-- msg: The raw message intercepted from a /petattack command
function CleveRoids.DoPetAttack(msg)
    local handled = false

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        if CleveRoids.DoWithConditionals(v, PetAttack, CleveRoids.FixEmptyTarget, true, PetAttack) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to conditionally start an attack. Returns false if no conditionals are found.
function CleveRoids.DoConditionalStartAttack(msg)
    if not string.find(msg, "%[") then return false end

    local handled = false
    local action = function()
        if not UnitExists("target") or UnitIsDead("target") then TargetNearestEnemy() end
        if not CleveRoids.CurrentSpell.autoAttack and not CleveRoids.CurrentSpell.autoAttackLock and UnitExists("target") and UnitCanAttack("player", "target") then
            CleveRoids.CurrentSpell.autoAttackLock = true
            CleveRoids.autoAttackLockElapsed = GetTime()
            AttackTarget()
        end
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        -- We pass 'nil' for the hook, so DoWithConditionals does nothing if it fails to parse conditionals.
        if CleveRoids.DoWithConditionals(v, nil, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to conditionally stop an attack. Returns false if no conditionals are found.
function CleveRoids.DoConditionalStopAttack(msg)
    if not string.find(msg, "%[") then return false end

    local handled = false
    local action = function()
        if CleveRoids.CurrentSpell.autoAttack and UnitExists("target") then
            AttackTarget()
            CleveRoids.CurrentSpell.autoAttack = false
        end
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        if CleveRoids.DoWithConditionals(v, nil, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to conditionally stop casting. Returns false if no conditionals are found.
function CleveRoids.DoConditionalStopCasting(msg)
    if not string.find(msg, "%[") then return false end

    local handled = false
    local action = function()
        SpellStopCasting()
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        if CleveRoids.DoWithConditionals(v, nil, nil, false, action) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to use or equip an item from the player's inventory by a  set of conditionals
-- Also checks if a condition is a spell so that you can mix item and spell use
-- msg: The raw message intercepted from a /use or /equip command
function CleveRoids.DoUse(msg)
    local handled = false

    -- START of replacement block for the 'action' function
    local action = function(msg)
        -- Try to interpret the message as a direct inventory slot ID first.
        local slotId = tonumber(msg)
        if slotId and slotId >= 1 and slotId <= 19 then -- Character slots are 1-19
            UseInventoryItem(slotId)
            return -- Exit after using the item by slot.
        end

        -- Original logic: if it's not a slot number, try to resolve by name.
        local item = CleveRoids.GetItem(msg)

        if item and item.inventoryID then
            -- This is for using an already-equipped item (like a trinket).
            -- This action does not cause an inventory change that needs a fast re-index.
            return UseInventoryItem(item.inventoryID)
        elseif item and item.bagID then
            -- This will use an item from a bag. It could be a potion (use) or a weapon (equip).
            -- We need to check if it's an equippable item before using it.
            local isEquippable = false
            local itemName, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(msg)
            if itemName and itemEquipLoc and itemEquipLoc ~= "" then
                isEquippable = true
            end

            CleveRoids.GetNextBagSlotForUse(item, msg)
            UseContainerItem(item.bagID, item.slot)

            -- If it was an equippable item, force a cache refresh on the next inventory event.
            if isEquippable then
                CleveRoids.lastItemIndexTime = 0
            end
            return
        end

        if (MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1) then return end
    end
    -- END of replacement block

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        v = string.gsub(v, "^%?", "")
        local subject = v
        local _,e = string.find(v,"%]")
        if e then subject = CleveRoids.Trim(string.sub(v,e+1)) end

        local wasHandled = false
        -- If the subject is not a number, check if it's a spell.
        if (not tonumber(subject)) and CleveRoids.GetSpell(subject) then
            wasHandled = CleveRoids.DoWithConditionals(v, CleveRoids.Hooks.CAST_SlashCmd, CleveRoids.FixEmptyTarget, not CleveRoids.hasSuperwow, CastSpellByName)
        else
            -- Otherwise, treat it as an item (by name or slot ID).
            wasHandled = CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action)
        end
        if wasHandled then
            handled = true
            break
        end
    end
    return handled -- Corrected typo from 'Handled' to 'handled'
end


function CleveRoids.EquipBagItem(msg, offhand)
    local item = CleveRoids.GetItem(msg)

    if not item or (not item.bagID and not item.inventoryID) then
        return false
    end

    local invslot = offhand and 17 or 16
    if item.bagID then
        CleveRoids.GetNextBagSlotForUse(item, msg)
        PickupContainerItem(item.bagID, item.slot)
    else
        PickupInventoryItem(item.inventoryID)
    end

    EquipCursorItem(invslot)
    ClearCursor()

    CleveRoids.lastItemIndexTime = 0

    return true
end

-- TODO: Refactor all these DoWithConditionals sections
function CleveRoids.DoEquipMainhand(msg)
    local handled = false

    local action = function(msg)
        return CleveRoids.EquipBagItem(msg, false)
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        v = string.gsub(v, "^%?", "")

        if CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

function CleveRoids.DoEquipOffhand(msg)
    local handled = false

    local action = function(msg)
        return CleveRoids.EquipBagItem(msg, true)
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        v = string.gsub(v, "^%?", "")

        if CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

function CleveRoids.DoUnshift(msg)
    local handled

    local action = function(msg)
        local currentShapeshiftIndex = CleveRoids.GetCurrentShapeshiftIndex()
        if currentShapeshiftIndex ~= 0 then
            CastShapeshiftForm(currentShapeshiftIndex)
        end
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        handled = false
        if CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end

    if handled == nil then
        action()
    end

    return handled
end

function CleveRoids.DoRetarget()
    if GetUnitName("target") == nil
        or UnitHealth("target") == 0
        or not UnitCanAttack("player", "target")
    then
        ClearTarget()
        TargetNearestEnemy()
    end
end

-- Attempts to stop macro
 function CleveRoids.DoStopMacro(msg)
    local handled = false
    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(CleveRoids.Trim(msg))) do
        if CleveRoids.DoWithConditionals(msg, nil, nil, not CleveRoids.hasSuperwow, "STOPMACRO") then
            handled = true -- we parsed at least one command
            break
        end
    end
    return handled
end

function CleveRoids.DoCastSequence(sequence)
    if not CleveRoids.hasSuperwow then
        CleveRoids.Print("|cFFFF0000/castsequence|r requires |cFF00FFFFSuperWoW|r.")
        return
    end

    if CleveRoids.currentSequence and not CleveRoids.CheckSpellCast("player") then
        CleveRoids.currentSequence = nil
    elseif CleveRoids.currentSequence then
        return
    end

    if sequence.index > 1 then
        if sequence.reset then
            for k, _ in sequence.reset do
                if CleveRoids.kmods[k] and CleveRoids.kmods[k]() then
                    CleveRoids.ResetSequence(sequence)
                end
            end
        end
    end

    local active = CleveRoids.GetCurrentSequenceAction(sequence)
    if active and active.action then
        sequence.status = 0
        sequence.lastUpdate = GetTime()
        sequence.expires = 0

        CleveRoids.currentSequence = sequence

        local action = (sequence.cond or "") .. active.action
        local result = CleveRoids.DoWithConditionals(action, nil, nil, not CleveRoids.hasSuperwow, CastSpellByName)

        return result
    end
end

CleveRoids.DoConditionalCancelAura = function(msg)
    local trimmedMsg = CleveRoids.Trim(msg or "")

    if trimmedMsg == "" then
        return false
    end
    if CleveRoids.DoWithConditionals(trimmedMsg, nil, CleveRoids.FixEmptyTarget, false, CleveRoids.CancelAura) then
        return true
    else
        return false
    end
end

function CleveRoids.OnUpdate(self)
    local time = GetTime()
    if CleveRoids.initializationTimer and time >= CleveRoids.initializationTimer then
        CleveRoids.IndexItems()
        CleveRoids.IndexActionBars()
        CleveRoids.ready = true
        CleveRoids.initializationTimer = nil
        CleveRoids.TestForAllActiveActions()
        CleveRoids.lastUpdate = time
        return
    end

    if not CleveRoids.ready then return end

    -- Throttle the OnUpdate loop to avoid excessive CPU usage.
    if (time - CleveRoids.lastUpdate) < 0.2 then return end
    CleveRoids.lastUpdate = time

    -- If a game event has queued an update, run the expensive check.
    if CleveRoids.isActionUpdateQueued then
        CleveRoids.TestForAllActiveActions()
        CleveRoids.isActionUpdateQueued = false -- Reset the flag
    end

    -- The rest of this function handles logic that MUST be time-based.
    if CleveRoids.CurrentSpell.autoAttackLock and (time - CleveRoids.autoAttackLockElapsed) > 0.2 then
        CleveRoids.CurrentSpell.autoAttackLock = false
        CleveRoids.CurrentSpell.autoAttackLockElapsed = nil
    end

    for _, sequence in pairs(CleveRoids.Sequences) do
        if sequence.index > 1 and sequence.reset.secs and (time - (sequence.lastUpdate or 0)) >= sequence.reset.secs then
            CleveRoids.ResetSequence(sequence)
        end
    end

    for guid,cast in pairs(CleveRoids.spell_tracking) do
        if time > cast.expires then
            CleveRoids.spell_tracking[guid] = nil
        end
    end
end

-- Initialize the nested table for the GameTooltip hooks if it doesn't exist
if not CleveRoids.Hooks.GameTooltip then CleveRoids.Hooks.GameTooltip = {} end

-- Save the original GameTooltip.SetAction function before we override it
CleveRoids.Hooks.GameTooltip.SetAction = GameTooltip.SetAction

-- Now, define our custom version of the function
function GameTooltip.SetAction(self, slot)
    local actions = CleveRoids.GetAction(slot)

    local action_to_display_info = nil
    if actions then
        if actions.active then
            action_to_display_info = actions.active
        elseif actions.tooltip then
            action_to_display_info = actions.tooltip
        end
    end

    if action_to_display_info and action_to_display_info.action then
        local action_name = action_to_display_info.action

        -- NEW: Check if action is a slot ID for tooltip
        local slotId = tonumber(action_name)
        if slotId and slotId >= 1 and slotId <= 19 then
            -- Use the more specific SetInventoryItem function to prevent conflicts with other addons.
            GameTooltip:SetInventoryItem("player", slotId)
            GameTooltip:Show()
            return
        end
        -- End new logic

        local current_spell_data = CleveRoids.GetSpell(action_name)
        if current_spell_data then
            GameTooltip:SetSpell(current_spell_data.spellSlot, current_spell_data.bookType)
            local rank_info = current_spell_data.rank or (current_spell_data.highest and current_spell_data.highest.rank)
            if rank_info and rank_info ~= "" then
                GameTooltipTextRight1:SetText("|cff808080" .. rank_info .. "|r")
            else
                GameTooltipTextRight1:SetText("")
            end
            GameTooltipTextRight1:Show()
            GameTooltip:Show()
            return
        end

        local current_item_data = CleveRoids.GetItem(action_name)
        if current_item_data then
            -- Use specific functions based on where the item is located.
            if current_item_data.inventoryID then
                GameTooltip:SetInventoryItem("player", current_item_data.inventoryID)
            elseif current_item_data.bagID and current_item_data.slot then
                GameTooltip:SetBagItem(current_item_data.bagID, current_item_data.slot)
            else
                -- Fallback to the original method if location is unknown.
                GameTooltip:SetHyperlink(current_item_data.link)
            end
            GameTooltip:Show()
            return
        end

        if action_to_display_info.macro and type(action_to_display_info.macro) == "table" then
            local nested_action_info = action_to_display_info.macro
            local nested_action_name = nested_action_info.action

            current_spell_data = CleveRoids.GetSpell(nested_action_name)
            if current_spell_data then
                GameTooltip:SetSpell(current_spell_data.spellSlot, current_spell_data.bookType)
                local rank_info = current_spell_data.rank or (current_spell_data.highest and current_spell_data.highest.rank)
                if rank_info and rank_info ~= "" then
                    GameTooltipTextRight1:SetText("|cff808080" .. rank_info .. "|r")
                else
                    GameTooltipTextRight1:SetText("")
                end
                GameTooltipTextRight1:Show()
                GameTooltip:Show()
                return
            end

            current_item_data = CleveRoids.GetItem(nested_action_name)
            if current_item_data then
                 if current_item_data.inventoryID then
                    GameTooltip:SetInventoryItem("player", current_item_data.inventoryID)
                elseif current_item_data.bagID and current_item_data.slot then
                    GameTooltip:SetBagItem(current_item_data.bagID, current_item_data.slot)
                else
                    GameTooltip:SetHyperlink(current_item_data.link)
                end
                GameTooltip:Show()
                return
            end
        end
    end

    -- If none of our custom logic handled it, call the original function we saved earlier.
    CleveRoids.Hooks.GameTooltip.SetAction(self, slot)
end


CleveRoids.Hooks.PickupAction = PickupAction
function PickupAction(slot)
    CleveRoids.ClearAction(slot)
    CleveRoids.ClearSlot(CleveRoids.actionSlots, slot)
    CleveRoids.ClearAction(CleveRoids.reactiveSlots, slot)
    return CleveRoids.Hooks.PickupAction(slot)
end

CleveRoids.Hooks.ActionHasRange = ActionHasRange
function ActionHasRange(slot)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active then
        return (1 and actions.active.inRange ~= -1 or nil)
    else
        return CleveRoids.Hooks.ActionHasRange(slot)
    end
end

CleveRoids.Hooks.IsActionInRange = IsActionInRange
function IsActionInRange(slot, unit)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active and actions.active.type == "spell" then
        return actions.active.inRange
    else
        return CleveRoids.Hooks.IsActionInRange(slot, unit)
    end
end

CleveRoids.Hooks.OriginalIsUsableAction = IsUsableAction
CleveRoids.Hooks.IsUsableAction = IsUsableAction
function IsUsableAction(slot, unit)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active then
        return actions.active.usable, actions.active.oom
    else
        return CleveRoids.Hooks.IsUsableAction(slot, unit)
    end
end

CleveRoids.Hooks.IsCurrentAction = IsCurrentAction
function IsCurrentAction(slot)
    local active = CleveRoids.GetActiveAction(slot)

    if not active then
        return CleveRoids.Hooks.IsCurrentAction(slot)
    else
        local name
        if active.spell then
            local rank = active.spell.rank or active.spell.highest.rank
            name = active.spell.name..(rank and ("("..rank..")"))
        elseif active.item then
            name = active.item.name
        end

        return CleveRoids.Hooks.IsCurrentAction(CleveRoids.GetProxyActionSlot(name) or slot)
    end
end

CleveRoids.Hooks.GetActionTexture = GetActionTexture
function GetActionTexture(slot)
    local actions = CleveRoids.GetAction(slot)

    if actions and (actions.active or actions.tooltip) then
        local proxySlot = (actions.active and actions.active.spell) and CleveRoids.GetProxyActionSlot(actions.active.spell.name)
        if proxySlot and CleveRoids.Hooks.GetActionTexture(proxySlot) ~= actions.active.spell.texture then
            return CleveRoids.Hooks.GetActionTexture(proxySlot)
        else
            return (actions.active and actions.active.texture) or (actions.tooltip and actions.tooltip.texture) or CleveRoids.unknownTexture
        end
    end
    return CleveRoids.Hooks.GetActionTexture(slot)
end

-- TODO: Look into https://github.com/Stanzilla/WoWUIBugs/issues/47 if needed
CleveRoids.Hooks.GetActionCooldown = GetActionCooldown
function GetActionCooldown(slot)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active then
        local a = actions.active

        local slotId = tonumber(a.action)
        if slotId and slotId >= 1 and slotId <= 19 then
            return GetInventoryItemCooldown("player", slotId)
        end

        if a.spell then
            return GetSpellCooldown(a.spell.spellSlot, a.spell.bookType)
        elseif a.item then
            if a.item.bagID and a.item.slot then
                return GetContainerItemCooldown(a.item.bagID, a.item.slot)
            elseif a.item.inventoryID then
                return GetInventoryItemCooldown("player", a.item.inventoryID)
            end
        end
        return 0, 0, 0
    else
        return CleveRoids.Hooks.GetActionCooldown(slot)
    end
end

CleveRoids.Hooks.GetActionCount = GetActionCount
function GetActionCount(slot)
    local action = CleveRoids.GetAction(slot)
    local count
    if action and action.active then

        local slotId = tonumber(action.active.action)
        if slotId and slotId >= 1 and slotId <= 19 then
            return GetInventoryItemCount("player", slotId)
        end

        if action.active.item then
            count = action.active.item.count
        elseif action.active.spell and action.active.spell.reagent then
            local reagent = CleveRoids.GetItem(action.active.spell.reagent)
            count = reagent and reagent.count
        end
    end

    return count or CleveRoids.Hooks.GetActionCount(slot)
end

CleveRoids.Hooks.IsConsumableAction = IsConsumableAction
function IsConsumableAction(slot)
    local action = CleveRoids.GetAction(slot)
    if action and action.active then

        local slotId = tonumber(action.active.action)
        if slotId and slotId >= 1 and slotId <= 19 then
            local _, count = GetInventoryItemCount("player", slotId)
            if count and count > 0 then return 1 end
        end

        if action.active.item and
            (CleveRoids.countedItemTypes[action.active.item.type]
            or CleveRoids.countedItemTypes[action.active.item.name])
        then
            return 1
        end


        if action.active.spell and action.active.spell.reagent then
            return 1
        end
    end

    return CleveRoids.Hooks.IsConsumableAction(slot)
end




-- Dummy Frame to hook ADDON_LOADED event in order to preserve compatiblity with other AddOns like SuperMacro
CleveRoids.Frame = CreateFrame("GameTooltip")

CleveRoids.Frame.costFontString = CleveRoids.Frame:CreateFontString()
CleveRoids.Frame.rangeFontString = CleveRoids.Frame:CreateFontString()
CleveRoids.Frame.reagentFontString = CleveRoids.Frame:CreateFontString()
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame:CreateFontString(), CleveRoids.Frame:CreateFontString())
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame.costFontString, CleveRoids.Frame.rangeFontString)
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame:CreateFontString(), CleveRoids.Frame:CreateFontString())
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame.reagentFontString, CleveRoids.Frame:CreateFontString())

CleveRoids.Frame:SetScript("OnUpdate", CleveRoids.OnUpdate)
CleveRoids.Frame:SetScript("OnEvent", function(...)
    CleveRoids.Frame[event](this,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10)
end)

-- == CORE EVENT REGISTRATION ==
CleveRoids.Frame:RegisterEvent("PLAYER_LOGIN")
CleveRoids.Frame:RegisterEvent("ADDON_LOADED")
CleveRoids.Frame:RegisterEvent("UPDATE_MACROS")
CleveRoids.Frame:RegisterEvent("SPELLS_CHANGED")
CleveRoids.Frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
CleveRoids.Frame:RegisterEvent("BAG_UPDATE")
CleveRoids.Frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

-- == STATE CHANGE EVENT REGISTRATION (for performance) ==
CleveRoids.Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
CleveRoids.Frame:RegisterEvent("PLAYER_FOCUS_CHANGED") -- For focus addons
CleveRoids.Frame:RegisterEvent("PLAYER_ENTER_COMBAT")
CleveRoids.Frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
CleveRoids.Frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
CleveRoids.Frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
CleveRoids.Frame:RegisterEvent("UNIT_AURA")
CleveRoids.Frame:RegisterEvent("UNIT_HEALTH")
CleveRoids.Frame:RegisterEvent("UNIT_POWER")
CleveRoids.Frame:RegisterEvent("UNIT_CASTEVENT")
CleveRoids.Frame:RegisterEvent("START_AUTOREPEAT_SPELL")
CleveRoids.Frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
CleveRoids.Frame:RegisterEvent("SPELLCAST_CHANNEL_START")
CleveRoids.Frame:RegisterEvent("SPELLCAST_CHANNEL_STOP")


function CleveRoids.Frame:PLAYER_LOGIN()
    _, CleveRoids.playerClass = UnitClass("player")
    _, CleveRoids.playerGuid = UnitExists("player")
    CleveRoids.IndexSpells()
    CleveRoids.initializationTimer = GetTime() + 1.5
    CleveRoids.Print("|cFF4477FFCleveR|r|cFFFFFFFFoid Macros|r |cFF00FF00Loaded|r - See the README.")
end

function CleveRoids.Frame:ADDON_LOADED(addon)
    if addon ~= "CleveRoidMacros" then
        return
    end

    CleveRoids.InitializeExtensions()

    if SuperMacroFrame then
        local hooks = {
            cast = { action = CleveRoids.DoCast },
            target = { action = CleveRoids.DoTarget },
            use = { action = CleveRoids.DoUse },
            castsequence = { action = CleveRoids.DoCastSequence }
        }

        -- Hook SuperMacro's RunLine to stay compatible
        CleveRoids.Hooks.RunLine = RunLine
        CleveRoids.RunLine = function(...)
            for i = 1, arg.n do
                if CleveRoids.stopmacro then
                    CleveRoids.stopmacro = false
                    return true
                end
                local intercepted = false
                local text = arg[i]

                for k,v in pairs(hooks) do
                    local begin, _end = string.find(text, "^/"..k.."%s+[!%[]")
                    if begin then
                        local msg = string.sub(text, _end)
                        v.action(msg)
                        intercepted = true
                        break
                    end
                end

                if not intercepted then
                    CleveRoids.Hooks.RunLine(text)
                end
            end
        end
        RunLine = CleveRoids.RunLine
    end
end

function CleveRoids.Frame:UNIT_CASTEVENT(caster,target,action,spell_id,cast_time)
    if action == "MAINHAND" or action == "OFFHAND" then return end

    -- handle cast spell tracking
    local cast = CleveRoids.spell_tracking[caster]
    if cast_time > 0 and action == "START" or action == "CHANNEL" then
        CleveRoids.spell_tracking[caster] = { spell_id = spell_id, expires = GetTime() + cast_time/1000, type = action }
    elseif cast
        and (
            (cast.spell_id == spell_id and (action == "FAIL" or action == "CAST"))
            or (GetTime() > cast.expires)
        )
    then
        CleveRoids.spell_tracking[caster] = nil
    end

    -- handle cast sequence
    if CleveRoids.currentSequence and caster == CleveRoids.playerGuid then
        local active = CleveRoids.GetCurrentSequenceAction(CleveRoids.currentSequence)

        local name, rank = SpellInfo(spell_id)
        local isSeqSpell = (active.action == name or active.action == (name.."("..rank..")"))
        if isSeqSpell then
            local status = CleveRoids.currentSequence.status
            if status == 0 and (action == "START" or action == "CHANNEL") and cast_time > 0 then
                CleveRoids.currentSequence.status = 1
                CleveRoids.currentSequence.expires = GetTime() + cast_time - 2000
            elseif (status == 0 and action == "CAST" and cast_time == 0)
                or (status == 1 and action == "CAST" and CleveRoids.currentSequence.expires)
            then
                CleveRoids.currentSequence.status = 2
                CleveRoids.currentSequence.lastUpdate = GetTime()
                CleveRoids.AdvanceSequence(CleveRoids.currentSequence)
                CleveRoids.currentSequence = nil
            elseif action == "INTERRUPTED" or action == "FAILED" then
                CleveRoids.currentSequence.status = 1
            end
        end
    end

    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:SPELLCAST_CHANNEL_START()
    CleveRoids.CurrentSpell.type = "channeled"
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:SPELLCAST_CHANNEL_STOP()
    CleveRoids.CurrentSpell.type = ""
    CleveRoids.CurrentSpell.spellName = ""
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:PLAYER_ENTER_COMBAT()
    CleveRoids.CurrentSpell.autoAttack = true
    CleveRoids.CurrentSpell.autoAttackLock = false
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:PLAYER_LEAVE_COMBAT()
    CleveRoids.CurrentSpell.autoAttack = false
    CleveRoids.CurrentSpell.autoAttackLock = false
    for _, sequence in pairs(CleveRoids.Sequences) do
        if CleveRoids.currentSequence ~= sequence and sequence.index > 1 and sequence.reset.combat then
            CleveRoids.ResetSequence(sequence)
        end
    end
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:PLAYER_TARGET_CHANGED()
    CleveRoids.CurrentSpell.autoAttack = false
    CleveRoids.CurrentSpell.autoAttackLock = false

    for _, sequence in pairs(CleveRoids.Sequences) do
        if CleveRoids.currentSequence ~= sequence and sequence.index > 1 and sequence.reset.target then
            CleveRoids.ResetSequence(sequence)
        end
    end
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:UPDATE_MACROS()
    CleveRoids.currentSequence = nil
    -- Explicitly nil tables before re-assignment
    CleveRoids.ParsedMsg = nil;
    CleveRoids.ParsedMsg = {}

    CleveRoids.Macros = nil;
    CleveRoids.Macros = {}

    CleveRoids.Actions = nil;
    CleveRoids.Actions = {}

    CleveRoids.Sequences = nil;
    CleveRoids.Sequences = {}

    CleveRoids.IndexSpells()
    CleveRoids.IndexTalents()
    CleveRoids.IndexActionBars()
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:SPELLS_CHANGED()
    CleveRoids.Frame:UPDATE_MACROS()
end

function CleveRoids.Frame:ACTIONBAR_SLOT_CHANGED()
    CleveRoids.ClearAction(arg1)
    CleveRoids.IndexActionSlot(arg1)
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:BAG_UPDATE()
    local now = GetTime()
    -- Only index items if more than 1 second has passed since the last index
    if (now - (CleveRoids.lastItemIndexTime or 0)) > 1.0 then
        CleveRoids.lastItemIndexTime = now
        CleveRoids.IndexItems()

        -- Directly clear all relevant caches and force a UI refresh for all buttons.
        CleveRoids.Actions = {}
        CleveRoids.Macros = {}
        CleveRoids.ParsedMsg = {}
        CleveRoids.QueueActionUpdate()
    end
end

function CleveRoids.Frame:UNIT_INVENTORY_CHANGED()
    if arg1 ~= "player" then return end
    CleveRoids.Frame:BAG_UPDATE()
end

function CleveRoids.Frame:START_AUTOREPEAT_SPELL()
    local _, className = UnitClass("player")
    if className == "HUNTER" then
        CleveRoids.CurrentSpell.autoShot = true
    else
        CleveRoids.CurrentSpell.wand = true
    end
    CleveRoids.QueueActionUpdate()
end

function CleveRoids.Frame:STOP_AUTOREPEAT_SPELL()
    local _, className = UnitClass("player")
    if className == "HUNTER" then
        CleveRoids.CurrentSpell.autoShot = false
    else
        CleveRoids.CurrentSpell.wand = false
    end
    CleveRoids.QueueActionUpdate()
end

-- Generic event handlers that just queue an update
function CleveRoids.Frame:PLAYER_FOCUS_CHANGED() CleveRoids.QueueActionUpdate() end
function CleveRoids.Frame:UPDATE_SHAPESHIFT_FORM() CleveRoids.QueueActionUpdate() end
function CleveRoids.Frame:SPELL_UPDATE_COOLDOWN() CleveRoids.QueueActionUpdate() end
function CleveRoids.Frame:UNIT_AURA() CleveRoids.QueueActionUpdate() end
function CleveRoids.Frame:UNIT_HEALTH() CleveRoids.QueueActionUpdate() end
function CleveRoids.Frame:UNIT_POWER() CleveRoids.QueueActionUpdate() end


CleveRoids.Hooks.SendChatMessage = SendChatMessage
function SendChatMessage(msg, ...)
    if msg and string.find(msg, "^#showtooltip") then
        return
    end
    CleveRoids.Hooks.SendChatMessage(msg, unpack(arg))
end

CleveRoids.RegisterActionEventHandler = function(fn)
    if type(fn) == "function" then
        table.insert(CleveRoids.actionEventHandlers, fn)
    end
end

CleveRoids.RegisterMouseOverResolver = function(fn)
    if type(fn) == "function" then
        table.insert(CleveRoids.mouseOverResolvers, fn)
    end
end


-- Bandaid so pfUI doesn't need to be edited
-- pfUI/modules/thirdparty-vanilla.lua:914
CleverMacro = true

---- START of pfUI Focus Fix ----
do
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function(self, event, arg1)
        if event == "PLAYER_LOGIN" then
            -- This ensures we wait until the player is fully in the world and all addons are loaded.
            self:UnregisterEvent("PLAYER_LOGIN")

            -- Ensure both pfUI and its focus module are loaded before attempting to hook.
            -- This also checks that the slash command we want to modify exists.
            if pfUI and pfUI.uf and pfUI.uf.focus and SlashCmdList.PFFOCUS then

                local original_PFFOCUS_Handler = SlashCmdList.PFFOCUS
                SlashCmdList.PFFOCUS = function(msg)
                    -- First, execute the original /focus command from pfUI to set the unit name.
                    original_PFFOCUS_Handler(msg)

                -- Now, if a focus name was set, find the corresponding UnitID.
                if pfUI.uf.focus.unitname then
                    local focusName = pfUI.uf.focus.unitname
                    local found_label, found_id = nil, nil

                    -- This function iterates through all known friendly units to find a
                    -- name match and return its specific UnitID components.
                    local function findUnitID()
                        -- Check party members and their pets
                        for i = 1, GetNumPartyMembers() do
                            if strlower(UnitName("party"..i) or "") == focusName then
                                return "party", i
                            end
                            if UnitExists("partypet"..i) and strlower(UnitName("partypet"..i) or "") == focusName then
                                return "partypet", i
                            end
                        end

                        -- Check raid members and their pets
                        for i = 1, GetNumRaidMembers() do
                            if strlower(UnitName("raid"..i) or "") == focusName then
                                return "raid", i
                            end
                            if UnitExists("raidpet"..i) and strlower(UnitName("raidpet"..i) or "") == focusName then
                                return "raidpet", i
                            end
                        end

                        -- Check player and pet
                        if strlower(UnitName("player") or "") == focusName then return "player", nil end
                        if UnitExists("pet") and strlower(UnitName("pet") or "") == focusName then return "pet", nil end

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
    end)
    f:RegisterEvent("PLAYER_LOGIN")
    end
    ---- END of pfUI Focus Fix ----
