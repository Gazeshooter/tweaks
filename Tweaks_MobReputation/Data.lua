-- Curated Vanilla / Classic 1.12 reputation-on-kill starting data.
-- Key: NPC ID. Each entry: {factionID, baseGain, firstStandingWITHOUTGain}.
-- Standing indexes: 1 Hated, 2 Hostile, 3 Unfriendly, 4 Neutral,
--                   5 Friendly, 6 Honored, 7 Revered, 8 Exalted.
-- cap=7 means kills earn rep THROUGH Honored, not once Revered is reached.
-- cap=9 denotes no verified standing cap (Exalted still maxes normally).
--
-- NOT a comprehensive Vanilla creature reputation database.
-- These entries are individual factual observations from Wowhead Classic
-- NPC "Gains" pages cross-checked with Classic faction reputation guides.
-- See README.md for known disagreements and Forever-specific limitations.
-- No CMaNGOS SQL code/data is redistributed.

local _, ns = ...
ns.Vanilla = {
    -- Timbermaw Hold (576). 5 rep through Honored (cap when Revered).
    [7153] = {{576, 5, 7}}, -- Deadwood Warrior
    [7154] = {{576, 5, 7}}, -- Deadwood Gardener
    [7155] = {{576, 5, 7}}, -- Deadwood Pathfinder
    [7156] = {{576, 5, 7}}, -- Deadwood Den Watcher
    [7157] = {{576, 5, 7}}, -- Deadwood Avenger
    [7158] = {{576, 5, 7}}, -- Deadwood Shaman
    [7438] = {{576, 5, 7}}, -- Winterfall Ursa
    [7439] = {{576, 5, 7}}, -- Winterfall Shaman
    [7440] = {{576, 5, 7}}, -- Winterfall Den Watcher
    [7441] = {{576, 5, 7}}, -- Winterfall Totemic
    [7442] = {{576, 5, 7}}, -- Winterfall Pathfinder
    [10916] = {{576, 5, 7}}, -- Winterfall Runner
    [9462] = {{576, 15, 9}}, -- Chieftain Bloodmaw
    [9464] = {{576, 15, 9}}, -- Overlord Ror
    [10738] = {{576, 25, 9}}, -- High Chief Winterfall

    -- Argent Dawn (529). Outdoor low-tier kills and Scholomance differ.
    [1783] = {{529, 5, 5}}, -- Skeletal Flayer; stops on Friendly
    [1787] = {{529, 5, 5}}, -- Skeletal Executioner
    [1788] = {{529, 5, 5}}, -- Skeletal Warlord
    [8477] = {{529, 5, 7}}, -- Skeletal Servant; stops on Revered
    [10485] = {{529, 5, 7}}, -- Risen Aberration; stops on Revered

    -- Cenarion Circle (609). Standard Twilight Cultists stop on Honored.
    -- Flamereaver uniquely continues until Revered (see guide vs NPC page).
    [11880] = {{609, 1, 6}}, -- Twilight Avenger
    [11881] = {{609, 1, 6}}, -- Twilight Geolord
    [11882] = {{609, 1, 6}}, -- Twilight Stonecaller
    [11883] = {{609, 1, 5}}, -- Twilight Master (NPC-specific Classic cap)
    [15213] = {{609, 1, 6}}, -- Twilight Overlord
    [15201] = {{609, 1, 7}}, -- Twilight Flamereaver (guide: through Honored)
}
-- Short labels used exclusively in mob tooltips; faction IDs avoid
-- ambiguity between similarly named reputations.
ns.ShortFactionNames = {
    [576] = "Timbermaw",
    [529] = "Argent Dawn",
    [609] = "Cenarion",
}
ns.FallbackFactionNames = {
    [576] = "Timbermaw Hold",
    [529] = "Argent Dawn",
    [609] = "Cenarion Circle",
}
