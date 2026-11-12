-- Tweaks: Questie Lookahead (+3) v1.2.0 for WoW Forever / Questie 12.6.5
-- Standalone companion addon. No Questie source files are modified; icon selection is saved in the Questie profile.
-- Shows *minimum required level* (not displayed quest level) from player+1 to player+3.

local loader = QuestieLoader
local Questie = _G.Questie
if not loader or not loader.ImportModule or not Questie then return end

local available = loader:ImportModule("AvailableQuests")
local db = loader:ImportModule("QuestieDB")
local lib = loader:ImportModule("QuestieLib")
local map = loader:ImportModule("QuestieMap")
local tooltips = loader:ImportModule("QuestieTooltips")
local threadLib = loader:ImportModule("ThreadLib")
local active = loader:ImportModule("ActiveQuests")
local corrections = loader:ImportModule("QuestieCorrections")
local blacklist = loader:ImportModule("QuestieQuestBlacklist")
local isle = loader:ImportModule("IsleOfQuelDanas")
local tooltipLayout = loader:ImportModule("TooltipLayout")

if not (available and db and lib and map and tooltips and threadLib and active) then return end
if type(available.CalculateAndDrawAll) ~= "function" or
   type(available.DrawAvailableQuest) ~= "function" or
   type(db.QueryQuestSingle) ~= "function" then return end
if available.TweaksLookaheadInstalled then return end
available.TweaksLookaheadInstalled = true

local LOOKAHEAD = 3
local indexed = false
local byRequiredLevel = {}
local minRequiredByQuest = {}
-- This tracks only starter icons introduced by this module. Normal Questie icons are never owned.
local ourStarters = {}
local busy, pending = false, false
local lastVisibleCount = 0
local lastPlayerLevel = 0

-- Icon choices match Questie's existing Icon Overrides dropdowns.
-- Save under the Questie profile so the choice follows the currently selected profile.
local ICON_PROFILE_KEY = "TWEAKS_LOOKAHEAD_ICON"
-- Recoloured original pfQuest "available" texture, bundled in this module.
local PFQUEST_RED_PATH = [[Interface\AddOns\Tweaks_QuestieLookahead\Icons\pfquest_red.tga]]
local function IconPath(key)
    if key == "pfquest_red" then return PFQUEST_RED_PATH end
    return Questie.icons[key]
end
local ICON_CHOICES = {
    "pfquest_red",
    "slay", "slay_mono", "loot", "loot_mono", "object", "object_mono", "event", "talk", "interact",
    "available", "available_gray", "incomplete", "complete", "repeatable", "repeatable_complete",
    "eventquest", "eventquest_complete", "pvpquest", "pvpquest_complete", "startend", "startendstart",
    "node", "node_cut", "route", "player", "fav", "hand", "faction_alliance", "faction_horde",
    "tracker_clean", "tracker_close", "tracker_database", "tracker_giver", "tracker_quests",
    "tracker_search", "tracker_settings",
}
local ICON_LABELS = {
    pfquest_red = "pfQuest red exclamation",
    slay = "Slay", slay_mono = "Slay mono", loot = "Loot", loot_mono = "Loot mono",
    object = "Object", object_mono = "Object mono", event = "Event", talk = "Talk",
    interact = "Interact", available = "Available", available_gray = "Available gray",
    incomplete = "Incomplete", complete = "Complete", repeatable = "Repeatable",
    repeatable_complete = "Repeatable Complete", eventquest = "Event Quest",
    eventquest_complete = "Event Quest Complete", pvpquest = "PvP Quest",
    pvpquest_complete = "PvP Quest Complete", startend = "Start and end",
    startendstart = "Start and unfinished", node = "pfQuest/Codex node",
    node_cut = "pfQuest/Codex node cut center", route = "Route waypoint",
    player = "Party marker", fav = "Favourite", hand = "Hand",
    faction_alliance = "Alliance", faction_horde = "Horde", tracker_clean = "Clean",
    tracker_close = "Close", tracker_database = "Pin", tracker_giver = "Available white",
    tracker_quests = "Book", tracker_search = "Search", tracker_settings = "Settings",
}

local function SelectedIconKey()
    local profile = Questie.db and Questie.db.profile
    local key = profile and profile[ICON_PROFILE_KEY] or "available_gray"
    if type(key) ~= "string" or not IconPath(key) then return "available_gray" end
    return key
end

local function SelectedIconPath()
    return IconPath(SelectedIconKey()) or Questie.icons["available_gray"]
end

local function IconOptions()
    local out = {}
    for _, key in ipairs(ICON_CHOICES) do
        local path = IconPath(key)
        if path then
            out[key] = "|T" .. path .. ":0|t " .. ICON_LABELS[key]
        end
    end
    return out
