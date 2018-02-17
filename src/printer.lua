local function log(message, ...)
    print(string.format("printer: " .. message, ...))
end     

-- Escapes non-ASCII characters in the given string. (%q of string.format() escapes only control characters)
local quoted = function(s)
    local result = ""
    for i = 1, s:len() do
        local b = s:byte(i)
        if 0x20 <= b and b <= 0x7e then
            result = result .. string.char(b)
        elseif b == 0x0a then
            result = result .. "\\n"
        else
            result = result .. string.format("\\x%02x", b)
        end
    end
    return "\"" .. result .. "\""
end

local usart = _require('usart').new(1, 9600)

local _submit = function(lines, callback)
    
    log("Submitting %d lines...", #lines)
    
    -- Let's output a zero just in case the stream is not synced well. It should be ignored by the printer anyway.
    usart:write("\0")
            
    local line_index = 1

    local submit_next_line
    submit_next_line = function()
        if line_index < #lines then
            
            local line = lines[line_index];
            log("Sending %s", quoted(line))
            usart:write(line .. "\n")
            
            line_index = line_index + 1
            node.task.post(0, submit_next_line)
        else
            
            log("Done")            
            -- TODO: trigger the callback directly of course.
            tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
                callback(nil)
            end)
        end
    end
    
    node.task.post(0, submit_next_line)
end

return {
        
    -- Prints partial reviews in the given table.
    print_reviews = function(self, reviews, callback)
        
        if #reviews == 0 then
            log("No reviews to print")
            callback(nil)
            return
        end
        
        log("Going to print %d review(s)", #reviews)
        
        local db = _require("review_db").new("reader", "reviews")
        if not db then
            callback("Could not open the review DB")
            return
        end
        
        log_heap("opened review reader")    
        
        local reviews_printed = 0
        
        local did_finish = function(error)
            
            if db then 
                db:close() 
                db = nil
            end
            
            if not error then
                log("Successfully printed %d review(s)", reviews_printed)
            end
            
            callback(error)
        end
        
        local next_review_index = 1
                
        local print_next
        print_next = function()
        
            if next_review_index > #reviews then
                did_finish(nil)
                return
            end
            
            local review = reviews[next_review_index]
            next_review_index = next_review_index + 1
            
            local r = db:full_review(review)
            if not r then
                did_finish(string.format("could not fetch the contents of the review #%d", review.id))
                return
            end
            
            local doc = _require("printer_doc")
            doc:add_text(string.format("\n#%d '", r.id))
            doc:add_text(r.title)
            doc:add_text("'\n")
            doc:add_text("(by ")
            doc:add_text(r.author)
            doc:add_text(")\n\n")                        
            doc:add_text(r.content)
            doc:add_text("\n\n")
            doc:add_text("---\n\n")
            
            local lines = doc:finish()

            _submit(
                lines,
                function (error)
                    if error then
                        did_finish(string.format("could not print review #%d", review.id))
                    else
                        log("done printing #%d", review.id)
                        reviews_printed = reviews_printed + 1
                        node.task.post(0, print_next)
                    end
                end
            )        
        end
        
        node.task.post(0, print_next)
    end    
}
