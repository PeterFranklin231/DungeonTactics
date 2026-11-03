# Isle of Beginnings (Godot 4.5 prototype)

Open `project.godot` in Godot 4.5 and press F5.

Controls: Arrows/WASD move (screen-relative), Enter/Space/E talk, Tab/M/Esc party menu.
Walk into NPCs, counters or the boat to interact. Walk onto doorsteps to enter buildings.

## The island
- **Riverbend** (start) - Rusty Tankard inn with sellswords, General Store.
- **Greenvale Plains** - slimes and boars. **Thornwood** - wolves and bandits.
- **The northern ridge** walls off the meadow. Go through the **Old Cave** (bats, spiders).
- **Sunpetal Meadow** - bats, spiders, wolves. **Gullhaven** on its east coast: Salty Gull inn,
  Brine & Blade Outfitters (better gear), and the shipwright on the dock who sells a boat (500g).
- You wake at the last inn you rested at. Resting and dying both save.

## Boat
Walk into it from Gullhaven's pier to board. Sail slowly around the coast; push into any
walkable shore to land. Its hold carries 10 stacks (manage from the Items tab while aboard
or in Gullhaven).

## Equipment
Slots: main hand, off hand, helm, body, gloves, boots, amulet, two rings.
Bases come in STR / DEX / INT styles at level 0 / 5 / 10 / 15 / 20 with stat requirements.
Rarities: normal, magic (1-2 affixes), rare (3-5 affixes), unique (preset). Shoot skills need a bow.
Weapon-only rolls: added physical damage, chance to Hit. Armour can very rarely roll damage.

## Where things live
- scripts/autoload/db.gd    abilities (with tags), consumables, enemies, encounters, skill tree
- scripts/autoload/loot.gd  item bases, affixes + weights, uniques, drop/shop generation
- scripts/autoload/game.gd  party, gold, bag, boat, inns, shops, save/load
- scripts/unit.gd           stats, leveling, tree allocation, equipment slots
- scripts/battle/           ATB battle (battle.gd) and formulas (combat.gd)
- scripts/maps/             iso map base (+ wandering monsters), overworld, towns, inns, cave
- scripts/ui/               dialog, party menu, skill tree, shared keyword-coloured tooltip
- scripts/art.gd            all placeholder art is procedural; swap in sprites later