end

local function IconSortOrder()
    return ICON_CHOICES
end

-- Paint only our own map/minimap frames. This does not modify Questie's shared
-- ICON_AVAILABLE_GRAY and cannot change ordinary unavailable/trivial quests.
local function PaintLookaheadFrames(id)
    if not ourStarters[id] or (available.__availableQuests and available.__availableQuests[id]) then return end
    local texture = SelectedIconPath()
    if not texture then return end
    for _, frame in pairs(map:GetFramesForQuest(id)) do
        if frame and frame.data and frame.data.Type == "available" and frame.UpdateTexture then
            frame:UpdateTexture(texture)
        end
    end
end

local function PaintAllLookaheadFrames()
    for id in pairs(ourStarters) do
        PaintLookaheadFrames(id)
    end
end

local function SetIconChoice(key)
    if type(key) ~= "string" or not IconPath(key) then return end
    if Questie.db and Questie.db.profile then
        Questie.db.profile[ICON_PROFILE_KEY] = key
        PaintAllLookaheadFrames()
    end
end

-- The native Questie settings and the older AceConfig settings have different
-- table schemas. Extend both at their public tab construction points, leaving
-- the bundled Questie files untouched and avoiding a global icon override.
local function ExtendIconSettings()
    local engine = loader:ImportModule("QuestieOptionsEngine")
    local legacy = loader:ImportModule("QuestieOptions")
    if engine and engine.tabs and engine.tabs.icons and type(engine.tabs.icons.Initialize) == "function" then
        local tab = engine.tabs.icons
        local nativeInitialize = tab.Initialize
        function tab:Initialize(...)
            local result = nativeInitialize(self, ...)
            local group = result and result.items and result.items.icon_overrides_group
            if group and group.items then
                group.items.tweaksQuestieLookaheadIcon = {
                    type = "dropdown",
                    order = 7.5, -- after Interact objectives, before the Quests divider
                    title = "Upcoming quests (+3)",
                    tooltip = "Map and minimap icon for quests that unlock in the next three levels. Only affects markers added by Tweaks Questie Lookahead.",
                    width = "third",
                    options = IconOptions,
                    sortOrder = IconSortOrder,
                    enabled = function() return Questie.db and Questie.db.profile and Questie.db.profile.enabled end,
                    get = SelectedIconKey,
                    set = SetIconChoice,
                }
            end
            return result
        end
    end
    if legacy and legacy.tabs and legacy.tabs.icons and type(legacy.tabs.icons.Initialize) == "function" then
        local tab = legacy.tabs.icons
        local legacyInitialize = tab.Initialize
        function tab:Initialize(...)
            local result = legacyInitialize(self, ...)
            local group = result and result.args and result.args.iconOverrides
            if group and group.args then
                group.args.tweaksQuestieLookaheadIcon = {
                    type = "select",
                    order = 21.5, -- after Interact objectives, before the Quests header
                    values = IconOptions,
                    sorting = IconSortOrder(),
                    style = "dropdown",
                    width = 0.796,
                    name = "Upcoming quests (+3)",
                    desc = "Map and minimap icon for quests that unlock in the next three levels. Only affects markers added by Tweaks Questie Lookahead.",
                    disabled = function() return not (Questie.db and Questie.db.profile and Questie.db.profile.enabled) end,
                    get = SelectedIconKey,
                    set = function(_, key) SetIconChoice(key) end,
                }
            end
            return result
        end
    end
end
ExtendIconSettings()

-- Map icons are pooled and can be recreated without a full quest recalculation.
-- The secure post-hook repaints a frame only when the quest belongs to Lookahead.
if type(map.DrawWorldIcon) == "function" and hooksecurefunc then
    hooksecurefunc(map, "DrawWorldIcon", function(_, data)
        if data and data.Type == "available" and ourStarters[data.Id] then
            PaintLookaheadFrames(data.Id)
        end
    end)
end

local function PlayerLevel()
    return UnitLevel("player") or 0
end

