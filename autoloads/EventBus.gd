# EventBus.gd
# ============================================
# PURPOSE: Central hub for all game events (signals).
# PRINCIPLE: Any system can emit events here, any system can listen.
#            This creates "loose coupling" - systems don't need to know
#            about each other, they just know about the EventBus.
# ACCESS: Global singleton via `EventBus.signal_name.emit(args)`
# ============================================
# HOW TO USE:
#   1. Add this script to Project → Project Settings → Autoload
#   2. Name it "EventBus" (no quotes)
#
#   EMITTING (when something happens):
#      EventBus.goal_scored.emit(Enums.Team.HOME, 6)
#
#   LISTENING (reacting to events):
#      func _ready():
#          EventBus.goal_scored.connect(_on_goal_scored)
#
#      func _on_goal_scored(team: Enums.Team, points: int):
#          update_scoreboard(team, points)
# ============================================
# WHY USE AN EVENT BUS?
#
#   WITHOUT EventBus (tight coupling):
#      - GameManager needs reference to ScoreUI
#      - GameManager needs reference to SoundManager
#      - GameManager needs reference to StatsTracker
#      - If you add a new system, you modify GameManager
#      - Testing GameManager requires all dependencies
#
#   WITH EventBus (loose coupling):
#      - GameManager just emits: EventBus.goal_scored.emit(...)
#      - ScoreUI listens and updates itself
#      - SoundManager listens and plays a sound
#      - StatsTracker listens and records the stat
#      - New systems just connect to existing signals
#      - Testing is easier (systems are independent)
# ============================================

extends Node


# ===========================================
# SIMULATION EVENTS
# ===========================================
# Events related to the simulation engine (GameManager)

## Emitted when the simulation state changes (STOPPED → READY → RUNNING, etc.)
## Parameters: new_state (Enums.SimState), old_state (Enums.SimState)
signal simulation_state_changed(new_state: int, old_state: int)

## Emitted at the start of each simulation tick
## Parameters: tick_number (int)
signal tick_started(tick_number: int)

## Emitted at the end of each simulation tick
## Parameters: tick_number (int)
signal tick_completed(tick_number: int)

## Emitted when simulation is reset
signal simulation_reset()


# ===========================================
# MATCH EVENTS
# ===========================================
# Events related to match flow (MatchDirector)

## Emitted when match state changes (PRE_MATCH → QUARTER_1, etc.)
## Parameters: new_state (Enums.MatchState), old_state (Enums.MatchState)
signal match_state_changed(new_state: int, old_state: int)

## Emitted when a quarter begins
## Parameters: quarter_number (int, 1-4)
signal quarter_started(quarter_number: int)

## Emitted when a quarter ends
## Parameters: quarter_number (int), home_score (int), away_score (int)
signal quarter_ended(quarter_number: int, home_score: int, away_score: int)

## Emitted when match clock time changes (for UI updates)
## Parameters: time_remaining_seconds (float), quarter (int)
signal match_clock_updated(time_remaining: float, quarter: int)

## Emitted when the match ends
## Parameters: home_score (int), away_score (int), winner (Enums.Team or null for draw)
signal match_ended(home_score: int, away_score: int, winner: int)


# ===========================================
# SCORING EVENTS
# ===========================================

## Emitted when any score is registered
## Parameters: team (Enums.Team), score_type (Enums.ScoreType), points (int)
signal score_registered(team: int, score_type: int, points: int)

## Emitted when a goal is scored (convenience signal, also triggers score_registered)
## Parameters: team (Enums.Team), scorer_unit (Unit or null)
signal goal_scored(team: int, scorer_unit: Unit)

## Emitted when a behind is scored
## Parameters: team (Enums.Team), scorer_unit (Unit or null, null if rushed)
signal behind_scored(team: int, scorer_unit: Unit)


# ===========================================
# BALL EVENTS
# ===========================================
# Events related to ball state and movement

## Emitted when ball state changes (HELD → LOOSE_AIR, etc.)
## Parameters: new_state (Enums.BallState), old_state (Enums.BallState)
signal ball_state_changed(new_state: int, old_state: int)

## Emitted when ball position changes
## Parameters: new_pos (Vector2i), old_pos (Vector2i)
signal ball_position_changed(new_pos: Vector2i, old_pos: Vector2i)

## Emitted when possession changes
## Parameters: new_owner (Unit or null), old_owner (Unit or null),
##             quality (Enums.PossessionQuality)
signal possession_changed(new_owner: Unit, old_owner: Unit, quality: int)

## Emitted when ball enters a scoring zone
## Parameters: zone_type (String: "goal" or "behind"), team_scoring (Enums.Team)
signal ball_entered_scoring_zone(zone_type: String, team_scoring: int)

