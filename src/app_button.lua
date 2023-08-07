-- Decides what to do when the push button is pressed in certain way.
return _require("button")(7, function(click_count, hold)

	if hold then
		log("%d-click & hold", click_count)
	else		
		log("%d-click", click_count)
	end

	if click_count == 1 then
		if hold then
			node.dsleep(1000)
		else
			-- If we called it directly, then the button handler would not be able to unload.
			node.task.post(0, check)
		end
	elseif click_count == 2 then
		node.task.post(0, print_new)
	end
end)
