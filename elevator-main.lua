--[[
Elevator Control by Hamish Robertson
Aliases: OminousPenguin, MC username: Peren

Licence: Creative Commons Attribution-NonCommercial-ShareAlike (http://creativecommons.org/licenses/by-nc-sa/3.0/)

This is a LUA program for ComputerCraft, a Minecraft mod by Daniel Ratcliffe aka dan200 (http://www.computercraft.info/)
This program is for controlling elevators from the Railcraft mod (http://www.railcraft.info/)
For help and feedback please use this forum thread: http://www.computercraft.info/forums2/index.php?/topic/1302-railcraft-mod-elevator-control/

This program requires RedPower 2 wires (Core + Digital modules). RedPower 2 is not currently available for MC 1.5

This is version 2b. It is in the beta release stage and so there may be bug. If you believe you have found a bug, please report it at the above forum thread
The following four variables can be used to specify details of the RP2 wiring you have used:
--]]

bundleSide = "bottom" -- The side of the computer to which the bundled cable is attached
elevatorWire = "purple" -- Colour of insulated wire from bundled cable to back of elevator track
detetctorWire = "white" -- Colour of insulated wire from bundled cable to cart detector
boardingWire = "lime" -- Colour of insulated wire from bundled cable to boarding rail

--[[
Use Ctrl+T to terminate the program.

You do not need to change anything below this point.

You are permitted to modify and or build upon this work.
If you make your own version publicly available, then please also publish it at the above forum thread. Thank you and happy coding!
--]]

version = "2.0.3b"
response = http.get("http://pastebin.com/raw.php?i=r3mt8mDD")
if response then
	local sResponse = response.readLine()
	response.close()
	if sResponse ~= version then
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
modemSide,coords,floors = file:read("*l"),file:read("*l"),file:read("*l"); file:close()
iter = string.gmatch(coords, "([^\031]+)") -- create iterator
x,y,z = tonumber(iter()),tonumber(iter()),tonumber(iter());iter = nil
modem = peripheral.wrap(modemSide)

if z ~= nil then
	print("Starting GPS host")
	if not modem.isOpen( gps.CHANNEL_GPS ) then
		print( "Opening GPS channel on "..modemSide.." modem" )
		modem.open( gps.CHANNEL_GPS )
	end
else 
	y = x; x = nil
end

function unserialise(s)
	local t = {}
	t.heights = {}
	mt = {
		__newindex = function(t,k,v)
			t.heights[#t.heights+1] = k
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

function addFloor(sMessage, offset)
	local iter = string.gmatch(sMessage:sub(offset), "([^\031]+)")
	local y,label = tonumber(iter()),iter()
	floors[y] = label
	newFloorTimer = os.startTimer(3)
end

function sortReverse(t)
	table.sort(t.heights, function (a,b) return (a > b) end)
	for i=1,#t.heights do if t.heights[i] == y then t.heights.y = i; break end end
end

function transmit(sChannel, sReplyChannel, sMessage)
	modem.close(sChannel)
	modem.transmit(sChannel, sReplyChannel, sMessage)
	modem.open(sChannel)
end

handlers = {
	modem_message =
		function (_, sChannel, sReplyChannel, sMessage, nDistance)
			if z and sChannel == gps.CHANNEL_GPS and sMessage == "PING" then
				-- Received GPS ping, send response
				transmit( sReplyChannel, gps.CHANNEL_GPS, textutils.serialize({x,y,z}) )
			elseif sChannel == CHANNEL_ELEVATOR and sMessage:sub(1,13) == "ELEV_ANNOUNCE" then
				-- Received elevator floor announcement broadcast, add floor to local table
				addFloor(sMessage,14)
				-- Send reply of own y and label
				transmit( sReplyChannel, CHANNEL_ELEVATOR, "ELEV_REPLY"..y.."\031"..floors[y] )
			elseif sChannel == os.getComputerID() and sMessage:sub(1,10) == "ELEV_REPLY" then
				-- Received a reply to own announcement
				addFloor(sMessage,11)
			elseif sChannel == CHANNEL_ELEVATOR and sMessage:sub(1,13) == "ELEV_ACTIVATE" then
				acceptInput = false
				if tonumber(sMessage:sub(14)) == y then
					ignoreDetector = false
					rs.setBundledOutput(bundleSide, colors[elevatorWire])
					term.clear()
					term.setCursorPos(19,7)
					term.write("Incoming cart")
					term.setCursorPos(15,9)
					term.write("Please clear the track")
				else
					displayBusy()
				end
			elseif sChannel == CHANNEL_ELEVATOR and sMessage:sub(1,9) == "ELEV_CALL" then
				acceptInput = false
				displayBusy()
				rs.setBundledOutput(bundleSide, colors[boardingWire])
				sleep(1)
				rs.setBundledOutput(bundleSide, 0)
			elseif sChannel == CHANNEL_ELEVATOR and sMessage == "ELEV_CLEAR" then
				if departedTimer then departedTimer = nil end
				acceptInput = true
				renderFloorList()
			end
		end,

	key =
		function (keycode)
			if acceptInput then
				if (keycode == 200) then -- up
					if selected > 1 then
						local previousSelection = selected
						if selected-1 == floors.heights.y then
							if selected > 2 then selected = selected-2 end
						else 
							selected = selected-1
						end
						redrawSelected(previousSelection)
					end
				elseif (keycode == 208) then -- down
					if selected < #floors.heights then
						local previousSelection = selected
						if selected+1 == floors.heights.y then
							if selected < #floors.heights-1 then selected = selected+2 end
						else 
							selected = selected+1
						end
						redrawSelected(previousSelection)
					end
				elseif (keycode == 57) then -- Space
					ignoreDetector = false
					acceptInput = false
					rs.setBundledOutput(bundleSide, colors[elevatorWire])
					transmit(CHANNEL_ELEVATOR, os.getComputerID(), "ELEV_CALL")
					term.clear()
					term.setCursorPos(20,8)
					term.write("Cart called")
				elseif keycode == 28 and selected ~= floors.heights.y then -- enter
					transmit(CHANNEL_ELEVATOR, os.getComputerID(), "ELEV_ACTIVATE"..floors.heights[selected])
					rs.setBundledOutput(bundleSide, colors[boardingWire])
					acceptInput = false
					term.clear()
					term.setCursorPos(20,8)
					term.write("Bon Voyage")
					term.setCursorPos(20,10)
					term.write("Press Esc")
					sleep(1)
					rs.setBundledOutput(bundleSide, 0)
					departedTimer = os.startTimer(2)
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
				file:write(coords.."\n")
				file:write(serialise(floors))
				file:close()
				renderFloorList()
			elseif timerID == departedTimer then
				departedTimer = nil
				displayBusy()
			end
		end,

	redstone =
		function()
			if ignoreDetector == false and colors.test(redstone.getBundledInput(bundleSide), colors[detetctorWire]) then
				ignoreDetector = true
				transmit(CHANNEL_ELEVATOR, os.getComputerID(), "ELEV_CLEAR")
				redstone.setBundledOutput(bundleSide, 0)
				renderFloorList()
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
	term.setCursorPos(19,7)
	term.write("Elevator busy")
	term.setCursorPos(20,9)
	term.write("Please wait")
end

function renderFloorList()
	term.clear()
	if updateAvailble then
		term.setCursorPos(30,1)
		term.write("New version available!")
	end
	local line = 10 - floors.heights.y
	for i=1,#floors.heights do
		term.setCursorPos(13-(tostring(floors.heights[i]):len()),line)
		term.write(floors.heights[i]..": "..floors[floors.heights[i]])
		line = line + 1
	end
	term.setCursorPos(2,18); term.write("Up/Down arrow keys to select destination")
	term.setCursorPos(2,19); term.write("Press Enter to activate         Space to call cart")
	term.setCursorPos(8,9); term.write(">")
	term.setCursorPos(42,9); term.write("<")
	selected = floors.heights.y
	acceptInput = true;
end

function redrawSelected(previousSelection)
	if previousSelection ~= floors.heights.y then
		local line = 9-floors.heights.y+previousSelection
		term.setCursorPos(8,line); term.write(" ")
		term.setCursorPos(42,line); term.write(" ")
	end
	local line = 9-floors.heights.y+selected
	term.setCursorPos(8,line); term.write("[")
	term.setCursorPos(42,line); term.write("]")
end

floors = unserialise(floors)
sortReverse(floors)

-- Announce self to other floors
modem.open( os.getComputerID() )
transmit( CHANNEL_ELEVATOR, os.getComputerID(), "ELEV_ANNOUNCE"..y.."\031"..floors[y] )

if #floors.heights == 1 then
	-- This floor only knows about it's self
	term.clear()
	term.setCursorPos(7,4); term.write("No other floors discovered")
	term.setCursorPos(7,6); term.write("Once the elevator program is started")
	term.setCursorPos(7,7); term.write("on other floors, they will appear here.")
else
	local selected
	renderFloorList()
end

while true do
	handlers:handle(os.pullEvent())
end
