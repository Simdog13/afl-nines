# GameManager.gd
# ============================================
# PURPOSE: The simulation engine - processes game ticks and manages sim state.
# PRINCIPLE: This is the HEART of the simulation. It controls WHEN things happen.
#            MatchDirector controls match flow (quarters, scoring).
#            GameManager controls simulation flow (ticks, pause, step).
# ACCESS: Global singleton via `GameManager.function_name()`
# ============================================
# RESPONSIBILITIES:
#   - Manage simulation state (STOPPED, READY, RUNNING, PAUSED)
#   - Process simulation ticks at the correct rate
#   - Provide dev mode controls (step, back, reset)
#   - Maintain tick history for rewind functionality
#   - Coordinate with MatchDirector for match flow
# ============================================
# STATE FLOW:
#   STOPPED → [ready()] → READY → [start()] → RUNNING
#                                → [step()]  → PAUSED
#   RUNNING → [pause()] → PAUSED → [start()] → RUNNING (resume)
#                                → [step()]  → PAUSED (advance 1)
#                                → [back()]  → PAUSED (rewind 1)
#   Any → [reset()] → STOPPED
# ============================================

extends Node


# ===========================================
# SIMULATION STATE
# ===========================================

## Current state of the simulation
var state: Enums.SimState = Enums.SimState.STOPPED:
	set(value):
		if state != value:
			var old_state = state
			state = value
			EventBus.simulation_state_changed.emit(state, old_state)
			Debug.log_state_change("GameManager", "SimState", 
				Enums.SimState.keys()[old_state], 
				Enums.SimState.keys()[state])

## Current tick number (increments each simulation step)
var current_tick: int = 0

## Speed multiplier (1.0 = normal, 2.0 = double speed, etc.)
var speed_multiplier: float = 1.0


# ===========================================
# TIMING
# ===========================================

## Accumulator for tick timing
var _tick_accumulator: float = 0.0

## How many real seconds between ticks (adjusted for speed)
var _seconds_per_tick: float:
	get:
		return Constants.SECONDS_PER_TICK / speed_multiplier


# ===========================================
# TICK HISTORY (for rewind)
# ===========================================

## Array of saved game states, one per tick
## Each entry is a Dictionary containing the complete game state
var _tick_history: Array[Dictionary] = []

## Maximum number of ticks to keep in history
const MAX_HISTORY_SIZE: int = 100


# ===========================================
# GAME DATA REFERENCES
# ===========================================
# These are set by the scene that sets up the game

## Reference to home team
var home_team: Team = null

## Reference to away team
var away_team: Team = null

## Reference to the ball
var ball: Ball = null


# ===========================================
# INITIALIZATION
# ===========================================


func _ready() -> void:
	Debug.log_info("GameManager", "Simulation engine initialized")
	Debug.log_info("GameManager", "Tick rate: %.1f ticks/sec (%.2fs per tick)" % [
		Constants.TICKS_PER_SECOND,
		Constants.SECONDS_PER_TICK
	])
	
	# Connect to UI control events
	EventBus.ui_control_requested.connect(_on_ui_control_requested)
	EventBus.ui_speed_change_requested.connect(_on_ui_speed_change_requested)


# ===========================================
# FRAME PROCESSING
# ===========================================


func _process(delta: float) -> void:
	# Only process ticks when running
	if state != Enums.SimState.RUNNING:
		return
	
	# Accumulate time
	_tick_accumulator += delta
	
	# Process ticks when enough time has passed
	while _tick_accumulator >= _seconds_per_tick:
		_tick_accumulator -= _seconds_per_tick
		_process_tick()


# ===========================================
# TICK PROCESSING
# ===========================================


## Process a single simulation tick
func _process_tick() -> void:
	# Save state BEFORE processing (for rewind)
	_save_tick_state()
	
	# Increment tick counter
	current_tick += 1
	Debug.set_current_tick(current_tick)
	
	# Emit tick started event
	EventBus.tick_started.emit(current_tick)
	
	# --- CORE TICK LOGIC ---
	
	# 1. Process ball physics (flight, bouncing)
	_process_ball()
	
	# 2. Process each unit's turn
	_process_units()
	
	# 3. Check for scoring
	_check_scoring()
	
	# 4. Update match time (delegated to MatchDirector)
	if MatchDirector:
		MatchDirector.process_tick()
	
	# --- END CORE TICK LOGIC ---
	
	# Emit tick completed event
	EventBus.tick_completed.emit(current_tick)
	
	# Periodic logging (every 10 ticks)
	if current_tick % 10 == 0:
		Debug.log_debug("GameManager", "Tick %d complete" % current_tick)


