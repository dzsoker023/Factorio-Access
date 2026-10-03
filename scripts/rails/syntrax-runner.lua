---Syntrax runner - executes syntrax code and places rails in game
---
---Uses build-helpers to place rails as ghosts, then revives them.
---In normal mode, checks cost before placing. In force/superforce, just places ghosts.

local BuildHelpers = require("scripts.rails.build-helpers")
local InventoryUtils = require("scripts.inventory-utils")
local RailInfo = require("railutils.rail-info")
local SurfaceHelper = require("scripts.rails.surface-helper")
local Syntrax = require("syntrax")

local mod = {}

---Destroy a list of ghosts (only if valid)
---@param ghosts LuaEntity[]
local function destroy_ghosts(ghosts)
   for _, g in ipairs(ghosts) do
      if g.valid then g.destroy() end
   end
end

---@class syntrax_runner.ExecuteOptions
---@field pindex integer Player index
---@field source string Syntrax source code
---@field position MapPosition Starting position
---@field direction defines.direction Starting end direction (0-15)
---@field rail_type railutils.RailType Starting rail type
---@field placement_direction defines.direction Starting rail's placement direction
---@field layer railutils.RailLayer? Layer of the starting rail, ground if omitted
---@field start_reach number? Elevated reach left at the starting end (what supports behind it can still hold)
---@field planner_description railutils.RailPlannerDescription Rail planner for prototype names
---@field build_mode defines.build_mode Build mode for placement

local GROUND_NAME_FIELD = {
   ["straight-rail"] = "straight_rail_name",
   ["curved-rail-a"] = "curved_rail_a_name",
   ["curved-rail-b"] = "curved_rail_b_name",
   ["half-diagonal-rail"] = "half_diagonal_rail_name",
   ["rail-ramp"] = "ramp_name",
}

local ELEVATED_NAME_FIELD = {
   ["straight-rail"] = "elevated_straight_rail_name",
   ["curved-rail-a"] = "elevated_curved_rail_a_name",
   ["curved-rail-b"] = "elevated_curved_rail_b_name",
   ["half-diagonal-rail"] = "elevated_half_diagonal_rail_name",
   ["rail-ramp"] = "ramp_name",
}

---Map generic rail type and layer to actual prototype name using rail planner
---@param generic_type string Generic rail type like "straight-rail"
---@param layer railutils.RailLayer
---@param planner_description railutils.RailPlannerDescription
---@return string The actual prototype name from the player's rail planner
local function map_rail_type(generic_type, layer, planner_description)
   local fields = layer == RailInfo.RailLayer.ELEVATED and ELEVATED_NAME_FIELD or GROUND_NAME_FIELD
   local field = fields[generic_type]
   if not field then error("Unknown rail type: " .. tostring(generic_type)) end
   return planner_description[field]
end

---Convert a syntrax placement to game placement format
---@param placement syntrax.vm.Placement
---@param planner_description railutils.RailPlannerDescription
---@return {name: string, position: MapPosition, direction: defines.direction, rail_layer: string?}
local function convert_placement(placement, planner_description)
   if placement.type == "rail" then
      return {
         name = map_rail_type(placement.rail_type, placement.layer, planner_description),
         position = placement.position,
         direction = placement.placement_direction,
      }
   elseif placement.type == "signal" then
      return {
         name = placement.signal_type,
         position = placement.position,
         direction = placement.direction,
         rail_layer = placement.layer,
      }
   elseif placement.type == "support" then
      return {
         name = planner_description.support_name,
         position = placement.position,
         direction = placement.direction,
         exact = true,
      }
   else
      error("Unknown placement type: " .. tostring((placement --[[@as syntrax.vm.Placement]]).type))
   end
end

---Format an error message for a failed placement
---@param group_idx integer
---@param placement syntrax.vm.Placement
---@return string
local function format_placement_error(group_idx, placement)
   local entity_type
   if placement.type == "rail" then
      entity_type = placement.layer == RailInfo.RailLayer.ELEVATED and ("elevated " .. placement.rail_type)
         or placement.rail_type
   elseif placement.type == "support" then
      entity_type = "rail-support"
   else
      entity_type = placement.signal_type
   end
   return string.format(
      "Failed to place group %d, %s at (%d, %d)",
      group_idx,
      entity_type,
      placement.position.x,
      placement.position.y
   )
end

---Try to place an alternative (array of placements) as ghosts
---@param pindex integer
---@param surface LuaSurface
---@param alternative syntrax.vm.Placement[]
---@param planner_description railutils.RailPlannerDescription
---@param build_mode defines.build_mode
---@return LuaEntity[]|nil ghosts All ghosts (created + existing) if successful, nil if failed
---@return LuaEntity[]|nil created_ghosts Ghosts we created (for cleanup tracking)
---@return syntrax.vm.Placement|nil failed_placement The placement that failed, if any
local function try_alternative(pindex, surface, alternative, planner_description, build_mode)
   local all_ghosts = {}
   local created_ghosts = {}

   for _, syntrax_placement in ipairs(alternative) do
      local placement = convert_placement(syntrax_placement, planner_description)

      -- Check if real entity already exists - counts as success, no ghost needed. Supports must stand exactly at the
      -- rail end, one a tile off does not count.
      local existing
      if placement.exact then
         existing = BuildHelpers.find_exact_entity(surface, placement.position, placement.name, placement.direction)
      else
         existing = BuildHelpers.find_expected_entity(
            surface,
            placement.position,
            placement.name,
            placement.direction,
            placement.rail_layer
         )
      end
      if existing then goto continue end

      -- Check if ghost already exists - counts as success, but we didn't create it
      local ghost
      if placement.exact then
         ghost = BuildHelpers.find_exact_ghost(surface, placement.position, placement.name, placement.direction)
      else
         ghost = BuildHelpers.find_expected_ghost(surface, placement.position, placement.name, placement.direction)
      end
      if ghost then
         table.insert(all_ghosts, ghost)
         goto continue
      end

      -- Try to place new ghost
      local new_ghosts = BuildHelpers.place_ghosts(pindex, { placement }, build_mode)
      if not new_ghosts or #new_ghosts == 0 then
         -- Failed to place - clean up only ghosts WE created
         destroy_ghosts(created_ghosts)
         return nil, nil, syntrax_placement
      end

      local new_ghost = new_ghosts[1]
      table.insert(all_ghosts, new_ghost)
      table.insert(created_ghosts, new_ghost)

      ::continue::
   end

   return all_ghosts, created_ghosts
