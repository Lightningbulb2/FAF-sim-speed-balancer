name = "Sim Speed Balancer"
version = 16
copyright = "Licensed under the FAF Vault License. Free to use and modify."
description =
"Dynamically adjust game speed to reduce lag and improve performance. Github at https://github.com/Lightningbulb2/FAF-sim-speed-balancer"
author = "Lightningbulb"
url = "https://github.com/Lightningbulb2/FAF-sim-speed-balancer"
uid = "927849a2-662c-4f31-b7dd-8b7d57f10358"

exclusive = false
enabled = true
ui_only = true
conflicts = {}
after = { "fa45244b-3fd5-490b-99a5-b7f5e4631d4c" }
before = {}
icon = "FAF-sim-speed-balancer/speed_balancer.png"

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


]]
