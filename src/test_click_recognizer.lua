-- App Store Review Printer.
-- Copyright (C) 2020, Aleh Dzenisiuk. All rights reserved.

-- Working in milliseconds here.
local r = require("click_recognizer")(
	10,		-- Debounce.
	200,	-- Double click.
	500,	-- Hold (as click & hold).
	function(click_count, hold)
		if hold then
			print(string.format(" - %d-click & hold", click_count))
		else
			print(string.format(" - %d-click", click_count))
		end
	end,
	function(level)
		print(string.format("Level: %d", level))
	end
)

print("\n# Click & hold")
r(0, 0)		-- Down.
r(0, 5)		-- Still down, but called earlier than asked, should be safe.
r(1, 8)		-- Bouncing.
r(1, 10)	-- Bouncing.
r(1, 10)	-- Repeating levels and timestamps should not matter.
r(0, 11)	-- Bouncing.
r(1, 12)	-- ...
r(0, 20)	-- ...
r(0, 15)	-- Called earlier for some reason, should be safe.
r(0, 30)	-- Should finally debounce as 0.

r(0, 100)	-- Holding.
r(0, 300)	-- ...
r(0, 400)	-- ...
r(0, 530)	-- Should report click & hold.

r(0, 600)	-- Should not report anything else even after going back to up.
r(0, 800)	-- ...
r(0, 1000)	--
r(1, 2000)	-- 
r(1, 5000)	--

print("\n# Regular click")
r(0, 0)		
r(0, 10)	-- Debounced as 0.
r(0, 20)
r(1, 20)
r(1, 50)	-- Debounced as 1.
r(1, 100)
r(1, 200)
r(1, 350)	-- Should report a single click.
r(1, 500)	-- Should not report anything else.
r(1, 1000)	-- ...
r(1, 5000)	-- ...

print("\n# Double click")
r(0, 0)		
r(0, 10)		
r(1, 20)
r(1, 30)

r(0, 100)
r(0, 110)		
r(1, 120)
r(1, 130)

r(1, 230)	-- Double click, but won't report till clear that no more is coming.

r(1, 430)	-- Holding to indicate that no more clicks are coming.

print("\n# Double click & hold")
r(0, 0)		
r(0, 10)		
r(1, 20)
r(1, 30)

r(0, 100)
r(0, 110)	-- Debounced as 0.
r(0, 610)	-- Double click & hold.

r(0, 800)	-- Should report nothing if holding more
r(0, 1000)	-- ...

r(1, 1500)	-- And even when getting back to 1
r(1, 1510)	-- ...
r(1, 2000)	-- ...
