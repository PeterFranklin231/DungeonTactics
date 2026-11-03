class_name Glossary
extends RefCounted
## Key terms. Descriptions everywhere else only *use* these words; what they mean lives here
## and is shown when you hover the word.
##
## Text markup: plain keywords ("Hit", "Poison", "Fire"...) are detected automatically.
## Terms with numbers use braces:  {regen:5:2} -> "Regeneration +5 for 2 rounds"
##                                 {regen:5}   -> "Regeneration +5"
##                                 {poison:12} -> "Poison 12"
##                                 {shield}    -> "Shield" (any term by id)

const TERMS := {
	"hit": {"name": "Hit", "color": Color(1.0, 0.78, 0.35),
		"text": "A weapon attack: your weapon's damage, scaled by your stats, plus any damage added to Hits. Hits can miss."},
	"melee": {"name": "Melee", "color": Color(1.0, 0.45, 0.4),
		"text": "A close-range Hit with your weapon."},
	"shoot": {"name": "Shoot", "color": Color(0.55, 0.95, 0.45),
		"text": "A ranged Hit with a bow. Needs a bow equipped."},
	"cast": {"name": "Cast", "color": Color(0.6, 0.72, 1.0),
		"text": "A spell. Costs MP, always lands and scales with INT."},
	"physical": {"name": "Physical", "color": Color(0.88, 0.84, 0.74),
		"text": "Weapon damage. Reduced by Armour."},
	"fire": {"name": "Fire", "color": Color(1.0, 0.55, 0.2),
		"text": "Elemental damage. Ignores Armour; reduced by Fire resistance."},
	"ice": {"name": "Ice", "color": Color(0.55, 0.9, 1.0),
		"text": "Elemental damage. Ignores Armour; reduced by Ice resistance."},
	"lightning": {"name": "Lightning", "color": Color(1.0, 0.95, 0.4),
		"text": "Elemental damage. Ignores Armour; reduced by Lightning resistance."},
	"shadow": {"name": "Shadow", "color": Color(0.75, 0.5, 1.0),
		"text": "Dark magic. Ignores Armour; reduced by Magic resistance."},
	"armour": {"name": "Armour", "color": Color(0.8, 0.82, 0.9),
		"text": "Reduces Physical damage taken. Stronger against small hits than big ones, up to 75%."},
	"evasion": {"name": "Evasion", "color": Color(0.6, 0.9, 0.7),
		"text": "Chance to dodge Hits completely."},
	"critical": {"name": "Critical", "color": Color(1.0, 0.95, 0.3),
		"text": "A critical Hit or spell deals 160% damage."},
	"heal": {"name": "Heal", "color": Color(0.5, 1.0, 0.6),
		"text": "Restores health instantly."},
	"shield": {"name": "Shield", "color": Color(0.7, 0.85, 1.0),
		"text": "Raises the target's Armour for a few turns."},
	"poison": {"name": "Poison", "color": Color(0.6, 0.95, 0.3),
		"text": "Deals its amount as damage at the start of each of the victim's turns, then halves (rounded down). More Poison adds to it. Poison can kill. Cure removes it."},
	"regen": {"name": "Regeneration", "color": Color(0.45, 1.0, 0.6),
		"text": "Restores its amount 4 times at the start of each of the unit's turns."},
	"trap": {"name": "Trap", "color": Color(1.0, 0.7, 0.3),
		"text": "Set on a tile. The first enemy to step on it springs it and loses half a turn. Up to 3 Traps at once."},
	"debuff": {"name": "Debuff", "color": Color(0.8, 0.5, 1.0),
		"text": "A harmful effect that lasts a few turns. Cure removes it."},
	"ensnare": {"name": "Ensnare", "color": Color(0.5, 0.8, 0.35),
		"text": "Bound in brambles: can't make Melee attacks, and its time bar fills at half speed until the end of its next turn."},
	"stun": {"name": "Stun", "color": Color(1.0, 0.85, 0.4),
		"text": "Loses its next turn completely."},
	"ward": {"name": "Ward", "color": Color(0.75, 0.88, 1.0),
		"text": "A barrier that soaks up incoming damage before health is lost, until it breaks or runs out of turns. Poison goes around it."},
	"silence": {"name": "Silence", "color": Color(0.8, 0.55, 1.0),
		"text": "Can't Cast anything until the effect ends."},
	"empowered": {"name": "Empowered", "color": Color(1.0, 0.6, 0.35),
		"text": "The next Hit deals bonus damage (every target it strikes), then the effect is spent."},
	"hidden": {"name": "Hidden", "color": Color(0.6, 0.65, 0.8),
		"text": "Enemies can't pick it as the target of a single-target attack. Attacks on everyone still land."},
	"counter": {"name": "Counter", "color": Color(1.0, 0.85, 0.4),
		"text": "Strikes back at once with a free basic Attack."},
	"back": {"name": "Back attack", "color": Color(1.0, 0.8, 0.45),
		"text": "Hitting a unit from behind: it can't dodge, and the Hit deals +35% damage. From the side: half its dodge chance, +15% damage."},
	"flank": {"name": "Flank", "color": Color(1.0, 0.8, 0.45),
		"text": "A Hit on a unit that one of your allies is standing next to deals +15% damage."},
	"targetall": {"name": "Target All", "color": Color(1.0, 0.85, 0.5),
		"text": "Hits every enemy in a small area (the target tile and the tiles next to it) for half damage, at 1.5x the MP cost."},
	"round": {"name": "round", "color": Color(0.85, 0.85, 0.95),
		"text": "One turn of the affected unit."},
	"str": {"name": "STR", "color": Color(0.95, 0.42, 0.36),
		"text": "Strength: +2% damage with swords, axes and STR skills per point, and more pack space."},
	"dex": {"name": "DEX", "color": Color(0.42, 0.9, 0.44),
		"text": "Dexterity: +2% damage with bows and DEX skills per point (daggers 1.5%), +0.3% critical chance, and a faster time bar."},
	"con": {"name": "CON", "color": Color(0.98, 0.7, 0.28),
		"text": "Constitution: +6 maximum HP per point."},
	"int": {"name": "INT", "color": Color(0.5, 0.66, 1.0),
		"text": "Intelligence: +1% spell damage and +3 MP per point."},
}

