-- Tweaks: hide Blizzard's extra health bar below GameTooltip.
-- TipTac's separately drawn health/power bars are not modified.

local bar = _G.GameTooltipStatusBar
if not bar then
    return
end

local function HideExternalTooltipBar(self)
    self:SetAlpha(0)
end

-- Applies on every UI load, including /reload and character login.
HideExternalTooltipBar(bar)

-- Also reapply when Blizzard or another addon shows the bar again.
bar:HookScript("OnShow", HideExternalTooltipBar)
