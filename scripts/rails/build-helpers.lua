---Build helpers for ghost-based entity placement
---Used by virtual-train-driving and syntrax-runner

local StorageManager = require("scripts.storage-manager")
local BlueprintSynthesizer = require("scripts.blueprint-synthesizer")
local HandMonitor = require("scripts.hand-monitor")

local mod = {}

---@class build_helpers.Inventories
---@field tmp_inv LuaInventory? Temporary inventory for hand swapping

---Initialize inventories for a player
---@return build_helpers.Inventories
local function init_inventories()
   return {}
end

-- IMPORTANT: changing the name of this or bumping the ephemeral version will leak inventories. That is fine as long as
-- it is only ever done occasionally, but if we need to do so more often then that is bad.  If this is moved to another
-- file, it must keep the name.
---@type table<number, build_helpers.Inventories>
local build_inventories = StorageManager.declare_storage_module("train_building_invs", init_inventories)

---Get or create a temporary inventory for storing the player's hand during builds
---@param pindex integer
---@return LuaInventory
function mod.get_or_create_tmp_inventory(pindex)
   local invs = build_inventories[pindex]

   -- Check if we have a valid inventory
   if invs.tmp_inv and invs.tmp_inv.valid then return invs.tmp_inv end

   -- Create a new inventory with 1 slot
   invs.tmp_inv = game.create_inventory(1)
   return invs.tmp_inv
end

---Find a ghost entity at a position matching the expected name and direction
---@param surface LuaSurface
---@param position MapPosition
---@param entity_name string
---@param direction defines.direction
---@return LuaEntity|nil
function mod.find_expected_ghost(surface, position, entity_name, direction)
   local ghosts = surface.find_entities_filtered({
      position = position,
      radius = 1,
      name = "entity-ghost",
      ghost_name = entity_name,
   })

   for _, ghost in ipairs(ghosts) do
      if ghost.direction == direction then return ghost end
   end

   return nil
end

local SIGNAL_TYPES = { ["rail-signal"] = true, ["rail-chain-signal"] = true }

---Find a real entity at a position matching the expected name and direction
---@param surface LuaSurface
---@param position MapPosition
---@param entity_name string
---@param direction defines.direction
---@param rail_layer ("ground"|"elevated")? For signals: the layer they must guard. A signal under a bridge is not the
---one on top of it.
---@return LuaEntity|nil
function mod.find_expected_entity(surface, position, entity_name, direction, rail_layer)
   local entities = surface.find_entities_filtered({
      position = position,
      radius = 1,
      name = entity_name,
   })

   for _, entity in ipairs(entities) do
      if entity.direction == direction then
         if not rail_layer or not SIGNAL_TYPES[entity.type] then return entity end
         if entity.rail_layer == defines.rail_layer[rail_layer] then return entity end
      end
   end

   return nil
end

---Blueprint fields that put a signal on the given layer. Signals default to the ground layer.
---@param rail_layer ("ground"|"elevated")?
---@return table?
local function layer_fields(rail_layer)
   if rail_layer == "elevated" then return { rail_layer = "elevated" } end
   return nil
end