## Emitted when ball goes out of bounds
## Parameters: position (Vector2i), last_touch_team (Enums.Team)
signal ball_out_of_bounds(position: Vector2i, last_touch_team: int)


# ===========================================
# UNIT EVENTS
# ===========================================
# Events related to player units

## Emitted when a unit starts an action
## Parameters: unit (Unit), action (Enums.Action)
signal unit_action_started(unit: Unit, action: int)

## Emitted when a unit completes an action
## Parameters: unit (Unit), action (Enums.Action), success (bool)
signal unit_action_completed(unit: Unit, action: int, success: bool)

## Emitted when a unit's state changes
## Parameters: unit (Unit), new_state (Enums.UnitState), old_state (Enums.UnitState)
signal unit_state_changed(unit: Unit, new_state: int, old_state: int)

## Emitted when a unit moves to a new cell
## Parameters: unit (Unit), new_pos (Vector2i), old_pos (Vector2i)
signal unit_moved(unit: Unit, new_pos: Vector2i, old_pos: Vector2i)

## Emitted when a unit's stamina changes significantly
## Parameters: unit (Unit), new_stamina (int), old_stamina (int)
signal unit_stamina_changed(unit: Unit, new_stamina: int, old_stamina: int)

## Emitted when a unit becomes exhausted (stamina critical)
## Parameters: unit (Unit)
signal unit_exhausted(unit: Unit)


# ===========================================
# DISPOSAL EVENTS
# ===========================================
# Events related to kicks and handballs

## Emitted when a disposal (kick/handball) is attempted
## Parameters: unit (Unit), action (Enums.Action), target_pos (Vector2i)
signal disposal_attempted(unit: Unit, action: int, target_pos: Vector2i)

## Emitted when a disposal is completed with result
## Parameters: unit (Unit), action (Enums.Action), outcome (Enums.DisposalOutcome)
signal disposal_completed(unit: Unit, action: int, outcome: int)


# ===========================================
# CONTEST EVENTS
# ===========================================
# Events related to contested ball situations

## Emitted when a contest for the ball begins
## Parameters: units (Array of Units involved), position (Vector2i)
signal contest_started(units: Array, position: Vector2i)

## Emitted when a contest resolves
## Parameters: winner (Unit or null), position (Vector2i)
signal contest_resolved(winner: Unit, position: Vector2i)

## Emitted when a tackle is attempted
## Parameters: tackler (Unit), target (Unit), success (bool)
signal tackle_attempted(tackler: Unit, target: Unit, success: bool)

## Emitted when a mark is attempted
## Parameters: marker (Unit), position (Vector2i), success (bool)
signal mark_attempted(marker: Unit, position: Vector2i, success: bool)


# ===========================================
# UI EVENTS
# ===========================================
# Events from UI to game systems (user input)

## Emitted when user requests simulation control
## Parameters: action (String: "start", "pause", "step", "back", "reset")
signal ui_control_requested(action: String)

## Emitted when user requests to change simulation speed
## Parameters: speed_multiplier (float)
signal ui_speed_change_requested(speed: float)


# ===========================================
# DEBUG EVENTS
# ===========================================
# Events useful for debugging and development

## Emitted for any noteworthy game event (catch-all for logging)
## Parameters: event_type (String), details (Dictionary)
signal debug_event(event_type: String, details: Dictionary)


# ===========================================
# HELPER FUNCTIONS
# ===========================================


## Emit a debug event with logging
## This is a convenience function for debugging
func emit_debug(event_type: String, details: Dictionary = {}) -> void:
	Debug.log_event("EventBus", event_type, details)
	debug_event.emit(event_type, details)


## Get a count of connections for a signal (useful for debugging)
func get_connection_count(signal_name: String) -> int:
	if has_signal(signal_name):
		return get_signal_connection_list(signal_name).size()
	return -1


## Print all signal connection counts (for debugging)
func print_connection_summary() -> void:
	Debug.log_section("EventBus Connection Summary")
	
	var signals = [
		"simulation_state_changed", "tick_started", "tick_completed",
		"match_state_changed", "quarter_started", "quarter_ended",
		"score_registered", "goal_scored", "behind_scored",
		"ball_state_changed", "possession_changed",
		"unit_action_started", "unit_action_completed", "unit_moved",
	]
	
	for sig in signals:
		var count = get_connection_count(sig)
		if count > 0:
			Debug.log_info("EventBus", "  %s: %d listeners" % [sig, count])


# ===========================================
# INITIALIZATION
# ===========================================


func _ready() -> void:
	Debug.log_info("EventBus", "Central event system initialized")
	Debug.log_debug("EventBus", "All signals ready for connections")
