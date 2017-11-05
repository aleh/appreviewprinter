local file_names = function(name)
    return name .. ".index", name .. ".content"
end

return {

    -- True if the DB with the given name exists.
    exists = function(name)
        local index_file_name, content_file_name = file_names(name)
        return file.exists(index_file_name) and file.exists(content_file_name)
    end,

    --[[ 
        Moves the DB with name from_name to one with to_name. 
        If there is a DB with to_name already, then it will be replaced. 
        Returns true, of succeeded.
    ]]--
    move = function(from_name, to_name)
        local from_index, from_content = file_names(from_name)
        local to_index, to_content = file_names(to_name)
        file.remove(to_index)
        file.remove(to_content)
        return file.rename(from_index, to_index) and file.rename(from_content, to_content)
    end,

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
    new = function(mode, name)
                
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
        
        local index_file_name = name .. ".index"
        local content_file_name = name .. ".content"
        
        local file_mode
        if mode == 'writer' then
            file_mode = "w"
        else
            file_mode = "r"
        end
        
        local index_file = file.open(index_file_name, file_mode)
        local content_file = file.open(content_file_name, file_mode)
        
        if not index_file or not content_file then 
            log("could not open the files for '%s'", name)
            return nil
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
                if not offset_after then return nil end
            
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
            
            local position = 0
            
            self.reset = function(_self)
                index_file:seek('set', 0)
                position = 0
            end
            
            local index_record_size = struct.size(index_format)
            
            local read_content = function(offset, len)
                if not content_file:seek('set', offset) then return nil end
                return content_file:read(len)
            end
            
            self.read = function(_self, all)
                
                if error then return nil end                
                
                local record = index_file:read(index_record_size)
                if not record then return nil end
                
                if record:len() ~= index_record_size then
                    fail("wrong record length")
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
                end
                
                position = position + 1
                
                return result
            end
            
            self.find_by_id = function(_self, id)
                self:reset()
                while true do
                    local r = self:read(false)
                    if not r then return nil end                    
                    if r.id == id then return r end
                end
                return nil
            end
        end
        
        return self
    end
}
