return function(enter_refreshing)

    set_state('connecting')

    _require("connect")(
        _require("config").networks,
        function(succeeded, msg)
            node.task.post(0, function()
                if succeeded then
                    enter_refreshing()
                else
                    log("Could not activate the connection: %s", msg)
                    enter_idle(false)
                end
            end)
        end
    )
end 
