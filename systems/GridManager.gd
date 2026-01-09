# GridManager.gd
# ============================================
# PURPOSE: Manages the playing field grid and spatial queries.
# PRINCIPLE: This is the authority on "where things are" and "where things can go".
#            All position validation goes through here.
# ACCESS: Global singleton via `GridManager.function_name()`
# ============================================
# RESPONSIBILITIES:
#   - Track which cells are occupied by units
#   - Validate movement destinations
#   - Provide pathfinding helpers
#   - Answer spatial queries (who's near X, what's in zone Y)
# ============================================
# GRID LAYOUT (32 x 25):
#
#   Y=0  ┌────────────────────────────────────────┐
#        │  DEFENSIVE  │  MIDFIELD   │  FORWARD   │  (Team HOME perspective)
#        │  (cols 0-10)│ (cols 11-21)│ (cols 22-31)│
#   Y=12 │      ●      │      ●      │      ●     │  ← Center line
#        │   (goal)    │  (center)   │   (goal)   │
#   Y=24 └────────────────────────────────────────┘
#       X=0                X=16                  X=31
#
# ============================================

extends Node


# ===========================================
# OCCUPANCY GRID
# ===========================================
# 2D array tracking which unit (if any) is in each cell.
# Access: _occupancy[x][y] = Unit or null

var _occupancy: Array = []


# ===========================================
# INITIALIZATION
# ===========================================


func _ready() -> void:
	_initialize_grid()
	Debug.log_info("GridManager", "Initialized %dx%d grid (%d cells)" % [
		Constants.GRID_WIDTH, 
		Constants.GRID_HEIGHT,
		Constants.GRID_WIDTH * Constants.GRID_HEIGHT
	])


## Create the empty occupancy grid
func _initialize_grid() -> void:
	_occupancy.clear()
	
	# Create a 2D array: _occupancy[x][y]
	for x in range(Constants.GRID_WIDTH):
		var column: Array = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(null)  # null = empty cell
		_occupancy.append(column)


## Reset the grid (clear all occupancy)
func reset() -> void:
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			_occupancy[x][y] = null
	Debug.log_info("GridManager", "Grid reset - all cells cleared")


# ===========================================
# OCCUPANCY MANAGEMENT
# ===========================================


## Place a unit at a grid position
## Returns true if successful, false if position invalid or occupied
func place_unit(unit, pos: Vector2i) -> bool:
	# Validate position is on the field
	if not is_valid_position(pos):
		Debug.log_warn("GridManager", "Cannot place %s at %s - invalid position" % [unit.player_name, pos])
		return false
	
	# Check if cell is already occupied
	if is_occupied(pos):
		var occupant = get_unit_at(pos)
		Debug.log_warn("GridManager", "Cannot place %s at %s - occupied by %s" % [
			unit.player_name, pos, occupant.player_name if occupant else "unknown"
		])
		return false
	
	# If unit was already placed somewhere, clear that cell first
	var old_pos = unit.grid_position
	if is_valid_position(old_pos) and get_unit_at(old_pos) == unit:
		_occupancy[old_pos.x][old_pos.y] = null
	
	# Place the unit
	_occupancy[pos.x][pos.y] = unit
	unit.set_grid_position(pos)
	
	Debug.log_debug("GridManager", "Placed %s at %s" % [unit.player_name, pos])
	return true


## Remove a unit from the grid (doesn't delete the unit, just clears occupancy)
func remove_unit(unit) -> void:
	var pos = unit.grid_position
	if is_valid_position(pos) and get_unit_at(pos) == unit:
		_occupancy[pos.x][pos.y] = null
		Debug.log_debug("GridManager", "Removed %s from %s" % [unit.player_name, pos])


## Move a unit from current position to new position
## Returns true if successful
func move_unit(unit, new_pos: Vector2i) -> bool:
	var old_pos = unit.grid_position
	
	# Validate new position
	if not is_valid_position(new_pos):
		Debug.log_warn("GridManager", "%s cannot move to %s - invalid position" % [unit.player_name, new_pos])
		return false
	
	# Check if new position is occupied (by someone else)
	var occupant = get_unit_at(new_pos)
	if occupant != null and occupant != unit:
		Debug.log_warn("GridManager", "%s cannot move to %s - occupied by %s" % [
			unit.player_name, new_pos, occupant.player_name
		])
		return false
	
	# Check zone restriction
	if not Enums.is_in_correct_zone(new_pos.x, unit.zone, unit.team):
		Debug.log_warn("GridManager", "%s cannot move to %s - outside their %s zone" % [
			unit.player_name, new_pos, Enums.Zone.keys()[unit.zone]
		])
		return false
	
	# Clear old position
	if is_valid_position(old_pos) and get_unit_at(old_pos) == unit:
		_occupancy[old_pos.x][old_pos.y] = null
	
	# Set new position
	_occupancy[new_pos.x][new_pos.y] = unit
	unit.set_grid_position(new_pos)
	
	Debug.log_debug("GridManager", "%s moved: %s -> %s" % [unit.player_name, old_pos, new_pos])
	return true


