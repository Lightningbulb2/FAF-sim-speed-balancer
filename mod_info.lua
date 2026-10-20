name = "Sim Speed Balancer"
version = 21
copyright = "Licensed under the FAF Vault License. Free to use and modify."
description =
"Dynamically microadjust game speed to reduce lag and improve performance. Details at https://github.com/Lightningbulb2/FAF-sim-speed-balancer"
author = "Lightningbulb"
url = "https://github.com/Lightningbulb2/FAF-sim-speed-balancer"
uid = "sim-speed-balancer-v21"

exclusive = false
enabled = true
ui_only = false
conflicts = {}
after = {}
before = { "sim-speed-balancer-ui-v21", "CHEESEBERRY-a1e2-c4t4-scfa-ssbmod-v0200" }
icon = "/mods/FAF-sim-speed-balancer/speed_balancer.png"

--[[

### Changelog

V11
add lobby settings, improve UI, fix incorrect readings, and cleanup unecessary code

V12
Cleanup code, and description for ranked match approval

V13
Add average tickrate readouts

V14
Split readouts into its own panel to be compatible with most other UI mods
Fix: Mass extractors pausing before upgrading

V15
Integrate UI version and SIM version into the same vault upload

V16
Fix: icon directory wrong and missing changelog, plus README announcement updates

V17
Fix: swap the UI version as the nested mod and fix icons again

V18:

Major cleanup

Feature: Add in-game UI button to quick-toggle mod functionality
• (player that is allowed to do so is set in the lobby based on slot number)

• (the button is always there in replay)

Feature: Exchange mod version between players who have the mod to catch discrepancies

Feature: Lobby toggle for printing lots of mod info in the log (for plotting)

Feature: Added readout for current realtime divergence the mod can recover

Fix: Broken UI scaling

Change: TPS readout window went from 10s to 5s, and now works before 5 seconds of data

V19:

Fix vault upload...

V20:

Fix logging toggle and modded client reporting in chat

V21:

Fix: Load BEFORE Supreme Scoreboard so it can run in Co-op before Supreme Scoreboard breaks the UI and prevents it from loading

Fix: Only run hide/show on the mod toggle button if it exists (prevents unecessary log errors)

Fix: UID capitalization causing mod deselect every game launch

Change: move version reporting to a UI element instead of going through chat

Add: ReUI support for moving the panel around (drag its tab along the left, right or top edge while its ReUI options window is open; "Reset position" puts it back)

Add: ReUI options to hide the logging button and to start with the panel folded

Add: hover the "Sim Speed Balancer" title to see every player's version (orange when someone differs)

]]