## Process ball movement and state
func _process_ball() -> void:
	if ball == null:
		return

	# If ball is in flight, advance it
	if ball.is_in_flight():
		var still_flying = ball.process_flight_tick()
		if not still_flying:
			# Ball has landed - it's now loose on ground
			ball.make_loose_ground(ball.grid_position)

			# Check if any unit is on this cell - they automatically pick it up
			_try_auto_pickup_at_landing()


## Process all units
func _process_units() -> void:
	# Process home team
	if home_team:
		for unit in home_team.units:
			_process_unit(unit)
	
	# Process away team
	if away_team:
		for unit in away_team.units:
			_process_unit(unit)


## Process a single unit's turn
func _process_unit(unit: Unit) -> void:
	# Skip invalid units
	if unit == null:
		return

	match unit.state:
		Enums.UnitState.IDLE:
			_process_idle_unit(unit)

		Enums.UnitState.MOVING:
			# If unit was moving, check if arrived
			if unit.grid_position == unit.target_position:
				unit.arrive_at_target()
				# Check if we arrived at the ball - pick it up
				_try_pickup_ball(unit)


## Process AI for an idle unit
func _process_idle_unit(unit: Unit) -> void:
	# Recover stamina when idle
	unit.recover_stamina(Constants.STAMINA_RECOVERY_RATE)

	# If unit has the ball, try to kick it forward
	if unit.has_ball:
		_ai_kick_ball(unit)
		return

	# If ball is loose on the ground, try to get it
	if ball and ball.state == Enums.BallState.LOOSE_GROUND:
		_ai_chase_ball(unit)


## AI: Chase the loose ball
func _ai_chase_ball(unit: Unit) -> void:
	var ball_pos = ball.grid_position
	var unit_pos = unit.grid_position

	# Calculate distance to ball
	var distance = Constants.grid_distance(unit_pos, ball_pos)

	# Only chase if ball is reasonably close (within 8 cells)
	if distance > 8:
		return

	# Check if ball is in our zone (we can't leave our zone)
	var ball_zone = Enums.get_zone_at_x(ball_pos.x, unit.team)
	if ball_zone != unit.zone:
		# Ball is in another zone, don't chase
		return

	# Move toward the ball (one cell at a time)
	var next_pos = _get_next_step_toward(unit_pos, ball_pos, unit.zone, unit.team)

	if next_pos != unit_pos:
		GridManager.move_unit(unit, next_pos)


## AI: Kick the ball forward toward opponent's goal
func _ai_kick_ball(unit: Unit) -> void:
	# Determine which direction to kick based on team
	var target_x = Constants.GOAL_RIGHT_X if unit.team == Enums.TeamID.HOME else Constants.GOAL_LEFT_X
	var target_y = Constants.FIELD_CENTER_Y  # Aim for center

	# Kick toward goal, but not too far (use half max distance)
	var max_distance = Constants.KICK_DISTANCE_MAX / 2
	var current_pos = unit.grid_position

	# Calculate kick target
	var direction_x = 1 if unit.team == Enums.TeamID.HOME else -1
	var kick_target = Vector2i(
		current_pos.x + (direction_x * max_distance),
		target_y
	)

	# Clamp to field bounds
	kick_target.x = clampi(kick_target.x, 0, Constants.GRID_WIDTH - 1)
	kick_target.y = clampi(kick_target.y, 0, Constants.GRID_HEIGHT - 1)

	# Execute the kick
	ball.start_flight(unit, current_pos, kick_target, Enums.Action.KICK)
	unit.has_ball = false


