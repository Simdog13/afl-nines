# Enums.gd
# ============================================
# PURPOSE: Defines all enumerations (fixed sets of choices) for the game.
# PRINCIPLE: Enums are type-safe labels. Using `Action.KICK` instead of "kick"
#            means the editor catches typos, provides autocomplete, and runs faster.
# ACCESS: Global singleton via `Enums.EnumName.VALUE` from any script.
# ============================================
# HOW TO USE:
#   1. Add this script to Project → Project Settings → Autoload
#   2. Name it "Enums" (no quotes)
#   3. Access values anywhere: var action = Enums.Action.KICK
#   4. Compare: if action == Enums.Action.KICK:
#   5. Get name: Enums.Action.keys()[action] returns "KICK"
# ============================================
# WHY ENUMS INSTEAD OF STRINGS?
#   String "tackel" - typo compiles fine, bug happens at runtime
#   Enum Enums.Action.TACKEL - editor immediately shows error (red underline)
#   
#   Strings are compared character-by-character (slow)
#   Enums are compared as integers (fast)
# ============================================

extends Node


# ===========================================
# SIMULATION STATE
# ===========================================
# What state is the simulation engine (GameManager) in?
# This controls whether ticks are processing and what dev controls are available.
#
# State flow:
#   STOPPED → [Ready] → READY → [Start] → RUNNING
#                              → [Step]  → PAUSED
#   RUNNING → [Pause] → PAUSED → [Start] → RUNNING
#                              → [Step]  → PAUSED (advance 1)
#                              → [Back]  → PAUSED (rewind 1)
#   Any → [Reset] → STOPPED

enum SimState {
	STOPPED,   # No simulation, fresh/reset state. Can: Ready, nothing else.
	READY,     # Units placed, waiting to start. Can: Start, Step, Reset.
	RUNNING,   # Auto-advancing ticks. Can: Pause, Reset.
	PAUSED,    # Halted mid-simulation. Can: Start (resume), Step, Back, Reset.
}


# ===========================================
# MATCH STATE
# ===========================================
# What phase is the actual AFL match in?
# This is the "broadcast layer" that users see - quarters, breaks, etc.
# Controlled by MatchDirector.

enum MatchState {
	PRE_MATCH,        # Before the game starts, teams being set up.
	
	QUARTER_1,        # First quarter in progress.
	QUARTER_BREAK_1,  # Break after Q1.
	
	QUARTER_2,        # Second quarter in progress.
	HALF_TIME,        # Half time break.
	
	QUARTER_3,        # Third quarter in progress.
	QUARTER_BREAK_3,  # Break after Q3.
	
	QUARTER_4,        # Fourth/final quarter in progress.
	POST_MATCH,       # Match complete, final siren.
}


# ===========================================
# PLAYER ZONES
# ===========================================
# AFL Nines has strict zones - players cannot leave their assigned zone.
# Each team has 3 defenders, 3 midfielders, 3 forwards.

enum Zone {
	DEFENSIVE,  # Backline - protect the goal, intercept, rebound.
	MIDFIELD,   # Center - win the ball, distribute to forwards.
	FORWARD,    # Attack - receive the ball, score goals.
}


# ===========================================
# PLAYER POSITIONS
# ===========================================
# Specific roles within each zone.
# For 9v9, we have 3 players per zone, but they can have specific roles.

enum Position {
	# Defensive zone (3 players)
	FULL_BACK,       # FB - Last line of defense, guards goal
	CENTRE_BACK,     # CB - Central defender, intercepts
	BACK_FLANKER,    # BF - Defensive wing, rebounds
	
	# Midfield zone (3 players)
	CENTRE,          # C - Primary ball winner, distributor
	WING_LEFT,       # WL - Left side midfielder
	WING_RIGHT,      # WR - Right side midfielder
	
	# Forward zone (3 players)
	FULL_FORWARD,    # FF - Primary goal scorer, stays deep
	CENTRE_FORWARD,  # CF - Creates space, marks, scores
	FORWARD_FLANKER, # FLK - Forward wing, crumbs and snaps
}


# ===========================================
# UNIT STATE
# ===========================================
# What is a player currently doing?
# Simplified from 8+ states to 4 core states for clarity.

enum UnitState {
	IDLE,        # Standing, waiting, recovering stamina.
	MOVING,      # Moving to a destination (with or without ball).
	CONTESTING,  # Competing for a loose ball or in a tackle.
	DISPOSING,   # In the act of kicking or handballing.
}


# ===========================================
# PLAYER ACTIONS
# ===========================================
# What action can a player take on their turn?
# These are the verbs of the simulation - what players DO.

enum Action {
	# Movement actions
	MOVE,          # Move toward a destination cell.
	STAND,         # Stay in place, recover stamina.
	
	# Ball-winning actions
	CONTEST,       # Compete for a loose ball.
	MARK,          # Attempt to catch a kicked ball.
	TACKLE,        # Attempt to dispossess opponent (touch tackle in AFL Nines).
	
	# Disposal actions (only when holding ball)
	KICK,          # Kick the ball to a target.
	HANDBALL,      # Handpass to a nearby teammate.
	
	# Special actions
	LEAD,          # Run to create space (forwards calling for ball).
	SHEPHERD,      # Block space to protect teammate (not tackling).
}


# ===========================================
# BALL STATE
# ===========================================
# Where is the ball and who controls it?
# Critical for determining what actions are legal.

enum BallState {
	# Controlled states
	HELD,          # Firmly in a player's hands, clean possession.
	BOUNCING,      # Player is running with ball (must bounce/dispose).
	
