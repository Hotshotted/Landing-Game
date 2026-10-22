# Coin economy

Flight-school money: every free-flight run in an aircraft you don't own costs a **rental fee** (the Cub is waived when you can't pay it, so nobody gets stuck), a crash in a rented aircraft adds a **damage fee** (2 x rent, capped at what you have), **buying** an aircraft ends its rental for good, and an **instructor lesson** is a paid practice landing that counts double toward proficiency. Practice landings, checkride landings and the daily approach are provided by the school: no rental. Aircraft are still unlocked by rank for checkrides and renting; buying one unlocks it early.

| | Cub | 172 | Glider | Twin | Jet |
|---|---|---|---|---|---|
| Rent per flight | 10 | 25 | 35 | 60 | 150 |
| Damage fee (crash) | 20 | 50 | 70 | 120 | 300 |
| Price | 100 | 1500 | 2000 | 3500 | 7000 |

Examiner fee for the checkride to rank r: 100 x 1.5^(r-1) (100, 150, 225, 338, 506, 759, 1139). Lesson: 35 x 1.35^(r-1), counts x2 toward the meter. Payouts: Greaser 80, Smooth 48, Good 32, Firm 16, Hard 8 coins, times the Greaser streak (up to x10), times the pot multiplier (+0.3 per landing survived in the run, lost with a crash). A routine two-landing run pays about 75 coins; six good landings with three Greasers pays about 1100.

All numbers are `Tuning` values (and in the `?tune` panel). `scripts/EconomySim.gd` is the player model; the smoke test (section 33) checks the milestones below.

## Simulation: first two hours

Average of simulated players. Cautious: cashes out after 2 landings, crashes rarely. Balanced: 4 landings. Greedy: up to 8 landings, crashes often. Each landing takes about 50 s, each run 15 s more; players buy the cheapest aircraft they can afford (keeping two rentals in reserve), book the checkride when they are endorsed and can pay the fee with a margin, and sometimes take a lesson.

## cautious
balance every 10 min: 291 375 555 560 604 635 602 528 504 504 482 560
bought at (minute, median):  CUB 4  172 not in 2 h  GLIDER not in 2 h  TWIN not in 2 h  JET not in 2 h
balance first covers the price:  CUB 4  172 not in 2 h  GLIDER not in 2 h  TWIN not in 2 h  JET not in 2 h
runs 42 (crashes 2), earned 3474, rental 702, damage 66, examiner fees 1382, lessons 651, rank at 2 h 3.8
checkrides taken 7.0, passed 53%, balance covered the fee 3.4x on average when booked
## balanced
balance every 10 min: 596 878 931 927 1044 976 949 972 1084 957 1115 835
bought at (minute, median):  CUB 4  172 58  GLIDER not in 2 h  TWIN not in 2 h  JET not in 2 h
balance first covers the price:  CUB 4  172 52  GLIDER not in 2 h  TWIN not in 2 h  JET not in 2 h
runs 25 (crashes 5), earned 4946, rental 91, damage 58, examiner fees 1337, lessons 353, rank at 2 h 3.0
checkrides taken 6.9, passed 43%, balance covered the fee 5.3x on average when booked
## greedy
balance every 10 min: 274 521 829 809 1190 1175 1712 1462 1268 1338 1313 908
bought at (minute, median):  CUB 26  172 77  GLIDER 93  TWIN not in 2 h  JET not in 2 h
balance first covers the price:  CUB 26  172 77  GLIDER 91  TWIN not in 2 h  JET not in 2 h
runs 20 (crashes 15), earned 4984, rental 41, damage 68, examiner fees 675, lessons 0, rank at 2 h 2.1
checkrides taken 4.8, passed 43%, balance covered the fee 9.8x on average when booked

## What it means

- **Coins are spent regularly.** Rentals, damage, lessons and examiner fees take a quarter or more of what a cautious or balanced pilot earns; the balance hovers at a few hundred to a thousand coins instead of piling up.
- **The Cub is the first goal** (about 5 minutes in), then the **172 is a mid-term goal**: about an hour for a balanced pilot, around 75 minutes for a greedy one who banks big runs, and not within two hours for a cautious one. The glider follows (about 100 minutes for the greedy), and the **twin and jet are long-term**: nobody owns them within two hours (the jet costs about the whole income of five hours of play).
- **Checkrides are affordable but not free**: the fee is covered 3x (cautious) to 9x (greedy) at the moment of booking, yet failing one (about half of first attempts) takes a real bite out of a cautious pilot's balance.
- **A big push-your-luck run feels big**: the streak and pot multipliers make a six-landing run with three Greasers pay about 15x a routine two-landing run.