---Place a single entity as a ghost using build_from_cursor
---Does NOT check costs, does NOT revive, does NOT play sounds
---@param pindex integer
---@param entity_name string
---@param position MapPosition
---@param direction defines.direction
---@param build_mode defines.build_mode
---@param rail_layer ("ground"|"elevated")? Layer for signals
---@return LuaEntity|nil ghost The placed ghost, or nil if failed
function mod.place_ghost(pindex, entity_name, position, direction, build_mode, rail_layer)
   local player = game.get_player(pindex)
   if not player then return nil end

   local surface = player.surface

   -- Check if entity already exists at this position
   local existing = mod.find_expected_entity(surface, position, entity_name, direction, rail_layer)
   if existing then
      -- Already exists - return nil but this is not a failure
      -- Caller should check for existing entities separately if needed
      return nil
   end

   -- Check if ghost already exists
   local existing_ghost = mod.find_expected_ghost(surface, position, entity_name, direction)
   if existing_ghost then return existing_ghost end

   -- Suppress hand change events for this tick
   HandMonitor.suppress_this_tick(pindex)

   -- Get temporary inventory and swap hand into it
   local tmp_inv = mod.get_or_create_tmp_inventory(pindex)
   local cursor = player.cursor_stack

   -- Swap player's hand to temp inventory
   local swap_success = cursor.swap_stack(tmp_inv[1])
   if not swap_success then return nil end

   -- Create blueprint in cursor
   cursor.set_stack({ name = "blueprint" })
   local bp_string =
      BlueprintSynthesizer.synthesize_simple_blueprint(entity_name, direction, nil, layer_fields(rail_layer))
   local import_result = cursor.import_stack(bp_string)
   if import_result ~= 0 then
      -- Import failed, restore hand
      cursor.swap_stack(tmp_inv[1])
      return nil
   end

   -- Try to build from cursor with specified build mode
   local can_build = player.can_build_from_cursor({
      position = position,
      build_mode = build_mode,
   })

   if can_build then player.build_from_cursor({
      position = position,
      build_mode = build_mode,
   }) end

   -- Clear blueprint and restore hand
   cursor.clear()
   cursor.swap_stack(tmp_inv[1])

   -- Check if ghost was placed
   local ghost = mod.find_expected_ghost(surface, position, entity_name, direction)
   return ghost
end

---Whether an entity sits exactly at a position
---@param entity LuaEntity
---@param position MapPosition
---@return boolean
local function is_at(entity, position)
   return entity.position.x == position.x and entity.position.y == position.y
end

---Find a ghost exactly at a position
---@param surface LuaSurface
---@param position MapPosition
---@param entity_name string
---@param direction defines.direction
---@return LuaEntity|nil
function mod.find_exact_ghost(surface, position, entity_name, direction)
   for _, ghost in ipairs(surface.find_entities_filtered({
      position = position,
      radius = 0.5,
      name = "entity-ghost",
      ghost_name = entity_name,
   })) do
      if ghost.direction == direction and is_at(ghost, position) then return ghost end
   end
   return nil
end

---Place a ghost at exactly the given position, without a blueprint. For rail supports: a blueprint snaps a lone
---support to its 2x2 grid, which puts it a tile off the rail end, and a support off the rail end holds nothing.
---Does NOT check costs, does NOT revive.
---@param pindex integer
---@param entity_name string
---@param position MapPosition
---@param direction defines.direction
---@return LuaEntity|nil ghost The placed or already existing ghost, or nil if it cannot go there
function mod.place_ghost_exact(pindex, entity_name, position, direction)
   local player = game.get_player(pindex)
   if not player then return nil end
   local surface = player.surface

   local existing = mod.find_exact_ghost(surface, position, entity_name, direction)
   if existing then return existing end

   local can = surface.can_place_entity({
      name = "entity-ghost",
      inner_name = entity_name,
      position = position,
      direction = direction,
      force = player.force,
      build_check_type = defines.build_check_type.manual_ghost,
   })
   if not can then return nil end

   local ghost = surface.create_entity({
      name = "entity-ghost",
      inner_name = entity_name,
      position = position,
      direction = direction,
      force = player.force,
      player = player,
   })
   if ghost and not is_at(ghost, position) then
      -- Snapped anyway: try once more without snapping
      ghost.destroy()
      ghost = surface.create_entity({
         name = "entity-ghost",
         inner_name = entity_name,
         position = position,
         direction = direction,
         force = player.force,
         player = player,
         snap_to_grid = false,
      })
   end
   if ghost and not is_at(ghost, position) then
      ghost.destroy()
      return nil
   end
   return ghost
end