-- Questie scans its entire quest DB already. Build a one-time minimum-level index
-- in small batches so subsequent refreshes only inspect the next three levels.
local function BuildIndex()
    if indexed then return true end
    if not db.QuestPointers then return false end
    local count = 0
    for id in pairs(db.QuestPointers) do
        local req = db.QueryQuestSingle(id, "requiredLevel")
        if type(req) == "number" and req > 0 then
            if not byRequiredLevel[req] then byRequiredLevel[req] = {} end
            byRequiredLevel[req][#byRequiredLevel[req] + 1] = id
            minRequiredByQuest[id] = req
        end
        count = count + 1
        if count % 250 == 0 then coroutine.yield() end
    end
    indexed = true
    return true
end

local function HasStarterFrame(id)
    for _, frame in pairs(map:GetFramesForQuest(id)) do
        if frame and frame.data and frame.data.Type == "available" then
            return true
        end
    end
    return false
end

-- Match Questie's own available-quest policy, except the level check itself.
local function IsEligible(id, playerLevel)
    local req = minRequiredByQuest[id]
    if not req or req <= playerLevel or req > playerLevel + LOOKAHEAD then return false end
    local _, effectiveReq, maxReq = lib.GetEffectiveQuestLevel(id, playerLevel)
    if not effectiveReq or effectiveReq <= playerLevel or effectiveReq > playerLevel + LOOKAHEAD then
        return false
    end
    if maxReq and maxReq ~= 0 and playerLevel > maxReq then return false end

    local profile = Questie.db and Questie.db.profile
    local character = Questie.db and Questie.db.char
    if not profile or not character or not profile.enabled or not profile.showAvailableQuests then return false end
    if (character.complete and character.complete[id]) or (character.hidden and character.hidden[id]) then return false end
    if (character.TrackerHiddenQuests and character.TrackerHiddenQuests[id]) then return false end
    if active.Get(id) or (db.autoBlacklist and db.autoBlacklist[id]) then return false end
    if corrections and corrections.hiddenQuests and corrections.hiddenQuests[id] then return false end
    local realm = GetRealmName()
    local global = Questie.db.global
    local spoken = global and global.unavailableQuestsDeterminedByTalking
    if spoken and spoken[realm] and spoken[realm][id] then return false end

    if ((not profile.showRepeatableQuests) and db.IsRepeatable(id)) or
       ((not profile.showPvPQuests) and db.IsPvPQuest(id)) or
       ((not profile.showDungeonQuests) and db.IsDungeonQuest(id)) or
       ((not profile.showRaidQuests) and db.IsRaidQuest(id)) then
        return false
    end
    if not profile.showAQWarEffortQuests and blacklist and blacklist.AQWarEffortQuests
       and blacklist.AQWarEffortQuests[id] then return false end
    if Questie.IsClassic and isle and isle.quests and
       isle.quests[profile.isleOfQuelDanasPhase] and
       isle.quests[profile.isleOfQuelDanasPhase][id] then return false end
    if Questie.IsSoD and db.IsRuneAndShouldBeHidden(id) then return false end

    -- This honours faction/race, class, profession, reputation, chain prerequisites,
    -- exclusivity and any other Questie eligibility requirements.
    return db.IsDoable(id, profile.debugEnabled) == true
end

local function RefreshCoroutine()
    if not BuildIndex() then return end
    local level = PlayerLevel()
    if level <= 0 then return end
    lastPlayerLevel = level
    local desired = {}
    local seen = 0
    for req = level + 1, level + LOOKAHEAD do
        for _, id in ipairs(byRequiredLevel[req] or {}) do
            if IsEligible(id, level) then desired[id] = true end
            seen = seen + 1
            if seen % 35 == 0 then coroutine.yield() end
        end
    end

    -- Hand icons over to native Questie when a quest becomes available. Native
    -- Questie reuses the frame and changes its grey texture to the normal one.
    -- Remove our own markers only if Questie has NOT taken over that quest.
    local native = available.__availableQuests or {}
    local toRemove = {}
    for id in pairs(ourStarters) do
        if native[id] then
            ourStarters[id] = nil
            -- In case Questie reused the frame, restore its native texture.
            for _, frame in pairs(map:GetFramesForQuest(id)) do
                if frame and frame.data and frame.data.Type == "available" and frame.data.QuestData then
                    local iconType = lib.GetQuestIcon(frame.data.QuestData)
                    if Questie.usedIcons[iconType] and frame.UpdateTexture then
                        frame:UpdateTexture(Questie.usedIcons[iconType])
                    end
                end
            end
        elseif not desired[id] then
            ourStarters[id] = nil
            toRemove[#toRemove + 1] = id
        elseif not HasStarterFrame(id) then
            -- Questie cleared/rebuilt its map icon pool; redraw on this pass.
            ourStarters[id] = nil
        end
    end
    for _, id in ipairs(toRemove) do
        available.RemoveQuest(id) -- uses Questie's own asynchronous frame/tooltip cleanup
    end

    local added = 0
    for id in pairs(desired) do
        if not native[id] and not ourStarters[id] then
            if HasStarterFrame(id) then
                -- An icon from a user's own Questie level filter already exists.
                -- Do not duplicate it or take ownership of it.
            else
                local quest = db.GetQuest(id)
                if quest and quest.Starts then
                    if not quest.tagInfoWasCached then
                        db.GetQuestTagInfo(id)
                        quest.tagInfoWasCached = true
                    end
                    -- Assign ownership before drawing, so QuestieMap's frame
                    -- creation hook can apply our independently selected texture.
                    ourStarters[id] = true
                    available.DrawAvailableQuest(quest)
                    if HasStarterFrame(id) then
                        PaintLookaheadFrames(id)
                        added = added + 1
                    else
                        ourStarters[id] = nil
                    end
                end
            end
        end
        seen = seen + 1
        if seen % 15 == 0 then coroutine.yield() end
    end
    -- Refresh custom textures after theme/profile changes or partial map redraws.
    PaintAllLookaheadFrames()
    local visible = 0
    for _ in pairs(ourStarters) do visible = visible + 1 end
    lastVisibleCount = visible
end

local QueueRefresh
QueueRefresh = function()
    if busy then
        pending = true
        return
    end
    if not db.QuestPointers then return end
    busy = true
    threadLib.Thread(RefreshCoroutine, 0,
        "Tweaks Questie Lookahead refresh failed",
        function()
            busy = false
            if pending then pending = false; QueueRefresh() end
        end,
        function(err)
            busy = false
            if _G.DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Tweaks Questie Lookahead:|r " .. tostring(err))
            end
            -- Avoid an automatic retry loop on an unsupported Questie update.
            pending = false
        end,
        "Tweaks.QuestieLookahead")
end

-- Normal Questie recalculations already respond to level-ups, quest completion,
-- reputation updates and settings changes. Use their completion callback to refresh
-- *after* the base marker pass, not during it. No Questie function is replaced.
local nativeCalculate = available.CalculateAndDrawAll
function available.CalculateAndDrawAll(callback)
    return nativeCalculate(function()
        if callback then callback() end
        QueueRefresh()
    end)
end

-- Rewrite ONLY module-owned upcoming quest rows, not Questie's ordinary quest rows.
-- Questie normally formats these as: [50] Quest Name (Available). Do not reuse
-- GetColoredQuestName, because it includes difficulty colour, a level prefix and
-- optional tags/quest IDs. Use the actual quest name directly from QuestieDB.
-- Keep any leading transparent indentation or reputation texture intact.
-- This is compatible with the separate Tweaks_QuestieChainXP Render wrapper.
if tooltipLayout and type(tooltipLayout.Render) == "function" then
    local nativeRender = tooltipLayout.Render
    function tooltipLayout:Render(tooltip, rows)
        if type(rows) == "table" and not rows.TweaksLookaheadDone and tooltip
            and tooltip._owner and tooltip._showData
            and tooltip._owner.data == tooltip._showData
            and type(tooltip.npcAndObjectOrder) == "table" then
            rows.TweaksLookaheadDone = true
            local titles = {}
            for _, quests in pairs(tooltip.npcAndObjectOrder) do
                for _, quest in pairs(quests) do
                    if ourStarters[quest.questId] and type(quest.title) == "string" then
                        local name = db.QueryQuestSingle(quest.questId, "name")
                        local required = minRequiredByQuest[quest.questId]
                        if type(name) == "string" and required then
                            titles[quest.title] = {name = name, required = required}
                        end
                    end
                end
            end
            for _, row in ipairs(rows) do
                if row.kind == "doubleLine" and type(row.leftText) == "string" then
                    for title, info in pairs(titles) do
                        if row.leftText == title or row.leftText:find(title, 1, true) then
                            -- Questie optionally prefixes rows with a texture for indentation.
                            local prefix = row.leftText:match("^(|T.-|t%s*)") or ""
                            row.leftText = prefix .. "|cff999999" .. info.name ..
                                " [Unlocks at " .. info.required .. "]|r"
                            -- Remove (Available) and the Shift XP/money reward from this
                            -- one pending quest row, keeping the display unambiguous.
                            row.rightText = ""
                            break
                        end
                    end
                end
            end
        end
        return nativeRender(self, tooltip, rows)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event)
    -- An entering-world refresh also handles first load, where Questie may still
    -- be constructing its DB when this module's files first load.
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, QueueRefresh)
    else
        C_Timer.After(0.6, QueueRefresh)
    end
end)

SLASH_TWEAKSQUESTIELOOKAHEAD1 = "/tlookahead"
SlashCmdList.TWEAKSQUESTIELOOKAHEAD = function()
    QueueRefresh()
    local s = "Tweaks Questie Lookahead: level " .. (lastPlayerLevel > 0 and lastPlayerLevel or PlayerLevel()) ..
              ", preview +" .. LOOKAHEAD .. ", " .. lastVisibleCount .. " additional quest(s) currently drawn."
    DEFAULT_CHAT_FRAME:AddMessage(s)
end
