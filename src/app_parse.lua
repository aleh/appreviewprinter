--
-- Parsing the feed JSON file and putting the reviews from there into the "new" reviews DB.
--    
return function()
    
    set_state('parsing')
    
    _require("parse_feed_file")(function(error)
        if not error then
            log("Done parsing the feed file")                
            _require('app_process')()
        else
            log("Failed parsing the feed file: %s", error)
            enter_idle(false)
        end
    end)
end

