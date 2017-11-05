return {
    
    --[[
    Connects to one of the known networks.
    Parameters:
        - wifi — a table mapping known SSIDs into passwords;
        - callback — function(succeeded, message) — completion handler.
    ]]--
    activate = function(networks, callback)

        assert(networks and callback)
    
        local log = function(message, ...)
            print(string.format("connection: " .. message, ...))
        end

        local state = 'idle'
        local current_ssid = nil

        local enter_idle = function()
            if state ~= 'idle' then
                state = 'idle'
                wifi.sta.eventMonStop()
                log("idle")
            end
        end
    
        local did_connect = function(ip)
    
            if state ~= 'connecting' then
                log("Connected, though don't need to be")
                return
            end
        
            log("Connected to '%s'. IP: %s", current_ssid or "?", ip or "?")
            state = 'connected'
            node.task.post(function()
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
        log("Searching known networks...")
                                    
        wifi.setmode(wifi.STATION)
                
        wifi.sta.getap(function (t)
    
            if state ~= 'connecting' then
                log("Got a list of networks, but don't need a connection at the moment")
                return
            end
            
            for ssid, v in pairs(t) do
                local p = networks[ssid]
                if p then
                                        
                    current_ssid = ssid
                    log("Connecting to '%s'...", current_ssid)
                
                    node.task.post(function ()
                        wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function() 
                            node.task.post(function()            
                                did_fail_to_connect("Could not find an AP to join")
                            end)
                        end)
                        wifi.sta.eventMonReg(wifi.STA_FAIL, function()
                            node.task.post(function()            
                                did_fail_to_connect("Failed") 
                            end)
                        end)
                        wifi.sta.eventMonReg(wifi.STA_GOTIP, function() 
                            node.task.post(function()            
                                did_connect(wifi.sta.getip())
                            end)
                        end)

                        wifi.sta.eventMonStart(500)
                    
                        wifi.sta.config(ssid, p)
                    end)
                    return
                end
            end
    
            did_fail_to_connect("Don't see any known networks")
        end)
    end
}
