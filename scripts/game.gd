extends Node3D
## Match controller: builds the world, runs the swallow physics,
## holes vs holes, bots and the three game modes.

const GROUND_LAYER := 1
const EDIBLE_LAYER := 2
const WELL_LAYER := 4
const CELL := 8.0
const MAX_HOLES := 16
const RESPAWN_TIME := 3.0
const ZONE_OUT_LIMIT := 4.0
const CAM_PITCH := 65.0
const GROUND_SHADER := preload("res://scripts/world/ground.gdshader")

const HOLE_COLORS := [Color("4cc9f0"), Color("f72585"), Color("ffd60a"), Color("80ed99"),
	Color("ff8500"), Color("b388eb"), Color("ff595e"), Color("f8f9fa"), Color("06d6a0")]
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


func _ready() -> void:
	mode = GameState.mode
	time_left = GameState.match_time()
	_build_environment()
	var blocks := GameState.city_blocks()
	var half := CityGen.map_extent(blocks) / 2.0
	bound = half - 2.0
	_build_ground(half)
	_spawn_city(GameState.resolve_seed(), blocks)
	_spawn_holes()

	hud = Hud.new()
	add_child(hud)
	hud.play_again.connect(func(): get_tree().reload_current_scene())
	hud.to_menu.connect(_go_menu)
	if mode == GameState.Mode.BATTLE:
		zone_start = half * 1.45
		zone_radius = zone_start
	running = true
	_update_hud()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_take_screenshot(arg.trim_prefix("--screenshot="))