# ===========================================
# QUERIES - BASIC
# ===========================================


## Check if a position is within field bounds
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < Constants.GRID_WIDTH and \
		   pos.y >= 0 and pos.y < Constants.GRID_HEIGHT


## Check if a cell is occupied
func is_occupied(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	return _occupancy[pos.x][pos.y] != null


## Get the unit at a position (or null if empty)
func get_unit_at(pos: Vector2i) -> Unit:
	if not is_valid_position(pos):
		return null
	return _occupancy[pos.x][pos.y]


## Check if a cell is empty and valid
func is_cell_free(pos: Vector2i) -> bool:
	return is_valid_position(pos) and not is_occupied(pos)


# ===========================================
# QUERIES - DISTANCE
# ===========================================


## Get Manhattan distance between two positions
func get_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)


## Get Euclidean (straight-line) distance
func get_distance_euclidean(from: Vector2i, to: Vector2i) -> float:
	return Vector2(from).distance_to(Vector2(to))


## Check if two positions are adjacent (including diagonals)
func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return dx <= 1 and dy <= 1 and (dx + dy) > 0


# ===========================================
# QUERIES - NEIGHBORS
# ===========================================


## Get all valid adjacent cells (including diagonals)
func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip self
			
			var neighbor = Vector2i(pos.x + dx, pos.y + dy)
			if is_valid_position(neighbor):
				neighbors.append(neighbor)
	
	return neighbors


## Get all valid adjacent cells that are empty
func get_free_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	
	for neighbor in get_neighbors(pos):
		if not is_occupied(neighbor):
			free.append(neighbor)
	
	return free


## Get all valid adjacent cells within a unit's zone
func get_valid_moves_for_unit(unit) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	
	for neighbor in get_neighbors(unit.grid_position):
		# Must be empty
		if is_occupied(neighbor):
			continue
		# Must be in unit's allowed zone
		if not Enums.is_in_correct_zone(neighbor.x, unit.zone, unit.team):
			continue
		valid.append(neighbor)
	
	return valid


# ===========================================
# QUERIES - SPATIAL SEARCHES
# ===========================================


## Find all units within a radius of a position
func get_units_in_radius(center: Vector2i, radius: int, team_filter: Enums.TeamID = Enums.TeamID.NONE) -> Array[Unit]:
	var units: Array[Unit] = []
	
	# Search in a square around the center, then filter by actual distance
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var pos = Vector2i(x, y)
			if not is_valid_position(pos):
				continue
			if get_distance(center, pos) > radius:
				continue
			
			var unit = get_unit_at(pos)
			if unit != null:
				# Apply team filter if specified
				if team_filter == Enums.TeamID.NONE or unit.team == team_filter:
					units.append(unit)
	
	return units


## Find the nearest unit to a position
func get_nearest_unit(pos: Vector2i, team_filter: Enums.TeamID = Enums.TeamID.NONE, exclude = null) -> Unit:
	var nearest = null
	var nearest_dist: int = 9999
	
	# Scan the entire grid (could optimize with spatial partitioning later)
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			var unit = _occupancy[x][y]
			if unit == null:
				continue
			if unit == exclude:
				continue
			if team_filter != Enums.TeamID.NONE and unit.team != team_filter:
				continue
			
			var dist = get_distance(pos, Vector2i(x, y))
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = unit
	
	return nearest


