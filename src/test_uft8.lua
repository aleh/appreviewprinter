-- App Store Review Printer.
-- Copyright (C) 2018-2021, Aleh Dzenisiuk. All rights reserved.

local utf8 = require('utf8')

local as_array = function(text)
    local result = {}
    for c in utf8.codepoints(text) do
        table.insert(result, c)
    end
    return result
end

local int_array_as_string = function(a)
    local result = ""
    for i, v in ipairs(a) do
        if result:len() > 0 then
            result = result .. ", "
        end
        result = result .. string.format("0x%02X", v)
    end
    return "[ " .. result .. " ]"
end

local array_as_string = function(a)
    local result = ""
    for i, v in ipairs(a) do
        if result:len() > 0 then
            result = result .. ", "
        end
        result = result .. string.format("%q", v)
    end
    return "[ " .. result .. " ]"
end

local assert_equal_arrays = function(a, b)
    assert(#a == #b, string.format("different lengths: %d vs %d", #a, #b))
    for i = 1,#a do
        assert(a[i] == b[i], string.format("mismatch at #%d: %s != %s", i, tostring(a[i]), tostring(b[i])))
    end
end

local cases = {
    { "",  {} },
    { "AB", { 65, 66 } },
    { "A\x7FB", { 65, 0x7F, 66 }},
    { "A©B", { 65, 0xA9, 66 }},
    { "AÿB", { 65, 0xFF, 66 }},
    { "AĀB", { 65, 0x100, 66 }},
    { "AЖB", { 65, 0x416, 66 }},
    { "A—B", { 65, 0x2014, 66 }},
    { "A👱B", { 65, 0x1f471, 66 }},
}

for i, case in ipairs(cases) do
    print()
    print(string.format("#%d: %q", i, case[1]))
    
    print("", int_array_as_string(case[2]))
    
    local a = as_array(case[1])
    print("", int_array_as_string(a))
    
    assert_equal_arrays(a, case[2])
end

print()
print("Checking for_each_chunk()...")

local split = function(str, max_size)
    local result = {}
    require("util").for_each_chunk(
        str, 
        max_size, 
        function(s)
            table.insert(result, s)
        end,
        function()
        end
    )
    return result
end

local split_cases = {
    { "12345678", { "1234", "5678" } },
    -- 2 bytes sequence
    { "123©678", { "123", "©67", "8" } },
    { "12©5678", { "12©", "5678" } },
    -- 3 bytes sequence
    { "123—78", { "123", "—7", "8" } },
    { "12—678", { "12", "—6", "78" } },
    { "1—5678", { "1—", "5678" } },
    { "—45678", { "—4", "5678" } },
    -- 4 bytes sequence
    { "123👱8", { "123", "👱", "8" } },
    { "12👱78", { "12", "👱", "78" } },
    { "1👱678", { "1", "👱", "678" } },
    { "👱5678", { "👱", "5678" } },
}
for i, case in ipairs(split_cases) do
    print()
    print(string.format("#%d: %q", i, case[1]))
    
    print("", array_as_string(case[2]))
    
    local a = split(case[1], 4)
    print("", array_as_string(a))
    
    assert_equal_arrays(a, case[2])
end

print("\nDone")
