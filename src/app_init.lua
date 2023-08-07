-- A "busy" LED is the one that lights up when our app_state is not idle.
local busy_led_pin = 2
local ready_led_pin = 3
local error_led_pin = 4

gpio.mode(busy_led_pin, gpio.OUTPUT)
gpio.write(busy_led_pin, gpio.LOW)

gpio.mode(ready_led_pin, gpio.OUTPUT)
gpio.write(ready_led_pin, gpio.LOW)

gpio.mode(error_led_pin, gpio.OUTPUT)
gpio.write(error_led_pin, gpio.LOW)

-- A global log used from other parts of the "main" module.
log = function(message, ...)
    print(string.format("main: " .. message, ...))
end

-- A global function tracing the heap, which something to keep an eye on in this project, used from submodules.
local prev_heap = nil
log_heap = function(msg)
    local h = node.heap()
    if prev_heap then
        if msg then
            log("Heap: %d (%d, %s)", h, h - prev_heap, msg)
        else
            log("Heap: %d (%d)", h, h - prev_heap)
        end
    else
        log("Heap: %d", h)
    end
    prev_heap = h
end

-- Diagnostics, 
-- Another little global helping to dump tables. Handy while debugging things interactively.
dump = function(t) 
	for k, v in pairs(t) do 
		print(k, v)
	end 
end

-- It's useful to know why the device has been woken up.
local reason
local reasons = {
    [0] = "power-on",
    [1] = "h/w wdg",
    [2] = "exc rst",
    [3] = "s/w wdg",
    [4] = "s/w rst",
    [5] = "dsleep wake up",
    [6] = "ext rst"
}
log("Boot reason: %s", reasons[info] or info or "?")
reasons = nil

-- Let's start monitoring the push button. 
-- (Ignoring the return value because we don't want to disable the handler anymore.)
_require("app_button")

-- Changes global states of the app controlling the LED.
set_state = function(new_state, new_substate) 	
	_require("app_setstate")(new_state, new_substate)
end

-- Idle mode. 
enter_idle = function(after_success)
    set_state('idle', after_success)
    -- Originally there was a sleep mode here, but not sure if handling button presses 
    -- will be convenient from the sleep mode.
end