## Dev helper: "-- --autoplay --screenshot=/path/shot.png" saves a frame after 8 s.
func _take_screenshot(path: String) -> void:
	await get_tree().create_timer(8.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_menu()


func _go_menu() -> void:
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
	sun.light_energy = 0.95
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
	if GameState.map_theme == GameState.MapTheme.SUBURB:
		ground_mat.set_shader_parameter("grass_color", Color("7fb069"))
		ground_mat.set_shader_parameter("road_color", Color("5c5f66"))
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = ground_mat
	add_child(mi)


func _spawn_city(seed_value: int, blocks: int) -> void:
	var factory := EdibleFactory.new()
	for spec in CityGen.generate(seed_value, blocks, GameState.map_theme):
		var e := factory.build(spec)
		world.add_child(e)
		_grid_add(e)
		total_points += e.points
		total_count += 1


func _spawn_holes() -> void:
	var count := 1 if mode == GameState.Mode.SOLO else 1 + GameState.bot_count
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	for i in count:
		var h := Hole.new()
		var is_player := i == 0
		h.setup(tr("YOU") if is_player else names[i % names.size()], HOLE_COLORS[i % HOLE_COLORS.size()], is_player)
		add_child(h)
		h.position = _spawn_point(i, count)
		if is_player:
			player = h
			h.leveled_up.connect(_on_player_level)
			if GameState.autoplay:
				_player_bot = BotAI.new(h, self, 0.8)
		else:
			h.controller = BotAI.new(h, self, randf_range(0.45, 0.95))
		holes.append(h)


func _spawn_point(i: int, count: int) -> Vector3:
	if count == 1:
		return Vector3(0, 0, CityGen.ROAD / 2.0 - CityGen.map_extent(GameState.city_blocks()) / 2.0 + CityGen.PITCH * 2)
	# Spread around a circle, snapped to the nearest road centre line.
	var a := TAU * i / count + randf() * 0.3
	var r := bound * 0.6
	var p := Vector3(cos(a) * r, 0, sin(a) * r)
	var half := CityGen.map_extent(GameState.city_blocks()) / 2.0
	var road_z: float = round((p.z + half - CityGen.ROAD / 2.0) / CityGen.PITCH) * CityGen.PITCH - half + CityGen.ROAD / 2.0
	p.z = road_z
	return p


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

	_swallow_step()
	_falling_step()
	if mode != GameState.Mode.SOLO:
		_holes_step()
	if mode == GameState.Mode.BATTLE:
		_zone_step(delta)

	_rebin_timer -= delta
	if _rebin_timer <= 0.0:
		_rebin_timer = 0.5
		_rebin()

	_update_ground()
	_check_end()


func _process(delta: float) -> void:
	if player == null:
		return
	var d := 24.0 + player.radius * 5.5
	var pitch := deg_to_rad(CAM_PITCH)
	var focus := player.get_global_transform_interpolated().origin
	var target := focus + Vector3(0, sin(pitch) * d, cos(pitch) * d)
	if camera.position == Vector3.ZERO:
		camera.position = target
	else:
		camera.position = camera.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	sun.directional_shadow_max_distance = d * 1.6
	_hud_timer -= delta
	if _hud_timer <= 0.0 and running:
		_hud_timer = 0.2
		_update_hud()


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
		for bucket in _cells_around(hp, r + 11.0):
			for e: Edible in bucket:
				if e.falling_into != null:
					continue
				var dx := e.position.x - hp.x
				var dz := e.position.z - hp.z
				var d := sqrt(dx * dx + dz * dz)
				if d > r + e.extent * 0.6 + 0.5:
					continue
				if e.freeze:
					e.freeze = false
					awake[e] = true
				e.sleeping = false
				if not HoleRules.fits(e.extent, r):
					continue
				if d < r * 0.92:
					_start_fall(e, h)
				else:
					# Object hangs over the edge: pull it in.
					var pull := Vector3(-dx, 0, -dz) / maxf(d, 0.01)
					e.apply_central_force(pull * e.mass * 14.0)


func _start_fall(e: Edible, h: Hole) -> void:
	e.falling_into = h
	e.collision_mask = EDIBLE_LAYER | WELL_LAYER
	e.sleeping = false
	e.apply_central_impulse(Vector3.DOWN * e.mass * 0.5)
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
		# Still on the surface but the hole moved away: put it back on the ground.
		var bottom := e.position.y - e.height * 0.5
		if bottom > -0.15:
			var gone := not h.alive
			if not gone:
				var d := Vector2(e.position.x - h.position.x, e.position.z - h.position.z).length()
				gone = d > h.radius + 0.1
			if gone:
				e.falling_into = null
				e.collision_mask = GROUND_LAYER | EDIBLE_LAYER
				falling.remove_at(i)


func _eat(e: Edible, h: Hole) -> void:
	_grid_remove(e)
	awake.erase(e)
	if h and h.alive:
		h.add_points(e.points)
		if h == player:
			eaten_count += 1
			if _vibrate_cooldown <= 0.0 and e.points >= 5:
				_vibrate_cooldown = 0.25
				Input.vibrate_handheld(clampi(10 + e.points / 20, 10, 60))
	e.queue_free()


func _rebin() -> void:
	for e in awake.keys():
		if not is_instance_valid(e):
			awake.erase(e)
			continue
		if e.position.y < -60.0:
			_grid_remove(e)
			awake.erase(e)
			e.queue_free()
			continue
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
			if HoleRules.can_eat_hole(a.radius, b.radius, d):
				_eat_hole(a, b)


func _eat_hole(a: Hole, b: Hole) -> void:
	a.add_points(maxi(5, b.points / 2))
	b.set_alive(false)
	if a == player:
		hud.notice(tr("ATE_HOLE") % b.hole_name, 1.5)
		Input.vibrate_handheld(80)
	if mode == GameState.Mode.CLASSIC:
		b.respawn_timer = RESPAWN_TIME
		b.set_points(b.points / 2)
		if b == player:
			hud.notice(tr("EATEN_RESPAWN"), RESPAWN_TIME)
	elif b == player:
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
		if o == me or not o.alive or me.radius <= o.radius * HoleRules.EAT_HOLE_RATIO:
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
	for bucket in _cells_around(me.position, reach):
		for e: Edible in bucket:
			if e.falling_into != null or not HoleRules.fits(e.extent, me.radius):
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
		cols.append(Vector4(c.r, c.g, c.b, 1))
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
	hud.notice(tr("LEVEL_UP") % level, 1.0)


func _update_hud() -> void:
	hud.set_time(time_left)
	hud.set_level(player.level, HoleRules.level_progress(player.points))
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
	var key := GameState.mode_key()
	var lines := []
	var title := tr("TIME_UP")
	match mode:
		GameState.Mode.SOLO:
			var pct := _percent()
			lines.append(tr("CITY_EATEN") % pct)
			lines.append(tr("POINTS") % player.points)
			if Save.submit_record(key, snappedf(pct, 0.1)):
				lines.append(tr("NEW_RECORD"))
		GameState.Mode.CLASSIC:
			var place := _ranking().find(player) + 1
			title = tr("YOU_WIN") if place == 1 else tr("PLACE") % place
			lines.append(tr("POINTS") % player.points)
			if Save.submit_record(key, player.points):
				lines.append(tr("NEW_RECORD"))
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
			if place == 1:
				Save.add_counter("battle_wins")
			if Save.submit_record(key, player.points):
				lines.append(tr("NEW_RECORD"))
	lines.append(tr("MAP_SEED") % GameState.map_seed)
	hud.show_results(title, lines)
	print("MATCH_END mode=%s points=%d eaten=%d/%d level=%d" % [key, player.points, eaten_count, total_count, player.level])
	if GameState.autoplay:
		get_tree().quit()
