-- GPIO pin which is used to detect whether the printer is busy or can accept our data.
local busy_pin = 5

-- GPIO pin which is used to send data to the printer.
local tx_pin = 6

-- Max time ins ms the printer can be busy.
local printer_busy_timeout = 5 * 1000

-- Milliseconds to wait between the lines.
local line_interval = 0

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

local _submit = function(lines, callback)

    log("Submitting %d lines...", #lines)

    -- Using a pullup, so it reads busy when not connected.
    gpio.mode(busy_pin, gpio.INPUT, gpio.PULLUP)
    
    local usart = _require('usart').new(tx_pin, 9600)

    local line_index = 1
    
    local retry_interval = 100
    local max_retry_counter = (printer_busy_timeout + retry_interval - 1) / retry_interval
    local retry_counter = 0
    
    local did_finish = function(error)
        usart:deinit()
        gpio.mode(busy_pin, gpio.INPUT, gpio.FLOAT)
        callback(error)
    end

    local submit_next_line
    submit_next_line = function()
        
        if line_index >= #lines then
            did_finish(nil)
        else
            if gpio.read(busy_pin) == gpio.LOW then
                
                retry_counter = 0

                local line = lines[line_index];
                usart:write(line .. "\n", function()
                    log("Sent line #%d, %d byte(s)", line_index, line:len() + 1)
                    line_index = line_index + 1
                    
                    if line_interval > 0 then
                        tmr.create():alarm(line_interval, tmr.ALARM_SINGLE, submit_next_line)
                    else
                        node.task.post(0, submit_next_line)
                    end
                end)
                
            else

                if retry_counter >= max_retry_counter then
                    log("Still busy, giving up")
                    if line_index == 0 then
                        did_finish("the printer is stuck")
                    else
                        did_finish("the printer is not available")
                    end
                else
                    if retry_counter == 0 then 
                        log("The printer is busy, will retry a couple of times...")
                    end
                    
                    retry_counter = retry_counter + 1
                    tmr.create():alarm(retry_interval, tmr.ALARM_SINGLE, function() 
                        node.task.post(0, submit_next_line)
                    end)
                end                
            end
        end
    end
    
    node.task.post(0, submit_next_line)
end

return {
        
    -- Prints partial reviews in the given table.
    print_reviews = function(self, callback)
        
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
        
        local doc = _require("printer_doc")        
                
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
            
            doc:add_text("\n")

            local stars = function(n)
                local r = ""
                for i = 1, n do r = r .. "*" end
                for i = n + 1, 5 do r = r .. "·" end
                return r
            end
            doc:with_emphasis(function()
                doc:add_text(stars(r.rating))
                doc:add_text(" ")
                doc:add_text(r.title)
            end)
            doc:add_text("\n")
            
            doc:with_small_font(function()
                doc:add_text(string.format("#%d, by ", r.id))
                doc:add_text(r.author)
                doc:add_text("\n")
            end)
            
            node.task.post(0, function()
            
                doc:with_small_font(function()
                    doc:add_text("\n")
                    doc:add_text(r.content .. "\n")
                end)
            
                doc:add_text("\n---\n")
                doc:add_text("\n\n")
            
                local lines = doc:finish()

                _submit(
                    lines,
                    function (error)
                        if error then
                            did_finish(string.format("could not print review #%d: %s", review.id, error))
                        else
                            log("Done printing #%d", review.id)
                            reviews_printed = reviews_printed + 1
                            node.task.post(0, print_next)
                        end
                    end
                )
            end)
        end
        
        node.task.post(0, print_next)
    end    
}