## Get the next step toward a target position (simple pathfinding)
func _get_next_step_toward(from: Vector2i, to: Vector2i, zone: Enums.Zone, team: Enums.TeamID) -> Vector2i:
	var dx = sign(to.x - from.x)
	var dy = sign(to.y - from.y)

	# Try moving horizontally first (more important in AFL)
	var next_pos = Vector2i(from.x + dx, from.y)

	# Check if horizontal move is valid and in zone
	if Constants.is_valid_grid_pos(next_pos) and Enums.get_zone_at_x(next_pos.x, team) == zone:
		if GridManager.is_cell_free(next_pos):
			return next_pos

	# Try moving vertically
	next_pos = Vector2i(from.x, from.y + dy)

	# Check if vertical move is valid and in zone
	if Constants.is_valid_grid_pos(next_pos) and Enums.get_zone_at_x(next_pos.x, team) == zone:
		if GridManager.is_cell_free(next_pos):
			return next_pos

	# Can't move, stay in place
	return from


## Try to pick up the ball if unit is on same cell
func _try_pickup_ball(unit: Unit) -> void:
	if ball == null or unit == null:
		return

	# Check if unit is on the same cell as the ball
	if unit.grid_position == ball.grid_position and ball.state == Enums.BallState.LOOSE_GROUND:
		ball.give_to_unit(unit, Enums.PossessionQuality.CLEAN)
		Debug.log_info("GameManager", "%s picked up the ball!" % unit.player_name)


## Try to automatically pick up ball when it lands (if unit is already there)
func _try_auto_pickup_at_landing() -> void:
	if ball == null:
		return

	var ball_pos = ball.grid_position

	# Check all units to see if any are on the landing spot
	for unit in home_team.units:
		if unit.grid_position == ball_pos:
			ball.give_to_unit(unit, Enums.PossessionQuality.CLEAN)
			Debug.log_info("GameManager", "%s caught the ball!" % unit.player_name)
			return

	for unit in away_team.units:
		if unit.grid_position == ball_pos:
			ball.give_to_unit(unit, Enums.PossessionQuality.CLEAN)
			Debug.log_info("GameManager", "%s caught the ball!" % unit.player_name)
			return


## Check if a score should be registered
func _check_scoring() -> void:
	if ball == null:
		return
	
	# Only check if ball just landed or is held
	if ball.state == Enums.BallState.LOOSE_GROUND or ball.state == Enums.BallState.HELD:
		var score_check = ball.check_scoring_zone()
		if score_check.is_score:
			_register_score(score_check.team, score_check.score_type)


## Register a score
func _register_score(team: Enums.TeamID, score_type: Enums.ScoreType) -> void:
	var points = 6 if score_type == Enums.ScoreType.GOAL else 1
	var scoring_team = home_team if team == Enums.TeamID.HOME else away_team

	# Validate team exists
	if scoring_team == null:
		Debug.log_error("GameManager", "Cannot register score - team is null")
		return

	# Update team score
	if score_type == Enums.ScoreType.GOAL:
		scoring_team.add_goal()
	else:
		scoring_team.add_behind()

	# Emit scoring event
	EventBus.score_registered.emit(team, score_type, points)

	Debug.log_info("GameManager", "%s %s! (%d points)" % [
		scoring_team.team_name,
		"GOAL" if score_type == Enums.ScoreType.GOAL else "Behind",
		points
	])

	# Reset ball to center (MatchDirector will handle the stoppage)
	if ball:
		ball.reset_to_center()
	else:
		Debug.log_warning("GameManager", "Cannot reset ball after score - ball is null")


# ===========================================
# STATE HISTORY (for rewind)
# ===========================================


## Save current state to history
func _save_tick_state() -> void:
	var state_snapshot = _capture_state()
	_tick_history.append(state_snapshot)
	
	# Trim history if too long
	while _tick_history.size() > MAX_HISTORY_SIZE:
		_tick_history.pop_front()


## Capture complete game state as a dictionary
func _capture_state() -> Dictionary:
	var snapshot = {
		"tick": current_tick,
		"ball": _capture_ball_state(),
		"home_team": _capture_team_state(home_team),
		"away_team": _capture_team_state(away_team),
	}
	return snapshot


## Capture ball state
func _capture_ball_state() -> Dictionary:
	if ball == null:
		return {}
	return {
		"grid_position": {"x": ball.grid_position.x, "y": ball.grid_position.y},
		"state": ball.state,
		"possessing_unit_id": ball.possessing_unit.id if ball.possessing_unit else -1,
		"last_touch_team": ball.last_touch_team,
	}


