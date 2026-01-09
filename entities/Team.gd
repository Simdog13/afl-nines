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
