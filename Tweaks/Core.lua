-- Tweaks is a grouping addon; feature modules stay separately toggleable.
-- Native AddOns Settings registration without changing third-party addon files.
-- The Tweaks landing page is a canvas so modules can place legacy dropdowns
-- without invoking Blizzard_Menu's newer submenu implementation.

local Tweaks = _G.Tweaks or {}
_G.Tweaks = Tweaks

local pages = {}
local order = {}
local rootControls = {}
local rootOrder = {}
local parentCategory
local rootFrame
local ready = false

local function hasSettingsAPI()
    return Settings
        and Settings.RegisterCanvasLayoutCategory
        and Settings.RegisterVerticalLayoutSubcategory
        and Settings.RegisterAddOnCategory
end

local function ensureParentCategory()
    if parentCategory then return parentCategory end
    if not hasSettingsAPI() then return end

    rootFrame = CreateFrame("Frame", "Tweaks_OptionsRoot", UIParent)
    rootFrame:SetSize(600, 450)

    local title = rootFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", 16, -16)
    title:SetText("Tweaks")

    local help = rootFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    help:SetText("Select a module on the left to configure its options.")

    local category = Settings.RegisterCanvasLayoutCategory(rootFrame, "Tweaks")
    Settings.RegisterAddOnCategory(category)
    parentCategory = category
    Tweaks.SettingsCategory = category
    Tweaks.SettingsRootFrame = rootFrame
    return category
end

local function reportError(id, err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler("Tweaks settings (" .. id .. "): " .. tostring(err)) end
end

local function registerPage(page)
    if page.registered then return end
    local parent = ensureParentCategory()
    if not parent then return end

    local child = Settings.RegisterVerticalLayoutSubcategory(parent, page.title)
    Settings.RegisterAddOnCategory(child)
    page.category = child
    page.registered = true

    local ok, err = pcall(page.build, child)
    if not ok then reportError(page.id, err) end
end

local function registerRootControl(control)
    if control.registered then return end
    if not ensureParentCategory() then return end
    control.registered = true
    -- Root controls receive a frame rather than a Settings category. This
    -- intentionally keeps their dropdowns out of Blizzard_Menu.
    local ok, err = pcall(control.build, rootFrame)
    if not ok then reportError(control.id, err) end
end

-- Call from a feature addon after its SavedVariables have initialized.
function Tweaks:RegisterSettingsSubcategory(id, title, build)
    if type(id) ~= "string" or type(title) ~= "string" or type(build) ~= "function" then
        return false
    end
    if pages[id] then return false end

    local page = {id = id, title = title, build = build}
    pages[id] = page
    order[#order + 1] = page
    if ready then registerPage(page) end
    return true
end

-- An optional control on the Tweaks landing page, using the native AddOns
-- canvas and its own standard (legacy) widgets, rather than Menu.lua.
function Tweaks:RegisterRootSettingsControl(id, build)
    if type(id) ~= "string" or type(build) ~= "function" then return false end
    if rootControls[id] then return false end
    local control = {id = id, build = build}
    rootControls[id] = control
    rootOrder[#rootOrder + 1] = control
    if ready then registerRootControl(control) end
    return true
end

function Tweaks:OpenSettings(id)
    local child = id and pages[id] and pages[id].category
    local target = child or parentCategory
    if target and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(target:GetID())
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    ready = true
    -- Register root before child categories, preserving the established API.
    ensureParentCategory()
    for _, control in ipairs(rootOrder) do registerRootControl(control) end
    for _, page in ipairs(order) do registerPage(page) end
end)
