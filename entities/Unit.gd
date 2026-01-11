# Unit.gd
# ============================================
# PURPOSE: Represents a single player on the field.
# PRINCIPLE: This is a DATA class - it holds information about a player.
#            It knows what it IS, not how to render or make decisions.
#            Rendering is done by UnitVisual. Decisions are made by AIController.
# ============================================
# WHAT A UNIT KNOWS:
#   - Identity: name, team, position, zone
#   - Location: which grid cell they're in
#   - Stats: speed, kicking, marking, etc. (0-100 scale)
#   - State: what they're currently doing (idle, moving, etc.)
#   - Stamina: current energy level
#   - Ball: whether they have possession
# ============================================
# HOW TO CREATE A UNIT:
#   var player = Unit.new()
#   player.initialize("John Smith", Enums.TeamID.HOME, Enums.Position.CENTRE)
#   player.grid_position = Vector2i(16, 12)
# ============================================

class_name Unit
extends RefCounted

# We use RefCounted instead of Node because Units are pure data.
# They don't need to be in the scene tree.
# The visual representation (UnitVisual) will be a separate Node that
# references this data.


# ===========================================
# IDENTITY
# ===========================================
# Who is this player?

## Display name (e.g., "J. Smith")
var player_name: String = "Unknown"

## Unique identifier (for saving/loading, lookups)
var id: int = -1

## Which team does this player belong to?
var team: Enums.TeamID = Enums.TeamID.HOME

## What position do they play? (determines which zone they're locked to)
var position: Enums.Position = Enums.Position.CENTRE

## Which zone are they restricted to? (derived from position)
var zone: Enums.Zone = Enums.Zone.MIDFIELD


# ===========================================
# LOCATION
# ===========================================
# Where is this player on the field?

## Current grid position (0,0 is top-left of field)
## This is the SOURCE OF TRUTH for where the unit is.
var grid_position: Vector2i = Vector2i(0, 0)

## Target grid position (where they're trying to move to)
## Used by movement system to know the destination.
var target_position: Vector2i = Vector2i(0, 0)

## Is the unit currently moving between cells?
## When true, visual interpolation happens between grid_position and target_position.
var is_moving: bool = false


# ===========================================
# STATS (0-100 scale)
# ===========================================
# Core attributes that affect gameplay.
# 0-20 = Poor, 21-40 = Below Average, 41-60 = Average, 
# 61-80 = Good, 81-100 = Elite

## How fast the player moves (cells per tick at full stamina)
var stat_speed: int = 50

## Kicking accuracy and distance
var stat_kicking: int = 50

## Ability to catch (mark) the ball
var stat_marking: int = 50

## Ability to dispossess opponents (touch tackle effectiveness)
var stat_tackling: int = 50

## Handball accuracy
var stat_handball: int = 50

## Decision making, reading the play, positioning instinct
var stat_awareness: int = 50

## Maximum stamina pool
var stat_stamina: int = 50

## Contested ball situations, holding ground
var stat_strength: int = 50


# ===========================================
# CURRENT STATE
# ===========================================
# What is the player doing RIGHT NOW?

## Current behavioral state
var state: Enums.UnitState = Enums.UnitState.IDLE

## Current stamina (0 to stat_stamina, starts full)
## When this hits 0, player is exhausted and impaired.
var current_stamina: int = 50

## Does this player currently have the ball?
var has_ball: bool = false

## Quality of possession (only relevant if has_ball is true)
var possession_quality: Enums.PossessionQuality = Enums.PossessionQuality.CLEAN

## Current action being performed (if any)
var current_action: Enums.Action = Enums.Action.STAND

## Ticks remaining for current action (some actions take multiple ticks)
var action_ticks_remaining: int = 0


# ===========================================
# ACTION QUEUE / DECISION
# ===========================================
# What has the AI decided this unit should do?

## The action chosen for this tick (set by AIController)
var chosen_action: Enums.Action = Enums.Action.STAND

