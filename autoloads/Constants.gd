# Constants.gd
# ============================================
# PURPOSE: Single source of truth for ALL game configuration values.
# PRINCIPLE: No magic numbers anywhere else in the codebase. If you need
#            to change a value (grid size, timing, positions), do it HERE.
# ACCESS: Global singleton via `Constants.VALUE_NAME` from any script.
# ============================================
# HOW TO USE:
#   1. Add this script to Project → Project Settings → Autoload
#   2. Name it "Constants" (no quotes)
#   3. Access values anywhere: var cell = Constants.CELL_SIZE
# ============================================

extends Node

# ===========================================
# GRID CONFIGURATION
# ===========================================
# The playing field is divided into a grid of cells.
# All game logic works in grid coordinates (0,0 to 31,24).
# Pixel positions are only calculated for rendering.

# Grid dimensions in cells
# 32 wide × 25 tall = 800 total cells
# This maps roughly to AFL field proportions (~150m × 120m)
const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 25

# Size of each cell in pixels
# 64px gives us a 2048×1600 pixel field, which fits nicely on modern screens
const CELL_SIZE: int = 64

# Calculated pixel dimensions (for reference - don't change these directly)
# FIELD_PIXEL_WIDTH = 32 × 64 = 2048 pixels
# FIELD_PIXEL_HEIGHT = 25 × 64 = 1600 pixels
const FIELD_PIXEL_WIDTH: int = GRID_WIDTH * CELL_SIZE   # 2048
const FIELD_PIXEL_HEIGHT: int = GRID_HEIGHT * CELL_SIZE  # 1600

# Center of the field (for ball-ups, center bounces)
# Integer division: 32/2 = 16, 25/2 = 12
const FIELD_CENTER_X: int = GRID_WIDTH / 2   # 16
const FIELD_CENTER_Y: int = GRID_HEIGHT / 2  # 12


# ===========================================
# ZONE BOUNDARIES
# ===========================================
# AFL Nines uses strict zones: players cannot leave their assigned zone.
# The field is divided into thirds along the X-axis.
#
# Visual representation (Team 0 attacks RIGHT →):
#
#    DEFENSIVE        MIDFIELD         FORWARD
#    (Team 0)                          (Team 0)
#   ←――――――――→      ←――――――――→       ←――――――――→
#   Cols 0-10       Cols 11-21       Cols 22-31
#
# For Team 1, the zones are mirrored:
#   Their FORWARD is cols 0-10, their DEFENSIVE is cols 22-31

# Zone X boundaries (inclusive)
# Defensive zone: columns 0 through 10 (11 columns)
const ZONE_DEFENSIVE_START: int = 0
const ZONE_DEFENSIVE_END: int = 10

# Midfield zone: columns 11 through 21 (11 columns)
const ZONE_MIDFIELD_START: int = 11
const ZONE_MIDFIELD_END: int = 21

# Forward zone: columns 22 through 31 (10 columns)
const ZONE_FORWARD_START: int = 22
const ZONE_FORWARD_END: int = 31


# ===========================================
# GOAL POSITIONS
# ===========================================
# Goals are at the left and right edges of the field.
# The goal area is centered vertically (around row 12).
#
# Goal structure (viewed from above):
#   [Behind Post] [GOAL] [GOAL] [GOAL] [Behind Post]
#
# A kick through the middle 3 cells = Goal (6 points)
# A kick through the outer cells = Behind (1 point)

# Team 0 scores on the RIGHT side (x = 31)
const GOAL_RIGHT_X: int = 31
# Team 1 scores on the LEFT side (x = 0)
const GOAL_LEFT_X: int = 0

# Vertical range for scoring (rows where goals/behinds can be scored)
# Center of field is row 12, goals span rows 10-14 (5 rows)
const GOAL_Y_MIN: int = 10
const GOAL_Y_MAX: int = 14

# The center 3 rows are "goal" (6 points), outer 2 are "behind" (1 point)
const GOAL_CENTER_Y_MIN: int = 11  # Rows 11, 12, 13 = goal
const GOAL_CENTER_Y_MAX: int = 13


# ===========================================
# TEAM CONFIGURATION
# ===========================================
# AFL Nines format: 9 players per team
# 3 Defenders + 3 Midfielders + 3 Forwards

const PLAYERS_PER_TEAM: int = 9
const DEFENDERS_PER_TEAM: int = 3
const MIDFIELDERS_PER_TEAM: int = 3
const FORWARDS_PER_TEAM: int = 3

# Team identifiers
const TEAM_HOME: int = 0  # Team 0 - attacks RIGHT, defends LEFT
const TEAM_AWAY: int = 1  # Team 1 - attacks LEFT, defends RIGHT


# ===========================================
# MATCH TIMING
# ===========================================
# AFL Nines uses 2 halves of 20 minutes each (real AFL Nines).
# For our simulation, we'll use shorter quarters for faster testing.
# 
# We measure time in SIMULATION SECONDS, then scale to real-time.
# Example: 180 sim seconds at 1.0 speed = 3 real minutes

