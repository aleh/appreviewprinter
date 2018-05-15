-- App Store Review Printer.
-- Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

return {
    
    -- Iterator through codepoints of a UTF8 string.
    codepoints = function(text)
    
        -- The state will be the number of extra bytes we expect.
        local state = 0

        -- Use bit32 module instead of NodeMCU's "bit" on a dektop.
        local _bit
        if bit32 then _bit = bit32 else _bit = bit end
    
        local i = 1
        local len = text:len()
    
        return function()
            local code = 0
            while i <= len do
                
                local b = text:byte(i)
                --~ print(i, state, string.format("0x%x", b))
                
                -- Incrementing the index now, so we can return anytime.
                i = i + 1
                
                if state == 0 then
                    -- Expecting a normal or start of a multi-byte sequence.
                    if b <= 0x7F then
                        -- Normal ASCII code, no bytes to follow.
                        return b
                    elseif _bit.band(b, 0xE0) == 0xC0 then
                        -- 110xxxxx, 1 more byte to follow.
                        code = _bit.band(b, 0x1F)
                        state = 1
                    elseif _bit.band(b, 0xF0) == 0xE0 then
                        -- 1110xxxx, 2 more bytes to follow.
                        code = _bit.band(b, 0x0F)
                        state = 2
                    elseif _bit.band(b, 0xF8) == 0xF0 then
                        -- 11110xxx, 3 more bytes to follow.
                        code = _bit.band(b, 0x07)
                        state = 3
                    else
                        -- A byte out of sync (10xxxxxx) or something invalid 0xF8-0xFF, skipping.
                        --~ error(string.format("An out of sync byte at %d", i))
                    end
                else
                    if _bit.band(b, 0xC0) == 0x80 then
                        code = _bit.lshift(code, 6) + _bit.band(b, 0x3F)
                        state = state - 1
                        if state == 0 then
                            return code
                        end
                    else
                        -- Oops, has no prefix. Ignoring and jumping to state 0 to resync.
                        state = 0
                        --~ error(string.format("No prefix at %d", i))
                    end
                end
                
            end
            
            return nil
        end
    end
}