class_name ScriptTemplates
extends RefCounted
## Starter scripts shown in the Studio script editor.

const HELP := "on_start(fn)  on_touch(\"name\", fn(player))  after(sec, fn)  every(sec, fn)  cancel(id)  time()  print(...)\nworld.find(\"name\"):set_color(i) / set_visible(b) / set_solid(b) / move_to(x,y,z,sec) / move_by(dx,dy,dz,sec) / position() / destroy()\nplayer:teleport(x,y,z) / kill() / give_coins(n) / set_speed(v) / set_jump(v) / message(text) / position()   player.name\nui.message(text, sec)  ui.status(text)  score.add(n) score.set(n) score.get()   Name parts with SELECT > name."

const TEMPLATES: Array = [
	["DOOR", """-- Name one part "button" and another "door" (SELECT > name).
on_touch("button", function(player)
  local door = world.find("door")
  door:set_solid(false)
  door:set_visible(false)
  ui.message(player.name .. " opened the door!", 2)
  after(5, function()
    door:set_solid(true)
    door:set_visible(true)
  end)
end)
"""],
	["VANISH", """-- Parts named "fade" disappear 1 second after you touch them.
on_touch("fade", function(player)
  local p = world.find("fade")
  after(1, function()
    p:set_visible(false)
    p:set_solid(false)
  end)
  after(4, function()
    p:set_visible(true)
    p:set_solid(true)
  end)
end)
"""],
	["SCORE", """-- Touch the part named "goal" to score and go back to the start.
on_start(function()
  ui.status("Reach the goal!")
end)

on_touch("goal", function(player)
  score.add(1)
  player:give_coins(5)
  player:message("GOAL!")
  player:teleport(0, 3, 0)
end)
"""],
	["DISCO", """-- Parts named "disco" change color every second.
local colors = {4, 5, 6, 7, 8, 9}
local i = 1
every(1, function()
  world.find("disco"):set_color(colors[i])
  i = i % #colors + 1
end)
"""],
	["BOOST", """-- Touch a part named "boost" to run faster for 4 seconds.
on_touch("boost", function(player)
  player:set_speed(16)
  player:message("SPEED BOOST!")
  after(4, function()
    player:set_speed(8.5)
  end)
end)
"""],
	["ELEVATOR", """-- A part named "lift" goes up and down when touched.
local up = false
on_touch("lift", function(player)
  local lift = world.find("lift")
  if up then
    lift:move_by(0, -8, 0, 2)
  else
    lift:move_by(0, 8, 0, 2)
  end
  up = not up
end)
"""],
]