## Capture team state
func _capture_team_state(team) -> Dictionary:
	if team == null:
		return {}
	
	var units_state = []
	for unit in team.units:
		units_state.append({
			"id": unit.id,
			"grid_position": {"x": unit.grid_position.x, "y": unit.grid_position.y},
			"current_stamina": unit.current_stamina,
			"state": unit.state,
			"has_ball": unit.has_ball,
		})
	
	return {
		"goals": team.goals,
		"behinds": team.behinds,
		"units": units_state,
	}


## Restore game state from a snapshot
func _restore_state(snapshot: Dictionary) -> void:
	current_tick = snapshot.get("tick", 0)
	Debug.set_current_tick(current_tick)
	
	_restore_team_state(home_team, snapshot.get("home_team", {}))
	_restore_team_state(away_team, snapshot.get("away_team", {}))
	_restore_ball_state(snapshot.get("ball", {}))
	
	Debug.log_info("GameManager", "Restored state to tick %d" % current_tick)


## Restore team state
func _restore_team_state(team, state_data: Dictionary) -> void:
	if team == null or state_data.is_empty():
		return
	
	team.goals = state_data.get("goals", 0)
	team.behinds = state_data.get("behinds", 0)
	
	var units_state = state_data.get("units", [])
	for unit_state in units_state:
		var unit_id = unit_state.get("id", -1)
		# Find unit by ID
		for unit in team.units:
			if unit.id == unit_id:
				var pos = unit_state.get("grid_position", {})
				unit.grid_position = Vector2i(pos.get("x", 0), pos.get("y", 0))
				unit.current_stamina = unit_state.get("current_stamina", 50)
				unit.state = unit_state.get("state", Enums.UnitState.IDLE)
				unit.has_ball = unit_state.get("has_ball", false)
				break


## Restore ball state
func _restore_ball_state(state_data: Dictionary) -> void:
	if ball == null or state_data.is_empty():
		return
	
	var pos = state_data.get("grid_position", {})
	ball.grid_position = Vector2i(pos.get("x", 0), pos.get("y", 0))
	ball.state = state_data.get("state", Enums.BallState.WITH_UMPIRE)
	ball.last_touch_team = state_data.get("last_touch_team", Enums.TeamID.NONE)
	
	# Restore possession
	var possessing_id = state_data.get("possessing_unit_id", -1)
	ball.possessing_unit = null
	if possessing_id >= 0:
		# Find the unit with this ID
		for team in [home_team, away_team]:
			if team:
				for unit in team.units:
					if unit.id == possessing_id:
						ball.possessing_unit = unit
						break


# ===========================================
# PUBLIC API - SIMULATION CONTROL
# ===========================================


## Initialize game with teams and ball
func setup_game(p_home_team, p_away_team, p_ball) -> void:
	home_team = p_home_team
	away_team = p_away_team
	ball = p_ball
	
	Debug.log_info("GameManager", "Game setup: %s vs %s" % [
		home_team.team_name if home_team else "???",
		away_team.team_name if away_team else "???"
	])


## Prepare simulation to run (place units, reset state)
func ready_simulation() -> void:
	if state != Enums.SimState.STOPPED:
		Debug.log_warn("GameManager", "Can only ready from STOPPED state")
		return
	
	# Reset tick counter
	current_tick = 0
	_tick_accumulator = 0.0
	_tick_history.clear()
	Debug.set_current_tick(0)
	
	# Place units on the grid
	if home_team:
		home_team.set_starting_positions()
		_register_team_on_grid(home_team)
	
	if away_team:
		away_team.set_starting_positions()
		_register_team_on_grid(away_team)

	# Reset ball to center and make it loose for center bounce
	if ball:
		ball.reset_to_center()
		# Start with ball loose on ground so players can contest it
		ball.make_loose_ground(ball.grid_position)

	state = Enums.SimState.READY
	Debug.log_info("GameManager", "Simulation ready")


## Register all units from a team onto the grid
func _register_team_on_grid(team) -> void:
	for unit in team.units:
		GridManager.place_unit(unit, unit.grid_position)


