# My initial proposal

### Lightningbulb — 4/23/2026 3:43 PM (DISCORD REPLY)
correct, my concept is that both simulation freezes from internet stutters or brief slowdowns from computation will adjust sim speed to make up at least some of the lost time.

The game runs at 10 ticks per second so 1 tick = 100ms

For full stops like internet stutters:

Increase the next 3-5 tick's speed substantially as players were already anticipating the movement (would give minor "zoop" forward) and if the time isn't made up, increase the sim speed by an extra tick for a few seconds to 11 ticks per second.


I'll have to test more, but some games don't appear to slow down, yet still stretch out by a few minutes and my guess is that any given slow tick can compound

Tick 1: 76ms (finished and waiting till 100ms)

Tick 2 86ms (finished and waiting till 100ms)

Tick 3: 95ms (finished and waiting till 100ms)

Tick 4: 102ms (2 ticks late)

Tick 5: 120ms (20 ticks late)

Tick 6: 98ms (finished and waiting till 100ms)


This depends on how FAF handles this though. It already has to do some automatic simspeed adjustments to keep people in sync (I think based on some console commands)

```wld_SkewRateAdjustBase``` - How much to adjust the sim rate based on one beat of skew.
   
```wld_SkewRateAdjustMax``` - Max amount to adjust the sim rate due to skew.


if it automatically syncs people to the slower speed on slow ticks (which would make sense) then we can add another tick per second for the following ticks that are easier to compute.

If the slowdown goes on for too long, then we would want to "expire" the lost time and it won't be made up, or there is just a maximum limit it can spend making up the lost time (5 seconds or so)

Of course this won't help if someone's cpu is completely bogged down and can't compute any easy ticks faster. Also, none of these numbers are exact and you would want to tune them to feel right, but that's the general concept. (edited)Thursday, April 23, 2026 3:48 PM


### Grandpa Sawyer — 4/23/2026 3:50 PM (DISCORD)
Assuming this can be pulled off without fault, it might be worth testing via FAF Develop for several matches.

Like, it sounds intriguing at first, but ultimately it comes down how it performs in practice.
