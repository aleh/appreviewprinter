-- Write-only software USART using the `gpio` module.

return {
        
    new = function(_pin, _baud_rate)

        local self = {}

        local pin = _pin
        local bit_time = 1000000 / _baud_rate                
        
        gpio.mode(pin, gpio.OUTPUT)
        gpio.write(pin, gpio.HIGH)        

        local _write = function(_b)
    
            -- We are beginning with a start bit, which is a logical zero (though it can be represented with the LOW state of the pin).
            local prev_state = false
    
            -- Time till the next toggle is at very least the duration of the start bit.
            local toggle_in = bit_time
            
            local times = {}
            
            -- Let's have the stop bit as a part of the byte.
            local b = bit.bor(_b, 0x100)
    
            -- Repeating 9 times so we have the stop bit handled here too.
            for i = 1, 9 do
                local this_bit_state = bit.band(b, 1) ~= 0
                if prev_state ~= this_bit_state then
                    -- The next bit is different, it's time to toggle!
                    table.insert(times, toggle_in)
                    prev_state = this_bit_state
                    toggle_in = bit_time
                else
                    -- No need to toggle now, just increase our delay till the next toggle.
                    toggle_in = toggle_in + bit_time
                end
                b = bit.rshift(b, 1)
            end
            
            table.insert(times, toggle_in)
            
            -- The initial state here defines whether we'll be using LOW or HIGH for a logic one.
            gpio.serout(pin, gpio.LOW, times)
            gpio.write(pin, gpio.HIGH)
        end
        
        self.write = function(self, data)
            for i = 1, data:len() do
                _write(data:byte(i))
            end
        end

        self.deinit = function(self)
            gpio.mode(pin, gpio.INPUT)
        end
        
        return self
    end
}
