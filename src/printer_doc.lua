local self = {}

local lines, line, col, max_cols

-- The current font mode for ESC ! sequence.
local mode = 0

local FONT_A_MAX_COLS = 31
local FONT_B_MAX_COLS = 41

self.begin = function(_self)
    -- The array of completed lines.
    lines = {}
    -- The current line incomplete line (not in the 'lines' array yet).
    line = ""
    -- The index of the text column where the next printable character will be put.
    col = 0
    -- The number of columns per line. 
    -- On a 58mm printer, this is 32 with font A, 42 with font B.
    -- TODO: make it a parameter here
    max_cols = FONT_A_MAX_COLS
    
    mode = 0
    
    -- Let's begin with a "reset all" escape sequence.
    _self:_add_codes("\027@")
end

-- Appends escape sequences to the current line. The sequences are not supposed to advance the current column.
self._add_codes = function(_self, codes)
    line = line .. codes
end

-- Ends the current line (adds it to the lines array), even if it's empty.
self._newline = function(_self)
    table.insert(lines, line)
    line = ""
    col = 0
end

-- Flushes the current line and returns an array of lines collected so far back, 
-- resets the lines and the state of the document.
self.finish = function(_self)
    if line:len() > 0 then table.insert(lines, line) end
    local result = lines
    _self:begin()
    return result
end        

-- Adds the given text cutting it hard into lines at the last column for the current font if needed. 
-- The text is assumed to be properly encoded and having no control characters.
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

-- We need to be able to map some of the Unicode codepoints into printer's CP437 codes.
-- The ASCII range (from 0x20 to 0x7E) maps 1 to 1, so needs no table and we can ignore 0x7F 
-- and the bad dollar sign. The codepoints for characters 0x80-0xFF need a mapping table. We could skip
-- pseudographics characters, but well. Also, I don't want to use a Lua table here because of the memory
-- requirements, so trading speed for memory. 
-- Two byte Unicode code points in this string are mapped to characters from 0x80 to 0xFF in CP437.
local cp437_map = "\x00\xC7\x00\xFC\x00\xE9\x00\xE2\x00\xE4\x00\xE0\x00\xE5\x00\xE7\x00\xEA\x00\xEB\x00\xE8\x00\xEF\x00\xEE\x00\xEC\x00\xC4\x00\xC5\x00\xC9\x00\xE6\x00\xC6\x00\xF4\x00\xF6\x00\xF2\x00\xFB\x00\xF9\x00\xFF\x00\xD6\x00\xDC\x00\xA2\x00\xA3\x00\xA5\x20\xA7\x01\x92\x00\xE1\x00\xED\x00\xF3\x00\xFA\x00\xF1\x00\xD1\x00\xAA\x00\xBA\x00\xBF\x23\x10\x00\xAC\x00\xBD\x00\xBC\x00\xA1\x00\xAB\x00\xBB\x25\x91\x25\x92\x25\x93\x25\x02\x25\x24\x25\x61\x25\x62\x25\x56\x25\x55\x25\x63\x25\x51\x25\x57\x25\x5D\x25\x5C\x25\x5B\x25\x10\x25\x14\x25\x34\x25\x2C\x25\x1C\x25\x00\x25\x3C\x25\x5E\x25\x5F\x25\x5A\x25\x54\x25\x69\x25\x66\x25\x60\x25\x50\x25\x6C\x25\x67\x25\x68\x25\x64\x25\x65\x25\x59\x25\x58\x25\x52\x25\x53\x25\x6B\x25\x6A\x25\x18\x25\x0C\x25\x88\x25\x84\x25\x8C\x25\x90\x25\x80\x03\xB1\x00\xDF\x03\x93\x03\xC0\x03\xA3\x03\xC3\x00\xB5\x03\xC4\x03\xA6\x03\x98\x03\xA9\x03\xB4\x22\x1E\x03\xC6\x03\xB5\x22\x29\x22\x61\x00\xB1\x22\x65\x22\x64\x23\x20\x23\x21\x00\xF7\x22\x48\x00\xB0\x22\x19\x00\xB7\x22\x1A\x20\x7F\x00\xB2\x25\xA0\x00\xA0"

