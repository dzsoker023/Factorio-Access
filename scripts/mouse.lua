--Here: Movement of the mouse pointer on screen
--Note: Does not include the mod cursor functions!

local fa_utils = require("scripts.fa-utils")
local dirs = defines.direction
local mod = {}

--Moves the mouse pointer to the correct pixel on the screen for an input map position. If the position is off screen, then the pointer is centered on the player character instead. Does not run in vanilla mode or if the mouse is released from synchronizing.
function mod.move_mouse_pointer(position, pindex)
   local player = players[pindex]
   local pos = position
   local screen = game.players[pindex].display_resolution
   local screen_center = fa_utils.mult_position({ x = screen.width, y = screen.height }, 0.5)
   local pixels = screen_center
   local offset = { x = 0, y = 0 }
   if players[pindex].vanilla_mode or game.get_player(pindex).game_view_settings.update_entity_selection == true then
      return
   elseif player.remote_view == true then
      --If in remote view, take the cursor position as the center point
      offset = fa_utils.mult_position(fa_utils.sub_position(pos, player.cursor_pos), 32 * player.zoom)
   elseif mod.cursor_position_is_on_screen_with_player_centered(pindex) == false then
      --If the cursor is distant, center the pointer on the player
      pos = players[pindex].position
      offset = fa_utils.mult_position(fa_utils.sub_position(pos, player.position), 32 * player.zoom)
   else
      offset = fa_utils.mult_position(fa_utils.sub_position(pos, player.position), 32 * player.zoom)
   end
   pixels = fa_utils.add_position(pixels, offset)
   mod.move_pointer_to_pixels(pixels.x, pixels.y, pindex)
   --game.get_player(pindex).print("moved to " ..  math.floor(pixels.x) .. " , " ..  math.floor(pixels.y), {volume_modifier=0})--
end

--Moves the mouse pointer to specified pixels on the screen.
function mod.move_pointer_to_pixels(x, y, pindex)
   if
      x >= 0
      and y >= 0
      and x < game.players[pindex].display_resolution.width
      and y < game.players[pindex].display_resolution.height
   then
      print("setCursor " .. pindex .. " " .. math.ceil(x) .. "," .. math.ceil(y))
   end
end

--Checks if the map position of the mod cursor falls on screen when the camera is locked on the player character.
function mod.cursor_position_is_on_screen_with_player_centered(pindex)
   local range_y = math.floor(16 / players[pindex].zoom) --found experimentally by counting tile ranges at different zoom levels
   local range_x = range_y * game.get_player(pindex).display_scale * 1.5 --found experimentally by checking scales
   return (
      math.abs(players[pindex].cursor_pos.y - players[pindex].position.y) <= range_y
      and math.abs(players[pindex].cursor_pos.x - players[pindex].position.x) <= range_x
   )
end

return mod
