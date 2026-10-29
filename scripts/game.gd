extends Node3D
## Match controller: builds the world, runs the swallow physics,
## holes vs holes, bots and the three game modes.
## With `attract = true` it is the main menu background: a small city, one bot,
## no HUD, no sound, a slowly orbiting camera.

signal attract_finished

const GROUND_LAYER := 1
const EDIBLE_LAYER := 2
const CELL := 8.0
const MAX_HOLES := 16
const RESPAWN_TIME := 3.0
const ZONE_OUT_LIMIT := 4.0
const CAM_PITCH := 65.0
const POWERUP_COUNT := 6
const POWERUP_RESPAWN := 18.0
const ATTRACT_TIME := 90.0
const POPUP_POOL := 12
## Traffic light cycle: horizontal green, all red, vertical green, all red.
const LIGHT_CYCLE := 16.0
const GROUND_SHADER := preload("res://scripts/world/ground.gdshader")

const HOLE_COLORS := [Color("4cc9f0"), Color("f72585"), Color("ffd60a"), Color("80ed99"),
	Color("ff8500"), Color("b388eb"), Color("ff595e"), Color("f8f9fa"), Color("06d6a0"),
	Color("3a86ff"), Color("ffafcc"), Color("a7c957"), Color("fb5607")]
const BOT_NAMES := ["Borsch", "Varenyk", "Kozak", "Nimbus", "Pixel", "Bublyk", "Kotyk",
	"Grim", "Mango", "Zirka", "Turbo", "Lava", "Blyskavka", "Shadow"]

var mode: int
var holes: Array[Hole] = []
var player: Hole
var hud: Hud
var camera: Camera3D
var sun: DirectionalLight3D
var ground_mat: ShaderMaterial
var world: Node3D

var grid := {}            # Vector2i -> Array[Edible]
var awake := {}           # Edible -> true (dynamic bodies, need re-binning)
var falling: Array[Edible] = []
var total_points := 0
var total_count := 0
var eaten_count := 0
var bound := 100.0
var time_left := 120.0
var running := false
var zone_start := 0.0
var zone_radius := 0.0
var _rebin_timer := 0.0
var _hud_timer := 0.0
var _vibrate_cooldown := 0.0
var _player_bot: BotAI = null
var half_extent := 100.0
var movers := {}          # Edible -> true (driving cars)
var lanes := {}           # lane key -> Array[Edible], leader first
var _traffic_time := 0.0
var powerups: Array[Powerup] = []
var _powerup_timers: Array[float] = []
var _flung := {}          # diagnostics: objects thrown into the air
var attract := false
var _attract_time := 0.0
var _orbit := 0.0
var _shake := 0.0         # camera trauma 0..1
var _popups: Array[Label3D] = []
var _popup_next := 0
var _last_tick := -1
var _best_item := 0
var demolition: Demolition
var _last_tick_us := 0
## Breakables that reached a hole this tick: [edible, hole, whole_fits].
var _breaking: Array = []
## Chunk points eaten by the player, shown as one "+N" per collapse.
var _debris_gain := 0
var _debris_gain_timer := 0.0
var _frame_ms_sum := 0.0
var _frames := 0


func _ready() -> void:
	mode = GameState.Mode.SOLO if attract else GameState.mode
	time_left = GameState.match_time()
	_build_environment()
	var blocks := _blocks()
	var half := CityGen.map_extent(blocks) / 2.0
	bound = half - 2.0
	half_extent = half
	_build_ground(half)
	demolition = Demolition.new()
	demolition.game = self
	add_child(demolition)
	_spawn_city(randi() % 1000000 if attract else GameState.resolve_seed(), blocks)
	_spawn_holes()
	if mode == GameState.Mode.BATTLE:
		zone_start = half * 1.45
		zone_radius = zone_start
	for i in (2 if attract else POWERUP_COUNT):
		_spawn_powerup()
	_make_popups()
	running = true
	if attract:
		return

	hud = Hud.new()
	add_child(hud)
	hud.play_again.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	hud.to_menu.connect(_go_menu)
	hud.resume.connect(resume)
	_update_hud()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_take_screenshot(arg.trim_prefix("--screenshot="))


func _blocks() -> int:
	return 2 if attract else GameState.city_blocks()


func _theme() -> int:
	return GameState.map_theme if attract else GameState.match_theme()


## Dev helper: "-- --autoplay --screenshot=/path/shot.png" saves a frame after 8 s.
func _take_screenshot(path: String) -> void:
	var delay := 8.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-delay="):
			delay = arg.trim_prefix("--shot-delay=").to_float()
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)
	get_tree().quit()


func _notification(what: int) -> void:
	if attract or hud == null:
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if hud.has_results():
				_go_menu()
			elif hud.is_paused():
				resume()
			else:
				pause()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not GameState.autoplay:
				pause()


func pause() -> void:
	if not running or hud == null or hud.is_paused():
		return
	get_tree().paused = true
	hud.show_pause()


