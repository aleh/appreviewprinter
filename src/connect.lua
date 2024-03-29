-- App Store Review Printer.
-- Copyright (C) 2018-2021, Aleh Dzenisiuk. All rights reserved.

--[[
Connects to one of the known networks.
Parameters:
    - networks — a table mapping known SSIDs into passwords;
    - callback — function(succeeded, message) — completion handler.
]]--
return function(networks, callback)

	-- assert(networks and callback)

    local log = function(message, ...)
        print(string.format("connect: " .. message, ...))
    end

    local state = 'idle'
    local current_ssid = nil

    local enter_idle = function()
        if state ~= 'idle' then
            state = 'idle'
            wifi.eventmon.unregister(wifi.eventmon.STA_DISCONNECTED)
            wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
            log("idle")
        end
    end

    local did_connect = function(ip)

        if state ~= 'connecting' then
            log("Connected but don't need to be")
            return
        end
    
        log("Connected to '%s'. IP: %s", current_ssid or "?", ip or "?")
        
        enter_idle()
        
        state = 'connected'
        node.task.post(0, function()
            callback(true)
        end)
    end
    
    local did_fail_to_connect = function(msg)
                
        if state == 'connecting' then
            log("Could not connect to '%s': %s", current_ssid or "?", msg)
            enter_idle()
            node.task.post(function()
                callback(false, msg)
            end)
        elseif state == 'connected' then
            enter_idle()
            log("Disconnected: %s", msg)
        else
            log("Disconnected while idle: %s", msg)
        end        
    end        

    if state ~= 'idle' then 
        log("Ignoring activation request")
        return
    end

    current_ssid = nil        
    state = 'connecting'
    log("Searching known SSIDs...")
                                
    wifi.setmode(wifi.STATION)
            
    wifi.sta.getap(function (t)

        if state ~= 'connecting' then
            log("Got SSIDs, but not trying to connect")
            return
        end
        
        for ssid, v in pairs(t) do
            local p = networks[ssid]
            if p then
                                    
                current_ssid = ssid
                log("Connecting to '%s'...", current_ssid)
            
                node.task.post(function ()
                    --[[
                    wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function()
                        node.task.post(function()            
                            did_fail_to_connect("Failed") 
                        end)
                    end)
                    ]]--
                    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function() 
                        node.task.post(function()            
                            did_connect(wifi.sta.getip())
                        end)
                    end)
                    wifi.sta.config({ssid = ssid, pwd = p, auto = true, save = false})
                end)
                return
            end
        end

        did_fail_to_connect("No known SSIDs")
    end)
end
