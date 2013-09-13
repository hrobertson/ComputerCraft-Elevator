--[[
Elevator Control by Hamish Robertson
Aliases: OminousPenguin, MC username: Peren

Licence: Creative Commons Attribution-NonCommercial-ShareAlike (http://creativecommons.org/licenses/by-nc-sa/3.0/)

This is a LUA program for ComputerCraft, a Minecraft mod by Daniel Ratcliffe aka dan200 (http://www.computercraft.info/)
This program is for controlling elevators from the Railcraft mod (http://www.railcraft.info/)
For help and feedback please use this forum thread: http://www.computercraft.info/forums2/index.php?/topic/1302-railcraft-mod-elevator-control/

This is version 2b. It is in the beta release stage and so there may be bug. If you believe you have found a bug, please report it at the above forum thread
The following four variables can be used to specify details of the RP2 wiring you have used:
--]]

bundleSide = "bottom" -- The side of the computer to which the bundled cable is attached
elevatorWire = "purple" -- Colour of insulated wire from bundled cable to back of elevator track. Purple = 10th color on rednet cable
detetctorWire = "white" -- Colour of insulated wire from bundled cable to cart detector. White = default color on rednet cable
boardingWire = "lime" -- Colour of insulated wire from bundled cable to boarding rail. Lime = 5th color on rednet cable

--[[
Use Ctrl+T to terminate the program.

You do not need to change anything below this point.

You are permitted to modify and or build upon this work.
If you make your own version publicly available, then please also publish it at the above forum thread. Thank you and happy coding!
--]]

version = "2.1.0b"
response = http.get("http://pastebin.com/raw.php?i=r3mt8mDD") -- beginnings 
if response then
	latestVersion = response.readLine()
	response.close()
	if latestVersion ~= version then
		updateAvailble = true
	end
end

CHANNEL_ELEVATOR = 34080
acceptInput, ignoreDetector, newFloorTimer, departedTimer = false, true, nil, nil
dir = shell.getRunningProgram(); i = string.find(dir, "/")
if i then
	config = dir:sub(1,i).."/elevator.cfg"
else
	config = "elevator.cfg"
end
print(config)
file = assert(io.open(config, "r"), "Failed to open elevator.cfg\nRun setup.lua first")
modemSide,elevID,coords,floors = file:read("*l"),file:read("*l"),file:read("*l"),file:read("*l"); file:close()
iter = string.gmatch(coords, "([^\031]+)") -- create iterator
x,y,z = tonumber(iter()),tonumber(iter()),tonumber(iter());iter = nil
modem = peripheral.wrap(modemSide)

if z ~= nil then
	print("Starting GPS host")
	if not modem.isOpen(gps.CHANNEL_GPS) then
		print("Opening GPS channel on "..modemSide.." modem")
		modem.open(gps.CHANNEL_GPS)
	end
else 
	y = x; x = nil
end

function writeToPos(x, y, str)
	term.setCursorPos(x, y)
	term.write(str)
end

function updateMenu()
	term.clear()
	local selected = 1
	writeToPos(4, 2, "Current version: "..version)
	writeToPos(5, 3, "Latest version: "..latestVersion)
	writeToPos(4, 5, "Please select one of the following options:")
	writeToPos(6, 7, "[x] Update all elevators within range")
	writeToPos(6, 8, " x  Update this elevator")
	writeToPos(6, 9, " x  Just update this computer")
	writeToPos(1, 19, "Arrow keys change selection    Backspace to go back")	

	local function changeSelection(previousSelection)
		writeToPos(6,6+previousSelection," x ")
		writeToPos(6,6+selected,"[x]")
	end

	local updateFunctions = {
		function () -- Selection 1: Update all elevators in range
			transmit(CHANNEL_ELEVATOR, os.getComputerID(), "UPDATE", true)
		end,
		function () -- Selection 2: Update this elevator
			
		end,
		function () -- Selection 3: Just update this computer
			
		end
	}

	local eventHandlers = {
		key =
			function (keycode)
					if (keycode == 200) then -- up
						if selected > 1 then
							selected = selected - 1
						end
						changeSelection(selected + 1)
					elseif (keycode == 208) then -- down
						if selected < 3 then
							selected = selected + 1
						end
						changeSelection(selected - 1)
					elseif keycode == 28 then -- enter
						updateFunctions[selected]()
					end
			end,
		
		handle =
			function (self, f, ...)
				f = self[f]
				if type(f) == "function" then return f(...) end
			end
	}

	while true do
		eventHandlers:handle(os.pullEvent())
	end
end -- updateOptions()

function unserialise(s)
	local t = {}
	t.heights = {}
	mt = {
		-- The table t uses the y coord as it's indices which are therefore not contiguous and so the retrevial order can not be relied upon.
		-- The 'heights' table is a contiguously indexed array whos values are the y coords of each floor. This enables us to sort the floors into (reverse) height order.
		__newindex = function(t,k,v)
			t.heights[#t.heights+1] = k -- k is the height coordinate of the floor
			rawset(t,k,v)
		end
	}
	setmetatable(t, mt)
	for u in string.gmatch(s, "[^\030]+") do
		local iter = string.gmatch(u, "([^\031]+)")
		t[tonumber(iter())] = iter()
	end
	return t
end

function serialise(t)
	local s = ""
	for i=1,#t.heights do
		s = s..t.heights[i].."\31"..t[t.heights[i]].."\30"
	end
	return s
end

function addFloor(sMessage)
	local iter = string.gmatch(sMessage, "([^\031]+)")
	local y,label = tonumber(iter()),iter()
	floors[y] = label
	newFloorTimer = os.startTimer(3)
end

function sortReverse(t)
	table.sort(t.heights, function (a,b) return (a > b) end)
	for i=1,#t.heights do
		if t.heights[i] == y then
			t.heights.y = i; break -- t.heights.y stores the index of the current floor in the t.heights table
			-- t.heights[t.heights.y] would give the y coordinate of the current floor
			-- t[t.heights[t.heights.y]] would give the text label of the current floor
		end
	end
end

function transmit(sChannel, sReplyChannel, sMessage, tBroadcast)
	-- tBroadcast optionaly specifies that "ALL" should be used instead of the elevator ID
	-- Messages are sent in this format: "ELEV" elevID/"ALL" messageID [messageBody]
	modem.close(sChannel)
	modem.transmit(sChannel, sReplyChannel, "ELEV\030"..(tBroadcast and "ALL" or elevID).."\030"..sMessage)
	modem.open(sChannel)
end

function pause()
	print ("Press any key to continue...")
	os.pullEvent("key")
end

eventHandlers = {
	modemFunctions = {
		["DISCOVER"] = function (sReplyChannel)
		-- Respond to elevator ID discovery request
			print("sending elevID")
			transmit(sReplyChannel, CHANNEL_ELEVATOR, "ID") -- No need for broadcast flag as the code in setup.lua doesn't filter based on elevID
		end,

		--["ID"] This function doesn't exist here as these messages are only for the setup program

		["ANNOUNCE"] = function (sReplyChannel, sMessage)
		-- Received new floor announcement broadcast
			-- Add floor to local table
			addFloor(sMessage)
			-- Send reply of own y and label
			transmit(sReplyChannel, CHANNEL_ELEVATOR, "REPLY\030"..y.."\031"..floors[y])
		end,

		["REPLY"] = function ()
		-- Received a reply to own announcement
			addFloor(sMessage)
		end,

		["ACTIVATE"] = function (sReplyChannel, sMessage)
		-- Elevator activation message from another floor
			acceptInput = false
			-- Check if this floor is the destination
			if tonumber(sMessage:sub(14)) == y then
				ignoreDetector = false
				rs.setBundledOutput(bundleSide, colors[elevatorWire])
				term.clear()
				writeToPos(19,7,"Incoming cart")
				writeToPos(15,9,"Please clear the track")
			else
				displayBusy()
			end
		end,

		["CALL"] = function ()
		-- Received cart call message
			acceptInput = false
			displayBusy()
			-- Pulse the boarding rail to send any cart that might be on it
			rs.setBundledOutput(bundleSide, colors[boardingWire])
			sleep(1)
			rs.setBundledOutput(bundleSide, 0)
		end,

		["CLEAR"] = function ()
		-- Recaived notifcation that a cart has arrived at another floor (and so the elevator is probably clear for use)
			if departedTimer then departedTimer = nil end
			acceptInput = true
			renderFloorList(true)
		end
	},

	modem_message = 
		function (_, sChannel, sReplyChannel, sMessage)
			term.clear()
			print("modem_message")
			if sChannel == CHANNEL_ELEVATOR or sChannel == os.getComputerID() then
				local iter = string.gmatch(sMessage, "([^\030]+)")
				if iter() ~= "ELEV" then return end -- Right channel but not meant for us
				local eID = iter()
				print("point1. eID: "..eID)
				if eID == elevID or eID == "ALL" then -- Correct elevID or message is for all elevators (and there is a corresponding function)
					print("point2")
					local f = eventHandlers.modemFunctions[iter()]
					if type(f) == "function" then
						return f(sReplyChannel, iter()) -- iter() = rest of the message
					end
				end

			-- Reply to GPS ping
			elseif z and sChannel == gps.CHANNEL_GPS and sMessage == "PING" then
				modem.transmit(sReplyChannel, gps.CHANNEL_GPS, textutils.serialize({x,y,z}))
			end
		end,

	key =
		function (keycode)
			if acceptInput then
				if (keycode == 200) then -- up
					if selected > 1 then
						if selected-1 == floors.heights.y then
							if selected > 2 then selected = selected-2 end
						else 
							selected = selected-1
						end
						renderFloorList()
					end
				elseif (keycode == 208) then -- down
					if selected < #floors.heights then
						if selected+1 == floors.heights.y then
							if selected < #floors.heights-1 then selected = selected+2 end
						else 
							selected = selected+1
						end
						renderFloorList()
					end
				elseif (keycode == 57) then -- Space
					ignoreDetector = false
					acceptInput = false
					rs.setBundledOutput(bundleSide, colors[elevatorWire])
					transmit(CHANNEL_ELEVATOR, os.getComputerID(), "CALL")
					term.clear()
					writeToPos(20,8,"Cart called")
				elseif keycode == 28 and selected ~= floors.heights.y then -- enter
					transmit(CHANNEL_ELEVATOR, os.getComputerID(), "ACTIVATE\030"..floors.heights[selected])
					rs.setBundledOutput(bundleSide, colors[boardingWire])
					acceptInput = false
					term.clear()
					writeToPos(20,8,"Bon Voyage")
					writeToPos(20,10,"Press Esc")
					sleep(1)
					rs.setBundledOutput(bundleSide, 0)
					departedTimer = os.startTimer(2)
				elseif keycode == 22 then -- U for update menu
					updateMenu()
				end
			end
		end,

	timer =
		function (timerID)
			if timerID == newFloorTimer then
				newFloorTimer = nil
				sortReverse(floors)
				local file = io.open("elevator.cfg", "w")
				file:write(modemSide.."\n")
				file:write(elevID.."\n")
				file:write(coords.."\n")
				file:write(serialise(floors))
				file:close()
				renderFloorList(true)
			elseif timerID == departedTimer then
				departedTimer = nil
				displayBusy()
			end
		end,

	redstone =
		function()
			if ignoreDetector == false and colors.test(redstone.getBundledInput(bundleSide), colors[detetctorWire]) then
				ignoreDetector = true
				transmit(CHANNEL_ELEVATOR, os.getComputerID(), "CLEAR")
				redstone.setBundledOutput(bundleSide, 0)
				renderFloorList(true)
			end
		end,
	
	handle =
		function (self, f, ...)
			f = self[f]
			if type(f) == "function" then return f(...) end
		end
}

function displayBusy()
	term.clear()
	writeToPos(19,7,"Elevator busy")
	writeToPos(20,9,"Please wait")
end

function renderFloorList(reset)
	if reset then selected = floors.heights.y end
	term.clear()
	if updateAvailble then
		writeToPos(30,1,"New version available!")
		writeToPos(33,2,"Press U for options")
	end
	local startIndex, line = 1, 1
	if selected > 9 then
		startIndex = selected - 8
	else
		line = 10 - selected
	end
	
	for i=startIndex,#floors.heights do
		term.setCursorPos(13-(tostring(floors.heights[i]):len()),line)
		term.write(floors.heights[i]..": "..floors[floors.heights[i]])
		line = line + 1
		if line == 17 then break end -- If we get to the bottom of the screen, stop printing floors
	end

	if selected ~= floors.heights.y then
		midMarkL, midMarkR = ">", "<"
		line = 9 - (selected - floors.heights.y) -- Eg we're on 20, selected is 19: 19 is now at line 9, 20 is at 10 which is 9 - (-1)
		writeToPos(8,line,"-")
		writeToPos(42,line,"-")
	else
		midMarkL, midMarkR = "-", "-"
	end
	writeToPos(8,9,midMarkL)
	writeToPos(42,9,midMarkR)

	writeToPos(2,18,"Up/Down arrow keys to select destination")
	writeToPos(2,19,"Press Enter to activate         Space to call cart")
	acceptInput = true;
end -- renderFloorList()

floors = unserialise(floors)
sortReverse(floors)

-- Announce self to other floors
modem.open(os.getComputerID())
transmit(CHANNEL_ELEVATOR, os.getComputerID(), "ANNOUNCE\030"..y.."\031"..floors[y])

selected = floors.heights.y

if #floors.heights == 1 then
	-- This floor only knows about it's self
	term.clear()
	writeToPos(7,4,"No other floors discovered")
	writeToPos(7,6,"Once the elevator program is started")
	writeToPos(7,7,"on other floors, they will appear here.")
else
	renderFloorList()
end

while true do
	eventHandlers:handle(os.pullEvent())
end
