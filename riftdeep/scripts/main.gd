extends Node
## Root: the home hub, dungeon runs through the portal, and all UI layers.

var world_root: Node2D
var battle_layer: CanvasLayer
var ui_root: Control
var dialog: Dialog
var sysmenu: SystemMenu
var menu: PartyMenu
var hud_panel: PartyHud
var fade: ColorRect
var title: Control
var current: Node
var battle: TacticsBattle
var in_battle := false
var in_run := false
var portal_glow := false
var hud_timer := 0.0
var tip: InfoTip
var kwtip: InfoTip       # keyword definitions, shown when hovering a key term
var trade: TradeWindow

func _ready() -> void:
	Game.main = self
	Game.busy_count = 0
	world_root = Node2D.new()
	add_child(world_root)
	battle_layer = CanvasLayer.new()
	battle_layer.layer = 1
	add_child(battle_layer)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiKit.theme()
	ui.add_child(ui_root)

	hud_panel = PartyHud.new()
	ui_root.add_child(hud_panel)
	hud_panel.visible = false
	menu = PartyMenu.new()
	ui_root.add_child(menu)
	trade = TradeWindow.new()
	ui_root.add_child(trade)
	dialog = Dialog.new()
	ui_root.add_child(dialog)
	_build_title()
	ui_root.move_child(title, dialog.get_index())  # dialogs (e.g. the overwrite confirm) draw above the title
	sysmenu = SystemMenu.new()
	ui_root.add_child(sysmenu)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	ui_root.add_child(fade)
	tip = InfoTip.new()
	ui_root.add_child(tip)
	kwtip = InfoTip.new()
	kwtip.z_index = 120
	ui_root.add_child(kwtip)

func _build_title() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.12))
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	c.add_child(v)
	var t1 := UiKit.label("RIFTDEEP", 54, Color(0.6, 0.85, 1.0))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := UiKit.label("a tactics prototype  -  every item holds a world", 18, Color(0.7, 0.75, 0.95))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	v.add_child(UiKit.label(" "))
	v.add_child(UiKit.label("Your name:"))
	var name_edit := LineEdit.new()
	name_edit.text = "Aldric"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(320, 0)
	v.add_child(name_edit)
	var start := Button.new()
	start.text = "New Game"
	v.add_child(start)
	var cont := Button.new()
	cont.text = "Continue"
	cont.visible = Game.has_save()
	cont.pressed.connect(_continue_game)
	v.add_child(cont)
	var tests := Button.new()
	tests.text = "Testing Multipliers"
	tests.pressed.connect(func(): sysmenu.open_settings_only())
	v.add_child(tests)
	var help := UiKit.label("Click to walk / use     Party: Tab     Roster: T     Build: B     Pause: Esc", 14, Color(0.7, 0.75, 0.9))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	var go := func():
		var n := name_edit.text.strip_edges()
		_start_game(n if n != "" else "Aldric")
	start.pressed.connect(go)
	name_edit.text_submitted.connect(func(_t): go.call())
	(cont if cont.visible else start).grab_focus.call_deferred()

func _start_game(hero_name: String) -> void:
	if not title.visible:
		return
	if Game.has_save():
		var r := await dialog.ask("Start a new game? This will overwrite your existing save.", ["Start new game", "Cancel"])
		if r != 0:
			return
	Game.new_game(hero_name)
	Game.save_game()
	await go_home(func(): title.visible = false)
	await dialog.ask("You wake in a quiet meadow beside a campfire, %s. Two wanderers, %s and %s, share the fire.\n\nIn the clearing stands an old portal device. Open it empty and it leads into a plain dungeon that goes down forever. Place an item in it and the rift opens into that item's own world - every floor you clear inside makes the item stronger.\n\nThis meadow is yours to build on: press B to build with wood. Recruit wanderers at the campfire - whoever stays home works (chopping wood) for every floor your party clears. T opens the roster, Tab the party menu. Rest at the campfire to save." % [hero_name, Game.party[1].name, Game.party[2].name])

func _continue_game() -> void:
	if not title.visible:
		return
	if Game.load_game():
		await go_home(func(): title.visible = false)

