class_name PartyMenu
extends PanelContainer
## Party / skill tree / items menu (Tab, M or Esc).

var tabs: TabContainer
var status_box: HBoxContainer
var tree_view: SkillTreeView
var member_pick: OptionButton
var points_label: Label
var items_box: VBoxContainer
var items_tab: Control
var gold_label: Label
var portraits: HBoxContainer
var sel := 0                 # selected party member, shared by every tab
var eq_pick: OptionButton
var eq_doll: Control
var eq_grid: GridContainer
var eq_bag_label: Label
var eq_msg: Label
var eq_stats: RichTextLabel
# Items tab
var it_search: LineEdit
var it_type: OptionButton
var it_rarity: OptionButton
var it_level: OptionButton
var it_sort: OptionButton
var it_view: OptionButton
var it_flow: HFlowContainer
var it_cap: Label
var it_msg: Label

const BODY_TYPE := "human"   # other body types (beasts etc.) will get their own layouts later
const DOLL_LAYOUT := {
	"human": {
		"helm": Rect2(118, 6, 64, 64), "amulet": Rect2(198, 34, 44, 44),
		"main": Rect2(14, 92, 68, 124), "body": Rect2(106, 80, 88, 124), "off": Rect2(218, 92, 68, 124),
		"gloves": Rect2(14, 228, 64, 64), "ring1": Rect2(96, 214, 44, 44), "ring2": Rect2(160, 214, 44, 44),
		"boots": Rect2(116, 300, 68, 78),
	},
}
const TYPE_FILTERS := [["All types", ""], ["Consumables", "consumable"], ["All weapons", "weapon"], ["Swords", "sword"], ["Axes", "axe"],
	["Daggers", "dagger"], ["Fist weapons", "fist"], ["Bows", "bow"], ["Wands", "wand"], ["Staves", "staff"], ["Shields", "shield"], ["Body armour", "body"],
	["Helms", "helm"], ["Gloves", "gloves"], ["Boots", "boots"], ["Rings", "ring"], ["Amulets", "amulet"]]
