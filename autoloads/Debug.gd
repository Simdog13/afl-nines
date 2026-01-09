# Debug.gd
# ============================================
# PURPOSE: Centralized logging and debugging tools.
# PRINCIPLE: All debug output goes through here. We can filter by level,
#            enable/disable categories, and format output consistently.
# ACCESS: Global singleton via `Debug.log_info("Context", "Message")`
# ============================================
# HOW TO USE:
#   1. Add this script to Project → Project Settings → Autoload
#   2. Name it "Debug" (no quotes)
#   3. Call from anywhere:
#        Debug.log_info("GameManager", "Simulation started")
#        Debug.log_warn("BallManager", "Ball went out of bounds")
#        Debug.log_error("Unit", "Invalid action attempted")
#        Debug.log_debug("AI", "Evaluating options...")
# ============================================
# LOG LEVELS (from most to least severe):
#   ERROR - Something broke, needs immediate attention
#   WARN  - Something unusual, might indicate a problem
#   INFO  - Normal operations, useful for understanding flow
#   DEBUG - Detailed internals, usually too noisy for normal use
# ============================================

extends Node


# ===========================================
# CONFIGURATION
# ===========================================

## Log level enum - controls which messages are printed
enum LogLevel {
	ERROR = 0,  # Only errors
	WARN = 1,   # Errors and warnings
	INFO = 2,   # Errors, warnings, and info (recommended for development)
	DEBUG = 3,  # Everything (very verbose, good for debugging specific issues)
}

## Current log level - messages at or below this level are printed
## Change this to filter output (higher = more messages)
@export var current_level: LogLevel = LogLevel.INFO

## Master switch to disable all logging
## Set to false to silence all debug output (e.g., for release builds)
@export var logging_enabled: bool = true

## Show timestamps in log messages
@export var show_timestamps: bool = true

## Show tick number in log messages (when simulation is running)
@export var show_tick_number: bool = true

## Categories that are muted (won't print regardless of level)
## Add category names here to silence specific systems
## Example: muted_categories = ["AI", "BallPhysics"]
var muted_categories: Array[String] = []


# ===========================================
# COLOR CODES
# ===========================================
# BBCode colors for different log levels.
# These make output easier to scan in Godot's Output panel.

const COLORS = {
	LogLevel.ERROR: "#FF6B6B",  # Soft red
	LogLevel.WARN:  "#FFE66D",  # Yellow
	LogLevel.INFO:  "#4ECDC4",  # Teal
	LogLevel.DEBUG: "#95A5A6",  # Gray
}

const LEVEL_NAMES = {
	LogLevel.ERROR: "ERROR",
	LogLevel.WARN:  "WARN ",
	LogLevel.INFO:  "INFO ",
	LogLevel.DEBUG: "DEBUG",
}


# ===========================================
# STATE TRACKING
# ===========================================
# Track the current tick for logging context.
# This is updated by GameManager each tick.

var _current_tick: int = 0


# ===========================================
# PUBLIC API - LOGGING FUNCTIONS
# ===========================================
# These are the main functions you'll call throughout the codebase.


## Log an ERROR message - something is broken
## Example: Debug.log_error("Unit", "Tried to move to invalid position")
func log_error(context: String, message: String) -> void:
	_log(LogLevel.ERROR, context, message)


## Log a WARNING message - something unusual happened
## Example: Debug.log_warn("Ball", "Ball position clamped to field bounds")
func log_warn(context: String, message: String) -> void:
	_log(LogLevel.WARN, context, message)


## Log an INFO message - normal operation worth noting
## Example: Debug.log_info("Match", "Quarter 1 started")
func log_info(context: String, message: String) -> void:
	_log(LogLevel.INFO, context, message)


## Log a DEBUG message - detailed internal state
## Example: Debug.log_debug("AI", "Evaluated 5 options, chose KICK")
func log_debug(context: String, message: String) -> void:
	_log(LogLevel.DEBUG, context, message)


# ===========================================
# PUBLIC API - TICK TRACKING
# ===========================================


## Called by GameManager at the start of each tick
## This lets us include tick numbers in log messages
func set_current_tick(tick: int) -> void:
	_current_tick = tick


## Get the current tick (for other systems that need it)
func get_current_tick() -> int:
	return _current_tick


# ===========================================
# PUBLIC API - CATEGORY CONTROL
# ===========================================


