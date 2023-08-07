-- A "busy" LED is the one that lights up when our app_state is not idle.
local busy_led_pin = 2
local ready_led_pin = 3
local error_led_pin = 4

-- Not using the 'led' module as memory budget is almost zero.
--~ busy_led = _require('led')(busy_led_pin, 100, 800)
--~ busy_led.set_on(false)

--
-- The general state of the application.
--
app_state = 'idle'
app_substate = false

return function(new_state, new_substate)

    app_state = new_state
	app_substate = new_substate
    log("app_state: %s", app_state)
    
	if app_state ~= 'idle' then
        --~ busy_led.start_blinking()
		gpio.write(busy_led_pin, gpio.HIGH)
		gpio.write(ready_led_pin, gpio.LOW)
		gpio.write(error_led_pin, gpio.LOW)
	else
        --~ busy_led.stop_blinking()
		gpio.write(busy_led_pin, gpio.LOW)
		if app_substate ~= nil or app_substate then
			gpio.write(ready_led_pin, gpio.HIGH)
			gpio.write(error_led_pin, gpio.LOW)
		else
			gpio.write(ready_led_pin, gpio.LOW)
			gpio.write(error_led_pin, gpio.HIGH)
		end
	end

    log_heap()
end
