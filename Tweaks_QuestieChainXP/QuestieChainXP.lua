-- Questie Chain XP - WoW Forever / Questie 12.6.5
-- Independent companion addon; does not modify Questie's files.
--
-- Questie renders its map-icon tooltips from a table of rows.  Intercepting
-- that table before it is rendered lets us preserve Questie's layout and
-- formatting, including descriptions, money rewards and quest colours.

local loader = QuestieLoader
if not loader or not loader.ImportModule then
    return
end

local tooltipLayout = loader:ImportModule("TooltipLayout")
local l10n = loader:ImportModule("l10n")

if not tooltipLayout or type(tooltipLayout.Render) ~= "function" then
    return
end

-- Guard against accidental double installation on a UI reload.
if tooltipLayout.QuestieChainXPInstalled then
    return
end
tooltipLayout.QuestieChainXPInstalled = true

local originalRender = tooltipLayout.Render
local nextInChainLabel = l10n and l10n("Next in chain") or "Next in chain"

-- UnitXPMax is the XP requirement of the player's *current* level.
-- It is read for every tooltip rebuild, not cached at addon load.
local function levelPercent(xp, xpMax)
    if not xpMax or xpMax <= 0 then
        return nil
    end
    return math.floor(100 * xp / xpMax + 0.5)
end

local function commaNumber(n)
    local str = tostring(math.floor(n))
    return str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Preserve the colour markup surrounding an existing reward.  Only the
-- inner "(3,150xp)" is changed to "(3,150xp, 5%)".
-- Returns the unmodified XP value, or nil when the row has no XP label.
local function addPercentToReward(row, xpMax)
    if row.kind ~= "doubleLine" or type(row.rightText) ~= "string" then
        return nil
    end

    local earned
    row.rightText = row.rightText:gsub("%(([%d,]+)[xX][pP]%)", function(digits)
        local xp = tonumber((digits:gsub(",", "")))
        if not xp then
            return "(" .. digits .. "xp)"
        end
        earned = xp
        local percent = levelPercent(xp, xpMax)
        if percent then
            return "(" .. digits .. "xp, " .. percent .. "%)"
        end
        return "(" .. digits .. "xp)"
    end, 1)

    return earned
end

local function isCurrentMapTooltip(tooltip)
    if not tooltip or not tooltip._owner or not tooltip._showData then
        return false
    end
    local icon = tooltip._owner
    -- Verify the icon still owns this tooltip (Questie reuses tooltip frames).
    return icon.data == tooltip._showData
        and tooltip:GetOwner() == (tooltip._showOwner or icon)
        and type(tooltip.npcAndObjectOrder) == "table"
end

-- Resolve the titles Questie uses for the main/current quest rows.  This
-- avoids mistakenly treating breadcrumb rows as the start of a new chain.
local function getMainQuestTitles(tooltip)
    local titles = {}
    for _, quests in pairs(tooltip.npcAndObjectOrder) do
        for _, quest in pairs(quests) do
            if quest.title then
                titles[quest.title] = true
            end
        end
    end
    return titles
end

local function augmentRows(tooltip, rows)
    if rows.QuestieChainXPDone or not isCurrentMapTooltip(tooltip) or not IsShiftKeyDown() then
        return
    end
    rows.QuestieChainXPDone = true

    local xpMax = UnitXPMax("player")
    local mainTitles = getMainQuestTitles(tooltip)
    local currentQuestXP = 0
    local hasCurrentQuest = false
    local chain
    local summaries = {}

    local function finishChain(atIndex)
        if chain and chain.followups > 0 then
            local pct = levelPercent(chain.xp, xpMax)
            local amount = "(" .. commaNumber(chain.xp) .. "xp"
            if pct then
                amount = amount .. ", " .. pct .. "%"
            end
            amount = amount .. ")"

            summaries[#summaries + 1] = {
                at = atIndex,
                row = {
                    kind = "doubleLine",
                    leftText = "Total chain XP (" .. chain.questCount .. " quests)",
                    rightText = amount,
                    args = {n = 6, 0.45, 0.85, 0.95, 1.0, 0.82, 0.25},
                },
            }
        end
        chain = nil
    end

    for i, row in ipairs(rows) do
        -- The header has a texture prefix.  Matching the localized words
        -- leaves that prefix (and the original heading) alone.
        local isNextHeader = row.kind == "line"
            and type(row.text) == "string"
            and row.text:find(nextInChainLabel, 1, true) ~= nil
        local isMainQuest = row.kind == "doubleLine" and mainTitles[row.leftText] == true

        -- A next-in-chain section consists of consecutive quest double-lines.
        -- Close it before the next unrelated row or the next main quest.
        if chain and (row.kind ~= "doubleLine" or isMainQuest) then
            finishChain(i)
        end

        -- Modify the XP shown in the existing quest row, not any descriptions.
        local rowXP = addPercentToReward(row, xpMax)

        if isMainQuest then
            currentQuestXP = rowXP or 0
            hasCurrentQuest = true
        elseif isNextHeader then
            chain = {
                xp = hasCurrentQuest and currentQuestXP or 0,
                questCount = hasCurrentQuest and 1 or 0,
                followups = 0,
            }
        elseif chain and row.kind == "doubleLine" then
            chain.xp = chain.xp + (rowXP or 0)
            chain.questCount = chain.questCount + 1
            chain.followups = chain.followups + 1
        end
    end
    finishChain(#rows + 1)

    -- Insert from the back so indices recorded above remain valid.
    for i = #summaries, 1, -1 do
        local summary = summaries[i]
        table.insert(rows, summary.at, summary.row)
    end
end

function tooltipLayout:Render(tooltip, rows)
    if type(rows) == "table" then
        augmentRows(tooltip, rows)
    end
    return originalRender(self, tooltip, rows)
end