## Mute a category (stop printing messages from it)
## Example: Debug.mute_category("AI") to silence AI logs
func mute_category(category: String) -> void:
	if category not in muted_categories:
		muted_categories.append(category)
		log_info("Debug", "Muted category: %s" % category)


## Unmute a category (resume printing messages from it)
func unmute_category(category: String) -> void:
	var index = muted_categories.find(category)
	if index >= 0:
		muted_categories.remove_at(index)
		log_info("Debug", "Unmuted category: %s" % category)


## Check if a category is currently muted
func is_category_muted(category: String) -> bool:
	return category in muted_categories


## Set the log level
## Example: Debug.set_level(Debug.LogLevel.DEBUG) for verbose output
func set_level(level: LogLevel) -> void:
	current_level = level
	log_info("Debug", "Log level changed to: %s" % LEVEL_NAMES[level])


# ===========================================
# PUBLIC API - SPECIAL LOGGING
# ===========================================


## Log a state change (useful for tracking state machines)
## Example: Debug.log_state_change("GameManager", "SimState", "STOPPED", "RUNNING")
func log_state_change(context: String, state_type: String, from_state: String, to_state: String) -> void:
	log_info(context, "%s: %s → %s" % [state_type, from_state, to_state])


## Log an event being emitted (useful for tracking signal flow)
## Example: Debug.log_event("EventBus", "goal_scored", {"team": 0, "points": 6})
func log_event(context: String, event_name: String, data: Dictionary = {}) -> void:
	var data_str = ""
	if not data.is_empty():
		data_str = " | Data: %s" % str(data)
	log_debug(context, "EVENT: %s%s" % [event_name, data_str])


## Log a function entry (useful for tracing execution flow)
## Example: Debug.log_function("GameManager", "_process_tick")
func log_function(context: String, function_name: String, args: Dictionary = {}) -> void:
	var args_str = ""
	if not args.is_empty():
		args_str = "(%s)" % str(args)
	log_debug(context, "→ %s%s" % [function_name, args_str])


# ===========================================
# PUBLIC API - DIVIDERS AND SECTIONS
# ===========================================


## Print a visual divider (useful for separating sections of output)
func log_divider(label: String = "") -> void:
	if not logging_enabled:
		return
	
	if label.is_empty():
		print_rich("[color=#666666]════════════════════════════════════════[/color]")
	else:
		print_rich("[color=#666666]══════════ %s ══════════[/color]" % label)


## Print a section header
func log_section(title: String) -> void:
	if not logging_enabled:
		return
	
	print_rich("")
	print_rich("[color=#FFD93D][b]▸ %s[/b][/color]" % title)


# ===========================================
# INTERNAL LOGGING IMPLEMENTATION
# ===========================================


## Internal logging function - all public log functions call this
func _log(level: LogLevel, context: String, message: String) -> void:
	# Check if logging is enabled
	if not logging_enabled:
		return
	
	# Check if this level should be printed
	if level > current_level:
		return
	
	# Check if this category is muted
	if context in muted_categories:
		return
	
	# Build the log message
	var parts: Array[String] = []
	
	# Timestamp
	if show_timestamps:
		var time = Time.get_time_dict_from_system()
		parts.append("[%02d:%02d:%02d]" % [time.hour, time.minute, time.second])
	
	# Tick number (if simulation is running)
	if show_tick_number and _current_tick > 0:
		parts.append("[T%04d]" % _current_tick)
	
	# Level
	parts.append("[%s]" % LEVEL_NAMES[level])
	
	# Context (the system/script name)
	parts.append("[%s]" % context)
	
	# Message
	parts.append(message)
	
	# Join and colorize
	var full_message = " ".join(parts)
	var color = COLORS[level]
	
	# Print with BBCode color
	print_rich("[color=%s]%s[/color]" % [color, full_message])


# ===========================================
# INITIALIZATION
# ===========================================


func _ready() -> void:
	# Print startup message
	log_section("Debug System Initialized")
	log_info("Debug", "Log level: %s" % LEVEL_NAMES[current_level])
	log_info("Debug", "Timestamps: %s, Tick numbers: %s" % [show_timestamps, show_tick_number])
	
	if not muted_categories.is_empty():
		log_info("Debug", "Muted categories: %s" % str(muted_categories))
