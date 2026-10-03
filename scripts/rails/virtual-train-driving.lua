---Virtual Train Driving
---
---Turtle graphics-style rail building where player "drives" a virtual train that lays tracks

local Consts = require("scripts.consts")
local StorageManager = require("scripts.storage-manager")
local Speech = require("scripts.speech")
local Sounds = require("scripts.ui.sounds")
local Viewpoint = require("scripts.viewpoint")
local Traverser = require("railutils.traverser")
local Queries = require("railutils.queries")
local FaUtils = require("scripts.fa-utils")
local BlueprintSynthesizer = require("scripts.blueprint-synthesizer")
local HandMonitor = require("scripts.hand-monitor")
local InventoryUtils = require("scripts.inventory-utils")
local UiRouter = require("scripts.ui.router")
local SurfaceHelper = require("scripts.rails.surface-helper")
local SyntraxRunner = require("scripts.rails.syntrax-runner")
local BuildHelpers = require("scripts.rails.build-helpers")
local ElevatedReach = require("scripts.rails.elevated-reach")
local RailInfo = require("railutils.rail-info")
local SupportPlanner = require("railutils.support-planner")
local SettingDecls = require("scripts.settings-decls")

local MessageBuilder = Speech.MessageBuilder

---Get effective rail name from entity (handles ghosts)
---@param ent LuaEntity
---@return string The rail prototype name
local function get_effective_name(ent)
   if ent.type == "entity-ghost" then return ent.ghost_name end
   return ent.name
end

---Check if an entity is a rail (real or ghost), on either layer or a ramp
---@param ent LuaEntity?
---@return boolean
local function is_rail_entity(ent)
   if not ent or not ent.valid then return false end
   if Consts.ALL_RAIL_TYPES_SET[ent.type] then return true end
   if ent.type == "entity-ghost" and Consts.ALL_RAIL_TYPES_SET[ent.ghost_type] then return true end
   return false
end

local mod = {}

mod.is_rail_entity = is_rail_entity

---Check if an entity is a built rail (not a ghost), on either layer or a ramp
---@param ent LuaEntity?
---@return boolean
function mod.is_real_rail(ent)
   return ent ~= nil and ent.valid and Consts.ALL_RAIL_TYPES_SET[ent.type] == true
end

local EPSILON = 1e-6

---@class vtd.Inventories
---@field tmp_inv LuaInventory? Temporary inventory for hand swapping

---Initialize inventories for a player
---@return vtd.Inventories
local function init_inventories()
   return {}
end

local vtd_inventories = StorageManager.declare_storage_module("virtual_train_invs", init_inventories)

---@class vtd.Move
---@field position MapPosition Position of the rail piece
---@field end_direction defines.direction Direction of the rail end we're facing
---@field rail_type railutils.RailType Type of rail (STRAIGHT, HALF_DIAGONAL, CURVE_A, CURVE_B)
---@field placement_direction defines.direction Direction the rail was placed
---@field entities LuaEntity[] Entities placed with this move (support, rail, signals, etc), removed last to first
---@field is_bookmark boolean Whether this move is a bookmark
---@field layer railutils.RailLayer? Layer of the end we're facing (nil in moves saved before elevated rails: ground)
---@field reach number? On elevated track: how much more track the supports and ramps behind can hold from this end

---@alias vtd.MoveKind "forward"|"left"|"right"|"change_layer"

---@class vtd.SupportSpot
---@field position MapPosition Rail end the support stands at
---@field direction defines.direction
---@field at_far_end boolean At the far end of the new rail (true) or at the end we are on (false)

---@class vtd.PendingSupport: vtd.SupportSpot
---@field kind vtd.MoveKind The move that needs it, retried when the support is accepted

---@class vtd.State
---@field locked boolean Whether the player is locked to rails
---@field moves vtd.Move[] Stack of moves representing the path
---@field speculating boolean Whether we're in speculative mode
---@field build_mode defines.build_mode Build mode for placing entities
---@field planner_description railutils.RailPlannerDescription? Rail planner captured at lock time
---@field pending_support vtd.PendingSupport? Support suggested for the last move, placed with control+comma

---Initialize state for a player
---@return vtd.State
local function init_state()
   return {
      locked = false,
      moves = {},
      speculating = false,
      build_mode = defines.build_mode.normal,
      planner_description = nil,
      pending_support = nil,
   }
end

local vtd_storage = StorageManager.declare_storage_module("virtual_train_driving", init_state)

---Check if player has a rail planner in hand
---@param player LuaPlayer
---@return boolean
local function has_rail_planner(player)
   if not player.cursor_stack or not player.cursor_stack.valid_for_read then return false end
   local prototype = player.cursor_stack.prototype
   return prototype.rails ~= nil
end

---Get or create a temporary inventory for storing the player's hand during builds
---@param pindex integer
---@return LuaInventory
local function get_or_create_tmp_inventory(pindex)
   local invs = vtd_inventories[pindex]

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
local function find_expected_ghost(surface, position, entity_name, direction)
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