-- CP437 character used instead of unknown Unicode codepoints.
local unknown_char = 0x3F

-- Pick bit arithmetics module for NodeMCU or normal Lua.
local _bit
if bit32 then _bit = bit32 else _bit = bit end        

-- Use our UTF-8 parser.
local utf8 = require('utf8')
            
-- Iterator returning CP437 codes for the given UTF8-encoded text.
local cp437 = function(text)
    local codepoints_iter = utf8.codepoints(text)
    return function()
        while true do
            local b = codepoints_iter()
            if b == nil then return nil end
            if b < 32 or b == 0x7F then
                -- Eat all the control characters except LF.
                if b == 10 then return b end
            elseif b <= 0x7E then
                -- All ASCII-range codes are the same.
                return b
            elseif b <= 0xFFFF then
                -- For the 16-bit ones let's check with our map.
                local i = 1
                local high = _bit.rshift(b, 8)
                local low = _bit.band(b, 0xFF)
                while i <= cp437_map:len() do
                    if cp437_map:byte(i) == high and cp437_map:byte(i + 1) == low then
                        return 0x80 + _bit.rshift(i, 1)
                    end
                    i = i + 2
                end
                -- Could not find it, unknown character.
                return unknown_char
            else
                -- A placeholder character for anything else.
                return unknown_char
            end
        end
    end
end

self._with_mode = function(_self, m, callback)
    mode = bit.bor(mode, m)
    _self:_add_codes("\027!" .. string.char(mode))
    callback()
    mode = bit.band(mode, bit.bnot(m))
    _self:_add_codes("\027!" .. string.char(mode))
end

-- Sets the small font mode, calls the given function and returns back to the normal font mode.
self.with_small_font = function(_self, callback)

    local prev_max_cols = max_cols
    max_cols = FONT_B_MAX_COLS
    
    -- Let's try to recalculate the current position in case somebody will use this in the middle of the string.
    col = (col * max_cols + prev_max_cols - 1) / prev_max_cols

    _self:_with_mode(1, callback)
    
    -- Well, let's try to recalculate again, though precision is not going to be good.
    col = (col * prev_max_cols + max_cols - 1) / max_cols

    max_cols = prev_max_cols
end

-- Sets the bold font mode, calls the given function and returns back to the normal font mode.
self.with_emphasis = function(_self, callback)
    _self:_with_mode(8, callback)
end
        
-- Adds one or more paragraphs of UTF-8 encoded text performing simple word wrapping. 
-- The text is supposed to have no space or control characters other than LF and a whitespace.
self.add_text = function(_self, _text)
    
    -- TODO: change the code below to work with an iterator directly
    local text = ""
    for b in cp437(_text) do
        text = text .. string.char(b)
    end
                
    local start_index, end_index
    
    local state = 'line-start'
    if col == 0 then
        state = 'line-start'
    else
        state = 'first-word'
        start_index = 1
        end_index = 1
    end

    local i = 1
    while i <= text:len() do
        
        local b = text:byte(i)                    
        assert(b == 10 or b >= 32, "unexpected control character")
        
        if state == 'line-start' then
            if b <= 32 then
                -- A space or a newline — ignoring everything except for newlines (to allow empty lines).
                if b == 10 then _self:_newline() end
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
    
    -- Let's make the end of text work like a non-space, so if our text consists of multiple calls to add_text,
    -- then they'll glue together with all the spaces.
    --~ if state ~= 'space' then end_index = text:len() end
    end_index = text:len()
    
    -- Let's output whatever we've collected, it should fit.
    if state ~= 'line-start' then
        local t = text:sub(start_index, end_index)
        _self:_add_raw(t)
    end
end

self:begin()

return self
