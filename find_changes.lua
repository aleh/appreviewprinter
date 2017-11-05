return function(callback)
    
    local function log(message, ...)
        print(string.format("diff: " .. message, ...))
    end
    
    local old_db, new_db, changed = false
    
    local did_finish = function(error)
        
        log("Finishing...")
        
        if old_db then
            old_db:close()
            old_db = nil
        end
        
        if new_db then
            new_db:close()
            new_db = nil
        end
        
        if not error and changed then
            log("Committing the new reviews")
            if not _require("review_db").move("new-reviews", "reviews") then
                log("Could not commit the new reviews")
            end
        end
        
        node.task.post(0, function()
            callback(error)
        end)
    end
            
    local db = _require("review_db")
    if not db.exists("reviews") then
        log("Don't have old reviews yet")
        -- Forcing the move
        changed = true
        did_finish()
        return
    end
    
    old_db = db.new("reader", "reviews")    
    new_db = db.new("reader", "new-reviews")
    db = nil
    
    if not new_db or not old_db then
        did_finish("Could not open one of the databases")
        return
    end

    log("Opened files")
    
    local check_next_review
    check_next_review = function()
        
        local r = new_db:read(false)
        
        if not r then 
            if new_db:has_error() then
                did_finish("Could not read a record")
            else
                did_finish() 
            end
            return
        end
        
        local old_review = old_db:find_by_id(r.id)
        if not old_review then
            log("#%d: new", r.id)
            changed = true
        else
            if r.rating ~= old_review.rating then
                log("#%d: changed rating", r.id)
                changed = true
            elseif r.digest ~= old_review.digest then
                log("#%d: changed contents", r.id)
                changed = true
            else
                log("#%d: no changes", r.id)
            end
        end
        
        node.task.post(0, check_next_review)
    end
    
    node.task.post(0, check_next_review)
end
