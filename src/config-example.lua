-- App Store Review Printer.
-- Copyright (C) 2018-2021, Aleh Dzenisiuk. All rights reserved.

return {
    networks = {
        ["network1"] = "password1",
        ["network2"] = "password2"
    },
    feed = {
        host = "itunes.apple.com", 
        port = 80,
        -- Put your app ID here. This one is for Instagram.
        path = "/us/rss/customerreviews/id=389801252/sortby=mostrecent/json"
    }
}