## Target for the chosen action (e.g., kick target, move destination)
var action_target: Vector2i = Vector2i(0, 0)

## Target unit for the chosen action (e.g., handball recipient, tackle target)
var action_target_unit: Unit = null


# ===========================================
# INITIALIZATION
# ===========================================


## Initialize a new unit with identity and position
## Call this after creating a Unit with Unit.new()
func initialize(p_name: String, p_team: Enums.TeamID, p_position: Enums.Position) -> void:
	player_name = p_name
	team = p_team
	position = p_position
	
	# Derive zone from position
	zone = Enums.get_zone_for_position(position)
	
	# Generate a unique ID (simple incrementing for now)
	id = _generate_id()
	
	# Start with full stamina
	current_stamina = stat_stamina
	
	# Start idle
	state = Enums.UnitState.IDLE
	has_ball = false
	
	Debug.log_debug("Unit", "Initialized: %s (Team %d, %s, Zone %s)" % [
		player_name, 
		team, 
		Enums.Position.keys()[position],
		Enums.Zone.keys()[zone]
	])


## Set all stats at once (useful for creating players from data)
func set_stats(speed: int, kicking: int, marking: int, tackling: int, 
			   handball: int, awareness: int, stamina: int, strength: int) -> void:
	stat_speed = clampi(speed, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_kicking = clampi(kicking, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_marking = clampi(marking, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_tackling = clampi(tackling, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_handball = clampi(handball, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_awareness = clampi(awareness, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_stamina = clampi(stamina, Constants.STAT_MIN, Constants.STAT_MAX)
	stat_strength = clampi(strength, Constants.STAT_MIN, Constants.STAT_MAX)
	
	# Reset current stamina to new max
	current_stamina = stat_stamina


## Set stats from a dictionary (useful for loading from JSON)
func set_stats_from_dict(stats: Dictionary) -> void:
	set_stats(
		stats.get("speed", 50),
		stats.get("kicking", 50),
		stats.get("marking", 50),
		stats.get("tackling", 50),
		stats.get("handball", 50),
		stats.get("awareness", 50),
		stats.get("stamina", 50),
		stats.get("strength", 50)
	)


# ===========================================
# POSITION & MOVEMENT
# ===========================================


## Set the unit's grid position directly (used for initial placement, teleporting)
func set_grid_position(pos: Vector2i) -> void:
	var old_pos = grid_position
	grid_position = pos
	target_position = pos  # Clear any movement target
	is_moving = false
	
	# Emit event for any listeners
	EventBus.unit_moved.emit(self, pos, old_pos)


## Start moving toward a target position
## Returns true if movement started, false if invalid
func start_move_to(target: Vector2i) -> bool:
	# Validate the target is on the field
	if not Constants.is_valid_grid_pos(target):
		Debug.log_warn("Unit", "%s tried to move to invalid position %s" % [player_name, target])
		return false
	
	# Check if target is in our allowed zone
	if not Enums.is_in_correct_zone(target.x, zone, team):
		Debug.log_warn("Unit", "%s cannot move to %s - outside their zone" % [player_name, target])
		return false
	
	target_position = target
	is_moving = true
	state = Enums.UnitState.MOVING
	
	return true


## Called when unit arrives at target position
func arrive_at_target() -> void:
	grid_position = target_position
	is_moving = false
	state = Enums.UnitState.IDLE
	
	EventBus.unit_moved.emit(self, grid_position, grid_position)


## Get the pixel position (center of cell) for rendering
func get_pixel_position() -> Vector2:
	return Constants.grid_to_pixel_center(grid_position)


## Check if this unit is in their correct zone
func is_in_correct_zone() -> bool:
	return Enums.is_in_correct_zone(grid_position.x, zone, team)


# ===========================================
# STAMINA
# ===========================================


## Spend stamina for an action
## Returns true if had enough stamina, false if exhausted
func spend_stamina(amount: int) -> bool:
	var old_stamina = current_stamina
	current_stamina = maxi(0, current_stamina - amount)
	
	# Emit event if significant change
	if abs(old_stamina - current_stamina) >= 5:
		EventBus.unit_stamina_changed.emit(self, current_stamina, old_stamina)
	
	# Check for exhaustion
	if current_stamina <= Constants.STAMINA_EXHAUSTED:
		EventBus.unit_exhausted.emit(self)
		Debug.log_info("Unit", "%s is exhausted! (stamina: %d)" % [player_name, current_stamina])
		return false
	
	return true


## Recover stamina (called when resting)
func recover_stamina(amount: int) -> void:
	var old_stamina = current_stamina
	current_stamina = mini(stat_stamina, current_stamina + amount)
	
	if current_stamina != old_stamina:
		EventBus.unit_stamina_changed.emit(self, current_stamina, old_stamina)


## Check if unit is exhausted
func is_exhausted() -> bool:
	return current_stamina <= Constants.STAMINA_EXHAUSTED


## Get stamina as a percentage (0.0 to 1.0)
func get_stamina_percent() -> float:
	if stat_stamina <= 0:
		return 0.0
	return float(current_stamina) / float(stat_stamina)


# ===========================================
# BALL POSSESSION
# ===========================================


## Give the ball to this unit
func gain_possession(quality: Enums.PossessionQuality = Enums.PossessionQuality.CLEAN) -> void:
	var had_ball = has_ball
	has_ball = true
	possession_quality = quality
	
	if not had_ball:
		Debug.log_info("Unit", "%s gains possession (%s)" % [
			player_name, 
			Enums.PossessionQuality.keys()[quality]
		])


## Remove the ball from this unit
func lose_possession() -> void:
	if has_ball:
		Debug.log_info("Unit", "%s loses possession" % player_name)
	has_ball = false
	possession_quality = Enums.PossessionQuality.CLEAN


# ===========================================
# STATE CHANGES
# ===========================================


## Change the unit's state
func set_state(new_state: Enums.UnitState) -> void:
	if state != new_state:
		var old_state = state
		state = new_state
		EventBus.unit_state_changed.emit(self, new_state, old_state)
		
		Debug.log_debug("Unit", "%s state: %s -> %s" % [
			player_name,
			Enums.UnitState.keys()[old_state],
			Enums.UnitState.keys()[new_state]
		])


# ===========================================
# UTILITY
# ===========================================


## Get distance to another unit (in grid cells)
func distance_to_unit(other: Unit) -> int:
	return Constants.grid_distance(grid_position, other.grid_position)


## Get distance to a grid position
func distance_to_position(pos: Vector2i) -> int:
	return Constants.grid_distance(grid_position, pos)


## Get a summary string (for debugging)
func get_summary() -> String:
	return "%s [%s] @ %s | Stamina:%d%% | Ball:%s | State:%s" % [
		player_name,
		Enums.Position.keys()[position],
		grid_position,
		int(get_stamina_percent() * 100),
		"YES" if has_ball else "no",
		Enums.UnitState.keys()[state]
	]


## Create a dictionary of this unit's data (for saving)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": player_name,
		"team": team,
		"position": position,
		"zone": zone,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"stats": {
			"speed": stat_speed,
			"kicking": stat_kicking,
			"marking": stat_marking,
			"tackling": stat_tackling,
			"handball": stat_handball,
			"awareness": stat_awareness,
			"stamina": stat_stamina,
			"strength": stat_strength,
		},
		"current_stamina": current_stamina,
		"has_ball": has_ball,
	}


# ===========================================
# STATIC HELPERS
# ===========================================

## Counter for generating unique IDs
static var _next_id: int = 1

## Generate a unique ID for a new unit
static func _generate_id() -> int:
	var id = _next_id
	_next_id += 1
	return id


## Reset the ID counter (call when starting a new game)
static func reset_id_counter() -> void:
	_next_id = 1
