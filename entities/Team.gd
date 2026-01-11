# Team.gd
# ============================================
# PURPOSE: Represents a team in the AFL Nines match.
# PRINCIPLE: This is a DATA class - it holds team information and manages players.
#            It knows the team's identity, roster, and score.
# ============================================
# WHAT A TEAM KNOWS:
#   - Identity: team name, team ID (HOME/AWAY)
#   - Roster: array of 9 Unit objects (3 defenders, 3 midfielders, 3 forwards)
#   - Score: goals and behinds scored
#   - Positioning: where players start for center bounces
# ============================================
# HOW TO CREATE A TEAM:
#   var team = Team.new()
#   team.initialize(Enums.TeamID.HOME, "Tigers")
#   team.create_default_players()
#   team.set_starting_positions()
# ============================================

class_name Team
extends RefCounted

# We use RefCounted instead of Node because Teams are pure data.
# They don't need to be in the scene tree.


# ===========================================
# IDENTITY
# ===========================================

## Team ID (HOME or AWAY)
var team_id: Enums.TeamID = Enums.TeamID.HOME

## Display name for the team
var team_name: String = "Unknown"


# ===========================================
# ROSTER
# ===========================================

## Array of all 9 players on this team
var units: Array[Unit] = []


# ===========================================
# SCORE
# ===========================================

## Number of goals scored (6 points each)
var goals: int = 0

## Number of behinds scored (1 point each)
var behinds: int = 0


# ===========================================
# INITIALIZATION
# ===========================================

## Initialize the team with an ID and name
func initialize(p_team_id: Enums.TeamID, p_team_name: String) -> void:
	team_id = p_team_id
	team_name = p_team_name
	units = []
	goals = 0
	behinds = 0

	Debug.log_info("Team", "Initialized team: %s (ID: %s)" % [
		team_name,
		Enums.TeamID.keys()[team_id]
	])


## Create 9 default players with standard positions and stats
## Creates 3 defenders, 3 midfielders, 3 forwards
func create_default_players() -> void:
	# Clear existing players
	units.clear()

	# Create defenders
	_create_player("Defender 1", Enums.Position.FULL_BACK)
	_create_player("Defender 2", Enums.Position.CENTRE_BACK)
	_create_player("Defender 3", Enums.Position.BACK_FLANKER)

	# Create midfielders
	_create_player("Midfielder 1", Enums.Position.CENTRE)
	_create_player("Midfielder 2", Enums.Position.WING_LEFT)
	_create_player("Midfielder 3", Enums.Position.WING_RIGHT)

	# Create forwards
	_create_player("Forward 1", Enums.Position.FULL_FORWARD)
	_create_player("Forward 2", Enums.Position.CENTRE_FORWARD)
	_create_player("Forward 3", Enums.Position.FORWARD_FLANKER)

	Debug.log_info("Team", "%s: Created %d players" % [team_name, units.size()])


## Helper to create a single player with default stats
func _create_player(name: String, position: Enums.Position) -> void:
	var unit = Unit.new()
	unit.initialize(name, team_id, position)

	# Set default stats (50 = average for all stats)
	# In a real game, you'd load these from a roster file or randomize
	unit.set_stats(
		50,  # speed
		50,  # kicking
		50,  # marking
		50,  # tackling
		50,  # handball
		50,  # awareness
		50,  # stamina
		50   # strength
	)

	units.append(unit)


# ===========================================
# SCORING
# ===========================================

## Add a goal (6 points)
func add_goal() -> void:
	goals += 1
	Debug.log_info("Team", "%s GOAL! Score: %s" % [team_name, get_score_string()])
	EventBus.score_registered.emit(team_id, 6)


## Add a behind (1 point)
func add_behind() -> void:
	behinds += 1
	Debug.log_info("Team", "%s Behind. Score: %s" % [team_name, get_score_string()])
	EventBus.score_registered.emit(team_id, 1)


## Reset the score to 0-0
func reset_score() -> void:
	goals = 0
	behinds = 0
	Debug.log_debug("Team", "%s: Score reset" % team_name)


## Get the score in AFL format: "G.B.Total" (e.g., "3.4.22")
func get_score_string() -> String:
	return "%d.%d.%d" % [goals, behinds, get_score()]


## Get the total score (goals × 6 + behinds × 1)
func get_score() -> int:
	return goals * 6 + behinds


# ===========================================
# POSITIONING
# ===========================================

