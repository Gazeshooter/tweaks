-- Tweaks is a parent/grouping addon; features remain independently toggleable.
-- Modules may register pages in the client's native Settings > AddOns menu.
-- No custom settings frame, AceConfig, or third-party addon modifications.

local Tweaks = _G.Tweaks or {}
_G.Tweaks = Tweaks

local pages = {}
local order = {}
local parentCategory
local ready = false

local function hasSettingsAPI()
    return Settings
        and Settings.RegisterVerticalLayoutCategory
        and Settings.RegisterVerticalLayoutSubcategory
        and Settings.RegisterAddOnCategory
end

local function ensureParentCategory()
    if parentCategory then return parentCategory end
    if not hasSettingsAPI() then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory("Tweaks")
    Settings.RegisterAddOnCategory(category)
    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Select a module to configure"))
    end
    parentCategory = category
    Tweaks.SettingsCategory = category
    return category
end

local function registerPage(page)
    if page.registered then return end
    local parent = ensureParentCategory()
    if not parent then return end

    local child = Settings.RegisterVerticalLayoutSubcategory(parent, page.title)
    Settings.RegisterAddOnCategory(child)
    page.registered = true

    -- Keep one module's settings error from preventing other modules loading.
    local ok, err = pcall(page.build, child)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler("Tweaks settings (" .. page.id .. "): " .. tostring(err)) end
    end
end

-- Call from a feature addon, after its saved variables have been initialized.
-- Registration also works for modules loaded on demand after PLAYER_LOGIN.
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

function Tweaks:OpenSettings()
    if parentCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(parentCategory:GetID())
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    ready = true
    for _, page in ipairs(order) do registerPage(page) end
end)
