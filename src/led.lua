-- App Store Review Printer.
-- Copyright (C) 2018-2021, Aleh Dzenisiuk. All rights reserved.

return function(pin, on_time, off_time)
		
	local on = false
	local blinking = false
	local blinking_on = false
	local blinking_timer = nil
	
	gpio.mode(pin, gpio.OUTPUT)
	
	local check
	
	check = function()
		if blinking_timer then
			if blinking_on then
				gpio.write(pin, gpio.LOW)
				blinking_on = false
				blinking_timer:alarm(on_time, tmr.ALARM_SINGLE, check)
			else
				gpio.write(pin, gpio.HIGH)
				blinking_on = true
				blinking_timer:alarm(off_time, tmr.ALARM_SINGLE, check)
			end
		else
			if on then
				gpio.write(pin, gpio.LOW)
			else
				gpio.write(pin, gpio.HIGH)
			end
		end
	end

	check()
	
	return {
		start_blinking = function()
			if blinking_timer then return end
			blinking_timer = tmr.create()
			blinking_on = on
			check()
		end,
		stop_blinking = function()
			if not blinking_timer then return end
			blinking_timer:unregister()
			blinking_timer = nil
			check()
		end,
		set_on = function(_on)
			on = _on
			check()
		end
	}
end