## Place all units at their starting positions for a center bounce
## HOME attacks right (toward x=31), AWAY attacks left (toward x=0)
## Players are placed in their zones with realistic AFL positioning
func set_starting_positions() -> void:
	# Y positions (field is 25 cells tall, so 0-24)
	# Spread players vertically across the field
	var y_top = 6
	var y_mid = 12
	var y_bot = 18

	# Position each unit based on their role and team
	for unit in units:
		var pos = Vector2i(0, 0)

		if team_id == Enums.TeamID.HOME:
			# HOME team attacks RIGHT (toward x=31)
			# Defenders on left (low x), Forwards on right (high x)
			match unit.position:
				# Defenders - in defensive zone (x 0-10), offset from AWAY forwards
				Enums.Position.FULL_BACK:
					pos = Vector2i(3, y_mid)      # Deep, center
				Enums.Position.CENTRE_BACK:
					pos = Vector2i(6, y_mid - 2)  # Higher up, slightly off center
				Enums.Position.BACK_FLANKER:
					pos = Vector2i(5, y_bot)      # Flank position

				# Midfielders - in midfield zone (x 11-21)
				Enums.Position.CENTRE:
					pos = Vector2i(15, y_mid)     # Near center, ready for bounce
				Enums.Position.WING_LEFT:
					pos = Vector2i(13, y_top)     # Left wing
				Enums.Position.WING_RIGHT:
					pos = Vector2i(13, y_bot)     # Right wing

				# Forwards - in forward zone (x 22-31), offset from AWAY defenders
				Enums.Position.FULL_FORWARD:
					pos = Vector2i(28, y_mid)     # Deep forward, center
				Enums.Position.CENTRE_FORWARD:
					pos = Vector2i(25, y_mid + 2) # Leading forward
				Enums.Position.FORWARD_FLANKER:
					pos = Vector2i(26, y_top)     # Forward flank

		else:
			# AWAY team attacks LEFT (toward x=0)
			# Defenders on right (high x), Forwards on left (low x)
			match unit.position:
				# Defenders - in defensive zone (right side for AWAY)
				Enums.Position.FULL_BACK:
					pos = Vector2i(28, y_mid)     # Deep, center
				Enums.Position.CENTRE_BACK:
					pos = Vector2i(25, y_mid + 2) # Higher up, offset from HOME forward
				Enums.Position.BACK_FLANKER:
					pos = Vector2i(26, y_top)     # Flank, offset from HOME flanker

				# Midfielders - in midfield zone (x 11-21)
				Enums.Position.CENTRE:
					pos = Vector2i(16, y_mid)     # Near center, opposite HOME centre
				Enums.Position.WING_LEFT:
					pos = Vector2i(18, y_top)     # Wing positions offset from HOME
				Enums.Position.WING_RIGHT:
					pos = Vector2i(18, y_bot)

				# Forwards - in forward zone (left side for AWAY)
				Enums.Position.FULL_FORWARD:
					pos = Vector2i(3, y_mid)      # Deep forward - offset from HOME defender
				Enums.Position.CENTRE_FORWARD:
					pos = Vector2i(6, y_mid + 2)  # Offset from HOME centre back
				Enums.Position.FORWARD_FLANKER:
					pos = Vector2i(5, y_bot)      # Offset from HOME flanker

		unit.set_grid_position(pos)

	Debug.log_info("Team", "%s: All players positioned for center bounce" % team_name)


# ===========================================
# UTILITY
# ===========================================

## Get a unit by position
func get_unit_by_position(position: Enums.Position) -> Unit:
	for unit in units:
		if unit.position == position:
			return unit
	return null


## Get all units in a specific zone
func get_units_in_zone(zone: Enums.Zone) -> Array[Unit]:
	var zone_units: Array[Unit] = []
	for unit in units:
		if unit.zone == zone:
			zone_units.append(unit)
	return zone_units


## Get summary of team state (for debugging)
func get_summary() -> String:
	return "%s (%s) - Score: %s - Players: %d" % [
		team_name,
		Enums.TeamID.keys()[team_id],
		get_score_string(),
		units.size()
	]


## Create a dictionary of team data (for saving)
func to_dict() -> Dictionary:
	var units_data = []
	for unit in units:
		units_data.append(unit.to_dict())

	return {
		"team_id": team_id,
		"team_name": team_name,
		"goals": goals,
		"behinds": behinds,
		"units": units_data
	}