const RARITY_FILTERS := [["All rarities", ""], ["Normal", "normal"], ["Magic", "magic"], ["Rare", "rare"], ["Unique", "unique"]]
const LEVEL_FILTERS := [["All levels", -1], ["Level 0", 0], ["Level 5", 5], ["Level 10", 10], ["Level 15", 15], ["Level 20", 20], ["Usable by party", -2]]
const SORTS := ["Sort: Type", "Sort: Rarity", "Sort: Value", "Sort: Level", "Sort: Name"]
const TYPE_ORDER := ["consumable", "sword", "axe", "dagger", "fist", "bow", "wand", "staff", "shield", "helm", "body", "gloves", "boots", "amulet", "ring"]
const RARITY_ORDER := {"unique": 0, "rare": 1, "magic": 2, "normal": 3, "": 4}

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 30
	offset_top = 24
	offset_right = -30
	offset_bottom = -24
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := UiKit.label("Party", 22, Color(1, 0.9, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var pc := VBoxContainer.new()
	pc.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(pc)
	portraits = HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 6)
	pc.add_child(portraits)
	var qe := UiKit.label("Q / E to switch", 12, Color(0.6, 0.65, 0.82))
	qe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(qe)
	var right_box := HBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(right_box)
	gold_label = UiKit.label("", 18, Color(1, 0.85, 0.3))
	right_box.add_child(gold_label)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(close_menu)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_box.add_child(close)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	# --- Status tab
	var ss := ScrollContainer.new()
	ss.name = "Status"
	tabs.add_child(ss)
	status_box = HBoxContainer.new()
	status_box.add_theme_constant_override("separation", 16)
	ss.add_child(status_box)

	# --- Skill tree tab
	var sv := VBoxContainer.new()
	sv.name = "Skill Tree"
	tabs.add_child(sv)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	sv.add_child(bar)
	member_pick = OptionButton.new()
	member_pick.visible = false
	member_pick.item_selected.connect(func(_i): _refresh_tree())
	bar.add_child(member_pick)
	points_label = UiKit.label("", 17, Color(1, 0.9, 0.5))
	bar.add_child(points_label)
	var hint := UiKit.label("Click a node for details and to purchase.  Drag to pan, wheel to zoom.", 14, Color(0.7, 0.75, 0.9))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(hint)
	tree_view = SkillTreeView.new()
	tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_view.allocated.connect(func():
		_refresh_tree()
		_refresh_status())
	sv.add_child(tree_view)

	# --- Equipment tab: paper doll | equipment bag grid | stats
	var eqv := HBoxContainer.new()
	eqv.name = "Equipment"
	eqv.add_theme_constant_override("separation", 18)
	tabs.add_child(eqv)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(304, 0)
	eqv.add_child(left)
	var pick_row := HBoxContainer.new()
	pick_row.visible = false
	eq_pick = OptionButton.new()
	eq_pick.item_selected.connect(func(_i): _refresh_equipment())
	pick_row.add_child(eq_pick)
	left.add_child(pick_row)
	eq_doll = Control.new()
	eq_doll.custom_minimum_size = Vector2(300, 384)
	eq_doll.draw.connect(_draw_doll)
	left.add_child(eq_doll)
	eq_msg = UiKit.label("", 14, Color(1, 0.75, 0.45))
	eq_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eq_msg.custom_minimum_size = Vector2(300, 0)
	left.add_child(eq_msg)

	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(262, 0)
	eqv.add_child(mid)
	eq_bag_label = UiKit.label("", 15, Color(1, 0.9, 0.55))
	mid.add_child(eq_bag_label)
	var gscroll := ScrollContainer.new()
	gscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(gscroll)
	eq_grid = GridContainer.new()
	eq_grid.columns = 4
	eq_grid.add_theme_constant_override("h_separation", 4)
	eq_grid.add_theme_constant_override("v_separation", 4)
	gscroll.add_child(eq_grid)
	var hint2 := UiKit.label("Click a bag item to equip it.\nClick a worn item to take it off.\nDrag and drop works too.", 13, Color(0.65, 0.7, 0.85))
	mid.add_child(hint2)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	eqv.add_child(right_scroll)
	eq_stats = RichTextLabel.new()
	Glossary.hook(eq_stats)
	eq_stats.bbcode_enabled = true
	eq_stats.fit_content = true
	eq_stats.scroll_active = false
	eq_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq_stats.add_theme_font_size_override("normal_font_size", 14)
	right_scroll.add_child(eq_stats)

	# --- Items tab: filter bar + grid
	var iv := VBoxContainer.new()
	iv.name = "Items"
	items_tab = iv
	tabs.add_child(iv)
	var fbar := HBoxContainer.new()
	fbar.add_theme_constant_override("separation", 8)
	iv.add_child(fbar)
	it_search = LineEdit.new()
	it_search.placeholder_text = "Search names and mods..."
	it_search.custom_minimum_size = Vector2(220, 0)
	it_search.text_changed.connect(func(_t): _refresh_items())
	fbar.add_child(it_search)
	it_type = _option(fbar, TYPE_FILTERS.map(func(x): return x[0]))
	it_rarity = _option(fbar, RARITY_FILTERS.map(func(x): return x[0]))
	it_level = _option(fbar, LEVEL_FILTERS.map(func(x): return x[0]))
	it_sort = _option(fbar, SORTS)
	it_view = _option(fbar, ["View: Bag", "View: Boat hold"])
	it_cap = UiKit.label("", 15, Color(1, 0.9, 0.55))
	it_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	it_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fbar.add_child(it_cap)
	var iscroll := ScrollContainer.new()
	iscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	iv.add_child(iscroll)
	it_flow = HFlowContainer.new()
	it_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	it_flow.add_theme_constant_override("h_separation", 5)
	it_flow.add_theme_constant_override("v_separation", 5)
	iscroll.add_child(it_flow)
	it_msg = UiKit.label("Click an item for actions. Hover to inspect.", 14, Color(0.65, 0.7, 0.85))
	iv.add_child(it_msg)

	visible = false

func open_menu() -> void:
	Game.push_busy()
	visible = true
	member_pick.clear()
	eq_pick.clear()
	for u in Game.party:
		member_pick.add_item("%s (Lv %d)%s" % [u.name, u.level, "  *" if u.skill_points > 0 else ""])
		eq_pick.add_item("%s (Lv %d %s)" % [u.name, u.level, u.cls])
	it_view.visible = Game.has_boat
	if not Game.has_boat:
		it_view.select(0)
	sel = clampi(sel, 0, Game.party.size() - 1)
	_apply_sel()
	refresh()
	await get_tree().process_frame
	tabs.get_tab_bar().grab_focus()

# ---------------------------------------------------------------------------
# Party portraits (header) - shared selection across all tabs
# ---------------------------------------------------------------------------
func _apply_sel() -> void:
	if member_pick.item_count > sel:
		member_pick.select(sel)
	if eq_pick.item_count > sel:
		eq_pick.select(sel)

func select_member(i: int) -> void:
	if Game.party.is_empty():
		return
	sel = posmod(i, Game.party.size())
	_apply_sel()
	Game.main.tip.hide_tip()
	refresh()

func _refresh_portraits() -> void:
	for c in portraits.get_children():
		portraits.remove_child(c)
		c.queue_free()
	for i in Game.party.size():
		var p := Portrait.new()
		p.unit = Game.party[i]
		p.index = i
		p.selected = i == sel
		p.picked.connect(select_member)
		portraits.add_child(p)

func _input(e: InputEvent) -> void:
	if not visible or Game.main.dialog.visible or Game.main.trade.visible:
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if e.physical_keycode == KEY_Q:
		select_member(sel - 1)
		get_viewport().set_input_as_handled()
	elif e.physical_keycode == KEY_E:
		select_member(sel + 1)
		get_viewport().set_input_as_handled()

func close_menu() -> void:
	if not visible:
		return
	visible = false
	Game.main.tip.hide_tip()
	Game.pop_busy()

func refresh() -> void:
	gold_label.text = "Gold: %s    " % Game.gold_text().trim_suffix(" gold").replace(" gold (", " (")
	_refresh_portraits()
	_refresh_status()
	_refresh_tree()
	_refresh_equipment()
	_refresh_items()

func _refresh_status() -> void:
	for c in status_box.get_children():
		status_box.remove_child(c)
		c.queue_free()
	for i in Game.party.size():
		var u: Unit = Game.party[i]
		var card := PanelContainer.new()
		var cst := UiKit.panel_style(Color(0.09, 0.12, 0.32, 0.95) if i == sel else Color(0.05, 0.07, 0.2, 0.9))
		if i == sel:
			cst.border_color = Color(1, 0.85, 0.35)
			cst.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", cst)
		card.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				select_member(i))
		card.custom_minimum_size = Vector2(360, 0)
		status_box.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UiKit.label("%s  -  %s" % [u.name, u.cls], 20, Color(1, 0.9, 0.55)))
		v.add_child(UiKit.label("Level %d     XP %d / %d" % [u.level, u.xp, u.xp_to_next()]))
		var hpc := Color(0.6, 1, 0.6) if u.is_alive() else Color(1, 0.4, 0.4)
		v.add_child(UiKit.label("HP %d / %d    MP %d / %d%s" % [u.hp, u.max_hp(), u.mp, u.max_mp(), "" if u.is_alive() else "   (KO)"], 16, hpc))
		v.add_child(UiKit.label(" "))
		var stat_lines: Array = []
		for s in Unit.STATS:
			var gn := u.growth_nodes(s)
			var growth := "   (+%d from growth)" % u.growth_bonus(s) if gn > 0 else ""
			stat_lines.append("%s  %d%s" % [DB.STAT_NAMES[s], u.stat(s), growth])
		v.add_child(_kw_label("\n".join(stat_lines), 16, Color(0.92, 0.94, 1.0)))
		v.add_child(UiKit.label("Speed %d   Crit %d%%" % [int(u.speed()), int(Combat.crit_chance(u) * 100)], 15, Color(0.75, 0.8, 0.95)))
		v.add_child(UiKit.label(" "))
		# Effects that persist outside combat (bandages, poison)
		var fx_lines := _active_effects(u)
		v.add_child(UiKit.label("Active effects", 15, Color(1, 0.9, 0.55)))
		if fx_lines.is_empty():
			v.add_child(UiKit.label("   None", 14, Color(0.6, 0.65, 0.85)))
		for fl in fx_lines:
			v.add_child(_kw_label("   " + str(fl[0]), 14, fl[1]))
		if u.skill_points > 0:
			v.add_child(UiKit.label("Unspent skill points: %d" % u.skill_points, 16, Color(1, 0.85, 0.3)))
		var field := _field_skills(u)
		if field.size() > 0:
			var sb := Button.new()
			sb.text = "Skills..."
			sb.disabled = not u.is_alive()
			sb.pressed.connect(_open_field_skills.bind(u))
			v.add_child(sb)
		if i > 0:
			var b := Button.new()
			b.text = "Dismiss"
			b.pressed.connect(_dismiss.bind(u))
			v.add_child(b)

