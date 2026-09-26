-- LÖVE for PS4 test app.
--
-- Checks the things that broke while bringing LÖVE up on PS4 (presenting from love.load,
-- rendering through a Canvas, a steady frame rate) and shows the live state of every connected
-- controller. Every step is also printed, so it shows up in klog and /data/love/log.txt.
--
-- Run it by installing the test pkg, or by copying ps4-test.love to /data/love/game.love and
-- starting the plain LÖVE app. Hold Options on any controller for two seconds to quit.

local t0 = love.timer.getTime()
local function log(...)
	print(string.format("[ps4test %.2f]", love.timer.getTime() - t0), ...)
end

local results = {}
local canvas
local frame = 0
local quitheld = 0
local font

local function check(name, fn)
	log(name .. "...")
	local ok, err = pcall(fn)
	table.insert(results, {name = name, ok = ok, err = err})
	log(name .. (ok and ": ok" or (": FAILED: " .. tostring(err))))
end

function love.load()
	font = love.graphics.newFont(28)
	love.graphics.setFont(font)
	log("screen", love.graphics.getDimensions(), "os", love.system.getOS())

	check("present from love.load", function()
		love.graphics.clear(0.3, 0, 0)
		love.graphics.rectangle("fill", 100, 100, 200, 200)
		love.graphics.present()
	end)

	check("create a canvas", function()
		canvas = love.graphics.newCanvas(1600, 896)
	end)

	check("present after drawing through a canvas", function()
		love.graphics.setCanvas(canvas)
		love.graphics.clear(0, 0.3, 0)
		love.graphics.rectangle("fill", 50, 50, 100, 100)
		love.graphics.setCanvas()
		love.graphics.clear(0, 0, 0)
		love.graphics.draw(canvas, 160, 92)
		love.graphics.present()
	end)
end

function love.joystickadded(joystick)
	log("controller added:", joystick:getID(), joystick:getName(), "gamepad:", joystick:isGamepad())
end

function love.joystickremoved(joystick)
	log("controller removed:", joystick:getID())
end

function love.gamepadpressed(joystick, button)
	log("pad " .. joystick:getID() .. " pressed " .. button)
end

function love.update(dt)
	frame = frame + 1
	if frame % 300 == 0 then
		log("frame", frame, "fps", love.timer.getFPS())
	end

	local held = false
	for _, j in ipairs(love.joystick.getJoysticks()) do
		if j:isGamepad() and j:isGamepadDown("start") then
			held = true
		end
	end
	quitheld = held and quitheld + dt or 0
	if quitheld > 2 then
		log("quit")
		love.event.quit()
	end
end

local buttons = {"a", "b", "x", "y", "leftshoulder", "rightshoulder", "leftstick", "rightstick",
	"dpup", "dpdown", "dpleft", "dpright", "start", "back"}
local names = {a = "X", b = "O", x = "[]", y = "/\\", leftshoulder = "L1", rightshoulder = "R1",
	leftstick = "L3", rightstick = "R3", dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
	start = "OPTIONS", back = "TOUCHPAD"}

function love.draw()
	-- Everything goes through the canvas, like games that scale a fixed-size picture.
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0.35)
	love.graphics.rectangle("fill", (frame * 4) % 1500, 700, 100, 100)
	love.graphics.setCanvas()
	love.graphics.draw(canvas, 160, 92)

	local y = 110
	love.graphics.print(string.format("LOVE %s on %s   %dx%d   %d fps", love.getVersion and table.concat({love.getVersion()}, ".", 1, 3) or "?",
		love.system.getOS(), love.graphics.getWidth(), love.graphics.getHeight(), love.timer.getFPS()), 200, y)
	y = y + 50
	for _, r in ipairs(results) do
		love.graphics.setColor(r.ok and {0.5, 1, 0.5} or {1, 0.4, 0.4})
		love.graphics.print((r.ok and "OK   " or "FAIL ") .. r.name, 200, y)
		y = y + 36
	end
	love.graphics.setColor(1, 1, 1)

	y = y + 20
	local joysticks = love.joystick.getJoysticks()
	love.graphics.print(#joysticks .. " controller(s)", 200, y)
	y = y + 40
	for i, j in ipairs(joysticks) do
		local line = string.format("%d: ", i)
		if j:isGamepad() then
			line = line .. string.format("L %+.2f %+.2f  R %+.2f %+.2f  L2 %.2f  R2 %.2f  ",
				j:getGamepadAxis("leftx"), j:getGamepadAxis("lefty"),
				j:getGamepadAxis("rightx"), j:getGamepadAxis("righty"),
				j:getGamepadAxis("triggerleft"), j:getGamepadAxis("triggerright"))
			for _, b in ipairs(buttons) do
				if j:isGamepadDown(b) then
					line = line .. names[b] .. " "
				end
			end
		else
			line = line .. j:getName() .. " (not a gamepad)"
		end
		love.graphics.print(line, 200, y)
		y = y + 36
	end

	love.graphics.print("Hold OPTIONS for 2 seconds to quit", 200, 900)
end
