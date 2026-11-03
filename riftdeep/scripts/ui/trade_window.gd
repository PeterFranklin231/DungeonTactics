class_name TradeWindow
extends PanelContainer
## Two-panel merchant screen. Your packs on the left, the merchant on the right.
## Click an item to move it across (highlighted BUY / SELL); click it again to put it back.
## Consumables move one at a time (right-click moves the whole stack).
## The net gold change shows bottom-middle; Accept / Cancel bottom-right.

signal closed

var shop_id := ""
var mode := "trade"           # "trade" or "loot"
var right_heading: Label
var right_foot: Label
var hint_label: Label
var grab_btn: Button
var gold_row: GridContainer
var gold_amount: LineEdit
var shop: Dictionary
# working state
var p_gear: Array = []        # player's gear not being sold
var p_items := {}             # player's consumables not being sold
var m_gear: Array = []        # merchant gear not being bought
var m_items := {}
var buy_gear: Array = []
var buy_items := {}
var sell_gear: Array = []
var sell_items := {}

var title: Label
var subtitle: Label
var left_gold: Label
var right_gold: Label
var left_cap: Label
var left_flow: HFlowContainer
var right_flow: HFlowContainer
var total_label: RichTextLabel
var problem_label: Label
var accept_btn: Button
var cancel_btn: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 30
	offset_top = 24
	offset_right = -30
	offset_bottom = -24
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	title = UiKit.label("", 22, Color(1, 0.9, 0.55))
	v.add_child(title)
	subtitle = UiKit.label("", 14, Color(0.7, 0.75, 0.9))
	v.add_child(subtitle)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	v.add_child(cols)
	var lp := _side(cols, "Your packs")
	left_gold = lp[0]
	left_flow = lp[1]
	left_cap = lp[2]
	var rp := _side(cols, "Merchant")
	right_gold = rp[0]
	right_flow = rp[1]
	right_foot = rp[2]
	right_heading = rp[3]
	# bottom bar: hint | totals (middle) | buttons (right)
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 64)
	v.add_child(bottom)
	hint_label = UiKit.label("", 13, Color(0.65, 0.7, 0.85))
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(240, 0)
	bottom.add_child(hint_label)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(mid)
	total_label = RichTextLabel.new()
	total_label.bbcode_enabled = true
	total_label.fit_content = true
	total_label.scroll_active = false
	total_label.add_theme_font_size_override("normal_font_size", 18)
	total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(total_label)
	gold_row = GridContainer.new()
	gold_row.columns = 3
	gold_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gold_row.add_theme_constant_override("h_separation", 6)
	gold_row.add_theme_constant_override("v_separation", 4)
	mid.add_child(gold_row)
	gold_amount = LineEdit.new()
	gold_amount.placeholder_text = "amount"
	gold_amount.custom_minimum_size = Vector2(90, 0)
	gold_row.add_child(gold_amount)
	for spec in [["Deposit", func(): _move_gold(_amount(), true)], ["Withdraw", func(): _move_gold(_amount(), false)],
			["Deposit all", func(): _move_gold(Game.gold, true)], ["Withdraw all", func(): _move_gold(int(Game.stash["gold"]), false)]]:
		var gb := Button.new()
		gb.text = spec[0]
		gb.pressed.connect(spec[1])
		gold_row.add_child(gb)
		if spec[0] == "Withdraw":
			gold_row.add_child(Control.new())  # second row starts under Deposit
	problem_label = UiKit.label("", 14, Color(1, 0.45, 0.4))
	problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(problem_label)
	var btns := HBoxContainer.new()
	btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 10)
	bottom.add_child(btns)
	grab_btn = Button.new()
	grab_btn.text = "  Grab All  "
	grab_btn.custom_minimum_size = Vector2(120, 44)
	grab_btn.pressed.connect(_grab_all)
	btns.add_child(grab_btn)
	accept_btn = Button.new()
	accept_btn.text = "  Accept  "
	accept_btn.custom_minimum_size = Vector2(120, 44)
	accept_btn.pressed.connect(_accept)
	for st in [["normal", 0.0], ["hover", 0.15], ["focus", 0.15], ["pressed", 0.25]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.5, 0.25).lightened(st[1])
		sb.border_color = Color(0.5, 1.0, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		accept_btn.add_theme_stylebox_override(st[0], sb)
	btns.add_child(accept_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "  Cancel  "
	cancel_btn.custom_minimum_size = Vector2(120, 44)
	cancel_btn.pressed.connect(_close)
	btns.add_child(cancel_btn)
	visible = false

func _side(parent: Control, heading: String) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.04, 0.06, 0.18, 0.9)))
	parent.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var hl := UiKit.label(heading, 18, Color(1, 0.9, 0.55))
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var gold := UiKit.label("", 18, Color(1, 0.85, 0.3))
	head.add_child(gold)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	sc.add_child(flow)
	var foot := UiKit.label("", 13, Color(0.65, 0.7, 0.85))
	v.add_child(foot)
	return [gold, flow, foot, hl]

