# Tweaks — WoW Forever

Small, independently toggleable quality-of-life addons for **World of Warcraft: Forever**.

Each `Tweaks_*` directory is a standalone WoW addon with its own `.toc` and checkbox in the AddOns menu. `Tweaks/` is the required parent/grouping addon; it now supplies shared native Settings registration but makes no gameplay changes itself.

## Modules

| Folder | Function | Extra requirements |
| --- | --- | --- |
| `Tweaks_MobReputation` | Shows standing-aware, per-kill mob reputation in tooltips using curated Classic estimates and cautious observed gains | None (TipTac optional) |
| `Tweaks_MobReputation` | Shows per-kill reputation in mob mouseover tooltips, with standing caps, short faction names and configurable capped display | None (TipTac optional) |\n| `Tweaks_OpenMapTerrain` | Adds an optional terrain-only mode under OpenMap → Settings → Look | OpenMap with API v4+ |
| `Tweaks_QuestieChainXP` | Shows quest XP as a percentage of the current level and total follow-up chain XP in Questie map tooltips | Questie |
| `Tweaks_QuestieLookahead` | Displays quest starters unlocked in the next three levels, including custom icon options | Questie |
| `Tweaks_QuestieOpenMapIcons` | Keeps Questie's world-map pins visible above OpenMap's stitched artwork, including after redraws | Questie and OpenMap |
| `Tweaks_TooltipBar` | Hides Blizzard's additional health bar underneath unit tooltips without changing TipTac's own bars | None |

## Installation

1. Copy `Tweaks/` and whichever `Tweaks_*` folders you want into your WoW Forever `Interface/AddOns/` directory.
2. Remove older standalone copies of the same tweaks (especially `QuestieChainXP`) so they cannot hook Questie twice.
3. Enable or disable the individual modules in the WoW AddOns menu; reload the UI after changing them.

This is **source code**, not a drop-in `Interface/AddOns` directory. Preserve each module's folder name and keep its `.toc` next to its Lua files.

## In-game options

The parent addon registers **Options > AddOns > Tweaks** using WoW Forever's native Settings API. Enabled modules can register their own subcategories without adding a custom window, modifying third-party addons, or affecting the separate AddOns-list checkboxes.

Currently `Tweaks_MobReputation` registers **Tweaks > Mob Reputation** (also opened with `/mobrep options`):

- **When kill reputation is capped**: Hide reputation line (default), Always show base gain, or Show zero gain.
- **Use short faction names**: enabled by default (`Timbermaw` rather than `Timbermaw Hold`).
- **Learn reputation from solo kills**: experimental, enabled by default.

Settings are saved per character and apply on subsequent mouseovers without a reload. Other modules may opt into the common subcategory registration API later; a disabled module does not create its settings page. To register a page from an enabled module after saved variables exist, call:

```lua
Tweaks:RegisterSettingsSubcategory("Tweaks_MyFeature", "My Feature", function(category)
    local option = Settings.RegisterAddOnSetting(
        category, "TweaksMyFeature_Enabled", "enabled", MyFeatureDB,
        "boolean", "Enabled", true)
    Settings.CreateCheckbox(category, option, "Help text")
end)
```

## Compatibility and notes

- Developed against WoW Forever. Questie and OpenMap internal APIs may change between addon releases.
- `Tweaks_QuestieOpenMapIcons` version 1.1 was verified in-game to restore missing Questie map icons, including with Lookahead and Chain XP enabled, across reloads, zone changes and zooming.
- The Lookahead module includes a recoloured pfQuest texture. See `Tweaks_QuestieLookahead/PFQUEST_TEXTURE_LICENSE.txt` for the original artwork attribution and MIT licence.
- The modules patch behaviour at runtime; **no source files in Questie, OpenMap or TipTac are modified**.

## Contributing

Keep each micro-tweak in a separate `Tweaks_FeatureName/` folder with its own `.toc`, `## Group: Tweaks` and `## Dependencies: Tweaks`. Declare other addon dependencies explicitly. Avoid shared edits to third-party addons.
