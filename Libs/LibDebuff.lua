-- Only load if pfUI's libdebuff is not available
if pfUI and pfUI.api and pfUI.api.libdebuff then return end

local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
_G.CleveRoids = CleveRoids

-- Namespace (pfUI-like shape under our own API)
CleveRoids.api = CleveRoids.api or {}
local CRLib = {
  -- pfUI-like surface for opportunistic lookups by (unranked) spell name
  Durations = {},                 -- [spellName] = seconds (learned)
  learnedDurById = {},            -- [spellID] = seconds (learned, moving avg)
  pendingApply   = {},            -- [targetGUID] = { [spellID] = appliedAt }
}
CleveRoids.api.libdebuff = CRLib

-- Simple moving-average to stabilize learned durations
local function Learn(spellID, sample)
  if not spellID or not sample or sample <= 0 or sample > 600 then return end
  local cur = CRLib.learnedDurById[spellID]
  if not cur then
    CRLib.learnedDurById[spellID] = sample
  else
    CRLib.learnedDurById[spellID] = (cur * 0.7) + (sample * 0.3)
  end
  -- Also keep a name-keyed mirror for compatibility with callers that expect pfUI.api.libdebuff.Durations[name]
  if SpellInfo then
    local name = SpellInfo(spellID)
    if name and name ~= "" then
      name = string.gsub(name, "%s*%(%s*Rank%s+%d+%s*%)", "")
      CRLib.Durations[name] = CRLib.learnedDurById[spellID]
    end
  end
end

-- Helper: return learned base duration for a spellID
function CRLib:GetDurationBySpellID(spellID)
  return self.learnedDurById[spellID]
end

-- A) SuperWoW: when a spell is successfully CAST, mark applied time
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("UNIT_CASTEVENT")
  f:SetScript("OnEvent", function()
    local casterGUID, targetGUID, evType, spellId = arg1, arg2, arg3, arg4
    if evType ~= "CAST" or not targetGUID or not spellId then return end
    CRLib.pendingApply[targetGUID] = CRLib.pendingApply[targetGUID] or {}
    CRLib.pendingApply[targetGUID][spellId] = GetTime()
  end)
end

-- B) Learn from RAW_COMBATLOG fades: “… <Spell> fades from <unit> (GUID:0x…)”
do
  local function parseFade(line)
    local spell = string.match(line, "^(.-) fades from ")
    local guid  = string.match(line, "GUID:([%x]+)")
    return spell, guid
  end

  local f = CreateFrame("Frame")
  f:RegisterEvent("RAW_COMBATLOG")
  f:SetScript("OnEvent", function()
    local raw = arg2
    if not raw or not string.find(raw, "fades from") then return end

    local spellName, targetGUID = parseFade(raw)
    if not spellName or not targetGUID then return end

    -- normalize name (strip rank) to compare
    spellName = string.gsub(spellName, "%s*%(%s*Rank%s+%d+%s*%)", "")

    local pend = CRLib.pendingApply[targetGUID]
    if not pend then return end

    -- try to match pending spellIDs by comparing names from SpellInfo(spellID)
    local now = GetTime()
    for spellID, appliedAt in pairs(pend) do
      local name = SpellInfo and SpellInfo(spellID)
      if name then
        name = string.gsub(name, "%s*%(%s*Rank%s+%d+%s*%)", "")
      end
      if name == spellName then
        local sample = now - (appliedAt or now)
        if sample > 2 then          -- ignore obvious dispels / noise
          Learn(spellID, sample)
        end
        pend[spellID] = nil
        -- don’t break; in case multiple ranks share same unranked name, we still clear the matched one
        break
      end
    end
  end)
end

local function norm(g)
  if not g then return nil end
  g = string.gsub(g, "^0x", "")
  return string.upper(g)
end

local function strip_rank(name)
  return name and string.gsub(name, "%s*%(%s*Rank%s+%d+%s*%)", "")
end

-- Try to resolve a base duration for a spellID:
local function get_base_duration(spellID)
  -- 1) pfUI’s known durations by unranked name
  if SpellInfo and pfUI and pfUI.api and pfUI.api.libdebuff then
    local n = SpellInfo(spellID)
    n = strip_rank(n)
    local d = pfUI.api.libdebuff.Durations[n]
    if d and d > 0 then return d end
  end
  -- 2) Learned (moving average) durations from this file
  local d = CleveRoids.api.libdebuff:GetDurationBySpellID(spellID)
  if d and d > 0 then return d end
  -- 3) Fallback: unknown
  return nil
end

