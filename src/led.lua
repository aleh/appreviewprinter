-- App Store Review Printer.
-- Copyright (C) 2019, Aleh Dzenisiuk. All rights reserved.

return {

	new = function(pin)
		
		local on = false
		local blinking = false
		local blinking_on = false
		local blinking_timer = tmr.create()
		local on_time, off_time
		
		gpio.mode(pin, gpio.OUTPUT)
		
		local check
		
		check = function()
			if blinking then
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
			start_blinking = function(_on_time, _off_time)
				if blinking then return end
				blinking = true
				on_time = _on_time
				off_time = _off_time
				check()
			end,
			stop_blinking = function()
				blinking = false
				on = false
				check()
			end,
			set_on = function(_on)
				on = _on
				check()
			end
		}
	end
}