# Quarter duration in simulation seconds
# 180 seconds = 3 minutes of real time at 1x speed
# Can be adjusted for testing (try 60 for quick tests)
const QUARTER_DURATION_SECONDS: float = 180.0

# Number of quarters (standard AFL = 4, AFL Nines = 2 halves, we'll use 4 for now)
const QUARTERS_PER_MATCH: int = 4

# Break durations (in real seconds, not sim seconds)
const QUARTER_BREAK_DURATION: float = 5.0   # Brief pause between Q1-Q2, Q3-Q4
const HALF_TIME_DURATION: float = 10.0       # Longer pause at half time


# ===========================================
# SIMULATION TIMING
# ===========================================
# The simulation runs in discrete "ticks" rather than continuous time.
# Each tick, every unit gets to make a decision and act.
#
# TICKS_PER_SECOND controls game speed:
#   - Higher = faster, more fluid, harder to follow
#   - Lower = slower, more readable, easier to debug
#
# At 2 ticks/second, a 180-second quarter = 360 ticks total

# How many simulation ticks occur per real-world second (at 1x speed)
const TICKS_PER_SECOND: float = 2.0

# Calculated: how many real seconds between ticks
# At 2 ticks/second, this is 0.5 seconds between ticks
const SECONDS_PER_TICK: float = 1.0 / TICKS_PER_SECOND

# Simulation seconds that pass per tick
# This controls how fast the match clock runs relative to ticks
# At 1.0, each tick = 1 sim second, so 180 ticks = 180 sim seconds = full quarter
const SIM_SECONDS_PER_TICK: float = 1.0

# Speed multipliers for fast-forward
const SPEED_NORMAL: float = 1.0
const SPEED_FAST: float = 2.0
const SPEED_FASTER: float = 4.0


# ===========================================
# PLAYER STATS - DEFAULTS
# ===========================================
# Stats use a 0-100 scale where:
#   0-20  = Poor
#   21-40 = Below Average  
#   41-60 = Average
#   61-80 = Good
#   81-100 = Elite
#
# These are DEFAULT values. Individual players will have variations.

const STAT_MIN: int = 0
const STAT_MAX: int = 100
const STAT_DEFAULT: int = 50

# Stamina costs per action (deducted from current stamina)
# Higher = more tiring
const STAMINA_COST_MOVE: int = 2
const STAMINA_COST_KICK: int = 8
const STAMINA_COST_HANDBALL: int = 4
const STAMINA_COST_TACKLE: int = 10
const STAMINA_COST_MARK: int = 6
const STAMINA_COST_REST: int = -5  # Negative = recovery

# Stamina thresholds
const STAMINA_EXHAUSTED: int = 20  # Below this, player is impaired
const STAMINA_RECOVERY_RATE: int = 5  # Per tick when resting


# ===========================================
# BALL PHYSICS
# ===========================================
# Simplified physics for the ball.
# Distances are in grid cells (not pixels).

# Maximum kick distance (in grid cells)
# Elite kicker at full power can kick ~15 cells
const KICK_DISTANCE_MAX: int = 15

# Handball distance (much shorter)
const HANDBALL_DISTANCE_MAX: int = 4

# Ball speed when kicked (cells per tick)
# A kick travels at 3 cells/tick, so a 15-cell kick takes 5 ticks
const BALL_SPEED_KICK: float = 3.0

# Ball speed when handballed
const BALL_SPEED_HANDBALL: float = 2.0


# ===========================================
# ACTION DISTANCES
# ===========================================
# How close do you need to be to perform certain actions?
# Measured in grid cells.

# Distance to attempt a tackle (adjacent = 1 cell away)
const TACKLE_RANGE: int = 1

# Distance to attempt a mark (catch a kicked ball)
# Player must be within this range of ball's landing spot
const MARK_RANGE: int = 1

# Distance at which ball pickup is automatic
const PICKUP_RANGE: int = 0  # Must be on same cell


# ===========================================
# UTILITY FUNCTIONS
# ===========================================
# These helper functions convert between grid and pixel coordinates.
# Call them as: Constants.grid_to_pixel(Vector2i(5, 10))

## Converts a grid coordinate to pixel coordinate (top-left of cell)
static func grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)


## Converts a grid coordinate to pixel coordinate (center of cell)
static func grid_to_pixel_center(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2,
		grid_pos.y * CELL_SIZE + CELL_SIZE / 2
	)


## Converts a pixel coordinate to grid coordinate
static func pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pixel_pos.x / CELL_SIZE),
		int(pixel_pos.y / CELL_SIZE)
	)


## Checks if a grid position is within the field bounds
static func is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and
		grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT
	)


## Calculates Manhattan distance between two grid positions
## (Manhattan = only horizontal + vertical movement, no diagonals)
## Used for quick distance checks
static func grid_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)


## Calculates actual Euclidean distance between two grid positions
## More accurate but slightly slower than Manhattan
static func grid_distance_euclidean(from: Vector2i, to: Vector2i) -> float:
	return from.distance_to(to)