# ---------------------------------------------------------------------------
func _set_mode(m: String) -> void:
	mode = m
	var loot := m == "loot"
	var st := m == "stash"
	grab_btn.visible = loot or st
	grab_btn.text = "  Grab All  " if loot else "  Add row  "
	accept_btn.visible = not st
	cancel_btn.text = "  Close  " if st else "  Cancel  "
	gold_row.visible = st
	right_heading.text = "Spoils" if loot else ("Stash" if st else "Merchant")
	right_gold.visible = not loot
	right_foot.text = "Click to take.  Right-click a stack to take it all." if loot else "Click to buy.  Right-click a stack to take it all."
	if st:
		right_foot.text = "Click to take an item back.  Right-click a stack to take it all."
		hint_label.text = "Click your items to store them. The stash stays at home, safe from anything that happens in the portal."
		return
	hint_label.text = "Green = taking.  Click a highlighted item to leave it.\nAnything left behind is lost." if loot else "Green = buying, gold = selling.\nClick a highlighted item to put it back."

## Post-battle loot: spoils on the right, your packs on the left (your own items can't be moved).
func open_loot(items: Dictionary, gear: Array) -> void:
	_set_mode("loot")
	shop_id = ""
	shop = {"gold": 0}
	title.text = "Spoils of battle"
	subtitle.text = "Take what you can carry. Grab All takes everything that fits."
	p_gear = Game.bag.duplicate()
	p_items = Game.inventory.duplicate()
	m_gear = gear.duplicate()
	m_items = items.duplicate()
	buy_gear = []
	buy_items = {}
	sell_gear = []
	sell_items = {}
	Game.push_busy()
	visible = true
	_rebuild()
	grab_btn.grab_focus.call_deferred()
	await closed

## The shared stash: moves happen immediately, plus gold deposit / withdraw.
func open_stash() -> void:
	_set_mode("stash")
	shop_id = ""
	shop = {"gold": 0}
	title.text = "Stash"
	subtitle.text = "The stash by the campfire. The trader spends your carried gold first, then your stash."
	Game.push_busy()
	visible = true
	_rebuild()
	cancel_btn.grab_focus.call_deferred()
	await closed

func _amount() -> int:
	return maxi(0, gold_amount.text.strip_edges().to_int())

func _move_gold(n: int, deposit: bool) -> void:
	if deposit:
		n = mini(n, Game.gold)
		Game.gold -= n
		Game.stash["gold"] = int(Game.stash["gold"]) + n
	else:
		n = mini(n, int(Game.stash["gold"]))
		Game.stash["gold"] = int(Game.stash["gold"]) - n
		Game.gold += n
	_rebuild()

func _stash_room(extra_gear: int, item_id: String = "", item_n: int = 0) -> bool:
	var used := Game.stash_used() + extra_gear
	if item_id != "":
		var have := int(Game.stash["items"].get(item_id, 0))
		used += Game.stacks_for(have + item_n) - Game.stacks_for(have)
	return used <= Game.stash_capacity()

func _stash_put_item(all: bool, id: String) -> void:
	var n := Game.item_count(id) if all else 1
	while n > 0 and not _stash_room(0, id, n):
		n -= 1
	if n <= 0:
		problem_label.text = "The stash is full."
		return
	Game.remove_item(id, n)
	Game.stash["items"][id] = int(Game.stash["items"].get(id, 0)) + n
	_rebuild()

func _stash_take_item(all: bool, id: String) -> void:
	var have := int(Game.stash["items"].get(id, 0))
	var n := have if all else 1
	while n > 0 and not Game.can_carry_item(id, n):
		n -= 1
	if n <= 0:
		problem_label.text = "Your packs are full."
		return
	Game.add_item(id, n)
	Game.stash["items"][id] = have - n
	if int(Game.stash["items"][id]) <= 0:
		Game.stash["items"].erase(id)
	_rebuild()

func _stash_put_gear(it: Dictionary) -> void:
	if not _stash_room(1):
		problem_label.text = "The stash is full."
		return
	Game.remove_gear(it)
	Game.stash["gear"].append(it)
	_rebuild()