---Build an entity using build_from_cursor with proper hand swapping
---@param pindex integer
---@param entity_name string
---@param position MapPosition
---@param direction defines.direction
---@param build_mode defines.build_mode
---@param opts { signal_layer: railutils.RailLayer?, quiet_unsupported: boolean? }?
---signal_layer: the layer a signal guards. quiet_unsupported: an elevated rail that cannot revive (nothing holds it)
---is reported as reason "unsupported" instead of being announced.
---@return LuaEntity|nil entity The built entity, or nil if already existed or ghost placed
---@return boolean success True if built, already existed, or ghost placed in forced mode
---@return "unsupported"? reason Why it failed, when the caller asked to handle it
local function try_build_entity(pindex, entity_name, position, direction, build_mode, opts)
   opts = opts or {}
   local player = game.get_player(pindex)
   if not player then return nil, false end

   local surface = player.surface

   -- Check if entity already exists at this position
   local existing = BuildHelpers.find_expected_entity(surface, position, entity_name, direction, opts.signal_layer)
   if existing then
      return nil, true -- Already exists, success (no cost)
   end

   -- In normal mode, check cost upfront; forced/superforced place ghosts for bots (no cost)
   local deductor = nil
   if build_mode == defines.build_mode.normal then
      deductor = InventoryUtils.deductor_to_place(pindex, entity_name)
      if not deductor then return nil, false end
   end

   -- Suppress hand change events for this tick since we're swapping the hand out and back
   HandMonitor.suppress_this_tick(pindex)

   -- Get temporary inventory and swap hand into it
   local tmp_inv = get_or_create_tmp_inventory(pindex)
   local cursor = player.cursor_stack

   -- Swap player's hand to temp inventory
   local swap_success = cursor.swap_stack(tmp_inv[1])
   if not swap_success then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.cannot-build" })
      return nil, false
   end

   -- Create blueprint in cursor
   cursor.set_stack({ name = "blueprint" })
   local extra = opts.signal_layer == RailInfo.RailLayer.ELEVATED and { rail_layer = "elevated" } or nil
   local bp_string = BlueprintSynthesizer.synthesize_simple_blueprint(entity_name, direction, nil, extra)
   local import_result = cursor.import_stack(bp_string)
   if import_result ~= 0 then
      -- Import failed, restore hand
      cursor.swap_stack(tmp_inv[1])
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.cannot-build" })
      return nil, false
   end

   -- Try to build from cursor (direction is already in the blueprint entity)
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

   -- Check if ghost was placed (blueprint always places ghosts)
   local ghost = find_expected_ghost(surface, position, entity_name, direction)

   if not ghost then
      if not can_build then
         Sounds.play_cannot_build(pindex)
         Speech.speak(pindex, { "fa.cannot-build" })
      end
      return nil, false
   end

   if build_mode == defines.build_mode.normal then
      -- Normal mode: revive the ghost to place the actual entity
      local _, revived_entity = ghost.silent_revive()
      if revived_entity then
         deductor:commit()
         return revived_entity, true
      else
         ghost.destroy()
         if opts.quiet_unsupported then return nil, false, "unsupported" end
         Sounds.play_cannot_build(pindex)
         Speech.speak(pindex, { "fa.cannot-build" })
         return nil, false
      end
   else
      -- Forced/superforced mode: ghost placement is success (bots or player pay later)
      return nil, true
   end
end

---Check if virtual train is locked for a player
---@param pindex integer
---@return boolean
function mod.is_locked(pindex)
   return vtd_storage[pindex].locked
end

---Unlock from rails and reset state
---@param pindex integer
---@param announce boolean
local function unlock_from_rails(pindex, announce)
   if announce then Speech.speak(pindex, { "fa.virtual-train-unlocked" }) end
   vtd_storage[pindex] = init_state()
end

