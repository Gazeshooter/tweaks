-- Tweaks_MobReputation: safe Forever tooltip post-hook, standing-aware
-- vanilla baselines, optional manually confirmed rules, and cautious
-- solo-kill observations. Does not access the combat log.
local addonName, ns = ...
local floor = math.floor
local tinsert = table.insert
local standingNames = {
    "Hated", "Hostile", "Unfriendly", "Neutral",
    "Friendly", "Honored", "Revered", "Exalted", "Exalted",
}
local factionIDs = {}
local snapshots = {}
local db
local pending = false
local recentDeadNpc
local recentDeadAt = 0
local lastSeenNpc
local hasTooltipProcessor = TooltipDataProcessor
    and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit

local function safe(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function npcIDFromGUID(guid)
    if not safe(guid) or type(guid) ~= "string" then return end
    local unitType, id = guid:match("^([^-]+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end
    return tonumber(id)
end

local function unitGUID(unit)
    if not safe(unit) or type(unit) ~= "string" then return end
    local success, result = pcall(UnitGUID, unit)
    if success and safe(result) then return result end
end

local function lookupFaction(fid)
    if not C_Reputation or not C_Reputation.GetFactionDataByID then return end
    local ok, info = pcall(C_Reputation.GetFactionDataByID, fid)
    if ok and type(info) == "table" then return info end
end

local function factionName(fid, info)
    local name = info and info.name
    return safe(name) and type(name) == "string" and name
        or ns.FallbackFactionNames[fid] or ("Faction " .. fid)
end

local function reaction(info)
    local r = info and info.reaction
    return safe(r) and type(r) == "number" and r >= 1 and r <= 8
        and floor(r) or nil
end

local function snapshotFactions()
    local result = {}
    if not C_Reputation then return result end
    if C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        local ok, count = pcall(C_Reputation.GetNumFactions)
        if ok and safe(count) and type(count) == "number" then
            for i = 1, math.min(count, 400) do
                local valid, info = pcall(C_Reputation.GetFactionDataByIndex, i)
                if valid and type(info) == "table" and safe(info.factionID)
                    and type(info.factionID) == "number" then
                    factionIDs[info.factionID] = true
                end
            end
        end
    end
    for fid in pairs(factionIDs) do
        local info = lookupFaction(fid)
        local value = info and info.currentStanding
        if safe(value) and type(value) == "number" then
            result[fid] = { value = value, rank = reaction(info) }
        end
    end
    return result
end

local function refreshFactionIDs()
    for _, rewards in pairs(ns.Vanilla) do
        for _, rule in ipairs(rewards) do factionIDs[rule[1]] = true end
    end
    for _, rewards in pairs(db.manual or {}) do
        for fid in pairs(rewards) do factionIDs[tonumber(fid)] = true end
    end
end

local function hasSoloDeadTarget()
    if GetNumGroupMembers and GetNumGroupMembers() > 0 then return end
    if IsInInstance then
        local ok, inInstance = pcall(IsInInstance)
        if ok and inInstance then return end
    end
    local guid = unitGUID("target")
    local npc = npcIDFromGUID(guid)
    if not npc then return end
    if not UnitIsDead then return end
    local ok, dead = pcall(UnitIsDead, "target")
    if not ok or not safe(dead) or dead ~= true then return end
    return npc
end

local function acceptObservation(npc, fid, value, rank)
    -- A single kill cannot be proven to be responsible for a faction event.
    -- Require two matching solo/corpse associations at the same standing.
    if not rank or type(value) ~= "number" or value == 0 or math.abs(value) > 10000 then
        return
    end
    local byNpc = db.observed[npc] or {}
    db.observed[npc] = byNpc
    local existing = byNpc[fid]
    if existing and existing.amount == value and existing.rank == rank then
        existing.count = math.min(50, (existing.count or 1) + 1)
    else
        byNpc[fid] = {amount = value, rank = rank, count = 1}
    end
end

local function captureAfterFactionGain()
    pending = false
    local fresh = snapshotFactions()
    local npc = recentDeadNpc
    -- Reject events if corpse attribution has expired.
    if not npc or GetTime() - recentDeadAt > 2 then
        snapshots = fresh
        return
    end
    for fid, now in pairs(fresh) do
        local old = snapshots[fid]
        if old and now.value ~= old.value and now.rank then
            acceptObservation(npc, fid, now.value - old.value, now.rank)
        end
    end
    snapshots = fresh
end

local function onFactionChat()
    -- This chat event alone has no mob GUID. Association is strictly
    -- provisional, requiring a dead *current target*, solo, and repetition.
    recentDeadNpc = hasSoloDeadTarget()
    recentDeadAt = GetTime()
    if not pending and C_Timer and C_Timer.After then
        pending = true
        C_Timer.After(0.2, captureAfterFactionGain)
    end
end

local function findRules(npc)
    local merged, byFaction = {}, {}
    local function add(fid, amount, cap, source)
        if not fid or not amount then return end
        local rule = {fid=fid, amount=amount, cap=cap or 9, source=source}
        if byFaction[fid] then
            merged[byFaction[fid]] = rule
        else
            tinsert(merged, rule)
            byFaction[fid] = #merged
        end
    end
    for _, record in ipairs(ns.Vanilla[npc] or {}) do
        add(record[1], record[2], record[3], "Classic estimate")
    end
    for fid, observation in pairs(db.observed[npc] or {}) do
        local current = reaction(lookupFaction(fid))
        if observation.count >= 2 and observation.rank == current then
            -- Observed values are standing-specific and override the BASE
            -- amount at exactly the standing where they were seen.
            local cap = (byFaction[fid] and merged[byFaction[fid]].cap) or 9
            add(fid, observation.amount, cap, "observed (solo)")
        end
    end
    for fid, override in pairs(db.manual[npc] or {}) do
        add(fid, override.amount, override.cap, "manual")
    end
    table.sort(merged, function(a,b) return a.fid < b.fid end)
    return merged
end

local function writeTooltip(tooltip, npc)
    if not db or db.disabled or not npc or not tooltip or not tooltip.AddLine then return end
    local rules = findRules(npc)
    if #rules == 0 and not db.debug then return end
    for _, r in ipairs(rules) do
        local info = lookupFaction(r.fid)
        local standing = reaction(info)
        local name = factionName(r.fid, info)
        local text, cr, cg, cb
        if standing and standing >= r.cap or standing == 8 then
            text = name .. ": no kill rep (cap: " .. standingNames[r.cap] .. ")"
            cr, cg, cb = 0.65, 0.65, 0.65
        else
            local n = r.amount
            local sign = n > 0 and "+" or ""
            text = "Rep: " .. sign .. n .. " " .. name
                .. " (" .. r.source
            if r.cap < 9 then text = text .. "; until " .. standingNames[r.cap] end
            if not standing then text = text .. "; standing unknown" end
            if info and info.hasBonusRepGain and r.source ~= "observed (solo)" then
                text = text .. "; bonuses may apply"
            end
            text = text .. ")"
            if n >= 0 then cr, cg, cb = 0.48, 0.86, 0.52
            else cr, cg, cb = 0.95, 0.45, 0.45 end
        end
        tooltip:AddLine(text, cr, cg, cb, true)
    end
    if db.debug then
        tooltip:AddLine("MobRep NPC ID: " .. npc, 0.7, 0.7, 0.95)
    end
end

local function onUnitTooltip(tooltip, data)
    if tooltip ~= GameTooltip or not db then return end
    local guid = data and data.guid
    if not safe(guid) then guid = nil end
    if not guid and tooltip.GetUnit then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if ok and unit then guid = unitGUID(unit) end
    end
    if not guid then guid = unitGUID("mouseover") end
    local npc = npcIDFromGUID(guid)
    if npc then
        lastSeenNpc = npc
        writeTooltip(tooltip, npc)
    end
end

local function printLine(message)
    print("|cff89d9a8Tweaks MobRep:|r " .. message)
end

local function parseRank(arg)
    if not arg or arg == "" or arg:lower() == "none" then return 9 end
    local n = tonumber(arg)
    if n and n >= 1 and n <= 9 then return floor(n) end
    for i, name in ipairs(standingNames) do
        if name:lower() == arg:lower() then return i end
    end
end

SLASH_TWEAKSMOBREP1 = "/mobrep"
SlashCmdList.TWEAKSMOBREP = function(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "debug" or cmd == "learn" then
        local field = cmd == "debug" and "debug" or "learn"
        local value = rest:lower()
        if value == "on" then db[field] = true
        elseif value == "off" then db[field] = false
        else db[field] = not db[field] end
        printLine(field .. " = " .. tostring(db[field]))
    elseif cmd == "add" then
        local npc, fid, amount, capName = rest:match("^(%d+)%s+(%d+)%s+([%+%-]?%d+)%s*(%S*)")
        npc, fid, amount = tonumber(npc), tonumber(fid), tonumber(amount)
        local cap = parseRank(capName)
        if npc and fid and amount and cap then
            db.manual[npc] = db.manual[npc] or {}
            db.manual[npc][fid] = {amount = amount, cap = cap}
            factionIDs[fid] = true
            printLine("Manual rule saved for NPC " .. npc .. ", faction " .. fid)
        else
            printLine("Usage: /mobrep add NPC_ID FACTION_ID AMOUNT [capRank|none]")
        end
    elseif cmd == "del" then
        local npc = tonumber(rest)
        if npc then
            db.manual[npc] = nil
            db.observed[npc] = nil
            printLine("Cleared personal data for NPC " .. npc .. " (Classic table unchanged)")
        end
    elseif cmd == "status" then
        local count = 0
        for _ in pairs(ns.Vanilla) do count = count + 1 end
        printLine(count .. " Vanilla NPC entries; learning " .. (db.learn and "on" or "off")
            .. "; debug " .. (db.debug and "on" or "off"))
        printLine("Last mouseover NPC: " .. tostring(lastSeenNpc or "none"))
    else
        printLine("/mobrep status | debug [on|off] | learn [on|off]")
        printLine("/mobrep add NPC_ID FACTION_ID AMOUNT [capRank|none] | del NPC_ID")
        printLine("Cap rank 7 = stops on Revered. Learn requires two solo observations.")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if type(TweaksMobReputationDB) ~= "table" then TweaksMobReputationDB = {} end
        db = TweaksMobReputationDB
        if type(db.manual) ~= "table" then db.manual = {} end
        if type(db.observed) ~= "table" then db.observed = {} end
        if db.learn == nil then db.learn = true end
        refreshFactionIDs()
        snapshots = snapshotFactions()
        if hasTooltipProcessor then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnitTooltip)
        else
            printLine("No modern unit-tooltip processor found; tooltip display unavailable")
        end
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if db and db.learn then onFactionChat() end
    elseif event == "UPDATE_FACTION" and db and not pending then
        snapshots = snapshotFactions()
    end
end)