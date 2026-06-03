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

}