# Ball.gd
# ============================================
# PURPOSE: Represents the football on the field.
# PRINCIPLE: This is a DATA class - it holds information about the ball.
#            It knows WHERE it is and WHO has it (if anyone).
#            Rendering is done by BallVisual. Physics calculations are elsewhere.
# ============================================
# WHAT THE BALL KNOWS:
#   - Location: which grid cell it's in (or traveling to)
#   - State: is it held, loose on ground, in the air, etc.
#   - Possession: who has it (if anyone)
#   - Movement: where it's going (if kicked/handballed)
# ============================================
# BALL STATES:
#   HELD        - A player has clean possession
#   BOUNCING    - Player is running with it (must dispose soon)
#   LOOSE_GROUND - On the ground, anyone can grab it
#   LOOSE_AIR   - In flight (from kick/handball), can be marked
#   WITH_UMPIRE - Dead ball, umpire has it (before bounce, after goal)
#   OUT_OF_BOUNDS - Over the boundary
#   DEAD        - Play stopped
# ============================================

class_name Ball
extends RefCounted


# ===========================================
# LOCATION
# ===========================================

## Current grid position of the ball
## This is the SOURCE OF TRUTH for where the ball is.
var grid_position: Vector2i = Vector2i(0, 0)

## Target position (where the ball is traveling to, if in flight)
var target_position: Vector2i = Vector2i(0, 0)

## Starting position of current flight (for interpolation)
var flight_start_position: Vector2i = Vector2i(0, 0)

## How many ticks into the current flight (0 if not in flight)
var flight_ticks_elapsed: int = 0

## Total ticks for current flight (0 if not in flight)
var flight_ticks_total: int = 0


# ===========================================
# STATE
# ===========================================

## Current state of the ball
var state: Enums.BallState = Enums.BallState.WITH_UMPIRE

## Previous state (for detecting changes)
var previous_state: Enums.BallState = Enums.BallState.WITH_UMPIRE


# ===========================================
# POSSESSION
# ===========================================

## The unit currently holding the ball (null if loose/in air)
var possessing_unit: Unit = null

## Which team last touched the ball (for out of bounds decisions)
var last_touch_team: Enums.TeamID = Enums.TeamID.NONE

## Quality of current possession (if held)
var possession_quality: Enums.PossessionQuality = Enums.PossessionQuality.CLEAN


# ===========================================
# FLIGHT DATA (when kicked/handballed)
# ===========================================

## Type of disposal that sent the ball flying
var flight_type: Enums.Action = Enums.Action.KICK

## The unit that kicked/handballed (for stats tracking)
var disposal_unit: Unit = null

## Intended target unit (who were they kicking to?)
var intended_target_unit: Unit = null


# ===========================================
# INITIALIZATION
# ===========================================


## Initialize the ball at a position (typically center for ball-up)
func initialize(start_pos: Vector2i) -> void:
	grid_position = start_pos
	target_position = start_pos
	state = Enums.BallState.WITH_UMPIRE
	previous_state = Enums.BallState.WITH_UMPIRE
	possessing_unit = null
	last_touch_team = Enums.TeamID.NONE
	
	_clear_flight_data()
	
	Debug.log_info("Ball", "Initialized at %s" % start_pos)


## Reset ball to center (after a goal, start of quarter)
func reset_to_center() -> void:
	var center = Vector2i(Constants.FIELD_CENTER_X, Constants.FIELD_CENTER_Y)
	
	grid_position = center
	target_position = center
	_set_state(Enums.BallState.WITH_UMPIRE)
	possessing_unit = null
	last_touch_team = Enums.TeamID.NONE
	
	_clear_flight_data()
	
	Debug.log_info("Ball", "Reset to center %s" % center)
	EventBus.ball_position_changed.emit(center, grid_position)


# ===========================================
# STATE CHANGES
# ===========================================


## Internal: change state and emit events
func _set_state(new_state: Enums.BallState) -> void:
	if state != new_state:
		previous_state = state
		state = new_state
		
		EventBus.ball_state_changed.emit(state, previous_state)
		
		Debug.log_debug("Ball", "State: %s -> %s" % [
			Enums.BallState.keys()[previous_state],
			Enums.BallState.keys()[state]
		])


# ===========================================
# POSSESSION
# ===========================================


