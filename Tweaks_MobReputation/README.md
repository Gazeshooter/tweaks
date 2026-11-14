# Tweaks_MobReputation (WoW Forever)

Independent `Tweaks` addon showing **reputation per mob kill in the mouseover unit tooltip**, with current-character standing caps.

## Install

Copy `Tweaks_MobReputation/` into `_forever_/Interface/AddOns/`, alongside the installed `Tweaks/` parent. Enable **Tweaks Mob Reputation** in WoW's AddOns menu. No TipTac modification is needed.

## Examples

- Deadwood Gardener (NPC 7154) while Unfriendly with Timbermaw Hold: `Rep: +5 Timbermaw Hold (Classic estimate; until Revered)`.
- The same mob at Revered: `Timbermaw Hold: no kill rep (cap: Revered)`.
- Twilight Avenger: +1 Cenarion Circle until Honored, based on vanilla; other Twilight NPCs may have different limits.
- The addon displays **base** reputation. Racial bonuses, Forever Legacy perks, special events and server tweaks can affect actual gains.

## Sources, assumptions, caveats

This first version bundles a deliberately **curated** set of 26 NPC-ID entries, across Timbermaw Hold, Argent Dawn and Cenarion Circle. It is NOT the whole Classic on-kill database. Values are from Wowhead Classic NPC 'Gains' listings and related Classic reputation guides, not from Forever's server data:

- https://www.wowhead.com/classic/npc=7154/deadwood-gardener
- https://www.wowhead.com/classic/guide/timbermaw-hold-reputation-wow-classic
- https://www.wowhead.com/classic/guide/cenarion-circle-reputation-wow-classic
- https://www.wowhead.com/classic/npc=1783/skeletal-flayer
- https://www.wowhead.com/classic/npc=10485/risen-aberration

'Until Revered' means rep gains through the last point of Honored; no gain once Revered. Cenarion Circle normal cultists generally stop on reaching Honored. Sources disagree on **Twilight Flamereaver** and a handful of cap details; the guide's through-Honored limit is used for Flamereavers. Forever may differ.

WoW Forever's Midnight-based addon API deliberately restricts combat log events. The addon **does not claim** it can reliably identify the victim responsible for every faction change. It only attempts an attribution when solo, outside an instance, with a dead currently-targeted creature. Two matching gains at the same reputation rank are required before displaying an 'observed (solo)' figure. This is a heuristic, not a verified kill log. Classic estimates remain the default where there is no matching observation.

Combat secrecy may prevent GUID access for certain mobs or within instances; no line will be displayed when the NPC ID is unavailable. Factions not yet visible in the reputation API are shown with their Classic baseline but an **unknown standing** label, not an inferred cap.

## Commands

- `/mobrep status` — built-in record count, settings and last NPC ID.
- `/mobrep debug on` — display NPC ID on mouseover for data/reporting.
- `/mobrep learn off` — disable the cautious observation heuristic.
- `/mobrep add 7154 576 5 revered` — save a local, per-character override (the optional cap is the **first non-paying standing**).
- `/mobrep add 7154 576 5 none` — same but without a specific rank cap.
- `/mobrep del 7154` — delete personal observations and overrides for an NPC.

To expand with more reliable Vanilla/Forever rows, add `[npcID] = {{factionID, baseGain, firstNonPayingStanding}}` to `Data.lua`. DO NOT mass-add unverified data from another expansion; those often use very different amounts.

## Verification status

Source-reviewed and statically packaged. The code has **not yet been exercised inside a running WoW Forever client**, so test in-game with a Deadwood Gardener and verify tooltip line placement against your TipTac configuration.