func _stash_take_gear(it: Dictionary) -> void:
	if not Game.can_carry_gear():
		problem_label.text = "Your packs are full."
		return
	Game.stash["gear"].erase(it)
	Game.add_gear(it)
	_rebuild()

func _add_stash_row() -> void:
	var cost := Game.stash_row_cost()
	if not Game.spend(cost):
		problem_label.text = "Another row costs %d gold." % cost
		return
	Game.stash_rows += 1
	_rebuild()
	problem_label.text = "The stash now has %d rows." % Game.stash_rows

func _grab_all() -> void:
	if mode == "stash":
		_add_stash_row()
		return
	# consumables first, then gear from best rarity down - as much as fits
	for id in m_items.keys():
		while int(m_items.get(id, 0)) > 0:
			m_items[id] = int(m_items[id]) - 1
			buy_items[id] = int(buy_items.get(id, 0)) + 1
			if _slots_after() > Game.capacity():
				buy_items[id] = int(buy_items[id]) - 1
				m_items[id] = int(m_items[id]) + 1
				break
		if int(m_items.get(id, 0)) <= 0:
			m_items.erase(id)
		if int(buy_items.get(id, 0)) <= 0:
			buy_items.erase(id)
	var order := m_gear.duplicate()
	order.sort_custom(func(a, b): return Loot.value_of(a) > Loot.value_of(b))
	for it in order:
		if _slots_after() + 1 <= Game.capacity():
			m_gear.erase(it)
			buy_gear.append(it)
	if m_gear.is_empty() and m_items.is_empty():
		_accept()
	else:
		_rebuild()
		problem_label.text = "Your packs are full - some items won't fit."

func open(id: String) -> void:
	_set_mode("trade")
	shop_id = id
	shop = Game.shops[id]
	var md: Dictionary = Game.MERCHANTS[id]
	title.text = md["name"]
	subtitle.text = "\"%s\"" % md["greeting"]
	p_gear = Game.bag.duplicate()
	p_items = Game.inventory.duplicate()
	m_gear = shop["gear"].duplicate()
	m_items = shop["items"].duplicate()
	buy_gear = []
	buy_items = {}
	sell_gear = []
	sell_items = {}
	Game.push_busy()
	visible = true
	_rebuild()
	cancel_btn.grab_focus.call_deferred()
	await closed

func _close() -> void:
	if not visible:
		return
	visible = false
	Game.main.tip.hide_tip()
	Game.pop_busy()
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("menu")):
		get_viewport().set_input_as_handled()
		_close()

# ---------------------------------------------------------------------------
func _totals() -> Array:
	var buy := 0
	var sell := 0
	for it in buy_gear:
		buy += Game.buy_price(it)
	for id in buy_items:
		buy += Game.buy_price(id) * int(buy_items[id])
	for it2 in sell_gear:
		sell += Game.sell_price(it2)
	for id2 in sell_items:
		sell += Game.sell_price(id2) * int(sell_items[id2])
	return [buy, sell]

func _slots_after() -> int:
	var n := p_gear.size() + buy_gear.size()
	var counts := p_items.duplicate()
	for id in buy_items:
		counts[id] = int(counts.get(id, 0)) + int(buy_items[id])
	for id2 in counts:
		n += Game.stacks_for(int(counts[id2]))
	return n

func _problem(net: int) -> String:
	if Game.funds() - net < 0:
		return "You can't afford this (%d gold short, counting your stash)." % (net - Game.funds())
	if int(shop["gold"]) + net < 0:
		return "The merchant only has %d gold." % int(shop["gold"])
	if _slots_after() > Game.capacity():
		return "Not enough room in your packs (%d / %d slots)." % [_slots_after(), Game.capacity()]
	return ""

