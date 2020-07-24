-- App Store Review Printer.
-- Copyright (C) 2018-2020, Aleh Dzenisiuk. All rights reserved.

--[[
State machine used to debounce buttons and recognize N-click, and N-click and hold patterns, e.g click and hold, double click, triple click and hold, etc.
]]--
return function(debounce_timeout, double_click_timeout, hold_timeout, callback, test_callback)
	
	-- Something to represent "never" that is still a number larger than any other duration used internally.
	-- Hold timeout is normally greater than a double-click one, so use it.
	local inf_time = hold_timeout + 1
	
	local last_level, last_level_time
	local debounced_level, debounced_level_time

	local debounce = function(level, now)
		
		if not last_level or last_level ~= level then
			-- First sample or still bouncing, need to wait.
			last_level, last_level_time = level, now
			return debounce_timeout
		end
		
		local left = (last_level_time + debounce_timeout) - now
		if left > 0 then
			-- Called a bit too early, not a problem, but need to wait.
			return left 
		end
		
		-- Enough time passed since the last change, assume the level has settled.
		debounced_level, debounced_level_time = level, now
		return inf_time
	end
	
	-- Using numbers for state, out of RAM at this point too:
	-- 0 -- 'idle'
	-- 1 -- 'down'
	-- 2 -- 'up'
	-- 3 -- 'end'
	local state = 0
	local next_time
	local click_count
	
	local process = function(level, now) 
		
		if state == 0 then

			if level == 0 then
				-- Clicked down first time, waiting for press and hold or up.
				state = 1
				click_count = 1
				next_time = now + hold_timeout
			else
				-- Still up, not interested, keeping 'idle'.
			end

		elseif state == 1 then
			
			if level == 0 then
				if now >= next_time then
					-- Holding down long enough, looks like a click-and-hold, report and do nothing till it's back up.
					state = 3
					next_time = nil
					callback(click_count, true)
				else
					-- Holding down but not long enough, keep waiting.
				end
			else
				-- Went up, wait for the possible next click before reporting the current one.
				state = 2
				next_time = now + double_click_timeout
			end

		elseif state == 2 then
			
			if level == 1 then
				if now >= next_time then
					-- More than double click timeout passed, so stop waiting and report what we've got.
					state = 0
					next_time = nil
					callback(click_count, false)
				else
					-- Still waiting for a potential next click. 
				end
			else
				-- OK, next click. 
				state = 1
				click_count = click_count + 1
				next_time = now + hold_timeout
			end

		elseif state == 3 then

			-- Reported an N-click + hold, but need to wait for button to go Up.
			if level == 1 then
				-- Done.
				state = 0
				next_time = nil
			end
		end
				
		if next_time then
			return next_time - now
		else
			return inf_time
		end
	end
	
	return function(level, now)
		local dt = debounce(level, now)
		local process_time = process(debounced_level, debounced_level_time)
		if process_time < dt then
			dt = process_time
		end
		if dt >= inf_time then 
			dt = nil 
		end
		if test_callback then
			test_callback(level, dt)
		end		
		return dt
	end
end