## A player picks up or marks the ball
func give_to_unit(unit: Unit, quality: Enums.PossessionQuality = Enums.PossessionQuality.CLEAN) -> void:
	var old_owner = possessing_unit
	
	# Clear ball from previous owner
	if possessing_unit != null and possessing_unit != unit:
		possessing_unit.lose_possession()
	
	# Give to new owner
	possessing_unit = unit
	possession_quality = quality
	last_touch_team = unit.team
	
	# Update unit's state
	unit.gain_possession(quality)
	
	# Ball position follows the unit
	var old_pos = grid_position
	grid_position = unit.grid_position
	target_position = grid_position
	
	# Set appropriate state
	_set_state(Enums.BallState.HELD)
	_clear_flight_data()
	
	# Emit events
	EventBus.possession_changed.emit(unit, old_owner, quality)
	if old_pos != grid_position:
		EventBus.ball_position_changed.emit(grid_position, old_pos)
	
	Debug.log_info("Ball", "%s takes possession (%s)" % [
		unit.player_name,
		Enums.PossessionQuality.keys()[quality]
	])


## Ball is dropped or knocked loose
func make_loose_ground(position: Vector2i) -> void:
	var old_pos = grid_position
	
	# Clear possession
	if possessing_unit != null:
		possessing_unit.lose_possession()
		possessing_unit = null
	
	grid_position = position
	target_position = position
	_set_state(Enums.BallState.LOOSE_GROUND)
	_clear_flight_data()
	
	EventBus.possession_changed.emit(null, possessing_unit, Enums.PossessionQuality.CLEAN)
	EventBus.ball_position_changed.emit(position, old_pos)
	
	Debug.log_info("Ball", "Loose on ground at %s" % position)


## Ball is in the air (kicked or handballed)
func make_loose_air(from_pos: Vector2i, to_pos: Vector2i, 
					disposal_type: Enums.Action, kicker: Unit, 
					intended_target: Unit = null) -> void:
	var old_pos = grid_position
	
	# Clear possession from kicker
	if possessing_unit != null:
		possessing_unit.lose_possession()
	
	# Record disposal info
	disposal_unit = kicker
	intended_target_unit = intended_target
	flight_type = disposal_type
	last_touch_team = kicker.team
	possessing_unit = null
	
	# Validate inputs
	if kicker == null:
		Debug.log_error("Ball", "Cannot start flight with null kicker")
		return

	if not Constants.is_valid_grid_pos(from_pos) or not Constants.is_valid_grid_pos(to_pos):
		Debug.log_error("Ball", "Cannot start flight with invalid positions: %s -> %s" % [from_pos, to_pos])
		return

	# Set up flight
	flight_start_position = from_pos
	grid_position = from_pos  # Ball starts at kicker
	target_position = to_pos

	# Calculate flight time based on distance and type
	var distance = Constants.grid_distance(from_pos, to_pos)
	var speed = Constants.BALL_SPEED_KICK if disposal_type == Enums.Action.KICK else Constants.BALL_SPEED_HANDBALL

	# Validate speed
	if speed <= 0:
		Debug.log_error("Ball", "Invalid ball speed: %f" % speed)
		return

	flight_ticks_total = maxi(1, int(ceil(float(distance) / speed)))
	flight_ticks_elapsed = 0
	
	_set_state(Enums.BallState.LOOSE_AIR)
	
	EventBus.possession_changed.emit(null, kicker, Enums.PossessionQuality.CLEAN)
	EventBus.disposal_attempted.emit(kicker, disposal_type, to_pos)
	
	Debug.log_info("Ball", "%s %s from %s to %s (%d ticks)" % [
		kicker.player_name,
		"kicks" if disposal_type == Enums.Action.KICK else "handballs",
		from_pos,
		to_pos,
		flight_ticks_total
	])


## Ball goes out of bounds
func make_out_of_bounds(position: Vector2i) -> void:
	var old_pos = grid_position
	
	if possessing_unit != null:
		possessing_unit.lose_possession()
		possessing_unit = null
	
	grid_position = position
	target_position = position
	_set_state(Enums.BallState.OUT_OF_BOUNDS)
	_clear_flight_data()
	
	EventBus.ball_out_of_bounds.emit(position, last_touch_team)
	
	Debug.log_info("Ball", "Out of bounds at %s (last touch: Team %d)" % [
		position, 
		last_touch_team
	])


## Umpire takes possession (after goal, before ball-up, etc.)
func give_to_umpire(position: Vector2i) -> void:
	var old_pos = grid_position
	
	if possessing_unit != null:
		possessing_unit.lose_possession()
		possessing_unit = null
	
	grid_position = position
	target_position = position
	_set_state(Enums.BallState.WITH_UMPIRE)
	_clear_flight_data()
	
	EventBus.ball_position_changed.emit(position, old_pos)
	
	Debug.log_info("Ball", "With umpire at %s" % position)


# ===========================================
# FLIGHT PROCESSING
# ===========================================


