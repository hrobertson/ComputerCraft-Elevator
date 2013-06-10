--[[
Elevator Control Setup by Hamish Robertson
Aliases: OminousPenguin, MC username: Peren

Licence: Creative Commons Attribution-NonCommercial-ShareAlike (http://creativecommons.org/licenses/by-nc-sa/3.0/)

This is a LUA program for ComputerCraft, a Minecraft mod by Daniel Ratcliffe aka dan200 (http://www.computercraft.info/)
This program is for controlling elevators from the Railcraft mod (http://www.railcraft.info/)
For help and feedback please use this forum thread: http://www.computercraft.info/forums2/index.php?/topic/1302-railcraft-mod-elevator-control/

This program requires RedPower 2 wires (Core + Digital modules). RedPower 2 is not currently available for MC 1.5

This is version 2b. It is in the beta release stage and so there may be bugs. If you believe you have found a bug, please report it at the above forum thread.

You are permitted to modify and or build upon this work.
If you make your own version publicly available, then please also publish it at the above forum thread. Thank you and happy coding!

NOTE: This is the setup program. It will create a file called elevator.cfg and download the main program to elevator.lua

Use Ctrl+T to terminate the program
--]]

local function printSetupHeader(saving)
	term.clear()
	term.setCursorPos(2,2); term.write("====================[ Setup ]====================")
	if saving then term.setCursorPos(5,5); term.write("Saving data... "); term.setCursorBlink(true) end
end

local function getModemSide()
	-- Find all attached modems
	local sides = {"left","right","top","bottom","back","front"}
	local i = 1
	while i <= #sides do
		if peripheral.getType( sides[i] ) ~= "modem" then
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

	-- If there is mroe than one modem attached, ask user to choose one
	local selected = 1
	local function redraw()
		printSetupHeader()
		term.setCursorPos(7,9); term.write("Use the modem on the          side")
		for i=1,#sides do
			if (i == selected) then
				term.setCursorPos(29,9)
				term.write(sides[i])
			else
				if (9-selected+i)<9 then
					term.setCursorPos(29,(8-selected+i))
				else 
					term.setCursorPos(29,(10-selected+i))
				end
				term.write(sides[i])
			end
		end--for
		term.setCursorPos(4,18); term.write("[ Arrow keys to select, Enter to confirm ]")
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

local function getFloorName()
	printSetupHeader()
	term.setCursorPos(7,9); term.write("Enter a name/label for this floor: ")
	term.setCursorPos(14,11); term.setCursorBlink(true)
	local name
	repeat
		name = io.read()
	until name ~= ""
	return name
end

local function getGPS()
	printSetupHeader()
	term.setCursorPos(5,5); term.write("Waiting for GPS response... ")
	term.setCursorPos(5,7)
	local x, y, z = gps.locate(2)
	if x ~= nil then
		term.write("... coordinates received")
		term.setCursorPos(5,9)
		term.write("Start GPS host in the background?")
		local _, keycode, selected = nil, nil, 1
		term.setCursorPos(14,11)
		term.write("[ Yes ]             No")
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
		term.write("... No response")
		term.setCursorPos(5,9)
		return
	end
end--function getGPS

local function getCoordsInput()
	printSetupHeader()
	term.setCursorPos(8,7); term.write("x coordinate:")
	term.setCursorPos(8,8); term.write("y coordinate:")
	term.setCursorPos(8,9); term.write("z coordinate:")
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
				for i,input in ipairs( inputs ) do
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

end

local function getFloorCoords()
	-- We need at least the y (height) coordinate so we can know what order the floors are in
	printSetupHeader()
	term.setCursorPos(4,4); term.write("The y (height) coordinate is required so that")
	term.setCursorPos(4,5); term.write("floors can be listed in the correct order.")
	term.setCursorPos(4,7); term.write("You have a few options:")
	term.setCursorPos(6,10); term.write("1. Enter y coordinate:")
	term.setCursorPos(6,12); term.write("2. Use GPS (requires 4 GPS hosts)")
	term.setCursorPos(6,14); term.write("3. Enter x,y,z and then this computer")
	term.setCursorPos(13,15); term.write("can become a GPS host.")
	term.setCursorPos(7,16); term.write("(recommended if you have over 4 floors)")
	term.setCursorPos(2,19); term.write("(Press F3 to view player coordinates)")
	
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
					return nil, y
				elseif selected == 2 then
					return getGPS()
				elseif selected == 3 then
					return getCoordsInput() -- input all 3
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
		local x,y,z = eventHandlers:handle(os.pullEvent())
		if y then return x,y,z end
	end
end--getFloorCoords()

if not shell.run("pastebin", "get", "iJWyUQVr", "elevator-main.lua") then
	print("Failed to download main program. Try manually from pastebin: iJWyUQVr\n(this is just the setup component)")
	return
end

local side = getModemSide()
if side == nil then
	printSetupHeader()
	term.setCursorPos(15,6); term.write("! No modem detected !")
	term.setCursorPos(8,9); term.write("A modem is required for")
	term.setCursorPos(8,11); term.write("communication with the other floors")
	term.setCursorPos(4,13); term.write("Please attach a modem then try again")
	return -- terminate program
end

local floorName = getFloorName()

local x,y,z

while true do
	x,y,z = getFloorCoords()
	if (x==nil) and (y==nil) then
		term.write("Press any key to continue... ")
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
local file = io.open(shell.resolve(".").."/elevator.cfg", "w")
file:write(side.."\n")
file:write(coords.."\n")
file:write(y.."\31"..floorName)
file:close()
term.write("Done")

term.setCursorPos(5,7); term.write("Setting elevator-main.lua to run on startup... ")

file = io.open("/startup", "w")
file:write("shell.run(\"/"..shell.resolve(".").."/elevator-main.lua\")")
file:close()
term.write("Done")

term.setCursorPos(5,9);
term.write("Press any key to reboot...")
os.pullEvent("key")
os.reboot()