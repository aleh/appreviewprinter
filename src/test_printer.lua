local doc = require("printer_doc")

doc:begin()

--[[
doc:_add_raw("123456789|123456789|123456789|1|")
doc:_add_raw("123456789|")
doc:_add_raw("123")
doc:_add_raw("456789|")
doc:_add_raw("123456789|")
doc:_add_raw("1|")
doc:_add_raw("123456789|")
]]--

doc:add_text("123456789|123456789|123456789|1234\n\n123456789|123456789|123456789|")
doc:add_text("12 ")

doc:add_text("Call me Ishmael. Some years ago- never mind how long precisely- having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world. It is a way I have of driving off the spleen and regulating the circulation. Whenever I find myself growing grim about the mouth; whenever it is a damp, drizzly November in my soul; whenever I find myself involuntarily pausing before coffin warehouses, and bringing up the rear of every funeral I meet; and especially whenever my hypos get such an upper hand of me, that it requires a strong moral principle to prevent me from deliberately stepping into the street, and methodically knocking people's hats off- then, I account it high time to get to sea as soon as I can. This is my substitute for pistol and ball. With a philosophical flourish Cato throws himself upon his sword; I quietly take to the ship. There is nothing surprising in this. If they but knew it, almost all men in their degree, some time or other, cherish very nearly the same feelings towards the ocean with me.\n")

doc:add_text("There now is your insular city of the Manhattoes, belted round by wharves as Indian isles by coral reefs- commerce surrounds it with her surf. Right and left, the streets take you waterward. Its extreme downtown is the battery, where that noble mole is washed by waves, and cooled by breezes, which a few hours previous were out of sight of land. Look at the crowds of water-gazers there.")

doc:add_text("\n")

--[[
-- Had the map in hex initially, but this is not supported in Lua 5.1, which is used by Node MCU, so recoding it.
local cp437_map = [[\x00\xC7\x00\xFC\x00\xE9\x00\xE2\x00\xE4\x00\xE0\x00\xE5\x00\xE7\x00\xEA\x00\xEB\x00\xE8\x00\xEF\x00\xEE\x00\xEC\x00\xC4\x00\xC5\x00\xC9\x00\xE6\x00\xC6\x00\xF4\x00\xF6\x00\xF2\x00\xFB\x00\xF9\x00\xFF\x00\xD6\x00\xDC\x00\xA2\x00\xA3\x00\xA5\x20\xA7\x01\x92\x00\xE1\x00\xED\x00\xF3\x00\xFA\x00\xF1\x00\xD1\x00\xAA\x00\xBA\x00\xBF\x23\x10\x00\xAC\x00\xBD\x00\xBC\x00\xA1\x00\xAB\x00\xBB\x25\x91\x25\x92\x25\x93\x25\x02\x25\x24\x25\x61\x25\x62\x25\x56\x25\x55\x25\x63\x25\x51\x25\x57\x25\x5D\x25\x5C\x25\x5B\x25\x10\x25\x14\x25\x34\x25\x2C\x25\x1C\x25\x00\x25\x3C\x25\x5E\x25\x5F\x25\x5A\x25\x54\x25\x69\x25\x66\x25\x60\x25\x50\x25\x6C\x25\x67\x25\x68\x25\x64\x25\x65\x25\x59\x25\x58\x25\x52\x25\x53\x25\x6B\x25\x6A\x25\x18\x25\x0C\x25\x88\x25\x84\x25\x8C\x25\x90\x25\x80\x03\xB1\x00\xDF\x03\x93\x03\xC0\x03\xA3\x03\xC3\x00\xB5\x03\xC4\x03\xA6\x03\x98\x03\xA9\x03\xB4\x22\x1E\x03\xC6\x03\xB5\x22\x29\x22\x61\x00\xB1\x22\x65\x22\x64\x23\x20\x23\x21\x00\xF7\x22\x48\x00\xB0\x22\x19\x00\xB7\x22\x1A\x20\x7F\x00\xB2\x25\xA0\x00\xA0]]
--[[
local cp437_map_51 = ""
for m in string.gmatch(cp437_map, "\\x(%x+)") do
    cp437_map_51 = cp437_map_51 .. string.format("\\%d", tonumber(m, 16))
end
print(cp437_map_51)
]]--

-- These have to look like codes from 0x80 to 0xFF
doc:add_text("ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒ")
doc:add_text("áíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐")
doc:add_text("└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀")
doc:add_text("αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ")

-- Escapes non-ASCII characters in the given string. (%q of string.format() escapes only control characters)
local quoted = function(s)
    local result = ""
    for i = 1, s:len() do
        local b = s:byte(i)
        if 0x20 <= b and b <= 0x7e then
            result = result .. string.char(b)
        elseif b == 0x0a then
            result = result .. "\\n"
        else
            result = result .. string.format("\\x%02x", b)
        end
    end
    return "\"" .. result .. "\""
end

local lines = doc:finish()
for _, v in ipairs(lines) do
    print(quoted(v))
end
