--Here: Kruise Kontrol wrapper methods so that FA can run it and independently assume its states
local fa_utils = require("scripts.fa-utils")
local fa_mouse = require("scripts.mouse")

local mod = {}

--FA actions to take when KK activate input is pressed
function mod.activated_kk(pindex, event)
   local p = game.get_player(pindex)
   if players[pindex].remote_view == true or fa_mouse.cursor_position_is_on_screen_with_player_centered(pindex) then
      --Allow KK
      players[pindex].kruise_kontrolling = true
      p.character_running_speed_modifier = 0
      local kk_pos = players[pindex].cursor_pos
      --Save what the player targetted
      players[pindex].kk_pos = kk_pos
      local kk_targets = p.surface.find_entities_filtered({ position = kk_pos, name = "highlight-box", invert = true })
      if kk_targets and #kk_targets > 0 then
         players[pindex].kk_target = kk_targets[1]
      else
         players[pindex].kk_target = nil
      end
      --Close remote view
      toggle_remote_view(pindex, false, true)
      close_menu_resets(pindex)

      --Determine and report the KK status
      players[pindex].kk_status = mod.status_determine(pindex)
      mod.status_read(pindex, true)
      players[pindex].kk_start_tick = event.tick
   else
      players[pindex].kruise_kontrolling = false
      fix_walk(pindex)
      toggle_remote_view(pindex, true, false)
      sync_remote_view(pindex)
      printout("Opened in remote view, press again to confirm", pindex)
   end
end

--FA actions to take when KK cancel input is pressed
function mod.cancelled_kk(pindex)
   if players[pindex].kruise_kontrolling == true then
      players[pindex].kruise_kontrolling = false
      fix_walk(pindex)
      toggle_remote_view(pindex, false, true)
      close_menu_resets(pindex)
      printout("Cancelled kruise kontrol action.", pindex)
   end
end

--Determines the assumed status of kruise kontrol. Mimics the checks from the mod itself in Character:determine_job(entity, position)
function mod.status_determine(pindex)
   local p = game.get_player(pindex)
   local entity = players[pindex].kk_target
   local position = players[pindex].kk_pos
   local status = ""
   players[pindex].kk_radius = -1

   if not (entity and entity.valid) then
      if p.vehicle then
         status = "driving"
      else
         status = "walking"
      end
      return status
   end

   local force = entity.force

   if force == p.force then
      if entity.type == "entity-ghost" then
         status = "building ghosts"
         return status
      end

      if entity.type == "tile-ghost" then
         status = "building ghosts"
         return status
      end

      if entity.to_be_deconstructed() then
         status = "deconstructing"
         return status
      end

      if entity.get_health_ratio() and entity.get_health_ratio() < 1 then
         status = "repairing"
         players[pindex].kk_radius = 50
         return status
      end

      if entity.to_be_upgraded() then
         status = "upgrading"
         return status
      end

      local fuel_inventory = entity.get_fuel_inventory()
      if fuel_inventory and fuel_inventory.is_empty() then
         status = "refueling"
         players[pindex].kk_radius = 50
         return status
      end
   end

   if entity.to_be_deconstructed() and (force.name == "neutral") then
      status = "deconstructing"
      return status
   end

   if entity.type == "resource" then
      status = "mining resources"
      return status
   end

   if entity.type == "tree" then
      status = "mining resources"
      return status
   end

   if entity.type == "simple-entity" and force.name == "neutral" then
      status = "mining resources"
      return status
   end

   if p.force.get_cease_fire(entity.force) == false then
      status = "attacking"
      players[pindex].kk_radius = 64
      return status
   end

   if entity.train ~= nil or entity.type == "car" then
      status = "following"
      return status
   end

   --Unknown case:
   return "walking"
end

--Updates the assumed status of Kruise Kontrol based on specific checks per status
function mod.status_update(pindex)
   --Return if not KK or KK was activated recently
   if players[pindex].kruise_kontrolling == false then return end
   if players[pindex].kk_start_tick == nil or game.tick - players[pindex].kk_start_tick < 65 then return end
   local p = game.get_player(pindex)
   local status = players[pindex].kk_status

   if status == "walking" then
      --Check that the player is not moving and not mining
      if fa_utils.player_was_still_for_1_second(pindex) and p.mining_state.mining == false then
         status = mod.apply_arrived(pindex)
      end
   elseif status == "driving" then
      --Check that the player vehicle is not moving
      if p.vehicle and p.vehicle.speed == 0 then status = mod.apply_arrived(pindex) end
   elseif status == "building ghosts" then
      --Check if no more ghosts around, or the existing ghosts do not have items in inventory
      local ghosts = p.surface.find_entities_filtered({ position = p.position, radius = 100, type = "entity-ghost" })
      if ghosts == nil or #ghosts == 0 then
         status = mod.apply_finished(pindex)
      else
         --Check which ghosts to ignore
         local ghost_count = #ghosts
         local ignore_count = 0
         for i, ghost in ipairs(ghosts) do
            if p.get_main_inventory().get_item_count(ghost.ghost_name) == 0 then
               ignore_count = ignore_count + 1
            else
               --Still going to build it
               return
            end
         end
         if ghost_count == ignore_count then
            --Ignore all remaining ghosts
            status = mod.apply_finished(pindex)
         end
      end
   elseif status == "deconstructing" then
      --Check if no more deconstructables around
      --Note: there are other end states such as inventory being full
      local targets =
         p.surface.find_entities_filtered({ position = p.position, radius = 100, to_be_deconstructed = true })
      if targets == nil or #targets == 0 then status = mod.apply_finished(pindex) end
   elseif status == "upgrading" then
      --Check if no more upgradables around
      --Note: there are other end states such as not having the missing items
      local targets = p.surface.find_entities_filtered({ position = p.position, radius = 100, to_be_upgraded = true })
      if targets == nil or #targets == 0 then status = mod.apply_finished(pindex) end
   end

   players[pindex].kk_status = status
   --Printout the status change if it is an end state
   if status == "arrived" or status == "finished" then mod.status_read(pindex, true) end
end

function mod.apply_finished(pindex)
   players[pindex].kk_status = "finished"
   players[pindex].kruise_kontrolling = false
   fix_walk(pindex)
   toggle_remote_view(pindex, false, true)
   return "finished"
end

function mod.apply_arrived(pindex)
   players[pindex].kk_status = "arrived"
   players[pindex].kruise_kontrolling = false
   fix_walk(pindex)
   toggle_remote_view(pindex, false, true)
   return "arrived"
end

--Reads out the assumed Kruise Kontrol status
function mod.status_read(pindex, short_version)
   local p = game.get_player(pindex)
   local status = players[pindex].kk_status
   local target = players[pindex].kk_target
   local target_pos = players[pindex].kk_pos
   local result = "Kruise Kontrol " .. status
   if short_version == true then
      printout(result, pindex)
      return
   end
   local target_dist = math.floor(util.distance(p.position, target_pos))
   local dist_info = ", " .. target_dist .. " tiles to target"
   if target_dist < 3 then dist_info = "" end
   if status == "walking" or status == "driving" then result = result .. dist_info end
   result = result .. ", press ENTER to cancel"
   printout(result, pindex)
end

return mod