func resume() -> void:
	get_tree().paused = false
	hud.hide_pause()


func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# --- World -----------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9ad1f5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_normal_bias = 1.5
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 600.0
	camera.rotation_degrees = Vector3(-CAM_PITCH, 0, 0)
	# Camera follows the interpolated hole itself, so it must not be interpolated again.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)

	world = Node3D.new()
	add_child(world)


func _build_ground(half: float) -> void:
	var size := half * 2.0 + 120.0
	var body := StaticBody3D.new()
	body.collision_layer = GROUND_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	add_child(body)

	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("half_extent", half)
	ground_mat.set_shader_parameter("block_size", CityGen.BLOCK)
	ground_mat.set_shader_parameter("pitch", CityGen.PITCH)
	ground_mat.set_shader_parameter("road", CityGen.ROAD)
	ground_mat.set_shader_parameter("sidewalk", CityGen.SIDEWALK)
	if _theme() == GameState.MapTheme.SUBURB:
		ground_mat.set_shader_parameter("grass_color", Color("7fb069"))
		ground_mat.set_shader_parameter("road_color", Color("5c5f66"))
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = ground_mat
	add_child(mi)


func _spawn_city(seed_value: int, blocks: int) -> void:
	var factory := EdibleFactory.new()
	for spec in CityGen.generate(seed_value, blocks, _theme()):
		var e := factory.build(spec)
		if _overlaps_existing(e):
			e.free()
			continue
		world.add_child(e)
		_grid_add(e)
		demolition.prepare(e)
		total_points += e.points
		total_count += 1
		if e.moving:
			_add_mover(e)
	_sort_lanes()


func _spawn_holes() -> void:
	var count := 1 if mode == GameState.Mode.SOLO else 1 + GameState.bot_count
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var skin := Skins.get_skin(GameState.skin)
	# Bots never wear a colour close to the player's skin.
	var colors: Array = []
	for c: Color in HOLE_COLORS:
		if _color_distance(c, skin.color) > 0.25:
			colors.append(c)
	var skill := GameState.bot_skill_range()
	for i in count:
		var h := Hole.new()
		var is_player := i == 0
		if is_player:
			h.setup("" if attract else tr("YOU"), skin.color, true, skin.pattern)
		else:
			h.setup(names[i % names.size()], colors[(i - 1) % colors.size()], false)
		add_child(h)
		h.position = _spawn_point(i, count)
		if is_player:
			player = h
			h.leveled_up.connect(_on_player_level)
			if GameState.autoplay or attract:
				_player_bot = BotAI.new(h, self, 0.8)
		else:
			h.controller = BotAI.new(h, self, randf_range(skill.x, skill.y), GameState.bot_chase_start())
		holes.append(h)


static func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _spawn_point(i: int, count: int) -> Vector3:
	if count == 1:
		return Vector3(0, 0, CityGen.ROAD / 2.0 - half_extent + CityGen.PITCH * mini(2, _blocks() - 1))
	# Spread around a circle, snapped to the nearest road centre line.
	var a := TAU * i / count + randf() * 0.3
	var r := bound * 0.6
	var p := Vector3(cos(a) * r, 0, sin(a) * r)
	var half := half_extent
	var road_z: float = round((p.z + half - CityGen.ROAD / 2.0) / CityGen.PITCH) * CityGen.PITCH - half + CityGen.ROAD / 2.0
	p.z = road_z
	return p


## Footprint rectangle (x0, z0, x1, z1) of a spawned object, yaw included.
func _footprint(e: Edible) -> Rect2:
	var s := e.size
	var c := absf(cos(e.rotation.y))
	var sn := absf(sin(e.rotation.y))
	var hx := (c * s.x + sn * s.z) * 0.5
	var hz := (sn * s.x + c * s.z) * 0.5
	return Rect2(e.position.x - hx, e.position.z - hz, hx * 2.0, hz * 2.0)


## Spawned objects must not overlap, otherwise physics flings them apart on wake.
func _overlaps_existing(e: Edible) -> bool:
	var r := _footprint(e).grow(-0.05)
	for bucket in _cells_around(e.position, e.extent * 0.5 + 10.0):
		for o: Edible in bucket:
			if r.intersects(_footprint(o)):
				return true
	return false


# --- Spatial grid ----------------------------------------------------------

func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func _grid_add(e: Edible) -> void:
	e.cell = _cell_of(e.position)
	if not grid.has(e.cell):
		grid[e.cell] = []
	grid[e.cell].append(e)


func _grid_remove(e: Edible) -> void:
	if grid.has(e.cell):
		grid[e.cell].erase(e)


func _cells_around(p: Vector3, reach: float) -> Array:
	var out := []
	var a := _cell_of(p - Vector3(reach, 0, reach))
	var b := _cell_of(p + Vector3(reach, 0, reach))
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			var c := Vector2i(x, z)
			if grid.has(c):
				out.append(grid[c])
	return out