## Start (or resume) the simulation
func start_simulation() -> void:
	if state == Enums.SimState.STOPPED:
		Debug.log_warn("GameManager", "Must call ready_simulation() before starting")
		return
	
	if state == Enums.SimState.RUNNING:
		Debug.log_warn("GameManager", "Simulation already running")
		return
	
	state = Enums.SimState.RUNNING
	Debug.log_info("GameManager", "Simulation started (speed: %.1fx)" % speed_multiplier)


## Pause the simulation
func pause_simulation() -> void:
	if state != Enums.SimState.RUNNING:
		Debug.log_warn("GameManager", "Can only pause when running")
		return
	
	state = Enums.SimState.PAUSED
	Debug.log_info("GameManager", "Simulation paused at tick %d" % current_tick)


## Step forward one tick (only when ready or paused)
func step_simulation() -> void:
	if state != Enums.SimState.READY and state != Enums.SimState.PAUSED:
		Debug.log_warn("GameManager", "Can only step when ready or paused")
		return
	
	# Process exactly one tick
	_process_tick()
	
	# Ensure we're paused after stepping
	state = Enums.SimState.PAUSED
	Debug.log_info("GameManager", "Stepped to tick %d" % current_tick)


## Step back one tick (only when paused, requires history)
func back_simulation() -> void:
	if state != Enums.SimState.PAUSED:
		Debug.log_warn("GameManager", "Can only rewind when paused")
		return
	
	if _tick_history.size() < 2:
		Debug.log_warn("GameManager", "No history to rewind to")
		return
	
	# Remove current state
	_tick_history.pop_back()
	
	# Restore previous state
	var previous_state = _tick_history.back()
	_restore_state(previous_state)
	
	Debug.log_info("GameManager", "Rewound to tick %d" % current_tick)


## Reset simulation completely
func reset_simulation() -> void:
	# Stop processing
	state = Enums.SimState.STOPPED
	
	# Clear state
	current_tick = 0
	_tick_accumulator = 0.0
	_tick_history.clear()
	Debug.set_current_tick(0)
	
	# Clear grid
	GridManager.reset()
	
	# Reset teams
	if home_team:
		home_team.reset_score()
		for unit in home_team.units:
			unit.current_stamina = unit.stat_stamina
			unit.has_ball = false
			unit.state = Enums.UnitState.IDLE
	
	if away_team:
		away_team.reset_score()
		for unit in away_team.units:
			unit.current_stamina = unit.stat_stamina
			unit.has_ball = false
			unit.state = Enums.UnitState.IDLE
	
	# Reset ball
	if ball:
		ball.reset_to_center()
	
	EventBus.simulation_reset.emit()
	Debug.log_info("GameManager", "Simulation reset")


## Set simulation speed
func set_speed(multiplier: float) -> void:
	speed_multiplier = clampf(multiplier, 0.25, 4.0)
	Debug.log_info("GameManager", "Speed set to %.2fx" % speed_multiplier)


# ===========================================
# EVENT HANDLERS
# ===========================================


## Handle UI control requests
func _on_ui_control_requested(action: String) -> void:
	match action:
		"ready":
			ready_simulation()
		"start":
			start_simulation()
		"pause":
			pause_simulation()
		"step":
			step_simulation()
		"back":
			back_simulation()
		"reset":
			reset_simulation()
		_:
			Debug.log_warn("GameManager", "Unknown control action: %s" % action)


## Handle speed change requests
func _on_ui_speed_change_requested(new_speed: float) -> void:
	set_speed(new_speed)


# ===========================================
# DEBUG & DIAGNOSTICS
# ===========================================


## Get current simulation status
func get_status() -> Dictionary:
	return {
		"state": Enums.SimState.keys()[state],
		"tick": current_tick,
		"speed": speed_multiplier,
		"history_size": _tick_history.size(),
		"home_score": home_team.get_score_string() if home_team else "N/A",
		"away_score": away_team.get_score_string() if away_team else "N/A",
	}


## Print simulation status
func print_status() -> void:
	Debug.log_section("Simulation Status")
	var status = get_status()
	for key in status:
		Debug.log_info("GameManager", "  %s: %s" % [key, status[key]])
