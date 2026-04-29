AIOpts = {
    {
        default = 3,
        label = "Zoop Speed Recovery Tick Limit",
        help = "Number of ticks that can be fast-forwarded after a freeze",
        key = 'SSB_ZoopTickLimit',
        values = {
            { text = "5 ticks",  help = "5 ticks",  key = '5' },
            { text = "10 ticks", help = "10 ticks", key = '10' },
            { text = "15 ticks", help = "15 ticks (default)", key = '15' },
            { text = "20 ticks", help = "20 ticks", key = '20' },
            { text = "30 ticks", help = "30 ticks", key = '30' },
        },
    },
    {
        default = 3,
        label = "Max Recovery Length",
        help = "Maximum seconds of slow time that can be recovered",
        key = 'SSB_MaxRecovery',
        values = {
            { text = "2s",  help = "2 seconds",  key = '2' },
            { text = "3s",  help = "3 seconds",  key = '3' },
            { text = "5s",  help = "5 seconds (default)", key = '5' },
            { text = "10s", help = "10 seconds", key = '10' },
            { text = "Unlimited", help = "No limit", key = '999' },
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
            { text = "0.5s", help = "Conservative - only triggers on big freezes", key = '0.5' },
            { text = "1.0s", help = "Very conservative - only major freezes", key = '1.0' },
        },
    },
}