# --- Main loop -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not running:
		return
	if attract:
		_attract_time += delta
		if _attract_time > ATTRACT_TIME:
			running = false
			attract_finished.emit()
			return
	else:
		time_left -= delta
	_vibrate_cooldown -= delta

	if player.alive:
		if _player_bot:
			_player_bot.update(delta)
		else:
			player.move_dir = _player_input()

	for h in holes:
		if h.alive:
			if h.controller:
				h.controller.update(delta)
			h.step(delta, bound)
		elif mode == GameState.Mode.CLASSIC:
			h.respawn_timer -= delta
			if h.respawn_timer <= 0.0:
				_respawn(h)

	_traffic_step(delta)
	_powerup_step(delta)
	_swallow_step()
	if not attract:
		_tick_sound()
	_falling_step()
	if mode != GameState.Mode.SOLO:
		_holes_step()
	if mode == GameState.Mode.BATTLE:
		_zone_step(delta)

	_rebin_timer -= delta
	if _rebin_timer <= 0.0:
		_rebin_timer = 0.5
		_rebin()
		_sort_lanes()
		demolition.tick()

	_update_ground()
	# Diagnostics: average time per physics tick, engine physics included.
	var now := Time.get_ticks_usec()
	if _last_tick_us > 0:
		_frame_ms_sum += (now - _last_tick_us) / 1000.0
		_frames += 1
	_last_tick_us = now
	_check_end()


func _process(delta: float) -> void:
	if player == null:
		return
	var focus := player.get_global_transform_interpolated().origin
	if attract:
		# Menu background: slow orbit around the bot, a bit further out.
		_orbit += delta * 0.12
		var dist := 30.0 + player.radius * 6.0
		var off := Vector3(sin(_orbit), 0, cos(_orbit)) * cos(deg_to_rad(50.0)) * dist
		off.y = sin(deg_to_rad(50.0)) * dist
		var want := focus + off
		camera.position = want if camera.position == Vector3.ZERO else camera.position.lerp(want, clampf(delta * 2.0, 0.0, 1.0))
		camera.look_at(focus)
		sun.directional_shadow_max_distance = dist * 1.8
		return
	var d := 24.0 + player.radius * 5.5
	var pitch := deg_to_rad(CAM_PITCH)
	var target := focus + Vector3(0, sin(pitch) * d, cos(pitch) * d)
	if camera.position == Vector3.ZERO:
		camera.position = target
	else:
		camera.position = camera.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	sun.directional_shadow_max_distance = d * 1.6
	_shake = maxf(_shake - delta * 1.6, 0.0)
	if _debris_gain_timer > 0.0:
		_debris_gain_timer -= delta
		if _debris_gain_timer <= 0.0 and _debris_gain > 0:
			_popup(player, "+%d" % _debris_gain, player.color.lightened(0.5) if _debris_gain < 50 else Color("ffd60a"))
			_debris_gain = 0
	var amp := _shake * _shake * (0.6 + player.radius * 0.08) if GameState.shake else 0.0
	camera.h_offset = randf_range(-amp, amp)
	camera.v_offset = randf_range(-amp, amp)
	if running:
		_update_pointers()
	_hud_timer -= delta
	if _hud_timer <= 0.0 and running:
		_hud_timer = 0.2
		_update_hud()


func _add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


## Edge-of-screen arrows towards nearby holes outside the view:
## red = can eat you, green = you can eat it.
func _update_pointers() -> void:
	if mode == GameState.Mode.SOLO or not player.alive:
		hud.set_pointers([])
		return
	var rect := get_viewport().get_visible_rect()
	var inner := rect.grow(-48.0)
	var center := rect.get_center()
	var found := []
	for o in holes:
		if o == player or not o.alive:
			continue
		var c := Color()
		if o.radius > player.radius * HoleRules.EAT_HOLE_RATIO:
			c = Color("ff4d6d")
		elif player.radius > o.radius * HoleRules.EAT_HOLE_RATIO:
			c = Color("80ed99")
		else:
			continue
		var dist := o.position.distance_to(player.position)
		if dist > 45.0 + player.radius * 4.0 or camera.is_position_behind(o.position):
			continue
		var sp := camera.unproject_position(o.position)
		if rect.has_point(sp):
			continue
		var dir := (sp - center).normalized()
		# Walk from the centre to the inner rectangle edge along dir.
		var tx := (inner.size.x / 2.0) / maxf(absf(dir.x), 0.001)
		var ty := (inner.size.y / 2.0) / maxf(absf(dir.y), 0.001)
		var p := center + dir * minf(tx, ty)
		found.append({"p": p, "a": dir.angle(), "c": c, "d": dist})
	found.sort_custom(func(a, b): return a.d < b.d)
	hud.set_pointers(found.slice(0, 4))


func _player_input() -> Vector2:
	var v := hud.joystick.vector
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): k.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): k.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): k.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): k.y += 1
	if k != Vector2.ZERO:
		return k.normalized()
	if v == Vector2.ZERO:
		return Vector2.ZERO
	return v.normalized() * clampf(v.length() * 1.6, 0.0, 1.0)


