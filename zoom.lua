--Here: Functions about the zoom system
local fa_graphics = require("graphics-and-mouse").graphics

local MIN_ZOOM = 0.275
local MAX_ZOOM = 3.282
local ZOOM_PER_TICK = 1.104086977
local ln_zoom = math.log(ZOOM_PER_TICK)

local fa_zoom = {}

function fa_zoom.get_zoom_tick(pindex)
   return math.floor(math.log(global.players[pindex].zoom)/ln_zoom + 0.5)
end

function fa_zoom.tick_to_zoom(zoom_tick)
   return ZOOM_PER_TICK ^ zoom_tick
end

function fa_zoom.fix_zoom(pindex)
   game.players[pindex].zoom = global.players[pindex].zoom
end

local function zoom_change(pindex,etick,change_by_tick)
   -- if global.players[pindex].last_zoom_event_tick == etick then
      -- print("maybe duplicate")
      -- return
   -- end
   -- global.players[pindex].last_zoom_event_tick = etick
   if game.players[pindex].render_mode == defines.render_mode.game then
      local tick = fa_zoom.get_zoom_tick(pindex)
      tick = tick + change_by_tick
      local zoom = fa_zoom.tick_to_zoom(tick)
      if zoom < MAX_ZOOM and zoom > MIN_ZOOM then
         global.players[pindex].zoom = zoom
         local stack = game.get_player(pindex).cursor_stack
         if stack and stack.valid_for_read and stack.valid and stack.prototype.place_result ~= nil then 
            fa_graphics.sync_build_cursor_graphics(pindex)
         else
            fa_graphics.draw_cursor_highlight(pindex, nil, nil)
         end
      end
   end
end

function fa_zoom.zoom_in(event)
   zoom_change(event.player_index, event.tick, 1)
end

function fa_zoom.zoom_out(event)
   zoom_change(event.player_index, event.tick, -1)
end

script.on_event("fa-zoom-in" , fa_zoom.zoom_in )
script.on_event("fa-zoom-out", fa_zoom.zoom_out)
script.on_event(defines.events.on_cutscene_waypoint_reached,function(event)
   if game.players[event.player_index].render_mode == defines.render_mode.game then
      fa_zoom.fix_zoom(event.player_index)
   end
end)
script.on_event("fa-debug-reset-zoom",function(event)
   global.players[event.player_index].zoom = 1
end)
script.on_event("fa-debug-reset-zoom-2x",function(event)
   global.players[event.player_index].zoom = 2
end)

return fa_zoom