	# Uncontrolled states
	LOOSE_GROUND,  # On the ground, anyone can pick it up.
	LOOSE_AIR,     # In the air (from kick/handball), can be marked.
	
	# Dead ball states
	WITH_UMPIRE,   # Umpire has ball (before bounce, after goal).
	OUT_OF_BOUNDS, # Ball went over boundary line.
	DEAD,          # Play stopped (free kick, etc).
}


# ===========================================
# POSSESSION QUALITY
# ===========================================
# How well does the player control the ball?
# Affects success chance of next disposal.

enum PossessionQuality {
	CLEAN,      # Perfect control, full accuracy on next disposal.
	PRESSURED,  # Opponent nearby, reduced accuracy.
	AWKWARD,    # Difficult pickup/mark, significantly reduced accuracy.
	FUMBLED,    # About to lose it, very low accuracy.
}


# ===========================================
# SCORE TYPE
# ===========================================
# What kind of score was registered?

enum ScoreType {
	GOAL,    # Through the middle posts - 6 points.
	BEHIND,  # Through the side posts - 1 point.
	RUSHED,  # Defender deliberately put through - 1 point to attacker.
}


# ===========================================
# DISPOSAL OUTCOME
# ===========================================
# What happened when a player kicked or handballed?

enum DisposalOutcome {
	# Successful outcomes
	MARK_TAKEN,      # Teammate caught it cleanly (mark = free kick).
	HANDBALL_RECEIVED, # Teammate received the handball.
	GOAL_SCORED,     # Ball went through for a goal.
	BEHIND_SCORED,   # Ball went through for a behind.
	
	# Neutral outcomes
	CONTESTED,       # Multiple players competing for the ball.
	GROUND_BALL,     # Ball hit the ground, now loose.
	
	# Negative outcomes
	INTERCEPTED,     # Opponent caught or picked up the ball.
	OUT_OF_BOUNDS,   # Ball went over the boundary.
	TURNOVER,        # Possession lost to the other team.
}


# ===========================================
# EVENT TYPES
# ===========================================
# What kind of game event occurred?
# Used by EventBus to categorize signals.

enum EventType {
	# Simulation events
	TICK_PROCESSED,
	SIMULATION_STATE_CHANGED,
	
	# Match events
	MATCH_STATE_CHANGED,
	QUARTER_STARTED,
	QUARTER_ENDED,
	MATCH_ENDED,
	
	# Ball events
	BALL_STATE_CHANGED,
	POSSESSION_CHANGED,
	DISPOSAL_ATTEMPTED,
	DISPOSAL_COMPLETED,
	
	# Scoring events
	SCORE_REGISTERED,
	
	# Unit events
	UNIT_ACTION_STARTED,
	UNIT_ACTION_COMPLETED,
	UNIT_STATE_CHANGED,
	UNIT_STAMINA_CHANGED,
	
	# Contest events
	CONTEST_STARTED,
	CONTEST_RESOLVED,
	TACKLE_ATTEMPTED,
	MARK_ATTEMPTED,
}


# ===========================================
# TEAM IDENTIFIER
# ===========================================
# Which team does something belong to?
# Using enum instead of magic numbers 0/1 for clarity.
# Named "TeamID" to avoid conflict with the Team class.

enum TeamID {
	HOME,  # Team 0 - attacks RIGHT, defends LEFT
	AWAY,  # Team 1 - attacks LEFT, defends RIGHT
	NONE,  # No team (e.g., ball with umpire)
}


# ===========================================
# HELPER FUNCTIONS
# ===========================================
# Utility functions for working with enums.


## Get the Zone enum value for a player's Position
static func get_zone_for_position(pos: Position) -> Zone:
	match pos:
		Position.FULL_BACK, Position.CENTRE_BACK, Position.BACK_FLANKER:
			return Zone.DEFENSIVE
		Position.CENTRE, Position.WING_LEFT, Position.WING_RIGHT:
			return Zone.MIDFIELD
		Position.FULL_FORWARD, Position.CENTRE_FORWARD, Position.FORWARD_FLANKER:
			return Zone.FORWARD
	# Default fallback (should never hit this)
	return Zone.MIDFIELD


## Check if a grid X position is within a zone (for TeamID HOME)
## For TeamID AWAY, the zones are mirrored.
static func get_zone_at_x(x: int, for_team: TeamID) -> Zone:
	# TeamID HOME attacks right, so their FORWARD zone is on the right
	# TeamID AWAY attacks left, so their FORWARD zone is on the left
	
	var effective_x = x
	if for_team == TeamID.AWAY:
		# Mirror the x coordinate for away team
		effective_x = Constants.GRID_WIDTH - 1 - x
	
	if effective_x <= Constants.ZONE_DEFENSIVE_END:
		return Zone.DEFENSIVE
	elif effective_x <= Constants.ZONE_MIDFIELD_END:
		return Zone.MIDFIELD
	else:
		return Zone.FORWARD


## Check if a unit at position X is in their correct zone
static func is_in_correct_zone(x: int, unit_zone: Zone, unit_team: TeamID) -> bool:
	var current_zone = get_zone_at_x(x, unit_team)
	return current_zone == unit_zone


## Get a human-readable name for any enum value
## Usage: Enums.get_enum_name(Enums.Action, Enums.Action.KICK) returns "KICK"
static func get_enum_name(enum_dict: Dictionary, value: int) -> String:
	for key in enum_dict.keys():
		if enum_dict[key] == value:
			return key
	return "UNKNOWN"
