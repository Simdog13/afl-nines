# Team.gd
# ============================================
# PURPOSE: Represents a team in the AFL Nines match.
# PRINCIPLE: This is a DATA class - it holds team information and player roster.
#            Manages team score (goals, behinds, total points).
# ============================================
# WHAT A TEAM KNOWS:
#   - Identity: team ID, team name
#   - Roster: collection of units (players)
#   - Score: goals, behinds, total points
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

## Which team is this? (HOME or AWAY)
var team_id: Enums.TeamID = Enums.TeamID.HOME

## Display name (e.g., "Tigers", "Lions")
var team_name: String = "Unknown"


# ===========================================
# ROSTER
# ===========================================

## All players on this team (should be 9 for AFL Nines)
var units: Array[Unit] = []


# ===========================================
# SCORE
# ===========================================

## Number of goals scored (6 points each)
var goals: int = 0

## Number of behinds scored (1 point each)
var behinds: int = 0

## Total score (computed from goals and behinds)
var score: int = 0


# ===========================================
# INITIALIZATION
# ===========================================

## Initialize the team with basic info
func initialize(p_team_id: Enums.TeamID, p_team_name: String) -> void:
	team_id = p_team_id
	team_name = p_team_name
	units = []
	goals = 0
	behinds = 0
	score = 0

	Debug.log_info("Team", "Team initialized: %s (%s)" % [
		team_name,
		"HOME" if team_id == Enums.TeamID.HOME else "AWAY"
	])


## Create 9 default players with positions for AFL Nines
func create_default_players() -> void:
	# Define the 9 positions for AFL Nines (3 defenders, 3 mids, 3 forwards)
	var positions = [
		# Defenders (3)
		Enums.Position.FULL_BACK,
		Enums.Position.CENTRE_BACK,
		Enums.Position.BACK_FLANKER,
		# Midfielders (3)
		Enums.Position.CENTRE,
		Enums.Position.WING_LEFT,
		Enums.Position.WING_RIGHT,
		# Forwards (3)
		Enums.Position.FULL_FORWARD,
		Enums.Position.CENTRE_FORWARD,
		Enums.Position.FORWARD_FLANKER,
	]

	# Create a unit for each position
	for i in range(positions.size()):
		var unit = Unit.new()
		var player_name = "%s Player %d" % [team_name, i + 1]
		unit.initialize(player_name, team_id, positions[i])
		units.append(unit)

	# Position all players at their starting positions
	set_starting_positions()

	Debug.log_info("Team", "%s: Created %d players" % [team_name, units.size()])


# ===========================================
# SCORING
# ===========================================

## Add a goal (6 points)
func add_goal() -> void:
	goals += 1
	_update_score()
	Debug.log_info("Team", "%s scored a GOAL! Score: %s" % [team_name, get_score_string()])


## Add a behind (1 point)
func add_behind() -> void:
	behinds += 1
	_update_score()
	Debug.log_info("Team", "%s scored a behind. Score: %s" % [team_name, get_score_string()])


## Reset score to 0-0
func reset_score() -> void:
	goals = 0
	behinds = 0
	score = 0
	Debug.log_info("Team", "%s: Score reset" % team_name)


## Recalculate total score from goals and behinds
func _update_score() -> void:
	score = (goals * 6) + behinds


## Get formatted score string (e.g., "3.5 (23)")
## Format: GOALS.BEHINDS (TOTAL)
func get_score_string() -> String:
	return "%d.%d (%d)" % [goals, behinds, score]


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
				# Defenders - in defensive zone (x 0-10)
				Enums.Position.FULL_BACK:
					pos = Vector2i(3, y_mid)      # Deep, center
				Enums.Position.CENTRE_BACK:
					pos = Vector2i(6, y_mid - 2)  # Higher up, slightly off center
				Enums.Position.BACK_FLANKER:
					pos = Vector2i(5, y_bot)      # Flank position

				# Midfielders - in midfield zone (x 11-21)
				Enums.Position.CENTRE:
					pos = Vector2i(14, y_mid)     # Near center, ready for bounce
				Enums.Position.WING_LEFT:
					pos = Vector2i(12, y_top)     # Left wing
				Enums.Position.WING_RIGHT:
					pos = Vector2i(12, y_bot)     # Right wing

				# Forwards - in forward zone (x 22-31)
				Enums.Position.FULL_FORWARD:
					pos = Vector2i(27, y_mid)     # Deep forward, center
				Enums.Position.CENTRE_FORWARD:
					pos = Vector2i(24, y_mid + 2) # Leading forward
				Enums.Position.FORWARD_FLANKER:
					pos = Vector2i(25, y_top)     # Forward flank

		else:
			# AWAY team attacks LEFT (toward x=0)
			# Defenders on right (high x), Forwards on left (low x)
			match unit.position:
				# Defenders - in defensive zone (right side for AWAY, x 22-31)
				Enums.Position.FULL_BACK:
					pos = Vector2i(28, y_mid)     # Deep, center
				Enums.Position.CENTRE_BACK:
					pos = Vector2i(25, y_mid - 2) # Higher up
				Enums.Position.BACK_FLANKER:
					pos = Vector2i(26, y_bot)     # Flank

				# Midfielders - in midfield zone (x 11-21)
				Enums.Position.CENTRE:
					pos = Vector2i(17, y_mid)     # Near center, opposite HOME centre
				Enums.Position.WING_LEFT:
					pos = Vector2i(19, y_top)     # Wing positions offset from HOME
				Enums.Position.WING_RIGHT:
					pos = Vector2i(19, y_bot)

				# Forwards - in forward zone (left side for AWAY, x 0-10)
				Enums.Position.FULL_FORWARD:
					pos = Vector2i(4, y_mid)      # Deep forward
				Enums.Position.CENTRE_FORWARD:
					pos = Vector2i(7, y_mid + 2)  # Leading forward
				Enums.Position.FORWARD_FLANKER:
					pos = Vector2i(6, y_top)      # Forward flank

		unit.set_grid_position(pos)

	Debug.log_info("Team", "%s: All players positioned for center bounce" % team_name)
