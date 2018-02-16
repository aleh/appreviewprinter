local function log(message, ...)
    print(string.format("main: " .. message, ...))
end

-- A global function tracing the heap, something to keep an eye on in this project, used from submodules.
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

-- Global non-caching version of `require`, used from submodules.
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

-- Another small global that's handy while debugging things.
dump = function(t)  for k, v in pairs(t) do print(k, v) end end

local function main()
    
    -- It's useful to know why the device has been woken up.
    local code, info = node.bootreason()
    local reasons = {
        [0] = "power-on",
        [1] = "hardware watchdog reset",
        [2] = "exception reset",
        [3] = "software watchdog reset",
        [4] = "software restart",
        [5] = "wake from deep sleep",
        [6] = "ext reset"
    }
    log("Boot reason: %s", reasons[info] or "unknown event")
    reasons = nil
    
    -- Let's see how much heap we begin with.
    log_heap()

    local state = 'idle'
    
    local set_state = function(new_state)
        state = new_state
        log("State: %s", state)
        log_heap()
    end
                
    --
    -- Sleeping
    --
    local enter_sleeping = function(after_success)
        
        local timeout
        if after_success then 
            timeout = 10
        else
            timeout = 5
        end
        
        log("Going to sleep for %d second(s)...", timeout)
        set_state('sleeping')
        
        node.task.post(0, function()
            node.dsleep(timeout * 1e6, 4)
        end)
    end
    
    -- Sort of forward declarations
    local enter_refreshing, enter_parsing, enter_processing_changes, enter_printing
    
    --
    -- Connecting
    --
    local enter_connecting = function()

        set_state('connecting')
        
        _require("connection").activate(
            _require("config").networks,
            function(succeeded, msg)
                if succeeded then
                    node.task.post(0, function()
                        enter_refreshing()
                    end)
                else
                    log("Could not activate the connection: %s", msg)
                    enter_sleeping(false)
                end
            end
        )
        
        log_heap("activating connection")
    end    
    
    --
    -- Refreshing
    --        
    enter_refreshing = function() 
        
        set_state('refreshing')
        
        local request = _require("uhttp").request.new()
        log_heap("required uhttp")
        
        local feed = _require("config").feed
        
        request:download(
            feed.host, 
            feed.path,
            feed.port,
            "raw-feed.json",
            function(succeeded, message)
                request = nil
                node.task.post(0, function()
                    
                    wifi.setmode(wifi.NULLMODE, true)
                    
                    log_heap("after download")
                    
                    if succeeded then
                        log("Done refreshing")
                        enter_parsing()
                    else
                        log("Failed to refresh: %s", message)
                        enter_sleeping(false)
                    end
                end)
            end
        )
        
        log_heap("started download")
    end
            
    --
    -- Parsing the raw feed and storing it on the flash.
    --    
    enter_parsing = function()
        
        set_state('parsing')
        
        _require("parse_feed_file").run(function(error)
            if not error then
                log("Done parsing the feed file")                
                enter_processing_changes()
            else
                log("Failed parsing the feed file")
                enter_sleeping(false)
            end
        end)
    end
    
    --
    -- Looking for changes in the new DB compared to the old DB.
    -- 
    enter_processing_changes = function()
        
        set_state('processing')
        
        _require("find_changes"):run(function(error, reviews)
            log("Done processing changes")
            if error then
                    enter_sleeping(true)
            else
                node.task.post(0, function()
                    enter_printing(reviews)
                end)
            end
        end)
    end
    
    enter_printing = function(reviews)
        
        set_state('printing')
        
        _require("printer"):print_reviews(reviews, function(error)
            log("Done printing")
            enter_sleeping(error == nil)
        end)      
    end
    
    enter_connecting()
end

main()
