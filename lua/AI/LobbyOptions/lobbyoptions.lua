AIOpts = {
    {
        default = 2,
        label = "Max Recovery Length",
        help = "Maximum seconds of slow time that can be recovered at once",
        key = 'SSB_MaxRecovery',
        values = {
            { text = "2s",  help = "up to 20 seconds of +1 speedup",  key = '2' },
            { text = "3s",  help = "up to 30 seconds of +1 speedup)",  key = '3' },
            { text = "5s",  help = "up to 50 seconds of +1 speedup", key = '5' },
            { text = "10s", help = "up to 100 seconds of +1 speedup", key = '10' },
        },
    },
    {
        default = 2,
        label = "Target Tickrate",
        help = "Tickrate the mod tries to maintain",
        key = 'SSB_TargetTickrate',
        values = {
            { text = "9.5 TPS",  help = "make the game feel like it used to",  key = '0.95' },
            { text = "10 TPS",  help = "make the game run at it's advertised tickrate",  key = '1.0' },
        },
    },
    {
        default = 1,
        label = "Debug: Who can toggle the mod ingame",
        help = "Sim Speed Balancer: The player that corresponds to this slot can toggle the mod ingame with a button",
        key = 'SSB_TogglePlayer',
        values = {
            { text = "Nobody",  help = "yup, no one at all",  key = 100 },
            { text = "Slot 1",  help = "player slot",  key = 1 },
            { text = "Slot 2",  help = "player slot",  key = 2 },
            { text = "Slot 3",  help = "player slot",  key = 3 },
            { text = "Slot 4",  help = "player slot",  key = 4 },
            { text = "Slot 5",  help = "player slot",  key = 5 },
            { text = "Slot 6",  help = "player slot",  key = 6 },
            { text = "Slot 7",  help = "player slot",  key = 7 },
            { text = "Slot 8",  help = "player slot",  key = 8 },
            { text = "Slot 9",  help = "player slot",  key = 9 },
            { text = "Slot 10",  help = "player slot",  key = 10 },
            { text = "Slot 11",  help = "player slot",  key = 11 },
            { text = "Slot 12",  help = "player slot",  key = 12 },
        },
    },
    {
        default = 1,
        label = "Debug: Detailed Logging",
        help = "Sim Speed Balancer: (may cause performance problems idk)",
        key = 'SSB_Logging',
        values = {
            { text = "OFF",  help = "Disable Logging",  key = 0 },
            { text = "ON",  help = "Enable Logging",  key = 1 },
        },
    },

}