## Find all units in a specific zone
func get_units_in_zone(zone: Enums.Zone, team_filter: Enums.TeamID = Enums.TeamID.NONE) -> Array[Unit]:
	var units: Array[Unit] = []
	
	# Determine x range for the zone
	var x_min: int
	var x_max: int
	
	match zone:
		Enums.Zone.DEFENSIVE:
			x_min = Constants.ZONE_DEFENSIVE_START
			x_max = Constants.ZONE_DEFENSIVE_END
		Enums.Zone.MIDFIELD:
			x_min = Constants.ZONE_MIDFIELD_START
			x_max = Constants.ZONE_MIDFIELD_END
		Enums.Zone.FORWARD:
			x_min = Constants.ZONE_FORWARD_START
			x_max = Constants.ZONE_FORWARD_END
	
	for x in range(x_min, x_max + 1):
		for y in range(Constants.GRID_HEIGHT):
			var unit = _occupancy[x][y]
			if unit != null:
				if team_filter == Enums.TeamID.NONE or unit.team == team_filter:
					units.append(unit)
	
	return units


# ===========================================
# ZONE HELPERS
# ===========================================


## Get the zone for a given x coordinate (from HOME team perspective)
func get_zone_at(x: int) -> Enums.Zone:
	if x <= Constants.ZONE_DEFENSIVE_END:
		return Enums.Zone.DEFENSIVE
	elif x <= Constants.ZONE_MIDFIELD_END:
		return Enums.Zone.MIDFIELD
	else:
		return Enums.Zone.FORWARD


## Get the x-coordinate boundaries for a zone
func get_zone_bounds(zone: Enums.Zone) -> Vector2i:
	match zone:
		Enums.Zone.DEFENSIVE:
			return Vector2i(Constants.ZONE_DEFENSIVE_START, Constants.ZONE_DEFENSIVE_END)
		Enums.Zone.MIDFIELD:
			return Vector2i(Constants.ZONE_MIDFIELD_START, Constants.ZONE_MIDFIELD_END)
		Enums.Zone.FORWARD:
			return Vector2i(Constants.ZONE_FORWARD_START, Constants.ZONE_FORWARD_END)
	return Vector2i(0, Constants.GRID_WIDTH - 1)


## Get the center position of a zone
func get_zone_center(zone: Enums.Zone) -> Vector2i:
	var bounds = get_zone_bounds(zone)
	var center_x = (bounds.x + bounds.y) / 2
	var center_y = Constants.GRID_HEIGHT / 2
	return Vector2i(center_x, center_y)


# ===========================================
# PATHFINDING - SIMPLE
# ===========================================


## Get the best next step toward a target (simple greedy approach)
## Returns the adjacent cell that gets closest to target, or current pos if stuck
func get_step_toward(from: Vector2i, to: Vector2i, unit = null) -> Vector2i:
	var best_pos = from
	var best_dist = get_distance(from, to)
	
	for neighbor in get_neighbors(from):
		# Must be free
		if is_occupied(neighbor):
			continue
		
		# If unit provided, must be in their zone
		if unit != null and not Enums.is_in_correct_zone(neighbor.x, unit.zone, unit.team):
			continue
		
		var dist = get_distance(neighbor, to)
		if dist < best_dist:
			best_dist = dist
			best_pos = neighbor
	
	return best_pos


## Get a path toward a target (simple greedy, not optimal)
## Returns array of positions to move through
## max_steps limits how far to look ahead
func get_path_toward(from: Vector2i, to: Vector2i, unit = null, max_steps: int = 10) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = from
	
	for i in range(max_steps):
		if current == to:
			break
		
		var next = get_step_toward(current, to, unit)
		if next == current:
			break  # Stuck, can't get closer
		
		path.append(next)
		current = next
	
	return path


# ===========================================
# DEBUG
# ===========================================


## Print grid state to debug log
func print_occupancy() -> void:
	Debug.log_section("Grid Occupancy")
	
	var occupied_count = 0
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if _occupancy[x][y] != null:
				var unit = _occupancy[x][y]
				Debug.log_debug("GridManager", "  (%d, %d): %s" % [x, y, unit.player_name])
				occupied_count += 1
	
	Debug.log_info("GridManager", "Total occupied: %d / %d cells" % [
		occupied_count, 
		Constants.GRID_WIDTH * Constants.GRID_HEIGHT
	])


## Get a simple ASCII representation of the grid (for debugging)
func get_ascii_grid() -> String:
	var output = ""
	
	for y in range(Constants.GRID_HEIGHT):
		var row = ""
		for x in range(Constants.GRID_WIDTH):
			var unit = _occupancy[x][y]
			if unit == null:
				# Show zone boundaries
				if x == Constants.ZONE_DEFENSIVE_END or x == Constants.ZONE_MIDFIELD_END:
					row += "|"
				else:
					row += "."
			else:
				# Show team: H for home, A for away
				row += "H" if unit.team == Enums.TeamID.HOME else "A"
		output += row + "\n"
	
	return output
