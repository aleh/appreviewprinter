-- App Store Review Printer.
-- Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

-- GPIO pin which is used to detect whether the printer is busy or can accept our data.
local busy_pin = 5

-- GPIO pin which is used to send the data to the printer.
local tx_pin = 6

-- Max time in milliseconds the printer can be busy.
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
                    
                    log("Still not available, giving up")
                    
                    if line_index == 0 then
                        did_finish("the printer is not available")
                    else
                        did_finish("the printer is stuck")
                    end
                    
                else
                    
                    if retry_counter == 0 then 
                        log("The printer is not available, will retry a couple of times just in case it's busy...")
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

-- Prints a single partial review from the given DB which should be open for reading.
local _print_review = function(db, review, callback)
    
    log("Going to print review #%d", review.id)
    
    local r = db:full_review(review)
    if not r then
        callback(string.format("could not fetch the contents of the review #%d", review.id))
        return
    end
	
    -- Formatting in the next cycle to make sure we have plenty of time.
    node.task.post(0, function()

        local doc = _require("printer_doc")

        doc:empty_lines(1)

        -- Rating and title.
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
        
        -- Author.
        doc:with_small_font(function()
            doc:add_text(string.format("#%d, by ", r.id))
            doc:add_text(r.author)
        end)
        doc:empty_lines(1)
        
        -- The body can be too large to process in a single chunk, so splitting it.
        require("util").for_each_chunk(
            r.content, 
            64,
            function(chunk)
                -- TODO: switching to the small font and back can cause the current output position to accumulate error. Set small font beforehand instead.
                doc:with_small_font(function()
                    doc:add_text(chunk)
                end)
            end,
            function()
                
                doc:add_text("\n---\n")

                local lines = doc:finish()

                _submit(
                    lines,
                    function (error)
                        if error then
                            callback(string.format("could not print review #%d: %s", r.id, error))
                        else
                            log("Done printing #%d", review.id)
                            callback(nil)
                        end
                    end
                )
            end
        )
    end)
end

return {
    
    -- Finds up to max_reviews from the database having 'updated' flag set. 
    -- Once a review is successfully printed it's 'updated' flag is reset.
    print_updated = function(self, max_reviews, callback)
        
        log("Going to print up to %d updated reviews", max_reviews)
        
        local db = _require("review_db").new("reader", "reviews")
        if not db then
            callback("could not open the review DB")
            return
        end

        local total_printed = 0
        
        local did_finish = function(error)
            
            if not error then
                log("Done printing updated review(s). Total: %d", total_printed)
            end
            
            if db then 
                db:close() 
                db = nil
            end
            
            callback(error)
        end
                
        local check_next
        check_next = function()
            
            if total_printed >= max_reviews then
                log("Printed %d reviews, enough for now", max_reviews)
                did_finish(nil)
				return
            end
            
            local r = db:read(false)
            if not r then             
                if db:error() then
                    did_finish(string.format("could not read the next review: %s", db:error()))
                else
                    did_finish(nil)
                end
            else
                -- Check if the review has 'updated' flag set (bit 0).
                if bit.band(r.flags, 1) == 1 then
                    -- Yes, let's print it out.
                    _print_review(db, r, function(error)
                        if error then
                            did_finish(string.format("could not print review #%d", r.id))
                        else
                            -- Let's clear the 'updated' flag, so we know we don't need to print it next time.
                            r.flags = bit.band(r.flags, bit.bnot(1))
                            if db:update(r) then
                                log("Cleared 'updated' flag for just printed review #%d", r.id)
                                total_printed = total_printed + 1
                                node.task.post(0, check_next)
                            else
                                did_finish(string.format("Could not clear 'updated' flag for just printed review #%d", r.id))
                            end
                        end
                    end)
                else           
                    -- No, let's check the next one. 
                    node.task.post(0, check_next)
                end
            end
        end
        
        node.task.post(0, check_next)
    end   
}
