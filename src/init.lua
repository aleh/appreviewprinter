-- App Store Review Printer.
-- Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

print("init.lua")

node.stripdebug(3)

tmr.create():alarm(
    3000, 
    tmr.ALARM_SINGLE, 
    function()
        if file.exists("init.lua") then
            dofile("application.lc")
        else
            print("no init.lua")
        end
    end
)
