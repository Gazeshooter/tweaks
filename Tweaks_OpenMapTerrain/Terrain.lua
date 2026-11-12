-- Tweaks_OpenMapTerrain - WoW Forever
-- Uses OpenMap's supported menu extension API; leaves OpenMap's own saved
-- options, explored-area selection, icons and database untouched between draws.

local ADDON = ...
local OpenMap = _G.OpenMap
local API = _G.OpenMapAPI

if not (OpenMap and API and API.version and API.version >= 4) then
    return
end

local mod = OpenMap:GetModule("worldmap")
local S = OpenMap.MapStitch
if not (mod and S and type(S.SetView) == "function") then
    return
end

-- Standalone account-wide preference, not an OpenMap option.
local function Enabled()
    local db = _G.TweaksOpenMapTerrainDB
    return type(db) == "table" and db.enabled == true
end

-- A new background on OpenMap's EXISTING minimap layer:
-- art and city maps are lower; exploration shade, quest icons, cave maps,
-- pins and player icons are higher. No existing art is hidden or reparented.
local backdrop, backdropLayer

local function UpdateBackdrop()
    local layer = S.closeLayers and S.closeLayers.minimap
    if not layer then return end

    if layer ~= backdropLayer then
        backdropLayer = layer
        backdrop = layer:CreateTexture(nil, "BACKGROUND", nil, -8)
        backdrop:SetAllPoints(layer)
        backdrop:SetColorTexture(0.10, 0.11, 0.12, 1)
    end
    backdrop:SetShown(Enabled())
end

local oldSetView = S.SetView

-- OpenMap computes close-up tile opacity using its own settings, so the
-- terrain mode temporarily substitutes only the four inputs to that
-- calculation. Values are ALWAYS restored before the function returns.
-- Critically, this does not change unexplored/darkening/hide, the chart,
-- zone icons, or any of OpenMap's persisted settings.
S.SetView = function(...)
    UpdateBackdrop()
    if not Enabled() or not mod.db then
        return oldSetView(...)
    end

    local db = mod.db
    local wasMinimap = db.minimap
    local wasMix = db.minimapMix
    local wasDeep = db.minimapDeep
    local wasFrom = db.minimapFrom
    local wasSoften = db.soften

    db.minimap = true
    db.minimapMix = 1
    db.minimapDeep = 1
    db.minimapFrom = 1
    db.soften = false

    -- A failure must never strand OpenMap in the temporary values.
    local ok, err = pcall(oldSetView, ...)

    db.minimap = wasMinimap
    db.minimapMix = wasMix
    db.minimapDeep = wasDeep
    db.minimapFrom = wasFrom
    db.soften = wasSoften

    if not ok then error(err, 0) end
end

local function SetEnabled(on)
    if type(_G.TweaksOpenMapTerrainDB) ~= "table" then
        _G.TweaksOpenMapTerrainDB = {}
    end
    _G.TweaksOpenMapTerrainDB.enabled = not not on
    UpdateBackdrop()
    if mod.RefreshView then mod.RefreshView() end
end

-- OpenMapAPI explicitly supports a third-party menu toggle under Look.
-- The API groups third-party rows under their own section, so this adds a
-- "The map" group rather than modifying/replacing the built-in one.
API.RegisterMenuToggle(ADDON, {
    id = "terrainOnly",
    label = "Terrain only",
    tab = "look",
    section = "The map",
    icon = "Interface\\Icons\\Spell_Nature_FarSight",
    get = Enabled,
    set = SetEnabled,
})

-- Retain the preference while switching to a dungeon, battleground, or
-- Blizzard's regular map. Only the stitched map's special layer is altered.
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if type(_G.TweaksOpenMapTerrainDB) ~= "table" then
        _G.TweaksOpenMapTerrainDB = { enabled = false }
    end
    if Enabled() and mod.RefreshView then mod.RefreshView() end
end)
