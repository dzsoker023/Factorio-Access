--Here: Movement of the mouse pointer on screen
--Note: Does not include the mod cursor functions!

local fa_utils = require("scripts.fa-utils")
local dirs = defines.direction
local mod = {}

--Moves the mouse pointer to the correct pixel on the screen for an input map position. If the position is off screen, then the pointer is centered on the player character instead. Does not run in vanilla mode or if the mouse is released from synchronizing. 
function mod.move_mouse_pointer(position,pindex)
   local pos = position
   if players[pindex].vanilla_mode or game.get_player(pindex).game_view_settings.update_entity_selection == true then
      return
   elseif players[pindex].cursor and cursor_position_is_on_screen_with_player_centered(pindex) == false then
      pos = players[pindex].position
      --move_mouse_pointer_map_mode(position,pindex)
      --return
   end
   local player = players[pindex]
   local pixels = fa_utils.mult_position( fa_utils.sub_position(pos, player.position), 32*player.zoom)
   local screen = game.players[pindex].display_resolution
   local screen_c = {x = screen.width, y = screen.height}
   pixels = fa_utils.add_position(pixels,fa_utils.mult_position(screen_c,0.5))
   mod.move_pointer_to_pixels(pixels.x, pixels.y, pindex)
   --game.get_player(pindex).print("moved to " ..  math.floor(pixels.x) .. " , " ..  math.floor(pixels.y), {volume_modifier=0})--
end

--Moves the mouse pointer to specified pixels on the screen.
function mod.move_pointer_to_pixels(x,y, pindex)
   if x >= 0 and y >=0 and x < game.players[pindex].display_resolution.width and y < game.players[pindex].display_resolution.height then
      print ("setCursor " .. pindex .. " " .. math.ceil(x) .. "," .. math.ceil(y))
   end
end

return mod