---Find a built entity exactly at a position
---@param surface LuaSurface
---@param position MapPosition
---@param entity_name string
---@param direction defines.direction
---@return LuaEntity|nil
local function find_exact_entity(surface, position, entity_name, direction)
   for _, entity in ipairs(surface.find_entities_filtered({ position = position, radius = 0.5, name = entity_name })) do
      if entity.direction == direction and is_at(entity, position) then return entity end
   end
   return nil
end
mod.find_exact_entity = find_exact_entity

---@class fa.rails.GhostPlacement
---@field name string
---@field position MapPosition
---@field direction defines.direction
---@field rail_layer string? Layer for signals
---@field exact boolean? Place at exactly this position, not through a blueprint (rail supports)

---Place multiple entities as ghosts
---If any placement fails, destroys all previously placed ghosts and returns nil
---@param pindex integer
---@param placements fa.rails.GhostPlacement[]
---@param build_mode defines.build_mode
---@return LuaEntity[]|nil ghosts All placed ghosts, or nil if any failed
function mod.place_ghosts(pindex, placements, build_mode)
   local player = game.get_player(pindex)
   if not player then return nil end

   local surface = player.surface
   local ghosts = {}

   for _, placement in ipairs(placements) do
      -- Exact placements (rail supports) do not go through a blueprint
      if placement.exact then
         if find_exact_entity(surface, placement.position, placement.name, placement.direction) then goto continue end
         local exact_ghost = mod.place_ghost_exact(pindex, placement.name, placement.position, placement.direction)
         if not exact_ghost then
            for _, g in ipairs(ghosts) do
               if g.valid then g.destroy() end
            end
            return nil
         end
         table.insert(ghosts, exact_ghost)
         goto continue
      end

      -- Check if real entity already exists (skip, don't fail)
      local existing = mod.find_expected_entity(
         surface,
         placement.position,
         placement.name,
         placement.direction,
         placement.rail_layer
      )
      if existing then
         -- Already built, skip this one
         goto continue
      end

      -- Check if ghost already exists
      local existing_ghost = mod.find_expected_ghost(surface, placement.position, placement.name, placement.direction)
      if existing_ghost then
         table.insert(ghosts, existing_ghost)
         goto continue
      end

      -- Place ghost
      local ghost = mod.place_ghost(
         pindex,
         placement.name,
         placement.position,
         placement.direction,
         build_mode,
         placement.rail_layer
      )
      if not ghost then
         -- Failed - destroy all placed ghosts
         for _, g in ipairs(ghosts) do
            if g.valid then g.destroy() end
         end
         return nil
      end
      table.insert(ghosts, ghost)

      ::continue::
   end

   return ghosts
end

---Revive all ghosts, returning the created entities
---@param ghosts LuaEntity[]
---@return LuaEntity[] entities The revived entities
function mod.revive_ghosts(ghosts)
   local entities = {}
   for _, ghost in ipairs(ghosts) do
      if ghost.valid then
         local _, entity = ghost.silent_revive()
         if entity then table.insert(entities, entity) end
      end
   end
   return entities
end

---Revive ghosts in passes until a pass revives nothing. Elevated rails only revive once a support or ramp holds them
---through built track, so one pass in placement order is not enough: a support ahead of a stretch builds the rails
---behind it pass by pass.
---@param ghosts LuaEntity[]
---@return LuaEntity[] entities The revived entities
---@return LuaEntity[] leftovers Ghosts that never revived
function mod.revive_ghosts_until_stable(ghosts)
   local entities = {}
   local pending = ghosts
   while true do
      local still_pending = {}
      local revived_any = false
      for _, ghost in ipairs(pending) do
         if ghost.valid then
            local _, entity = ghost.silent_revive()
            if entity then
               table.insert(entities, entity)
               revived_any = true
            else
               table.insert(still_pending, ghost)
            end
         end
      end
      pending = still_pending
      if not revived_any or #pending == 0 then break end
   end
   return entities, pending
end

return mod
