# MatchDirector.gd
# ============================================
# PURPOSE: The "referee" and "broadcast producer" of the match.
# PRINCIPLE: Controls WHAT happens in terms of match flow.
#            GameManager controls WHEN (ticks). MatchDirector controls WHAT (quarters, scores).
# ACCESS: Global singleton via `MatchDirector.function_name()`
# ============================================
# RESPONSIBILITIES:
#   - Track match state (quarters, breaks, end)
#   - Manage match clock
#   - Coordinate stoppages (after goals, etc.)
#   - Declare match results
# ============================================
# MATCH FLOW:
#   PRE_MATCH → QUARTER_1 → QUARTER_BREAK_1 → QUARTER_2 → HALF_TIME
#            → QUARTER_3 → QUARTER_BREAK_3 → QUARTER_4 → POST_MATCH
# ============================================

extends Node


# ===========================================
# MATCH STATE
# ===========================================

## Current match state
var match_state: Enums.MatchState = Enums.MatchState.PRE_MATCH:
	set(value):
		if match_state != value:
			var old_state = match_state
			match_state = value
			EventBus.match_state_changed.emit(match_state, old_state)
			Debug.log_state_change("MatchDirector", "MatchState",
				Enums.MatchState.keys()[old_state],
				Enums.MatchState.keys()[match_state])


# ===========================================
# TIMING
# ===========================================

## Current quarter number (1-4)
var current_quarter: int = 1

## Time remaining in current quarter (in simulation seconds)
var quarter_time_remaining: float = 0.0

## Is the match clock currently running?
var is_clock_running: bool = false

## Is there a stoppage in play? (after goal, etc.)
var is_stoppage: bool = false

## Ticks remaining in current stoppage
var stoppage_ticks_remaining: int = 0


# ===========================================
# STOPPAGE SETTINGS
# ===========================================

## Ticks to pause after a goal
const GOAL_STOPPAGE_TICKS: int = 10

## Ticks to pause after a behind
const BEHIND_STOPPAGE_TICKS: int = 5

## Ticks for quarter break
const QUARTER_BREAK_TICKS: int = 20

## Ticks for half time
const HALF_TIME_TICKS: int = 40


# ===========================================
# INITIALIZATION
# ===========================================


func _ready() -> void:
	Debug.log_info("MatchDirector", "Match director initialized")
	Debug.log_info("MatchDirector", "Quarter duration: %.0f seconds" % Constants.QUARTER_DURATION_SECONDS)
	
	# Connect to scoring events
	EventBus.score_registered.connect(_on_score_registered)


# ===========================================
# TICK PROCESSING
# ===========================================


## Called by GameManager each tick
func process_tick() -> void:
	# Handle stoppage countdown
	if is_stoppage:
		stoppage_ticks_remaining -= 1
		if stoppage_ticks_remaining <= 0:
			_end_stoppage()
		return  # Don't advance clock during stoppage
	
	# Only advance clock during active quarters
	if not _is_playing_quarter():
		return
	
	if not is_clock_running:
		return
	
	# Advance match clock
	quarter_time_remaining -= Constants.SIM_SECONDS_PER_TICK
	
	# Emit clock update (every second of sim time, roughly)
	if int(quarter_time_remaining) != int(quarter_time_remaining + Constants.SIM_SECONDS_PER_TICK):
		EventBus.match_clock_updated.emit(quarter_time_remaining, current_quarter)
	
	# Check for quarter end
	if quarter_time_remaining <= 0:
		_end_quarter()


# ===========================================
# MATCH FLOW CONTROL
# ===========================================


## Start a new match
func start_match() -> void:
	if match_state != Enums.MatchState.PRE_MATCH:
		Debug.log_warn("MatchDirector", "Cannot start match - not in PRE_MATCH state")
		return
	
	Debug.log_section("MATCH STARTING")
	
	current_quarter = 1
	_start_quarter()


## Start the current quarter
func _start_quarter() -> void:
	# Set match state based on quarter
	match current_quarter:
		1: match_state = Enums.MatchState.QUARTER_1
		2: match_state = Enums.MatchState.QUARTER_2
		3: match_state = Enums.MatchState.QUARTER_3
		4: match_state = Enums.MatchState.QUARTER_4
	
	# Reset quarter timer
	quarter_time_remaining = Constants.QUARTER_DURATION_SECONDS
	is_clock_running = true
	is_stoppage = false

	# Make ball loose at center for the bounce
	if GameManager.ball:
		var center = Vector2i(Constants.FIELD_CENTER_X, Constants.FIELD_CENTER_Y)
		GameManager.ball.make_loose_ground(center)
		Debug.log_debug("MatchDirector", "Ball bounced at center to start quarter")

	EventBus.quarter_started.emit(current_quarter)
	Debug.log_info("MatchDirector", "=== QUARTER %d START ===" % current_quarter)
	Debug.log_info("MatchDirector", "Time: %.0f seconds" % quarter_time_remaining)


## End the current quarter
func _end_quarter() -> void:
	is_clock_running = false
	
	# Get scores for the event
	var home_score = GameManager.home_team.score if GameManager.home_team else 0
	var away_score = GameManager.away_team.score if GameManager.away_team else 0
	
	EventBus.quarter_ended.emit(current_quarter, home_score, away_score)
	
	Debug.log_info("MatchDirector", "=== QUARTER %d END ===" % current_quarter)
	Debug.log_info("MatchDirector", "Score: %d - %d" % [home_score, away_score])
	
	# Determine what's next
	if current_quarter >= Constants.QUARTERS_PER_MATCH:
		_end_match()
	else:
		_start_break()