func _rebuild() -> void:
	for f in [left_flow, right_flow]:
		for c in f.get_children():
			f.remove_child(c)
			c.queue_free()
	var u: Unit = Game.party[0]
	if mode == "stash":
		for id in _sorted_ids(Game.inventory):
			_add_cons(left_flow, id, int(Game.inventory[id]), "", "", _stash_put_item.bind(id))
		for it in _sorted_gear(Game.bag):
			_add_gear(left_flow, it, "", "", _stash_put_gear.bind(it), u)
		for i in maxi(0, Game.free_slots()):
			left_flow.add_child(ItemIcon.new(60))
		for id2 in _sorted_ids(Game.stash["items"]):
			_add_cons(right_flow, id2, int(Game.stash["items"][id2]), "", "", _stash_take_item.bind(id2))
		for it2 in _sorted_gear(Game.stash["gear"]):
			_add_gear(right_flow, it2, "", "", _stash_take_gear.bind(it2), u)
		for j in maxi(0, Game.stash_capacity() - Game.stash_used()):
			right_flow.add_child(ItemIcon.new(60))
		left_gold.text = "Gold: %d" % Game.gold
		right_gold.text = "Gold: %d" % int(Game.stash["gold"])
		left_cap.text = "Packs: %d / %d slots.  Click to store.  Right-click a stack to store it all." % [Game.used_slots(), Game.capacity()]
		right_foot.text = "Stash: %d / %d slots (%d rows).  Click to take back." % [Game.stash_used(), Game.stash_capacity(), Game.stash_rows]
		grab_btn.text = "  Add row (%dg)  " % Game.stash_row_cost()
		total_label.text = "[center]Carrying [color=#ffd870]%d[/color] gold   ·   Stash [color=#88ff88]%d[/color] gold[/center]" % [Game.gold, int(Game.stash["gold"])]
		return
	var loot := mode == "loot"
	# left: your stuff + pending purchases (in loot mode your own items stay put)
	for id in _sorted_ids(p_items):
		_add_cons(left_flow, id, int(p_items[id]), "", "" if loot else "%dg" % Game.sell_price(id), _noop_item if loot else _sell_item.bind(id))
	for it in _sorted_gear(p_gear):
		_add_gear(left_flow, it, "", "" if loot else "%dg" % Game.sell_price(it), _noop if loot else _sell_gear.bind(it), u)
	var pend := "take" if loot else "buy"
	for id2 in _sorted_ids(buy_items):
		_add_cons(left_flow, id2, int(buy_items[id2]), pend, "" if loot else "%dg" % Game.buy_price(id2), _unbuy_item.bind(id2))
	for it2 in buy_gear:
		_add_gear(left_flow, it2, pend, "" if loot else "%dg" % Game.buy_price(it2), _unbuy_gear.bind(it2), u)
	# right: merchant stock / spoils + pending sales
	for id3 in _sorted_ids(m_items):
		_add_cons(right_flow, id3, int(m_items[id3]), "", "" if loot else "%dg" % Game.buy_price(id3), _buy_item.bind(id3))
	for it3 in _sorted_gear(m_gear):
		_add_gear(right_flow, it3, "", "" if loot else "%dg" % Game.buy_price(it3), _buy_gear.bind(it3), u)
	for id4 in _sorted_ids(sell_items):
		_add_cons(right_flow, id4, int(sell_items[id4]), "sell", "%dg" % Game.sell_price(id4), _unsell_item.bind(id4))
	for it4 in sell_gear:
		_add_gear(right_flow, it4, "sell", "%dg" % Game.sell_price(it4), _unsell_gear.bind(it4), u)
	if loot:
		var n := buy_gear.size()
		for k in buy_items:
			n += int(buy_items[k])
		left_gold.text = "Gold: %d" % Game.gold
		left_cap.text = "Packs after looting: %d / %d slots." % [_slots_after(), Game.capacity()]
		total_label.text = "[center]%s[/center]" % ("Taking %d item%s" % [n, "" if n == 1 else "s"] if n > 0 else "Nothing selected")
		var over := _slots_after() > Game.capacity()
		problem_label.text = "Not enough room in your packs (%d / %d slots)." % [_slots_after(), Game.capacity()] if over else ""
		accept_btn.disabled = over
		return
	var t := _totals()
	var net: int = t[0] - t[1]
	left_gold.text = "Gold: %d" % Game.gold + ("  (+%d stash)" % int(Game.stash["gold"]) if int(Game.stash["gold"]) > 0 else "")
	right_gold.text = "Gold: %d" % int(shop["gold"])
	left_cap.text = "Packs after trade: %d / %d slots.  Click to sell.  Right-click a stack to sell it all." % [_slots_after(), Game.capacity()]
	var line: String
	if t[0] == 0 and t[1] == 0:
		line = "Nothing selected"
	elif net > 0:
		line = "You pay [color=#ff8866]%d gold[/color]" % net
		if net > Game.gold:
			line += "  [font_size=14][color=#aab0cc](%d from your stash)[/color][/font_size]" % (net - Game.gold)
	elif net < 0:
		line = "You receive [color=#88ff88]%d gold[/color]" % -net
	else:
		line = "Even trade"
	var detail := "" if (t[0] == 0 and t[1] == 0) else "\n[font_size=13][color=#aab0cc]Buying %dg   ·   Selling %dg[/color][/font_size]" % [t[0], t[1]]
	total_label.text = "[center]%s%s[/center]" % [line, detail]
	var prob := _problem(net)
	problem_label.text = prob
	accept_btn.disabled = prob != "" or (t[0] == 0 and t[1] == 0)

