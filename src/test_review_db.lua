-- App Store Review Printer.
-- Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

local max_mem = 0
local print_mem = function()
    collectgarbage()
    local m, _ = collectgarbage('count')
    if m > max_mem then max_mem = m end
    print(string.format("Memory: %dK (max %dK)", m, max_mem))
end

print_mem()

file = io
struct = require('struct')

local writer = require("review_db").new('writer', 'review_db_test')
if not writer then
    print("Could not open the DB")
    return
end

package.path = package.path .. ";./ustream/?.lua"

local parser = require("review_feed_parser").new({
    
    review = function(p, review)
        writer:write(review)
    end,
    
    error = function(p, message)
        writer:close()
        print("Oops: " .. message)
    end,
    
    done = function(p)
        writer:close()
        print("Done")
    end
})

local f = io.open("ustream/test_review_feed.json")
while true do
    local line = f:read(64)
    if not line then break end
    parser:process(line)
end

parser:finish()
parser = nil
print_mem()

f:close()
f = nil
print_mem()

local reader = require("review_db").new('reader', 'review_db_test')
while true do
    local review = reader:read(true)
    if not review then break end
    print(review.id, review.rating, review.title, review.author, review.content)
end