func _swallow_step() -> void:
	for h in holes:
		if not h.alive:
			continue
		var r := h.radius
		var hp := h.position
		var mr := h.magnet_radius()
		var ms := h.magnet_strength()
		for bucket in _cells_around(hp, maxf(r + 11.0, mr + 2.0)):
			for e: Edible in bucket:
				if e.falling_into != null:
					continue
				var dx := e.position.x - hp.x
				var dz := e.position.z - hp.z
				var d := sqrt(dx * dx + dz * dz)
				# Things that do not fit stay static: the hole slides under them,
				# unless they can fall apart and a chunk would fit.
				if not HoleRules.fits(e.fit_size, r):
					if e.breakable and demolition.can_fracture(e, h, d):
						e.falling_into = h
						_breaking.append([e, h, false])
					continue
				var touching := d <= r + e.extent * 0.5 + 0.3
				var pulled := e.magnetic and d < mr
				if not (touching or pulled):
					continue
				_wake(e)
				if d < r + e.extent * 0.3:
					# Overlaps the hole: from now on it ignores the ground
					# and tips over into the hole (big things fall apart first).
					if e.breakable:
						e.falling_into = h
						_breaking.append([e, h, true])
					else:
						_start_fall(e, h)
				elif e.magnetic:
					var pull := Vector3(-dx, 0, -dz) / maxf(d, 0.01)
					var k := 4.0 if touching else ms * (1.0 - d / mr)
					e.apply_central_force(pull * e.mass * k)
	# Breaking changes the grid, so it waits until the loops above are done.
	for item in _breaking:
		var e: Edible = item[0]
		if not is_instance_valid(e):
			continue
		if item[2]:
			demolition.collapse(e, item[1])
		else:
			e.falling_into = null
			demolition.fracture(e, item[1])
	_breaking.clear()


func _wake(e: Edible) -> void:
	if e.freeze:
		var was_moving := e.moving
		e.moving = false
		movers.erase(e)
		e.freeze = false
		if was_moving:
			e.linear_velocity = e.transform.basis.z * e.move_speed
		awake[e] = true
	e.sleeping = false


# --- Traffic ---------------------------------------------------------------

func _lane_key(e: Edible) -> String:
	var fwd := e.transform.basis.z
	if absf(fwd.x) > 0.5:
		return "h%d:%d" % [roundi(e.position.z * 10.0), signi(roundi(fwd.x))]
	return "v%d:%d" % [roundi(e.position.x * 10.0), signi(roundi(fwd.z))]


func _add_mover(e: Edible) -> void:
	var key := _lane_key(e)
	if not lanes.has(key):
		lanes[key] = []
		# One speed per lane, so cars never catch up with each other.
		lanes[key].append(randf_range(5.0, 8.0))
	e.move_speed = lanes[key][0]
	lanes[key].append(e)
	movers[e] = true


## Leader first (largest coordinate along the driving direction); slot 0 is the speed.
func _sort_lanes() -> void:
	for key in lanes.keys():
		_sort_lane(key)


func _sort_lane(key: String) -> void:
	var list: Array = lanes[key]
	var speed: float = list[0]
	var cars: Array = []
	for i in range(1, list.size()):
		var e = list[i]
		if is_instance_valid(e) and e.moving:
			cars.append(e)
	cars.sort_custom(func(a: Edible, b: Edible):
		return a.position.dot(a.transform.basis.z) > b.position.dot(b.transform.basis.z))
	lanes[key] = [speed] + cars


func _green(horizontal: bool) -> bool:
	var t := fmod(_traffic_time, LIGHT_CYCLE)
	return t < 5.0 if horizontal else (t >= 8.0 and t < 13.0)


## Stop position (car front, along the driving direction) before the next crossing, or INF.
func _stop_line(front: float, dsign: float) -> float:
	# Crossing centres in world coords are -half + ROAD/2 + j * PITCH; in "s" they are mirrored by dsign.
	var best := INF
	var blocks := _blocks()
	for j in blocks + 1:
		var c := (-half_extent + CityGen.ROAD / 2.0 + j * CityGen.PITCH) * dsign
		var line := c - CityGen.ROAD / 2.0 - 0.3
		if line >= front - 0.05 and line < best:
			best = line
	return best


