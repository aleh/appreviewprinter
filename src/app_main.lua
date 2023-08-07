-- App Store Review Printer.
-- Copyright (C) 2018-2022, Aleh Dzenisiuk. All rights reserved.

-- A global non-caching version of `require`, used from submodules.
_require = function(s)
    return dofile(s .. ".lc")
	--[[
    local name = s .. ".lc"
    if file.exists(name) then
        return dofile(name)
    end
    local name = s .. ".lua"
    if file.exists(name) then
        return dofile(name)
    end 
    return nil
	]]--   
end

_require("app_init")

--
-- Connecting to WiFi
--
local enter_connecting = function() 
	_require('app_connect')(function()	
		_require('app_refresh')(function()
			_require('app_parse')()
		end)
	end)
end

--
-- Globals allowing to trigger main actions from the terminal.
--

local check_busy = function()
    if app_state ~= 'idle' then 
        log("busy") 
        return true 
    else
        return false
    end
end

check = function()
    if check_busy() then return end
    enter_connecting()
end

print_new = function()
    if check_busy() then return end
    _require('app_print')()
end

enter_idle(true)

-- Let's see how much heap we begin with.
log_heap()
