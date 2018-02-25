local function log(message, ...)
    print(string.format("find_changes: " .. message, ...))
end

-- How many changed reviews we can print at once.
local max_reviews_to_print = 3
local old_db, new_db, error, changed = false
local has_old_reviews

local set_error = function(msg)
    if not error then
        log(msg)
        error = msg
    end
end

local open = function()
    
    error = nil
    
    local db = _require("review_db")
    
    new_db = db.new("reader", "new-reviews")
    
    has_old_reviews = db.exists("reviews")
    if has_old_reviews then
        old_db = db.new("reader", "reviews")
    else
        log("has no old reviews yet, everything will be new")
    end
    
    db = nil

    if not new_db or (not old_db and has_old_reviews) then
        set_error("could not open one of the databases")
        return false
    end
    
    return true
end

local close = function(should_commit)
    
    log("closing databases");

    if old_db then
        old_db:close()
        old_db = nil
    end
    
    if new_db then
        new_db:close()
        new_db = nil
    end                

    if should_commit then
        
        if error then 
            log("not committing: there was an error along the way");
            return false 
        end
        
        log("committing")
    
        if _require("review_db").move("new-reviews", "reviews") then
            log("done")
            return true
        else
            set_error("could not commit the new reviews")
            return false
        end
    else
        log("no need to commit");
    end
end

local next = function()
    
    if error then return 'error' end
    
    local r = new_db:read(false)
    
    if not r then 
        if new_db:error() then
            set_error(string.format("could not read the next new review: %s", new_db:error()))
            return 'error'
        else
            return 'end'
        end
    end
    
    if not has_old_reviews then
        return 'new', r, 0
    end
    
    local old_review = old_db:find_by_id(r.id)
    if not old_review then
        return 'new', r, 0
    else
        if r.rating ~= old_review.rating then
            return 'rating', r, old_review.flags
        elseif r.digest ~= old_review.digest then
            return 'contents', r, old_review.flags
        else
            return 'none', r, old_review.flags
        end
    end
end

return {
        
    run = function(_self, callback)
        
        if not open() then
            callback("could not open the databases")
            return
        end
        
        log_heap("opened DBs")
        
        local something_changed = false
        
        local did_finish = function(error)            
            close(something_changed and error == nil)
            if error then
                callback(error)
            else
                callback(nil, reviews_to_print)
            end
        end
                        
        local process_next_change
        process_next_change = function()
        
            local change, review, flags = next()
            if change == 'error' then
                did_finish("could not fetch the next review")
                return
            elseif change == 'end' then 
                did_finish(nil)
                return
            end
                                
            if change ~= 'none' then                 
                review.flags = bit.bor(flags, 1)
                something_changed = true
                log("#%d: %s", review.id, change)
            else
                review.flags = flags
                log("#%d: no changes", review.id)
            end
                        
            if not new_db:update(review) then
                did_finish("could not update flags of the review #%d", review.id)
                return
            end            
            
            node.task.post(0, process_next_change)
        end
        
        node.task.post(0, process_next_change)        
    end
}