## Advance the ball's flight by one tick
## Returns true if still in flight, false if landed
func process_flight_tick() -> bool:
	if state != Enums.BallState.LOOSE_AIR:
		return false
	
	if flight_ticks_total <= 0:
		return false
	
	flight_ticks_elapsed += 1
	
	# Update position along flight path
	var progress = float(flight_ticks_elapsed) / float(flight_ticks_total)
	progress = clampf(progress, 0.0, 1.0)
	
	var old_pos = grid_position
	grid_position = Vector2i(
		int(lerp(float(flight_start_position.x), float(target_position.x), progress)),
		int(lerp(float(flight_start_position.y), float(target_position.y), progress))
	)
	
	if old_pos != grid_position:
		EventBus.ball_position_changed.emit(grid_position, old_pos)
	
	# Check if flight is complete
	if flight_ticks_elapsed >= flight_ticks_total:
		grid_position = target_position
		Debug.log_debug("Ball", "Flight complete, landed at %s" % grid_position)
		return false
	
	return true


## Get the current progress through flight (0.0 to 1.0)
func get_flight_progress() -> float:
	if flight_ticks_total <= 0:
		return 1.0
	return clampf(float(flight_ticks_elapsed) / float(flight_ticks_total), 0.0, 1.0)


## Check if ball is currently in flight
func is_in_flight() -> bool:
	return state == Enums.BallState.LOOSE_AIR and flight_ticks_elapsed < flight_ticks_total


## Clear all flight-related data
func _clear_flight_data() -> void:
	flight_start_position = grid_position
	flight_ticks_elapsed = 0
	flight_ticks_total = 0
	disposal_unit = null
	intended_target_unit = null


# ===========================================
# QUERIES
# ===========================================


## Check if the ball is loose (can be picked up / contested)
func is_loose() -> bool:
	return state == Enums.BallState.LOOSE_GROUND or state == Enums.BallState.LOOSE_AIR


## Check if someone has the ball
func is_held() -> bool:
	return state == Enums.BallState.HELD or state == Enums.BallState.BOUNCING


## Check if play is stopped
func is_dead() -> bool:
	return state == Enums.BallState.WITH_UMPIRE or \
		   state == Enums.BallState.OUT_OF_BOUNDS or \
		   state == Enums.BallState.DEAD


## Get the pixel position for rendering
func get_pixel_position() -> Vector2:
	# If in flight, interpolate between positions
	if is_in_flight():
		var progress = get_flight_progress()
		var start_pixel = Constants.grid_to_pixel_center(flight_start_position)
		var end_pixel = Constants.grid_to_pixel_center(target_position)
		return start_pixel.lerp(end_pixel, progress)
	
	return Constants.grid_to_pixel_center(grid_position)


## Get which team currently has possession (or NONE if loose)
func get_possessing_team() -> Enums.TeamID:
	if possessing_unit != null:
		return possessing_unit.team
	return Enums.TeamID.NONE


## Check if ball is in a scoring zone
func check_scoring_zone() -> Dictionary:
	# Returns: {is_score: bool, score_type: ScoreType, team: Team}
	var result = {
		"is_score": false,
		"score_type": Enums.ScoreType.BEHIND,
		"team": Enums.TeamID.NONE
	}
	
	var x = grid_position.x
	var y = grid_position.y
	
	# Check right side (Team HOME scores here)
	if x >= Constants.GOAL_RIGHT_X:
		if y >= Constants.GOAL_Y_MIN and y <= Constants.GOAL_Y_MAX:
			result.is_score = true
			result.team = Enums.TeamID.HOME
			# Goal if through center posts, behind if through sides
			if y >= Constants.GOAL_CENTER_Y_MIN and y <= Constants.GOAL_CENTER_Y_MAX:
				result.score_type = Enums.ScoreType.GOAL
			else:
				result.score_type = Enums.ScoreType.BEHIND
	
	# Check left side (Team AWAY scores here)
	elif x <= Constants.GOAL_LEFT_X:
		if y >= Constants.GOAL_Y_MIN and y <= Constants.GOAL_Y_MAX:
			result.is_score = true
			result.team = Enums.TeamID.AWAY
			if y >= Constants.GOAL_CENTER_Y_MIN and y <= Constants.GOAL_CENTER_Y_MAX:
				result.score_type = Enums.ScoreType.GOAL
			else:
				result.score_type = Enums.ScoreType.BEHIND
	
	return result


# ===========================================
# DEBUG
# ===========================================


## Get a summary string for debugging
func get_summary() -> String:
	var owner_str = possessing_unit.player_name if possessing_unit else "None"
	var flight_str = ""
	if is_in_flight():
		flight_str = " (in flight: %d/%d)" % [flight_ticks_elapsed, flight_ticks_total]
	
	return "Ball @ %s | State: %s | Owner: %s%s" % [
		grid_position,
		Enums.BallState.keys()[state],
		owner_str,
		flight_str
	]
