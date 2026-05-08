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
            { text = "Unlimited", help = "No limit", key = '999' },
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

    --[[
    {
        default = 3,
        label = "Zoop Speed Recovery Tick Limit",
        help = "Max number of ticks that can be fast-forwarded after a freeze",
        key = 'SSB_ZoopTickLimit',
        values = {
            { text = "2 ticks",  help = "2 ticks",  key = '2' },
            { text = "3 ticks",  help = "3 ticks",  key = '3' },
            { text = "4 ticks",  help = "4 ticks (default)",  key = '4' },
        },
    },
    
    {
        default = 2,
        label = "Halt Cutoff",
        help = "Minimum delay between ticks before zoop speed recovery kicks in",
        key = 'SSB_HaltCutoff',
        values = {
            { text = "0.2s", help = "Sensitive - triggers on small stutters", key = '0.2' },
            { text = "0.3s", help = "Default - triggers on noticeable freezes", key = '0.3' },
            { text = "0.4s", help = "A little conservative", key = '0.4' },
            { text = "0.5s", help = "Conservative - only triggers on big freezes", key = '0.5' },
            { text = "1.0s", help = "Very conservative - only major freezes", key = '1.0' },
        },
    },
    ]]
}