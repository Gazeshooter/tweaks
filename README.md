# Tweaks — WoW Forever

Small, independently toggleable quality-of-life addons for **World of Warcraft: Forever**.

Each `Tweaks_*` directory is a standalone WoW addon with its own `.toc` and checkbox in the AddOns menu. `Tweaks/` is the required parent/grouping addon; it now supplies shared native Settings registration but makes no gameplay changes itself.

## Modules

| Folder | Function | Extra requirements |
| --- | --- | --- |
| `Tweaks_MobReputation` | Shows standing-aware mob reputation per kill in mouseover tooltips; configurable cap behaviour, short faction names and experimental learning | None (TipTac optional) |
| `Tweaks_OpenMapTerrain` | Adds **Terrain only** to OpenMap's **Look → The map** menu, showing terrain/minimap detail in place of stitched artwork without changing exploration shading or other map options | OpenMap (extension API v4+) |
| `Tweaks_QuestieChainXP` | Shows quest XP as a percentage of the current level and total follow-up chain XP in Questie map tooltips | Questie |
| `Tweaks_QuestieLookahead` | Displays quest starters unlocked in the next three levels, including custom icon options | Questie |
| `Tweaks_TooltipBar` | Hides Blizzard's additional health bar underneath unit tooltips without changing TipTac's internal bars | None |

## Installation

1. Copy `Tweaks/` and whichever `Tweaks_*` folders you want into your WoW Forever `Interface/AddOns/` directory.
2. Remove older standalone copies of the same tweaks (especially `QuestieChainXP`) so they cannot hook Questie twice. **Delete any old `Tweaks_QuestieOpenMapIcons/` folder from your local AddOns directory**; deleting it from GitHub does not uninstall a previously installed copy.
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

## OpenMap Terrain only

Install `Tweaks_OpenMapTerrain/` alongside `Tweaks/` and OpenMap. Open the world map, then **OpenMap → Settings → Look → The map → Terrain only**. The toggle is **off by default** and its preference is saved account-wide in `TweaksOpenMapTerrainDB`.

When enabled, it favors the client's minimap/terrain tiles over OpenMap's stitched zone artwork and adds a neutral backing behind that terrain. It does **not** rewrite OpenMap's saved options, exploration darkening/hiding, quest pins, or other layers. It applies to OpenMap's stitched world map, not dungeon/battleground/Blizzard map views. Because this is an OpenMap-specific option, its control stays in **OpenMap's Look tab**, rather than duplicating it under native Tweaks options.

The module uses OpenMap's menu extension API v4+ and temporarily adjusts view-calculation inputs. If a future OpenMap version changes its internal map-rendering API, this module may need an update.

## Questie and OpenMap icon compatibility

**`Tweaks_QuestieOpenMapIcons` has been retired.** OpenMap **v0.8.6** (12 November 2026) fixed Questie 12.8's renamed pin module and icon draw-order resets; **v0.8.7** (12 November 2026) fixed icons hidden behind the artwork on the first zone-map opening. Current OpenMap already performs the pin lifting that our standalone workaround used to do.

Use **OpenMap v0.8.7 or newer** with a compatible Questie release. The fix is based on upstream code/changelogs, not independently verified in a live game session. If icons disappear again, reproduce with the retired addon removed and report the versions and redraw conditions upstream. Earlier OpenMap builds may still exhibit the issue.

## Compatibility and notes

- Developed against WoW Forever. Questie and OpenMap internal APIs may change between addon releases.
- The Lookahead module includes a recoloured pfQuest texture. See `Tweaks_QuestieLookahead/PFQUEST_TEXTURE_LICENSE.txt` for the original artwork attribution and MIT licence.
- The modules patch behaviour at runtime; **no source files in Questie, OpenMap or TipTac are modified**.

## Contributing

Keep each micro-tweak in a separate `Tweaks_FeatureName/` folder with its own `.toc`, `## Group: Tweaks` and `## Dependencies: Tweaks`. Declare other addon dependencies explicitly. Avoid shared edits to third-party addons.