end

---Whether a program builds anything elevated: ramps, elevated rails or supports
---@param placement_groups syntrax.vm.PlacementGroup[]
---@return boolean
local function uses_elevated(placement_groups)
   for _, group in ipairs(placement_groups) do
      for _, alternative in ipairs(group) do
         for _, placement in ipairs(alternative) do
            if placement.type == "support" then return true end
            if placement.type == "rail" then
               if placement.rail_type == RailInfo.RailType.RAMP then return true end
               if placement.layer == RailInfo.RailLayer.ELEVATED then return true end
            end
         end
      end
   end
   return false
end

---Execute syntrax code and place rails
---@param opts syntrax_runner.ExecuteOptions
---@return LuaEntity[]|nil entities The placed rails/ghosts, or nil on failure
---@return string|nil error Error message if failed
function mod.execute(opts)
   local player = game.get_player(opts.pindex)
   if not player then return nil, "Invalid player" end

   -- Supports are planned only when the planner can build elevated rails. Without it, elevated words fail below.
   local planner = opts.planner_description
   local run_opts = { initial_layer = opts.layer }
   if SurfaceHelper.has_elevated(planner) then
      run_opts.support = {
         support_range = prototypes.entity[planner.support_name].support_range,
         ramp_range = prototypes.entity[planner.ramp_name].support_range,
         start_reach = opts.start_reach,
      }
   end

   -- Parse and execute syntrax
   local placement_groups, err =
      Syntrax.execute(opts.source, opts.position, opts.direction, opts.rail_type, opts.placement_direction, run_opts)
   if err then return nil, err.message end

   -- Handle empty result
   if not placement_groups or #placement_groups == 0 then return {}, nil end

   if uses_elevated(placement_groups) then
      if not SurfaceHelper.has_elevated(planner) then return nil, "This rail planner cannot build elevated rails" end
      if not player.force.rail_planner_allow_elevated_rails then
         return nil, "Elevated rails are not researched yet"
      end
   end

   -- Process each placement group, trying alternatives until one works
   local all_ghosts = {}
   local all_created = {} -- Track only ghosts we created, for cleanup

   for group_idx, group in ipairs(placement_groups) do
      local group_ghosts, group_created = nil, nil
      local last_failed_placement = nil

      -- Try each alternative in order
      for _, alternative in ipairs(group) do
         local failed
         group_ghosts, group_created, failed =
            try_alternative(opts.pindex, player.surface, alternative, opts.planner_description, opts.build_mode)
         if group_ghosts then break end
         if failed then last_failed_placement = failed end
      end

      if not group_ghosts then
         -- No alternative worked - clean up only what we created
         destroy_ghosts(all_created)
         if last_failed_placement then return nil, format_placement_error(group_idx, last_failed_placement) end
         return nil, string.format("Failed to place group %d", group_idx)
      end

      for _, g in ipairs(group_ghosts) do
         table.insert(all_ghosts, g)
      end
      for _, g in ipairs(group_created) do
         table.insert(all_created, g)
      end
   end

   -- All groups placed successfully as ghosts
   -- Now handle costs and revival

   if opts.build_mode == defines.build_mode.normal then
      -- Check cost for all placed ghosts
      local proto_names = {}
      for _, ghost in ipairs(all_ghosts) do
         if ghost.valid then table.insert(proto_names, ghost.ghost_name) end
      end

      local deductor = InventoryUtils.deductor_for_placements(opts.pindex, proto_names, false)
      if not deductor then
         destroy_ghosts(all_created)
         return nil, "Insufficient items"
      end

      -- Elevated rails revive only once something holds them, which can take several passes
      local entities, leftovers = BuildHelpers.revive_ghosts_until_stable(all_ghosts)
      if #leftovers == 0 then
         deductor:commit()
         return entities, nil
      end

      -- Something did not get held. What was built is held, so keep it and pay only for that; remove the ghosts this
      -- run made that could not be built, and say so.
      local created = {}
      for _, g in ipairs(all_created) do
         if g.valid then created[g.unit_number] = true end
      end
      local removed = 0
      for _, g in ipairs(leftovers) do
         if created[g.unit_number] then
            g.destroy()
            removed = removed + 1
         end
      end
      local built_names = {}
      for _, e in ipairs(entities) do
         table.insert(built_names, e.name)
      end
      local built_deductor = InventoryUtils.deductor_for_placements(opts.pindex, built_names, true)
      if built_deductor then built_deductor:commit() end
      return entities,
         string.format(
            "built %d, but %d could not be built because nothing holds them up, so those were removed",
            #entities,
            removed
         )
   end

   -- Force/superforce mode - just return ghosts
   return all_ghosts, nil
end

return mod
