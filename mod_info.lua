name = "Sim Speed Balancer"
version = 17
copyright = "Licensed under the FAF Vault License. Free to use and modify."
description =
"Dynamically adjust game speed to reduce lag and improve performance. Github at https://github.com/Lightningbulb2/FAF-sim-speed-balancer"
author = "Lightningbulb"
url = "https://github.com/Lightningbulb2/FAF-sim-speed-balancer"
uid = "9c82a91e-677d-40bb-91fc-df9358de7f4e"

exclusive = false
enabled = true
ui_only = false
conflicts = {}
after = {}
before = { "41126c8e-9f23-46bf-8865-045686d60856" }
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


]]