func _traffic_step(delta: float) -> void:
	_traffic_time += delta
	# A car that wrapped around is now the last one in its lane: re-sort right away,
	# otherwise it keeps the leader slot and drives through the car in front of it.
	var wrapped_lanes: Array[String] = []
	for key in lanes:
		var list: Array = lanes[key]
		var horizontal: bool = (key as String).begins_with("h")
		var green := _green(horizontal)
		var leader_back := INF
		for i in range(1, list.size()):
			var e = list[i]
			if not is_instance_valid(e) or not e.moving:
				continue
			var fwd: Vector3 = e.transform.basis.z
			var dsign := signf(fwd.x if horizontal else fwd.z)
			var half_len: float = e.extent * 0.5
			var s: float = e.position.dot(fwd)
			var target: float = s + e.move_speed * delta
			if not green:
				var line := _stop_line(s + half_len, dsign)
				if line < INF and s + half_len + e.move_speed * delta > line:
					target = minf(target, line - half_len)
			if leader_back < INF:
				target = minf(target, leader_back - half_len - 1.5)
			target = maxf(target, s)
			leader_back = target - half_len
			var p: Vector3 = e.position + fwd * (target - s)
			var wrapped := false
			if horizontal and absf(p.x) > half_extent - 2.0 and signf(p.x) == dsign:
				p.x -= dsign * (half_extent * 2.0 - 4.0)
				wrapped = true
			elif not horizontal and absf(p.z) > half_extent - 2.0 and signf(p.z) == dsign:
				p.z -= dsign * (half_extent * 2.0 - 4.0)
				wrapped = true
			e.position = p
			if wrapped:
				e.reset_physics_interpolation()
				leader_back = INF
				if not wrapped_lanes.has(key):
					wrapped_lanes.append(key)
	for key in wrapped_lanes:
		_sort_lane(key)


# --- Powerups --------------------------------------------------------------

func _spawn_powerup() -> void:
	var blocks := _blocks()
	var p := Powerup.new()
	p.kind = Powerup.random_kind(mode != GameState.Mode.SOLO)
	world.add_child(p)
	for attempt in 6:
		var road := -half_extent + CityGen.ROAD / 2.0 + randi_range(0, blocks) * CityGen.PITCH
		var along := randf_range(-bound, bound) * 0.9
		p.position = Vector3(along, 1.6, road) if randf() < 0.5 else Vector3(road, 1.6, along)
		# Battle: only inside the zone, otherwise nobody can get it.
		if mode != GameState.Mode.BATTLE or Vector2(p.position.x, p.position.z).length() < zone_radius - 8.0:
			break
	powerups.append(p)


func _powerup_step(delta: float) -> void:
	for i in range(_powerup_timers.size() - 1, -1, -1):
		_powerup_timers[i] -= delta
		if _powerup_timers[i] <= 0.0:
			_powerup_timers.remove_at(i)
			_spawn_powerup()
	for i in range(powerups.size() - 1, -1, -1):
		var p := powerups[i]
		for h in holes:
			if not h.alive:
				continue
			if Vector2(h.position.x - p.position.x, h.position.z - p.position.z).length() < h.radius + 1.0:
				h.give_effect(p.kind, Powerup.DURATIONS[p.kind])
				if _me(h):
					hud.notice(tr(Powerup.NAMES[p.kind]) + "!", 1.5)
					GameState.vibrate(40)
					Sfx.play("powerup")
				p.queue_free()
				powerups.remove_at(i)
				_powerup_timers.append(POWERUP_RESPAWN)
				break


func _start_fall(e: Edible, h: Hole) -> void:
	if e.kind == "debris":
		demolition.release(e)
	e.falling_into = h
	e.collision_mask = EDIBLE_LAYER
	e.gravity_scale = 1.6
	e.sleeping = false
	# Tip it over towards the middle of the hole: things narrower than the hole
	# would otherwise sink straight down, which looks like falling through the ground.
	var to_c := Vector3(h.position.x - e.position.x, 0, h.position.z - e.position.z)
	if to_c.length() < 0.05:
		var a := randf() * TAU
		to_c = Vector3(cos(a), 0, sin(a))
	to_c = to_c.normalized()
	var spin := clampf(0.8 + e.height * 0.25, 0.8, 2.5)
	e.angular_velocity += Vector3.UP.cross(to_c) * spin
	e.linear_velocity += to_c * 0.6
	falling.append(e)


func _falling_step() -> void:
	for i in range(falling.size() - 1, -1, -1):
		var e := falling[i]
		if not is_instance_valid(e):
			falling.remove_at(i)
			continue
		var h := e.falling_into as Hole
		var top := e.position.y + e.height * 0.5
		if top < -0.5 or e.position.y < -40.0:
			falling.remove_at(i)
			_eat(e, h)
			continue
		var bottom := e.position.y - e.height * 0.5
		# Falling things bump into each other and can kick one upwards: never fly.
		if e.linear_velocity.y > 2.0:
			e.linear_velocity.y = 2.0
		var d := INF
		if h.alive:
			d = Vector2(e.position.x - h.position.x, e.position.z - h.position.z).length()
		var off_hole := d > h.radius + e.extent * 0.5 + 0.3
		if h.alive and h.radius > h.target_radius + 0.02 and bottom < -0.1:
			# The hole is shrinking (Giant ended) and this is already partly
			# underground: it counts as eaten.
			falling.remove_at(i)
			_eat(e, h)
			continue
		if off_hole and bottom > -0.1:
			# Fully back on solid ground (the hole moved away): normal object again.
			e.falling_into = null
			e.collision_mask = GROUND_LAYER | EDIBLE_LAYER
			e.gravity_scale = 1.0
			falling.remove_at(i)
		elif off_hole and (not h.alive or d > h.radius + h.lip_width()):
			# Already partly underground and nothing holds it: it is hidden anyway,
			# count it as eaten instead of popping it back up through the asphalt.
			falling.remove_at(i)
			_eat(e, h)


