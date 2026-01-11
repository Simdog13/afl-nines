# Team.gd
# ============================================
# PURPOSE: Represents a team in the match.
# PRINCIPLE: This is a DATA class - it holds information about a team.
#            It knows WHO is on the team and their SCORE.
#            Rendering and AI logic are handled elsewhere.
# ============================================
# WHAT A TEAM KNOWS:
#   - Identity: team name, team ID
#   - Roster: 9 players (units)
#   - Score: goals and behinds
# ============================================
# HOW TO CREATE A TEAM:
#   var team = Team.new()
#   team.initialize(Enums.TeamID.HOME, "Tigers")
#   team.create_default_players()
# ============================================

class_name Team
extends RefCounted

# We use RefCounted instead of Node because Teams are pure data.
# They don't need to be in the scene tree.


# ===========================================
# IDENTITY
# ===========================================

## Team name (e.g., "Tigers", "Lions")
var team_name: String = "Unknown"

## Which team is this? (HOME or AWAY)
var team_id: Enums.TeamID = Enums.TeamID.HOME


# ===========================================
# ROSTER
# ===========================================

## Array of 9 Unit objects representing the players
var units: Array[Unit] = []


# ===========================================
# SCORING
# ===========================================

## Number of goals scored (6 points each)
var goals: int = 0

## Number of behinds scored (1 point each)
var behinds: int = 0

## Total score (computed property)
var score: int:
	get:
		return goals * 6 + behinds


# ===========================================
# INITIALIZATION
# ===========================================


## Initialize the team with ID and name
func initialize(id: Enums.TeamID, name: String) -> void:
	team_id = id
	team_name = name
	units = []
	goals = 0
	behinds = 0
	Debug.log_info("Team", "%s team initialized (ID: %d)" % [team_name, team_id])


## Create 9 default players for the team
## 3 defenders, 3 midfielders, 3 forwards
func create_default_players() -> void:
	units.clear()

	# Player names for variety
	var names = [
		"Smith", "Jones", "Brown", "Wilson", "Taylor",
		"Davis", "Miller", "Anderson", "Thomas"
	]

	# Create one player for each position
	var positions = [
		# Defenders
		Enums.Position.FULL_BACK,
		Enums.Position.CENTRE_BACK,
		Enums.Position.BACK_FLANKER,
		# Midfielders
		Enums.Position.CENTRE,
		Enums.Position.WING_LEFT,
		Enums.Position.WING_RIGHT,
		# Forwards
		Enums.Position.FULL_FORWARD,
		Enums.Position.CENTRE_FORWARD,
		Enums.Position.FORWARD_FLANKER,
	]

	for i in range(9):
		var unit = Unit.new()
		var player_name = names[i]
		var position = positions[i]

		# Generate random stats (40-80 range for variety)
		var stats = {
			"speed": randi_range(40, 80),
			"kicking": randi_range(40, 80),
			"marking": randi_range(40, 80),
			"tackling": randi_range(40, 80),
			"handball": randi_range(40, 80),
			"awareness": randi_range(40, 80),
			"stamina": randi_range(60, 100),
			"strength": randi_range(40, 80),
		}

		unit.initialize(i, player_name, team_id, position, stats)
		units.append(unit)

	Debug.log_info("Team", "%s: Created %d players" % [team_name, units.size()])


# ===========================================
# SCORING
# ===========================================


## Add a goal (6 points)
func add_goal() -> void:
	goals += 1
	Debug.log_info("Team", "%s scored a GOAL! Total: %s" % [team_name, get_score_string()])


## Add a behind (1 point)
func add_behind() -> void:
	behinds += 1
	Debug.log_info("Team", "%s scored a BEHIND! Total: %s" % [team_name, get_score_string()])


## Reset score to 0-0
func reset_score() -> void:
	goals = 0
	behinds = 0
	Debug.log_info("Team", "%s score reset to 0.0.0" % team_name)


## Get score as a formatted string (e.g., "5.3.33")
## Format is "Goals.Behinds.TotalPoints"
func get_score_string() -> String:
	return "%d.%d.%d" % [goals, behinds, score]


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
