--
-- Fetching the JSON feed and saving it in a file to process later.
--        
return function(enter_parsing) 
    
    set_state('refreshing')
    
    local request = _require("uhttp_request")()
    log_heap("uhttp")
    
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
