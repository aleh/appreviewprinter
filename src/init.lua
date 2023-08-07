-- App Store Review Printer.
-- Copyright (C) 2018-2021, Aleh Dzenisiuk. All rights reserved.

print("init.lua")

tmr.create():alarm(
    3000, 
    tmr.ALARM_SINGLE, 
    function()
        if file.exists("init.lua") then
            dofile("app_main.lc")
        else
            print("no init.lua")
        end
    end
)
