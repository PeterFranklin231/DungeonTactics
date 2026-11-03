extends Node
## Static game data: abilities, items, enemies, encounters and the skill tree.
## Everything here is meant to be tweaked / rebalanced freely.

const STAT_NAMES := {"str": "STR", "dex": "DEX", "con": "CON", "int": "INT"}

var BRANCH_COLORS := {
	"str": Color(0.92, 0.32, 0.26),
	"dex": Color(0.36, 0.86, 0.38),
	"int": Color(0.38, 0.58, 1.0),
	"con": Color(0.96, 0.66, 0.2),
	"none": Color(0.9, 0.9, 0.85),
}

# ---------------------------------------------------------------------------
# Abilities
#   target: enemy | enemies | random3 | ally | allies | self | ally_dead
#   kind:   phys | magic | heal | buff
#   tags:   hit (uses weapon damage + "adds damage to hits"), melee, shoot (needs a bow),
#           cast (a spell), fire / ice, heal
#   stat:   which stat scales it ("atk" = depends on weapon)
# Optional: atb_hit (knock target time bar), atb_after (keep some ATB),
#           crit_bonus, buff {mods}, turns, drain (heal % of damage dealt)
# ---------------------------------------------------------------------------
const ABILITIES := {
	"attack": {"name": "Attack", "mp": 0, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.0, "element": "phys", "tags": ["hit", "melee"],
		"desc": ""},
	# --- STR ---
	"bash": {"name": "Bash", "mp": 3, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.5, "element": "phys", "atb_hit": -35.0, "tags": ["hit", "melee"],
		"desc": "A heavy Melee Hit (150% weapon damage, scales with STR) that staggers, knocking the target's time bar back."},
	"cleave": {"name": "Cleave", "mp": 6, "target": "enemies", "kind": "phys", "stat": "str", "mult": 0.85, "element": "phys", "tags": ["hit", "melee"],
		"desc": "A wide Melee swing that Hits every enemy (85% weapon damage, scales with STR)."},
	"charged_strike": {"name": "Charged Strike", "mp": 7, "target": "enemy", "kind": "phys", "stat": "str", "mult": 2.4, "element": "phys", "tags": ["hit", "melee"],
		"desc": "Gather all your strength into one devastating Melee Hit (240% weapon damage, scales with STR)."},
	"ice_strike_1": {"name": "Ice Strike I", "mp": 5, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.3, "element": "ice", "atb_hit": -20.0, "tags": ["hit", "melee", "ice"],
		"desc": "A frost-wreathed Melee Hit (130% weapon damage, scales with STR) dealing Ice damage that chills the target's time bar."},
	# --- DEX ---
	"multishot": {"name": "Multishot", "mp": 5, "target": "random3", "kind": "phys", "stat": "dex", "mult": 0.95, "element": "phys", "tags": ["hit", "shoot"],
		"desc": "Shoot three arrows at random enemies, each a Hit (95% weapon damage, scales with DEX)."},
	"aimed_shot": {"name": "Aimed Shot", "mp": 5, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 1.8, "element": "phys", "crit_bonus": 0.3, "tags": ["hit", "shoot"],
		"desc": "A careful Shoot Hit (180% weapon damage, scales with DEX) with +30% critical chance."},
	"quick_jab": {"name": "Quick Jab", "mp": 2, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 0.9, "element": "phys", "atb_after": 55.0, "tags": ["hit", "melee"],
		"desc": "A fast Melee Hit (90% weapon damage, scales with DEX). Your time bar starts at 55% afterwards."},
	# --- INT: Mage (each spell's Mastery adds a Target All version at half damage) ---
	"fireball_1": {"name": "Fire I", "mp": 5, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [7, 11], "element": "fire", "tags": ["cast", "fire"],
		"desc": "Cast a bolt of Fire at one enemy: 7-11 damage (+0.3 per level)."},
	"fireball_2": {"name": "Fire II", "mp": 12, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [18, 28], "element": "fire", "tags": ["cast", "fire"],
		"desc": "Cast a roaring Fire blast at one enemy: 18-28 damage (+0.3 per level)."},
	"fireball_3": {"name": "Fire III", "mp": 22, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [36, 54], "element": "fire", "tags": ["cast", "fire"],
		"desc": "Cast an inferno of Fire on one enemy: 36-54 damage (+0.3 per level)."},
	"frost_1": {"name": "Ice I", "mp": 5, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [6, 9], "element": "ice", "atb_hit": -15.0, "tags": ["cast", "ice"],
		"desc": "Cast a shard of Ice that chills the target's time bar: 6-9 damage (+0.3 per level)."},
	"frost_2": {"name": "Ice II", "mp": 12, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [15, 24], "element": "ice", "atb_hit": -20.0, "tags": ["cast", "ice"],
		"desc": "Cast a lance of Ice that chills the target's time bar: 15-24 damage (+0.3 per level)."},
	"frost_3": {"name": "Ice III", "mp": 22, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [30, 46], "element": "ice", "atb_hit": -30.0, "tags": ["cast", "ice"],
		"desc": "Cast a glacier of Ice that freezes the target's time bar: 30-46 damage (+0.3 per level)."},
	"spark_1": {"name": "Lightning I", "mp": 5, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [2, 16], "element": "lightning", "crit_bonus": 0.1, "tags": ["cast", "lightning"],
		"desc": "Cast a crackling Lightning bolt with +10% critical chance: 2-16 damage (+0.3 per level)."},
	"spark_2": {"name": "Lightning II", "mp": 12, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [4, 42], "element": "lightning", "crit_bonus": 0.12, "tags": ["cast", "lightning"],
		"desc": "Cast a forked Lightning strike with +12% critical chance: 4-42 damage (+0.3 per level)."},
	"spark_3": {"name": "Lightning III", "mp": 22, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.0, "base": [8, 82], "element": "lightning", "crit_bonus": 0.15, "tags": ["cast", "lightning"],
		"desc": "Call down a Lightning storm on one enemy with +15% critical chance: 8-82 damage (+0.3 per level)."},
	# --- INT/CON: Healer ---
	"heal_1": {"name": "Heal I", "mp": 5, "target": "ally", "kind": "heal", "stat": "int", "mult": 1.0, "tags": ["cast", "heal"],
		"desc": "Cast to Heal one ally (INT x2 + 2 per level + 8). Usable outside combat."},
	"heal_2": {"name": "Heal II", "mp": 11, "target": "ally", "kind": "heal", "stat": "int", "mult": 1.9, "tags": ["cast", "heal"],
		"desc": "Cast a strong Heal on one ally (190% of Heal I). Usable outside combat."},
	"heal_3": {"name": "Heal III", "mp": 20, "target": "ally", "kind": "heal", "stat": "int", "mult": 3.0, "tags": ["cast", "heal"],
		"desc": "Cast a mighty Heal on one ally (300% of Heal I). Usable outside combat."},
	"mass_heal_1": {"name": "Mass Heal I", "mp": 14, "target": "allies", "kind": "heal", "stat": "int", "mult": 0.7, "tags": ["cast", "heal"],
		"desc": "Cast to Heal the whole party (70% of Heal I). Usable outside combat."},
	"cure": {"name": "Cure", "mp": 4, "target": "ally", "kind": "cure", "tags": ["cast", "heal"],
		"desc": "Cast to remove Poison and every debuff from one ally. Usable outside combat."},
	"cure_all": {"name": "Cure All", "mp": 10, "target": "allies", "kind": "cure", "tags": ["cast", "heal"],
		"desc": "Cast to remove Poison and every debuff from the whole party. Usable outside combat."},
	"shield": {"name": "Shield", "mp": 6, "target": "ally", "kind": "shield", "stat": "int", "mult": 1.5, "turns": 3, "tags": ["cast", "shield"],
		"desc": "Cast a Shield on one ally: +Armour equal to INT x1.5 + 2 per level + 4 for 3 turns."},
	"shield_all": {"name": "Shield All", "mp": 15, "target": "allies", "kind": "shield", "stat": "int", "mult": 0.7, "turns": 3, "tags": ["cast", "shield"],
		"desc": "Cast a Shield on the whole party: +Armour equal to 70% of (INT x1.5 + 2 per level) + 3 for 3 turns."},
	# --- CON ---
	"second_wind": {"name": "Second Wind", "mp": 4, "target": "self", "kind": "heal", "stat": "con", "mult": 1.2, "tags": ["heal"],
		"desc": "Catch your breath and Heal yourself (CON based). Usable outside combat."},
	"fortify": {"name": "Fortify", "mp": 5, "target": "self", "kind": "buff", "buff": {"def_pct": 0.4}, "turns": 3, "tags": [],
		"desc": "Brace yourself: take 40% less Physical damage for 3 turns."},
	"protect": {"name": "Protect", "mp": 0, "target": "ally_other", "kind": "protect", "tags": ["shield"],
		"desc": "Shield an ally with your body until your next turn: every attack aimed at them hits you instead, and your Armour rises by 50% and all resistances by 10%."},
	# --- Rogue / Ranger / Trickster: traps and debuffs ---
	"poison_blade": {"name": "Poison Blade", "mp": 4, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 0.9, "element": "phys", "tags": ["hit", "melee", "poison"],
		"poison": {"stat": "dex", "mult": 0.9, "base": 4},
		"desc": "A venomed Melee Hit (90% weapon damage, scales with DEX) that inflicts Poison (DEX x0.9 + your level + 4)."},
	"crippling_shot": {"name": "Crippling Shot", "mp": 4, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 1.0, "element": "phys", "tags": ["hit", "shoot"],
		"on_hit_debuff": {"name": "Crippled", "mods": {"speed": -0.35}, "turns": 3},
		"desc": "Shoot a Hit at the legs (100% weapon damage, scales with DEX): the target's time bar fills 35% slower for 3 turns."},
	"hunters_trap": {"name": "Hunter's Trap", "mp": 5, "target": "self", "kind": "trap", "tags": ["trap"],
		"desc": "Set a Trap: 8 + 3 per level Physical damage (+2% per DEX), and the victim loses half its time bar."},
	"hex_weakness": {"name": "Hex of Weakness", "mp": 5, "target": "enemy", "kind": "debuff", "debuff": {"phys_dmg": -0.3, "spell_dmg": -0.3}, "turns": 3, "tags": ["cast"],
		"desc": "Cast a Hex debuff: the target deals 30% less damage for 3 turns."},
	"smoke_bomb": {"name": "Smoke Bomb", "mp": 6, "target": "enemies", "kind": "debuff", "debuff": {"accuracy": -0.25}, "turns": 2, "tags": [],
		"desc": "Blind every enemy: their attacks miss 25% more often for 2 turns."},
	# --- Berserker (STR / CON) ---
	"wind_up": {"name": "Wind Up", "mp": 3, "target": "self", "kind": "buff", "buff": {"empower": 1.5}, "turns": 2, "buff_name": "Empowered",
		"flags": {"consume_on_hit": true}, "atb_after": 50.0, "tags": [],
		"desc": "Gather yourself for one mighty blow: you are Empowered (+150% damage on your next Hit, for up to 2 turns). Your time bar starts at 50% afterwards."},
	"whirlwind": {"name": "Whirlwind", "mp": 10, "target": "enemies", "kind": "phys", "stat": "str", "mult": 1.1, "element": "phys", "atb_after": -20.0, "tags": ["hit", "melee"],
		"desc": "Spin through the enemy ranks: a Melee Hit on every enemy (110% weapon damage, scales with STR). Leaves you off balance - your time bar starts at -20%."},
	"shield_slam": {"name": "Shield Slam", "mp": 5, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.0, "element": "phys", "stun_chance": 0.35, "needs": "shield", "tags": ["hit", "melee"],
		"desc": "Smash your shield into an enemy: a Melee Hit (100% weapon damage, scales with STR) with a 35% chance to Stun. Needs a shield."},
	"war_cry": {"name": "War Cry", "mp": 8, "target": "allies", "kind": "buff", "buff": {"phys_dmg": 0.2}, "turns": 3, "enemy_atb": -15.0, "tags": [],
		"desc": "A thunderous roar: the party deals 20% more Physical damage for 3 turns, and every enemy's time bar is knocked back 15%."},
	"execute": {"name": "Execute", "mp": 6, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.5, "element": "phys", "execute": 0.3, "tags": ["hit", "melee"],
		"desc": "A finishing Melee Hit (150% weapon damage, scales with STR), doubled against enemies below 30% health."},
	# --- Assassin / Rogue (DEX / STR) ---
	"backstab": {"name": "Backstab", "mp": 5, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 1.8, "element": "phys", "crit_vs_weak": 0.4, "tags": ["hit", "melee"],
		"desc": "Strike where it hurts: a Melee Hit (180% weapon damage, scales with DEX) with +40% Critical chance against a target suffering Poison or a Debuff."},
	"fan_of_knives": {"name": "Fan of Knives", "mp": 7, "target": "enemies", "kind": "phys", "stat": "dex", "mult": 0.55, "element": "phys", "tags": ["hit", "poison"],
		"poison": {"stat": "dex", "mult": 0.3, "base": 2},
		"desc": "Hurl a spray of knives: a Hit on every enemy (55% weapon damage, scales with DEX) that inflicts Poison (DEX x0.3 + your level + 2)."},
	"envenom": {"name": "Envenom", "mp": 4, "target": "self", "kind": "buff", "buff": {}, "turns": 4, "buff_name": "Envenomed",
		"flags": {"envenom": {"stat": "dex", "mult": 0.6, "base": 3}, "charges": 3}, "tags": ["poison"],
		"desc": "Coat your blades: your next 3 Hits each inflict Poison (DEX x0.6 + your level + 3). Lasts up to 4 turns."},
	"eviscerate": {"name": "Eviscerate", "mp": 6, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 0.6, "element": "phys", "eviscerate": 1.5, "tags": ["hit", "melee", "poison"],
		"desc": "A Melee Hit (60% weapon damage, scales with DEX) that tears the wound open: all of the target's remaining Poison is dealt at once, at 150%."},
	"flurry": {"name": "Flurry", "mp": 6, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 0.45, "element": "phys", "strikes": 3, "tags": ["hit", "melee"],
		"desc": "Three lightning-fast Melee Hits on one enemy (45% weapon damage each, scales with DEX). Each can be Critical and triggers on-hit effects."},
	"vanish": {"name": "Vanish", "mp": 5, "target": "self", "kind": "buff", "tags": [],
		"buff_list": [{"name": "Hidden", "mods": {}, "turns": 1, "hidden": true},
			{"name": "Shadow Strike", "mods": {"assured_crit": 1.0}, "turns": 2, "consume_on_hit": true}],
		"desc": "Melt into the shadows: you are Hidden until your next turn, and your next Hit is a guaranteed Critical."},
	"garrote": {"name": "Garrote", "mp": 5, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 0.8, "element": "phys", "tags": ["hit", "melee"],
		"on_hit_debuff": {"name": "Silenced", "mods": {}, "turns": 2, "silence": true},
		"desc": "Choke an enemy: a Melee Hit (80% weapon damage, scales with DEX) that inflicts Silence for 2 turns."},
	"mug": {"name": "Mug", "mp": 4, "target": "enemy", "kind": "phys", "stat": "dex", "mult": 0.9, "element": "phys", "mug": true, "tags": ["hit", "melee"],
		"desc": "A Melee Hit (90% weapon damage, scales with DEX) that picks the target's pocket: 50% chance to steal gold, and sometimes an item. Each enemy can only be robbed once."},
	"caltrops": {"name": "Caltrops", "mp": 5, "target": "enemies", "kind": "debuff", "debuff": {"speed": -0.15}, "turns": 2, "buff_name": "Caltrops",
		"dot": {"stat": "dex", "mult": 0.4, "base": 4.0, "lvl": 1.5}, "tags": [],
		"desc": "Scatter caltrops under every enemy: for 2 turns each takes Physical damage whenever it acts (DEX x0.4 + 1.5 per level + 4) and its time bar fills 15% slower."},
	"riposte": {"name": "Riposte", "mp": 4, "target": "self", "kind": "buff", "buff": {"evasion": 0.15}, "raw_turns": 1, "buff_name": "Riposte",
		"flags": {"riposte": true}, "tags": [],
		"desc": "Take a duelling stance until your next turn: +15% Evasion, and you Counter every Hit you dodge."},
	# --- Spellbinder (INT / DEX): curses and weapon enchantments ---
	"slow": {"name": "Slow", "mp": 5, "target": "enemy", "kind": "debuff", "debuff": {"speed": -0.4}, "turns": 3, "buff_name": "Slowed", "tags": ["cast"],
		"desc": "Cast a Debuff: the target's time bar fills 40% slower for 3 turns."},
	"hex_frailty": {"name": "Curse of Frailty", "mp": 6, "target": "enemy", "kind": "debuff", "debuff": {"def_pct": -0.3}, "turns": 3, "tags": ["cast"],
		"desc": "Cast a Debuff: the target takes 30% more Physical damage for 3 turns."},
	"elemental_bane": {"name": "Elemental Bane", "mp": 7, "target": "enemy", "kind": "debuff", "debuff": {"fire_res": -0.25, "ice_res": -0.25, "lightning_res": -0.25}, "turns": 3, "tags": ["cast"],
		"desc": "Cast a Debuff: the target's Fire, Ice and Lightning resistances drop by 25% for 3 turns."},
	"flame_weapon": {"name": "Flame Weapon", "mp": 7, "target": "ally", "kind": "imbue", "element": "fire", "base": [3, 7], "turns": 3, "tags": ["cast", "fire"],
		"desc": "Cast on one ally: for 3 turns their Hits add 3-7 Fire damage (+0.5 per level, +2% per INT)."},
	"frost_weapon": {"name": "Frost Weapon", "mp": 7, "target": "ally", "kind": "imbue", "element": "ice", "base": [2, 6], "turns": 3, "tags": ["cast", "ice"],
		"desc": "Cast on one ally: for 3 turns their Hits add 2-6 Ice damage (+0.5 per level, +2% per INT)."},
	"storm_weapon": {"name": "Storm Weapon", "mp": 7, "target": "ally", "kind": "imbue", "element": "lightning", "base": [1, 10], "turns": 3, "tags": ["cast", "lightning"],
		"desc": "Cast on one ally: for 3 turns their Hits add 1-10 Lightning damage (+0.5 per level, +2% per INT)."},
	# --- Mystic (INT / CON): blessings cast on an ally ---
	"ward": {"name": "Sanctuary Ward", "mp": 7, "target": "ally", "kind": "ward", "turns": 3, "tags": ["cast"],
		"desc": "Cast a Ward on one ally that absorbs INT x2 + 3 per level + 10 damage, for 3 turns."},
	"mist_veil": {"name": "Mist Veil", "mp": 5, "target": "ally", "kind": "buff", "buff": {"evasion": 0.2}, "turns": 3, "tags": ["cast"],
		"desc": "Cast on one ally: +20% Evasion for 3 turns."},
	"clarity": {"name": "Clarity", "mp": 4, "target": "ally", "kind": "buff", "buff": {"mp_regen": 2}, "turns": 3, "tags": ["cast"],
		"desc": "Cast on one ally: +2 MP regeneration (4 times per round) for 3 turns."},
	"inspire": {"name": "Inspire", "mp": 6, "target": "ally", "kind": "buff", "buff": {"spell_dmg": 0.25}, "turns": 3, "tags": ["cast"],
		"desc": "Cast on one ally: +25% spell damage for 3 turns."},
	"haste": {"name": "Haste", "mp": 8, "target": "ally", "kind": "buff", "buff": {"speed": 0.3}, "turns": 3, "tags": ["cast"],
		"desc": "Cast on one ally: their time bar fills 30% faster for 3 turns."},
	"rejuvenate": {"name": "Rejuvenate", "mp": 6, "target": "ally", "kind": "hot", "rounds": 4, "tags": ["cast", "heal"],
		"desc": "Cast {regen} on one ally for 4 rounds: INT x0.15 + 0.25 per level + 1 each tick."},
	# --- Monk: fist techniques (need fist weapons, or bare hands) ---
	"palm_strike": {"name": "Palm Strike", "mp": 3, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.4, "element": "phys", "atb_hit": -25.0, "needs": "fists", "tags": ["hit", "melee"],
		"desc": "A driving open-palm Melee Hit (140% weapon damage) that knocks the target's time bar back 25%. Needs fist weapons or bare hands."},
	"pressure_point": {"name": "Pressure Point", "mp": 5, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.0, "element": "phys", "needs": "fists", "tags": ["hit", "melee"],
		"on_hit_debuff": {"name": "Pressure Point", "mods": {"def_pct": -0.2, "fire_res": -0.15, "ice_res": -0.15, "lightning_res": -0.15}, "turns": 3},
		"desc": "Strike a nerve: a Melee Hit (100% weapon damage) and a Debuff for 3 turns - the target takes 20% more Physical damage and loses 15% Fire, Ice and Lightning resistance. Needs fist weapons or bare hands."},
	"flame_fist": {"name": "Flame Fist", "mp": 6, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.1, "element": "phys", "chi": {"element": "fire", "base": [6, 10]}, "needs": "fists", "tags": ["hit", "melee", "fire"],
		"desc": "A blazing Melee Hit (110% weapon damage) plus 6-10 Fire damage (+0.6 per level, +2% per INT). Needs fist weapons or bare hands."},
	"frost_fist": {"name": "Frost Fist", "mp": 6, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.1, "element": "phys", "chi": {"element": "ice", "base": [5, 9]}, "atb_hit": -20.0, "needs": "fists", "tags": ["hit", "melee", "ice"],
		"desc": "A freezing Melee Hit (110% weapon damage) plus 5-9 Ice damage (+0.6 per level, +2% per INT) that knocks the target's time bar back 20%. Needs fist weapons or bare hands."},
	"thunder_fist": {"name": "Thunder Fist", "mp": 6, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.1, "element": "phys", "chi": {"element": "lightning", "base": [2, 16]}, "crit_bonus": 0.15, "needs": "fists", "tags": ["hit", "melee", "lightning"],
		"desc": "A crackling Melee Hit (110% weapon damage) plus 2-16 Lightning damage (+0.6 per level, +2% per INT), with +15% Critical chance. Needs fist weapons or bare hands."},
	"hundred_fists": {"name": "Hundred Fists", "mp": 9, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 0.35, "element": "phys", "strikes": 5, "needs": "fists", "tags": ["hit", "melee"],
		"desc": "A blur of five Melee Hits on one enemy (35% weapon damage each). Each can be Critical and triggers on-hit effects. Needs fist weapons or bare hands."},
	"quaking_palm": {"name": "Quaking Palm", "mp": 7, "target": "enemy", "kind": "phys", "stat": "atk", "mult": 1.3, "element": "phys", "stun_chance": 0.3, "needs": "fists", "tags": ["hit", "melee"],
		"desc": "A shuddering Melee Hit (130% weapon damage) with a 30% chance to Stun. Needs fist weapons or bare hands."},
	"whirling_kick": {"name": "Whirling Kick", "mp": 7, "target": "enemies", "kind": "phys", "stat": "atk", "mult": 0.8, "element": "phys", "needs": "fists", "tags": ["hit", "melee"],
		"desc": "A spinning kick that is a Melee Hit on every enemy (80% weapon damage). Needs fist weapons or bare hands."},
	"meditate": {"name": "Meditate", "mp": 0, "target": "self", "kind": "meditate", "atb_after": 30.0, "tags": [],
		"desc": "Centre yourself: restore INT + 2 per level + 5 MP and gain {regen} (CON x0.2 + 0.3 per level + 1) for 2 rounds. Your time bar starts at 30% afterwards."},
	# --- Enemy only ---
	"acid_splash": {"name": "Acid Splash", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.3, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"gore": {"name": "Gore", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.6, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"bite": {"name": "Savage Bite", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.4, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"howl": {"name": "Howl", "mp": 0, "target": "allies", "kind": "buff", "buff": {"phys_dmg": 0.25}, "turns": 3, "tags": [], "desc": ""},
	"dirty_strike": {"name": "Dirty Strike", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.6, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"fire_bolt": {"name": "Fire Bolt", "mp": 6, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.8, "element": "fire", "tags": ["cast", "fire"], "desc": ""},
	"leech_bite": {"name": "Leech Bite", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.2, "element": "phys", "drain": 0.5, "tags": ["hit", "melee"], "desc": ""},
	"venom_bite": {"name": "Venom Bite", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.4, "element": "phys", "tags": ["hit", "melee", "poison"],
		"poison": {"stat": "str", "mult": 0.3, "base": 2}, "desc": ""},
	"frost_splash": {"name": "Frost Splash", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.4, "element": "ice", "atb_hit": -15.0, "tags": ["hit", "melee", "ice"], "desc": ""},
	"poison_cloud": {"name": "Poison Cloud", "mp": 0, "target": "enemies", "kind": "poison_cloud", "amount": 10, "tags": ["poison"], "desc": ""},
	"leg_sweep": {"name": "Leg Sweep", "mp": 0, "target": "enemies", "kind": "phys", "stat": "str", "mult": 0.8, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"venom_spit": {"name": "Venom Spit", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 0.5, "element": "phys", "tags": ["hit", "poison"],
		"poison": {"stat": "str", "mult": 0.6, "base": 6}, "desc": ""},
	"summon_spiderlings": {"name": "Call the Brood", "mp": 0, "target": "self", "kind": "summon", "summon": "spiderling", "count": [1, 2], "max_enemies": 4, "tags": [], "desc": ""},
	# --- The Blight (undead) ---
	"rend": {"name": "Rend", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.35, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"bone_ray": {"name": "Bone Ray", "mp": 0, "target": "enemy", "kind": "magic", "stat": "int", "mult": 1.6, "element": "shadow", "tags": ["cast"], "desc": ""},
	"raise_dead": {"name": "Raise Dead", "mp": 0, "target": "self", "kind": "summon", "summon": "zombie", "count": [1, 1], "max_enemies": 5, "tags": [], "desc": ""},
	"curse_frailty": {"name": "Curse of Frailty", "mp": 0, "target": "enemy", "kind": "debuff", "debuff": {"def_pct": -0.3}, "turns": 3, "tags": ["cast"], "desc": ""},
	"curse_wither": {"name": "Withering Curse", "mp": 0, "target": "enemy", "kind": "debuff", "debuff": {"phys_dmg": -0.3, "spell_dmg": -0.3}, "turns": 3, "tags": ["cast"], "desc": ""},
	# --- The Darkness (after the Broodmother falls) ---
	"plague_bite": {"name": "Plague Bite", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.3, "element": "phys", "tags": ["hit", "melee", "poison"],
		"poison": {"stat": "str", "mult": 0.4, "base": 6}, "desc": ""},
	"raise_plague": {"name": "Raise the Plagued", "mp": 0, "target": "self", "kind": "summon", "summon": "plague_zombie", "count": [1, 1], "max_enemies": 5, "tags": [], "desc": ""},
	"death_coil": {"name": "Death Coil", "mp": 0, "target": "enemy", "kind": "magic", "stat": "int", "mult": 2.2, "element": "shadow", "tags": ["cast"], "desc": ""},
	"soul_storm": {"name": "Soul Storm", "mp": 0, "target": "enemies", "kind": "magic", "stat": "int", "mult": 1.0, "element": "shadow", "tags": ["cast"], "desc": ""},
	# --- Eastern isle ---
	"maul": {"name": "Maul", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.6, "element": "phys", "atb_hit": -20.0, "tags": ["hit", "melee"], "desc": ""},
	"volley": {"name": "Volley", "mp": 0, "target": "random3", "kind": "phys", "stat": "dex", "mult": 0.6, "element": "phys", "tags": ["hit", "shoot"], "desc": ""},
	# --- Tidewater Grotto ---
	"shell_bash": {"name": "Shell Bash", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.3, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"static_bite": {"name": "Static Bite", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.3, "element": "lightning", "atb_hit": -10.0, "tags": ["hit", "melee", "lightning"], "desc": ""},
	"crushing_claw": {"name": "Crushing Claw", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 2.2, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"claw_sweep": {"name": "Claw Sweep", "mp": 0, "target": "enemies", "kind": "phys", "stat": "str", "mult": 0.75, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"grab": {"name": "Grab", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 0.8, "element": "phys", "stun": true, "tags": ["hit", "melee"], "desc": ""},
	# --- The sea ---
	"pincer": {"name": "Crushing Pincer", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.5, "element": "phys", "tags": ["hit", "melee"], "desc": ""},
	"shock_lash": {"name": "Shock Lash", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.2, "element": "lightning", "atb_hit": -15.0, "tags": ["hit", "melee", "lightning"], "desc": ""},
	"tidal_wave": {"name": "Tidal Wave", "mp": 0, "target": "enemies", "kind": "magic", "stat": "int", "mult": 0.75, "element": "ice", "tags": ["cast", "ice"], "desc": ""},
	"constrict": {"name": "Constrict", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 1.6, "element": "phys", "atb_hit": -30.0, "tags": ["hit", "melee"], "desc": ""},
	"web": {"name": "Web", "mp": 0, "target": "enemy", "kind": "phys", "stat": "str", "mult": 0.3, "element": "phys", "atb_hit": -45.0, "tags": ["hit"], "desc": ""},
}

const TAG_NAMES := {"hit": "Hit", "melee": "Melee", "shoot": "Shoot", "cast": "Cast", "fire": "Fire", "ice": "Ice", "heal": "Heal",
	"lightning": "Lightning", "shield": "Shield", "poison": "Poison", "trap": "Trap"}

## Abilities may be "id#all": the Target All version unlocked by a Mastery (half damage, 1.5x MP).
func base_id(aid: String) -> String:
	return aid.trim_suffix("#all")

func resolve_ability(aid: String) -> Dictionary:
	var ab: Dictionary = ABILITIES[base_id(aid)]
	if not aid.ends_with("#all"):
		return ab
	var v := ab.duplicate(true)
	v["target"] = "enemies"
	v["mult"] = float(ab.get("mult", 1.0)) * 0.5
	v["mp"] = int(ceil(int(ab["mp"]) * 1.5))
	v["name"] = ab["name"] + " (All)"
	v["desc"] = "{targetall}. " + str(ab["desc"])
	return v

## Tags of an ability as used by this unit (Attack becomes Shoot with a bow).
func tags_for(aid: String, u = null) -> Array:
	var t: Array = ABILITIES[base_id(aid)].get("tags", []).duplicate()
	if aid == "attack" and u != null and not u.is_enemy and Loot.is_bow(u.weapon()):
		t = ["hit", "shoot"]
	return t

## Tooltip lines for an ability: Array of [text, color, colorize]
func ability_lines(aid: String, u = null) -> Array:
	var ab: Dictionary = resolve_ability(aid)
	var lines: Array = []
	var head: String = ab["name"]
	if int(ab["mp"]) > 0:
		head += "   (%d MP)" % int(ab["mp"])
	lines.append([head, Color(1, 0.9, 0.55), false])
	var tags := tags_for(aid, u)
	if tags.size() > 0:
		var names: Array = []
		for t in tags:
			names.append("{%s}" % t)
		lines.append([", ".join(names), Color(0.7, 0.72, 0.82), true])
	if ab["desc"] != "":
		lines.append([ab["desc"], Color(0.92, 0.94, 1.0), true])
	if u != null and tags.has("shoot") and not u.has_bow():
		lines.append(["You need a bow equipped to Shoot.", Color(1.0, 0.4, 0.35), true])
	return lines

## "" if the unit can use the ability now, otherwise the reason.
func ability_problem(aid: String, u) -> String:
	var ab: Dictionary = resolve_ability(aid)
	if tags_for(aid, u).has("shoot") and not u.has_bow():
		return "needs bow"
	if ab.get("needs", "") == "shield" and not u.has_shield():
		return "needs shield"
	if ab.get("needs", "") == "fists" and not u.fists():
		return "needs fists"
	if tags_for(aid, u).has("cast") and u.buffs.any(func(b): return b.get("silence", false)):
		return "silenced"
	if u.mp < int(ab["mp"]):
		return "MP"
	return ""

# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------
const ITEMS := {
	"potion": {"name": "Potion", "price": 15, "target": "ally", "effect": "heal", "amount": 50, "desc": "Heals 50 HP."},
	"bandage": {"name": "Bandage", "price": 8, "target": "ally", "effect": "hot", "amount": 5, "rounds": 2,
		"desc": "{regen:5:2}"},
	"hi_potion": {"name": "Hi-Potion", "price": 60, "target": "ally", "effect": "heal", "amount": 150, "desc": "Heals 150 HP."},
	"ether": {"name": "Ether", "price": 40, "target": "ally", "effect": "mp", "amount": 25, "desc": "Restores 25 MP."},
	"phoenix_down": {"name": "Phoenix Down", "price": 100, "target": "ally_dead", "effect": "revive", "amount": 25, "desc": "Revives a fallen ally with 25% HP."},
	"fire_bomb": {"name": "Fire Bomb", "price": 50, "target": "enemies", "effect": "damage", "amount": 35, "element": "fire", "battle_only": true,
		"desc": "Explodes for 35 Fire damage to all enemies. Battle only."},
}
const SHOP_STOCK := ["potion", "bandage", "hi_potion", "ether", "phoenix_down", "fire_bomb"]

# ---------------------------------------------------------------------------
# Enemies
#   lvl: item level of drops.  wd: natural weapon damage.  gear: equipment drop chance.
# ---------------------------------------------------------------------------
const ENEMIES := {
	"slime": {"name": "Green Slime", "str": 4, "dex": 3, "con": 3, "int": 1, "hp": 16, "mp": 0, "xp": 17, "gold": 3, "aggro": 4, "chase": 2.2,
		"lvl": 1, "wd": [2, 5], "armour": 0, "gear": 0.05,
		"abilities": ["attack", "attack", "acid_splash"], "res": {"fire": -0.5, "ice": 0.25}, "shape": "slime", "scale": 1.4,
		"color": Color(0.35, 0.82, 0.32), "drop": 0.1},
	# Sunpetal Meadow's only inhabitants: big, cold and tougher than wolves.
	"blue_slime": {"name": "Blue Slime", "str": 14, "dex": 12, "con": 12, "int": 3, "hp": 150, "mp": 0, "xp": 162, "gold": 10, "aggro": 5, "chase": 2.7,
		"lvl": 13, "wd": [20, 28], "armour": 8, "gear": 0.12,
		"abilities": ["attack", "attack", "frost_splash"], "res": {"ice": 0.5, "fire": -0.25, "poison": 0.3}, "shape": "slime", "scale": 1.75,
		"color": Color(0.3, 0.55, 0.95), "drop": 0.15},
	"boar": {"name": "Wild Boar", "str": 7, "dex": 4, "con": 6, "int": 1, "hp": 36, "mp": 0, "xp": 36, "gold": 6, "aggro": 3, "chase": 2.9,
		"lvl": 3, "wd": [5, 9], "armour": 4, "gear": 0.08,
		"abilities": ["attack", "attack", "gore"], "res": {}, "shape": "boar", "scale": 1.5,
		"color": Color(0.5, 0.33, 0.2), "drop": 0.15},
	"wolf": {"name": "Grey Wolf", "str": 9, "dex": 12, "con": 6, "int": 2, "hp": 40, "mp": 0, "xp": 58, "gold": 4, "aggro": 6, "chase": 3.6,
		"lvl": 5, "wd": [6, 10], "armour": 2, "gear": 0.1,
		"abilities": ["attack", "attack", "bite", "howl"], "res": {"ice": 0.25}, "shape": "wolf", "scale": 1.5,
		"color": Color(0.55, 0.56, 0.6), "drop": 0.12},
	"bandit": {"name": "Bandit", "str": 11, "dex": 9, "con": 9, "int": 3, "hp": 62, "mp": 0, "xp": 88, "gold": 22, "aggro": 5, "chase": 3.3,
		"lvl": 6, "wd": [7, 12], "armour": 10, "gear": 0.25,
		"abilities": ["attack", "attack", "dirty_strike"], "res": {}, "shape": "bandit", "scale": 1.6,
		"color": Color(0.35, 0.3, 0.26), "drop": 0.3},
	"bandit_mage": {"name": "Bandit Mage", "str": 5, "dex": 8, "con": 5, "int": 12, "hp": 44, "mp": 40, "xp": 104, "gold": 30, "aggro": 5, "chase": 3.0,
		"lvl": 7, "wd": [6, 9], "armour": 3, "gear": 0.25,
		"abilities": ["attack", "fire_bolt", "fire_bolt"], "res": {"fire": 0.3}, "shape": "bandit_mage", "scale": 1.6,
		"color": Color(0.45, 0.25, 0.5), "drop": 0.3},
	"bat": {"name": "Cave Bat", "str": 10, "dex": 16, "con": 8, "int": 2, "hp": 84, "mp": 0, "xp": 81, "gold": 12, "aggro": 6, "chase": 3.9,
		"lvl": 9, "wd": [11, 18], "armour": 3, "gear": 0.14,
		"abilities": ["attack", "attack", "leech_bite"], "res": {}, "shape": "bat", "scale": 1.4,
		"color": Color(0.36, 0.28, 0.4), "drop": 0.12},
	"spider": {"name": "Giant Spider", "str": 16, "dex": 11, "con": 14, "int": 3, "hp": 150, "mp": 0, "xp": 143, "gold": 20, "aggro": 5, "chase": 3.3,
		"lvl": 11, "wd": [14, 22], "armour": 16, "gear": 0.17,
		"abilities": ["attack", "venom_bite", "web"], "res": {"fire": -0.3, "poison": 0.5}, "shape": "spider", "scale": 1.45,
		"color": Color(0.45, 0.33, 0.24), "drop": 0.15},
	# Slow, fat and harmless up close - but its spore clouds poison everyone.
	"fungus": {"name": "Bloated Shroom", "str": 1, "dex": 1, "con": 20, "int": 4, "hp": 190, "mp": 0, "xp": 160, "gold": 16, "lurker": true, "aggro": 5, "chase": 2.1,
		"lvl": 10, "wd": [1, 2], "armour": 0, "gear": 0.12, "speed_mult": 1.15, "wander": 0.4,
		"abilities": ["poison_cloud"], "res": {"poison": 1.0, "fire": -0.4}, "shape": "fungus", "scale": 1.5,
		"color": Color(0.62, 0.22, 0.6), "drop": 0.2},
	# --- The Blight: the dead, dark far side of the island (levels 15-17) ---
	# Zombies never stop coming: slow, tough, and they only ever attack.
	"zombie": {"name": "Rotting Zombie", "str": 18, "dex": 6, "con": 18, "int": 1, "hp": 240, "mp": 0, "xp": 210, "gold": 9, "aggro": 7, "chase": 2.6,
		"lvl": 15, "wd": [30, 42], "armour": 8, "gear": 0.14, "speed_mult": 0.85,
		"abilities": ["attack", "attack", "attack", "rend"], "res": {"poison": 1.0, "fire": -0.35, "ice": 0.2, "shadow": 0.5}, "shape": "zombie", "scale": 1.55,
		"color": Color(0.48, 0.6, 0.38), "drop": 0.15},
	# Necromancers raise more zombies, blast with bone rays and lay curses.
	"necromancer": {"name": "Necromancer", "str": 8, "dex": 12, "con": 10, "int": 20, "hp": 170, "mp": 0, "xp": 300, "gold": 45, "aggro": 6, "chase": 3.0,
		"lvl": 16, "wd": [23, 32], "armour": 4, "gear": 0.3,
		"abilities": ["bone_ray", "bone_ray", "raise_dead", "curse_frailty", "curse_wither"], "res": {"shadow": 0.6, "fire": -0.2, "poison": 0.3}, "shape": "necromancer", "scale": 1.6,
		"color": Color(0.22, 0.12, 0.3), "drop": 0.3},
	# --- The sea: fought from the deck of your boat (levels 12-15) ---
	"reef_crab": {"name": "Reef Crab", "str": 16, "dex": 8, "con": 16, "int": 1, "hp": 150, "mp": 0, "xp": 150, "gold": 14, "aggro": 5, "chase": 2.6,
		"lvl": 12, "wd": [16, 24], "armour": 30, "gear": 0.12,
		"abilities": ["attack", "attack", "pincer"], "res": {"ice": 0.3, "lightning": -0.5}, "shape": "crab", "scale": 1.5,
		"color": Color(0.85, 0.35, 0.22), "drop": 0.15},
	"lash_eel": {"name": "Lash Eel", "str": 12, "dex": 20, "con": 8, "int": 2, "hp": 110, "mp": 0, "xp": 140, "gold": 8, "aggro": 6, "chase": 3.6,
		"lvl": 13, "wd": [18, 26], "armour": 2, "gear": 0.1,
		"abilities": ["attack", "shock_lash"], "res": {"lightning": 0.5, "fire": 0.3}, "shape": "eel", "scale": 1.5,
		"color": Color(0.2, 0.6, 0.55), "drop": 0.12},
	"sea_serpent": {"name": "Sea Serpent", "str": 22, "dex": 12, "con": 22, "int": 8, "hp": 420, "mp": 0, "xp": 420, "gold": 40, "aggro": 6, "chase": 3.0,
		"lvl": 15, "wd": [26, 36], "armour": 14, "gear": 0.35,
		"abilities": ["attack", "tidal_wave", "constrict"], "res": {"ice": 0.4, "fire": 0.2}, "shape": "serpent", "scale": 2.0,
		"color": Color(0.18, 0.42, 0.5), "drop": 0.3},
	# --- The Darkness: everything that walks the island after the Broodmother falls (levels 30-32) ---
	"plague_zombie": {"name": "Plague Zombie", "str": 30, "dex": 10, "con": 30, "int": 1, "hp": 620, "mp": 0, "xp": 900, "gold": 25, "aggro": 7, "chase": 2.8,
		"lvl": 30, "wd": [46, 62], "armour": 25, "gear": 0.25, "speed_mult": 0.85, "dark": true, "aura": true,
		"abilities": ["attack", "attack", "attack", "plague_bite"], "res": {"poison": 1.0, "fire": -0.3, "shadow": 0.6}, "shape": "zombie", "scale": 1.65,
		"color": Color(0.36, 0.44, 0.3), "drop": 0.2},
	"death_priest": {"name": "Death Priest", "str": 14, "dex": 18, "con": 18, "int": 34, "hp": 430, "mp": 0, "xp": 1150, "gold": 90, "aggro": 7, "chase": 3.2,
		"lvl": 31, "wd": [40, 52], "armour": 10, "gear": 0.4, "dark": true, "aura": true,
		"abilities": ["bone_ray", "bone_ray", "raise_plague", "curse_frailty", "curse_wither"], "res": {"shadow": 0.7, "fire": -0.2, "poison": 0.5}, "shape": "necromancer", "scale": 1.7,
		"color": Color(0.12, 0.05, 0.16), "drop": 0.35},
	"shadow_wolf": {"name": "Shadow Wolf", "str": 30, "dex": 30, "con": 22, "int": 4, "hp": 520, "mp": 0, "xp": 1100, "gold": 15, "aggro": 8, "chase": 4.2,
		"lvl": 32, "wd": [48, 64], "armour": 12, "gear": 0.2, "dark": true, "aura": true,
		"abilities": ["attack", "attack", "bite", "howl"], "res": {"shadow": 0.5, "ice": 0.3}, "shape": "wolf", "scale": 1.7,
		"color": Color(0.17, 0.15, 0.22), "drop": 0.2},
	"dread_boar": {"name": "Dread Boar", "str": 34, "dex": 12, "con": 34, "int": 2, "hp": 760, "mp": 0, "xp": 1150, "gold": 20, "aggro": 5, "chase": 3.6,
		"lvl": 32, "wd": [54, 72], "armour": 32, "gear": 0.2, "dark": true, "aura": true,
		"abilities": ["attack", "attack", "gore"], "res": {"shadow": 0.5, "fire": -0.2}, "shape": "boar", "scale": 1.8,
		"color": Color(0.22, 0.12, 0.15), "drop": 0.2},
	# Lord of the fallen Riverbend: beat him to lift the darkness.
	"malgrave": {"name": "Malgrave the Lich", "str": 30, "dex": 20, "con": 40, "int": 50, "hp": 5500, "mp": 0, "xp": 9000, "gold": 2500, "aggro": 0, "chase": 0.0,
		"lvl": 36, "wd": [78, 100], "armour": 40, "gear": 0.0, "boss": true, "dark": true, "aura": true, "unique": "malgraves_phylactery", "speed_mult": 1.3,
		"abilities": ["bone_ray", "death_coil", "soul_storm", "raise_plague", "curse_frailty", "bone_ray"], "res": {"shadow": 0.8, "poison": 1.0, "fire": -0.2}, "shape": "necromancer", "scale": 2.5,
		"color": Color(0.3, 0.05, 0.12), "drop": 0.0},
	# --- The eastern isle: wilderness and bandits (levels 10-12) ---
	"dire_wolf": {"name": "Dire Wolf", "str": 14, "dex": 16, "con": 10, "int": 2, "hp": 115, "mp": 0, "xp": 115, "gold": 6, "aggro": 6, "chase": 3.6,
		"lvl": 10, "wd": [13, 19], "armour": 4, "gear": 0.1,
		"abilities": ["attack", "attack", "bite", "howl"], "res": {"ice": 0.2}, "shape": "wolf", "scale": 1.6,
		"color": Color(0.45, 0.38, 0.31), "drop": 0.12},
	"highland_bear": {"name": "Highland Bear", "str": 20, "dex": 7, "con": 20, "int": 2, "hp": 210, "mp": 0, "xp": 160, "gold": 10, "aggro": 4, "chase": 3.0,
		"lvl": 12, "wd": [17, 25], "armour": 12, "gear": 0.12,
		"abilities": ["attack", "attack", "maul"], "res": {"ice": 0.2}, "shape": "bear", "scale": 1.7,
		"color": Color(0.42, 0.28, 0.18), "drop": 0.15},
	"bandit_raider": {"name": "Bandit Raider", "str": 16, "dex": 12, "con": 14, "int": 3, "hp": 125, "mp": 0, "xp": 125, "gold": 30, "aggro": 5, "chase": 3.3,
		"lvl": 10, "wd": [14, 20], "armour": 14, "gear": 0.3,
		"abilities": ["attack", "attack", "dirty_strike"], "res": {}, "shape": "bandit", "scale": 1.6,
		"color": Color(0.45, 0.2, 0.18), "drop": 0.3},
	"bandit_archer": {"name": "Bandit Archer", "str": 10, "dex": 18, "con": 10, "int": 3, "hp": 95, "mp": 0, "xp": 130, "gold": 30, "aggro": 6, "chase": 3.3,
		"lvl": 11, "wd": [15, 22], "armour": 6, "gear": 0.3,
		"abilities": ["attack", "attack", "volley"], "res": {}, "shape": "bandit_archer", "scale": 1.6,
		"color": Color(0.3, 0.38, 0.22), "drop": 0.3},
	"bandit_shaman": {"name": "Bandit Shaman", "str": 6, "dex": 10, "con": 10, "int": 14, "hp": 105, "mp": 60, "xp": 150, "gold": 40, "aggro": 5, "chase": 3.0,
		"lvl": 12, "wd": [12, 17], "armour": 4, "gear": 0.3,
		"abilities": ["attack", "fire_bolt", "fire_bolt", "curse_wither"], "res": {"fire": 0.3}, "shape": "bandit_mage", "scale": 1.6,
		"color": Color(0.6, 0.25, 0.15), "drop": 0.3},
	# What's left of Gullhaven's people if help comes too late.
	"hollow_villager": {"name": "Hollow Villager", "str": 18, "dex": 7, "con": 18, "int": 1, "hp": 300, "mp": 0, "xp": 300, "gold": 15, "aggro": 6, "chase": 2.8,
		"lvl": 18, "wd": [30, 40], "armour": 6, "gear": 0.25, "speed_mult": 0.9, "dark": true,
		"abilities": ["attack", "attack", "attack", "rend"], "res": {"poison": 1.0, "fire": -0.35, "shadow": 0.5}, "shape": "zombie", "scale": 1.5,
		"color": Color(0.55, 0.52, 0.4), "drop": 0.25},
	# --- Tidewater Grotto, Thornback Isle (levels 12-15) ---
	"hermit_crab": {"name": "Hermit Crab", "str": 15, "dex": 6, "con": 16, "int": 1, "hp": 140, "mp": 0, "xp": 150, "gold": 12, "aggro": 5, "chase": 2.6,
		"lvl": 12, "wd": [15, 22], "armour": 34, "gear": 0.12,
		"abilities": ["attack", "attack", "shell_bash"], "res": {"lightning": -0.3, "ice": 0.2}, "shape": "hermit", "scale": 1.5,
		"color": Color(0.88, 0.45, 0.3), "drop": 0.15},
	"storm_bat": {"name": "Storm Bat", "str": 12, "dex": 22, "con": 8, "int": 3, "hp": 95, "mp": 0, "xp": 145, "gold": 10, "aggro": 6, "chase": 3.9,
		"lvl": 14, "wd": [16, 24], "armour": 3, "gear": 0.12, "spark": true,
		"abilities": ["attack", "static_bite", "static_bite"], "res": {"lightning": 0.6}, "shape": "bat", "scale": 1.45,
		"color": Color(0.28, 0.32, 0.55), "drop": 0.12},
	# Boss of the grotto. Not part of the story: he's back every time you return.
	"ironclaw": {"name": "Old Ironclaw", "str": 26, "dex": 10, "con": 30, "int": 2, "hp": 3500, "mp": 0, "xp": 2200, "gold": 600, "aggro": 0, "chase": 0.0,
		"lvl": 18, "wd": [42, 56], "armour": 45, "gear": 0.0, "boss": true, "unique_pool": ["ironclaw_carapace", "tidebreaker_gauntlets", "crown_of_the_deep"],
		"abilities": ["attack", "crushing_claw", "claw_sweep", "grab"], "res": {"lightning": -0.4, "ice": 0.3}, "shape": "crab", "scale": 4.4,
		"color": Color(0.55, 0.22, 0.2), "drop": 0.0},
	"spiderling": {"name": "Spiderling", "str": 8, "dex": 13, "con": 6, "int": 2, "hp": 46, "mp": 0, "xp": 16, "gold": 0, "aggro": 5, "chase": 3.3,
		"lvl": 8, "wd": [8, 12], "armour": 4, "gear": 0.0,
		"abilities": ["attack", "venom_bite"], "res": {"poison": 0.5}, "shape": "spider", "scale": 0.95,
		"color": Color(0.5, 0.36, 0.28), "drop": 0.05},
	# Boss of the Old Cave: never wanders, fought to open the passage.
	"broodmother": {"name": "The Broodmother", "str": 24, "dex": 13, "con": 20, "int": 6, "hp": 1650, "mp": 0, "xp": 1300, "gold": 300, "aggro": 5, "chase": 3.3,
		"lvl": 12, "wd": [26, 36], "armour": 24, "gear": 0.0, "boss": true, "unique": "broodmothers_coil",
		"abilities": ["attack", "leg_sweep", "venom_spit", "summon_spiderlings"], "res": {"fire": -0.2, "poison": 0.9}, "shape": "spider", "scale": 2.7,
		"color": Color(0.32, 0.12, 0.15), "drop": 0.0},
}

func _n(id: String, lo: int, hi: int) -> Array:
	var a: Array = []
	for i in randi_range(lo, hi):
		a.append(id)
	return a

## Returns an Array of enemy ids for a random encounter in the zone.
func roll_encounter(zone: String) -> Array:
	var r := randf()
	if zone == "cave" and Game.blight_active():
		zone = "dark_cave"   # the dead have taken the tunnel
	match zone:
		"dark":
			if r < 0.3:
				return _n("plague_zombie", 2, 3)
			elif r < 0.5:
				return ["death_priest", "plague_zombie", "plague_zombie"]
			elif r < 0.7:
				return _n("shadow_wolf", 2, 3)
			elif r < 0.85:
				return _n("dread_boar", 1, 2)
			elif r < 0.95:
				return ["shadow_wolf", "dread_boar"]
			return ["death_priest", "shadow_wolf"]
		"grotto":
			if r < 0.25:
				return _n("hermit_crab", 2, 3)
			elif r < 0.45:
				return _n("storm_bat", 2, 3)
			elif r < 0.6:
				return _n("blue_slime", 1, 2)
			elif r < 0.75:
				return ["hermit_crab"] + _n("storm_bat", 1, 2)
			elif r < 0.9:
				return ["blue_slime", "storm_bat", "storm_bat"]
			return ["hermit_crab", "hermit_crab", "blue_slime"]
		"ruins":
			if r < 0.7:
				return _n("hollow_villager", 2, 3)
			return ["necromancer", "hollow_villager", "hollow_villager"]
		"dark_cave":
			if r < 0.6:
				return _n("plague_zombie", 1, 3)
			return ["death_priest", "plague_zombie"]
		"east":
			if r < 0.25:
				return _n("dire_wolf", 2, 3)
			elif r < 0.4:
				return ["highland_bear"]
			elif r < 0.5:
				return ["highland_bear", "dire_wolf"]
			elif r < 0.65:
				return ["bandit_raider", "bandit_raider"]
			elif r < 0.8:
				return ["bandit_raider", "bandit_archer"]
			elif r < 0.92:
				return ["bandit_raider", "bandit_archer", "bandit_shaman"]
			return ["bandit_archer", "bandit_archer", "bandit_raider"]
		"plains":
			if r < 0.45:
				return _n("slime", 1, 3)
			elif r < 0.75:
				return ["boar"]
			elif r < 0.92:
				return ["boar", "slime"]
			return ["boar", "slime", "slime"]
		"cave":
			if r < 0.2:
				return _n("bat", 2, 4)
			elif r < 0.36:
				return ["spider"]
			elif r < 0.48:
				return ["spider"] + _n("bat", 1, 2)
			elif r < 0.56:
				return ["spider", "spider"]
			elif r < 0.68:
				return ["fungus", "spider"]
			elif r < 0.8:
				return ["fungus"] + _n("bat", 2, 3)
			elif r < 0.9:
				return ["fungus", "fungus"]
			return ["spider"] + _n("bat", 3, 3)
		"blight":
			if r < 0.25:
				return ["zombie", "zombie"]
			elif r < 0.45:
				return _n("zombie", 3, 3)
			elif r < 0.7:
				return ["necromancer", "zombie", "zombie"]
			elif r < 0.85:
				return ["necromancer", "zombie"]
			elif r < 0.95:
				return ["necromancer", "necromancer", "zombie"]
			return _n("zombie", 4, 4)
		"sea":
			if r < 0.25:
				return _n("reef_crab", 1, 2)
			elif r < 0.5:
				return _n("lash_eel", 2, 3)
			elif r < 0.7:
				return ["reef_crab", "lash_eel", "lash_eel"]
			elif r < 0.85:
				return ["reef_crab", "reef_crab", "lash_eel"]
			elif r < 0.95:
				return ["sea_serpent"]
			return ["sea_serpent", "lash_eel"]
		"meadow":
			if r < 0.35:
				return ["blue_slime"]
			elif r < 0.75:
				return _n("blue_slime", 2, 2)
			elif r < 0.95:
				return _n("blue_slime", 3, 3)
			return _n("blue_slime", 4, 4)
	# forest
	if r < 0.35:
		return _n("wolf", 2, 3)
	elif r < 0.45:
		return _n("wolf", 3, 5)
	elif r < 0.65:
		return ["bandit", "bandit"]
	elif r < 0.82:
		return ["bandit", "bandit_mage"]
	elif r < 0.92:
		return ["bandit", "bandit", "bandit_mage"]
	return ["boar", "boar"]

# ---------------------------------------------------------------------------
# Quests (state lives in Game.flags["quests"]: id -> "active" | "ready" | "done" | "failed")
# ---------------------------------------------------------------------------
const QUESTS := {
	"mountain_path": {"title": "The Mountain Path", "giver": "Tomas, in Riverbend", "riverbend": true,
		"active": "Tomas's brother lives in Gullhaven, beyond the northern ridge. The only way there is through the Old Cave, and it's overrun by spiders and bats. Clear the way.",
		"ready": "The Broodmother is dead and the cave is open. Return to Tomas in Riverbend.",
		"done": "You cleared the Old Cave, and Tomas paid you for opening the way to his brother.",
		"failed": "The cave is open - but Riverbend fell to the dead before you could tell Tomas."},
	"teddy": {"title": "The Stolen Teddy", "giver": "Elsie, a little girl in Riverbend", "riverbend": true,
		"active": "Bandits robbed Elsie's family on the road, and one of them took her teddy, Mister Buttons. Bandits roam the Thornwood - and further afield. Get him back.",
		"ready": "You found Mister Buttons! Bring him back to Elsie in Riverbend.",
		"done": "Elsie has Mister Buttons back, and gave you her secret ring: the Bramble Loop.",
		"failed": "Riverbend has fallen. You never learned what became of Elsie."},
	"warn_island": {"title": "Sound the Alarm", "giver": "An old fisherman, in Gullhaven",
		"active": "The dead are taking over the island. Sail to the island to the south-east and warn the mayor of the town on its north shore.",
		"done": "You warned Mayor Halvard of Saltmarsh. His ships sailed for Gullhaven."},
}
const BANDITS := ["bandit", "bandit_mage", "bandit_raider", "bandit_archer", "bandit_shaman"]

# ---------------------------------------------------------------------------
# Names / flavour
# ---------------------------------------------------------------------------
const FIRST_NAMES := ["Mira", "Doran", "Kess", "Brann", "Ysolde", "Tamsin", "Garrick", "Pell", "Rook", "Liora",
	"Vance", "Hale", "Sable", "Oren", "Nyx", "Torvin", "Wren", "Iska", "Bram", "Cassia", "Fenn", "Junia", "Merek", "Asha"]
const HIRE_QUOTES := [
	"Coin first, heroics second.",
	"I've seen the Thornwood. You'll want me there.",
	"Buy me another ale and we'll talk. Or just pay me.",
	"I don't run. Not usually.",
	"Slimes? Boars? Pfah. Point me at something real.",
	"Keep me fed and I'll keep you breathing.",
	"I'm between employers. Permanently, if you like.",
]
const RUMOURS := [
	"Wolves have been pushing out of the Thornwood. They hunt in packs - never go in alone.",
	"Bandits camp somewhere in the deep forest. One of them throws fire, they say.",
	"Slimes burn easy. Bring fire if you've got it.",
	"There's an old cave through the northern ridge. Bats, spiders and worse in there - and a meadow full of big blue slimes on the far side.",
	"Gullhaven's shipwright will sell you a boat, if you can find the place.",
	"West of the meadow the land just... dies. Grey trees, dead earth, and the dead walking it. Something there raises them.",
	"Sail if you like, but the water's not empty. Crabs as big as carts, eels that bite like lightning - and once, a serpent.",
	"Rest upstairs before you head out. Dead adventurers don't pay their tabs.",
	"A bash to the head will make anything lose its rhythm. Stagger 'em!",
]

# ---------------------------------------------------------------------------
# Skill tree
# ---------------------------------------------------------------------------
var TREE := {}
const SP := 64.0

func _ready() -> void:
	_build_tree()

func _add(id: String, data: Dictionary) -> void:
	data["id"] = id
	data["links"] = []
	TREE[id] = data

func _link(a: String, b: String) -> void:
	TREE[a]["links"].append(b)
	TREE[b]["links"].append(a)

## spec: "+" (minor, stat a), "+2" (minor, stat b), "PL:Name", "N:Name" (+5 a), "N2:Name" (+3 a +3 b),
## "S:ability", or {"name", "eff"} for a passive.
func _entry(spec, stat: String, stat2: String = "") -> Dictionary:
	if spec is Dictionary:
		return {"name": spec["name"], "type": spec.get("type", "passive"), "effects": spec["eff"]}
	var s: String = spec
	if s == "+":
		return {"name": STAT_NAMES[stat], "type": "minor", "effects": {stat: 1}}
	if s == "+2":
		return {"name": STAT_NAMES[stat2], "type": "minor", "effects": {stat2: 1}}
	if s.begins_with("PL:"):
		return {"name": s.substr(3), "type": "major", "effects": {stat + "_pl": 1}}
	if s.begins_with("N2:"):
		return {"name": s.substr(3), "type": "notable", "effects": {stat: 3, stat2: 3}}
	if s.begins_with("N:"):
		return {"name": s.substr(2), "type": "notable", "effects": {stat: 5}}
	if s.begins_with("S:"):
		var aid := s.substr(2)
		return {"name": ABILITIES[aid]["name"], "type": "skill", "effects": {"skill": aid}}
	push_error("bad tree spec " + s)
	return {}

func _polar(deg: float, r: float) -> Vector2:
	return Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * SP * r

# ---------------------------------------------------------------------------
# Skill tree layout
#   Four stat spokes: STR up, DEX right, INT down, CON left (radius 1-15).
#   Eight class arms between them (radius 3-16), each mixing its two neighbouring stats.
#   Rings at radius 5, 9 and 13 cross-link every spoke and arm, so most nodes can be
#   reached from more than one direction. Four corner nodes join each quadrant's arms.
# ---------------------------------------------------------------------------
const SPOKES := {
	"str": {"ang": -90.0, "main": ["+", "+", "S:bash", "+", "PL:Titan's Growth I", "+", {"name": "Brutality", "eff": {"phys_dmg": 0.1}},
		"N:Brute Force", "+", "PL:Titan's Growth II", "+", "S:cleave", {"name": "Wide Arc", "eff": {"sk_cleave_dmg": 0.1}}, "N:Juggernaut", "PL:Titan's Growth III"]},
	"dex": {"ang": 0.0, "main": ["+", "+", "S:multishot", "+", "PL:Fleetfoot I", "+", {"name": "Keen Eye", "eff": {"crit": 0.05}},
		"N:Lightning Reflexes", "+", "PL:Fleetfoot II", "+", {"name": "Swiftness", "eff": {"speed": 0.1}}, {"name": "Swift Shadows", "eff": {"sk_quick_jab_dmg": 0.15, "sk_flurry_dmg": 0.15}}, "N:Windrunner", "PL:Fleetfoot III"]},
	"int": {"ang": 90.0, "main": ["+", "+", {"name": "Mana Font", "eff": {"mp_regen": 1}}, "+", "PL:Sage's Growth I", "+", {"name": "Pyromancy", "eff": {"fire_dmg": 0.1}},
		"N:Arcane Mind", {"name": "Lingering Hex", "eff": {"sk_slow_turns": 1, "sk_hex_frailty_turns": 1, "sk_elemental_bane_turns": 1, "sk_hex_weakness_turns": 1}}, "PL:Sage's Growth II", "+", {"name": "Resonance", "eff": {"spell_dmg": 0.1}}, {"name": "Spellweaving", "eff": {"spell_dmg": 0.1}}, "N:Archmage's Insight", "PL:Sage's Growth III"]},
	"con": {"ang": 180.0, "main": ["+", "+", "S:second_wind", "+", "PL:Stalwart I", "+", {"name": "Thick Skin", "eff": {"def_pct": 0.1}},
		"N:Iron Hide", "+", "PL:Stalwart II", "+", "S:fortify", {"name": "Steadfast", "eff": {"sk_fortify_turns": 1, "sk_war_cry_turns": 1}}, "N:Unbreakable", "PL:Stalwart III"]},
}

## Class arms. a = nearer stat, b = the other neighbour. 14 entries at radius 3..16.
const ARMS := {
	"warrior": {"name": "Warrior", "ang": -112.5, "a": "str", "b": "con", "home": "str", "content": [
		"+", "+2", {"name": "Heavy Hands", "eff": {"phys_dmg": 0.1}}, "+", "+2", "N2:Battle Hardened", "+",
		"S:charged_strike", "+2", {"name": "Sweeping Blows", "eff": {"sk_cleave_dmg": 0.1, "sk_whirlwind_dmg": 0.1}}, {"name": "Terrifying Victor", "eff": {"ow_freeze": 0.5}}, "+2", "+",
		{"name": "Warlord", "type": "keystone", "eff": {"str": 4, "con": 4, "phys_dmg": 0.15}}]},
	"defender": {"name": "Defender", "ang": -157.5, "a": "con", "b": "str", "home": "con", "content": [
		"+", "+2", {"name": "Bulwark", "eff": {"def_pct": 0.1}}, "+", "S:protect", "N2:Iron Will", "+",
		{"name": "Guardian's Aegis", "eff": {"shield_share": 0.5}}, "+2", {"name": "Vitality", "eff": {"hp_pct": 0.1}},
		{"name": "Shield Wall", "eff": {"def_pct": 0.1}}, "+2", {"name": "Shield Training", "eff": {"sk_shield_slam_stun": 0.15, "sk_shield_slam_dmg": 0.15}},
		{"name": "Bastion", "type": "keystone", "eff": {"con": 5, "def_pct": 0.1, "hp_pct": 0.1}}]},
	"ranger": {"name": "Ranger", "ang": -67.5, "a": "str", "b": "dex", "home": "str", "content": [
		"+2", "+", {"name": "Precision", "eff": {"phys_dmg": 0.1}}, "+2", "S:crippling_shot", "N2:Hunter's Stamina", "+2",
		"S:aimed_shot", "+", "S:hunters_trap", {"name": "Eagle Eye", "eff": {"crit": 0.05}}, "+", "+2",
		{"name": "Deadeye", "type": "keystone", "eff": {"dex": 4, "str": 4, "crit": 0.08}}]},
	"rogue": {"name": "Rogue", "ang": -22.5, "a": "dex", "b": "str", "home": "dex", "content": [
		"+", {"name": "Hunter's Insight", "eff": {"insight": 1}}, "S:quick_jab", "S:riposte", "S:poison_blade", "N2:Cutthroat",
		{"name": "Light Step", "eff": {"ow_slow": 0.1}}, "+", {"name": "Virulence", "eff": {"sk_poison_blade_poison": 0.3, "sk_fan_of_knives_poison": 0.3, "sk_envenom_poison": 0.3}}, {"name": "Elusive", "eff": {"evasion": 0.05}},
		{"name": "Vanishing Act", "eff": {"ow_flee_freeze": 1.0}}, "+2", "+",
		{"name": "Shadowstep", "type": "keystone", "eff": {"dex": 5, "evasion": 0.06, "speed": 0.05}}]},
	"trickster": {"name": "Trickster", "ang": 22.5, "a": "dex", "b": "int", "home": "dex", "content": [
		"+", "+2", {"name": "Frostbound Steel", "eff": {"ice_dmg": 0.1}}, "S:hex_weakness", "+2", "N2:Sleight of Hand", "+",
		"S:ice_strike_1", {"name": "Frostbitten Edge", "eff": {"sk_ice_strike_1_dmg": 0.2, "sk_frost_weapon_pow": 0.2}}, "S:smoke_bomb", {"name": "Long Shadow", "eff": {"ow_radius": 3.0}}, "+2", "+",
		{"name": "Illusionist", "type": "keystone", "eff": {"dex": 3, "int": 3, "evasion": 0.05, "spell_dmg": 0.1}}]},
	"mage": {"name": "Mage", "ang": 67.5, "a": "int", "b": "dex", "home": "int",
		"trunk": ["+", "+2", "N2:Quick Study"],
		"subs": [
			{"key": "fire", "dang": -11.0, "content": ["S:fireball_1", {"name": "Fire Mastery I", "type": "mastery", "eff": {"mastery": "fireball_1"}},
				"+", "+2", {"name": "Kindling", "eff": {"fire_dmg": 0.1}}, "S:fireball_2", {"name": "Fire Mastery II", "type": "mastery", "eff": {"mastery": "fireball_2"}},
				"+", "+2", "S:fireball_3", {"name": "Fire Mastery III", "type": "mastery", "eff": {"mastery": "fireball_3"}}]},
			{"key": "ice", "dang": 0.0, "content": ["S:frost_1", {"name": "Ice Mastery I", "type": "mastery", "eff": {"mastery": "frost_1"}},
				"+", "+2", {"name": "Cryomancy", "eff": {"ice_dmg": 0.1}}, "S:frost_2", {"name": "Ice Mastery II", "type": "mastery", "eff": {"mastery": "frost_2"}},
				"+", "+2", "S:frost_3", {"name": "Ice Mastery III", "type": "mastery", "eff": {"mastery": "frost_3"}}]},
			{"key": "bolt", "dang": 11.0, "content": ["S:spark_1", {"name": "Lightning Mastery I", "type": "mastery", "eff": {"mastery": "spark_1"}},
				"+", "+2", {"name": "Conductivity", "eff": {"lightning_dmg": 0.1}}, "S:spark_2", {"name": "Lightning Mastery II", "type": "mastery", "eff": {"mastery": "spark_2"}},
				"+", "+2", "S:spark_3", {"name": "Lightning Mastery III", "type": "mastery", "eff": {"mastery": "spark_3"}}]},
		],
		"tip": {"name": "Archmage", "type": "keystone", "eff": {"int": 5, "spell_dmg": 0.15}}},
	"healer": {"name": "Healer", "ang": 112.5, "a": "int", "b": "con", "home": "int", "content": [
		"+", "+2", "S:heal_1", "S:shield", "+", "N2:Gentle Hands", "S:cure", "S:heal_2",
		{"name": "Devotion", "eff": {"heal_pow": 0.1}}, "S:shield_all", "S:cure_all", {"name": "Sanctified Steel", "eff": {"sk_flame_weapon_pow": 0.25, "sk_frost_weapon_pow": 0.25, "sk_storm_weapon_pow": 0.25, "sk_ward_pow": 0.15}}, "S:heal_3",
		{"name": "Saint", "type": "keystone", "eff": {"int": 3, "con": 3, "heal_pow": 0.2}}]},
	"monk": {"name": "Monk", "ang": 157.5, "a": "con", "b": "int", "home": "con",
		"trunk": ["+", "+2", "N2:Discipline"],
		"subs": [
			{"key": "body", "dang": 0.0, "content": ["+", {"name": "Fireproof", "eff": {"fire_res": 0.1}}, "S:meditate", {"name": "Frostproof", "eff": {"ice_res": 0.1}},
				{"name": "Frozen Knuckles", "eff": {"fist_add_ice_min": 2, "fist_add_ice_max": 5}}, {"name": "Flowing Water", "eff": {"sk_mist_veil_turns": 1, "sk_haste_turns": 1}},
				"S:quaking_palm", {"name": "Inner Calm", "eff": {"hp_regen": 2}}, "S:whirling_kick",
				{"name": "Storm Knuckles", "eff": {"fist_add_lightning_min": 1, "fist_add_lightning_max": 8}}, {"name": "Rapid Strikes", "eff": {"fist_double": 0.1}}]},
			{"key": "fist", "dang": 10.0, "content": ["S:palm_strike", {"name": "Iron Fists", "eff": {"fist_dmg": 0.15}}, "S:pressure_point",
				{"name": "Burning Palms", "eff": {"fist_add_fire_min": 2, "fist_add_fire_max": 5}}, "S:flame_fist", "S:frost_fist",
				{"name": "Inner Strength", "eff": {"fist_con": 0.01}}, "S:thunder_fist", "S:hundred_fists",
				{"name": "Chi Mastery", "eff": {"sk_flame_fist_dmg": 0.25, "sk_frost_fist_dmg": 0.25, "sk_thunder_fist_dmg": 0.25, "fist_dmg": 0.1}},
				{"name": "Twin Dragon Style", "type": "notable", "eff": {"attack_twice": 1}}]},
		],
		"tip": {"name": "Inner Peace", "type": "keystone", "eff": {"con": 4, "int": 2, "hp_regen": 3, "evasion": 0.05}}},
}

## Diagonal branches filling the gaps between two class arms (radius 3 outwards). A short trunk
## splits into two lines that lean towards each neighbouring arm. They join the rings like everything else.
const DIAGONALS := {
	"berserker": {"name": "Berserker", "ang": -135.0, "a": "str", "b": "con", "arms": ["warrior", "defender"],
		"trunk": ["+", "S:wind_up", "N2:Bloodlust"],
		"subs": [
			{"key": "w", "dang": 9.0, "content": ["+", "S:execute", "+2", {"name": "Coiled Spring", "eff": {"sk_wind_up_pow": 0.5}}, "+", "S:whirlwind",
				{"name": "Headsman", "eff": {"sk_execute_dmg": 0.25}}]},
			{"key": "d", "dang": -9.0, "content": ["+2", "S:shield_slam", "+", "S:war_cry", "+2", {"name": "Rallying Roar", "eff": {"sk_war_cry_pow": 0.5}}, "N2:Warmonger"]},
		]},
	"assassin": {"name": "Assassin", "ang": -45.0, "a": "dex", "b": "str", "arms": ["rogue", "ranger"],
		"trunk": ["+", "S:backstab", "N2:Killer Instinct"],
		"subs": [
			{"key": "r", "dang": 9.0, "content": ["+", "S:envenom", "S:fan_of_knives", "+2", "S:eviscerate", {"name": "Cruelty", "eff": {"sk_eviscerate_dmg": 0.25}}, "S:vanish"]},
			{"key": "g", "dang": -9.0, "content": ["+2", "S:flurry", {"name": "Opportunist", "eff": {"sk_backstab_crit": 0.15, "sk_backstab_dmg": 0.1}}, "S:garrote", "+", "S:mug", "S:caltrops"]},
		]},
	"spellbinder": {"name": "Spellbinder", "ang": 39.0, "a": "int", "b": "dex", "arms": ["trickster", "mage"],
		"trunk": ["+", "S:slow", "N2:Hexcraft"],
		"subs": [
			{"key": "c", "dang": -5.5, "content": ["+2", "S:hex_frailty", "+", "S:elemental_bane", {"name": "Withering Gaze", "eff": {"sk_slow_pow": 0.25, "sk_hex_frailty_pow": 0.25, "sk_elemental_bane_pow": 0.25, "sk_hex_weakness_pow": 0.25}}, "+2", "N2:Malediction"]},
			{"key": "e", "dang": 7.0, "content": ["+", "S:flame_weapon", "+2", "S:frost_weapon", "+", "S:storm_weapon", {"name": "Runesmith", "eff": {"sk_flame_weapon_pow": 0.25, "sk_frost_weapon_pow": 0.25, "sk_storm_weapon_pow": 0.25}}]},
		]},
	"mystic": {"name": "Mystic", "ang": 135.0, "a": "int", "b": "con", "arms": ["healer", "monk"],
		"trunk": ["+", "S:ward", "N2:Serenity"],
		"subs": [
			{"key": "h", "dang": -9.0, "content": ["+", "S:clarity", "+2", "S:inspire", "+", "S:rejuvenate", {"name": "Wellspring", "eff": {"sk_rejuvenate_pow": 0.3, "sk_clarity_pow": 0.5}}]},
			{"key": "m", "dang": 9.0, "content": ["+2", "S:mist_veil", "+", "S:haste", "+2", {"name": "Ironbark", "eff": {"sk_ward_pow": 0.3}}, "N2:Tranquility"]},
		]},
}

const CORNERS := [
	{"id": "corner_ne", "ang": -45.0, "arms": ["ranger", "rogue"], "name": "Wild Hunt", "eff": {"str": 3, "dex": 3, "crit": 0.05}},
	{"id": "corner_se", "ang": 45.0, "arms": ["trickster", "mage"], "name": "Arcane Trickery", "eff": {"dex": 3, "int": 3, "spell_dmg": 0.1}},
	{"id": "corner_sw", "ang": 135.0, "arms": ["healer", "monk"], "name": "Body and Soul", "eff": {"int": 3, "con": 3, "heal_pow": 0.1, "hp_pct": 0.05}},
	{"id": "corner_nw", "ang": -135.0, "arms": ["defender", "warrior"], "name": "Unyielding", "eff": {"con": 3, "str": 3, "def_pct": 0.05, "phys_dmg": 0.05}},
]
const RINGS := [5, 9, 13]

func _nearest_stat(deg: float) -> String:
	var best := "str"
	var bd := 999.0
	for st in SPOKES:
		var d: float = absf(wrapf(deg - float(SPOKES[st]["ang"]), -180.0, 180.0))
		if d < bd:
			bd = d
			best = st
	return best

func sc_len(arm: Dictionary) -> int:
	return (arm["subs"][0]["content"] as Array).size()

func _arm_node(id: String, spec, arm: Dictionary, aid: String, ang: float, r: int, at_radius: Dictionary) -> void:
	var e := _entry(spec, arm["a"], arm["b"])
	e["pos"] = _polar(ang, r)
	e["branch"] = aid
	e["aff"] = {arm["a"]: 0.6, arm["b"]: 0.4}
	e["class"] = arm["name"]
	_add(id, e)
	if not at_radius.has(r):
		at_radius[r] = []
	at_radius[r].append([ang, id])

func _build_tree() -> void:
	TREE.clear()
	BRANCH_COLORS["warrior"] = BRANCH_COLORS["str"].lerp(BRANCH_COLORS["con"], 0.35)
	BRANCH_COLORS["defender"] = BRANCH_COLORS["con"].lerp(BRANCH_COLORS["str"], 0.35)
	BRANCH_COLORS["ranger"] = BRANCH_COLORS["str"].lerp(BRANCH_COLORS["dex"], 0.35)
	BRANCH_COLORS["rogue"] = BRANCH_COLORS["dex"].lerp(BRANCH_COLORS["str"], 0.35)
	BRANCH_COLORS["trickster"] = BRANCH_COLORS["dex"].lerp(BRANCH_COLORS["int"], 0.35)
	BRANCH_COLORS["mage"] = BRANCH_COLORS["int"].lerp(BRANCH_COLORS["dex"], 0.35)
	BRANCH_COLORS["healer"] = BRANCH_COLORS["int"].lerp(BRANCH_COLORS["con"], 0.35)
	BRANCH_COLORS["monk"] = BRANCH_COLORS["con"].lerp(BRANCH_COLORS["int"], 0.35)
	BRANCH_COLORS["berserker"] = BRANCH_COLORS["str"].lerp(BRANCH_COLORS["con"], 0.5).lightened(0.1)
	BRANCH_COLORS["assassin"] = BRANCH_COLORS["dex"].lerp(BRANCH_COLORS["str"], 0.5).lightened(0.1)
	BRANCH_COLORS["spellbinder"] = BRANCH_COLORS["int"].lerp(BRANCH_COLORS["dex"], 0.5).lightened(0.1)
	BRANCH_COLORS["mystic"] = BRANCH_COLORS["int"].lerp(BRANCH_COLORS["con"], 0.5).lightened(0.1)
	_add("origin", {"name": "Origin", "type": "origin", "effects": {}, "pos": Vector2.ZERO, "branch": "none", "aff": {}})
	var at_radius := {}   # radius -> [[angle, id], ...] for ring links
	# Spokes (ids str_m1.. kept stable for saves)
	for st in SPOKES:
		var ang: float = SPOKES[st]["ang"]
		var main: Array = SPOKES[st]["main"]
		var prev := "origin"
		for i in main.size():
			var e := _entry(main[i], st)
			var id := "%s_m%d" % [st, i + 1]
			e["pos"] = _polar(ang, i + 1)
			e["branch"] = st
			e["aff"] = {st: 1.0}
			_add(id, e)
			_link(prev, id)
			prev = id
			if not at_radius.has(i + 1):
				at_radius[i + 1] = []
			at_radius[i + 1].append([ang, id])
	# Class arms (a straight line of 14 nodes, or a trunk that splits into sub-lines)
	var arm_tip := {}
	for aid in ARMS:
		var arm: Dictionary = ARMS[aid]
		var ang2: float = arm["ang"]
		var line: Array = arm.get("trunk", arm.get("content", []))
		var prev2 := "%s_m2" % arm["home"]
		for j in line.size():
			var id2 := "%s_%d" % [aid, j + 1]
			_arm_node(id2, line[j], arm, aid, ang2, j + 3, at_radius)
			_link(prev2, id2)
			prev2 = id2
		arm_tip[aid] = prev2
		if arm.has("subs"):
			var split := prev2
			var ends: Array = []
			for sub in arm["subs"]:
				var sang: float = ang2 + float(sub["dang"])
				var sc: Array = sub["content"]
				var prev4 := split
				for k2 in sc.size():
					var id4 := "%s_%s_%d" % [aid, sub["key"], k2 + 1]
					_arm_node(id4, sc[k2], arm, aid, sang, line.size() + 3 + k2, at_radius)
					_link(prev4, id4)
					prev4 = id4
				ends.append(prev4)
			var tid := "%s_tip" % aid
			var te := _entry(arm["tip"], arm["a"], arm["b"])
			te["pos"] = _polar(ang2, line.size() + 3 + sc_len(arm) + 0.6)
			te["branch"] = aid
			te["aff"] = {arm["a"]: 0.6, arm["b"]: 0.4}
			te["class"] = arm["name"]
			_add(tid, te)
			for e_id in ends:
				_link(e_id, tid)
			arm_tip[aid] = tid
	# Diagonal branches between two arms
	for did in DIAGONALS:
		var dg: Dictionary = DIAGONALS[did]
		var dang: float = dg["ang"]
		var trunk: Array = dg["trunk"]
		var prevd := ""
		for j in trunk.size():
			var idd := "%s_%d" % [did, j + 1]
			_arm_node(idd, trunk[j], dg, did, dang, j + 3, at_radius)
			if j == 0:
				for arm_id in dg["arms"]:
					_link("%s_1" % arm_id, idd)
			else:
				_link(prevd, idd)
			prevd = idd
		for sub in dg["subs"]:
			var prevs := prevd
			var sc2: Array = sub["content"]
			for k in sc2.size():
				var ids := "%s_%s_%d" % [did, sub["key"], k + 1]
				_arm_node(ids, sc2[k], dg, did, dang + float(sub["dang"]), trunk.size() + 3 + k, at_radius)
				_link(prevs, ids)
				prevs = ids
	# Rings with bridge nodes across long gaps
	for r in RINGS:
		var lst: Array = at_radius[r]
		lst.sort_custom(func(x, y): return x[0] < y[0])
		for k in lst.size():
			var a0: Array = lst[k]
			var a1: Array = lst[(k + 1) % lst.size()]
			var gap: float = wrapf(float(a1[0]) - float(a0[0]), 0.0, 360.0)
			var chord: float = 2.0 * r * SP * sin(deg_to_rad(gap) * 0.5)
			var nb := int(chord / 150.0)
			var prev3: String = a0[1]
			for bi in nb:
				var t := float(bi + 1) / float(nb + 1)
				var bang: float = float(a0[0]) + gap * t
				var stb := _nearest_stat(bang)
				var bid := "ring%d_%d_%d" % [r, k, bi]
				var be := _entry("+", stb)
				be["pos"] = _polar(bang, r)
				be["branch"] = stb
				be["aff"] = {stb: 1.0}
				_add(bid, be)
				_link(prev3, bid)
				prev3 = bid
			_link(prev3, a1[1])
	# Corners join each quadrant's two arms
	for c in CORNERS:
		_add(c["id"], {"name": c["name"], "type": "keystone", "effects": c["eff"], "pos": _polar(c["ang"], 17.6), "branch": "none",
			"aff": {}, "class": "Corner"})
		for arm_id in c["arms"]:
			_link(c["id"], arm_tip[arm_id])

const EFFECT_NAMES := {
	"phys_dmg": "Physical Damage", "fire_dmg": "Fire Damage", "ice_dmg": "Ice Damage", "spell_dmg": "Spell Damage",
	"heal_pow": "Healing Power", "crit": "Critical Chance", "evasion": "Evasion", "speed": "Speed",
	"def_pct": "Physical Damage Reduction", "fire_res": "Fire Resistance", "ice_res": "Ice Resistance", "hp_pct": "Maximum HP",
	"magic_res": "Magic Resistance", "lightning_dmg": "Lightning Damage", "lightning_res": "Lightning Resistance",
}

## "sk_<ability>_<what>": passives that improve one skill.
func skill_mod_text(k: String, v: float) -> String:
	var what := k.get_slice("_", k.count("_"))
	var aid := k.substr(3, k.length() - 4 - what.length())
	var nm: String = ABILITIES[aid]["name"] if ABILITIES.has(aid) else aid
	match what:
		"dmg":
			return "%s: +%d%% damage" % [nm, int(round(v * 100.0))]
		"crit":
			return "%s: +%d%% Critical chance" % [nm, int(round(v * 100.0))]
		"poison":
			return "%s: +%d%% Poison" % [nm, int(round(v * 100.0))]
		"turns":
			return "%s: lasts %d more turn%s" % [nm, int(v), "" if int(v) == 1 else "s"]
		"stun":
			return "%s: +%d%% chance to Stun" % [nm, int(round(v * 100.0))]
		"pow":
			return "%s: +%d%% effect" % [nm, int(round(v * 100.0))]
	return "%s: %s %+.2f" % [nm, what, v]

func describe_effects(eff: Dictionary) -> String:
	var lines: Array = []
	for k in eff:
		var v = eff[k]
		if k == "skill":
			var ab: Dictionary = ABILITIES[v]
			lines.append("Grants skill: %s (%d MP)" % [ab["name"], ab["mp"]])
			lines.append(ab["desc"])
		elif k == "mastery":
			lines.append("Unlocks {targetall} for %s." % ABILITIES[v]["name"])
		elif k.begins_with("sk_"):
			lines.append(skill_mod_text(k, float(v)))
		elif k.begins_with("fist_add_") and k.ends_with("_min"):
			var el: String = k.trim_prefix("fist_add_").trim_suffix("_min")
			lines.append("Fist Hits add %d-%d %s damage" % [int(v), int(eff.get("fist_add_%s_max" % el, v)), el.capitalize()])
		elif k.begins_with("fist_add_"):
			pass
		elif k == "fist_dmg":
			lines.append("Fist Hits deal +%d%% damage" % int(round(float(v) * 100.0)))
		elif k == "fist_con":
			lines.append("Fist Hits deal +%s%% damage per CON" % str(snappedf(float(v) * 100.0, 0.1)).trim_suffix(".0"))
		elif k == "fist_double":
			lines.append("+%d%% chance for Fist Hits to Hit twice" % int(round(float(v) * 100.0)))
		elif k == "attack_twice":
			lines.append("Your basic Attack Hits twice while fighting with fists")
		elif k == "shield_share":
			lines.append("Shield effects you apply (Shield spells, Protect) also add %d%% of your own Armour." % int(round(float(v) * 100)))
		elif k == "mp_regen":
			lines.append("+%d MP Regeneration" % int(v))
		elif k == "hp_regen":
			lines.append("{regen:%d}" % int(v))
		elif k == "ow_slow":
			lines.append("Monsters move %d%% slower on the map (whole party benefits)." % int(round(float(v) * 100)))
		elif k == "ow_freeze":
			lines.append("After you win a fight, nearby monsters stay frozen +%.1f seconds (whole party benefits)." % float(v))
		elif k == "ow_flee_freeze":
			lines.append("After you flee, nearby monsters stay frozen +%.1f seconds (whole party benefits)." % float(v))
		elif k == "ow_radius":
			lines.append("Post-battle freeze reaches +%d tiles further (whole party benefits)." % int(v))
		elif k == "insight":
			lines.append("Hover over monsters on the overworld to see their numbers, health and threat.")
		elif STAT_NAMES.has(k):
			lines.append("+%d %s" % [v, STAT_NAMES[k]])
		elif k.ends_with("_pl"):
			lines.append("+%d %s for every 2 character levels (retroactive)" % [v, STAT_NAMES[k.substr(0, 3)]])
		elif EFFECT_NAMES.has(k):
			lines.append("+%d%% %s" % [int(round(float(v) * 100.0)), EFFECT_NAMES[k]])
		else:
			lines.append("%s %s" % [k, str(v)])
	return "\n".join(lines)
