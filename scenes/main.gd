# Main.gd
extends Node2D

# Game state
var home_team
var away_team
var ball

# Visual nodes
var unit_visuals: Dictionary = {}
var ball_visual: ColorRect

# Colors
const COLOR_FIELD = Color(0.2, 0.5, 0.2)
const COLOR_ZONE_LINE = Color(1, 1, 1, 0.3)
const COLOR_CENTER_CIRCLE = Color(1, 1, 1, 0.5)
const COLOR_GOAL = Color(1, 1, 1, 0.2)
const COLOR_HOME_TEAM = Color(0.2, 0.4, 0.9)
const COLOR_AWAY_TEAM = Color(0.9, 0.3, 0.2)
const COLOR_BALL = Color(0.95, 0.6, 0.2)
const COLOR_HOME_BALL = Color(0.4, 0.6, 1.0)
const COLOR_AWAY_BALL = Color(1.0, 0.5, 0.4)

const UNIT_SIZE = 48
const BALL_SIZE = 24
const CELL_SIZE = 64


func _ready() -> void:
	get_window().title = "AFL Nines"
	
	_create_game_entities()
	GameManager.setup_game(home_team, away_team, ball)
	
	_draw_field()
	_create_unit_visuals()
	_create_ball_visual()
	
	GameManager.ready_simulation()
	_update_all_visuals()
	
	EventBus.tick_completed.connect(_on_tick_completed)
	EventBus.simulation_reset.connect(_on_simulation_reset)
	
	Debug.log_section("CONTROLS")
	Debug.log_info("Main", "SPACE = Step | P = Play/Pause | R = Reset | 1/2/3 = Speed")


func _create_game_entities() -> void:
	home_team = Team.new()
	home_team.initialize(Enums.TeamID.HOME, "Tigers")
	home_team.create_default_players()
	
	away_team = Team.new()
	away_team.initialize(Enums.TeamID.AWAY, "Lions")
	away_team.create_default_players()
	
	ball = Ball.new()
	ball.initialize(Vector2i(Constants.FIELD_CENTER_X, Constants.FIELD_CENTER_Y))


func _draw_field() -> void:
	# Field background
	var field_bg = ColorRect.new()
	field_bg.color = COLOR_FIELD
	field_bg.size = Vector2(Constants.FIELD_PIXEL_WIDTH, Constants.FIELD_PIXEL_HEIGHT)
	field_bg.z_index = -10
	add_child(field_bg)
	
	# Zone lines
	_draw_zone_line(Constants.ZONE_DEFENSIVE_END)
	_draw_zone_line(Constants.ZONE_MIDFIELD_END)
	
	# Center square
	var center = ColorRect.new()
	var circle_size = CELL_SIZE * 3
	center.color = COLOR_CENTER_CIRCLE
	center.size = Vector2(circle_size, circle_size)
	center.position = Vector2(
		Constants.FIELD_CENTER_X * CELL_SIZE + CELL_SIZE/2 - circle_size/2,
		Constants.FIELD_CENTER_Y * CELL_SIZE + CELL_SIZE/2 - circle_size/2
	)
	center.z_index = -5
	add_child(center)
	
	# Goal zones
	var left_goal = ColorRect.new()
	left_goal.color = COLOR_GOAL
	left_goal.size = Vector2(CELL_SIZE, (Constants.GOAL_Y_MAX - Constants.GOAL_Y_MIN + 1) * CELL_SIZE)
	left_goal.position = Vector2(0, Constants.GOAL_Y_MIN * CELL_SIZE)
	left_goal.z_index = -5
	add_child(left_goal)
	
	var right_goal = ColorRect.new()
	right_goal.color = COLOR_GOAL
	right_goal.size = Vector2(CELL_SIZE, (Constants.GOAL_Y_MAX - Constants.GOAL_Y_MIN + 1) * CELL_SIZE)
	right_goal.position = Vector2((Constants.GRID_WIDTH - 1) * CELL_SIZE, Constants.GOAL_Y_MIN * CELL_SIZE)
	right_goal.z_index = -5
	add_child(right_goal)


func _draw_zone_line(x_cell: int) -> void:
	var line = ColorRect.new()
	line.color = COLOR_ZONE_LINE
	line.size = Vector2(2, Constants.FIELD_PIXEL_HEIGHT)
	line.position = Vector2((x_cell + 1) * CELL_SIZE - 1, 0)
	line.z_index = -5
	add_child(line)