---Get current move (always the last move in the stack)
---@param pindex integer
---@return vtd.Move|nil
local function get_current_move(pindex)
   local state = vtd_storage[pindex]
   if #state.moves == 0 then return nil end
   return state.moves[#state.moves]
end

---Create traverser from a move record
---@param move vtd.Move
---@return railutils.Traverser
local function create_traverser_from_move(move)
   return Traverser.new(move.rail_type, move.position, move.placement_direction, move.end_direction, move.layer)
end

---Get a bounding box for the tile containing a position
---@param position MapPosition
---@return BoundingBox
local function get_tile_search_area(position)
   local floor_x = math.floor(position.x)
   local floor_y = math.floor(position.y)
   return {
      { x = floor_x + 0.001, y = floor_y + 0.001 },
      { x = floor_x + 0.999, y = floor_y + 0.999 },
   }
end

---Check if a rail already exists at position matching prototype and direction
---@param surface LuaSurface
---@param position MapPosition
---@param prototype_name string
---@param direction defines.direction
---@return LuaEntity|nil
local function find_matching_rail(surface, position, prototype_name, direction)
   local entities = surface.find_entities_filtered({
      area = get_tile_search_area(position),
      name = prototype_name,
   })

   for _, entity in ipairs(entities) do
      if entity.direction == direction then return entity end
   end

   return nil
end

---Build a rail at the specified position using build_from_cursor
---@param pindex integer
---@param position MapPosition
---@param rail_type railutils.RailType
---@param placement_direction defines.direction
---@param layer railutils.RailLayer Layer of the rail (ignored for ramps)
---@param quiet_unsupported boolean? See try_build_entity
---@return LuaEntity|nil entity The created entity, or nil if already exists or ghost placed
---@return boolean success True if built, already existed, or ghost placed
---@return "unsupported"? reason
local function try_build_rail(pindex, position, rail_type, placement_direction, layer, quiet_unsupported)
   local state = vtd_storage[pindex]
   local prototype_name = Queries.rail_type_to_layered_prototype_type(rail_type, layer)

   return try_build_entity(
      pindex,
      prototype_name,
      position,
      placement_direction,
      state.build_mode,
      { quiet_unsupported = quiet_unsupported }
   )
end

---Push a move onto the stack
---@param pindex integer
---@param position MapPosition
---@param end_direction defines.direction
---@param rail_type railutils.RailType
---@param placement_direction defines.direction
---@param entity LuaEntity|nil
---@param is_bookmark boolean
---@param layer railutils.RailLayer Layer of the end we face
---@param reach number? Elevated reach left at that end
local function push_move(
   pindex,
   position,
   end_direction,
   rail_type,
   placement_direction,
   entity,
   is_bookmark,
   layer,
   reach
)
   local state = vtd_storage[pindex]
   local entities = {}
   if entity then table.insert(entities, entity) end
   table.insert(state.moves, {
      position = { x = position.x, y = position.y },
      end_direction = end_direction,
      rail_type = rail_type,
      placement_direction = placement_direction,
      entities = entities,
      is_bookmark = is_bookmark or false,
      layer = layer,
      reach = reach,
   })
end

---Pop a move from the stack
---@param pindex integer
---@param destroy_entities boolean Whether to destroy the entities
---@return vtd.Move|nil move The popped move, or nil if stack empty
---@return boolean? success Whether the entities were successfully removed (nil if not attempted)
local function pop_move(pindex, destroy_entities)
   local state = vtd_storage[pindex]
   if #state.moves == 0 then return nil end

   local move = table.remove(state.moves)

   -- Remove entities if requested
   if destroy_entities and #move.entities > 0 then
      -- Check upfront if we have character/inventory for real entities
      local player = game.get_player(pindex)
      local main_inv = nil
      local has_real_entity = false

      for _, entity in ipairs(move.entities) do
         if entity.valid and entity.type ~= "entity-ghost" then
            has_real_entity = true
            break
         end
      end

      if has_real_entity then
         if not player or not player.character then
            table.insert(state.moves, move)
            return nil, false
         end
         main_inv = player.character.get_inventory(defines.inventory.character_main)
         if not main_inv then
            table.insert(state.moves, move)
            return nil, false
         end
      end

      -- Remove entities in reverse order (signals before rails)
      for i = #move.entities, 1, -1 do
         local entity = move.entities[i]
         if entity.valid then
            if entity.type == "entity-ghost" then
               entity.destroy()
            else
               local success = entity.mine({ inventory = main_inv })
               if not success then
                  -- Mining failed - put move back (some entities may be lost)
                  table.insert(state.moves, move)
                  return nil, false
               end
            end
         end
      end
   end

   return move, true
end

---Announce current rail position and state
---@param pindex integer
local function announce_rail(pindex)
   local current = get_current_move(pindex)
   if not current then return end

   local mb = MessageBuilder.new()

   -- Position
   mb:fragment(FaUtils.format_coordinates(current.position.x, current.position.y))

   -- Activity
   local state = vtd_storage[pindex]
   if state.speculating then
      mb:fragment("planning rails")
   else
      mb:fragment("building rails")
   end

   -- Direction
   mb:fragment({ "fa.facing-direction", { "fa.direction", current.end_direction } })

   -- Layer
   if current.rail_type == RailInfo.RailType.RAMP then
      mb:fragment({ "fa.virtual-train-on-ramp" })
   elseif current.layer == RailInfo.RailLayer.ELEVATED then
      mb:fragment({ "fa.virtual-train-elevated" })
   end

   if state.speculating then mb:fragment("speculating") end

   Speech.speak(pindex, mb:build())
end

---Check if a connection exists by trying a move function
---@param rail_entity LuaEntity
---@param rail_type railutils.RailType
---@param layer railutils.RailLayer?
---@param end_direction defines.direction
---@param move_fn fun(trav: railutils.Traverser): boolean? Returns false if the move is not possible
---@return boolean
local function check_connection(rail_entity, rail_type, layer, end_direction, move_fn)
   local position = { x = rail_entity.position.x, y = rail_entity.position.y }
   local trav = Traverser.new(rail_type, position, rail_entity.direction, end_direction, layer)
   if move_fn(trav) == false then return false end

   local expected_pos = trav:get_position()
   local expected_direction = trav:get_placement_direction()
   local expected_type = Queries.rail_type_to_layered_prototype_type(trav:get_rail_kind(), trav:get_layer())
   local expected_floor_x = math.floor(expected_pos.x)
   local expected_floor_y = math.floor(expected_pos.y)

   local rails_at_pos = rail_entity.surface.find_entities_filtered({
      area = get_tile_search_area(expected_pos),
      type = Consts.ALL_RAIL_TYPES,
   })

   for _, connected_rail in ipairs(rails_at_pos) do
      local rail_floor_x = math.floor(connected_rail.position.x)
      local rail_floor_y = math.floor(connected_rail.position.y)
      if
         rail_floor_x == expected_floor_x
         and rail_floor_y == expected_floor_y
         and connected_rail.name == expected_type
         and connected_rail.direction == expected_direction
      then
         return true
      end
   end

   return false
end

---Count total connections (forward, left, right) for a rail end
---@param rail_entity LuaEntity
---@param end_direction defines.direction
---@return integer count Number of connections (0-4, the 4th is a ramp)
local function count_connections(rail_entity, end_direction)
   local rail_type, layer = Queries.prototype_type_to_rail_type_and_layer(get_effective_name(rail_entity))

   local count = 0
   local moves = {
      function(t)
         t:move_forward()
      end,
      function(t)
         t:move_left()
      end,
      function(t)
         t:move_right()
      end,
      function(t)
         if not t:can_change_layer() then return false end
         t:move_change_layer()
      end,
   }
   for _, move_fn in ipairs(moves) do
      if check_connection(rail_entity, rail_type, layer, end_direction, move_fn) then count = count + 1 end
   end

   return count
end

---Determine which end direction to use when locking onto a rail
---Prefers ends with fewer connections, otherwise chooses most counterclockwise
---@param rail_entity LuaEntity
---@return defines.direction The end direction to use
local function determine_initial_end(rail_entity)
   -- Get rail type and both end directions
   local rail_name = get_effective_name(rail_entity)
   local rail_type = Queries.prototype_type_to_rail_type_and_layer(rail_name)

   local end_dirs = Queries.get_end_directions(rail_type, rail_entity.direction)
   if #end_dirs ~= 2 then error("Rail data corrupt!") end

   -- Count connections at each end
   local end1_connections = count_connections(rail_entity, end_dirs[1])
   local end2_connections = count_connections(rail_entity, end_dirs[2])

   -- Prefer the end with no connections.
   if end1_connections == 0 and end2_connections == 0 then
      return end_dirs[1] < end_dirs[2] and end_dirs[1] or end_dirs[2]
   elseif end1_connections == 0 then
      return end_dirs[1]
   elseif end2_connections == 0 then
      return end_dirs[2]
   end

   -- Equal connections: choose most counterclockwise (numerically least)
   if end_dirs[1] < end_dirs[2] then
      return end_dirs[1]
   else
      return end_dirs[2]
   end
end

---Support and ramp ranges of the planner captured at lock time. Only for planners that can build elevated rails.
---@param state vtd.State
---@return fa.rails.ElevatedRanges
local function get_ranges(state)
   local planner = state.planner_description
   assert(planner and SurfaceHelper.has_elevated(planner))
   return {
      support_range = prototypes.entity[planner.support_name].support_range,
      ramp_range = prototypes.entity[planner.ramp_name].support_range,
   }
end

---Whether this player can build elevated rails with the captured planner; says why not if not
---@param pindex integer
---@return boolean
local function elevated_allowed(pindex)
   local state = vtd_storage[pindex]
   if not (state.planner_description and SurfaceHelper.has_elevated(state.planner_description)) then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-no-elevated-planner" })
      return false
   end
   if not game.get_player(pindex).force.rail_planner_allow_elevated_rails then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-elevated-not-researched" })
      return false
   end
   return true
end

---Layer of a rail end: ramps have one per end, other rails one per piece
---@param rail_type railutils.RailType
---@param layer railutils.RailLayer?
---@param placement_direction defines.direction
---@param end_direction defines.direction
---@return railutils.RailLayer
local function end_layer(rail_type, layer, placement_direction, end_direction)
   if rail_type == RailInfo.RailType.RAMP then
      return Queries.get_ramp_end_layer(rail_type, placement_direction, end_direction) --[[@as railutils.RailLayer]]
   end
   return layer or RailInfo.RailLayer.GROUND
end

---Elevated reach at an end of a rail in the world. Ghosts hold nothing, so their reach is 0.
---@param state vtd.State
---@param rail LuaEntity?
---@param layer railutils.RailLayer
---@param end_direction defines.direction
---@return number?
local function world_reach(state, rail, layer, end_direction)
   if layer ~= RailInfo.RailLayer.ELEVATED then return nil end
   if not (state.planner_description and SurfaceHelper.has_elevated(state.planner_description)) then return 0 end
   if not mod.is_real_rail(rail) then return 0 end
   ---@cast rail LuaEntity
   return ElevatedReach.reach_at_end(rail, end_direction, get_ranges(state))
end

---Lock onto a rail at the cursor position
---@param pindex integer
---@param rail_entity LuaEntity|nil Optional rail entity to lock onto (uses player.selected if nil)
---@param build_mode defines.build_mode|nil Build mode to use (defaults to normal)
function mod.lock_on_to_rail(pindex, rail_entity, build_mode)
   local player = game.get_player(pindex)
   if not player then return end

   -- Check if player has rail planner and get its description
   if not has_rail_planner(player) then
      Speech.speak(pindex, { "fa.virtual-train-need-planner" })
      return
   end

   local planner_description = SurfaceHelper.get_planner_description(player.cursor_stack.prototype)
   if not planner_description then
      Speech.speak(pindex, { "fa.virtual-train-need-planner" })
      return
   end

   -- Get rail entity (use provided one or player.selected)
   local rail = rail_entity or player.selected

   -- Check if rail is valid (check entity type)
   if not is_rail_entity(rail) then
      Speech.speak(pindex, { "fa.virtual-train-no-rail" })
      return
   end

   -- Convert entity name to rail type and layer
   local rail_name = get_effective_name(rail)
   if not Queries.is_known_rail_prototype_type(rail_name) then
      Speech.speak(pindex, { "fa.virtual-train-no-rail-info" })
      return
   end
   local rail_type, piece_layer = Queries.prototype_type_to_rail_type_and_layer(rail_name)
   local is_elevated_piece = rail_type == RailInfo.RailType.RAMP or piece_layer == RailInfo.RailLayer.ELEVATED
   if is_elevated_piece and not SurfaceHelper.has_elevated(planner_description) then
      Speech.speak(pindex, { "fa.virtual-train-no-elevated-planner" })
      return
   end

   -- Determine which end direction to use
   local chosen_end_direction = determine_initial_end(rail)
   local layer = end_layer(rail_type, piece_layer, rail.direction, chosen_end_direction)

   -- Initialize state
   local state = vtd_storage[pindex]
   state.locked = true
   state.moves = {}
   state.speculating = false
   state.build_mode = build_mode or defines.build_mode.normal
   state.planner_description = planner_description
   state.pending_support = nil

   -- Add initial rail to moves (entity = rail, not nil, but we won't destroy it on undo)
   -- Actually, use nil since it already exists and we shouldn't destroy it
   local reach = world_reach(state, rail, layer, chosen_end_direction)
   push_move(pindex, rail.position, chosen_end_direction, rail_type, rail.direction, nil, false, layer, reach)

   -- Set cursor position
   local vp = Viewpoint.get_viewpoint(pindex)
   vp:set_cursor_pos(rail.position)

   -- Announce lock-on with build mode and end direction
   local mb = MessageBuilder.new()
   mb:fragment({ "fa.virtual-train-locked" })
   if state.build_mode == defines.build_mode.forced then
      mb:fragment({ "fa.virtual-train-mode-force" })
   elseif state.build_mode == defines.build_mode.superforced then
      mb:fragment({ "fa.virtual-train-mode-superforce" })
   end
   mb:fragment({ "fa.facing-direction", { "fa.direction", chosen_end_direction } })
   if rail_type == RailInfo.RailType.RAMP then
      mb:fragment({ "fa.virtual-train-on-ramp" })
   elseif layer == RailInfo.RailLayer.ELEVATED then
      mb:fragment({ "fa.virtual-train-elevated" })
   end
   Speech.speak(pindex, mb:build())
end

---Handle cursor stack changed - check if player still has rail planner
---@param event EventData.on_player_cursor_stack_changed
function mod.on_cursor_stack_changed(event)
   local pindex = event.player_index
   local state = vtd_storage[pindex]

   if not state.locked then return end

   local player = game.get_player(pindex)
   if not player or not has_rail_planner(player) then unlock_from_rails(pindex, true) end
end

---Traverser moves for each move kind
---@type table<vtd.MoveKind, fun(trav: railutils.Traverser)>
local MOVE_FUNCS = {
   forward = function(trav)
      trav:move_forward()
   end,
   left = function(trav)
      trav:move_left()
   end,
   right = function(trav)
      trav:move_right()
   end,
   change_layer = function(trav)
      trav:move_change_layer()
   end,
}

---Remove an entity we just built, giving its items back where possible
---@param pindex integer
---@param entity LuaEntity?
local function remove_built(pindex, entity)
   if not (entity and entity.valid) then return end
   if entity.type == "entity-ghost" then
      entity.destroy()
      return
   end
   local player = game.get_player(pindex)
   local inv = player and player.character and player.character.get_inventory(defines.inventory.character_main)
   if inv then
      entity.mine({ inventory = inv })
   else
      entity.destroy()
   end
end

---Build a rail support exactly at a rail end
---@param pindex integer
---@param position MapPosition
---@param direction defines.direction
---@return boolean success
---@return LuaEntity? entity The built support (normal mode), nil if it already stood there or is a ghost
---@return boolean? existed It was already there
local function try_build_support(pindex, position, direction)
   local state = vtd_storage[pindex]
   local player = game.get_player(pindex)
   if not player then return false end
   local name = state.planner_description.support_name

   -- A support facing the opposite way along the track holds the same
   for _, dir in ipairs({ direction, (direction + 8) % 16 }) do
      if BuildHelpers.find_exact_entity(player.surface, position, name, dir) then return true, nil, true end
   end

   local normal = state.build_mode == defines.build_mode.normal
   local deductor = nil
   if normal then
      deductor = InventoryUtils.deductor_to_place(pindex, name)
      if not deductor then return false end
   end

   local ghost = BuildHelpers.place_ghost_exact(pindex, name, position, direction)
   if not ghost then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-support-cannot-place" })
      return false
   end
   if not normal then return true, nil, false end

   local _, entity = ghost.silent_revive()
   if not entity then
      if ghost.valid then ghost.destroy() end
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-support-cannot-place" })
      return false
   end
   ---@cast deductor fa.InventoryUtils.Deductor
   deductor:commit()
   return true, entity, false
end

local move_in_direction

---An elevated rail cannot be held: suggest a support, or place it right away in automatic mode
---@param pindex integer
---@param kind vtd.MoveKind
---@param piece railutils.SupportPlanner.Piece The rail that needs holding
---@param far_direction defines.direction Its far end
---@param current vtd.Move The move it continues from
---@return boolean success
---@return LocalisedString? prefix
local function support_needed(pindex, kind, piece, far_direction, current)
   local state = vtd_storage[pindex]

   -- Best at the far end of the new rail: from there it holds 5 more. Otherwise at the end we are on.
   local spot = nil
   if far_direction % 2 == 0 then
      spot = {
         position = SupportPlanner.end_position(piece, far_direction),
         direction = far_direction,
         at_far_end = true,
      }
   elseif current.end_direction % 2 == 0 then
      spot = {
         position = create_traverser_from_move(current):get_end_position(),
         direction = current.end_direction,
         at_far_end = false,
      }
   end

   if not spot then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-no-support-spot", { "fa.direction", far_direction } })
      return false
   end

   if settings.global[SettingDecls.SETTING_NAMES.ELEVATED_AUTO_SUPPORT].value then
      return move_in_direction(pindex, MOVE_FUNCS[kind], kind, spot)
   end

   state.pending_support = {
      kind = kind,
      position = spot.position,
      direction = spot.direction,
      at_far_end = spot.at_far_end,
   }
   Speech.speak(pindex, {
      spot.at_far_end and "fa.virtual-train-support-needed-ahead" or "fa.virtual-train-support-needed-here",
   })
   return false
end

---Move in a direction
---@param pindex integer
---@param move_func fun(trav: railutils.Traverser) Function to call on traverser
---@param kind vtd.MoveKind
---@param support vtd.SupportSpot? A support to build first, so the new rail is held
---@return boolean success True if move succeeded
---@return LocalisedString? prefix Said before the tile is read
function move_in_direction(pindex, move_func, kind, support)
   local player = game.get_player(pindex)
   if not player then return false end

   local state = vtd_storage[pindex]
   state.pending_support = nil

   local current = get_current_move(pindex)
   if not current then return false end

   -- Create traverser from current state and move
   local trav = create_traverser_from_move(current)
   move_func(trav) -- Let it crash if it fails

   -- Get new state from traverser
   local new_pos = trav:get_position()
   local new_end_dir = trav:get_direction()
   local new_rail_type = trav:get_rail_kind()
   local new_placement_dir = trav:get_placement_direction()
   local new_layer = trav:get_layer()

   if state.speculating then
      -- In speculation mode, just update cursor position without modifying stack
      local vp = Viewpoint.get_viewpoint(pindex)
      vp:set_cursor_pos(new_pos)
      return true
   end

   local is_ramp = new_rail_type == RailInfo.RailType.RAMP
   local is_elevated_rail = not is_ramp and new_layer == RailInfo.RailLayer.ELEVATED
   if (is_ramp or is_elevated_rail) and not elevated_allowed(pindex) then return false end

   if not is_elevated_rail then
      -- Ground rails and ramps hold themselves
      local entity, success = try_build_rail(pindex, new_pos, new_rail_type, new_placement_dir, new_layer)
      if not success then return false end
      local reach = nil
      if is_ramp and new_layer == RailInfo.RailLayer.ELEVATED then reach = get_ranges(state).ramp_range end
      push_move(pindex, new_pos, new_end_dir, new_rail_type, new_placement_dir, entity, false, new_layer, reach)
      Viewpoint.get_viewpoint(pindex):set_cursor_pos(new_pos)
      if is_ramp then
         return true,
            { new_layer == RailInfo.RailLayer.ELEVATED and "fa.virtual-train-ramp-up" or "fa.virtual-train-ramp-down" }
      end
      return true
   end

   -- Elevated rail that is already built: drive over it, and ask the world what holds it
   local elevated_name = Queries.rail_type_to_layered_prototype_type(new_rail_type, new_layer)
   local existing = find_matching_rail(player.surface, new_pos, elevated_name, new_placement_dir)
   if existing then
      local reach = world_reach(state, existing, new_layer, new_end_dir)
      push_move(pindex, new_pos, new_end_dir, new_rail_type, new_placement_dir, nil, false, new_layer, reach)
      Viewpoint.get_viewpoint(pindex):set_cursor_pos(new_pos)
      return true
   end

   -- Elevated rail: something must hold it
   local ranges = get_ranges(state)
   local piece = { rail_type = new_rail_type, placement_direction = new_placement_dir, position = new_pos }
   local length = SupportPlanner.length(piece)
   local reach_after = (current.reach or 0) - length

   local support_entity = nil
   if support then
      local ok, entity = try_build_support(pindex, support.position, support.direction)
      if not ok then return false end
      support_entity = entity
      reach_after = support.at_far_end and ranges.support_range or (ranges.support_range - length)
   end

   -- Ghosts never revive here, so in force modes go by the reach we track. In normal mode the engine decides: the
   -- track ahead may be held by something we do not track.
   if state.build_mode ~= defines.build_mode.normal and reach_after < -EPSILON then
      return support_needed(pindex, kind, piece, new_end_dir, current)
   end

   local entity, success, reason = try_build_rail(pindex, new_pos, new_rail_type, new_placement_dir, new_layer, true)
   if not success then
      remove_built(pindex, support_entity)
      if reason == "unsupported" then
         if support then
            Sounds.play_cannot_build(pindex)
            Speech.speak(pindex, { "fa.cannot-build" })
            return false
         end
         return support_needed(pindex, kind, piece, new_end_dir, current)
      end
      return false
   end

   push_move(
      pindex,
      new_pos,
      new_end_dir,
      new_rail_type,
      new_placement_dir,
      entity,
      false,
      new_layer,
      math.max(reach_after, 0)
   )
   -- The support goes first in the list, so undo removes the rail before the support holding it
   if support_entity then table.insert(state.moves[#state.moves].entities, 1, support_entity) end

   Viewpoint.get_viewpoint(pindex):set_cursor_pos(new_pos)
   if support then return true, { "fa.virtual-train-support-placed" } end
   return true
end

---Extend forward
---@param pindex integer
---@return boolean success
---@return LocalisedString? prefix
function mod.extend_forward(pindex)
   return move_in_direction(pindex, MOVE_FUNCS.forward, "forward")
end

---Extend left
---@param pindex integer
---@return boolean success
---@return LocalisedString? prefix
function mod.extend_left(pindex)
   return move_in_direction(pindex, MOVE_FUNCS.left, "left")
end

---Extend right
---@param pindex integer
---@return boolean success
---@return LocalisedString? prefix
function mod.extend_right(pindex)
   return move_in_direction(pindex, MOVE_FUNCS.right, "right")
end

---Ramp to the other layer from the current end (shift+comma)
---@param pindex integer
---@return boolean success
---@return LocalisedString? prefix
function mod.change_layer(pindex)
   local current = get_current_move(pindex)
   if not current then return false end
   if not create_traverser_from_move(current):can_change_layer() then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-ramp-not-cardinal", { "fa.direction", current.end_direction } })
      return false
   end
   return move_in_direction(pindex, MOVE_FUNCS.change_layer, "change_layer")
end

---Place the suggested support and build the rail that needed it (control+comma)
---@param pindex integer
---@return boolean success
---@return LocalisedString? prefix
function mod.accept_support(pindex)
   local state = vtd_storage[pindex]
   local pending = state.pending_support
   if not pending then
      Speech.speak(pindex, { "fa.virtual-train-no-support-pending" })
      return false
   end
   return move_in_direction(pindex, MOVE_FUNCS[pending.kind], pending.kind, pending)
end

---Place a support at the end we are on (control+shift+comma)
---@param pindex integer
function mod.place_support_here(pindex)
   local state = vtd_storage[pindex]
   local current = get_current_move(pindex)
   if not current then return end

   if state.speculating then
      Speech.speak(pindex, { "fa.virtual-train-cannot-support-speculating" })
      return
   end
   if current.layer ~= RailInfo.RailLayer.ELEVATED then
      Speech.speak(pindex, { "fa.virtual-train-support-ground" })
      return
   end
   if current.end_direction % 2 ~= 0 then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-no-support-spot", { "fa.direction", current.end_direction } })
      return
   end
   if not elevated_allowed(pindex) then return end

   local position = create_traverser_from_move(current):get_end_position()
   local ok, entity, existed = try_build_support(pindex, position, current.end_direction)
   if not ok then return end
   if entity then table.insert(current.entities, entity) end
   current.reach = get_ranges(state).support_range
   Speech.speak(pindex, { existed and "fa.virtual-train-support-exists" or "fa.virtual-train-support-placed" })
end

---Flip to other end of current rail
---@param pindex integer
function mod.flip_end(pindex)
   local current = get_current_move(pindex)
   if not current then return end

   local trav = create_traverser_from_move(current)
   trav:flip_ends()

   -- The reach behind the other end is different: ask the world
   local state = vtd_storage[pindex]
   local layer = trav:get_layer()
   local reach = nil
   if layer == RailInfo.RailLayer.ELEVATED then
      local player = game.get_player(pindex)
      local name = Queries.rail_type_to_layered_prototype_type(trav:get_rail_kind(), layer)
      local rail = player
         and find_matching_rail(player.surface, trav:get_position(), name, trav:get_placement_direction())
      reach = world_reach(state, rail, layer, trav:get_direction())
   end

   -- Add new move with flipped end
   push_move(
      pindex,
      trav:get_position(),
      trav:get_direction(),
      trav:get_rail_kind(),
      trav:get_placement_direction(),
      nil, -- No entity built
      false,
      layer,
      reach
   )

   -- Update cursor position
   local vp = Viewpoint.get_viewpoint(pindex)
   vp:set_cursor_pos(trav:get_position())

   -- Announce flip with new direction
   local mb = MessageBuilder.new()
   mb:fragment({ "fa.virtual-train-flipped" })
      :fragment({ "fa.virtual-train-now-facing", { "fa.direction", trav:get_direction() } })
   Speech.speak(pindex, mb:build())
end

---Toggle speculation mode
---@param pindex integer
function mod.toggle_speculation(pindex)
   local state = vtd_storage[pindex]
   local current = get_current_move(pindex)
   if not current then return end

   if state.speculating then
      -- Exit speculation: restore cursor to current stack position
      -- (Stack was never modified during speculation)
      local vp = Viewpoint.get_viewpoint(pindex)
      vp:set_cursor_pos(current.position)

      state.speculating = false

      Speech.speak(pindex, { "fa.virtual-train-speculation-exit" })
   else
      -- Enter speculation mode
      state.speculating = true

      Speech.speak(pindex, { "fa.virtual-train-speculation-enter" })
   end
end

---Create bookmark at current position
---@param pindex integer
function mod.create_bookmark(pindex)
   local state = vtd_storage[pindex]

   if state.speculating then
      Speech.speak(pindex, { "fa.virtual-train-cannot-bookmark-speculating" })
      return
   end

   if #state.moves > 0 then
      state.moves[#state.moves].is_bookmark = true
      Speech.speak(pindex, { "fa.virtual-train-bookmark-created" })
   end
end

---Return to last bookmark
---@param pindex integer
---@return boolean success Whether a bookmark was found and returned to
function mod.return_to_bookmark(pindex)
   local state = vtd_storage[pindex]

   if state.speculating then
      Speech.speak(pindex, { "fa.virtual-train-cannot-use-bookmark-speculating" })
      return false
   end

   -- Find last bookmark
   local bookmark_index = nil
   for i = #state.moves, 1, -1 do
      if state.moves[i].is_bookmark then
         bookmark_index = i
         break
      end
   end

   if not bookmark_index then
      Speech.speak(pindex, { "fa.virtual-train-no-bookmarks" })
      return false
   end

   -- Remove all moves after bookmark (don't destroy rails)
   local removed_count = 0
   while #state.moves > bookmark_index do
      pop_move(pindex, false)
      removed_count = removed_count + 1
   end

   -- Clear bookmark flag so user can access earlier bookmarks
   state.moves[bookmark_index].is_bookmark = false

   -- Update cursor position
   local current = get_current_move(pindex)
   if current then
      local vp = Viewpoint.get_viewpoint(pindex)
      vp:set_cursor_pos(current.position)
   end

   Speech.speak(pindex, { "fa.virtual-train-returned-to-bookmark", removed_count })
   return true
end

---Backspace (undo last move)
---@param pindex integer
function mod.backspace(pindex)
   local state = vtd_storage[pindex]

   if state.speculating then
      Speech.speak(pindex, { "fa.virtual-train-cannot-undo-speculating" })
      return
   end

   local move, success = pop_move(pindex, true)
   if not move then
      if success == false then
         Sounds.play_cannot_build(pindex)
         Speech.speak(pindex, { "fa.virtual-train-cannot-backspace" })
      end
      return
   end

   if #state.moves == 0 then
      -- Removed last move, unlock
      unlock_from_rails(pindex, true)
      return
   end

   -- Update cursor position
   local current = get_current_move(pindex)
   if current then
      local vp = Viewpoint.get_viewpoint(pindex)
      vp:set_cursor_pos(current.position)
   end

   Speech.speak(pindex, { "fa.virtual-train-undid" })
end

---Place signal using build_from_cursor
---@param pindex integer
---@param side "left"|"right"
---@param is_chain boolean
---@return boolean success True if signal was placed or already existed
function mod.place_signal(pindex, side, is_chain)
   local current = get_current_move(pindex)
   if not current then return false end

   local state = vtd_storage[pindex]
   if current.rail_type == RailInfo.RailType.RAMP then
      Sounds.play_cannot_build(pindex)
      Speech.speak(pindex, { "fa.virtual-train-no-signal-on-ramp" })
      return false
   end
   local trav = create_traverser_from_move(current)

   local signal_side = side == "left" and Traverser.SignalSide.LEFT or Traverser.SignalSide.RIGHT
   local signal_pos = trav:get_signal_pos(signal_side)
   local signal_dir = trav:get_signal_direction(signal_side)

   local signal_name = is_chain and "rail-chain-signal" or "rail-signal"

   local entity, already_existed = try_build_entity(
      pindex,
      signal_name,
      signal_pos,
      signal_dir,
      state.build_mode,
      { signal_layer = current.layer or RailInfo.RailLayer.GROUND }
   )

   if entity then
      -- Add signal to current move's entities for undo
      table.insert(current.entities, entity)

      local mb = MessageBuilder.new()
      mb:fragment({
         "fa.virtual-train-placed-" .. (is_chain and "chain-signal" or "signal"),
      }):fragment({ "fa.direction", signal_dir })
      Speech.speak(pindex, mb:build())
      return true
   elseif already_existed then
      -- Signal already exists, no error
      Speech.speak(pindex, { "fa.virtual-train-signal-exists", side })
      return true
   end
   -- If entity is nil and not already_existed, try_build_entity already spoke the error
   return false
end

---Main keyboard action handler
---@param event EventData
---@return boolean handled Whether this event was handled (prevents fallthrough)
---@return boolean should_read_tile Whether caller should read the tile
---@return LocalisedString? prefix Said before the tile, e.g. that a support was placed
function mod.on_kb_descriptive_action_name(event)
   ---@cast event EventData.CustomInputEvent
   local pindex = event.player_index
   local state = vtd_storage[pindex]

   if not state.locked then return false, false end

   local player = game.get_player(pindex)
   if not player or not has_rail_planner(player) then
      unlock_from_rails(pindex, true)
      return false, false
   end

   local action = event.input_name

   -- A suggested support is only good for the very next key
   if action ~= "fa-c-comma" and action ~= "fa-k" then state.pending_support = nil end

   -- Movement (success determines tile read)
   if action == "fa-comma" then
      local success, prefix = mod.extend_forward(pindex)
      return true, success, prefix
   elseif action == "fa-m" then
      local success, prefix = mod.extend_left(pindex)
      return true, success, prefix
   elseif action == "fa-dot" then
      local success, prefix = mod.extend_right(pindex)
      return true, success, prefix
   elseif action == "fa-s-comma" then
      local success, prefix = mod.change_layer(pindex)
      return true, success, prefix
   elseif action == "fa-c-comma" then
      local success, prefix = mod.accept_support(pindex)
      return true, success, prefix
   elseif action == "fa-cs-comma" then
      mod.place_support_here(pindex)
      return true, false
   elseif action == "fa-a-comma" then
      mod.flip_end(pindex)
      return true, true
   end

   -- Speculation
   if action == "fa-slash" then
      mod.toggle_speculation(pindex)
      return true, false
   end

   -- Bookmarks
   if action == "fa-s-b" then
      mod.create_bookmark(pindex)
      return true, false
   end

   -- Signals (success determines tile read)
   if action == "fa-c-m" then
      local success = mod.place_signal(pindex, "left", true)
      return true, success
   elseif action == "fa-c-dot" then
      local success = mod.place_signal(pindex, "right", true)
      return true, success
   elseif action == "fa-s-m" then
      local success = mod.place_signal(pindex, "left", false)
      return true, success
   elseif action == "fa-s-dot" then
      local success = mod.place_signal(pindex, "right", false)
      return true, success
   end

   -- Status
   if action == "fa-k" then
      announce_rail(pindex)
      return true, false
   end

   -- Undo
   if action == "fa-backspace" then
      mod.backspace(pindex)
      return true, true
   end

   return false, false
end

---Open syntrax input UI if locked onto a rail
---@param pindex integer
---@return boolean opened True if UI was opened
function mod.open_syntrax_input(pindex)
   local state = vtd_storage[pindex]
   if not state.locked then return false end
   if not state.planner_description then return false end

   local current = get_current_move(pindex)
   if not current then return false end

   UiRouter.get_router(pindex):open_ui(UiRouter.UI_NAMES.SYNTRAX_INPUT, {
      position = current.position,
      direction = current.end_direction,
   })
   return true
end

---Execute syntrax code using stored VTD state
---@param pindex integer
---@param source string Syntrax source code
---@return LuaEntity[]|nil entities The placed rails/ghosts, or nil on failure
---@return string|nil error Error message if failed
function mod.execute_syntrax(pindex, source)
   local state = vtd_storage[pindex]
   if not state.locked then return nil, "Not locked to rails" end
   if not state.planner_description then return nil, "No rail planner" end

   local current = get_current_move(pindex)
   if not current then return nil, "No current position" end

   return SyntraxRunner.execute({
      pindex = pindex,
      source = source,
      position = current.position,
      direction = current.end_direction,
      rail_type = current.rail_type,
      placement_direction = current.placement_direction,
      layer = current.layer,
      start_reach = current.reach,
      planner_description = state.planner_description,
      build_mode = state.build_mode,
   })
end

return mod