func fade_to(a: float, dur: float = 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", a, dur)
	await tw.finished

## Back to the meadow.
func go_home(during: Callable = Callable()) -> void:
	Game.push_busy()
	tip.hide_tip()
	await fade_to(1.0)
	if current != null:
		current.queue_free()
		current = null
	if during.is_valid():
		during.call()
	var home := HomeMap.new()
	current = home
	world_root.add_child(home)
	RenderingServer.set_default_clear_color(Color(0.1, 0.15, 0.1))
	_update_hud()
	await fade_to(0.0)
	Game.pop_busy()

func open_shop(shop_id: String, _greeting: String = "") -> void:
	await trade.open(shop_id)

func open_stash() -> void:
	await trade.open_stash()

# ---------------------------------------------------------------------------
# A run through the portal: floor after floor until you go home or fall.
# ---------------------------------------------------------------------------
func start_run(item) -> void:
	if in_run:
		return
	in_run = true
	portal_glow = true
	var world_name: String = item.get("name", "") if item is Dictionary else ""
	var start_level: int = Loot.world_level(item) if item is Dictionary else 1
	Game.depth = 1
	Game.rest_party()
	while true:
		var lvl := start_level + Game.depth - 1
		var result := await _fight_floor(Game.depth, lvl, world_name)
		if result == "defeat":
			Game.on_defeat()
			in_run = false
			portal_glow = false
			await go_home()
			await dialog.ask("The portal spits you back out by the campfire, battered but alive. Everything you carried and learned is still yours.")
			Game.save_game()
			return
		var news := ""
		var made := Game.work_floor_cleared()
		if not made.is_empty():
			news += "\n\nBack home, your town works: " + ", ".join(made.keys().map(func(k): return "+%d %s" % [made[k], k])) + "."
		if item is Dictionary:
			Loot.level_item(item)
			world_name = item["name"]
			news += "\n\nThe item grows stronger: %s (all stats x%.2f)." % [item["name"], Loot.wlv_mult(item)]
			for u in Game.party:
				u.recalc()
		else:
			Game.deepest = maxi(Game.deepest, Game.depth)
		# a short breather between floors
		for u in Game.party:
			if not u.is_alive():
				u.hp = 1
			else:
				u.hp = mini(u.max_hp(), u.hp + int(u.max_hp() * 0.25))
			u.mp = mini(u.max_mp(), u.mp + int(u.max_mp() * 0.25))
			u.poison_left = 0
			u.hots.clear()
		var stay := true
		while true:
			var nxt := Game.depth + 1
			var r := await dialog.ask("Floor %d cleared.%s\n\nFallen allies get back up, and everyone catches their breath (+25%% HP and MP). The way down is open - floor %d holds monsters of level %d%s." % [Game.depth, news, nxt, start_level + nxt - 1, ", and a boss" if nxt % 2 == 0 else ""],
				["Descend to floor %d" % nxt, "Party menu", "Return home through the portal"])
			news = ""
			if r == 1:
				menu.open_menu()
				while menu.visible:
					await get_tree().process_frame
				continue
			stay = r == 0
			break
		if not stay:
			break
		Game.depth += 1
	in_run = false
	portal_glow = false
	Game.depth = 0
	Game.rest_party()
	await go_home()
	Game.save_game()

func _fight_floor(floor_n: int, lvl: int, world_name: String) -> String:
	in_battle = true
	Game.push_busy()
	await fade_to(1.0, 0.3)
	if current != null:
		current.queue_free()
		current = null
	hud_panel.visible = false
	battle = TacticsBattle.new()
	battle.setup(floor_n, lvl, world_name)
	battle_layer.add_child(battle)
	RenderingServer.set_default_clear_color(Color(0.06, 0.05, 0.08))
	await fade_to(0.0, 0.3)
	Game.pop_busy()
	var result: String = await battle.finished
	await fade_to(1.0, 0.3)
	battle.queue_free()
	battle = null
	in_battle = false
	await fade_to(0.0, 0.2)
	return result

# ---------------------------------------------------------------------------
# Input & HUD
# ---------------------------------------------------------------------------
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if dialog.visible:
		if e.is_action_pressed("ui_cancel"):
			dialog.cancel()
			get_viewport().set_input_as_handled()
		return
	if menu.visible:
		if e.is_action_pressed("menu") or e.is_action_pressed("ui_cancel"):
			menu.close_menu()
			get_viewport().set_input_as_handled()
		return
	if e.keycode == KEY_ESCAPE and not title.visible and not trade.visible:
		if in_battle:
			if battle != null and (battle.selecting or battle._has_back()):
				return
		elif Game.ui_busy:
			return
		sysmenu.open_menu()
		get_viewport().set_input_as_handled()
		return
	if in_battle or title.visible or current == null or Game.ui_busy:
		return
	if e.is_action_pressed("menu"):
		menu.open_menu()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.25
		_update_hud()

func _update_hud() -> void:
	if current == null:
		return
	hud_panel.visible = false
