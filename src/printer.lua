return {
    
    -- Creates and returns a new instance of a document builder.
    new_doc = function()
        
        local self = {}
        
        local lines, line, col, max_cols

        self.begin = function(_self)
            -- The array of completed lines.
            lines = {}
            -- The current line, not in the 'lines' array yet.
            line = ""
            -- The index of the text column where the next printable character will be put.
            col = 0
            -- The number of columns per line. 
            -- On a 58mm printer, this is 32 with font A, 42 with font B.
            max_cols = 32
            -- Let's begin with a "reset all" escape sequence.
            _self:_add_codes("\027@")
        end
        
        -- Appends escape sequences to the current line that are not supposed to advance the current column.
        self._add_codes = function(_self, codes)
            line = line .. codes
        end
        
        -- Ends the current line even if it's empty.
        self._newline = function(_self)
            table.insert(lines, line)
            line = ""
            col = 0
        end

        -- Flushes the current line and returns an array of them back, resets the lines and the state of the document.
        self.finish = function(_self)
            if line:len() > 0 then table.insert(lines, line) end
            local result = lines
            _self:begin()
            return result
        end        
        
        -- Adds the given text assuming it is properly encoded already and has no control characters.
        self._add_raw = function(_self, t) 
            local i = 1
            while true do
                
                local chars_left = t:len() - i + 1
                
                if chars_left <= 0 then return end
                
                if col >= max_cols then _self:_newline() end
                
                local cols_left = max_cols - col
                
                local to_move
                if chars_left < cols_left then
                    to_move = chars_left
                else
                    to_move = cols_left
                end
                
                line = line .. t:sub(i, i + to_move - 1)
                col = col + to_move
                i = i + to_move
            end
        end

        self.add_text = function(_self, text)
            
            local state = 'line-start'
            local start_index, end_index
            local i = 1
            while i <= text:len() do
                local b = text:byte(i)
                assert(b == 10 or b >= 32, "unexpected control character")
                if state == 'line-start' then
                    if b <= 32 then
                        -- A space or a newline — ignoring them all in the beginning of the line.
                    else
                        -- A non-space, our line begins.
                        state = 'first-word'
                        start_index = i
                        end_index = i
                    end
                elseif state == 'first-word' or state == 'word' or state == 'space' then
                    if b == 10 then
                        -- Got a newline, just output what we've got so far excluding the trailing spaces.
                        if state ~= 'space' then end_index = i - 1 end
                        _self:_add_raw(text:sub(start_index, end_index))
                        _self:_newline()
                        state = 'line-start'
                    else
                        if b <= 32 then
                            -- Got a space and there was no space before, so let's remember last non-space position.
                            if state ~= 'space' then 
                                end_index = i - 1 
                                state = 'space'
                            end
                        else
                            -- A non-space.
                            if state == 'space' then state = 'word' end
                        end
                        
                        local len = i - start_index + 1
                        if col + len >= max_cols then
                            -- The current character, space or not, is not going to fit, let's output the words fitting
                            -- so far, and restart our scan from the next character after the outputted part.
                            if state == 'first-word' then
                                -- Unless it's the first word and we don't really have anywhere to return to, 
                                -- just need to output everything fitting.
                                local t = text:sub(start_index, i)
                                _self:_add_raw(t)
                                _self:_newline()
                                state = 'line-start'
                            else
                                local t = text:sub(start_index, end_index)
                                _self:_add_raw(t)
                                _self:_newline()                            
                                state = 'line-start'
                                i = end_index -- It'll be incremented below.
                            end
                        end
                    end
                end
                i = i + 1
            end
            
            -- End of text should work like a space.
            if state ~= 'space' then end_index = text:len() end
            
            -- Let's output whatever we've collected, it should fit.
            if state ~= 'line-start' then
                local t = text:sub(start_index, end_index)
                _self:_add_raw(t)
            end
        end

        self:begin()
        
        return self
    end,
    
    submit = function(self, doc, callback)        
        
        print(string.format("Printing: '%s'", doc))
        tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
            callback(nil)
        end)
    end
}
