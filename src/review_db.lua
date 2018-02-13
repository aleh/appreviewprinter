local file_names = function(name)
    return name .. ".index", name .. ".content"
end

-- True if the DB with the given name exists.
local exists = function(name)
    local index_file_name, content_file_name = file_names(name)
    return file.exists(index_file_name) and file.exists(content_file_name)
end

--[[ 
    Moves the DB with name from_name to one with to_name. 
    If there is a DB with to_name already, then it will be replaced. 
    Returns true, of succeeded.
]]--
local move = function(from_name, to_name)
    local from_index, from_content = file_names(from_name)
    local to_index, to_content = file_names(to_name)
    file.remove(to_index)
    file.remove(to_content)
    return file.rename(from_index, to_index) and file.rename(from_content, to_content)
end

--[[
    Opens the review DB with the given name in 'reader' or 'writer' mode, the instance has the following methods:
    
    db:close() — closes the DB.
    db:has_error() — true, if there was an error writing or reading the DB.
    
    In 'writer' mode:
    - db:write(review) — writes the given review into the DB (available in the 'writer' modd.
    
    In 'reader' mode:
    - db:reset() — resets the next review cursor into the beginning of the file.
    - db:read(all) — reads the next review from the file; 
        if all is true, then all the fields are returned (pos, id, rating, author, title, body); 
        otherwise only pos, id, and rating are available.
    - db:find_by_id(id) — returns partial review with the given ID or nil if the review was not found or an error occurred.
]]--
local new = function(mode, name)
            
    package.loaded["review_db"] = nil
    
    local self = {}
    
    assert(mode == 'reader' or mode == 'writer')
    assert(name ~= nil and type(name) == 'string')        
            
    local index_file = nil
    local content_file = nil
    local error = false
    
    local index_file_name, content_file_name
    
    local log = function(msg, ...)
        print(string.format("review_db: " .. msg, ...))
    end        
    
    local fail = function(msg)
        if not error then
            log("failed: %s", msg)
            error = true
            self:close()
        end
    end        
    
    log("%s: opening '%s'", mode, name)
    
    local index_file_name, content_file_name = file_names(name)
    
    local file_mode
    if mode == 'writer' then
        file_mode = "w+"
    else
        file_mode = "r"
    end
    
    local index_file = file.open(index_file_name, file_mode)        
    if not index_file then 
        log("could not open the index file '%s'", name)
        return nil
    end
    
    local content_file
    if mode == 'writer' then
        content_file = file.open(content_file_name, file_mode)
        if not content_file then
            log("could not open the content file for writing")
            return nil
        end
    else
        -- Will open is lazily when in the reader mode.
    end

    self.has_error = function(_self)
        return error
    end
    
    self.close = function(_self)
        if index_file then
            index_file:close()
            index_file = nil
        end            
        if content_file then
            content_file:close()
            content_file = nil
        end
        if error then
            if mode == 'writer' then
                log("trying to remove the files because something went wrong")
                file.remove(content_file_name)
                file.remove(index_file_name)
            end
        end
    end
    
    local index_format = "<! LB L LH LH LH"
    
    if mode == 'writer' then 
                       
        local write_content = function(s)
        
            local offset = content_file:seek()
            if offset == nil then return nil end
        
            if not content_file:write(s) then return nil end
        
            local offset_after = content_file:seek()
            if offset_after == nil then return nil end
        
            return offset, offset_after - offset
        end
        
        local hash = function(s)
            local r = 0
            for i = 1, s:len() do
                r = bit.bxor(s:byte(i), bit.bor(bit.rshift(r, 32 - 3), bit.lshift(r, 3)))
            end
            return r
        end            
                
        self.write = function(_self, review)
                    
            if error then return false end
        
            -- Content first.
            local title_offset, title_len = write_content(review.title)
            local author_offset, author_len = write_content(review.author)
            local body_offset, body_len = write_content(review.content)
        
            if not title_offset or not author_offset or not body_offset then 
                fail("could not write the contents of a review")
                return false 
            end

            --[[
            local hasher = crypto.new_hash("SHA1")
            -- Don't care about changes in the author field, only title/content
            hasher:update(review.title)
            hasher:update(review.content)
            local digest = hasher:finalize()
            ]]--
            
            local digest = hash(review.title) + hash(review.content)        
                    
            -- Then the index.
            local record = struct.pack(
                index_format, 
                tonumber(review.id), tonumber(review.rating), 
                digest,
                title_offset, title_len,
                author_offset, author_len,
                body_offset, body_len
            )
            if not index_file:write(record) then 
                fail("could not write an index record")
                return false 
            end
        
            return true
        end

    else
        
        local index_record_size = struct.size(index_format)
                
        local position = 0
        local total_records = 0
        
        self.reset = function(_self)
            local end_pos = index_file:seek('end')
            if end_pos == nil then 
                fail("could not determine the size of the index file")
                return false
            end
            total_records = end_pos / index_record_size
            position = 0
            return true
        end
        
        if not self:reset() then return nil end
                
        local read_content = function(offset, len)
            
            if not content_file then
                content_file = file.open(content_file_name, file_mode)
                if not content_file then
                    fail("could not open the content file")
                    return nil
                end
            end
            
            if not content_file:seek('set', offset) then return nil end
            return content_file:read(len)
        end
        
        -- Full review for a partial one.
        self.full_review = function(_self, review)
            return _self:read_at(review.pos, true)
        end

        -- A partial or full review at a given position. 
        self.read_at = function(_self, position, all)
            
            if position >= total_records then 
                -- End of file reached.
                return nil 
            end
            
            if index_file:seek('set', position * index_record_size) == nil then                    
                fail(string.format("could not seek a header record at %d", position))
                return nil 
            end
                    
            local record = index_file:read(index_record_size)
            if not record then 
                fail(string.format("could not read a header record at %d", position))
                return nil 
            end
        
            if record:len() ~= index_record_size then
                fail("wrong length of a header record")
                return nil
            end
                        
            local review_id, review_rating, digest,
                title_offset, title_len,
                author_offset, author_len,
                body_offset, body_len = struct.unpack(index_format, record)
        
            local result = { pos = position, id = review_id, rating = review_rating, digest = digest }
        
            if all then
                result.title = read_content(title_offset, title_len)
                result.author = read_content(author_offset, author_len)
                result.content = read_content(body_offset, body_len)
                if not result.title or not result.author or not result.content then
                    fail("could not read the contents of a record")
                    return nil
                end
            end
            
            return result
        end
        
        -- Reads the next review. 
        -- If `all` parameter is true, then all the fields are returned; otherwise the returned review is partial
        -- (has only `id`, `rating` and two service fields, `pos` and ` digest`).
        -- The contents of a partial review can be fetched by passing the `pos` to `read_at` method.
        self.read = function(_self, all)
            
            if error then return nil end 
            
            local result = _self:read_at(position, all)
            if not result then
                return nil
            end
            
            position = position + 1
            
            return result
        end
        
        -- Returns a review by its id or nil it could not find one. Linear search.
        -- Pass `true` for the `all` parameter to get all the content fields as well.
        self.find_by_id = function(_self, id, all)
            self:reset()
            while true do
                local r = self:read(all)
                if not r then return nil end                    
                if r.id == id then return r end
            end
            return nil
        end
    end
    
    return self
end

return {
    exists = exists,
    move = move,
    new = new
}