func _eat(e: Edible, h: Hole) -> void:
	_grid_remove(e)
	awake.erase(e)
	var debris := e.kind == "debris"
	if debris:
		demolition.forget(e)
		demolition.release(e)
	if h and h.alive:
		# Chunks of one building do not build up a streak on their own.
		var gained := h.streak_points(e.points) if debris else h.combo_points(e.points)
		h.add_points(gained)
		if h == player:
			eaten_count += 1
			_best_item = maxi(_best_item, e.whole_points if debris else e.points)
		if _me(h):
			_eat_feedback(e, h, gained)
	e.queue_free()


func _me(h: Hole) -> bool:
	return h == player and not attract


## Sound, vibration, shake and the floating "+N" for something the player ate.
func _eat_feedback(e: Edible, h: Hole, gained: int) -> void:
	if e.kind == "debris":
		Sfx.play("gulp", randf_range(0.7, 0.9), -6.0, 70)
		_debris_gain += gained
		_debris_gain_timer = 0.4
		return
	# Small things sound high, big things low.
	var big := e.points >= 40
	var pitch := clampf(1.6 - log(float(e.points) + 1.0) * 0.18, 0.55, 1.6) * randf_range(0.93, 1.07)
	Sfx.play("gulp_big" if big else "gulp", pitch, -4.0 if e.points < 3 else 0.0, 0 if big else 45)
	if _vibrate_cooldown <= 0.0 and e.points >= 5:
		_vibrate_cooldown = 0.25
		GameState.vibrate(clampi(10 + e.points / 20, 10, 60))
	if e.points >= 20:
		_add_shake(clampf(e.points / 250.0, 0.12, 0.5))
	if gained >= 5:
		_popup(h, "+%d" % gained, h.color.lightened(0.5) if gained < 50 else Color("ffd60a"))


func _make_popups() -> void:
	for i in POPUP_POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 72
		l.outline_size = 18
		l.outline_modulate = Color(0, 0, 0, 0.75)
		var f := UiTheme.font(800)
		if f:
			l.font = f
		l.visible = false
		l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(l)
		_popups.append(l)


func _popup(h: Hole, text: String, color: Color) -> void:
	var l := _popups[_popup_next]
	_popup_next = (_popup_next + 1) % _popups.size()
	var tw: Tween = l.get_meta("tween") if l.has_meta("tween") else null
	if tw and tw.is_valid():
		tw.kill()
	var spread := h.radius * 0.6 + 0.5
	l.position = h.position + Vector3(randf_range(-spread, spread), 1.5 + h.radius * 0.5, randf_range(-spread, spread))
	l.text = text
	l.pixel_size = 0.008 * (1.0 + h.radius * 0.3)
	l.modulate = color
	l.outline_modulate.a = 0.75
	l.visible = true
	tw = create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 2.0 + h.radius * 0.6, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(func(): l.visible = false)
	l.set_meta("tween", tw)


## Clock ticks during the last 10 seconds.
func _tick_sound() -> void:
	var s := int(ceil(time_left))
	if s <= 10 and s > 0 and s != _last_tick:
		_last_tick = s
		Sfx.play("tick", 1.0 if s > 3 else 1.3)


func _rebin() -> void:
	for e in movers.keys():
		if not is_instance_valid(e):
			movers.erase(e)
			continue
		var mc := _cell_of(e.position)
		if mc != e.cell:
			_grid_remove(e)
			_grid_add(e)
	for e in awake.keys():
		if not is_instance_valid(e):
			awake.erase(e)
			continue
		if e.position.y < -60.0:
			_grid_remove(e)
			awake.erase(e)
			e.queue_free()
			continue
		# Chunks of a tall building start high up: count only real jumps.
		var base_y: float = e.get_meta("home", Vector3(0, e.height * 0.5, 0)).y - e.height * 0.5 if e.kind == "debris" else 0.0
		if e.position.y - e.height * 0.5 > maxf(base_y, 0.0) + 2.5:
			_flung[e.get_instance_id()] = true
		var c := _cell_of(e.position)
		if c != e.cell:
			_grid_remove(e)
			_grid_add(e)
		if e.sleeping and e.falling_into == null:
			awake.erase(e)


# --- Holes vs holes --------------------------------------------------------

func _holes_step() -> void:
	for a in holes:
		if not a.alive:
			continue
		for b in holes:
			if b == a or not b.alive:
				continue
			var d := Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()
			if not b.has_effect(Powerup.Kind.SHIELD) and HoleRules.can_eat_hole(a.radius, b.radius, d):
				_eat_hole(a, b)


