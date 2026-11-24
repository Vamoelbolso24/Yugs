# Custom cards: how they work

Everything about your custom cards lives in this folder:

| File | What it is |
|---|---|
| `cards.txt` | Every custom card: name, type, stats, text. The top of the file explains each field. |
| `scripts/c<ID>.lua` | The card's effect, written in Lua (e.g. `scripts/c1900000000.lua`). Normal Monsters don't need one. |
| `pics/<ID>.jpg` | The card's artwork (e.g. `pics/1900000000.jpg`; `.png` and `.webp` work too). Optional. |

Card IDs are numbers: the first custom card is **1900000000**, then 1900000001, 1900000002...
(real cards all have numbers below 1000000000, so they never clash).

The game reads the script files in this folder directly: there is no other copy. Edit
`scripts/c<ID>.lua`, start a new duel, and the new version is used.

- After changing `cards.txt` (names, stats, text): close the black Yugs window and run `start.bat` again.
- After changing a script: just start a new duel. No restart needed.

If something is wrong in `cards.txt` (a typo in a field, a missing Level...), the black window
tells you exactly which card and line.

## Making a new card, step by step

1. Add the card to `cards.txt` with the next free ID, for example `[1900000002]`.
2. Find a real card whose effect is close to yours and look at its script:
   `npm run find-card -- "Negate Attack"` (in PowerShell, in the Yugs folder).
3. Copy that script into `scripts/c1900000002.lua` and change what's different.
   The two example cards (`c1900000000.lua` Telephone Ring, `c1900000001.lua` Busy Signal) explain every line.
4. Restart the server, then test it: **Test duel (admin)** on the home screen lets you
   start with the card in your hand.

## Things to know when writing scripts

- Start every script with `local s,id=GetID()`. `id` is the card's own ID number.
- To point at another card in a script, use its number, for example
  `Duel.IsExistingMatchingCard(Card.IsCode,tp,LOCATION_HAND,0,1,nil,1900000000)`.
- `aux.Stringid(id,0)` shows "Prompt 1" from `cards.txt`, `aux.Stringid(id,1)` shows "Prompt 2", and so on.
- `tp` is the player who controls the card, `1-tp` is the opponent.
- Every real card's script is in `vendor/CardScripts/official/c<passcode>.lua`. That's
  over 13,000 working examples. The full list of functions is documented at
  https://github.com/ProjectIgnis/CardScripts/wiki

## Common effect shapes (and a real card to copy from)

| Effect | Copy from |
|---|---|
| When Normal Summoned: do something | `c1900000000.lua`, Sangan, Hane-Hane |
| When an opponent's monster attacks: negate | `c1900000001.lua`, Negate Attack, Magic Cylinder |
| Draw cards (Spell) | Pot of Greed, Graceful Charity |
| Destroy a target | Fissure, Mystical Space Typhoon, Trap Hole |
| Add a card from Deck to hand | Sangan, Reinforcement of the Army |
| Special Summon from hand/GY | Monster Reborn, Call of the Haunted |
| Gain / lose ATK (Equip) | Black Pendant, Axe of Despair |
| Burn damage | Ookazi, Just Desserts |
| Continuous boost to your monsters | Field Spells like Sogen |
| Once per turn ignition effect ("You can...") | Breaker the Magical Warrior |

## Sending a batch to Claude

Write the cards directly in the `cards.txt` format (copy a block, give it the next ID number,
and change it) and say which ones need scripts. That saves a conversion step. Mention a real card with a similar
effect when you know one; it makes the script faster to write.
