local function log(message, ...)
    print(string.format("main: " .. message, ...))
end     

-- A global to trace heap, something to keep an eye on in this project, used from submodules.
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
        [6] = "external reset"
    }
    log("Starting. Boot reason: %s", reasons[info] or "unknown")
    reasons = nil
    
    -- Let's see how much heap we begin with.
    log_heap()

    log("Loading config...")
    local config = _require("config")
    
    local state = 'idle'
                
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
        state = 'sleeping'
        
        node.task.post(0, function()
            log_heap()
            log("Good night!")
            node.dsleep(timeout * 1e6)
        end)
    end
    
    -- Sort of forward declarations
    local enter_refreshing, enter_parsing, enter_processing_changes  
    
    ---
    --- Connecting
    ---
    local enter_connecting = function()

        state = 'connecting'
        log("Connecting...")
        
        _require("connection").activate(
            config.networks,
            function(succeeded, msg)
                if succeeded then
                    log_heap("up")
                    enter_refreshing()
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
        
        state = 'refreshing'        
        log("Refreshing...")
        
        log_heap()
        local request = _require("uhttp").request.new()
        log_heap("required uhttp")
        
        request:download(
            config.feed.host, 
            config.feed.path,
            config.feed.port,
            "raw-feed.json",
            function(succeeded, message)
                request = nil
                node.task.post(0, function()
                    
                    -- TODO: Deactivate WiFi here
                    
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
    end
            
    --
    -- Parsing the raw feed and storing it on flash.
    --    
    enter_parsing = function()
        
        log("Parsing the feed file...")
        state = 'parsing'
        
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
        
        log("Processing changes...")
        state = 'processing-changes'
        
        _require("find_changes"):run(function(error)
            log("Done processing changes")
            enter_sleeping(error == nil)
        end)
    end
        
    enter_connecting()
end

main()