## Word forms (lower case, letters only) that link to a term.
const ALIASES := {
	"hit": "hit", "hits": "hit",
	"melee": "melee",
	"shoot": "shoot", "shoots": "shoot",
	"cast": "cast", "casts": "cast", "spell": "cast", "spells": "cast",
	"physical": "physical",
	"fire": "fire", "ice": "ice", "lightning": "lightning", "shadow": "shadow",
	"armour": "armour",
	"evasion": "evasion", "dodge": "evasion",
	"critical": "critical", "crit": "critical",
	"heal": "heal", "heals": "heal",
	"poison": "poison", "poisons": "poison", "poisoned": "poison",
	"regeneration": "regen", "regen": "regen",
	"trap": "trap", "traps": "trap",
	"ensnare": "ensnare", "ensnared": "ensnare",
	"ward": "ward", "wards": "ward",
	"silence": "silence", "silenced": "silence", "silences": "silence",
	"empowered": "empowered",
	"hidden": "hidden",
	"counter": "counter", "counters": "counter",
	"flank": "flank", "flanking": "flank", "flanked": "flank",
	"stun": "stun", "stuns": "stun", "stunned": "stun",
	"debuff": "debuff", "debuffs": "debuff", "hex": "debuff", "curse": "debuff", "curses": "debuff", "cursed": "debuff",
	"str": "str", "strength": "str", "dex": "dex", "dexterity": "dex",
	"con": "con", "constitution": "con", "int": "int", "intelligence": "int",
}

static func _clean(word: String) -> String:
	var out := ""
	for ch in word.to_lower():
		if ch >= "a" and ch <= "z":
			out += ch
	return out

## Term id for a plain word, or "".
static func term_of(word: String) -> String:
	return ALIASES.get(_clean(word), "")

static func color_of_word(word: String):
	var id := term_of(word)
	return TERMS[id]["color"] if id != "" else null

## Display label for a {markup} term.
static func label(id: String, args: Array) -> String:
	match id:
		"regen":
			if args.size() >= 2:
				return "Regeneration +%s for %s turn%s" % [args[0], args[1], "" if str(args[1]) == "1" else "s"]
			if args.size() == 1:
				return "Regeneration +%s" % args[0]
		"poison":
			if args.size() >= 1:
				return "Poison %s" % args[0]
	return TERMS[id]["name"] if TERMS.has(id) else id

