--
-- Printing out the reviews scheduled for printing.
-- 
return function()
    
    set_state('printing')
    
    _require("printer"):print_updated(3, function(error)
        
        if error then
            log("Failed to print updated reviews: %s", error)
        else
            log("Done printing updated reviews")
        end
        
        enter_idle(error == nil)
    end)      
end
