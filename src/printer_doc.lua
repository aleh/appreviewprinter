-- App Store Review Printer.
-- Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

local self = {}

if bit32 then bit = bit32 end

local lines, line, col, max_cols

-- The current font mode for the ESC ! sequence.
local mode = 0

local FONT_A_MAX_COLS = 30
local FONT_B_MAX_COLS = 42

self.begin = function(_self)
    
    -- The array of completed lines.
    lines = {}
    
    -- The current incomplete line (not in the 'lines' array yet).
    line = ""
    
    -- The index of the text column where the next printable character will be put.
    col = 0
    
    -- The number of columns per line for the current font, which is Font A after the initialization.
    max_cols = FONT_A_MAX_COLS
    
    -- No emphasis or font changes turned on yet.
    mode = 0
    
    -- Let's begin with a "reset all".
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

-- Moves to the new line unless we are already in the beginning of the line. 
self._newline_if_needed = function(_self)
    if line:len() > 0 then 
        table.insert(lines, line)
        line = ""
        col = 0
    end
end

-- Flushes the current line and returns an array of lines collected so far back, 
-- resets the lines and the state of the document.
self.finish = function(_self)
    _self:_newline_if_needed()
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
local cp437_map =
"\0\199\0\252\0\233\0\226\0\228\0\224\0\229\0\231\0\234\0\235\0\232\0\239\0\238\0\236\0\196\0\197\0\201\0\230\0\198\0\244\0\246\0\242\0\251\0\249\0\255\0\214\0\220\0\162\0\163\0\165\32\167\1\146\0\225\0\237\0\243\0\250\0\241\0\209\0\170\0\186\0\191\35\16\0\172\0\189\0\188\0\161\0\171\0\187\37\145\37\146\37\147\37\2\37\36\37\97\37\98\37\86\37\85\37\99\37\81\37\87\37\93\37\92\37\91\37\16\37\20\37\52\37\44\37\28\37\0\37\60\37\94\37\95\37\90\37\84\37\105\37\102\37\96\37\80\37\108\37\103\37\104\37\100\37\101\37\89\37\88\37\82\37\83\37\107\37\106\37\24\37\12\37\136\37\132\37\140\37\144\37\128\3\177\0\223\3\147\3\192\3\163\3\195\0\181\3\196\3\166\3\152\3\169\3\180\34\30\3\198\3\181\34\41\34\97\0\177\34\101\34\100\35\32\35\33\0\247\34\72\0\176\34\25\0\183\34\26\32\127\0\178\37\160\0\160"

-- A map with additional important characters that we can still show in cp347.
local cp437_quick_map = {
    -- The vertical quote for a Unicode apostrophe.
    [0x2019] = 39,
    -- The dumb quotation mark for the left and right quotation marks.
    [0x201C] = 34,
    [0x201D] = 34,
    -- The minus for different kind of dashes.
    [0x2012] = 45,
    [0x2013] = 45,
    [0x2014] = 45,
    [0x2015] = 45
}

-- CP437 character used instead of unknown Unicode codepoints.
local unknown_char = 240

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
                
                -- For the 16-bit ones let's check with our maps.
                
                -- First with a quick one.
                local ch = cp437_quick_map[b]
                if ch then return ch end
                
                -- Then with the larger, but slower one.
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
    
    -- Let's try to recalculate the current position in case somebody will use this in the middle of a string.
    col = (col * max_cols + prev_max_cols - 1) / prev_max_cols

    _self:_with_mode(1, callback)
    
    -- Let's try to recalculate again, though precision is not going to be good.
    col = (col * prev_max_cols + max_cols - 1) / max_cols

    max_cols = prev_max_cols
end

-- Sets the bold font mode, calls the given function and returns back to the normal font mode.
self.with_emphasis = function(_self, callback)
    _self:_with_mode(8, callback)
end

-- Sets alignment to center, calls the given function and restores the alignment back.
self.centered = function(_self, callback)
    _self:_add_codes("\027a\001")
    callback()
    _self:_add_codes("\027a\000")
end

-- Feeds forward the specified number of lines.
self.empty_lines = function(_self, N)
    _self:_newline_if_needed()
    for i = 1, N do
        _self:_add_codes("\n")
    end
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
                -- Ignoring all control codes in the beginning of the line except for LF (to allow empty lines).
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
