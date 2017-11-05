print("init.lua")

tmr.create():alarm(
    3000, 
    tmr.ALARM_SINGLE, 
    function()
        if file.open("init.lua") == nil then
            print("init.lua deleted or renamed")
        else
            file.close("init.lua")
            dofile("application.lc")
        end
    end
)