## Tooltip text for a term (with its numbers, if any).
static func tooltip(id: String, args: Array) -> String:
	match id:
		"regen":
			if args.size() >= 2:
				var x := int(args[0])
				return "Restores %d health 4 times at the start of each of the unit's turns (%d per turn), for %s turns." % [x, x * 4, str(args[1])]
			if args.size() == 1:
				return "Restores %s health 4 times at the start of each of the unit's turns." % args[0]
		"poison":
			if args.size() >= 1:
				var a := int(args[0])
				var seq: Array = []
				var v := a
				while v > 0 and seq.size() < 6:
					seq.append(str(v))
					v /= 2
				return "Deals %s damage over the victim's next turns (halving each turn). More Poison adds to it. Poison can kill. Cure removes it." % ", ".join(seq)
	return TERMS[id]["text"] if TERMS.has(id) else ""

## Replaces {markup} with its display label (for plain-text tooltips).
static func plain(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "{":
			var j := text.find("}", i)
			if j > i:
				var parts := text.substr(i + 1, j - i - 1).split(":")
				var id := parts[0]
				parts.remove_at(0)
				out += label(id, Array(parts))
				i = j + 1
				continue
		out += ch
		i += 1
	return out

static func _link(id: String, args: Array, shown: String) -> String:
	var col: Color = TERMS[id]["color"] if TERMS.has(id) else Color.WHITE
	var meta := "kw:" + id + ("" if args.is_empty() else ":" + ":".join(args))
	return "[url=%s][color=#%s]%s[/color][/url]" % [meta, col.to_html(false), shown.replace("[", "[lb]")]

## BBCode for a RichTextLabel: {markup} and keywords become hoverable, coloured links.
static func bbcode(text: String) -> String:
	var out := ""
	var i := 0
	var word := ""
	var flush := func(w: String) -> String:
		if w == "":
			return ""
		var id := term_of(w)
		if id == "":
			return w.replace("[", "[lb]")
		# keep trailing punctuation outside the link
		var core := w
		var tail := ""
		while core.length() > 0 and not (core[core.length() - 1].to_lower() >= "a" and core[core.length() - 1].to_lower() <= "z"):
			tail = core[core.length() - 1] + tail
			core = core.substr(0, core.length() - 1)
		var head := ""
		while core.length() > 0 and not (core[0].to_lower() >= "a" and core[0].to_lower() <= "z"):
			head += core[0]
			core = core.substr(1)
		return head.replace("[", "[lb]") + _link(id, [], core) + tail.replace("[", "[lb]")
	while i < text.length():
		var ch := text[i]
		if ch == "{":
			var j := text.find("}", i)
			if j > i:
				out += flush.call(word)
				word = ""
				var parts := text.substr(i + 1, j - i - 1).split(":")
				var id := parts[0]
				parts.remove_at(0)
				out += _link(id, Array(parts), label(id, Array(parts)))
				i = j + 1
				continue
		if ch == " " or ch == "\n" or ch == "\t":
			out += flush.call(word) + ch
			word = ""
		else:
			word += ch
		i += 1
	out += flush.call(word)
	return out

## Makes keyword links in a RichTextLabel show their tooltip on hover.
static func hook(rtl: RichTextLabel) -> void:
	rtl.bbcode_enabled = true
	rtl.meta_underlined = false
	if rtl.has_meta("glossary_hooked"):
		return
	rtl.set_meta("glossary_hooked", true)
	rtl.meta_hover_started.connect(func(meta): show_term(str(meta)))
	rtl.meta_hover_ended.connect(func(_meta): hide_term())
	rtl.tree_exiting.connect(hide_term)

static func show_term(meta: String) -> void:
	if not meta.begins_with("kw:") or Game.main == null:
		return
	var parts := meta.substr(3).split(":")
	var id := parts[0]
	parts.remove_at(0)
	var args := Array(parts)
	if not TERMS.has(id):
		return
	var lines: Array = [[label(id, args), TERMS[id]["color"], false], [tooltip(id, args), Color(0.92, 0.94, 1.0), false]]
	var mp: Vector2 = Game.main.get_viewport().get_mouse_position()
	Game.main.kwtip.show_lines(lines, Rect2(mp + Vector2(4, 6), Vector2.ZERO), TERMS[id]["color"])

static func hide_term() -> void:
	if Game.main != null and Game.main.kwtip != null:
		Game.main.kwtip.hide_tip()
