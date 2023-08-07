--
-- Looking for changes in the "new" DB compared to the "old" one.
-- 
return function()
    
    set_state('processing')
    
    _require("find_changes")(function(error, reviews)
        if error then
            enter_idle(true)
        else
			enter_idle(false)
            -- node.task.post(0, function()
            --    enter_printing(reviews)
            -- end)
        end
    end)
end
