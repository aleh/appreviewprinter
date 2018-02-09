local utf8 = require('utf8')

local as_array = function(text)
    local result = {}
    for c in utf8.codepoints(text) do
        table.insert(result, c)
    end
    return result
end

local array_as_string = function(a)
    local result = ""
    for i, v in ipairs(a) do
        if result:len() > 0 then
            result = result .. ", "
        end
        result = result .. string.format("0x%02X", v)
    end
    return "[ " .. result .. " ]"
end

local assert_equal_arrays = function(a, b)
    assert(#a == #b, string.format("different lengths: %d vs %d", #a, #b))
    for i = 1,#a do
        assert(a[i] == b[i], string.format("mismatch at #%d: %d != %d", i, a[i], b[i]))
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
    
    print("", array_as_string(case[2]))
    
    local a = as_array(case[1])
    print("", array_as_string(a))
    
    assert_equal_arrays(a, case[2])
end

print("\nDone")