func _eat_hole(a: Hole, b: Hole) -> void:
	a.add_points(maxi(5, b.points / 2))
	b.set_alive(false)
	if _me(a):
		hud.notice(tr("ATE_HOLE") % b.hole_name, 1.5)
		GameState.vibrate(80)
		Sfx.play("eat_hole")
		_add_shake(0.6)
		_popup(a, "+%d" % maxi(5, b.points / 2), Color("80ed99"))
	if _me(b):
		Sfx.play("eaten")
		GameState.vibrate(200)
		_add_shake(0.8)
	if mode == GameState.Mode.CLASSIC:
		b.respawn_timer = RESPAWN_TIME
		b.set_points(b.points / 2)
		if _me(b):
			hud.notice(tr("EATEN_RESPAWN"), RESPAWN_TIME)
	elif _me(b):
		hud.notice(tr("ELIMINATED"), 3.0)


func _respawn(h: Hole) -> void:
	for attempt in 12:
		var p := Vector3(randf_range(-bound, bound) * 0.8, 0, randf_range(-bound, bound) * 0.8)
		var safe := true
		for o in holes:
			if o != h and o.alive and o.position.distance_to(p) < o.radius + 20.0:
				safe = false
				break
		if safe or attempt == 11:
			h.position = p
			break
	h.snap_radius()
	h.reset_physics_interpolation()
	h.set_alive(true)


func _zone_step(delta: float) -> void:
	var t := 1.0 - clampf(time_left / GameState.match_time(), 0.0, 1.0)
	zone_radius = lerpf(zone_start, 18.0, clampf(t / 0.8, 0.0, 1.0))
	for h in holes:
		if not h.alive:
			continue
		if Vector2(h.position.x, h.position.z).length() > zone_radius:
			h.out_of_zone += delta
			if h == player and int(h.out_of_zone * 2.0) != int((h.out_of_zone - delta) * 2.0):
				hud.notice(tr("ZONE_WARNING"), 0.6)
			if h.out_of_zone > ZONE_OUT_LIMIT:
				h.set_alive(false)
				if h == player:
					hud.notice(tr("ELIMINATED"), 3.0)
					Sfx.play("eaten")
		else:
			h.out_of_zone = 0.0


# --- Queries used by bots --------------------------------------------------

func clamp_to_play_area(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -bound, bound)
	p.z = clampf(p.z, -bound, bound)
	if mode == GameState.Mode.BATTLE:
		var flat := Vector2(p.x, p.z)
		var lim := maxf(zone_radius - 6.0, 4.0)
		if flat.length() > lim:
			flat = flat.normalized() * lim
			p = Vector3(flat.x, 0, flat.y)
	return p


func find_threat(me: Hole, reach: float) -> Hole:
	if mode == GameState.Mode.SOLO:
		return null
	if me.has_effect(Powerup.Kind.SHIELD):
		return null
	var best: Hole = null
	var best_d := reach
	for o in holes:
		if o == me or not o.alive or o.radius <= me.radius * HoleRules.EAT_HOLE_RATIO:
			continue
		var d := o.position.distance_to(me.position) - o.radius
		if d < best_d:
			best_d = d
			best = o
	return best


func find_prey(me: Hole, reach: float) -> Hole:
	if mode == GameState.Mode.SOLO:
		return null
	var best: Hole = null
	var best_d := reach
	for o in holes:
		if o == me or not o.alive or me.radius <= o.radius * HoleRules.EAT_HOLE_RATIO \
				or o.has_effect(Powerup.Kind.SHIELD):
			continue
		var d := o.position.distance_to(me.position)
		if d < best_d:
			best_d = d
			best = o
	return best


## Position of the best-value food that fits, or null.
func find_food(me: Hole, reach: float) -> Variant:
	reach = minf(reach, 45.0)
	var best: Variant = null
	var best_score := 0.0
	for p in powerups:
		var pd := Vector2(p.position.x - me.position.x, p.position.z - me.position.z).length()
		if pd < reach and not me.has_effect(p.kind):
			var ps := 80.0 / (pd + 4.0) * (1.3 if p.kind == Powerup.Kind.SHIELD else 1.0)
			if ps > best_score:
				best_score = ps
				best = Vector3(p.position.x, 0, p.position.z)
	for bucket in _cells_around(me.position, reach):
		for e: Edible in bucket:
			if e.falling_into != null or not HoleRules.fits(e.fit_size, me.radius):
				continue
			var d := e.position.distance_to(me.position)
			if d > reach:
				continue
			var score := float(e.points) / (d + 4.0)
			if score > best_score:
				best_score = score
				best = Vector3(e.position.x, 0, e.position.z)
	return best


# --- Rendering / HUD -------------------------------------------------------

