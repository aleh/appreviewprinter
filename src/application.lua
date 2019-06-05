-- App Store Review Printer.
-- Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

local log = function(message, ...)
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

-- A global non-caching version of `require`, used from submodules.
_require = function(s)
    local name = s .. ".lc"
    if file.exists(name) then
        return dofile(name)
    end
    local name = s .. ".lua"
    if file.exists(name) then
        return dofile(name)
    end    
    return nil
end

-- Another small global dumping tables which is handy while debugging things interactively.
dump = function(t) for k, v in pairs(t) do print(k, v) end end

-- It's useful to know why the device has been woken up.
local code, info = node.bootreason()
local reasons = {
    [0] = "power-on",
    [1] = "h/w watchdog",
    [2] = "exception reset",
    [3] = "s/w watchdog",
    [4] = "s/w restart",
    [5] = "deep sleep wake up",
    [6] = "ext reset"
}
log("Boot reason: %s", reasons[info] or info or "unknown")
reasons = nil

-- Let's see how much heap we begin with.
log_heap()
    
--
-- The general state of the application.
--
local state = 'idle'
local substate = false

-- Not using the 'led' module as memory budget is almost zero.
local busy_led_pin = 3

gpio.mode(busy_led_pin, gpio.OUTPUT)

local set_state = function(new_state, new_substate)

    state = new_state
	substate = new_substate
    log("State: %s", state)
    log_heap()
    
	if state ~= 'idle' then
		gpio.write(busy_led_pin, gpio.LOW)		
	else
		gpio.write(busy_led_pin, gpio.HIGH)
	end
end
            
--
-- Idle mode. 
-- Originally there was a sleep mode here, but not sure if handling button presses 
-- will be convenient from the sleep mode.
--
local enter_idle = function(after_success)

    set_state('idle', after_success)
    
    -- TODO: begin blinking an 'error' or 'success' patterns depending on after_success flag
    
    --[[
    local timeout
    if after_success then 
        timeout = 10
    else
        timeout = 5
    end
    
    log("Going to sleep for %d second(s)...", timeout)
    set_state('sleeping')
    
    node.task.post(0, function()
        log("Good night!")
        node.dsleep(timeout * 1000000, 4)    
    end)
    ]]--
end

enter_idle(true)

-- Sort of forward declarations, so upvalues are captured properly.
local enter_refreshing, enter_parsing, enter_processing_changes, enter_printing

--
-- Connecting to WiFi
--
local enter_connecting = function()

    set_state('connecting')
    
    _require("connection").activate(
        _require("config").networks,
        function(succeeded, msg)
            node.task.post(0, function()
                if succeeded then
                    enter_refreshing()
                else
                    log("Could not activate the connection: %s", msg)
                    enter_idle(false)
                end
            end)
        end
    )
end    

--
-- Fetching the JSON feed and saving it in a file to process later.
--        
enter_refreshing = function() 
    
    set_state('refreshing')
    
    local request = _require("uhttp_request").new()
    log_heap("required uhttp")
    
    local feed_config = _require("config").feed
    
    request:download(
        feed_config.host, 
        feed_config.path,
        feed_config.port,
        "raw-feed.json",
        function(succeeded, message)
            request = nil
            node.task.post(0, function()
                
                wifi.setmode(wifi.NULLMODE, true)
                
                if succeeded then
                    log("Done refreshing")
                    enter_parsing()
                else
                    log("Failed to refresh: %s", message)
                    enter_idle(false)
                end
            end)
        end
    )
end
        
--
-- Parsing the feed JSON file and putting the reviews from there into the "new" reviews DB.
--    
enter_parsing = function()
    
    set_state('parsing')
    
    _require("parse_feed_file"):run(function(error)
        if not error then
            log("Done parsing the feed file")                
            enter_processing_changes()
        else
            log("Failed parsing the feed file: %s", error)
            enter_idle(false)
        end
    end)
end

--
-- Looking for changes in the "new" DB compared to the "old" one.
-- 
enter_processing_changes = function()
    
    set_state('processing')
    
    _require("find_changes"):run(function(error, reviews)
        if error then
            enter_idle(true)
        else
			enter_idle(false)
            -- node.task.post(0, function()
            --    enter_printing(reviews)
            -- end)
        end
    end)
end

--
-- Printing out the reviews scheduled for printing.
-- 
enter_printing = function()
    
    set_state('printing')
    
    _require("printer"):print_updated(3, function(error)
        
        if error then
            log("Failed to print updated reviews: %s", error)
        else
            log("Done printing updated reviews")
        end
        
        enter_idle(error == nil)
    end)      
end

--
-- Globals allowing to trigger main actions from the terminal.
--

local check_busy = function()
    if state ~= 'idle' then 
        log("busy") 
        return true 
    else
        return false
    end
end

check = function()
    if check_busy() then return end
    enter_connecting()
end

print_new = function()
    if check_busy() then return end
    enter_printing()
end

-- enter_connecting()
