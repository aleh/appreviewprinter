-- App Store Review Printer.
-- Copyright (C) 2019, Aleh Dzenisiuk. All rights reserved.

--[[
Wraps a switch between the given pin and the GND. A built-in pull-up is enabled, so the switch should pull the pin LOW when activated.

Supports debouncing and handling multiple clicks.

Parameters:
	- pin -- the pin the button is attached to, follows the numbering of 'gpio' module.
	- callback -- a function that's called when the button is clicked, accepts a single parameter, number of clicks.

]]--
return function(pin, callback)
	
	local r = _require("click_recognizer")(
		10,		-- Debounce.
		200,	-- Double click.
		1000,	-- Hold (as click & hold).
		callback
	)
	
	gpio.mode(pin, gpio.INT, gpio.PULLUP)

	-- The interface of the click recognizer is made for a single timer.
	local timer = tmr.create()

	local check
	check = function()
		local dt = r(gpio.read(pin), tmr.now() / 1000)
		timer:stop()
		if dt then
			timer:register(dt, tmr.ALARM_SEMI, function(t)
				check()
			end)
			timer:start()
		end
	end

	gpio.trig(pin, 'both', function(level, when, eventcount)
		check()
	end)	
end
