--[[
Elevator Control Setup by Hamish Robertson
Aliases: OminousPenguin, MC username: Peren

Licence: Creative Commons Attribution-NonCommercial-ShareAlike (http://creativecommons.org/licenses/by-nc-sa/3.0/)

This is a LUA program for ComputerCraft, a Minecraft mod by Daniel Ratcliffe aka dan200 (http://www.computercraft.info/)
This program is for controlling elevators from the Railcraft mod (http://www.railcraft.info/)
For help and feedback please use this forum thread: http://www.computercraft.info/forums2/index.php?/topic/1302-railcraft-mod-elevator-control/

This is version 2b. It is in the beta release stage and so there may be bugs. If you believe you have found a bug, please report it at the above forum thread.

You are permitted to modify and or build upon this work.
If you make your own version publicly available, then please also publish it at the above forum thread. Thank you and happy coding!

NOTE: This is the setup program. It will create a file called elevator.cfg and download the main program to elevator-main.lua

Use Ctrl+T to terminate the program
--]]

CHANNEL_ELEVATOR = 34080

function writeToPos(x, y, str)
	term.setCursorPos(x, y)
	term.write(str)
end
function clearArea(x1,y1,x2,y2)
	for i=y1,y2 do
		writeToPos(x1,i,string.rep(" ",x2-x1))
	end
end
function eventHandle(tHandlers, f, ...)
	f = tHandlers[f]
	if type(f) == "function" then return f(...) end
end
function debug(msg)
	print(msg)
	os.pullEvent("key")
end
function printSetupHeader(saving)
	term.clear()
	writeToPos(2,2,"====================[ Setup ]====================")
	if saving then writeToPos(5,5,"Saving data... "); term.setCursorBlink(true) end
end

function getModemSide()
	-- Find all attached modems
	local sides = {"left","right","top","bottom","back","front"}
	local i = 1
	while i <= #sides do
		if peripheral.getType(sides[i]) ~= "modem" then
			table.remove(sides,i)
		else
			i = i + 1
		end
	end

	if #sides == 0 then
		return nil
	elseif #sides == 1 then
		return sides[1]
	end

	-- If there is more than one modem attached, ask user to choose one
	local selected = 1
	local function redraw()
		printSetupHeader()
		writeToPos(7,9,"Use the modem on the          side")
		for i=1,#sides do
			if (i == selected) then
				writeToPos(29,9,sides[i])
			else
				if (9-selected+i)<9 then
					term.setCursorPos(29,(8-selected+i))
				else 
					term.setCursorPos(29,(10-selected+i))
				end
				term.write(sides[i])
			end
		end--for
		writeToPos(4,18,"[ Arrow keys to select, Enter to confirm ]")
	end--redraw()

	redraw(); -- First draw

	while true do
		local _, keycode = os.pullEvent ("key")
		if (keycode == 200) then -- up
			if selected > 1 then selected = selected-1 end
		elseif (keycode == 208) then -- down
			if selected < 6 then selected = selected+1 end
		elseif (keycode == 28) then -- enter
			return sides[selected]
		end
		redraw()
	end
end--getModemSide()

function getElevatorID()
	local elevatorID
	printSetupHeader()
	writeToPos(3, 4, "Searching for other elevators.")
	writeToPos(3, 6, "This may take a few seconds...")
	writeToPos(5, 10, "(Remember that rain reduces modem range)")
	local modem = peripheral.wrap(modemSide)
	modem.open(os.getComputerID())
	modem.transmit(CHANNEL_ELEVATOR, os.getComputerID(), "ELEV\030ALL\030DISCOVER") -- Ask all elevator terminals in range to tell us their elevator ID
	local tElevatorIDs = {}
	local mt = {
		tMeta = {},
		iIndex = 1,
		__newindex = function(t,k,v)
			this = getmetatable(t)
			if this.tMeta[k] ~= true then
				this.tMeta[k] = true
				rawset(t,this.iIndex,k)
				this.iIndex = this.iIndex + 1
			end
		end,
	}
	setmetatable(tElevatorIDs,mt)
	local _, _, sChannel, sReplyChannel, sMessage
	local discoveryTimer
	local tHandlers = {
		modem_message = function (_, sChannel, sReplyChannel, sMessage, nDistance)
			discoveryTimer = os.startTimer(3) -- Reset timer
			local iter = string.gmatch(sMessage, "([^\030]+)")
			if sChannel == os.getComputerID() and iter() == "ELEV" then
				local eID = iter()
				if iter() == "ID" then
					tElevatorIDs[eID] = true
				end
			end
		end,
		timer = function (timerID)
			if timerID == discoveryTimer then	return true	end
		end
	}
	discoveryTimer = os.startTimer(3) -- Loop will timeout after three seconds of not receiving an event
	while true do
		local v = eventHandle(tHandlers, os.pullEvent())
		if v then break end
	end
	writeToPos(3, 6, "Press any key to continue...  ") -- Pause to let them read the message about rain
	os.pullEvent("key")

	local function getCustomID()
		writeToPos(5, 7, "Please specify an ID: ")
		writeToPos(2, 9, "IDs can have letters, numbers and other characters")
		term.setCursorPos(27, 7); term.setCursorBlink(true)
		return io.read()
	end

	printSetupHeader()
	if #tElevatorIDs == 0 then
		writeToPos(2, 5, "No existing elevators detected.")
		elevatorID = getCustomID()
	else
		writeToPos(2, 5, "The following elevator IDs were detected:")
		writeToPos(3, 18, "Press Enter to use the selected ID")
		writeToPos(3, 19, "Press Tab to create a new elevator ID")
		local selected = 1
		for k,v in ipairs(tElevatorIDs) do
			writeToPos(5, 6+k, v)
		end
		writeToPos(3,7,">")
		local function updateSelection(previousSelection)
			writeToPos(3,6+previousSelection," ")
			writeToPos(3,6+selected,">")
		end
		while true do
			local _, keycode = os.pullEvent ("key")
			if (keycode == 200) then -- up
				previousSelection = selected
				if selected > 1 then selected = selected-1 end
			elseif (keycode == 208) then -- down
				previousSelection = selected
				if selected < #tElevatorIDs then selected = selected+1 end
			elseif (keycode == 28) then -- enter
				elevatorID = tElevatorIDs[selected]
				break
			elseif (keycode == 15) then -- tab
				clearArea(2,5,52,9)
				elevatorID = getCustomID()
				break
			end
			updateSelection(previousSelection)
		end
	end
	return elevatorID
end--getElevatorID()

function getFloorName()
	printSetupHeader()
	writeToPos(7,9,"Enter a name/label for this floor: ")
	term.setCursorPos(14,11); term.setCursorBlink(true)
	local name
	repeat
		name = io.read()
	until name ~= ""
	return name
end--getFloorName()

function getGPS()
	printSetupHeader()
	writeToPos(5, 5, "Waiting for GPS response... ")
	term.setCursorPos(5,7)
	local x, y, z = gps.locate(2)
	if x ~= nil then
		term.write("... coordinates received")
		writeToPos(5, 9, "Start GPS host in the background?")
		local _, keycode, selected = nil, nil, 1
		writeToPos(14,11,"[ Yes ]             No")
		while true do
			term.setCursorPos(14,11)
			_, keycode = os.pullEvent ("key")
			if (keycode == 205) or (keycode == 49) then -- right
				if selected == 1 then
					selected = 2
					term.write("  Yes             [ No ]")
				end
			elseif (keycode == 203) or (keys.getName(keycode) == n) then -- left
				if selected == 2 then
					selected = 1
					term.write("[ Yes ]             No  ")
				end
			elseif (keycode == 28) then -- enter
				if selected == 1 then
					return x,y,z
				else
					return nil, y
				end
			end
		end--while
	else -- We didn't get coords from GPS
		term.write("... could not determine coordinates")
		return
	end
end--getGPS()

function getCoordsInput()
	printSetupHeader()
	writeToPos(8,7,"x coordinate:")
	writeToPos(8,8,"y coordinate:")
	writeToPos(8,9,"z coordinate:")
	writeToPos(4,13,"Important: If your GPS hosts are all in a")
	writeToPos(4,14,"vertical line (same x & y coordinates), then")
	writeToPos(4,15,"you need to place another host off to the side")
	writeToPos(4,16,"to enable an accurate GPS fix")
	writeToPos(4,17,"(Usage: gps host x y z")
	term.setCursorPos(22,7); term.setCursorBlink(true)
	
	local selected, inputs = 1, {"","",""}
	
	local function redraw()
		term.setCursorPos(22+inputs[selected]:len(),6+selected)
	end
	
	local eventHandlers = {
		key = function(keycode)
			if (keycode == 200) and (selected > 1) then -- up
				selected = selected-1
				redraw(selected);
			elseif (selected < 3) and ((keycode == 208) or (keycode == 28)) then -- down
				selected = selected+1
				redraw(selected);
			elseif (keycode == 28) then -- enter
				for i,input in ipairs(inputs) do
					if inputs[selected] == "" then return end
				end
				return inputs[1], inputs[2], inputs[3]
			elseif (keycode == 14) and inputs[selected] ~= "" then -- backspace
					inputs[selected] = inputs[selected]:sub(1,-2)
					term.setCursorPos(22+inputs[selected]:len(),6+selected)
					term.write(" ")
					term.setCursorPos(22+inputs[selected]:len(),6+selected)
			end
		end,

		char = function(c)
			if (inputs[selected]:len() < 4) and (string.find(c, "[%d\-]") ~= nil) then -- number entered
				inputs[selected] = inputs[selected]..c
				term.write(c)
			end
		end,

		handle = function (self, f, ...)
			f = self[f]
			if type(f) == "function" then return f(...) end
		end
	}
	while true do
		local x,y,z = eventHandlers:handle(os.pullEvent())
		if x then return x,y,z end
	end
end--getCoordsInput

function getFloorCoords()
	-- We need at least the y (height) coordinate so we can know what order the floors are in
	printSetupHeader()
	writeToPos(4,4,"The y (height) coordinate is required so that")
	writeToPos(4,5,"floors can be listed in the correct order.")
	writeToPos(4,7,"You have a few options:")
	writeToPos(6,10,"1. Enter y coordinate:")
	writeToPos(6,12,"2. Use GPS (requires 4 GPS hosts)")
	writeToPos(6,14,"3. Enter x,y,z and then this computer")
	writeToPos(13,15,"can become a GPS host.")
	writeToPos(7,16,"(recommended if you have over 4 floors)")
	writeToPos(2,19,"(Press F3 to view player coordinates)")
	
	local selected, line, y = 1, {10,12,14}, ""

	local function redraw(i, clear)
		term.setCursorPos(3,8+(2*i))
		local t = (clear and write(" ")) or write("[")
		term.setCursorPos(49,8+(2*i))
		local t = clear and write(" ") or write("]")
		term.setCursorPos(29,10)
	end

	redraw(1)
	term.setCursorBlink(true)

	local eventHandlers = {
		key = function(keycode)
			if (keycode == 200) then -- up
				if selected > 1 then
					redraw(selected, true)
					selected = selected-1
					if selected == 1 then term.setCursorBlink(true) end
					redraw(selected);
				end
			elseif (keycode == 208) then -- down
				if selected < 3 then
					redraw(selected, true)
					selected = selected+1
					term.setCursorBlink(false)
					redraw(selected);
				end
			elseif (keycode == 28) then -- enter
				if ((selected == 1) and (y ~= "")) then
					return true, nil, y
				elseif selected == 2 then
					return true, getGPS()
				elseif selected == 3 then
					return true, getCoordsInput() -- input all 3
				end
			elseif (keycode == 14) then -- backspace
				if ((selected == 1) and (y ~= "")) then
					y = y:sub(1,-2)
					term.setCursorPos(29+y:len(),10)
					term.write(" ")
					term.setCursorPos(29+y:len(),10)
				end
			end
		end,

		char = function(c)
			if (selected == 1) and ((y:len() < 4) and (string.find(c, "%d") ~= nil)) then -- number entered
				y = y..c
				term.setCursorPos(28+y:len(),10)
				term.write(c)
			end
		end,

		handle = function (self, f, ...)
			f = self[f]
			if type(f) == "function" then return f(...) end
		end
	}
	while true do
		local RETURN,x,y,z = eventHandlers:handle(os.pullEvent())
		if RETURN then return x,y,z end
	end
end--getFloorCoords()

fs.delete("elevator-main.lua")
if not shell.run("pastebin", "get", "iJWyUQVr", "elevator-main.lua") then
	print("Failed to download main program. Try manually from pastebin: iJWyUQVr\n(this is just the setup component)")
	return
end

modemSide = getModemSide()
if modemSide == nil then
	printSetupHeader()
	writeToPos(15,6,"! No modem detected !")
	writeToPos(8,9,"A modem is required for")
	writeToPos(8,11,"communication with the other floors")
	writeToPos(4,13,"Please attach a modem then try again")
	return -- terminate program
end

local elevatorID = getElevatorID()

local floorName = getFloorName()

local x,y,z

while true do
	x,y,z = getFloorCoords()
	if y==nil then
		writeToPos(5, 11, "Press any key to continue...")
		os.pullEvent("key")
	else
		break
	end
end
local coords = y
if x and y then
	coords = x.."\31"..y.."\31"..z
end

printSetupHeader(true)
configPath = shell.resolve(".").."/elevator.cfg"
fs.delete(configPath)
local file = io.open(configPath, "w")
file:write(modemSide.."\n")
file:write(elevatorID.."\n")
file:write(coords.."\n")
file:write(y.."\31"..floorName)
file:close()
term.write("Done")

writeToPos(5,7,"Setting elevator-main.lua to run on startup... ")

file = io.open("/startup", "w")
file:write("shell.run(\"/"..shell.resolve(".").."/elevator-main.lua\")")
file:close()
term.write("Done")

writeToPos(5, 9, "Press any key to reboot...")
os.pullEvent("key")
os.reboot()