func _update_ground() -> void:
	var pos := PackedVector4Array()
	var cols := PackedVector4Array()
	for h in holes:
		if not h.alive or pos.size() >= MAX_HOLES:
			continue
		pos.append(Vector4(h.position.x, h.position.z, h.radius, 0))
		var c := h.color.srgb_to_linear()
		cols.append(Vector4(c.r, c.g, c.b, h.pattern))
	pos.resize(MAX_HOLES)
	cols.resize(MAX_HOLES)
	ground_mat.set_shader_parameter("holes", pos)
	ground_mat.set_shader_parameter("hole_colors", cols)
	ground_mat.set_shader_parameter("hole_count", _alive_count())
	if mode == GameState.Mode.BATTLE:
		ground_mat.set_shader_parameter("zone", Vector3(0, 0, zone_radius))


func _alive_count() -> int:
	var n := 0
	for h in holes:
		if h.alive:
			n += 1
	return mini(n, MAX_HOLES)


func _ranking() -> Array[Hole]:
	var r: Array[Hole] = holes.duplicate()
	r.sort_custom(func(a: Hole, b: Hole): return a.points > b.points)
	return r


func _on_player_level(level: int) -> void:
	if attract:
		return
	hud.notice(tr("LEVEL_UP") % level, 1.0)
	Sfx.play("level", 1.0, 0.0, 300)


func _update_hud() -> void:
	if hud == null:
		return
	hud.set_time(time_left)
	hud.set_level(player.level, HoleRules.level_progress(player.points))
	hud.set_effects(player.effects)
	hud.set_combo(player.combo)
	match mode:
		GameState.Mode.SOLO:
			hud.set_info(tr("CITY_EATEN") % _percent())
		GameState.Mode.BATTLE:
			hud.set_info(tr("ALIVE") % _alive_count())
	if mode == GameState.Mode.SOLO:
		hud.set_board([])
		return
	var rows := []
	var rank := _ranking()
	for i in rank.size():
		var h := rank[i]
		if i < 4 or h == player:
			rows.append({"place": i + 1, "name": h.hole_name, "points": h.points, "color": h.color, "me": h == player})
	hud.set_board(rows)


func _percent() -> float:
	return 100.0 * eaten_count / maxf(total_count, 1)


# --- End of match ----------------------------------------------------------

func _check_end() -> void:
	if attract:
		return
	var over := time_left <= 0.0
	if mode == GameState.Mode.BATTLE:
		over = over or not player.alive or _alive_count() <= 1
	if over:
		_finish()


func _finish() -> void:
	running = false
	for h in holes:
		h.move_dir = Vector2.ZERO
	_update_hud()
	# Smoke runs must not touch the player's records.
	var save := not GameState.autoplay
	var stats_before := Skins.current_stats()
	var key := GameState.record_key()
	var lines := []
	var title := tr("TIME_UP")
	var record := false
	match mode:
		GameState.Mode.SOLO:
			var pct := snappedf(_percent(), 0.1)
			if GameState.daily:
				title = tr("DAILY_DONE")
			lines.append(tr("CITY_EATEN") % pct)
			lines.append(tr("POINTS") % player.points)
			if save:
				record = Save.submit_record(key, pct)
				if GameState.daily:
					Save.submit_record("solo", pct)
		GameState.Mode.CLASSIC:
			var place := _ranking().find(player) + 1
			title = tr("YOU_WIN") if place == 1 else tr("PLACE") % place
			lines.append(tr("POINTS") % player.points)
			if save:
				record = Save.submit_record(key, player.points)
		GameState.Mode.BATTLE:
			var place := 1
			if player.alive:
				for h in holes:
					if h != player and h.alive and h.points > player.points:
						place += 1
			else:
				place = _alive_count() + 1
			title = tr("YOU_WIN") if place == 1 else tr("PLACE") % place
			lines.append(tr("POINTS") % player.points)
			if save:
				if place == 1:
					Save.add_counter("battle_wins")
				record = Save.submit_record(key, player.points)
	if record:
		lines.append(tr("NEW_RECORD"))
	lines.append(tr("EATEN_COUNT") % eaten_count)
	if save:
		Save.add_counter("total_eaten", eaten_count)
		var before := Skins.unlocked_set(stats_before)
		for i in Skins.unlocked_set(Skins.current_stats()):
			if not before.has(i):
				lines.append(tr("NEW_SKIN") % tr(Skins.get_skin(i).name))
	if not GameState.daily:
		lines.append(tr("MAP_SEED") % GameState.map_seed)
	Sfx.play("end")
	hud.show_results(title, lines)
	var all_powerups := 0
	for h in holes:
		all_powerups += h.powerups_taken
	print("MATCH_END mode=%s points=%d eaten=%d/%d level=%d powerups=%d/%d movers_left=%d flung=%d best_item=%d fractured=%d debris_peak=%d frame_ms=%.2f" % [key,
		player.points, eaten_count, total_count, player.level, player.powerups_taken, all_powerups, movers.size(),
		_flung.size(), _best_item, demolition.fractured, demolition.debris_peak, _frame_ms_sum / maxf(_frames, 1)])
	if GameState.autoplay:
		get_tree().quit()
