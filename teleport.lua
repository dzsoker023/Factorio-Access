--Here: teleporting
local fa_utils = require("fa-utils")
local fa_graphics = require("graphics-and-mouse").graphics
local fa_mouse = require("graphics-and-mouse").mouse

local mod = {}

--Teleports the player character to the cursor position.
function mod.teleport_to_cursor(pindex, muted, ignore_enemies, return_cursor)
   local result = mod.teleport_to_closest(pindex, players[pindex].cursor_pos, muted, ignore_enemies)
   if return_cursor then
      players[pindex].cursor_pos = players[pindex].position
   end
   return result
end

--Makes the player teleport to the closest valid position to a target position. Uses game's teleport function. Muted makes silent and effectless teleporting
function mod.teleport_to_closest(pindex, pos, muted, ignore_enemies)
   local pos = table.deepcopy(pos)
   local muted = muted or false
   local first_player = game.get_player(pindex)
   local surf = first_player.surface
   local radius = .5
   local new_pos = surf.find_non_colliding_position("character", pos, radius, .1, true)
   while new_pos == nil do
      radius = radius + 1
      new_pos = surf.find_non_colliding_position("character", pos, radius, .1, true)
   end
   --Do not teleport if in a vehicle, in a menu, or already at the desitination
   if first_player.vehicle ~= nil and first_player.vehicle.valid then
      printout("Cannot teleport while in a vehicle.", pindex)
      return false
   elseif util.distance(game.get_player(pindex).position, pos) <= 1.5 then
      printout("Already at target", pindex)
      return false
   elseif players[pindex].in_menu and players[pindex].menu ~= "travel" and players[pindex].menu ~= "structure-travel" then
      printout("Cannot teleport while in a menu.", pindex)
      return false
   end
   --Do not teleport near enemies unless instructed to ignore them
   if not ignore_enemies then
      local enemy = first_player.surface.find_nearest_enemy{position = new_pos, max_distance = 30, force =  first_player.force}
      if enemy and enemy.valid then
         printout("Warning: There are enemies at this location, but you can force teleporting if you press CONTROL + SHIFT + T", pindex)
         return false
      end
   end
   --Attempt teleport
   local can_port = first_player.surface.can_place_entity{name = "character", position = new_pos}
   if can_port then
      local old_pos = table.deepcopy(first_player.position)
      if not muted then
         --Teleporting visuals at origin
         rendering.draw_circle{color = {0.8, 0.2, 0.0},radius = 0.5,width = 15,target = old_pos, surface = first_player.surface, draw_on_ground = true, time_to_live = 60}
         rendering.draw_circle{color = {0.6, 0.1, 0.1},radius = 0.3,width = 20,target = old_pos, surface = first_player.surface, draw_on_ground = true, time_to_live = 60}
         local smoke_effect = first_player.surface.create_entity{name = "iron-chest", position = first_player.position, raise_built = false, force = first_player.force}
         smoke_effect.destroy{}
         --Teleport sound at origin
         game.get_player(pindex).play_sound{path = "player-teleported", volume_modifier = 0.2, position = old_pos}
         game.get_player(pindex).play_sound{path = "utility/scenario_message", volume_modifier = 0.8, position = old_pos}
      end
      local teleported = false
      if muted then
         teleported = first_player.teleport(new_pos)
      else
         teleported = first_player.teleport(new_pos)
      end
      if teleported then
         first_player.force.chart(first_player.surface, {{new_pos.x-15,new_pos.y-15},{new_pos.x+15,new_pos.y+15}})
         players[pindex].position = table.deepcopy(new_pos)
         reset_bump_stats(pindex)
         if not muted then
            --Teleporting visuals at target
            rendering.draw_circle{color = {0.3, 0.3, 0.9},radius = 0.5,width = 15,target = new_pos, surface = first_player.surface, draw_on_ground = true, time_to_live = 60}
            rendering.draw_circle{color = {0.0, 0.0, 0.9},radius = 0.3,width = 20,target = new_pos, surface = first_player.surface, draw_on_ground = true, time_to_live = 60}
            local smoke_effect = first_player.surface.create_entity{name = "iron-chest", position = first_player.position, raise_built = false, force = first_player.force}
            smoke_effect.destroy{}
            --Teleport sound at target
            game.get_player(pindex).play_sound{path = "player-teleported", volume_modifier = 0.2, position = new_pos}
            game.get_player(pindex).play_sound{path = "utility/scenario_message", volume_modifier = 0.8, position = new_pos}
         end
         if new_pos.x ~= pos.x or new_pos.y ~= pos.y then
            if not muted then
               printout("Teleported " .. math.ceil(fa_utils.distance(pos,first_player.position)) .. " " .. fa_utils.direction(pos, first_player.position) .. " of target", pindex)
            end
         end
         --Update cursor after teleport
         players[pindex].cursor_pos = table.deepcopy(new_pos)
         fa_mouse.move_mouse_pointer(fa_utils.center_of_tile(players[pindex].cursor_pos),pindex)
         fa_graphics.draw_cursor_highlight(pindex,nil,nil)
      else
         printout("Teleport Failed", pindex)
         return false
      end
   else
      printout("Cannot teleport", pindex)--this is unlikely to be reached because we find the first non-colliding position
      return false
   end

   -- --Adjust camera
   -- game.get_player(pindex).close_map()

   return true
end

return mod