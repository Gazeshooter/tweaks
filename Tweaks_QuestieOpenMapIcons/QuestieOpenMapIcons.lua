-- Tweaks: Questie + OpenMap icons, v1.1.0 (WoW Forever / Questie 12.8+).
--
-- Questie sets a fixed world-map frame level (2016+), sometimes *after*
-- HereBeDragons/OpenMap have positioned the icon. That may put Questie
-- textures behind the stitched map art. Older fixes repaired the level
-- during SetDrawOrder, but their map refresh scan used Questie's old
-- HereBeDragons pin template name.
--
-- Repair both the draw-order phase and subsequent world-map pin re-acquires.
-- Leave minimap frames, icon textures and non-stitched maps alone.

local loader = _G.QuestieLoader
local api = _G.OpenMapAPI
if not (loader and api and api.IsStitched and api.ArtTopLevel and hooksecurefunc) then return end

-- Access existing Questie modules without ImportModule creating empty ones.
local modules = loader._modules
local mapModule = modules and modules.QuestieMap
local utils = mapModule and mapModule.utils
if not (utils and type(utils.SetDrawOrder) == "function") then return end
if utils.TweaksQuestieOpenMapIconsHooked then return end
utils.TweaksQuestieOpenMapIconsHooked = true

local pins = modules and modules.HBDPins
if not pins and _G.LibStub then
    pins = LibStub("HereBeDragonsQuestie-Pins-2.0", true)
end

local BASE_LEVEL = 2015
local MAX_BASE_LEVEL = BASE_LEVEL + 32
local offsets = setmetatable({}, {__mode = "k"})

local function LiftWorldIcon(icon)
    if not (icon and icon.GetFrameLevel and icon.GetParent and icon.SetFixedFrameLevel
        and not icon.miniMapIcon and api.IsStitched()) then return false end

    -- A world-map icon is parented to a HereBeDragons pin with .icon == icon.
    local holder = icon:GetParent()
    if not (holder and holder.icon == icon) then return false end

    local artTop = api.ArtTopLevel()
    if type(artTop) ~= "number" then return false end
    local current = icon:GetFrameLevel()

    -- Keep Questie's relative priority: completion icons stay above starters.
    local offset = offsets[icon] or 0
    if current >= BASE_LEVEL and current <= MAX_BASE_LEVEL then
        offset = current - BASE_LEVEL
        offsets[icon] = offset
    end
    if current > artTop then return false end

    local target = artTop + 1 + offset
    if current == target then return false end
    icon:SetFixedFrameLevel(false)
    icon:SetFrameLevel(target)
    icon:SetFixedFrameLevel(true)
    return true
end

-- The last step of QuestieMap.ProcessQueue(): Questie resets the frame level.
hooksecurefunc(utils, "SetDrawOrder", LiftWorldIcon)

-- HereBeDragons re-acquires map pins after navigation, zoom, or a Questie
-- redraw. It does not call Questie's SetDrawOrder when re-acquiring a pin,
-- so repair the pin after it has been parented to the world map as well.
local provider = pins and pins.worldmapProvider
if provider and type(provider.HandlePin) == "function" then
    hooksecurefunc(provider, "HandlePin", function(_, icon)
        LiftWorldIcon(icon)
    end)
end

local function Templates()
    local out, seen = {}, {}
    local function Add(template)
        if type(template) == "string" and not seen[template] then
            seen[template] = true
            out[#out + 1] = template
        end
    end
    Add(pins and pins.worldmapPinTemplate)
    Add("HereBeDragonsPins-Questie-WorldMapPin") -- Questie 12.8+
    Add("HereBeDragonsPinsTemplateQuestie")     -- pre-12.8 Questie
    return out
end

-- Repair pins that were already on the map when the module loaded, and
-- supply a small in-game diagnostic if other pin visibility issues remain.
local function RefreshExisting()
    local inspected, repaired, belowArt = 0, 0, 0
    if not api.IsStitched() then return inspected, repaired, belowArt end
    local worldMap = _G.WorldMapFrame
    if not (worldMap and worldMap.EnumeratePinsByTemplate) then
        return inspected, repaired, belowArt
    end
    local artTop = api.ArtTopLevel()
    for _, template in ipairs(Templates()) do
        if worldMap.pinPools and worldMap.pinPools[template] then
            for pin in worldMap:EnumeratePinsByTemplate(template) do
                local icon = pin and pin.icon
                if icon and not icon.miniMapIcon then
                    inspected = inspected + 1
                    if type(artTop) == "number" and icon:GetFrameLevel() <= artTop then
                        belowArt = belowArt + 1
                    end
                    if LiftWorldIcon(icon) then repaired = repaired + 1 end
                end
            end
        end
    end
    return inspected, repaired, belowArt
end

local function RefreshSoon()
    if _G.C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshExisting)
    else
        RefreshExisting()
    end
end

local worldMap = _G.WorldMapFrame
if worldMap then worldMap:HookScript("OnShow", RefreshSoon) end
if type(api.RegisterCallback) == "function" then
    local owner = {}
    api.RegisterCallback(owner, "OpenMap_StitchedChanged", RefreshSoon)
end

SLASH_TWEAKSQUESTIEOPENMAPICONS1 = "/tqicons"
SlashCmdList.TWEAKSQUESTIEOPENMAPICONS = function()
    local count, repaired, below = RefreshExisting()
    if _G.DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(("Tweaks Questie+OpenMap: stitched=%s, pins=%d, below art before repair=%d, repaired=%d, template=%s")
            :format(tostring(api.IsStitched()), count, below, repaired,
                tostring(pins and pins.worldmapPinTemplate or "unavailable")))
    end
end

RefreshSoon()