func _create_unit_visuals() -> void:
	for unit in home_team.units:
		_create_unit_visual(unit, COLOR_HOME_TEAM)
	for unit in away_team.units:
		_create_unit_visual(unit, COLOR_AWAY_TEAM)


func _create_unit_visual(unit: Unit, base_color: Color) -> void:
	var visual = ColorRect.new()
	visual.size = Vector2(UNIT_SIZE, UNIT_SIZE)
	visual.color = base_color
	visual.z_index = 1
	
	var label = Label.new()
	label.text = _get_position_abbrev(unit.position)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(UNIT_SIZE, UNIT_SIZE)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	visual.add_child(label)
	
	add_child(visual)
	unit_visuals[unit.id] = visual


func _get_position_abbrev(pos: Enums.Position) -> String:
	match pos:
		Enums.Position.FULL_BACK: return "FB"
		Enums.Position.CENTRE_BACK: return "CB"
		Enums.Position.BACK_FLANKER: return "BF"
		Enums.Position.CENTRE: return "C"
		Enums.Position.WING_LEFT: return "WL"
		Enums.Position.WING_RIGHT: return "WR"
		Enums.Position.FULL_FORWARD: return "FF"
		Enums.Position.CENTRE_FORWARD: return "CF"
		Enums.Position.FORWARD_FLANKER: return "FLK"
	return "?"


func _create_ball_visual() -> void:
	ball_visual = ColorRect.new()
	ball_visual.size = Vector2(BALL_SIZE, BALL_SIZE)
	ball_visual.color = COLOR_BALL
	ball_visual.z_index = 2
	add_child(ball_visual)


func _update_all_visuals() -> void:
	for unit in home_team.units:
		_update_unit_visual(unit, COLOR_HOME_TEAM, COLOR_HOME_BALL)
	for unit in away_team.units:
		_update_unit_visual(unit, COLOR_AWAY_TEAM, COLOR_AWAY_BALL)
	_update_ball_visual()


func _update_unit_visual(unit: Unit, base_color: Color, ball_color: Color) -> void:
	var visual = unit_visuals.get(unit.id)
	if visual == null:
		return
	
	var pixel_pos = Constants.grid_to_pixel(unit.grid_position)
	visual.position = Vector2(
		pixel_pos.x + (CELL_SIZE - UNIT_SIZE) / 2,
		pixel_pos.y + (CELL_SIZE - UNIT_SIZE) / 2
	)
	visual.color = ball_color if unit.has_ball else base_color


func _update_ball_visual() -> void:
	var pixel_pos = ball.get_pixel_position()
	ball_visual.position = Vector2(
		pixel_pos.x - BALL_SIZE / 2,
		pixel_pos.y - BALL_SIZE / 2
	)
	ball_visual.visible = not ball.is_held()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if GameManager.state == Enums.SimState.STOPPED:
					GameManager.ready_simulation()
				GameManager.step_simulation()
			KEY_P:
				if GameManager.state == Enums.SimState.RUNNING:
					GameManager.pause_simulation()
				elif GameManager.state == Enums.SimState.STOPPED:
					GameManager.ready_simulation()
					GameManager.start_simulation()
					MatchDirector.start_match()
				else:
					GameManager.start_simulation()
					if MatchDirector.match_state == Enums.MatchState.PRE_MATCH:
						MatchDirector.start_match()
			KEY_R:
				GameManager.reset_simulation()
				MatchDirector.reset()
				GameManager.ready_simulation()
				_update_all_visuals()
			KEY_1:
				GameManager.set_speed(1.0)
			KEY_2:
				GameManager.set_speed(2.0)
			KEY_3:
				GameManager.set_speed(4.0)


func _on_tick_completed(_tick: int) -> void:
	_update_all_visuals()


func _on_simulation_reset() -> void:
	_update_all_visuals()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ui_text = "Tick: %d | %s | Q%d %s" % [
		GameManager.current_tick,
		Enums.SimState.keys()[GameManager.state],
		MatchDirector.current_quarter,
		MatchDirector.get_time_string()
	]
	var score_text = "%s %s vs %s %s" % [
		home_team.team_name,
		home_team.get_score_string(),
		away_team.get_score_string(),
		away_team.team_name
	]
	
	draw_rect(Rect2(10, 10, 400, 50), Color(0, 0, 0, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), ui_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(20, 48), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
