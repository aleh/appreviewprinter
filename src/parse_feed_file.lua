return {
    
    run = function(callback)
        
        local log = function(message, ...)
            print(string.format("parsing: " .. message, ...))
        end

        local parser, feed_file, review_db
        
        local did_finish = function(error)
                
            if feed_file then
                feed_file:close()
                feed_file = nil
            end
    
            if review_db then
                review_db:close()
                review_db = nil
            end
        
            parser = nil
            
            node.setcpufreq(node.CPU80MHZ)
                        
            node.task.post(0, function()
                callback(error)
            end)
        end                
    
        log_heap("before processing")
        
        review_db = _require("review_db").new("writer", "new-reviews")
        if not review_db then
            did_finish("Could not open the review db writer")
            return
        end        
        log_heap("db writer")        
        
        feed_file = file.open("raw-feed.json")        
        if not feed_file then
            did_finish("Could not open feed file")
            return
        end
        log_heap("feed file")        
                        
        parser = _require("review_feed_parser").new({
            review = function(p, a)
            
                log("#%s", a.id)
            
                if not review_db:write(a) then
                    did_finish("Could not write a review into the db")
                    return false
                end
 
                return true
            end,
            error = function(p, message)
                did_finish(message)
            end,
            done = function(p)
                did_finish()
            end
        })
        log_heap("review feed parser")
                                
        local process_line
        process_line = function()
            local line = feed_file:read(256)
            if line then
                node.task.post(0, function() 
                    if parser:process(line) then
                        -- It can be that the processing has finished in this call and then the feed_file got nil.
                        if feed_file then
                            node.task.post(0, process_line)
                        end
                    end
                end)
            else
                parser:finish()
            end
        end        

        node.setcpufreq(node.CPU160MHZ)
    
        node.task.post(0, process_line)
    end
}
