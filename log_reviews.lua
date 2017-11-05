return function(callback)
    
    local stars = function(n)
        local result = ""
        for i = 1, 5 do
            if i <= n then
                result = result .. "*"
            else
                result = result .. "."
            end
        end
        return result
    end    

    local db
    
    local write_next_review
    write_next_review = function()
        local r = db:read(true)
        if r then
            print(string.format("%s %s (by %s) #%s\n\n%s\n", stars(r.rating), r.title, r.author, r.id, r.content))
            node.task.post(0, write_next_review)
        else
            db:close()
            db = nil
            node.task.post(0, function() 
                callback()
            end)
        end
    end
    
    db = _require("review_db").new("reader", "new-reviews")
    if db then
        node.task.post(0, write_next_review)
    else
        node.task.post(0, function()
            callback("Could not open the review DB")
        end)
    end
end