## A small rich-text label whose key terms show their definition on hover.
func _kw_label(text: String, font_size: int, col: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	Glossary.hook(r)
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(330, 0)
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("default_color", col)
	r.text = Glossary.bbcode(text)
	return r

## [text, colour] lines for effects that last outside battle.
func _active_effects(u: Unit) -> Array:
	var out: Array = []
	for hh in u.hots:
		var ticks := int(hh["ticks"])
		out.append(["{regen:%d}   %ds left" % [int(hh["amount"]), ticks], Color(0.55, 1.0, 0.6)])
	if u.poison_left > 0:
		out.append(["{poison:%d}" % u.poison_left, Color(0.65, 0.95, 0.35)])
	for b in u.buffs:
		out.append(["%s (%d turns)" % [b.get("name", "Effect"), int(b.get("turns", 0))], Color(1.0, 0.6, 0.6) if b.get("debuff", false) else Color(0.7, 0.85, 1.0)])
	for fb in u.field_buffs:
		out.append(["%s (%ds)" % [fb["name"], int(ceil(float(fb["secs"])))], Color(0.7, 0.85, 1.0)])
	if not u.is_alive():
		out.append(["Knocked out - revive or rest at an inn", Color(1, 0.45, 0.4)])
	return out

## Skills this character can use outside battle (heals and cures).
func _field_skills(u: Unit) -> Array:
	return u.learned.filter(func(aid): return DB.ABILITIES[aid]["kind"] in ["heal", "cure"])

func _open_field_skills(u: Unit) -> void:
	var skills := _field_skills(u)
	var choices: Array = []
	for aid in skills:
		var ab: Dictionary = DB.ABILITIES[aid]
		var short := u.mp < int(ab["mp"])
		choices.append({"text": "%s   (%d MP)%s" % [ab["name"], int(ab["mp"]), "   - not enough MP" if short else ""],
			"disabled": short, "tip": DB.ability_lines(aid, u)})
	choices.append("Close")
	var r: int = await Game.main.dialog.ask("%s's skills usable outside battle.   MP %d / %d" % [u.name, u.mp, u.max_mp()], choices)
	if r >= 0 and r < skills.size():
		await _cast_field(u, skills[r])

func _cast_field(caster: Unit, aid: String) -> void:
	var ab: Dictionary = DB.ABILITIES[aid]
	var targets: Array = []
	match ab["target"]:
		"self":
			targets = [caster]
		"allies":
			targets = Game.party.filter(func(x): return x.is_alive())
		_:
			var alive: Array = Game.party.filter(func(x): return x.is_alive())
			var choices: Array = []
			for t in alive:
				choices.append("%s   HP %d/%d" % [t.name, t.hp, t.max_hp()])
			choices.append("Cancel")
			var r: int = await Game.main.dialog.ask("%s casts %s on whom?" % [caster.name, ab["name"]], choices)
			if r < 0 or r >= alive.size():
				return
			targets = [alive[r]]
	var curing: bool = ab["kind"] == "cure"
	if curing and targets.all(func(x): return x.poison_left <= 0 and not x.buffs.any(func(b): return b.get("debuff", false))):
		await Game.main.dialog.ask("Nobody needs curing.")
		return
	if not curing and targets.all(func(x): return x.hp >= x.max_hp()):
		await Game.main.dialog.ask("Everyone is already at full health.")
		return
	caster.mp -= int(ab["mp"])
	var lines: Array = []
	for t in targets:
		if curing:
			t.cleanse()
			lines.append("%s is cured." % t.name)
			continue
		var before: int = t.hp
		t.hp = mini(t.max_hp(), t.hp + Combat.heal_amount(caster, ab))
		lines.append("%s recovers %d HP." % [t.name, t.hp - before])
	await Game.main.dialog.ask("%s casts %s!\n%s" % [caster.name, ab["name"], "\n".join(lines)])
	refresh()

func _dismiss(u: Unit) -> void:
	var r: int = await Game.main.dialog.ask("Dismiss %s? They'll head back to the Rusty Tankard." % u.name, ["Dismiss", "Keep"])
	if r == 0:
		Game.party.erase(u)
		for slot in u.equip.keys():
			for it in u.unequip(slot):
				Game.add_gear(it)
		if Game.hirelings.size() < Game.MAX_HIRELINGS:
			u.hire_cost = int(u.hire_cost * 1.2)
			Game.hirelings.append(u)
		open_refresh()

func open_refresh() -> void:
	member_pick.clear()
	eq_pick.clear()
	for u in Game.party:
		member_pick.add_item("%s (Lv %d)" % [u.name, u.level])
		eq_pick.add_item("%s (Lv %d %s)" % [u.name, u.level, u.cls])
	sel = clampi(sel, 0, Game.party.size() - 1)
	_apply_sel()
	refresh()

func _refresh_tree() -> void:
	var i := member_pick.selected
	if i < 0 or i >= Game.party.size():
		i = 0
	var u: Unit = Game.party[i]
	tree_view.unit = u
	points_label.text = "Skill points: %d" % u.skill_points
	member_pick.set_item_text(i, "%s (Lv %d)%s" % [u.name, u.level, "  *" if u.skill_points > 0 else ""])

# ---------------------------------------------------------------------------
# Equipment: paper doll + bag grid + stats
# ---------------------------------------------------------------------------
func _option(parent: Control, labels: Array) -> OptionButton:
	var o := OptionButton.new()
	for l in labels:
		o.add_item(l)
	o.item_selected.connect(func(_i): _refresh_items())
	parent.add_child(o)
	return o

func _eq_unit() -> Unit:
	var i := eq_pick.selected
	if i < 0 or i >= Game.party.size():
		i = 0
	return Game.party[i]

func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func _draw_doll() -> void:
	# faint human silhouette behind the slots
	var col := Color(0.25, 0.3, 0.55, 0.35)
	var cx := 150.0
	eq_doll.draw_circle(Vector2(cx, 40), 30, col)
	eq_doll.draw_colored_polygon(Art.pts([Vector2(cx - 50, 86), Vector2(cx + 50, 86), Vector2(cx + 40, 210), Vector2(cx - 40, 210)]), col)
	eq_doll.draw_line(Vector2(cx - 50, 92), Vector2(cx - 100, 240), col, 18)
	eq_doll.draw_line(Vector2(cx + 50, 92), Vector2(cx + 100, 240), col, 18)
	eq_doll.draw_line(Vector2(cx - 22, 205), Vector2(cx - 24, 360), col, 22)
	eq_doll.draw_line(Vector2(cx + 22, 205), Vector2(cx + 24, 360), col, 22)

func _refresh_equipment() -> void:
	if Game.party.is_empty():
		return
	var u := _eq_unit()
	_clear(eq_doll)
	var layout: Dictionary = DOLL_LAYOUT[BODY_TYPE]
	for slot in layout:
		var r: Rect2 = layout[slot]
		var ic := ItemIcon.new(r.size.x)
		ic.custom_minimum_size = r.size
		ic.position = r.position
		ic.size = r.size
		ic.unit = u
		ic.item = u.equip.get(slot)
		ic.placeholder = Unit.SLOT_NAMES[slot]
		if ic.item == null and slot == "off" and Loot.is_two_handed(u.equip.get("main")):
			ic.placeholder = "(2-handed)"
		if ic.item != null:
			ic.drag_payload = {"from": "slot", "slot": slot}
		ic.drop_check = func(d): return d.get("from") == "bag" and u.can_equip(d["item"], slot) == ""
		ic.drop_do = func(d): _equip(u, d["item"], slot)
		ic.clicked.connect(func(_i, _b): _unequip(u, slot))
		eq_doll.add_child(ic)
	eq_doll.queue_redraw()
	# bag grid: equipment + empty slots up to capacity
	_clear(eq_grid)
	var gear: Array = Game.bag.duplicate()
	gear.sort_custom(func(a, b): return _type_rank(a) < _type_rank(b))
	for it in gear:
		var ic2 := ItemIcon.new(58)
		ic2.item = it
		ic2.unit = u
		ic2.dim = u.can_equip(it, u.slots_for(it)[0]) != ""
		ic2.drag_payload = {"from": "bag", "item": it}
		ic2.drop_check = func(d): return d.get("from") == "slot"
		ic2.drop_do = func(d): _unequip(u, d["slot"])
		ic2.clicked.connect(func(_i, _b): _equip(u, it, ""))
		eq_grid.add_child(ic2)
	for i in maxi(0, Game.free_slots()):
		var empty := ItemIcon.new(58)
		empty.drop_check = func(d): return d.get("from") == "slot"
		empty.drop_do = func(d): _unequip(u, d["slot"])
		eq_grid.add_child(empty)
	eq_bag_label.text = "Equipment bag   (packs %d / %d)" % [Game.used_slots(), Game.capacity()]
	eq_stats.text = _stat_summary(u)

func _equip(u: Unit, item: Dictionary, slot: String) -> void:
	var target := slot
	if target == "":
		var slots: Array = u.slots_for(item)
		target = slots[0]
		for sl in slots:
			if not u.equip.has(sl):
				target = sl
				break
	var why := u.can_equip(item, target)
	if why != "":
		eq_msg.text = "%s can't use %s: %s." % [u.name, item["name"], why]
		return
	Game.remove_gear(item)
	for d in u.equip_item(item, target):
		Game.add_gear(d)
	eq_msg.text = ""
	refresh()

func _unequip(u: Unit, slot: String) -> void:
	if not u.equip.has(slot):
		return
	if not Game.can_carry_gear():
		eq_msg.text = "Your packs are full - make room before taking that off."
		return
	for d in u.unequip(slot):
		Game.add_gear(d)
	eq_msg.text = ""
	refresh()

func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

const C_HEAD := "#ffd77a"
const C_LABEL := "#9aa3c7"
const C_VAL := "#f2f3ff"
const C_NOTE := "#7f86a6"
const C_ELEM := {"phys": "#f2f3ff", "fire": "#ff9a4d", "ice": "#7fd6ff", "lightning": "#fff066"}
const ELEM_NAME := {"phys": "Physical", "fire": "Fire", "ice": "Ice", "lightning": "Lightning"}

## Header row inside the shared table.
func _section(title: String) -> Array:
	return ["[/color]", title]

## Two-column table of [label, value-bbcode] rows.
func _rows(rows: Array) -> String:
	var t := "[table=2]"
	for r in rows:
		if str(r[0]).begins_with("[/color]"):
			t += "[cell padding=0,12,18,3][color=%s][b]%s[/b][/color][/cell][cell][/cell]" % [C_HEAD, r[1]]
			continue
		t += "[cell padding=0,1,18,1][color=%s]%s[/color][/cell][cell padding=0,1,0,1][color=%s]%s[/color][/cell]" % [C_LABEL, r[0], C_VAL, r[1]]
	return t + "[/table]\n"

func _range_text(ranges: Dictionary) -> String:
	var parts: Array = []
	var lo := 0.0
	var hi := 0.0
	for el in ["phys", "fire", "ice", "lightning"]:
		if not ranges.has(el):
			continue
		var r: Array = ranges[el]
		lo += r[0]
		hi += r[1]
		parts.append("[color=%s]%d-%d[/color] %s" % [C_ELEM[el], int(round(r[0])), int(round(r[1])), Glossary.bbcode(ELEM_NAME[el])])
	return "%s   [color=%s](avg %d)[/color]" % ["  +  ".join(parts), C_NOTE, int(round((lo + hi) * 0.5))]

func _stat_summary(u: Unit) -> String:
	var t := "[font_size=18][color=%s][b]%s[/b][/color][/font_size]   [color=%s]Level %d %s[/color]\n" % [C_HEAD, u.name, C_LABEL, u.level, u.cls]
	t += "[table=4]"
	for st in [["STR", "str"], ["DEX", "dex"], ["CON", "con"], ["INT", "int"]]:
		t += "[cell padding=0,4,22,2][color=%s]%s[/color] [b]%d[/b][/cell]" % [C_LABEL, st[0], u.stat(st[1])]
	t += "[/table]\n"
	var rows: Array = [["Health", "%d / %d" % [u.hp, u.max_hp()]], ["Mana", "%d / %d" % [u.mp, u.max_mp()]],
		["Carries", "%d pack slots" % u.carry_slots()]]

	# --- Offence
	var style := "Shoot" if Loot.is_bow(u.weapon()) else "Melee"
	rows.append(_section("ATTACK  (%s Hit)" % style))
	var wname: String = u.weapon()["name"] if u.weapon() != null else "Bare hands"
	rows.append([wname, _range_text(Combat.hit_ranges(u))])
	if u.dual_wielding():
		var off: Dictionary = u.equip.get("off", {})
		rows.append([str(off.get("name", "Off hand")) + " (70%)", _range_text(Combat.hit_ranges(u, true))])
	var crit := Combat.crit_chance(u)
	rows.append([Glossary.bbcode("Critical"), "%s chance" % _pct(crit)])
	var dh := u.mod("double_hit") + (u.mod("fist_double") if u.fists() else 0.0)
	if dh > 0.0 and style == "Melee":
		rows.append(["Hit twice", "%s chance" % _pct(dh)])
	if u.fists() and u.mod("attack_twice") > 0.0:
		rows.append(["Twin Dragon", "Attack Hits twice"])
	if u.mod("accuracy") > 0.0:
		rows.append(["Accuracy", "+%s" % _pct(u.mod("accuracy"))])
	rows.append(["Speed", "%d" % int(u.speed())])
	var foe := Combat.typical_enemy(u.level)
	var atk := Combat.expected_attack_turn(u, foe)
	rows.append(["vs typical Lv %d foe" % u.level, "~%d per hit,  %s to hit,  [b]~%d per turn[/b]" % [int(round(atk["per_hit"])), _pct(atk["hit"]), int(round(atk["turn"]))]])
	var r := u.weapon_range()
	var note := "Weapon %d-%d,  x%.2f from %s" % [r[0], r[1], Combat.stat_mult(u, DB.ABILITIES["attack"]), " and ".join(Combat.stat_weights(u, DB.ABILITIES["attack"]).map(func(w): return DB.STAT_NAMES[w[0]]))]
	if u.mod("phys_dmg") != 0.0:
		note += ",  +%s Physical" % _pct(u.mod("phys_dmg"))
	rows.append(["", "[color=%s][font_size=12]%s[/font_size][/color]" % [C_NOTE, Glossary.bbcode(note)]])

	# --- Defence
	rows.append(_section("DEFENCE"))
	var inc := Combat.incoming_estimate(u, u.level)
	var drows: Array = rows
	drows.append([Glossary.bbcode("Armour"), "%d" % int(u.armour())])
	drows.append(["Typical Lv %d hit" % u.level, "~%d  ->  you take [b]~%d[/b]  (%s less)" % [int(round(inc["raw"])), int(round(inc["taken"])), _pct(inc["reduction"])]])
	drows.append([Glossary.bbcode("Evasion"), _pct(inc["dodge"])])
	drows.append(["Resistances", Glossary.bbcode("Fire %s   Ice %s   Magic %s   Poison %s" % [
		_pct(u.resist("fire")), _pct(u.resist("ice")), _pct(clampf(u.mod("magic_res"), 0.0, 0.75)), _pct(u.resist("poison"))])])
	var regen: Array = []
	if u.mod("hp_regen") > 0.0:
		regen.append("%d HP" % int(u.mod("hp_regen")))
	if u.mod("mp_regen") > 0.0:
		regen.append("%d MP" % int(u.mod("mp_regen")))
	if regen.size() > 0:
		drows.append([Glossary.bbcode("Regeneration"), " and ".join(regen)])

	# --- Modifiers
	var bon: Array = []
	for k in [["phys_dmg", "Physical damage"], ["spell_dmg", "Spell damage"], ["fire_dmg", "Fire damage"], ["ice_dmg", "Ice damage"], ["heal_pow", "Healing"]]:
		if u.mod(k[0]) != 0.0:
			bon.append([k[1], "+%s" % _pct(u.mod(k[0]))])
	if bon.size() > 0:
		rows.append(_section("MODIFIERS"))
		rows.append_array(bon)
	return t + _rows(rows)

# ---------------------------------------------------------------------------
# Items: filterable grid
# ---------------------------------------------------------------------------
func _type_key(e) -> String:
	if e is String:
		return "consumable"
	return Loot.base_of(e).get("kind", "")

func _type_rank(e) -> int:
	var k := _type_key(e)
	var i := TYPE_ORDER.find(k)
	return i if i >= 0 else 99

func _entry_value(e) -> int:
	return int(DB.ITEMS[e]["price"]) if e is String else Loot.value_of(e)

func _entry_name(e) -> String:
	return DB.ITEMS[e]["name"] if e is String else e["name"]

func _entry_level(e) -> int:
	return -1 if e is String else int(Loot.base_of(e).get("lvl", 0))

func _matches(e) -> bool:
	var tf: String = TYPE_FILTERS[it_type.selected][1]
	var k := _type_key(e)
	if tf != "":
		if tf == "weapon":
			if e is String or Loot.base_of(e).get("cat", "") != "weapon":
				return false
		elif tf != k:
			return false
	var rf: String = RARITY_FILTERS[it_rarity.selected][1]
	if rf != "" and (e is String or e.get("rarity", "normal") != rf):
		return false
	var lf: int = LEVEL_FILTERS[it_level.selected][1]
	if lf >= 0 and _entry_level(e) != lf:
		return false
	if lf == -2:
		if e is String:
			return false
		var ok := false
		for u in Game.party:
			if Loot.req_problem(e, u) == "":
				ok = true
		if not ok:
			return false
	var q := it_search.text.strip_edges().to_lower()
	if q != "":
		var hay := _entry_name(e).to_lower()
		if e is Dictionary:
			var b := Loot.base_of(e)
			hay += " " + str(b.get("name", "")).to_lower() + " " + Loot.type_line(e).to_lower()
			for ik in b.get("imp", {}):
				hay += " " + Loot.stat_text({"k": ik, "v": b["imp"][ik]}).to_lower()
			for m in e.get("mods", []):
				hay += " " + Loot.stat_text(m).to_lower()
		else:
			hay += " " + str(DB.ITEMS[e]["desc"]).to_lower()
		if not hay.contains(q):
			return false
	return true

func _sorted(entries: Array) -> Array:
	var mode := it_sort.selected
	entries.sort_custom(func(a, b):
		var ka; var kb
		match mode:
			1:
				ka = RARITY_ORDER.get("" if a is String else a.get("rarity", ""), 4)
				kb = RARITY_ORDER.get("" if b is String else b.get("rarity", ""), 4)
			2:
				ka = -_entry_value(a)
				kb = -_entry_value(b)
			3:
				ka = -_entry_level(a)
				kb = -_entry_level(b)
			4:
				ka = _entry_name(a)
				kb = _entry_name(b)
			_:
				ka = _type_rank(a)
				kb = _type_rank(b)
		if ka == kb:
			return _entry_name(a) < _entry_name(b)
		return ka < kb)
	return entries

func _refresh_items() -> void:
	if it_flow == null:
		return
	_clear(it_flow)
	var in_hold := Game.has_boat and it_view.selected == 1
	var src_items: Dictionary = Game.boat_hold["items"] if in_hold else Game.inventory
	var src_gear: Array = Game.boat_hold["gear"] if in_hold else Game.bag
	var entries: Array = []
	for id in src_items:
		entries.append(id)
	entries.append_array(src_gear)
	entries = _sorted(entries.filter(func(e): return _matches(e)))
	for e in entries:
		if e is String:
			# one cell per stack of STACK_SIZE (bag), or one cell for the hold
			var total := int(src_items[e])
			var stacks := 1 if in_hold else Game.stacks_for(total)
			for si in stacks:
				var ic := ItemIcon.new(58)
				ic.consumable = e
				ic.count = total if in_hold else mini(Game.STACK_SIZE, total - si * Game.STACK_SIZE)
				ic.clicked.connect(func(_i, _b): _item_actions(e, in_hold))
				it_flow.add_child(ic)
		else:
			var ic2 := ItemIcon.new(58)
			ic2.item = e
			ic2.unit = Game.party[clampi(sel, 0, Game.party.size() - 1)]
			var usable := false
			for u in Game.party:
				if Loot.req_problem(e, u) == "":
					usable = true
			ic2.dim = not usable
			ic2.clicked.connect(func(_i, _b): _item_actions(e, in_hold))
			it_flow.add_child(ic2)
	if not in_hold and it_search.text == "" and it_type.selected == 0 and it_rarity.selected == 0 and it_level.selected == 0:
		for i in maxi(0, Game.free_slots()):
			it_flow.add_child(ItemIcon.new(58))
	if in_hold:
		it_cap.text = "Boat hold %d / %d stacks%s" % [Game.hold_stacks(), Game.BOAT_HOLD, "" if Game.can_access_hold() else "  (go aboard or to Gullhaven to move items)"]
	else:
		it_cap.text = "Packs %d / %d slots" % [Game.used_slots(), Game.capacity()]

func _item_actions(e, in_hold: bool) -> void:
	var hold_ok := Game.can_access_hold()
	var name := _entry_name(e)
	var acts: Array = []
	var choices: Array = []
	if in_hold:
		acts.append("to_bag")
		var room := Game.can_carry_item(e, int(Game.boat_hold["items"][e])) if e is String else Game.can_carry_gear()
		choices.append({"text": "Move to packs" + ("" if room else "  (packs full)"), "disabled": not hold_ok or not room})
	elif e is String:
		acts.append("use")
		choices.append({"text": "Use", "disabled": DB.ITEMS[e].get("battle_only", false)})
		if Game.has_boat:
			acts.append("to_hold")
			var hfull: bool = Game.hold_stacks() >= Game.BOAT_HOLD and not Game.boat_hold["items"].has(e)
			choices.append({"text": "Move all to boat hold", "disabled": not hold_ok or hfull})
	else:
		for u in Game.party:
			acts.append(u)
			var why: String = u.can_equip(e, u.slots_for(e)[0])
			choices.append({"text": "Equip on %s%s" % [u.name, "" if why == "" else "  (%s)" % why], "disabled": why != "", "tip": Loot.describe(e, u)})
		if Game.has_boat:
			acts.append("to_hold")
			choices.append({"text": "Move to boat hold", "disabled": not hold_ok or Game.hold_stacks() >= Game.BOAT_HOLD})
		acts.append("discard")
		choices.append("Discard")
	choices.append("Cancel")
	var r: int = await Game.main.dialog.ask(name, choices)
	if r < 0 or r >= acts.size():
		return
	var act = acts[r]
	if act is Unit:
		Game.remove_gear(e)
		for d in act.auto_equip(e):
			Game.add_gear(d)
		it_msg.text = "%s equipped %s." % [act.name, name]
	else:
		match act:
			"use":
				await _use_item(e)
				return
			"to_hold":
				if e is String:
					var n := Game.item_count(e)
					Game.remove_item(e, n)
					Game.boat_hold["items"][e] = int(Game.boat_hold["items"].get(e, 0)) + n
				else:
					Game.remove_gear(e)
					Game.boat_hold["gear"].append(e)
			"to_bag":
				if e is String:
					Game.add_item(e, int(Game.boat_hold["items"][e]))
					Game.boat_hold["items"].erase(e)
				else:
					Game.boat_hold["gear"].erase(e)
					Game.add_gear(e)
			"discard":
				var c: int = await Game.main.dialog.ask("Throw away %s? (Shops will buy it instead.)" % name, ["Discard", "Keep"])
				if c == 0:
					Game.remove_gear(e)
	refresh()

func _use_item(iid: String) -> void:
	var choices: Array = []
	for u in Game.party:
		choices.append("%s   HP %d/%d   MP %d/%d%s" % [u.name, u.hp, u.max_hp(), u.mp, u.max_mp(), "" if u.is_alive() else "  (KO)"])
	choices.append("Cancel")
	var r: int = await Game.main.dialog.ask("Use %s on whom?" % DB.ITEMS[iid]["name"], choices)
	if r < 0 or r >= Game.party.size():
		return
	var line := Game.apply_item(iid, Game.party[r])
	if line == "":
		await Game.main.dialog.ask("It would have no effect.")
	else:
		Game.remove_item(iid)
		await Game.main.dialog.ask(line)
	refresh()