## Start a break between quarters
func _start_break() -> void:
	# Set break state
	match current_quarter:
		1: match_state = Enums.MatchState.QUARTER_BREAK_1
		2: match_state = Enums.MatchState.HALF_TIME
		3: match_state = Enums.MatchState.QUARTER_BREAK_3
	
	# Determine break duration
	var break_ticks = QUARTER_BREAK_TICKS
	if current_quarter == 2:
		break_ticks = HALF_TIME_TICKS
	
	Debug.log_info("MatchDirector", "--- %s ---" % Enums.MatchState.keys()[match_state])
	
	# Start stoppage for the break
	_start_stoppage(break_ticks)
	
	# When stoppage ends, it will call _end_stoppage which advances the quarter


## End the match
func _end_match() -> void:
	match_state = Enums.MatchState.POST_MATCH
	is_clock_running = false
	
	var home_score = GameManager.home_team.score if GameManager.home_team else 0
	var away_score = GameManager.away_team.score if GameManager.away_team else 0
	
	var winner = Enums.TeamID.NONE
	if home_score > away_score:
		winner = Enums.TeamID.HOME
	elif away_score > home_score:
		winner = Enums.TeamID.AWAY
	
	EventBus.match_ended.emit(home_score, away_score, winner)
	
	Debug.log_section("MATCH ENDED")
	Debug.log_info("MatchDirector", "Final Score: %d - %d" % [home_score, away_score])
	
	if winner == Enums.TeamID.NONE:
		Debug.log_info("MatchDirector", "Result: DRAW!")
	else:
		var winner_name = GameManager.home_team.team_name if winner == Enums.TeamID.HOME else GameManager.away_team.team_name
		Debug.log_info("MatchDirector", "Winner: %s" % winner_name)
	
	# Pause the simulation
	GameManager.pause_simulation()


# ===========================================
# STOPPAGES
# ===========================================


## Start a stoppage (pause play for a number of ticks)
func _start_stoppage(ticks: int) -> void:
	is_stoppage = true
	is_clock_running = false
	stoppage_ticks_remaining = ticks
	Debug.log_debug("MatchDirector", "Stoppage started (%d ticks)" % ticks)


## End the current stoppage
func _end_stoppage() -> void:
	is_stoppage = false
	stoppage_ticks_remaining = 0
	
	Debug.log_debug("MatchDirector", "Stoppage ended")
	
	# Check if this was a quarter break
	if match_state in [Enums.MatchState.QUARTER_BREAK_1, 
					   Enums.MatchState.HALF_TIME, 
					   Enums.MatchState.QUARTER_BREAK_3]:
		# Advance to next quarter
		current_quarter += 1
		_start_quarter()
	else:
		# Resume normal play
		is_clock_running = true

		# Restart play with ball-up at center
		if GameManager.ball:
			var center = Vector2i(Constants.FIELD_CENTER_X, Constants.FIELD_CENTER_Y)
			GameManager.ball.make_loose_ground(center)
			Debug.log_debug("MatchDirector", "Ball-up at center to resume play")


# ===========================================
# EVENT HANDLERS
# ===========================================


## Handle score events
func _on_score_registered(team: Enums.TeamID, score_type: Enums.ScoreType, _points: int) -> void:
	# Start appropriate stoppage
	var stoppage_ticks = GOAL_STOPPAGE_TICKS if score_type == Enums.ScoreType.GOAL else BEHIND_STOPPAGE_TICKS
	_start_stoppage(stoppage_ticks)
	
	Debug.log_info("MatchDirector", "Stoppage for %s" % Enums.ScoreType.keys()[score_type])


# ===========================================
# QUERIES
# ===========================================


## Check if we're in an active playing quarter
func _is_playing_quarter() -> bool:
	return match_state in [
		Enums.MatchState.QUARTER_1,
		Enums.MatchState.QUARTER_2,
		Enums.MatchState.QUARTER_3,
		Enums.MatchState.QUARTER_4
	]


## Check if match is in progress (not pre or post)
func is_match_in_progress() -> bool:
	return match_state != Enums.MatchState.PRE_MATCH and \
		   match_state != Enums.MatchState.POST_MATCH


## Get time remaining as a formatted string (MM:SS)
func get_time_string() -> String:
	var total_seconds = int(max(0, quarter_time_remaining))
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%d:%02d" % [minutes, seconds]


## Get match status as a dictionary
func get_status() -> Dictionary:
	return {
		"state": Enums.MatchState.keys()[match_state],
		"quarter": current_quarter,
		"time_remaining": quarter_time_remaining,
		"time_string": get_time_string(),
		"clock_running": is_clock_running,
		"is_stoppage": is_stoppage,
	}


# ===========================================
# DEBUG
# ===========================================


## Print match status
func print_status() -> void:
	Debug.log_section("Match Status")
	var status = get_status()
	for key in status:
		Debug.log_info("MatchDirector", "  %s: %s" % [key, status[key]])
	
	# Also print scores
	if GameManager.home_team and GameManager.away_team:
		Debug.log_info("MatchDirector", "  Score: %s vs %s" % [
			GameManager.home_team.get_score_string(),
			GameManager.away_team.get_score_string()
		])


## Reset match to pre-match state
func reset() -> void:
	match_state = Enums.MatchState.PRE_MATCH
	current_quarter = 1
	quarter_time_remaining = 0.0
	is_clock_running = false
	is_stoppage = false
	stoppage_ticks_remaining = 0
	
	Debug.log_info("MatchDirector", "Match reset to PRE_MATCH")
