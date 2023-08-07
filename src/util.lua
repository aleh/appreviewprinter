-- App Store Review Printer.
-- Copyright (C) 2018-2021, Aleh Dzenisiuk. All rights reserved.

-- Stub NodeMCU-specific stuff to be able to test it on a desktop.
if not node then
    node = { task = { post = function(prio, callback) callback() end } }
end
if not bit then bit = bit32 end

return {

    -- Calls chunk_callback asynchronously one or more times each time passing the next part of the given UTF-8 
    -- string not larger than max_chunk_size; calls done_callback afterwards. 
    -- While doing so it tries to avoid cutting UTF-8 sequences in the middle.
    for_each_chunk = function(str, max_chunk_size, chunk_callback, done_callback)
        
        assert(str ~= nil)
        -- In the worst case we might need to go back for up to 3 bytes and still have something to feed the callback with.
        assert(max_chunk_size > 3)
        assert(chunk_callback ~= nil)
        assert(done_callback ~= nil)
        
        local next_chunk
        local i = 1
        next_chunk = function()
            
            local left = str:len() - i + 1
            
            if max_chunk_size >= left then
                chunk_callback(str:sub(i, i + left - 1))
                done_callback()
            else
                
                local last = i + max_chunk_size - 1

                -- Let's check if the character after the next one can potentially be a part of a UTF-8 sequence.
                if bit.band(0xC0, str:byte(last + 1)) == 0x80 then
                    
                    -- Yes, it can be, though it can also be a stray byte with its first bits being 10, 
                    -- so let's try to find the start byte to be sure.
                    
                    local j = last
                    
                    -- The start byte cannot be very far from here. If there is one further, then it's not related 
                    -- to the byte after the last one.
                    local min_j = j - 2
                    
                    repeat
                        local b = str:byte(j)
                        if bit.band(0xE0, b) == 0xC0 or bit.band(0xF0, b) == 0xE0 or bit.band(0xF8, b) == 0xF0 then
                            -- OK, found a start byte. We are not 100% sure that it begins a sequence our byte 
                            -- belongs to, but anyway it should be safe to finish our cut just before. 
                            last = j - 1
                            break
                        end
                        j = j - 1
                    until j < min_j
                    
                else
                    -- No, the next character cannot be a part of a sequence, we can cut where we have 
                    -- initially decided.
                end
                
                chunk_callback(str:sub(i, last))
                
                i = last + 1
                node.task.post(0, next_chunk)
            end
        end
        
        node.task.post(0, next_chunk)
    end
}