func _sorted_ids(d: Dictionary) -> Array:
	var ks: Array = d.keys().filter(func(k): return int(d[k]) > 0)
	ks.sort_custom(func(a, b): return DB.SHOP_STOCK.find(a) < DB.SHOP_STOCK.find(b))
	return ks

func _sorted_gear(arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort_custom(func(x, y):
		var bx := Loot.base_of(x)
		var by := Loot.base_of(y)
		if bx["cat"] != by["cat"]:
			return str(bx["cat"]) < str(by["cat"])
		return int(bx["tier"]) < int(by["tier"]))
	return a

func _add_cons(flow: Control, id: String, count: int, pend: String, price: String, cb: Callable) -> void:
	var ic := ItemIcon.new(60)
	ic.consumable = id
	ic.count = count
	ic.pending = pend
	ic.price_text = price
	ic.clicked.connect(func(_i, btn): cb.call(btn == MOUSE_BUTTON_RIGHT))
	flow.add_child(ic)

func _add_gear(flow: Control, it: Dictionary, pend: String, price: String, cb: Callable, u: Unit) -> void:
	var ic := ItemIcon.new(60)
	ic.item = it
	ic.unit = u
	ic.pending = pend
	ic.price_text = price
	var usable := false
	for m in Game.party:
		if Loot.req_problem(it, m) == "":
			usable = true
	ic.dim = not usable
	ic.clicked.connect(func(_i, _b): cb.call())
	flow.add_child(ic)

# --- moves -------------------------------------------------------------------
func _noop() -> void:
	pass

func _noop_item(_all: bool) -> void:
	pass

func _move(from: Dictionary, to: Dictionary, id: String, all: bool) -> void:
	var n: int = int(from.get(id, 0)) if all else 1
	n = mini(n, int(from.get(id, 0)))
	if n <= 0:
		return
	from[id] = int(from[id]) - n
	if from[id] <= 0:
		from.erase(id)
	to[id] = int(to.get(id, 0)) + n
	Game.main.tip.hide_tip()
	_rebuild()

func _move_gear(from: Array, to: Array, it: Dictionary) -> void:
	var i := from.find(it)
	if i < 0:
		return
	from.remove_at(i)
	to.append(it)
	Game.main.tip.hide_tip()
	_rebuild()

func _sell_item(all: bool, id: String) -> void:
	_move(p_items, sell_items, id, all)

func _unsell_item(all: bool, id: String) -> void:
	_move(sell_items, p_items, id, all)

func _buy_item(all: bool, id: String) -> void:
	_move(m_items, buy_items, id, all)

func _unbuy_item(all: bool, id: String) -> void:
	_move(buy_items, m_items, id, all)

func _sell_gear(it: Dictionary) -> void:
	_move_gear(p_gear, sell_gear, it)

func _unsell_gear(it: Dictionary) -> void:
	_move_gear(sell_gear, p_gear, it)

func _buy_gear(it: Dictionary) -> void:
	_move_gear(m_gear, buy_gear, it)

func _unbuy_gear(it: Dictionary) -> void:
	_move_gear(buy_gear, m_gear, it)

# ---------------------------------------------------------------------------
func _accept() -> void:
	if not visible:
		return   # already accepted (Grab All accepts by itself when everything fits)
	if mode == "loot":
		if _slots_after() > Game.capacity():
			return
		for id0 in buy_items:
			Game.add_item(id0, int(buy_items[id0]))
		for it0 in buy_gear:
			Game.add_gear(it0)
		buy_items = {}
		buy_gear = []
		_close()
		return
	var t := _totals()
	var net: int = t[0] - t[1]
	if _problem(net) != "":
		return
	if net > 0:
		Game.spend(net)
	else:
		Game.gold -= net
	shop["gold"] = int(shop["gold"]) + net
	# player side
	var inv := p_items.duplicate()
	for id in buy_items:
		inv[id] = int(inv.get(id, 0)) + int(buy_items[id])
	Game.inventory = inv
	Game.bag = p_gear + buy_gear
	# merchant side
	var stock := m_items.duplicate()
	for id2 in sell_items:
		stock[id2] = int(stock.get(id2, 0)) + int(sell_items[id2])
	shop["items"] = stock
	shop["gear"] = m_gear + sell_gear
	_close()
