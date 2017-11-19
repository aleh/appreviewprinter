local max_cols = 32

return {
    
    doc = function()
        
        local self = {}
        
        local lines, line, col
        
        self.begin = function(_self)
            lines = {}
            line = ""
            col = 0
        end
        
        self.add_text = function(_self, text)            
            -- TODO: escape/encode
            -- TODO: word wrapping
            for i = 1, text:len() do
                local ch = text:sub(i)
                if ch == "\n" or col >= max_cols then
                    table.insert(lines, line)
                    line = ""
                    col = 0
                else
                    col = col + 1
                end
                line = self.line .. ch
            end
        end
        
        self.finish = function(_self)
            if line:len() > 0 then
                table.insert(lines, line)
            end
            local result = lines
            self:begin()
        end
        
        self:begin()
        
        return self
    end,
    
    submit = function(self, doc, callback)        
        
        print(string.format("Printing: '%s'", doc))
        tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
            callback(nil)
        end)
    end
}
