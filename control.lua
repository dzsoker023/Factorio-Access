require("syntrax")

--Main file for mod runtime
local Logging = require("scripts.logging")
Logging.init()
-- Set logging level
--Logging.set_level("DEBUG")

-- Create logger for control.lua
local logger = Logging.Logger("control")

local util = require("util")

local AreaOperations = require("scripts.area-operations")
local AudioCues = require("scripts.audio-cues")
local Blueprints = require("scripts.blueprints")
local BuildingTools = require("scripts.building-tools")
local BuildDimensions = require("scripts.build-dimensions")
local BuildLock = require("scripts.build-lock")
-- Register build lock backends (tiles must be first to catch tile items before simple backend)
BuildLock.register_backend(require("scripts.build-lock-backends.tiles"))
BuildLock.register_backend(require("scripts.build-lock-backends.transport-belts"))
BuildLock.register_backend(require("scripts.build-lock-backends.electric-poles"))
BuildLock.register_backend(require("scripts.build-lock-backends.simple"))
local BumpDetection = require("scripts.bump-detection")
local CircuitNetworks = require("scripts.circuit-network")
local Combat = require("scripts.combat")
local Consts = require("scripts.consts")
local SettingDecls = require("scripts.settings-decls")
local SETTING_NAMES = SettingDecls.SETTING_NAMES
local Crafting = require("scripts.crafting")
local CursorChanges = require("scripts.cursor-changes")
local Driving = require("scripts.driving")
local HandMonitor = require("scripts.hand-monitor")
local Electrical = require("scripts.electrical")
local EntityAccess = require("scripts.entity-access")
local EntitySelection = require("scripts.entity-selection")
local Equipment = require("scripts.equipment")
local EventManager = require("scripts.event-manager")
local FaCommands = require("scripts.fa-commands")
local FaInfo = require("scripts.fa-info")
local FaUtils = require("scripts.fa-utils")
local F = require("scripts.field-ref")
local Filters = require("scripts.filters")
local Graphics = require("scripts.graphics")
local InventoryTransfers = require("scripts.inventory-transfers")
local InventoryUtils = require("scripts.inventory-utils")
local ItemInfo = require("scripts.item-info")
local KruiseKontrol = require("scripts.kruise-kontrol-wrapper")
local LightningZones = require("scripts.lightning-zones")
local Localising = require("scripts.localising")
local NoHover = require("scripts.no-hover")
local Speech = require("scripts.speech")
local MessageBuilder = Speech.MessageBuilder
local Mouse = require("scripts.mouse")
local MovementHistory = require("scripts.movement-history")
local PlayerInit = require("scripts.player-init")
local PlayerMiningTools = require("scripts.player-mining-tools")
local Quickbar = require("scripts.quickbar")
local Research = require("scripts.research")
require("scripts.rich-text") -- registers rich text processor with speech.lua
local Rulers = require("scripts.rulers")
local ScannerEntrypoint = require("scripts.scanner.entrypoint")
local Territory = require("scripts.scanner.backends.territory")
local Spidertron = require("scripts.spidertron")
local SpidertronRemote = require("scripts.spidertron-remote")
local TH = require("scripts.table-helpers")
local Teleport = require("scripts.teleport")
local TestFramework = require("scripts.test-framework")
local TileReader = require("scripts.tile-reader")
local TransportBelts = require("scripts.transport-belts")
local TravelTools = require("scripts.travel-tools")
local UpgradePlanner = require("scripts.upgrade-planner")
local PlannerUtils = require("scripts.planner-utils")
local VanillaMode = require("scripts.vanilla-mode")
local VirtualTrainDriving = require("scripts.rails.virtual-train-driving")
local SonifierTickHandler = require("scripts.sonifiers.tick-handler")
local GridSonifier = require("scripts.sonifiers.grid-sonifier")
local CraftingBackend = require("scripts.sonifiers.grid-backends.crafting")
local BattleNotice = require("scripts.sonifiers.battle-notice")
local ForceGhostEnabler = require("scripts.force-ghost-enabler")
local AimAssist = require("scripts.combat.aim-assist")
local Capsules = require("scripts.combat.capsules")
local PlayerWeapon = require("scripts.combat.player-weapon")
local Zoom = require("scripts.zoom")

-- UI modules (required for registration with router)
require("scripts.ui.belt-analyzer")
local EntityUI = require("scripts.ui.entity-ui")
require("scripts.ui.menus.blueprints-menu")
require("scripts.ui.menus.blueprint-book-menu")
require("scripts.ui.selectors.decon-selector")
require("scripts.ui.selectors.upgrade-selector")
require("scripts.ui.selectors.blueprint-selector")
require("scripts.ui.menus.blueprint-setup")
require("scripts.ui.menus.blueprint-setup-config")
require("scripts.ui.planners.upgrade-planner-menu")
require("scripts.ui.planners.decon-planner-menu")
require("scripts.ui.tabs.tile-chooser")
require("scripts.ui.selectors.copy-paste-selector")
require("scripts.ui.menus.gun-menu")
local MainMenu = require("scripts.ui.menus.main-menu")
local WorldMenu = require("scripts.ui.menus.world-menu")
require("scripts.ui.menus.fast-travel-menu")
require("scripts.ui.menus.debug-menu")
require("scripts.ui.menus.settings-menu")
require("scripts.ui.menus.rail-builder")
require("scripts.ui.menus.syntrax-program")
local SpidertronRemoteSelector = require("scripts.ui.menus.spidertron-remote-selector")
require("scripts.ui.tabs.item-chooser")
require("scripts.ui.tabs.signal-chooser")
require("scripts.ui.tabs.fluid-chooser")
require("scripts.ui.tabs.entity-chooser")
require("scripts.ui.tabs.prototype-lister")
require("scripts.ui.tabs.equipment-selector")
local Help = require("scripts.ui.help")
local MessageLists = require("scripts.message-lists")
require("scripts.ui.logistics-config")
require("scripts.ui.selectors.logistic-group-selector")
require("scripts.ui.selectors.train-group-selector")
require("scripts.ui.selectors.platform-selector")
require("scripts.ui.selectors.planet-selector")
require("scripts.ui.selectors.interrupt-selector")
require("scripts.ui.selectors.stop-selector")
require("scripts.ui.constant-combinator")
require("scripts.ui.decider-combinator")
require("scripts.ui.power-switch")
require("scripts.ui.schedule-editor")
require("scripts.ui.programmable-speaker")
require("scripts.ui.circuit-navigator")
require("scripts.ui.selectors.spidertron-autopilot-selector")
require("scripts.ui.selectors.spidertron-follow-selector")
require("scripts.ui.menus.offshore-pump-placement")
require("scripts.ui.menus.warnings")
require("scripts.ui.generic-inventory")
require("scripts.ui.simple-textbox")
require("scripts.ui.internal.search-setter")
require("scripts.ui.internal.cursor-coordinate-input")
require("scripts.ui.internal.syntrax-input")
require("scripts.ui.help")
require("scripts.ui.menus.tutorial")
local GameGui = require("scripts.ui.game-gui")
local UiRouter = require("scripts.ui.router")
local VehicleCycler = require("scripts.vehicle-cycler")
local Viewpoint = require("scripts.viewpoint")
local Wires = require("scripts.wires")
local Walking = require("scripts.walking")
local Warnings = require("scripts.warnings")
local WorkQueue = require("scripts.work-queue")
local WorkerRobots = require("scripts.worker-robots")
local sounds = require("scripts.ui.sounds")

---@meta scripts.shared-types

-- Register grid sonifier backends
GridSonifier.register_backend_factory("crafting", CraftingBackend.new, CraftingBackend.ENTITY_TYPES)

entity_types = {}
production_types = {}
building_types = {}
local dirs = defines.direction

---Check if in combat mode and speak feedback if so
---@param pindex integer
---@return boolean true if in combat mode (caller should return early)
local function skip_in_combat_mode(pindex)
   if Combat.is_combat_mode(pindex) then
      Speech.speak(pindex, { "fa.not-available-in-combat-mode" })
      return true
   end
   return false
end

-- Initialize players as a deny-access table to catch any direct usage
players = TH.deny_access_table()

--Reads the item in hand, its facing direction if applicable, its count, and its total count including units in the main inventory.
---@param pindex number
local function read_hand(pindex)
   if storage.players[pindex].skip_read_hand == true then
      storage.players[pindex].skip_read_hand = false
      return
   end
   local cursor_stack = game.get_player(pindex).cursor_stack
   local cursor_ghost = game.get_player(pindex).cursor_ghost
   if cursor_stack and cursor_stack.valid_for_read then
      if cursor_stack.is_blueprint then
         --Blueprint extra info
         Speech.speak(pindex, Blueprints.get_blueprint_info(cursor_stack, true, pindex))
      elseif cursor_stack.is_blueprint_book then
         Speech.speak(pindex, Blueprints.get_blueprint_book_info(cursor_stack, true))
      elseif cursor_stack.is_upgrade_item then
         local message = MessageBuilder.new()
         UpgradePlanner.describe_planner(message, cursor_stack)
         Speech.speak(pindex, message:build())
      elseif cursor_stack.is_deconstruction_item then
         local label = cursor_stack.label
         if label and label ~= "" then
            Speech.speak(pindex, { "fa.item-decon-planner-labeled", label })
         else
            Speech.speak(pindex, { "item-name.deconstruction-planner" })
         end
      else
         --Any other valid item
         local vp = Viewpoint.get_viewpoint(pindex)
         local out = { "fa.cursor-description" }
         table.insert(out, cursor_stack.prototype.localised_name)
         local build_entity = cursor_stack.prototype.place_result
         if build_entity and build_entity.supports_direction then
            table.insert(out, 1)
            table.insert(out, { "fa.facing-direction", FaUtils.direction_lookup(vp:get_hand_direction()) })
         else
            table.insert(out, 0)
            table.insert(out, "")
         end
         table.insert(out, cursor_stack.count)
         --In remote view (or any state without an accessible character), the
         --player has no main inventory to check - get_main_inventory() returns
         --nil there instead of an empty inventory, so guard against that.
         local main_inventory = game.get_player(pindex).get_main_inventory()
         local extra = main_inventory and main_inventory.get_item_count(cursor_stack.name) or 0
         if extra > 0 then
            table.insert(out, cursor_stack.count + extra)
         else
            table.insert(out, 0)
         end
         Speech.speak(pindex, out)
      end
   elseif cursor_ghost ~= nil then
      --Any ghost
      local vp = Viewpoint.get_viewpoint(pindex)
      local out = { "fa.cursor-description" }
      table.insert(out, cursor_ghost.name.localised_name)
      local build_entity = cursor_ghost.name.place_result
      if build_entity and build_entity.supports_direction then
         table.insert(out, 1)
         table.insert(out, { "fa.facing-direction", FaUtils.direction_lookup(vp:get_hand_direction()) })
      else
         table.insert(out, 0)
         table.insert(out, "")
      end
      table.insert(out, 0)
      local extra = 0
      if extra > 0 then
         table.insert(out, cursor_stack.count + extra)
      else
         table.insert(out, 0)
      end
      Speech.speak(pindex, out)
   else
      Speech.speak(pindex, { "fa.empty_cursor" })
   end
end

--Checks if the storage players table has been created, and if the table entry for this player exists. Otherwise it is initialized.
function check_for_player(index)
   if storage.players[index] == nil then
      local player = game.get_player(index)
      if player then PlayerInit.initialize(player) end
      return false
   else
      return true
   end
end

---Local helper: Reads tile info and adds build preview info if player is holding a building
---@param pindex integer Player index
---@param start_text LocalisedString? Optional text to prepend to the result
local function read_tile_with_preview_info(pindex, start_text)
   local message = MessageBuilder.new()
   if start_text then message:fragment(start_text) end

   TileReader.read_tile_inner(pindex, message)

   -- Add build preview info if holding a building and tile is empty/has resources
   local ent = EntitySelection.get_first_ent_at_tile(pindex)
   if not ent or ent.type == "resource" then
      local stack = game.get_player(pindex).cursor_stack
      if stack and stack.valid_for_read and stack.valid and stack.prototype.place_result ~= nil then
         message:fragment(BuildingTools.build_preview_checks_info(stack, pindex))
      end
   end

   Speech.speak(pindex, message:build())
end

--Update the position info and cursor info during smooth walking.
EventManager.on_event(
   defines.events.on_player_changed_position,
   ---@param event EventData.on_player_changed_position
   ---@param pindex integer
   function(event, pindex)
      local p = game.get_player(pindex)

      -- Check for teleportation (large position jump)
      local reader = MovementHistory.get_movement_history_reader(pindex)
      local prev_entry = reader:get(0)
      local old_pos = prev_entry and prev_entry.position
      if old_pos and util.distance(old_pos, p.position) > 10 then
         MovementHistory.reset_and_increment_generation(pindex)
      end

      --Update cursor graphics
      local stack = p.cursor_stack
      if stack and stack.valid_for_read and stack.valid then Graphics.sync_build_cursor_graphics(pindex) end
   end
)

--Handles a player joining into a game session.
function on_player_join(pindex)
   local playerList = {}
   for _, p in pairs(game.connected_players) do
      playerList["_" .. p.index] = p.name
   end

   --Reset the player building direction to match the vanilla behavior (Factorio 2.0)
   local vp = Viewpoint.get_viewpoint(pindex)
   vp:set_hand_direction(dirs.north)
end

EventManager.on_event(
   defines.events.on_player_joined_game,
   ---@param event EventData.on_player_joined_game
   function(event)
      if game.is_multiplayer() then on_player_join(event.player_index) end
   end
)

--Called for every player on every tick, to manage automatic walking and enforcing mouse pointer position syncs.
--Todo: create a new function for all mouse pointer related updates within this function
local function move_characters(event)
   for pindex, player in pairs(storage.players) do
      local router = UiRouter.get_router(pindex)
      local vp = Viewpoint.get_viewpoint(pindex)
      local cursor_pos = vp:get_cursor_pos()

      if VanillaMode.is_enabled(pindex) then
         player.player.game_view_settings.update_entity_selection = true
      elseif player.player.game_view_settings.update_entity_selection == false then
         --Force the mouse pointer to the mod cursor if there is an item in hand
         --(so that the game does not make a mess when you left click while the cursor is actually locked)
         local stack = game.get_player(pindex).cursor_stack
         if stack and stack.valid_for_read then
            if
               stack.prototype.place_result ~= nil
               or stack.prototype.place_as_tile_result ~= nil
               or stack.is_blueprint
               or stack.is_deconstruction_item
               or stack.is_upgrade_item
               or stack.prototype.type == "selection-tool"
               or stack.prototype.type == "copy-paste-tool"
            then
               --Force the pointer to the build preview location (and draw selection tool boxes)
               Graphics.sync_build_cursor_graphics(pindex)
            else
               --Force the pointer to the cursor location (if on screen)
               Mouse.move_mouse_pointer(vp:get_cursor_pos(), pindex)
            end
         end
      end
   end
end

--Called every tick.
function on_tick(event)
   MessageLists.try_translate_all_players()
   NoHover.on_tick()
   ScannerEntrypoint.on_tick()
   MovementHistory.update_all_players()
   Rulers.update_all_players()
   SonifierTickHandler.on_tick()
   BattleNotice.on_tick()
   ForceGhostEnabler.on_tick()

   move_characters(event)

   -- Check alerts via AudioCues
   AudioCues.check_cues(event.tick, players)

   -- Check bump detection every tick for all players
   for _, player in pairs(game.players) do
      if not player.connected then goto continue end
      if VanillaMode.is_enabled(player.index) then goto continue end

      BumpDetection.check_and_play_bump_alert_sound(player.index, event.tick)
      BumpDetection.check_and_play_stuck_alert_sound(player.index, event.tick)
      -- Process build lock for walking movement
      BuildLock.process_walking_movement(player.index)
      -- Process walking announcements (anchored cursor or entity detection)
      Walking.process_walking_announcements(player.index)
      -- Check for pending logistics announcements
      WorkerRobots.on_tick(player.index)
      -- Handle shooting (combat mode aim assist or shooting_selected with safe mode)
      Combat.on_tick(player.index)

      ::continue::
   end

   if event.tick % 15 == 0 then
      for pindex, player in pairs(players) do
         -- Other periodic checks can go here
      end
   elseif event.tick % 61 == 0 then
      -- Refresh search cache periodically (coprime with other updates)
      for pindex, player in pairs(players) do
         if player.connected then UiRouter.on_inventory_changed(pindex) end
      end
   elseif event.tick % 90 == 13 then
      for pindex, player in pairs(players) do
         --Fix running speed bug (toggle walk also fixes it)
         fix_walk(pindex)
      end
   elseif event.tick % 450 == 14 then
      --Run regular reminders every 7.5 seconds
      for pindex, player in pairs(players) do
         if game.get_player(pindex).ticks_to_respawn ~= nil then
            Speech.speak(
               pindex,
               { "fa.respawn-countdown", tostring(math.floor(game.get_player(pindex).ticks_to_respawn / 60)) }
            )
         end
         --Report the KK state, if any.
         KruiseKontrol.status_read(pindex, false)
      end
   end
end

EventManager.on_event(
   defines.events.on_tick,
   ---@param event EventData.on_tick
   function(event)
      on_tick(event)
      WorkQueue.on_tick()
      TestFramework.on_tick(event)
      HandMonitor.on_tick()
   end
)

--Makes the character face the cursor, choosing the nearest of 4 cardinal directions (north or south only).
function turn_to_cursor_direction_cardinal(pindex)
   local p = game.get_player(pindex)
   if not p.character then return end
   local vp = Viewpoint.get_viewpoint(pindex)
   local dir = FaUtils.get_direction_precise(vp:get_cursor_pos(), p.position)
   if dir == dirs.northwest or dir == dirs.north or dir == dirs.northeast then
      p.character.direction = dirs.north
   elseif dir == dirs.southwest or dir == dirs.south or dir == dirs.southeast then
      p.character.direction = dirs.south
   end
end

--Called when a player enters or exits a vehicle
EventManager.on_event(
   defines.events.on_player_driving_changed_state,
   ---@param event EventData.on_player_driving_changed_state
   ---@param pindex integer
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      BumpDetection.reset_bump_stats(pindex)
      MovementHistory.reset_and_increment_generation(pindex)
      game.get_player(pindex).clear_cursor()
      local p = game.get_player(pindex)
      local vehicle = p.vehicle
      -- Note: `driving` can be true with a nil `vehicle` (e.g. `LuaPlayer.land_on_planet()` toggles the driving
      -- state without attaching a real vehicle), so both must be checked before announcing an entered vehicle.
      if p.driving and vehicle then
         storage.players[pindex].last_vehicle = vehicle
         -- LuaPlayer.centered_on ("the entity being centered on in remote view", read-write) is what
         -- actually keeps the remote CAMERA following the vehicle continuously while driving - a plain
         -- one-off set_controller{position=...} at drive-start (vehicles-overview.lua) only snaps to
         -- where the vehicle WAS at that instant, then never moves again as it drives off. Reported
         -- live as "drove out of the audible/visible zone" - the user's own read was that whatever the
         -- remote view is centered/anchored on governs what's audible, independent of the physical
         -- body, which matches this property's documented purpose far better than the sound-model.lua
         -- reference-point fix alone did. Only meaningful in remote view - irrelevant (and presumably a
         -- no-op or error) while physically embodied.
         if p.controller_type == defines.controllers.remote then p.centered_on = vehicle end
         Speech.speak(pindex, { "fa.vehicle-entered", Localising.get_localised_name_with_fallback(vehicle) })
      elseif storage.players[pindex].last_vehicle ~= nil and storage.players[pindex].last_vehicle.valid then
         if p.controller_type == defines.controllers.remote and p.centered_on == storage.players[pindex].last_vehicle then
            p.centered_on = nil
         end
         Speech.speak(
            pindex,
            { "fa.vehicle-exited", Localising.get_localised_name_with_fallback(storage.players[pindex].last_vehicle) }
         )
         Teleport.teleport_to_closest(pindex, storage.players[pindex].last_vehicle.position, true, true)
         storage.players[pindex].last_vehicle = nil
      else
         storage.players[pindex].last_vehicle = nil
         Speech.speak(pindex, { "fa.driving-state-changed" })
      end
   end
)

--Called when a player changes surface
EventManager.on_event(
   defines.events.on_player_changed_surface,
   ---@param event EventData.on_player_changed_surface
   ---@param pindex integer
   function(event, pindex)
      MovementHistory.reset_and_increment_generation(pindex)
   end
)

--Save info about last item pickup and draw radius
EventManager.on_event(
   defines.events.on_picked_up_item,
   ---@param event EventData.on_picked_up_item
   ---@param pindex integer
   function(event, pindex)
      local p = game.get_player(pindex)
      --Draw the pickup range
      rendering.draw_circle({
         color = { 0.3, 1, 0.3 },
         radius = 1.25,
         width = 1,
         target = p.position,
         surface = p.surface,
         time_to_live = 10,
         draw_on_ground = true,
      })
      storage.players[pindex].last_pickup_tick = event.tick
      storage.players[pindex].last_item_picked_up = event.item_stack.name
   end
)

--Quickbar event handlers
local quickbar_get_events = {}
local quickbar_set_events = {}
local quickbar_page_events = {}
for i = 1, 10 do
   local key = tostring(i % 10)
   table.insert(quickbar_get_events, "fa-" .. key)
   table.insert(quickbar_set_events, "fa-c-" .. key)
   table.insert(quickbar_page_events, "fa-s-" .. key)
end

EventManager.on_event(quickbar_get_events, Quickbar.quickbar_get_handler)

EventManager.on_event(quickbar_set_events, Quickbar.quickbar_set_handler)

EventManager.on_event(quickbar_page_events, Quickbar.quickbar_page_handler)

function swap_weapon_forward(pindex, write_to_character)
   local p = game.get_player(pindex)
   if p.character == nil then
      return 0 --This is an intentionally selected error code
   end
   local gun_index = p.character.selected_gun_index
   if gun_index == nil then
      return 0 --This is an intentionally selected error code
   end
   local guns_inv = p.character.get_inventory(defines.inventory.character_guns)
   local ammo_inv = game.get_player(pindex).character.get_inventory(defines.inventory.character_ammo)

   --Simple index increment (not needed)
   gun_index = gun_index + 1
   if gun_index > 3 then gun_index = 1 end
   --game.print("start " .. gun_index)--
   assert(ammo_inv)

   --Increment again if the new index has no guns or no ammo
   local ammo_stack = ammo_inv[gun_index]
   local gun_stack = guns_inv[gun_index]
   local tries = 0
   while
      tries < 4
      and (
         ammo_stack == nil
         or not ammo_stack.valid_for_read
         or not ammo_stack.valid
         or gun_stack == nil
         or not gun_stack.valid_for_read
         or not gun_stack.valid
      )
   do
      gun_index = gun_index + 1
      if gun_index > 3 then gun_index = 1 end
      ammo_stack = ammo_inv[gun_index]
      gun_stack = guns_inv[gun_index]
      tries = tries + 1
   end

   if tries > 3 then
      --game.print("error " .. gun_index)--
      return -1
   end

   if write_to_character then p.character.selected_gun_index = gun_index end
   --game.print("end " .. gun_index)--
   return gun_index
end

function swap_weapon_backward(pindex, write_to_character)
   local p = game.get_player(pindex)
   if p.character == nil then
      return 0 --This is an intentionally selected error code
   end
   local gun_index = p.character.selected_gun_index
   if gun_index == nil then
      return 0 --This is an intentionally selected error code
   end
   local guns_inv = p.get_inventory(defines.inventory.character_guns)
   local ammo_inv = game.get_player(pindex).get_inventory(defines.inventory.character_ammo)

   --Simple index increment (not needed)
   gun_index = gun_index - 1
   if gun_index < 1 then gun_index = 3 end

   --Increment again if the new index has no guns or no ammo
   local ammo_stack = ammo_inv[gun_index]
   local gun_stack = guns_inv[gun_index]
   local tries = 0
   while
      tries < 4
      and (
         ammo_stack == nil
         or not ammo_stack.valid_for_read
         or not ammo_stack.valid
         or gun_stack == nil
         or not gun_stack.valid_for_read
         or not gun_stack.valid
      )
   do
      gun_index = gun_index - 1
      if gun_index < 1 then gun_index = 3 end
      ammo_stack = ammo_inv[gun_index]
      gun_stack = guns_inv[gun_index]
      tries = tries + 1
   end

   if tries > 3 then return -1 end

   if write_to_character then p.character.selected_gun_index = gun_index end
   return gun_index
end

function clicked_on_entity(ent, pindex)
   local p = game.get_player(pindex)
   if ent == nil then
      --No entity clicked
      p.selected = nil
      return
   elseif not ent.valid then
      --Invalid entity clicked
      p.print("Invalid entity clicked", { volume_modifier = 0 })
      if p.opened ~= nil and p.opened.object_name == "LuaEntity" and p.opened.valid then
         p.print("Opened " .. p.opened.name, { volume_modifier = 0 })
         ent = p.opened
         return
      else
         p.selected = nil
         return
      end
   end
   if p.character and p.character.unit_number == ent.unit_number then
      --Self click
      return
   end

   p.selected = ent
   if EntityUI.maybe_open_entity(pindex, ent) then
      -- UI opened successfully
   elseif ent.operable then
      if ent then Speech.speak(pindex, { "fa.no-menu-for", Localising.get_localised_name_with_fallback(ent) }) end
   elseif ent.type == "resource" and ent.name ~= "crude-oil" and ent.name ~= "uranium-ore" then
      if ent then
         Speech.speak(pindex, { "fa.no-menu-for-mineable", Localising.get_localised_name_with_fallback(ent) })
      end
   else
      if ent then Speech.speak(pindex, { "fa.no-menu-for", Localising.get_localised_name_with_fallback(ent) }) end
   end
end

--[[Manages inventory transfers that are bigger than one stack.
* Has checks and speech output!
]]

--When the item in hand changes
EventManager.on_event(
   defines.events.on_player_cursor_stack_changed,
   ---@param event EventData.on_player_cursor_stack_changed
   ---@param pindex integer
   function(event, pindex)
      -- Skip if suppressed (e.g., during rail building hand swaps)
      if not HandMonitor.is_enabled(pindex) then return end

      CursorChanges.on_cursor_stack_changed(event, pindex, read_hand)
      VirtualTrainDriving.on_cursor_stack_changed(event)

      -- Close UIs that are bound to hand contents
      UiRouter.on_hand_contents_changed(pindex)
   end
)

EventManager.on_event(
   defines.events.on_player_mined_item,
   ---@param event EventData.on_player_mined_item
   ---@param pindex integer
   function(event, pindex)
      --Play item pickup sound
      sounds.play_picked_up_item(pindex)
      sounds.play_close_inventory(pindex)
   end
)

function ensure_storage_structures_are_up_to_date()
   storage.forces = storage.forces or {}
   storage.players = storage.players or {}
   for pindex, player in pairs(game.players) do
      PlayerInit.initialize(player)
   end

   storage.entity_types = {}
   entity_types = storage.entity_types

   local types = {}

   for _, ent in pairs(prototypes.entity) do
      if
         types[ent.type] == nil
         and ent.weight == nil
         and (
            ent.burner_prototype ~= nil
            or ent.electric_energy_source_prototype ~= nil
            or ent.automated_ammo_count ~= nil
         )
      then
         types[ent.type] = true
      end
   end

   for i, type in pairs(types) do
      table.insert(entity_types, i)
   end
   table.insert(entity_types, "container")

   storage.production_types = {}
   production_types = storage.production_types

   -- TODO: reimplement production types. Seems only to be the warnings menu
   -- using it.

   storage.building_types = {}
   building_types = storage.building_types

   local ents = prototypes.entity
   local types = {}
   for i, ent in pairs(ents) do
      if ent.is_building then types[ent.type] = true end
   end
   types["transport-belt"] = nil
   for i, type in pairs(types) do
      table.insert(building_types, i)
   end
   table.insert(building_types, "character")
end

EventManager.on_load(function()
   entity_types = storage.entity_types
   production_types = storage.production_types
   building_types = storage.building_types
end)

EventManager.on_configuration_changed(ensure_storage_structures_are_up_to_date)

EventManager.on_init(function()
   ---@type any
   local freeplay = remote.interfaces["freeplay"]
   if freeplay and freeplay["set_skip_intro"] then remote.call("freeplay", "set_skip_intro", true) end
   ensure_storage_structures_are_up_to_date()
   TestFramework.on_init()
   AudioCues.on_init()
end)

EventManager.on_event(
   defines.events.on_cutscene_finished,
   ---@param event EventData.on_cutscene_finished
   ---@param pindex integer
   function(event, pindex)
      --Speech.speak(pindex, "Press TAB to continue")
   end
)

EventManager.on_event(
   defines.events.on_cutscene_started,
   ---@param event EventData.on_cutscene_started
   ---@param pindex integer
   function(event, pindex)
      --Speech.speak(pindex, "Press TAB to continue")
   end
)

EventManager.on_event(
   defines.events.on_player_created,
   ---@param event EventData.on_player_created
   function(event)
      PlayerInit.initialize(game.players[event.player_index])
      --if not game.is_multiplayer() then Speech.speak(pindex, "Press 'TAB' to continue") end
   end
)

EventManager.on_event(
   defines.events.on_gui_closed,
   ---@param event EventData.on_gui_closed
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      print(serpent.line(event, { nocode = true }))
      --Other resets - now executed unconditionally
      if event.element ~= nil then event.element.destroy() end
      router:close_ui()
   end
)

function fix_walk(pindex)
   local player = game.get_player(pindex)
   if not player.character then return end
   -- Always use normal walking speed
   player.character_running_speed_modifier = 0 -- 100% + 0 = 100%
end

EventManager.on_event(
   defines.events.on_gui_opened,
   ---@param event EventData.on_gui_opened
   ---@param pindex integer
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      local p = game.get_player(pindex)
   end
)

EventManager.on_event(
   defines.events.on_object_destroyed,
   ---@param event EventData.on_object_destroyed
   function(event) --DOES NOT HAVE THE KEY PLAYER_INDEX
      ScannerEntrypoint.on_entity_destroyed(event)

      -- Close UIs that are bound to this entity
      UiRouter.on_entity_destroyed(event.registration_number)
   end
)

--If a filter inserter is selected, the item in hand is set as its output filter item.
function set_inserter_filter_by_hand(pindex, ent)
   local stack = game.get_player(pindex).cursor_stack
   if ent.filter_slot_count == 0 then return "This inserter has no filters to set" end
   if stack == nil or stack.valid_for_read == false then
      --Delete last filter
      for i = ent.filter_slot_count, 1, -1 do
         local filt = Filters.get_filter_prototype(ent, i)
         if filt ~= nil then
            Filters.set_filter(ent, i, nil)
            return "Last filter cleared"
         end
      end
      return "All filters cleared"
   else
      --Add item in hand as next filter
      for i = 1, ent.filter_slot_count, 1 do
         local filt = Filters.get_filter_prototype(ent, i)
         if filt == nil then
            Filters.set_filter(ent, i, stack.name)
            if Filters.get_filter_prototype(ent, i) == stack.name then
               return "Added filter"
            else
               return "Filter setting failed"
            end
         end
      end
      return "All filters full"
   end
end

--Notifies battle sonifier when structures are damaged
--Character/vehicle damage sounds are handled by the tick-based health-bar sonifier
EventManager.on_event(
   defines.events.on_entity_damaged,
   ---@param event EventData.on_entity_damaged
   function(event)
      local ent = event.entity
      local tick = event.tick
      if ent == nil or not ent.valid then
         return
      elseif ent.name == "character" then
         -- Character damage is handled by tick-based health-bar sonifier
         return
      elseif Consts.VEHICLE_TYPES[ent.type] then
         -- Vehicle damage is handled by tick-based health-bar sonifier
         return
      elseif ent.get_health_ratio() == 1.0 then
         --Ignore alerts if an entity has full health despite being damaged
         return
      elseif tick < 3600 and tick > 600 then
         --No alerts for the first 10th to 60th seconds (because of the alert spam from spaceship fire damage)
         return
      end

      BattleNotice.notify(ent.force)
   end
)

--Notifies battle sonifier when structures are destroyed
EventManager.on_event(
   defines.events.on_entity_died,
   ---@param event EventData.on_entity_died
   function(event)
      local ent = event.entity
      if ent == nil or ent.name == "character" then return end
      BattleNotice.notify(ent.force)
   end
)

--Notify all players when a player character dies
EventManager.on_event(
   defines.events.on_player_died,
   ---@param event EventData.on_player_died
   ---@param pindex integer
   function(event, pindex)
      local p = game.get_player(pindex)
      local causer = event.cause
      local bodies = p.surface.find_entities_filtered({ name = "character-corpse" })
      local latest_body = nil
      local latest_death_tick = 0
      local name = p.name
      if name == nil then name = " " end
      --Find the most recent character corpse
      for i, body in ipairs(bodies) do
         if
            body.character_corpse_player_index == pindex and body.character_corpse_tick_of_death > latest_death_tick
         then
            latest_body = body
            latest_death_tick = latest_body.character_corpse_tick_of_death
         end
      end
      --Verify the latest death
      if event.tick - latest_death_tick > 120 then latest_body = nil end
      --Generate death message
      local result = "Player " .. name
      if causer == nil or not causer.valid then
         result = result .. " died "
      elseif causer.name == "character" and causer.player ~= nil and causer.player.valid then
         local other_name = causer.player.name
         if other_name == nil then other_name = "" end
         result = result .. " was killed by player " .. other_name
      else
         result = result .. " was killed by " .. causer.name
      end
      if latest_body ~= nil and latest_body.valid then
         result = result
            .. " at "
            .. math.floor(0.5 + latest_body.position.x)
            .. ", "
            .. math.floor(0.5 + latest_body.position.y)
            .. "."
      end
      --Notify all players
      for pindex, player in pairs(players) do
         storage.players[pindex].last_damage_alert_tick = event.tick
         Speech.speak(pindex, result)
         game.get_player(pindex).print(result) --**laterdo unique sound, for now use console sound
      end
   end
)

EventManager.on_event(
   defines.events.on_player_display_resolution_changed,
   ---@param event EventData.on_player_display_resolution_changed
   ---@param pindex integer
   function(event, pindex)
      local new_res = game.get_player(pindex).display_resolution
      if players and storage.players[pindex] then storage.players[pindex].display_resolution = new_res end
      game
         .get_player(pindex)
         .print("Display resolution changed: " .. new_res.width .. " x " .. new_res.height, { volume_modifier = 0 })
   end
)

EventManager.on_event(
   defines.events.on_player_display_scale_changed,
   ---@param event EventData.on_player_display_scale_changed
   ---@param pindex integer
   function(event, pindex)
      local new_sc = game.get_player(pindex).display_scale
      if players and storage.players[pindex] then storage.players[pindex].display_resolution = new_sc end
      game.get_player(pindex).print("Display scale changed: " .. new_sc, { volume_modifier = 0 })
   end
)

EventManager.on_event(defines.events.on_string_translated, Localising.handler)

EventManager.on_event(
   defines.events.on_player_respawned,
   ---@param event EventData.on_player_respawned
   ---@param pindex integer
   function(event, pindex)
      local vp = Viewpoint.get_viewpoint(pindex)
      local position = game.get_player(pindex).position
      vp:set_cursor_pos({ x = position.x, y = position.y })
      MovementHistory.reset_and_increment_generation(pindex)
   end
)

EventManager.on_event(
   defines.events.on_player_main_inventory_changed,
   ---@param event EventData.on_player_main_inventory_changed
   ---@param pindex integer
   function(event, pindex)
      -- Refresh search cache if UI is open and search is active
      UiRouter.on_inventory_changed(pindex)
   end
)

--If the player has unexpected lateral movement while smooth running in a cardinal direction, like from bumping into an entity or being at the edge of water, play a sound.

function all_ents_are_walkable(pos)
   local ents = game.surfaces[1].find_entities_filtered({
      position = FaUtils.center_of_tile(pos),
      radius = 0.4,
      invert = true,
      type = Consts.ENT_TYPES_YOU_CAN_WALK_OVER,
   })
   for i, ent in ipairs(ents) do
      return false
   end
   return true
end

EventManager.on_event(
   defines.events.on_console_chat,
   ---@param event EventData.on_console_chat
   function(event)
      local speaker = game.get_player(event.player_index).name
      if speaker == nil or speaker == "" then speaker = "Player" end
      local message = event.message
      for pindex, player in pairs(players) do
         Speech.speak(pindex, { "fa.chat-message", speaker, message })
      end
   end
)

EventManager.on_event(
   defines.events.on_console_command,
   ---@param event EventData.on_console_command
   function(event)
      -- For our own commands, we handle the speaking and must not read here.
      if FaCommands.COMMANDS[event.command] then return end

      local speaker = game.get_player(event.player_index).name
      if speaker == nil or speaker == "" then speaker = "Player" end
      for pindex, player in pairs(players) do
         Speech.speak(pindex, { "fa.command-message", speaker, event.command, event.parameters })
      end
   end
)

function general_mod_menu_up(pindex, menu, lower_limit_in) --todo*** use
   local lower_limit = lower_limit_in or 0
   menu.index = menu.index - 1
   if menu.index < lower_limit then
      menu.index = lower_limit
      sounds.play_ui_edge(pindex)
   else
      --Play sound
      sounds.play_menu_move(pindex)
   end
end

function general_mod_menu_down(pindex, menu, upper_limit)
   menu.index = menu.index + 1
   if menu.index > upper_limit then
      menu.index = upper_limit
      sounds.play_ui_edge(pindex)
   else
      --Play sound
      sounds.play_menu_move(pindex)
   end
end

EventManager.on_event(
   defines.events.on_surface_created,
   ---@param event EventData.on_surface_created
   function(event)
      ScannerEntrypoint.on_new_surface(game.get_surface(event.surface_index))
   end
)

EventManager.on_event(
   defines.events.on_surface_deleted,
   ---@param event EventData.on_surface_deleted
   function(event)
      ScannerEntrypoint.on_surface_delete(event.surface_index)
   end
)

-- Scanner: entity creation events (most use "entity" field)
EventManager.on_event({
   defines.events.on_built_entity,
   defines.events.on_robot_built_entity,
   defines.events.script_raised_built,
   defines.events.on_entity_spawned,
   defines.events.on_biter_base_built,
}, ScannerEntrypoint.build_new_entity_handler("entity"))

-- Scanner: entity creation events with different field names
EventManager.on_event(defines.events.on_entity_cloned, ScannerEntrypoint.build_new_entity_handler("destination"))

-- Scanner: Space Age entity creation events
if script.feature_flags.space_travel then
   EventManager.on_event(
      defines.events.on_space_platform_built_entity,
      ScannerEntrypoint.build_new_entity_handler("entity")
   )
   EventManager.on_event(defines.events.on_segment_entity_created, ScannerEntrypoint.build_new_entity_handler("entity"))
   EventManager.on_event(defines.events.on_tower_planted_seed, ScannerEntrypoint.build_new_entity_handler("plant"))
   EventManager.on_event(
      defines.events.on_cargo_pod_delivered_cargo,
      ScannerEntrypoint.build_new_entity_handler("spawned_container", true)
   )
end

EventManager.on_event(defines.events.on_research_finished, Research.on_research_finished)
-- New input event definitions

--Moves the cursor, and conducts an area scan for larger cursors. If the player is in a slow moving vehicle, it is stopped.
---Move a large cursor by n tiles and read the area
---@param pindex number
---@param direction defines.direction
---@param tiles number Number of tiles to move
---@param prefix_text string? Optional text to prepend to the reading
local function move_large_cursor_by(pindex, direction, tiles, prefix_text)
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_pos = vp:get_cursor_pos()
   local cursor_size = vp:get_cursor_size()
   local p = game.get_player(pindex)

   cursor_pos = FaUtils.offset_position_legacy(cursor_pos, direction, tiles)
   vp:set_cursor_pos(cursor_pos)

   local scan_left_top = {
      x = math.floor(cursor_pos.x) - cursor_size,
      y = math.floor(cursor_pos.y) - cursor_size,
   }
   local scan_right_bottom = {
      x = math.floor(cursor_pos.x) + cursor_size + 1,
      y = math.floor(cursor_pos.y) + cursor_size + 1,
   }
   local scan_summary = FaInfo.area_scan_summary_info(pindex, scan_left_top, scan_right_bottom)
   if prefix_text and prefix_text ~= "" then scan_summary = prefix_text .. scan_summary end
   Graphics.draw_large_cursor(scan_left_top, scan_right_bottom, pindex)
   Speech.speak(pindex, scan_summary)

   -- In remote view, this UI feedback click is deliberately played WITHOUT a
   -- position (see sounds.play_building_placement: omitting position routes
   -- through play_sound_internal, i.e. an ordinary, always-audible
   -- LuaPlayer::play_sound call). A positioned sound is only played if its
   -- location is charted for the player (LuaPlayer::play_sound docs) - fine
   -- when position = p.position, since a player's own square is essentially
   -- always charted, but the remote-view cursor can and does roam into
   -- not-yet-charted territory (freshly generated platform tiles, newly
   -- entered planet regions, etc.), where a positioned click would silently
   -- fail to play. This UI cue isn't meant to be spatial audio anyway, so
   -- dropping position here makes it reliable instead of "random".
   if storage.players[pindex].remote_view then
      sounds.play_building_placement(p.index)
   else
      p.play_sound({
         path = "Close-Inventory-Sound",
         position = p.position,
         volume_modifier = 0.75,
      })
   end
end

local function cursor_mode_move(direction, pindex, single_only)
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_pos = vp:get_cursor_pos()
   local cursor_size = vp:get_cursor_size()
   local diff = cursor_size * 2 + 1
   if single_only then diff = 1 end
   local p = game.get_player(pindex)

   if cursor_size == 0 then
      -- Cursor size 0 ("1 by 1"): Read tile
      cursor_pos = FaUtils.offset_position_legacy(cursor_pos, direction, diff)
      vp:set_cursor_pos_continuous(cursor_pos, direction)

      EntitySelection.reset_entity_index(pindex)
      read_tile_with_preview_info(pindex)

      --Update drawn cursor
      local stack = p.cursor_stack
      if
         stack
         and stack.valid_for_read
         and stack.valid
         and (stack.prototype.place_result ~= nil or stack.is_blueprint)
      then
         Graphics.sync_build_cursor_graphics(pindex)
      end

      --Update cursor highlight
      local ent = EntitySelection.get_first_ent_at_tile(pindex)
      if ent and ent.valid then
         Graphics.draw_cursor_highlight(pindex, ent, nil)
      else
         Graphics.draw_cursor_highlight(pindex, nil, nil)
      end

      if storage.players[pindex].remote_view then
         sounds.play_building_placement(p.index)
      else
         p.play_sound({
            path = "Close-Inventory-Sound",
            position = p.position,
            volume_modifier = 0.75,
         })
      end
   else
      -- Use continuous movement tracking for WASD movements
      vp:set_cursor_pos_continuous(cursor_pos, direction)
      move_large_cursor_by(pindex, direction, diff)
   end
end

--Chooses the function to call after a movement keypress, according to the current mode.
local function move_key(direction, event, force_single_tile)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local router = UiRouter.get_router(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)

   -- Combat mode: Set aim direction instead of moving cursor
   if Combat.is_combat_mode(pindex) then
      AimAssist.set_direction(pindex, direction)
      return
   end

   -- Cursor mode: Move cursor on map
   cursor_mode_move(direction, pindex, force_single_tile)
end

EventManager.on_event(
   "fa-w",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      move_key(defines.direction.north, event)
   end
)

EventManager.on_event(
   "fa-a",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      move_key(defines.direction.west, event)
   end
)

EventManager.on_event(
   "fa-s",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      move_key(defines.direction.south, event)
   end
)

EventManager.on_event(
   "fa-d",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      move_key(defines.direction.east, event)
   end
)

--Moves the cursor in the same direction multiple times until the reported entity changes. Change includes: new entity name or new direction for entites with the same name, or changing between nil and ent. Returns move count.
local function cursor_skip_iteration(pindex, direction, iteration_limit)
   local p = game.get_player(pindex)
   local start = nil
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_pos = vp:get_cursor_pos()
   -- [CURSOR-SKIP-GENERIC] Was "start_tile_is_water" / FaUtils.tile_is_water
   -- alone; generalized to a terrain *category* (nil, "water", or "soil") so
   -- this same tunnel-across-a-region mechanism also covers Gleba's crop
   -- soil tiles, not just water. See FaUtils.get_cursor_skip_terrain_category
   -- for the full rationale and the list of tile kinds each category covers.
   local start_terrain_category = FaUtils.get_cursor_skip_terrain_category(p.surface, cursor_pos)
   local start_tile_is_ruler_aligned = Rulers.is_any_ruler_aligned(pindex, cursor_pos)
   local current = nil
   local limit = iteration_limit or 100
   local moved = 1
   local comment = ""

   -- Returns a new value for current or nil, ignoring a list of entities.
   --
   ---@returns LuaEntity?
   local function compute_current()
      EntitySelection.reset_entity_index(pindex)
      for ent in EntitySelection.iterate_selected_ents(pindex) do
         local bad = ent.type == "logistic-robot"
            or ent.type == "construction-robot"
            or ent.type == "combat-robot"
            or ent.type == "corpse"
         if not bad then return ent end
      end

      return nil
   end

   -- [CURSOR-SKIP-GHOST-FIX] For a ghost entity, `.name`/`.type` are ALWAYS
   -- the literal placeholder prototype ("entity-ghost"), never the identity
   -- of whatever it is a ghost of - that real identity lives in
   -- `.ghost_name`/`.ghost_type` instead (see LuaEntity docs, Subclasses:
   -- Ghost). The name-equality check below used to compare raw `.name`
   -- directly, so it treated EVERY ghost as interchangeable with every
   -- other ghost regardless of what each one was actually a ghost of - a
   -- row of a furnace-ghost then an assembler-ghost (both facing the same
   -- direction) would silently skip through as if they were "the same
   -- entity, keep going", instead of stopping cursor-skip at the boundary
   -- between them. This helper returns a stable identity key for the
   -- purposes of that comparison: the real (ghosted) prototype name for a
   -- ghost, tagged with a "ghost:" prefix so a ghost is still never
   -- considered equal to a REAL, already-built entity of the same
   -- prototype (that distinction already worked correctly before this fix
   -- and must keep working after it).
   --
   -- A TILE ghost (a planned foundation/landfill/concrete tile, `.type ==
   -- "tile-ghost"`) has the exact same placeholder problem as an entity
   -- ghost - `.name` is always the literal `"tile-ghost"`, and the real
   -- planned tile name is in `.ghost_name` too (confirmed against this
   -- mod's own existing ghost-handling code, which already treats
   -- `"entity-ghost"` and `"tile-ghost"` as the same family in
   -- `scripts/entity-selection.lua` and `scripts/cursor-changes.lua`).
   -- This was missed in the first pass of this fix - a run of, say,
   -- `space-platform-foundation` tile-ghosts next to `landfill`
   -- tile-ghosts would have kept the same bug the entity-ghost case had.
   local function entity_skip_identity(ent)
      if ent.type == "entity-ghost" or ent.type == "tile-ghost" then return "ghost:" .. ent.ghost_name end
      return ent.name
   end

   start = compute_current()

   --For pipes to ground, apply a special case where you jump to the underground neighbour
   if start ~= nil and start.valid and start.type == "pipe-to-ground" then
      -- `entity.fluidbox.get_pipe_connections(n)` (the old code here) is a
      -- STALE API pattern - in 2.1 it can throw "LuaEntity doesn't contain
      -- key fluidbox" even for a perfectly normal, properly placed vanilla
      -- pipe-to-ground, not just some rare/modded edge case. The correct,
      -- current (2.1) API is the top-level entity method
      -- `get_fluid_box_pipe_connections(index)`, confirmed against the live
      -- lua-api.factorio.com docs (the local llm-docs mirror still only
      -- documents the old style): it returns the exact same per-connection
      -- data (connection_type / target / target_position) and is
      -- documented as always safely returning nil rather than throwing for
      -- entities that don't support it - no pcall should even be needed,
      -- but it's kept as cheap extra insurance.
      --
      -- [PIPE-SKIP-FIX] The first attempt at this fix (in the block just
      -- below this comment, now replaced) used `con.target_position` - a
      -- PipeConnection field documented as "the absolute position of the
      -- connection's intended target" - to both measure the jump distance
      -- and to move the cursor to. In testing this did not land the cursor
      -- on the paired underground entity, so the skip appeared to do
      -- nothing. Checked this mod's own git history for a previously
      -- working implementation: commit 2aeb947d ("Fix skipping pipe to
      -- ground", by the mod's original author) is an ancestor of this
      -- branch's history and fixed this exact mechanism once already, but
      -- an unrelated later branch merge silently reverted control.lua's
      -- pipe-to-ground block back to the pre-2.1 API (the same merge that
      -- caused the "doesn't contain key fluidbox" crash this block already
      -- fixed) - so that working fix was lost along with the API names,
      -- and my crash-only fix reinvented a different, non-working
      -- replacement for the reverted line instead of restoring it.
      --
      -- The verified-working pattern: don't use `con.target_position` at
      -- all. Query the TARGET entity's own fluidbox connections and use
      -- ITS first connection's position instead. Per commit 6500afbe's own
      -- migration notes, `PipeConnection.target` changed type in 2.1 from a
      -- LuaFluidBox to the connected LuaEntity directly, so the pre-2.1
      -- `con.target.get_pipe_connections(1)[1].position` (a method on the
      -- old LuaFluidBox-typed target) becomes
      -- `con.target.get_fluid_box_pipe_connections(1)[1].position` (the
      -- same renamed entity method as `start`'s own connections list just
      -- above, just called on the far end too) - restoring exactly what
      -- commit 2aeb947d already proved works.
      local jumped = false
      local ok, connections = pcall(function()
         return start.get_fluid_box_pipe_connections(1)
      end)
      if ok and connections then
         for i, con in ipairs(connections) do
            if con.target ~= nil and con.connection_type == "underground" then
               local ok2, target_connection_pos = pcall(function()
                  return con.target.get_fluid_box_pipe_connections(1)[1].position
               end)
               if ok2 and target_connection_pos then
                  local dist = math.ceil(util.distance(start.position, target_connection_pos))
                  local dir_neighbor = FaUtils.get_direction_biased(target_connection_pos, start.position)
                  if dir_neighbor == direction then
                     vp:set_cursor_pos(target_connection_pos)
                     EntitySelection.reset_entity_index(pindex)
                     current = EntitySelection.get_first_ent_at_tile(pindex)
                     jumped = true
                     return dist
                  end
               end
            end
         end
      end

      -- Last-resort fallback if even the correct API above somehow doesn't
      -- give us anything (e.g. a genuinely unusual modded pipe-to-ground):
      -- `LuaEntity.neighbours` is documented as always safe for
      -- pipe-connectable entities (Dictionary/Array[Array]/single LuaEntity,
      -- never throws), but only gives raw connected entities, not
      -- connection-type metadata. Approximate "the underground link"
      -- as any neighbour more than 1 tile away in the facing direction -
      -- a normal surface pipe connection is always exactly 1 tile away,
      -- so anything farther must be the automatic underground pairing.
      if not jumped then
         local ok2, raw_neighbours = pcall(function()
            return start.neighbours
         end)
         if ok2 and type(raw_neighbours) == "table" then
            local candidates = raw_neighbours[1]
            if type(candidates) ~= "table" then candidates = raw_neighbours end
            for _, neighbour in pairs(candidates) do
               if type(neighbour) == "table" and neighbour.valid then
                  local dist = math.ceil(util.distance(start.position, neighbour.position))
                  local dir_neighbor = FaUtils.get_direction_biased(neighbour.position, start.position)
                  if dist > 1 and dir_neighbor == direction then
                     vp:set_cursor_pos(neighbour.position)
                     EntitySelection.reset_entity_index(pindex)
                     current = EntitySelection.get_first_ent_at_tile(pindex)
                     return dist
                  end
               end
            end
         end
      end
      --For underground belts, apply a special case where you jump to the underground neighbour
   elseif start ~= nil and start.valid and start.type == "underground-belt" then
      -- LuaEntity has no plain "neighbours" field for underground belts (that
      -- caused a crash: "LuaEntity doesn't contain key neighbours") - the
      -- correct field is "underground_belt_neighbour" (singular), which can
      -- be nil if this underground belt isn't currently paired with another.
      local neighbour = start.underground_belt_neighbour
      if neighbour then
         local other_end = neighbour
         local dist = math.ceil(util.distance(start.position, other_end.position))
         local dir_neighbor = FaUtils.get_direction_biased(other_end.position, start.position)
         if dir_neighbor == direction then
            vp:set_cursor_pos(other_end.position)
            EntitySelection.reset_entity_index(pindex)
            current = EntitySelection.get_first_ent_at_tile(pindex)
            return dist
         end
      end
      --For a start tile in a special terrain category (water-like or Gleba
      --soil), find the first tile that has left that category
   elseif start_terrain_category ~= nil then
      local selected_terrain_category = nil
      --Iterate first_tile
      cursor_pos = FaUtils.offset_position_legacy(cursor_pos, direction, 1)
      vp:set_cursor_pos(cursor_pos)
      selected_terrain_category = FaUtils.get_cursor_skip_terrain_category(p.surface, cursor_pos)

      --Run checks and skip when needed
      while moved < limit do
         if selected_terrain_category ~= start_terrain_category then
            --Left the starting terrain category (e.g. water tile -> non-water
            --tile, or Gleba soil -> non-soil tile)
            return moved
         else
            --For audio rulers, stop if crossing into or out of alignment with any rulers
            local current_tile_is_ruler_aligned = Rulers.is_any_ruler_aligned(pindex, cursor_pos)
            if start_tile_is_ruler_aligned ~= current_tile_is_ruler_aligned then
               return moved
               --Also for rulers, stop if at the definiton point of any ruler
            elseif Rulers.is_at_any_ruler_definition(pindex, cursor_pos) then
               return moved
            end
            --Iterate again
            cursor_pos = FaUtils.offset_position_legacy(cursor_pos, direction, 1)
            vp:set_cursor_pos(cursor_pos)
            selected_terrain_category = FaUtils.get_cursor_skip_terrain_category(p.surface, cursor_pos)
            moved = moved + 1
         end
      end
      --Reached limit
      return -1
   end
   --Iterate first tile
   cursor_pos = FaUtils.offset_position_legacy(cursor_pos, direction, 1)
   vp:set_cursor_pos(cursor_pos)

   current = compute_current()

   --Run checks and skip when needed
   while moved < limit do
      --For audio rulers, stop if crossing into or out of alignment with any rulers
      local current_tile_is_ruler_aligned = Rulers.is_any_ruler_aligned(pindex, cursor_pos)
      if start_tile_is_ruler_aligned ~= current_tile_is_ruler_aligned then
         return moved
         --Also for rulers, stop if at the definiton point of any ruler
      elseif Rulers.is_at_any_ruler_definition(pindex, cursor_pos) then
         return moved
      end
      --Check the current entity or tile against the starting one
      if current == nil then
         if start == nil then
            --Both are nil: check if the tile entered a special terrain
            --category (water-like or Gleba soil), else skip. [CURSOR-SKIP-GENERIC]
            --Was a water-only check; generalized the same way as the branch
            --above so walking onto soil from plain ground also stops here.
            local selected_terrain_category = FaUtils.get_cursor_skip_terrain_category(p.surface, cursor_pos)
            if selected_terrain_category ~= nil then
               --Plain ground -> special terrain category found
               return moved
            else
               --skip
            end
         else
            --Valid start ent -> nil found
            return moved
         end
      else
         if start == nil or start.valid == false then
            --Nil entity start -> valid entity found
            return moved
         else
            --Both are valid
            if start.unit_number == current.unit_number and current.type ~= "resource" then
               --They are the same ent: skip
            else
               --They are different ents OR they are resource ents (which can have the same unit number despite being different ents)
               if entity_skip_identity(start) ~= entity_skip_identity(current) then
                  --They have different (effective) identities: return.
                  --[CURSOR-SKIP-GHOST-FIX] Uses entity_skip_identity, not
                  --raw .name, so two ghosts of different real prototypes
                  --are correctly treated as different here.
                  --p.print("RET 1, start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
                  return moved
               else
                  --They have the same name
                  if current.supports_direction == false then
                     --They both do not support direction: skip
                  else
                     --They support direction
                     if current.direction ~= start.direction then
                        --They have different directions: return
                        --p.print("RET 2, start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
                        return moved
                     else
                        --They have same direction: skip

                        --Exception for transport belts facing the same direction: Return if neighbor counts or shapes are different
                        if start.type == "transport-belt" then
                           local start_input_neighbors = #start.belt_neighbours["inputs"]
                           local start_output_neighbors = #start.belt_neighbours["outputs"]
                           local current_input_neighbors = #current.belt_neighbours["inputs"]
                           local current_output_neighbors = #current.belt_neighbours["outputs"]
                           if
                              start_input_neighbors ~= current_input_neighbors
                              or start_output_neighbors ~= current_output_neighbors
                              or start.belt_shape ~= current.belt_shape
                           then
                              --p.print("RET 3, start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
                              return moved
                           end
                        end
                     end
                  end
               end
            end
            --p.print("start: " .. start.name .. ", current: " .. current.name .. ", comment:" .. comment)--
         end
      end
      --Skip case: Move 1 more tile
      cursor_pos = FaUtils.offset_position_legacy(cursor_pos, direction, 1)
      vp:set_cursor_pos(cursor_pos)
      moved = moved + 1
      current = compute_current()
   end
   --Reached limit
   return -1
end

--Shift the cursor by the size of the preview in hand or otherwise by the size of the cursor.
local function apply_skip_by_preview_size(pindex, direction)
   local p = game.get_player(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_pos = vp:get_cursor_pos()

   --Check the moved count against the dimensions of the preview in hand
   local stack = p.cursor_stack
   local width, height = BuildDimensions.get_stack_build_dimensions(stack, vp:get_hand_direction())

   --Default to cursor size if not something else
   if not width or not height or (width + height <= 2) then
      local shift = (vp:get_cursor_size() * 2 + 1)
      vp:set_cursor_pos(FaUtils.offset_position_legacy(cursor_pos, direction, shift))
      return shift
   end

   --For entities/blueprints larger than 1x1, move by the appropriate dimension
   local shift
   if direction == dirs.east or direction == dirs.west then
      shift = width
   elseif direction == dirs.north or direction == dirs.south then
      shift = height
   end

   vp:set_cursor_pos(FaUtils.offset_position_legacy(cursor_pos, direction, shift))
   return shift
end

--Runs the cursor skip actions and reads out results
local function cursor_skip(pindex, direction, iteration_limit, use_preview_size)
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_size = vp:get_cursor_size()
   local p = game.get_player(pindex)
   local limit = iteration_limit or 100

   --Special case: larger cursors move by 1 tile with ctrl+WASD
   if use_preview_size and cursor_size > 0 then
      move_large_cursor_by(pindex, direction, 1)
      return
   end

   local cursor_pos = vp:get_cursor_pos()
   local result = ""
   local moved_count = 0
   if use_preview_size == true then
      moved_count = apply_skip_by_preview_size(pindex, direction)
      result = "Skipped by preview size " .. moved_count .. ", "
   else
      moved_count = cursor_skip_iteration(pindex, direction, limit)
      result = "Skipped "
   end

   cursor_pos = vp:get_cursor_pos()

   if use_preview_size then
      --Rolling always plays the regular moving sound
      if storage.players[pindex].remote_view then
         sounds.play_building_placement(p.index)
      else
         p.play_sound({
            path = "Close-Inventory-Sound",
            position = p.position,
            volume_modifier = 1,
         })
      end
   elseif moved_count < 0 then
      --No change found within the limit
      result = result .. limit .. " tiles without a change, "
      if storage.players[pindex].remote_view then
         sounds.play_sound(p.index, { path = "inventory-wrap-around", volume_modifier = 1 })
      else
         p.play_sound({
            path = "inventory-wrap-around",
            position = p.position,
            volume_modifier = 1,
         })
      end
   elseif moved_count == 1 then
      result = ""
      if storage.players[pindex].remote_view then
         sounds.play_building_placement(p.index)
      else
         p.play_sound({
            path = "Close-Inventory-Sound",
            position = p.position,
            volume_modifier = 1,
         })
      end
   elseif moved_count > 1 then
      --Change found, with more than 1 tile moved
      result = result .. moved_count .. " tiles, "
      if storage.players[pindex].remote_view then
         sounds.play_sound(p.index, { path = "inventory-wrap-around", volume_modifier = 1 })
      else
         p.play_sound({
            path = "inventory-wrap-around",
            position = p.position,
            volume_modifier = 1,
         })
      end
   end

   --Read the tile reached
   read_tile_with_preview_info(pindex, result)
   Graphics.sync_build_cursor_graphics(pindex)
end

---Handle shift+direction key press
---In combat mode with capsule: use capsule in direction
---Outside combat mode: cursor skip
---@param pindex integer
---@param direction defines.direction
local function handle_shift_direction(pindex, direction)
   -- In combat mode, shift+wasd throws capsules if one is held
   if Combat.is_combat_mode(pindex) then
      if Capsules.get_held_capsule_data(pindex) then
         Capsules.use_capsule_in_direction(pindex, direction, false)
      else
         Speech.speak(pindex, { "fa.no-capsule-in-hand" })
      end
      return
   end
   -- Outside combat mode, do normal cursor skip
   cursor_skip(pindex, direction)
end

EventManager.on_event(
   "fa-s-w",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      handle_shift_direction(pindex, defines.direction.north)
   end
)

EventManager.on_event(
   "fa-s-a",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      handle_shift_direction(pindex, defines.direction.west)
   end
)

EventManager.on_event(
   "fa-s-s",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      handle_shift_direction(pindex, defines.direction.south)
   end
)

EventManager.on_event(
   "fa-s-d",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      handle_shift_direction(pindex, defines.direction.east)
   end
)

EventManager.on_event(
   "fa-c-w",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      cursor_skip(pindex, defines.direction.north, 1000, true)
   end
)

EventManager.on_event(
   "fa-c-a",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      cursor_skip(pindex, defines.direction.west, 1000, true)
   end
)

EventManager.on_event(
   "fa-c-s",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      cursor_skip(pindex, defines.direction.south, 1000, true)
   end
)

EventManager.on_event(
   "fa-c-d",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      cursor_skip(pindex, defines.direction.east, 1000, true)
   end
)

-- Ctrl+shift+wasd force-fires capsules even in safe mode
EventManager.on_event(
   "fa-cs-w",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if Combat.is_combat_mode(pindex) and Capsules.get_held_capsule_data(pindex) then
         Capsules.use_capsule_in_direction(pindex, defines.direction.north, true)
      end
   end
)

EventManager.on_event(
   "fa-cs-a",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if Combat.is_combat_mode(pindex) and Capsules.get_held_capsule_data(pindex) then
         Capsules.use_capsule_in_direction(pindex, defines.direction.west, true)
      end
   end
)

EventManager.on_event(
   "fa-cs-s",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if Combat.is_combat_mode(pindex) and Capsules.get_held_capsule_data(pindex) then
         Capsules.use_capsule_in_direction(pindex, defines.direction.south, true)
      end
   end
)

EventManager.on_event(
   "fa-cs-d",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if Combat.is_combat_mode(pindex) and Capsules.get_held_capsule_data(pindex) then
         Capsules.use_capsule_in_direction(pindex, defines.direction.east, true)
      end
   end
)

EventManager.on_event(
   "fa-s-up",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      BuildingTools.nudge_key(defines.direction.north, event)
   end
)

EventManager.on_event(
   "fa-s-left",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      BuildingTools.nudge_key(defines.direction.west, event)
   end
)

EventManager.on_event(
   "fa-s-down",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      BuildingTools.nudge_key(defines.direction.south, event)
   end
)

EventManager.on_event(
   "fa-s-right",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      BuildingTools.nudge_key(defines.direction.east, event)
   end
)

---@param event EventData.CustomInputEvent
---@param direction defines.direction
---@param name string
local function nudge_self(event, direction, name)
   local pindex = event.player_index
   local p = game.get_player(pindex)

   if not p.character then
      Speech.speak(pindex, { "fa.nudge-failed" })
      return
   end

   if p.vehicle then
      Speech.speak(pindex, { "fa.nudged-self", name })
      return
   end

   local new_pos = FaUtils.center_of_tile(FaUtils.offset_position_legacy(p.position, direction, 1))

   if not p.surface.can_place_entity({ name = "character", position = new_pos }) then
      Speech.speak(pindex, { "fa.tile-occupied" })
      return
   end

   if not p.teleport(new_pos) then
      Speech.speak(pindex, { "fa.teleport-failed" })
      return
   end

   local stack = p.cursor_stack
   if stack and stack.valid_for_read and stack.valid and stack.prototype.place_result then
      Graphics.sync_build_cursor_graphics(pindex)
   end

   local ent = EntitySelection.get_first_ent_at_tile(pindex)
   if ent and ent.valid then
      Graphics.draw_cursor_highlight(pindex, ent, nil)
   else
      Graphics.draw_cursor_highlight(pindex, nil, nil)
   end

   Speech.speak(pindex, { "fa.nudged-self", name })
end

EventManager.on_event(
   "fa-c-up",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      nudge_self(event, defines.direction.north, "north")
   end
)

EventManager.on_event(
   "fa-c-left",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      nudge_self(event, defines.direction.west, "west")
   end
)

EventManager.on_event(
   "fa-c-down",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      nudge_self(event, defines.direction.south, "south")
   end
)

EventManager.on_event(
   "fa-c-right",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      nudge_self(event, defines.direction.east, "east")
   end
)

--Read the current co-ordinates of the cursor on the map or in a menu. For crafting recipe and technology menus, it reads the ingredients / requirements instead.
--Todo: split this function by menu.
local function read_coords(pindex, start_phrase)
   local vp = Viewpoint.get_viewpoint(pindex)

   start_phrase = start_phrase or ""
   local result = start_phrase
   local ent = storage.players[pindex].building.ent
   local offset = 0

   local router = UiRouter.get_router(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)

   local position = vp:get_cursor_pos()
   local marked_pos = { x = position.x, y = position.y }

   -- Territory status (Vulcanus demolishers): a live point-query, not tied to whether the
   -- scanner has discovered this spot yet. Silent everywhere the position isn't part of
   -- any territory at all (i.e. everywhere off Vulcanus, and open ground on Vulcanus with
   -- no generated territory) - but explicit ("Free "/"Guarded ") whenever it IS part of
   -- one, in either state, since this is exactly the "can I safely build/mine here"
   -- signal the maintainer asked for, not something that should ever go unsaid.
   -- Plain hardcoded strings, not locale keys: start_phrase is built via raw Lua string
   -- concatenation throughout this function (see the existing "Cursor returned " caller
   -- below), which only works with plain strings, not LocalisedString tables - matching
   -- the function's existing, pre-established convention rather than introducing a second
   -- one.
   local territory_status = Territory.get_status_at(game.get_player(pindex).surface, marked_pos)
   if territory_status == "active" then
      start_phrase = start_phrase .. "Guarded "
   elseif territory_status == "abandoned" then
      start_phrase = start_phrase .. "Free "
   end

   -- Fulgora lightning-attractor protection status: the same shape of check
   -- as the territory status just above (a live point-query against
   -- whatever's cached, silent unless there's something to say) but for "is
   -- this exact spot within an attractor's protection circle", from the
   -- grid built at the last End refresh (see lightning-zones.lua and the
   -- changelog section "Fulgora lightning-attractor coverage grid").
   --
   -- This is THE actual "K" key (data/input.lua: fa-k -> key_sequence "K"),
   -- which is this function, read_coords - not TileReader.read_tile_inner,
   -- which an earlier fix mistakenly targeted (that function is reached by
   -- cursor movement and other callers, but not by pressing K itself). Kept
   -- the TileReader hook too since it's still correct for those other
   -- callers, but the fix that actually matters for "press K" is this one.
   --
   -- Deliberately position-only, independent of cursor_stack: dzsoker's
   -- primary use case is checking a spot's coverage WHILE HOLDING a
   -- lightning-rod/collector stack to decide where to place it, so this
   -- must keep working exactly the same whether the player's hand is empty
   -- or holding something.
   local lightning_covered = LightningZones.is_covered(game.get_player(pindex).surface, marked_pos)

   if game.get_player(pindex).driving and game.get_player(pindex).vehicle ~= nil then
      --Give vehicle coords and orientation and speed --laterdo find exact speed coefficient
      local vehicle = game.get_player(pindex).vehicle
      assert(vehicle ~= nil) -- When driving is true, vehicle is guaranteed to exist
      local speed = vehicle.speed * 215
      local message = MessageBuilder.new()

      if start_phrase then message:fragment(start_phrase) end

      if vehicle.type ~= "spider-vehicle" then
         if speed > 0 then
            message:fragment({
               "fa.vehicle-heading",
               Localising.get_localised_name_with_fallback(vehicle),
               FaUtils.get_heading_info(vehicle),
               tostring(math.floor(speed)),
            })
         elseif speed < 0 then
            message:fragment({
               "fa.vehicle-reversing",
               Localising.get_localised_name_with_fallback(vehicle),
               FaUtils.get_heading_info(vehicle),
               tostring(math.floor(-speed)),
            })
         else
            message:fragment({
               "fa.vehicle-parked",
               Localising.get_localised_name_with_fallback(vehicle),
               FaUtils.get_heading_info(vehicle),
            })
         end
      else
         message:fragment({
            "fa.vehicle-spider-moving",
            Localising.get_localised_name_with_fallback(vehicle),
            tostring(math.floor(speed)),
         })
      end

      message:fragment({
         "fa.vehicle-position-in",
         Localising.get_localised_name_with_fallback(vehicle),
         tostring(math.floor(vehicle.position.x)),
         tostring(math.floor(vehicle.position.y)),
      })

      if lightning_covered == false then message:fragment({ "fa.ent-info-lightning-unprotected" }) end

      Speech.speak(pindex, message:build())
   else
      --Simply give coords (floored for the readout, extra precision for the console)
      local location = FaUtils.get_entity_part_at_cursor(pindex)
      local message = MessageBuilder.new()

      if start_phrase then message:fragment(start_phrase) end

      if location and location ~= " " then
         message:fragment({
            "fa.coordinates-at-with-location",
            "",
            location,
            tostring(math.floor(marked_pos.x)),
            tostring(math.floor(marked_pos.y)),
         })
      else
         message:fragment({
            "fa.coordinates-at",
            "",
            tostring(math.floor(marked_pos.x)),
            tostring(math.floor(marked_pos.y)),
         })
      end

      -- Also print to console with extra precision
      game.get_player(pindex).print(
         (start_phrase or "")
            .. " at "
            .. math.floor(marked_pos.x)
            .. ", "
            .. math.floor(marked_pos.y)
            .. "\n ("
            .. math.floor(marked_pos.x * 10) / 10
            .. ", "
            .. math.floor(marked_pos.y * 10) / 10
            .. ")",
         { volume_modifier = 0 }
      )
      --Draw the point
      rendering.draw_circle({
         color = { 1.0, 0.2, 0.0 },
         radius = 0.1,
         width = 5,
         target = marked_pos,
         surface = game.get_player(pindex).surface,
         time_to_live = 180,
      })

      --If there is a build preview, give its dimensions and which way they extend
      local stack = game.get_player(pindex).cursor_stack
      local p_width, p_height = BuildDimensions.get_stack_build_dimensions(stack, vp:get_hand_direction())

      -- Tiles are always 1x1, so tile case still triggers.
      if p_width and p_height and (p_width > 1 or p_height > 1) then
         message:fragment({ "fa.build-preview-dimensions", tostring(p_width), tostring(p_height) })
      elseif stack and stack.valid_for_read and stack.valid and stack.prototype.place_as_tile_result ~= nil then
         --Paving preview size
         local size = vp:get_cursor_size() * 2 + 1
         if storage.players[pindex].preferences.tiles_placed_from_northwest_corner then
            message:fragment({ "fa.paving-preview-northwest", tostring(size), tostring(size) })
         else
            message:fragment({ "fa.paving-preview-centered", tostring(size), tostring(size) })
         end
      end

      if lightning_covered == false then message:fragment({ "fa.ent-info-lightning-unprotected" }) end

      Speech.speak(pindex, message:build())
   end
end

--Read coordinates of the cursor. Extra info as well such as entity part if an entity is selected, and heading and speed info for vehicles.
EventManager.on_event(
   "fa-k",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- Check for virtual train driving (status command doesn't need TileReader.read_tile)
      if VirtualTrainDriving.on_kb_descriptive_action_name(event) then return end

      read_coords(pindex)
   end
)

--Get distance and direction of cursor from player.
---@param event EventData.CustomInputEvent
local function kb_read_cursor_distance_and_direction(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_pos = vp:get_cursor_pos()
   --Read where the cursor is with respect to the player, e.g. "at 5 west"
   local dir_dist = FaUtils.dir_dist_locale(p.position, cursor_pos)
   local cursor_location_description = { "fa.at" }
   local cursor_production = " "
   local cursor_description_of = " "
   local result = { "fa.thing-producing-listpos-dirdist", cursor_location_description }
   table.insert(result, cursor_production) --no production
   table.insert(result, cursor_description_of) --listpos
   table.insert(result, dir_dist)
   Speech.speak(pindex, result)
   p.print(result, { volume_modifier = 0 })
   --Draw the point
   rendering.draw_circle({
      color = { 1, 0.2, 0 },
      radius = 0.1,
      width = 5,
      target = cursor_pos,
      surface = p.surface,
      time_to_live = 180,
   })
end

EventManager.on_event(
   "fa-s-k",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_read_cursor_distance_and_direction(event)
   end
)

--Get distance and direction of cursor from player as a vector with a horizontal component and vertical component.
---@param event EventData.CustomInputEvent
local function kb_read_cursor_distance_vector(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)
   local c_pos = vp:get_cursor_pos()
   local p_pos = p.position
   local diff_x = math.floor(c_pos.x) - math.floor(p_pos.x)
   local diff_y = math.floor(c_pos.y) - math.floor(p_pos.y)

   ---@type defines.direction
   local dir_x = dirs.east

   if diff_x < 0 then dir_x = dirs.west end

   ---@type defines.direction
   local dir_y = dirs.south

   if diff_y < 0 then dir_y = dirs.north end
   local result = "At "
      .. math.abs(diff_x)
      .. " "
      .. FaUtils.direction_lookup(dir_x)
      .. " and "
      .. math.abs(diff_y)
      .. " "
      .. FaUtils.direction_lookup(dir_y)
   Speech.speak(pindex, result)
   p.print(result, { volume_modifier = 0 })
   --Show cursor position
   rendering.draw_circle({
      color = { 1, 0.2, 0 },
      radius = 0.1,
      width = 5,
      target = c_pos,
      surface = p.surface,
      time_to_live = 180,
   })
end

EventManager.on_event(
   "fa-a-k",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      kb_read_cursor_distance_vector(event)
   end
)

local function kb_read_character_coords(event)
   local pindex = event.player_index
   local pos = game.get_player(pindex).position
   local result = "Character at " .. math.floor(pos.x) .. ", " .. math.floor(pos.y)
   --Report co-ordinates (floored for the readout, extra precision for the console)
   Speech.speak(pindex, result)
   game.get_player(pindex).print(
      result .. "\n (" .. math.floor(pos.x * 10) / 10 .. ", " .. math.floor(pos.y * 10) / 10 .. ")",
      { volume_modifier = 0 }
   )
end

EventManager.on_event(
   "fa-c-k",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_read_character_coords(event)
   end
)

--Teleports the cursor to the player's anchor point - normally their PHYSICAL position, where
--their character (or other physical controller, e.g. god/editor) actually is, not just
--LuaControl::position, which in remote view reflects wherever the remote camera happens to be
--centered instead (and does not track further cursor movement there, since nothing in this mod
--moves the vanilla remote-view camera to follow our own cursor). Using physical_position/
--physical_surface here means J consistently means "show me where I really am", including
--correctly switching the remote view over to the right surface first if it's currently showing
--a different one.
--
--EXCEPTION - while driving a vehicle (p.vehicle set, whether physically embodied or true
--remote driving - see vehicles-overview.lua), jumping to the physical body is the wrong target:
--in the remote-driving case the physical body is stationary somewhere far away, so "show me
--where I really am" there means the vehicle, not the parked character - and it doubles as a
--way to re-center the cursor on the vehicle's CURRENT (moving) position, since nothing else
--keeps the cursor following it as it drives. Reported as confusing/annoying live; this is the
--fix.
---@param event EventData.CustomInputEvent
local function kb_jump_to_player(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)

   local target_pos, target_surface, coords_label
   if p.vehicle then
      target_pos = p.vehicle.position
      target_surface = p.vehicle.surface
      coords_label = "Cursor moved to vehicle "
   else
      target_pos = p.physical_position
      target_surface = p.physical_surface
      coords_label = "Cursor returned "
   end

   if p.controller_type == defines.controllers.remote and p.surface_index ~= target_surface.index then
      p.set_controller({
         type = defines.controllers.remote,
         surface = target_surface,
         position = target_pos,
      })
   end

   local cursor_pos = vp:get_cursor_pos()
   local cursor_size = vp:get_cursor_size()
   cursor_pos.x = math.floor(target_pos.x)
   cursor_pos.y = math.floor(target_pos.y)
   vp:set_cursor_pos(cursor_pos)
   read_coords(pindex, coords_label)
   if cursor_size < 2 then
      Graphics.draw_cursor_highlight(pindex, nil, nil)
   else
      local scan_left_top = {
         math.floor(cursor_pos.x) - cursor_size,
         math.floor(cursor_pos.y) - cursor_size,
      }
      local scan_right_bottom = {
         math.floor(cursor_pos.x) + cursor_size + 1,
         math.floor(cursor_pos.y) + cursor_size + 1,
      }
      Graphics.draw_large_cursor(scan_left_top, scan_right_bottom, pindex)
   end
end

---@param event EventData.CustomInputEvent
local function kb_read_driving_structure_ahead(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local ent = storage.players[pindex].last_driving_alert_ent
   if ent and ent.valid then
      local dir = FaUtils.get_heading_value(p.vehicle)
      local dir_ent = FaUtils.get_direction_biased(ent.position, p.vehicle.position)
      if p.vehicle.speed >= 0 and (dir_ent == dir or math.abs(dir_ent - dir) == 1 or math.abs(dir_ent - dir) == 15) then
         local dist = math.floor(util.distance(p.vehicle.position, ent.position))
         Speech.speak(
            pindex,
            { "fa.driving-structure-ahead", Localising.get_localised_name_with_fallback(ent), tostring(dist) }
         )
      elseif p.vehicle.speed <= 0 and dir_ent == FaUtils.rotate_180(dir) then
         local dist = math.floor(util.distance(p.vehicle.position, ent.position))
         Speech.speak(
            pindex,
            { "fa.driving-structure-behind", Localising.get_localised_name_with_fallback(ent), tostring(dist) }
         )
      end
   end
end

EventManager.on_event(
   "fa-j",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      local p = game.get_player(pindex)

      if Combat.is_combat_mode(pindex) then
         Speech.speak(pindex, { "fa.not-available-in-combat-mode" })
      else
         kb_jump_to_player(event)
      end
   end
)

---@param event EventData.CustomInputEvent
local function kb_s_b(event)
   local pindex = event.player_index
   local vp = Viewpoint.get_viewpoint(pindex)
   local pos = vp:get_cursor_pos()
   vp:set_cursor_bookmark(table.deepcopy(pos))
   Speech.speak(pindex, { "fa.cursor-bookmark-saved", tostring(math.floor(pos.x)), tostring(math.floor(pos.y)) })
   sounds.play_close_inventory(pindex)
end

EventManager.on_event(
   "fa-s-b",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- Check for virtual train driving (create bookmark)
      if VirtualTrainDriving.on_kb_descriptive_action_name(event) then return end

      if skip_in_combat_mode(pindex) then return end
      kb_s_b(event)
   end
)

---@param event EventData.CustomInputEvent
local function kb_b(event)
   local pindex = event.player_index
   local vp = Viewpoint.get_viewpoint(pindex)
   local pos = vp:get_cursor_bookmark()
   if pos == nil or pos.x == nil or pos.y == nil then return end
   vp:set_cursor_pos(pos)
   Graphics.draw_cursor_highlight(pindex, nil, nil)
   Graphics.sync_build_cursor_graphics(pindex)
   Speech.speak(pindex, { "fa.cursor-bookmark-loaded", tostring(math.floor(pos.x)), tostring(math.floor(pos.y)) })
   sounds.play_close_inventory(pindex)
end

EventManager.on_event(
   "fa-b",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- Check for virtual train driving
      if VirtualTrainDriving.is_locked(pindex) then
         local success = VirtualTrainDriving.return_to_bookmark(pindex)
         if success then TileReader.read_tile(pindex) end
         return
      end

      if skip_in_combat_mode(pindex) then return end
      kb_b(event)
   end
)

---@param event EventData.CustomInputEvent
local function kb_ca_b(event)
   local pindex = event.player_index
   local vp = Viewpoint.get_viewpoint(pindex)
   local pos = vp:get_cursor_pos()
   Rulers.upsert_ruler(pindex, pos.x, pos.y)
   Speech.speak(pindex, { "fa.ruler-saved-at", tostring(math.floor(pos.x)), tostring(math.floor(pos.y)) })
   sounds.play_close_inventory(pindex)
end

EventManager.on_event(
   "fa-ca-b",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_ca_b(event)
   end
)

EventManager.on_event(
   "fa-as-b",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      Rulers.clear_rulers(pindex)
      Speech.speak(pindex, { "fa.rulers-cleared" })
   end
)

EventManager.on_event(
   "fa-cas-b",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local p = game.get_player(pindex)
      if p.is_cursor_empty then p.cursor_stack.set_stack("blueprint-book") end
   end
)

EventManager.on_event(
   "fa-s-c",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      UiRouter.get_router(pindex):open_ui(UiRouter.UI_NAMES.CURSOR_COORDINATE_INPUT)
   end
)

EventManager.on_event(
   "fa-s-t",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      Teleport.teleport_to_cursor(pindex, false, false, false)
   end
)

EventManager.on_event(
   "fa-cs-t",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      Teleport.teleport_to_cursor(pindex, false, true, false)
   end
)

---@param event EventData.CustomInputEvent
local function kb_cs_p(event)
   local pindex = event.player_index
   local vp = Viewpoint.get_viewpoint(pindex)
   local alert_pos = storage.players[pindex].last_damage_alert_pos
   if alert_pos == nil then
      Speech.speak(pindex, { "fa.no-target" })
      return
   end
   vp:set_cursor_pos(alert_pos)
   Teleport.teleport_to_cursor(pindex, false, true, true)
   local position = game.get_player(pindex).position
   vp:set_cursor_pos({ x = position.x, y = position.y })
   storage.players[pindex].last_damage_alert_pos = position
   Graphics.draw_cursor_highlight(pindex, nil, nil)
   Graphics.sync_build_cursor_graphics(pindex)
   EntitySelection.reset_entity_index(pindex)
end

EventManager.on_event(
   "fa-cs-p",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_cs_p(event)
   end
)

---Toggles cursor mode on or off. Appropriately affects other modes such as build lock or remote view.
---@param pindex number
---@param muted boolean
local function toggle_cursor_mode(pindex, muted)
   local p = game.get_player(pindex)
   local vp = Viewpoint.get_viewpoint(pindex)
   if p.character == nil then
      vp:set_cursor_anchored(false)
      Speech.speak(pindex, { "fa.cannot-anchor-no-character" })
      return
   end

   if not vp:get_cursor_anchored() then
      --Enable
      vp:set_cursor_anchored(true)

      --Finally, read the new tile
      Speech.speak(pindex, { "fa.anchored-cursor" })
   else
      --Finally, read the new tile
      vp:set_cursor_anchored(false)
      -- For the unanchored case it's worth reading the tile the cursor ended up on.
      if muted ~= true then read_tile_with_preview_info(pindex, { "fa.unanchored-cursor" }) end
   end
end

EventManager.on_event(
   "fa-i",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      toggle_cursor_mode(pindex, false)
   end
)

-- Handle escape key: close textbox if open (sending nil to parent), otherwise give pause hint
EventManager.on_event(
   "fa-escape",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if GameGui.is_textbox_open(pindex) then
         local router = UiRouter.get_router(pindex)
         local top_ui_name = router:get_open_ui_name()

         -- Send nil result to parent UI to signal cancellation
         if top_ui_name then
            local registered_uis = UiRouter.get_registered_uis()
            local ui = registered_uis[top_ui_name]
            if ui and ui.on_child_result then
               local context = GameGui.get_textbox_context(pindex)
               -- Use close_with_result to properly notify parent and clean up
               GameGui.close_textbox(pindex)
               router:close_with_result(nil)
               return
            end
         end

         -- Fallback: just close textbox and pop UI
         GameGui.close_textbox(pindex)
         router:close_ui()
      else
         Speech.speak(pindex, { "fa.escape-to-pause" })
      end
   end
)

---Valid cursor sizes
---@type integer[]
local CURSOR_SIZES = { 0, 1, 2, 5, 10, 25, 50, 125 }

---Adjusts the cursor size for a given player by stepping through predefined cursor size options.
---Direction +1 increases the size to the next larger value, -1 decreases it.
---@param pindex number Player index
---@param direction number Step direction in CURSOR_SIZES (+1 to increase, -1 to decrease)
local function adjust_cursor_size(pindex, direction)
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_pos = vp:get_cursor_pos()
   local current_size = vp:get_cursor_size()
   local index = nil

   for i, size in ipairs(CURSOR_SIZES) do
      if size == current_size then
         index = i
         break
      end
   end

   if index == nil then return end

   local new_index = index + direction
   if new_index < 1 or new_index > #CURSOR_SIZES then return end

   local new_size = CURSOR_SIZES[new_index]
   vp:set_cursor_size(new_size)

   local say_size = new_size * 2 + 1
   Speech.speak(pindex, { "fa.cursor-size", tostring(say_size), tostring(say_size) })
   sounds.play_close_inventory(pindex)
   Graphics.draw_large_cursor({
      cursor_pos.x - new_size,
      cursor_pos.y - new_size,
   }, {
      cursor_pos.x + new_size + 1,
      cursor_pos.y + new_size + 1,
   }, pindex)
end

--We have cursor sizes 1,3,5,11,21,51,101,251
EventManager.on_event(
   "fa-s-i",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      adjust_cursor_size(pindex, 1)
   end
)

--We have cursor sizes 1,3,5,11,21,51,101,251
EventManager.on_event(
   "fa-c-i",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      adjust_cursor_size(pindex, -1)
   end
)

--[[
Toggle remote view. This used to be a no-op stub ("remote view is currently not working in
Factorio 2.0") - re-enabled now that we're on 2.1.19, per confirmed, current API research
(LuaPlayer::set_controller, ::exit_remote_view, ::physical_position, ::physical_surface - all
verified against the live 2.1.19 API docs, which match both the locally generated llm-docs
mirror and the actually-installed game version).

Bound to ALT + I (matches the key this stub already reserved) rather than vanilla's own
default M/Tab "toggle world map" key: plain M is already heavily used elsewhere in this mod
(fa-m: a generic UI action-1 binding plus a virtual-train-driving action), and Tab/Shift+Tab
are core tab-list navigation in nearly every FA menu - remapping either would collide with
existing, frequently-used functionality.

Entering centers the remote view on the player's own physical position/surface (not, say, an
arbitrary map center), and moves our own FA cursor there too, so the screen-reader cursor and
the remote view agree on where "here" is from the first moment. storage.players[pindex].remote_view
is kept in sync here - it already existed and already drove sound-playback style (world-position
vs player-relative) at several call sites, but was previously dead code since nothing ever set
it to true.
]]
EventManager.on_event(
   "fa-a-i",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if skip_in_combat_mode(pindex) then return end
      local p = game.get_player(pindex)
      local vp = Viewpoint.get_viewpoint(pindex)

      if p.controller_type == defines.controllers.remote then
         local left = p.exit_remote_view()
         if not left then
            Speech.speak(pindex, { "fa.remote-view-exit-failed" })
            return
         end
         storage.players[pindex].remote_view = false
         local pos = p.physical_position
         vp:set_cursor_pos({ x = math.floor(pos.x), y = math.floor(pos.y) })
         Graphics.draw_cursor_highlight(pindex, nil, nil)
         Graphics.sync_build_cursor_graphics(pindex)
         Speech.speak(pindex, { "fa.remote-view-exited" })
      else
         local pos = p.physical_position
         p.set_controller({
            type = defines.controllers.remote,
            surface = p.physical_surface,
            position = pos,
         })
         storage.players[pindex].remote_view = true
         vp:set_cursor_pos({ x = math.floor(pos.x), y = math.floor(pos.y) })
         Graphics.draw_cursor_highlight(pindex, nil, nil)
         Graphics.sync_build_cursor_graphics(pindex)
         Speech.speak(pindex, { "fa.remote-view-entered" })
      end
   end
)

EventManager.on_event(
   "fa-pageup",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      local p = game.get_player(pindex)
      local ent = p.opened

      if ent and ent.type == "inserter" then
         -- TODO: Move to capability-based UI
         -- Temporarily inline the functionality
         ent.inserter_stack_size_override = ent.inserter_stack_size_override + 1
         local result = ent.inserter_stack_size_override .. " set for hand stack size"
         Speech.speak(pindex, result)
      else
         ScannerEntrypoint.move_subcategory(pindex, -1)
      end
   end
)

EventManager.on_event(
   "fa-s-pageup",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      ScannerEntrypoint.move_within_subcategory(pindex, -1)
   end
)

EventManager.on_event(
   "fa-c-pageup",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      ScannerEntrypoint.move_category(pindex, -1)
   end
)

EventManager.on_event(
   "fa-pagedown",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      local p = game.get_player(pindex)
      local ent = p.opened

      if ent and ent.type == "inserter" then
         -- TODO: Move to capability-based UI
         -- Temporarily inline the functionality
         local result = ""
         if ent.inserter_stack_size_override > 1 then
            ent.inserter_stack_size_override = ent.inserter_stack_size_override - 1
            result = ent.inserter_stack_size_override .. " set for hand stack size"
         else
            ent.inserter_stack_size_override = 0
            local cap = ent.force.inserter_stack_size_bonus + 1
            if ent.name == "stack-inserter" or ent.name == "stack-filter-inserter" then
               cap = ent.force.stack_inserter_capacity_bonus + 1
            end
            result = "restored " .. cap .. " as default hand stack size "
         end
         Speech.speak(pindex, result)
      else
         ScannerEntrypoint.move_subcategory(pindex, 1)
      end
   end
)

EventManager.on_event(
   "fa-s-pagedown",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      ScannerEntrypoint.move_within_subcategory(pindex, 1)
   end
)

EventManager.on_event(
   "fa-c-pagedown",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      ScannerEntrypoint.move_category(pindex, 1)
   end
)

EventManager.on_event(
   "fa-home",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      ScannerEntrypoint.announce_current_item(pindex)
   end
)

EventManager.on_event(
   "fa-end",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      ScannerEntrypoint.do_refresh(pindex)
   end
)

EventManager.on_event("fa-s-end", function(event)
   local player = game.get_player(event.player_index)
   local char = player.character
   if not char then return end
   ScannerEntrypoint.do_refresh(event.player_index, char.direction)
end)

EventManager.on_event("fa-s-slash", function(event)
   local pindex = event.player_index
   local player = game.get_player(pindex)

   local help_items = {}

   -- Add hand status message
   local cursor_stack = player.cursor_stack
   if cursor_stack and cursor_stack.valid_for_read then
      local item_name = Localising.get_localised_name_with_fallback(cursor_stack.prototype)
      local msg = MessageBuilder.new():fragment({ "fa.hand-contains", item_name }):build()
      table.insert(help_items, Help.message(msg))
   else
      table.insert(help_items, Help.message({ "fa.hand-empty" }))
   end

   -- If hand has item, check for prototype-specific help
   if cursor_stack and cursor_stack.valid_for_read then
      local prototype_type = cursor_stack.prototype.type
      local help_list_name = prototype_type .. "-protohelp"
      if MessageLists.has_list(help_list_name) then table.insert(help_items, Help.message_list(help_list_name)) end
   end

   -- Add map help
   table.insert(help_items, Help.message_list("map-help"))

   -- Open help UI
   local router = UiRouter.get_router(pindex)
   local help_params = Help.create_parameters(help_items)
   router:open_ui(UiRouter.UI_NAMES.HELP, help_params)
end)

-- Tutorial (Ctrl+T)
EventManager.on_event("fa-c-t", function(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)

   -- Open tutorial UI
   router:open_ui(UiRouter.UI_NAMES.TUTORIAL, {})
end)

-- Prototype lister (Alt+P)
EventManager.on_event("fa-a-p", function(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.PROTOTYPE_LISTER, {})
end)

-- Circuit/copper network neighbors (N key)
EventManager.on_event(
   "fa-n",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local player = game.get_player(pindex)
      local ent = player.selected

      if ent and ent.valid then
         -- Check for combinators (multi-connection circuit entities)
         if
            ent.type == "arithmetic-combinator"
            or ent.type == "decider-combinator"
            or ent.type == "selector-combinator"
         then
            local msg = CircuitNetworks.get_combinator_neighbors_info(ent, pindex)
            Speech.speak(pindex, msg)
            return
         end

         -- Check for power switch (multi-connection entity with both copper and circuit)
         if ent.type == "power-switch" then
            local msg = CircuitNetworks.get_power_switch_neighbors_info(ent, pindex)
            Speech.speak(pindex, msg)
            return
         end

         -- Check for electric pole (copper wires)
         if ent.type == "electric-pole" then
            local msg = CircuitNetworks.get_copper_wire_neighbors_info(ent, pindex)
            Speech.speak(pindex, msg)
            return
         end

         -- Check if entity has circuit network capability
         local cb = ent.get_control_behavior()
         if cb then
            local msg = CircuitNetworks.get_circuit_neighbors_info(ent, pindex)
            Speech.speak(pindex, msg)
            return
         end
      end

      Speech.speak(pindex, { "", "Not in a network" })
   end
)

-- Remove wires (Alt+N key)
EventManager.on_event(
   "fa-a-n",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      CircuitNetworks.remove_wires(pindex)
   end
)

-- Circuit network navigator (Ctrl+Alt+N key)
EventManager.on_event(
   "fa-c-n",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local player = game.get_player(pindex)
      local ent = player.selected

      -- Check if entity has circuit network capability
      if ent and ent.valid then
         local cb = ent.get_control_behavior()
         if cb then
            UiRouter.get_router(pindex):open_ui(UiRouter.UI_NAMES.CIRCUIT_NAVIGATOR, { entity = ent })
            return
         end
      end

      Speech.speak(pindex, { "", "No circuit network capable entity selected" })
   end
)

-- fa-c-tab is now handled by the UI router for section navigation

--Used when a tile has multiple overlapping entities. Reads out the next entity.
---@param event EventData.CustomInputEvent
local function kb_tile_cycle(event)
   local pindex = event.player_index
   local ent = EntitySelection.get_next_ent_at_tile(pindex)
   if ent and ent.valid then
      Speech.speak(pindex, FaInfo.ent_info(pindex, ent))
      game.get_player(pindex).selected = ent
   else
      local tile_name = EntitySelection.get_player_tile(pindex)
      Speech.speak(pindex, tile_name)
   end
end

--Reads other entities on the same tile? Note: Possibly unneeded
EventManager.on_event(
   "fa-s-f",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      kb_tile_cycle(event)
   end
)

--Opens the main unified menu
---@param event EventData.CustomInputEvent
local function kb_open_player_inventory(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local router = UiRouter.get_router(pindex)

   if p.ticks_to_respawn ~= nil then return end
   -- Without a character, only proceed for the "remote" controller (remote view, or riding a
   -- space platform in transit) - open_main_menu offers a reduced menu (ghost placement instead
   -- of craft/inventory) in that case. Any other characterless state (e.g. spectating) still
   -- has nothing sensible to show.
   if p.character == nil and p.controller_type ~= defines.controllers.remote then return end
   sounds.play_open_inventory(p.index)
   p.selected = nil

   -- Open the main menu
   MainMenu.open_main_menu(pindex)
end

EventManager.on_event(
   "fa-e",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- Always open inventory - closing is handled by the UI event system
      kb_open_player_inventory(event)
   end
)

EventManager.on_event(
   "fa-a-w",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      WorldMenu.open_world_menu(pindex)
   end
)

-- Now handled by router.lua
---@param event EventData
local function kb_read_menu_name(event)
   ---@cast event EventData.CustomInputEvent
   local pindex = event.player_index

   Speech.speak(pindex, { "fa.not-in-menu" })
end

EventManager.on_event("fa-s-e", function(event) --read_menu_name
   local pindex = event.player_index
   kb_read_menu_name(event)
end)

---@param event EventData.CustomInputEvent
local function kb_delete(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)
   local p = game.get_player(pindex)
   local hand = p.cursor_stack

   if hand and hand.valid_for_read then
      local is_planner = hand.is_blueprint
         or hand.is_blueprint_book
         or hand.is_deconstruction_item
         or hand.is_upgrade_item
      if is_planner then
         if FaUtils.confirm_action(pindex, hand.export_stack(), "Press again to delete the planner in hand.") then
            p.cursor_stack_temporary = true
            p.clear_cursor()
         end
      end
   end
end
EventManager.on_event(
   "fa-delete",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_delete(event)
   end
)

---@param event EventData.CustomInputEvent
local function kb_mine_tiles(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local stack = p.cursor_stack
   if not (stack and stack.valid_for_read and stack.valid and stack.prototype.place_as_tile_result) then return end

   local vp = Viewpoint.get_viewpoint(pindex)
   local c_pos = vp:get_cursor_pos()
   local c_size = vp:get_cursor_size()
   local left_top = { x = math.floor(c_pos.x - c_size), y = math.floor(c_pos.y - c_size) }
   local right_bottom = { x = math.floor(c_pos.x + 1 + c_size), y = math.floor(c_pos.y + 1 + c_size) }
   local tiles = p.surface.find_tiles_filtered({ area = { left_top, right_bottom } })

   for _, tile in ipairs(tiles) do
      if p.mine_tile(tile) then sounds.play_entity_mined(p.index, "stone-furnace") end
   end
end

---@param event EventData.CustomInputEvent
local function kb_mine_access_sounds(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local ent = p.selected
   if ent and ent.valid and ent.prototype.mineable_properties.products and ent.type ~= "resource" then
      sounds.play_mine(p.index)
   elseif ent and ent.valid and ent.name == "character-corpse" then
      Speech.speak(pindex, { "fa.collecting-items" })
   end
end

EventManager.on_event(
   "fa-x",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      local p = game.get_player(pindex)
      local stack = p.cursor_stack
      if stack and stack.valid_for_read and stack.valid and stack.prototype.place_as_tile_result then
         kb_mine_tiles(event)
      end
      kb_mine_access_sounds(event)
   end
)

--Area mining for obstacles, trees, rocks, etc.
EventManager.on_event(
   "fa-s-x",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      AreaOperations.mine_area(pindex)
   end
)

--Mines groups of entities depending on the name or type. Includes trees and rocks.

EventManager.on_event(
   "fa-cs-x",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      local ent = game.get_player(pindex).selected
      if ent and ent.valid then AreaOperations.super_mine_area(pindex) end
   end
)

---Left click actions with items in hand
---@param event EventData.CustomInputEvent
local function kb_click_hand(event)
   local pindex = event.player_index
   storage.players[pindex].last_click_tick = event.tick

   local player = game.get_player(pindex)
   local stack = player.cursor_stack

   -- Check if the item in hand can be built
   if stack and stack.valid_for_read then
      if (stack.is_blueprint and stack.is_blueprint_setup()) or stack.is_blueprint_book then
         -- Blueprint or blueprint book building
         local vp = Viewpoint.get_viewpoint(pindex)
         BuildingTools.build_blueprint(pindex, vp:get_flipped_horizontal(), vp:get_flipped_vertical())
      elseif stack.name == "red-wire" or stack.name == "green-wire" or stack.name == "copper-wire" then
         -- Wire dragging - red/green circuit wires or copper electrical wire
         CircuitNetworks.drag_wire_and_read(pindex)
      else
         local proto = stack.prototype
         local capsule_action = proto.capsule_action
         if capsule_action then
            -- Handle capsules
            if Combat.is_combat_mode(pindex) then
               Capsules.use_capsule_undirected(pindex)
            elseif capsule_action.type == "use-on-self" then
               player.use_from_cursor(player.position)
            else
               -- Throwables, remotes, cliff explosives: use at cursor
               local vp = Viewpoint.get_viewpoint(pindex)
               player.use_from_cursor(vp:get_cursor_pos())
            end
         elseif proto.place_result or proto.place_as_tile_result then
            -- Item can be placed/built
            local vp = Viewpoint.get_viewpoint(pindex)
            local success = BuildingTools.build_item_in_hand_with_params({
               pindex = pindex,
               building_direction = vp:get_hand_direction(),
               flip_horizontal = vp:get_flipped_horizontal(),
               flip_vertical = vp:get_flipped_vertical(),
            })
            if success then
               TileReader.read_tile(pindex)
            else
               -- Build failed, try opening entity menu if one exists at cursor
               local ent = EntitySelection.get_first_ent_at_tile(pindex)
               if ent and EntityUI.has_ui(ent) then clicked_on_entity(ent, pindex) end
            end
         else
            -- Item cannot be built (e.g., intermediate products, tools, etc.)
            -- If there's an entity with a menu at the cursor, open its menu
            local ent = EntitySelection.get_first_ent_at_tile(pindex)
            if ent and EntityUI.has_ui(ent) then
               clicked_on_entity(ent, pindex)
            else
               Speech.speak(pindex, { "fa.cannot-build-item" })
            end
         end
      end
   elseif player.cursor_ghost then
      -- Ghost building
      local vp = Viewpoint.get_viewpoint(pindex)
      local success = BuildingTools.build_item_in_hand_with_params({
         pindex = pindex,
         building_direction = vp:get_hand_direction(),
         flip_horizontal = vp:get_flipped_horizontal(),
         flip_vertical = vp:get_flipped_vertical(),
      })
      if success then TileReader.read_tile(pindex) end
   end
end

--Left click actions with no menu and no items in hand
---@param event EventData.CustomInputEvent
local function kb_click_entity(event)
   local pindex = event.player_index
   storage.players[pindex].last_ck_tick = event.tick
   local ent = EntitySelection.get_first_ent_at_tile(pindex)
   clicked_on_entity(ent, pindex)
end

EventManager.on_event(
   "fa-leftbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)

      if storage.players[pindex].last_click_tick == event.tick then return end
      local p = game.get_player(pindex)
      local stack = p.cursor_stack
      local ghost = p.cursor_ghost

      -- Handle planners specially (direct or in book)
      local vp = Viewpoint.get_viewpoint(pindex)
      local cursor_pos = vp:get_cursor_pos()
      local cursor_size = vp:get_cursor_size()

      if PlannerUtils.has_decon_planner(pindex) then
         if cursor_size > 0 then
            -- Cursor larger than 1x1: apply planner directly to cursor area
            local planner = PlannerUtils.get_decon_planner(pindex)
            local area = {
               left_top = { x = cursor_pos.x - cursor_size + 0.5, y = cursor_pos.y - cursor_size + 0.5 },
               right_bottom = { x = cursor_pos.x + cursor_size + 0.5, y = cursor_pos.y + cursor_size + 0.5 },
            }
            p.surface.deconstruct_area({
               area = area,
               force = p.force,
               player = p,
               item = planner,
            })
            Speech.speak(pindex, { "fa.planner-marked-for-deconstruction" })
         else
            -- 1x1 cursor: start area selection
            router:open_ui(UiRouter.UI_NAMES.DECON_AREA_SELECTOR, {
               first_point = { x = cursor_pos.x, y = cursor_pos.y },
               intro_message = {
                  "fa.planner-deconstruct-first-point",
                  math.floor(cursor_pos.x),
                  math.floor(cursor_pos.y),
               },
               second_message = { "fa.planner-select-second-point" },
            })
         end
         return
      elseif PlannerUtils.has_upgrade_planner(pindex) then
         if cursor_size > 0 then
            -- Cursor larger than 1x1: apply planner directly to cursor area
            local planner = PlannerUtils.get_upgrade_planner(pindex)
            local area = {
               left_top = { x = cursor_pos.x - cursor_size + 0.5, y = cursor_pos.y - cursor_size + 0.5 },
               right_bottom = { x = cursor_pos.x + cursor_size + 0.5, y = cursor_pos.y + cursor_size + 0.5 },
            }
            p.surface.upgrade_area({
               area = area,
               force = p.force,
               player = p,
               item = planner,
            })
            Speech.speak(pindex, { "fa.planner-marked-for-upgrade" })
         else
            -- 1x1 cursor: start area selection
            router:open_ui(UiRouter.UI_NAMES.UPGRADE_AREA_SELECTOR, {
               first_point = { x = cursor_pos.x, y = cursor_pos.y },
               intro_message = { "fa.planner-upgrade-first-point", math.floor(cursor_pos.x), math.floor(cursor_pos.y) },
               second_message = { "fa.planner-select-second-point" },
            })
         end
         return
      elseif stack and stack.valid_for_read then
         if stack.is_blueprint then
            -- Only start selection for empty blueprints
            if not stack.is_blueprint_setup() then
               -- Start selection for empty blueprint
               router:open_ui(UiRouter.UI_NAMES.BLUEPRINT_SETUP, {
                  first_point = { x = cursor_pos.x, y = cursor_pos.y },
                  intro_message = {
                     "fa.planner-blueprint-first-point",
                     math.floor(cursor_pos.x),
                     math.floor(cursor_pos.y),
                  },
                  second_message = { "fa.planner-blueprint-second-point" },
                  permanent = true,
               })
               return
            end
            -- Blueprint is set up - fall through to normal click behavior
         elseif stack.is_blueprint_book then
            -- Check if book has an active blueprint that is set up
            local book_inv = stack.get_inventory(defines.inventory.item_main)
            if book_inv and stack.active_index then
               local active_bp = book_inv[stack.active_index]
               if
                  active_bp
                  and active_bp.valid_for_read
                  and active_bp.is_blueprint
                  and active_bp.is_blueprint_setup()
               then
                  -- Active blueprint is set up - fall through to normal click behavior to place it
               else
                  -- Active blueprint not set up or invalid
                  Speech.speak(pindex, { "fa.blueprint-book-no-active-blueprint" })
                  return
               end
            else
               -- No active blueprint or empty book
               Speech.speak(pindex, { "fa.blueprint-book-no-active-blueprint" })
               return
            end
         elseif stack.name == "copy-paste-tool" or stack.name == "cut-paste-tool" then
            -- Start selection for copy/cut
            local is_cut = stack.name == "cut-paste-tool"
            router:open_ui(UiRouter.UI_NAMES.COPY_PASTE_AREA_SELECTOR, {
               first_point = { x = cursor_pos.x, y = cursor_pos.y },
               intro_message = {
                  is_cut and "fa.planner-cut-first-point" or "fa.planner-copy-first-point",
                  math.floor(cursor_pos.x),
                  math.floor(cursor_pos.y),
               },
               second_message = false,
            })
            return
         elseif stack.prototype.type == "spidertron-remote" then
            -- Add autopilot point for spidertron remote (enqueue, don't clear)
            SpidertronRemote.add_to_autopilot(p, cursor_pos, false)
            return
         elseif stack.prototype.rails then
            -- Rail planner: check if there's a rail at cursor to lock onto
            local ent = EntitySelection.get_first_ent_at_tile(pindex)
            if ent and ent.valid and Consts.RAIL_TYPES_SET[ent.type] then
               VirtualTrainDriving.lock_on_to_rail(pindex, ent)
               return
            end
            -- No rail at cursor, fall through to normal click behavior
         elseif stack.is_repair_tool then
            local ent = EntitySelection.get_first_ent_at_tile(pindex)
            if ent then Combat.repair_pack_used(ent, pindex) end
            return
         end
      end

      -- Normal left-click behavior
      if ghost or (stack and stack.valid_for_read and stack.valid) then
         kb_click_hand(event)
      else
         kb_click_entity(event)
      end
   end
)

EventManager.on_event(
   "fa-a-l",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      WorkerRobots.logistics_request_toggle_handler(pindex)
   end
)

EventManager.on_event(
   "fa-a-f",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      WorkerRobots.announce_robot_dispatch_status(pindex)
   end
)

EventManager.on_event(
   "fa-a-leftbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- Handle rail builder when locked to rails in VTD mode
      if VirtualTrainDriving.is_locked(pindex) then
         UiRouter.get_router(pindex):open_ui(UiRouter.UI_NAMES.RAIL_BUILDER)
         return
      end

      local p = game.get_player(pindex)
      local stack = p.cursor_stack

      -- Handle offshore pumps with alt+[
      if stack and stack.valid_for_read and stack.name == "offshore-pump" then
         BuildingTools.build_offshore_pump_in_hand(pindex)
         return
      end
   end
)

---@param event EventData.CustomInputEvent
---@param ent LuaEntity
local function kb_launch_rocket(event, ent)
   local pindex = event.player_index
   local cargo_inventory = ent.get_inventory(defines.inventory.rocket_silo_rocket)

   local destination
   if cargo_inventory and not cargo_inventory.is_empty() then
      -- Cargo present, need a landing pad
      local landing_pads = ent.surface.find_entities_filtered({ type = "cargo-landing-pad" })
      if #landing_pads == 0 then
         Speech.speak(pindex, { "fa.no-cargo-landing-pad" })
         return
      end
      destination = {
         type = defines.cargo_destination.station,
         station = landing_pads[1],
         transform_launch_products = true,
      }
   else
      -- No cargo, launch to orbit
      destination = {
         type = defines.cargo_destination.orbit,
      }
   end

   local try_launch = ent.launch_rocket(destination)
   if try_launch then
      if destination.type == defines.cargo_destination.orbit then
         Speech.speak(pindex, { "fa.launch-to-orbit-successful" })
      else
         Speech.speak(pindex, { "fa.launch-successful" })
      end
   else
      Speech.speak(pindex, { "fa.not-ready-to-launch" })
   end
end

EventManager.on_event(
   "fa-s-enter",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local p = game.get_player(pindex)
      local ent = p.selected

      if not ent or not ent.valid then return end

      if ent.type == "rocket-silo" then
         kb_launch_rocket(event, ent)
      elseif ent.type == "constant-combinator" then
         local cb = ent.get_control_behavior()
         ---@cast cb LuaConstantCombinatorControlBehavior?
         if cb then
            cb.enabled = not cb.enabled
            if cb.enabled then
               Speech.speak(pindex, { "fa.switched-on" })
            else
               Speech.speak(pindex, { "fa.switched-off" })
            end
         end
         return
      end

      if ent.type == "power-switch" then
         local cb = ent.get_control_behavior()
         if cb and (cb.circuit_enable_disable or cb.connect_to_logistic_network) then
            Speech.speak(pindex, { "fa.power-switch-circuit-controlled" })
         else
            ent.power_switch_state = not ent.power_switch_state
            if ent.power_switch_state then
               Speech.speak(pindex, { "fa.switched-on" })
            else
               Speech.speak(pindex, { "fa.switched-off" })
            end
         end
         return
      end
   end
)

--Reads the entity status but also adds on extra info depending on the entity
---@param event EventData.CustomInputEvent
local function kb_read_entity_status(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)

   local result = FaInfo.read_selected_entity_status(pindex)
   if result ~= nil and result ~= "" then Speech.speak(pindex, result) end
end

--Right click actions with items in hand
---@param event EventData.CustomInputEvent
local function kb_click_hand_right(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)
   local p = game.get_player(pindex)
   local stack = game.get_player(pindex).cursor_stack

   storage.players[pindex].last_click_tick = event.tick
   --If something is in hand...
   if
      stack.prototype ~= nil
      and (stack.prototype.place_result ~= nil or stack.prototype.place_as_tile_result ~= nil)
   then
      --Laterdo here: build as ghost
      kb_read_entity_status(event)
   elseif stack.is_blueprint then
      local router = UiRouter.get_router(pindex)
      router:open_ui(UiRouter.UI_NAMES.BLUEPRINT)
   elseif stack.is_blueprint_book then
      local router = UiRouter.get_router(pindex)
      router:open_ui(UiRouter.UI_NAMES.BLUEPRINT_BOOK)
   elseif stack.is_deconstruction_item or stack.is_upgrade_item then
      -- Deconstruction and upgrade planners are now handled via left-click and alt+left-click
      Speech.speak(pindex, { "fa.planner-use-leftbracket" })
   else
      -- Regular item in hand (including spidertron remote) - read entity status as fallback
      kb_read_entity_status(event)
   end
end

EventManager.on_event(
   "fa-rightbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if storage.players[pindex].last_click_tick == event.tick then return end
      local router = UiRouter.get_router(pindex)
      local p = game.get_player(pindex)
      local stack = p.cursor_stack

      if stack and stack.valid_for_read and stack.valid and stack.prototype.type == "spidertron-remote" then
         -- Toggle selected spidertron on remote
         local entity = EntitySelection.get_first_ent_at_tile(pindex)
         if entity and entity.type == "spider-vehicle" then
            SpidertronRemote.toggle_spidertron(p, entity)
         else
            Speech.speak(pindex, { "fa.spidertron-remote-no-spidertron-selected" })
         end
      elseif stack and stack.valid_for_read and stack.is_upgrade_item then
         -- Open upgrade planner menu (direct only, not in book - book opens book menu)
         router:open_ui(UiRouter.UI_NAMES.UPGRADE_PLANNER)
      elseif stack and stack.valid_for_read and stack.is_deconstruction_item then
         -- Open deconstruction planner menu
         router:open_ui(UiRouter.UI_NAMES.DECON_PLANNER)
      elseif stack and stack.valid_for_read then
         kb_click_hand_right(event)
      else
         -- Empty hand case - read entity status

         kb_read_entity_status(event)
      end
   end
)

EventManager.on_event(
   "fa-a-rightbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- Handle syntrax input when locked to rails in VTD mode
      if VirtualTrainDriving.open_syntrax_input(pindex) then return end

      local p = game.get_player(pindex)
      local stack = p.cursor_stack

      if stack and stack.valid_for_read and stack.prototype.type == "spidertron-remote" then
         SpidertronRemoteSelector.open_spidertron_selector(pindex)
      end
   end
)

EventManager.on_event(
   "fa-s-leftbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if storage.players[pindex].last_click_tick == event.tick then return end
      storage.players[pindex].last_click_tick = event.tick

      local p = game.get_player(pindex)
      local stack = p.cursor_stack

      -- Force build: places through obstacles (auto-landfill)
      if stack and stack.valid_for_read then
         if stack.prototype.type == "spidertron-remote" then
            -- Clear autopilot and set new destination for spidertron remote
            local vp = Viewpoint.get_viewpoint(pindex)
            local cursor_pos = vp:get_cursor_pos()
            SpidertronRemote.add_to_autopilot(p, cursor_pos, true)
            return
         end

         -- Rail planner: lock on with force mode (real or ghost rails)
         if stack.prototype.rails then
            local ent = EntitySelection.get_first_ent_at_tile(pindex)
            local is_rail = ent and ent.valid and Consts.RAIL_TYPES_SET[ent.type]
            local is_ghost_rail = ent
               and ent.valid
               and ent.type == "entity-ghost"
               and Consts.RAIL_TYPES_SET[ent.ghost_type]
            if is_rail or is_ghost_rail then
               VirtualTrainDriving.lock_on_to_rail(pindex, ent, defines.build_mode.forced)
               return
            end
         end

         -- Blueprint force build
         if (stack.is_blueprint and stack.is_blueprint_setup()) or stack.is_blueprint_book then
            local vp = Viewpoint.get_viewpoint(pindex)
            BuildingTools.build_blueprint(
               pindex,
               vp:get_flipped_horizontal(),
               vp:get_flipped_vertical(),
               defines.build_mode.forced
            )
            return
         end

         local proto = stack.prototype
         if proto.place_result or proto.place_as_tile_result then
            -- Force build: places landfill when needed
            local vp = Viewpoint.get_viewpoint(pindex)
            local success = BuildingTools.build_item_in_hand_with_params({
               pindex = pindex,
               building_direction = vp:get_hand_direction(),
               flip_horizontal = vp:get_flipped_horizontal(),
               flip_vertical = vp:get_flipped_vertical(),
               build_mode = defines.build_mode.forced,
            })
            if success then TileReader.read_tile(pindex) end
         else
            -- Item cannot be built
            Speech.speak(pindex, { "fa.cannot-build-item" })
         end
      end
   end
)

---@param event EventData.CustomInputEvent
local function kb_repair_area(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)
   local stack = p.cursor_stack

   storage.players[pindex].last_click_tick = event.tick
   if stack and stack.valid_for_read and stack.valid and stack.is_repair_tool then
      Combat.repair_area(math.ceil(p.reach_distance), pindex)
   end
end

EventManager.on_event(
   "fa-ca-rightbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      KruiseKontrol.activate_kk(pindex)
   end
)

EventManager.on_event(
   "fa-cs-leftbracket",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local player = game.players[pindex]
      local stack = player.cursor_stack
      if not stack.valid_for_read then return end

      -- Rail planner: lock on with superforce mode (real or ghost rails)
      if stack.prototype.rails then
         local ent = EntitySelection.get_first_ent_at_tile(pindex)
         local is_rail = ent and ent.valid and Consts.RAIL_TYPES_SET[ent.type]
         local is_ghost_rail = ent
            and ent.valid
            and ent.type == "entity-ghost"
            and Consts.RAIL_TYPES_SET[ent.ghost_type]
         if is_rail or is_ghost_rail then
            VirtualTrainDriving.lock_on_to_rail(pindex, ent, defines.build_mode.superforced)
            return
         end
      end

      -- Repair tool: repair area
      if stack.is_repair_tool then
         kb_repair_area(event)
         return
      end

      -- Blueprint superforce build
      if (stack.is_blueprint and stack.is_blueprint_setup()) or stack.is_blueprint_book then
         local vp = Viewpoint.get_viewpoint(pindex)
         BuildingTools.build_blueprint(
            pindex,
            vp:get_flipped_horizontal(),
            vp:get_flipped_vertical(),
            defines.build_mode.superforced
         )
         return
      end

      -- Superforce build: replaces existing entities and places landfill
      local proto = stack.prototype
      if proto.place_result or proto.place_as_tile_result then
         local vp = Viewpoint.get_viewpoint(pindex)
         local success = BuildingTools.build_item_in_hand_with_params({
            pindex = pindex,
            building_direction = vp:get_hand_direction(),
            flip_horizontal = vp:get_flipped_horizontal(),
            flip_vertical = vp:get_flipped_vertical(),
            build_mode = defines.build_mode.superforced,
         })
         if success then TileReader.read_tile(pindex) end
      end
   end
)

--Calls function to notify if items are being picked up via vanilla F key.
---@param event EventData.CustomInputEvent
local function kb_read_item_pickup_state(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)

   local p = game.get_player(pindex)
   local result = ""
   local check_last_pickup = false
   local nearby_belts =
      p.surface.find_entities_filtered({ position = p.position, radius = 1.25, type = "transport-belt" })
   local nearby_ground_items =
      p.surface.find_entities_filtered({ position = p.position, radius = 1.25, name = "item-on-ground" })
   --Draw the pickup range
   rendering.draw_circle({
      color = { 0.3, 1, 0.3 },
      radius = 1.25,
      width = 1,
      target = p.position,
      surface = p.surface,
      time_to_live = 60,
      draw_on_ground = true,
   })
   --Check if there is a belt within n tiles
   if #nearby_belts > 0 then
      result = "Picking up "
      --Check contents being picked up
      local ent = nearby_belts[1]
      if ent == nil or not ent.valid then
         result = result .. " from nearby belts"
         Speech.speak(pindex, result)
         return
      end
      local left = TH.nqc_to_sorted_descending(
         TH.rollup2(ent.get_transport_line(1).get_contents(), F.name().get, F.quality().get, F.count().get)
      )
      local right = TH.nqc_to_sorted_descending(
         TH.rollup2(ent.get_transport_line(2).get_contents(), F.name().get, F.quality().get, F.count().get)
      )
      local all = {}
      TH.concat_arrays(left, right)
      -- Rename it, for clarity.
      local all = left
      table.sort(all, function(a, b)
         return a.count > b.count
      end)

      if all[1] then result = result .. all[1].name end
      if all[2] then result = result .. " " .. string.format("and %s", all[2].name) end
      if all[3] then result = result .. " and others" end

      result = result .. " from nearby belts"
      --Check if there are ground items within n tiles
   elseif #nearby_ground_items > 0 then
      result = "Picking up "
      if nearby_ground_items[1] and nearby_ground_items[1].valid then
         result = result .. nearby_ground_items[1].stack.name
      end
      result = result .. " from ground, and possibly more items "
   else
      result = "No items within range to pick up"
   end
   Speech.speak(pindex, result)
end

EventManager.on_event(
   "fa-h",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      BuildingTools.flip_item_in_hand_horizontal(event)
   end
)

EventManager.on_event(
   "fa-f",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_read_item_pickup_state(event)
   end
)

---@param event EventData.CustomInputEvent
local function kb_read_health_and_armor_stats(event)
   local pindex = event.player_index
   local p = game.get_player(pindex)

   local mb = MessageBuilder.new()
   Combat.notify_health_shields(pindex, mb)

   -- For character, also add armor equipment stats
   if not p.driving then
      mb:list_item()
      mb:fragment(Equipment.read_armor_stats(pindex, nil))
   end

   Speech.speak(pindex, mb:build())
end

EventManager.on_event(
   "fa-v",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      BuildingTools.flip_item_in_hand_vertical(event)
   end
)

EventManager.on_event(
   "fa-s-v",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      VehicleCycler.cycle_to_next_vehicle(pindex)
   end
)

EventManager.on_event(
   "fa-g",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_read_health_and_armor_stats(event)
   end
)

--[[
[TRAIN-COUPLE-RESTORE] SHIFT+G (disconnect) and CONTROL+G (connect) used to
exist for coupling rolling stock together, per CHANGES.md: "Changed keybinds
for health checking and train wagon connecting... Press SHIFT + G to
disconnect selected train wagons... Press CONTROL + G to connect selected
train wagons." They were lost (silently, for CONTROL+G; the 0.16.34 entry
"Remove shift+g. This is now in the equipment overview." only explains
SHIFT+G) when the equipment overhaul reclaimed the G-key family, and never
relocated. Restoring them here on the currently-selected entity
(`player.selected`, same concept `kb_mine_access_sounds`/`kb_read_health_and_
armor_stats`-style single-key handlers already read from), using
LuaEntity.connect_rolling_stock/disconnect_rolling_stock(direction). Per
user decision, both defines.rail_direction values (front and back) are
always attempted, since the player has no way to see which end is which -
the result message says which side(s), if any, actually changed.
]]

---@param event EventData.CustomInputEvent
---@param connecting boolean true = try to connect, false = try to disconnect
local function kb_couple_train_wagon(event, connecting)
   local pindex = event.player_index
   local player = game.get_player(pindex)
   local entity = player.selected

   if not entity or not entity.valid or not Consts.ROLLING_STOCK_TYPES[entity.type] then
      sounds.play_ui_edge(pindex)
      Speech.speak(pindex, { "fa.train-couple-no-selection" })
      return
   end

   local check = EntityAccess.can_write_to_entity(pindex, entity)
   if not check.allowed then
      sounds.play_ui_edge(pindex)
      Speech.speak(pindex, check.reason)
      return
   end

   local front_ok, back_ok
   if connecting then
      front_ok = entity.connect_rolling_stock(defines.rail_direction.front)
      back_ok = entity.connect_rolling_stock(defines.rail_direction.back)
   else
      front_ok = entity.disconnect_rolling_stock(defines.rail_direction.front)
      back_ok = entity.disconnect_rolling_stock(defines.rail_direction.back)
   end

   local mb = MessageBuilder.new()
   if front_ok and back_ok then
      mb:fragment({ connecting and "fa.train-coupled-both-sides" or "fa.train-uncoupled-both-sides" })
   elseif front_ok or back_ok then
      mb:fragment({ connecting and "fa.train-coupled-one-side" or "fa.train-uncoupled-one-side" })
   else
      mb:fragment({ connecting and "fa.train-couple-nothing-to-connect" or "fa.train-couple-nothing-to-disconnect" })
   end
   Speech.speak(pindex, mb:build())

   if front_ok or back_ok then
      sounds.play_menu_click(pindex)
   else
      sounds.play_ui_edge(pindex)
   end
end

EventManager.on_event(
   "fa-s-g",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_couple_train_wagon(event, false)
   end
)

EventManager.on_event(
   "fa-c-g",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_couple_train_wagon(event, true)
   end
)

EventManager.on_event(
   "fa-r",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      ---From event rotate-building
      BuildingTools.rotate_item_in_hand(event, true)
   end
)

-- Shift+R: Counterclockwise rotation, or toggle spawners first in combat mode
EventManager.on_event(
   "fa-s-r",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if Combat.is_combat_mode(pindex) then
         AimAssist.toggle_spawners_first(pindex)
      else
         BuildingTools.rotate_item_in_hand(event, false)
      end
   end
)

-- Ctrl+R: Toggle strongest/closest (aim assist)
EventManager.on_event(
   "fa-c-r",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      AimAssist.toggle_healthiest_first(pindex)
   end
)

-- Ctrl+Shift+R: Toggle safe mode (aim assist)
EventManager.on_event(
   "fa-cs-r",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      AimAssist.toggle_safe_mode(pindex)
   end
)

--Called when player rotates an entity on the map
EventManager.on_event(
   defines.events.on_player_rotated_entity,
   ---@param event EventData.on_player_rotated_entity
   function(event)
      BuildingTools.on_entity_rotated(event)
   end
)

--Called when player flips an entity on the map
EventManager.on_event(
   defines.events.on_player_flipped_entity,
   ---@param event EventData.on_player_flipped_entity
   function(event)
      BuildingTools.on_entity_flipped(event)
   end
)

--Reads detailed item info for the item in hand (router handles UI cases via on_read_info)
EventManager.on_event(
   "fa-y",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      -- UI routing is handled automatically by router.lua (line 485)
      -- This is the fallback for when no UI is open
      ItemInfo.read_item_in_hand(pindex)
   end
)

--Read production statistics info for the selected item, in the hand or else selected in the inventory menu
EventManager.on_event(
   "fa-u",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      if game.get_player(pindex).driving then return end
      local str = FaInfo.selected_item_production_stats_info(pindex)
      Speech.speak(pindex, str)
   end
)

EventManager.on_event(
   "fa-s-u",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      FaInfo.read_pollution_level_at_position(Viewpoint.get_viewpoint(pindex):get_cursor_pos(), pindex)
   end
)

--Gives in-game time. The night darkness is from 11 to 13, and peak daylight hours are 18 to 6.
--For realism, if we adjust by 12 hours, we get 23 to 1 as midnight and 6 to 18 as peak solar.
---@param event EventData.CustomInputEvent
local function kb_read_time_and_research_progress(event)
   local pindex = event.player_index
   --Get local time
   local surf = game.get_player(pindex).surface
   local hour = math.floor((24 * surf.daytime + 12) % 24)
   local minute = math.floor((24 * surf.daytime - math.floor(24 * surf.daytime)) * 60)
   local time_string = { "fa.local-time", tostring(hour), string.format("%02d", minute) }

   --Get total playtime
   local total_hours = math.floor(game.tick / 216000)
   local total_minutes = math.floor((game.tick % 216000) / 3600)
   local total_time_string = { "fa.mission-time", tostring(total_hours), tostring(total_minutes) }

   --Add research progress info
   local progress_string = Research.get_progress_string(pindex)

   Speech.speak(pindex, FaUtils.spacecat(time_string, progress_string, total_time_string))
end

EventManager.on_event(
   "fa-t",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_read_time_and_research_progress(event)
   end
)

EventManager.on_event(
   "fa-f1",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      game.auto_save("manual")
      Speech.speak(pindex, { "fa.saving-game-wait" })
   end
)

---@param event EventData.CustomInputEvent
local function kb_toggle_build_lock(event)
   local pindex = event.player_index
   BuildLock.toggle(pindex)
end

--Toggle building while walking
EventManager.on_event(
   "fa-c-b",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_toggle_build_lock(event)
   end
)

EventManager.on_event("fa-cas-v", function(event, pindex)
   local p = game.get_player(pindex)
   local router = UiRouter.get_router(pindex)
   local enabling = not VanillaMode.is_enabled(pindex)

   if enabling then
      -- Speak before toggle so speech still works
      Speech.speak(pindex, { "fa.vanilla-mode-enabled" })
      sounds.play_confirm(pindex)

      VanillaMode.toggle(pindex)

      -- Close any open UI
      router:close_ui()

      -- Exit combat mode if active
      if Combat.is_combat_mode(pindex) then Combat.toggle_combat_mode(pindex) end

      -- Re-enable mouse entity selection
      p.game_view_settings.update_entity_selection = true
   else
      VanillaMode.toggle(pindex)

      -- Disable mouse entity selection
      p.game_view_settings.update_entity_selection = false

      sounds.play_confirm(pindex)
      Speech.speak(pindex, { "fa.vanilla-mode-disabled" })
   end
end)

---@param event EventData.CustomInputEvent
local function kb_toggle_cursor_hiding(event)
   local pindex = event.player_index
   local vp = Viewpoint.get_viewpoint(pindex)
   local cursor_hidden = vp:get_cursor_hidden()
   local p = game.get_player(pindex)
   if cursor_hidden == nil or cursor_hidden == false then
      vp:set_cursor_hidden(true)
      Speech.speak(pindex, { "fa.cursor-hiding-enabled" })
      p.print("Cursor hiding : ON")
   else
      vp:set_cursor_hidden(false)
      Speech.speak(pindex, { "fa.cursor-hiding-disabled" })
      p.print("Cursor hiding : OFF")
   end
end

EventManager.on_event(
   "fa-ca-c",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_toggle_cursor_hiding(event)
   end
)

---nothing else uses this; perhaps merge this into kb_clear_renders
local function clear_renders()
   rendering.clear("FactorioAccess")
   rendering.clear("")
end

---@param event EventData.CustomInputEvent
local function kb_clear_renders(event)
   local pindex = event.player_index
   game.get_player(pindex).gui.screen.clear()
   local vp = Viewpoint.get_viewpoint(pindex)
   vp:set_cursor_ent_highlight_box(nil)
   vp:set_cursor_tile_highlight_box(nil)
   storage.players[pindex].building_footprint = nil
   storage.players[pindex].building_dir_arrow = nil
   storage.players[pindex].overhead_sprite = nil
   storage.players[pindex].overhead_circle = nil
   storage.players[pindex].custom_GUI_frame = nil
   storage.players[pindex].custom_GUI_sprite = nil
   clear_renders()
   Speech.speak(pindex, { "fa.cleared-renders" })
end

EventManager.on_event(
   "fa-ca-r",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      kb_clear_renders(event)
   end
)

EventManager.on_event(
   "fa-mouse-button-3",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      game.get_player(pindex).game_view_settings.update_entity_selection = true
   end
)

-- Q: Pipette tool
EventManager.on_event(
   "fa-q",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      CursorChanges.kb_pipette_tool(event)
   end
)

EventManager.on_event(
   "fa-s-q",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      read_hand(pindex)
   end
)

EventManager.on_event(
   "fa-p",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local router = UiRouter.get_router(pindex)
      router:open_ui(UiRouter.UI_NAMES.WARNINGS)
   end
)

EventManager.on_event(
   "fa-s-p",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      FaInfo.read_nearest_damaged_ent_info(Viewpoint.get_viewpoint(pindex):get_cursor_pos(), pindex)
   end
)

EventManager.on_event(
   "fa-a-v",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      TravelTools.fast_travel_menu_open(pindex)
   end
)

--Toggle whether rockets are launched automatically when they have cargo
EventManager.on_event(
   "fa-c-space",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      Speech.speak(pindex, { "fa.not-implemented-factorio-2" })
   end
)

--Help key and tutorial system DISABLED (tutorial content nonfunctional)
-- Tutorial system module and data left in place as dead code for future work

EventManager.on_event(
   "fa-l",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      local p = game.get_player(pindex)
      if p.character == nil then return end
      if p.driving == false then
         WorkerRobots.logistics_info_key_handler(pindex)
      else
         Driving.pda_read_assistant_toggled_info(pindex)
      end
   end
)

-- Reload mod scripts (control stage only)
-- NOTE: This does NOT reload:
-- - Localizations (locale/*.cfg files)
-- - Prototypes (data.lua, data-updates.lua, data-final-fixes.lua)
-- - Graphics/sounds
-- For a full reload including translations, Factorio must be restarted.
EventManager.on_event("fa-cas-r", function(event, pindex)
   Speech.speak(
      pindex,
      "Reloading mod scripts (control.lua). Note: This does not reload localizations or prototypes. For full reload including translations, restart Factorio."
   )
   game.reload_script()
end)

EventManager.on_event("fa-c-o", function(event)
   Speech.speak(
      event.player_index,
      "Type in the new cruise control speed and press 'ENTER' and then 'E' to confirm, or press 'ESC' to exit"
   )
end)

EventManager.on_event("fa-cas-d", function(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.DEBUG)
end)

EventManager.on_event("fa-cas-m", function(event)
   local pindex = event.player_index
   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.SETTINGS)
end)

-- Toggle combat mode (changes sound reference point from cursor to character)
EventManager.on_event("fa-cs-i", function(event)
   Combat.toggle_combat_mode(event.player_index)
end)

-- Blueprint book navigation at world level (when not in a menu)
---@param pindex integer
---@param offset integer 1 for next, -1 for previous
local function cycle_blueprint_book(pindex, offset)
   local player = game.get_player(pindex)
   if not player then return end

   local cursor_stack = player.cursor_stack
   if not cursor_stack or not cursor_stack.valid_for_read or not cursor_stack.is_blueprint_book then return end

   local book_inv = cursor_stack.get_inventory(defines.inventory.item_main)
   if not book_inv or #book_inv == 0 then
      Speech.speak(pindex, { "fa.blueprint-book-empty" })
      return
   end

   local current = cursor_stack.active_index or 1
   local new_idx = current + offset
   if new_idx < 1 then
      new_idx = #book_inv
   elseif new_idx > #book_inv then
      new_idx = 1
   end

   cursor_stack.active_index = new_idx
   local active_item = book_inv[new_idx]
   if active_item and active_item.valid_for_read then
      Speech.speak(pindex, { "", { "fa.blueprint-book-switched" }, " ", ItemInfo.item_info(active_item) })
   end
end

EventManager.on_event("fa-comma", function(event)
   -- Check for virtual train driving
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end

   local pindex = event.player_index
   local player = game.get_player(pindex)
   if not player then return end

   local cursor_stack = player.cursor_stack
   if not cursor_stack or not cursor_stack.valid_for_read or not cursor_stack.is_blueprint_book then return end

   local book_inv = cursor_stack.get_inventory(defines.inventory.item_main)
   if not book_inv or #book_inv == 0 then
      Speech.speak(pindex, { "fa.blueprint-book-empty" })
      return
   end

   if not cursor_stack.active_index then
      Speech.speak(pindex, { "fa.blueprint-book-no-active" })
      return
   end

   local active_item = book_inv[cursor_stack.active_index]
   if active_item and active_item.valid_for_read then
      Speech.speak(pindex, { "", { "fa.blueprint-book-active" }, " ", ItemInfo.item_info(active_item) })
   else
      Speech.speak(pindex, { "fa.blueprint-book-empty-active" })
   end
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-m", function(event)
   -- Check for virtual train driving
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end

   local pindex = event.player_index
   local player = game.get_player(pindex)
   local stack = player.cursor_stack

   -- Check if wire is in hand
   if stack and stack.valid_for_read then
      local wire_type = stack.name
      if wire_type == "red-wire" or wire_type == "green-wire" or wire_type == "copper-wire" then
         -- Wire in hand - select input/left side
         CircuitNetworks.drag_wire_and_read(pindex, "input")
         return
      elseif stack.prototype.type == "spidertron-remote" then
         SpidertronRemote.cycle_spidertrons(player, -1)
         TileReader.read_tile(pindex)
         return
      end
   end

   cycle_blueprint_book(pindex, -1)
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-dot", function(event)
   -- Check for virtual train driving
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end

   local pindex = event.player_index
   local player = game.get_player(pindex)
   local stack = player.cursor_stack

   -- Check if wire is in hand
   if stack and stack.valid_for_read then
      local wire_type = stack.name
      if wire_type == "red-wire" or wire_type == "green-wire" or wire_type == "copper-wire" then
         -- Wire in hand - select output/right side
         CircuitNetworks.drag_wire_and_read(pindex, "output")
         return
      elseif stack.prototype.type == "spidertron-remote" then
         SpidertronRemote.cycle_spidertrons(player, 1)
         TileReader.read_tile(pindex)
         return
      end
   end

   cycle_blueprint_book(pindex, 1)
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-a-comma", function(event)
   -- Check for virtual train driving
   if VirtualTrainDriving.on_kb_descriptive_action_name(event) then return end
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-slash", function(event)
   -- Check for virtual train driving first
   if VirtualTrainDriving.on_kb_descriptive_action_name(event) then return end

   -- Otherwise, fall through to UI handling (handled by router)
end, EventManager.EVENT_KIND.WORLD)

-- Virtual train signal placement keybindings
EventManager.on_event("fa-c-m", function(event)
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-s-m", function(event)
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-c-dot", function(event)
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-s-dot", function(event)
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end
end, EventManager.EVENT_KIND.WORLD)

-- Dangerous delete: Delete blueprint/decon/upgrade planner from hand, or clear spidertron remote list
EventManager.on_event("fa-c-backspace", function(event)
   local pindex = event.player_index
   local player = game.get_player(pindex)
   if not player then return end

   local cursor_stack = player.cursor_stack
   if not cursor_stack or not cursor_stack.valid_for_read then
      Speech.speak(pindex, { "fa.dangerous-delete-nothing-to-delete" })
      return
   end

   -- Check for spidertron remote
   if cursor_stack.prototype.type == "spidertron-remote" then
      SpidertronRemote.clear_remote(player)
      return
   end

   -- Check if it's a planner item using API flags
   if
      cursor_stack.is_blueprint
      or cursor_stack.is_blueprint_book
      or cursor_stack.is_deconstruction_item
      or cursor_stack.is_upgrade_item
   then
      local item_description = ItemInfo.item_info({
         name = cursor_stack.name,
         count = cursor_stack.count,
         quality = cursor_stack.quality and cursor_stack.quality.name or nil,
      })

      -- Clear the cursor
      cursor_stack.clear()

      Speech.speak(pindex, { "fa.dangerous-delete-deleted", item_description })
   else
      Speech.speak(pindex, { "fa.dangerous-delete-not-planner" })
   end
end, EventManager.EVENT_KIND.WORLD)

-- Clear autopilot for spidertron remote
EventManager.on_event("fa-backspace", function(event)
   -- Check for virtual train driving
   local handled, should_read = VirtualTrainDriving.on_kb_descriptive_action_name(event)
   if handled then
      if should_read then TileReader.read_tile(event.player_index) end
      return
   end

   local pindex = event.player_index
   local player = game.get_player(pindex)
   if not player then return end

   local cursor_stack = player.cursor_stack
   if cursor_stack and cursor_stack.valid_for_read and cursor_stack.prototype.type == "spidertron-remote" then
      SpidertronRemote.clear_autopilot(player)
   end
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-c-l", function(event)
   local pindex = event.player_index
   local player = game.get_player(pindex)
   if not player then return end

   local entity = player.selected
   if not entity or not entity.valid then
      Speech.speak(pindex, { "fa.entity-invalid" })
      return
   end

   -- Check if entity has any logistics support
   local points = entity.get_logistic_point()
   if not points then
      Speech.speak(pindex, { "fa.entity-no-logistics" })
      return
   end

   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.LOGISTICS_CONFIG, { entity = entity })
end)

EventManager.on_event("fa-cs-l", function(event)
   local pindex = event.player_index
   local player = game.get_player(pindex)
   if not player or not player.character then return end

   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.LOGISTICS_CONFIG, { entity = player.character })
end)

EventManager.on_event(
   "fa-kk-cancel",
   ---@param event EventData.CustomInputEvent
   function(event, pindex)
      KruiseKontrol.cancel_kk(pindex)
   end
)

-- Send hand contents to trash: O key
EventManager.on_event("fa-o", function(event)
   local pindex = event.player_index
   local player = game.get_player(pindex)
   if not player or not player.character then return end

   local cursor_stack = player.cursor_stack
   if not cursor_stack or not cursor_stack.valid_for_read then
      Speech.speak(pindex, { "fa.trash-nothing-in-hand" })
      return
   end

   -- Get character's trash inventory
   local trash_inventory = InventoryUtils.find_trash_inventory(player.character)
   if not trash_inventory then
      Speech.speak(pindex, { "fa.trash-not-available" })
      return
   end

   -- Try to insert into trash
   local item_name = cursor_stack.name
   local item_count = cursor_stack.count
   local item_quality = cursor_stack.quality and cursor_stack.quality.name or nil

   local inserted = trash_inventory.insert({ name = item_name, count = item_count, quality = item_quality })

   if inserted > 0 then
      -- Remove from hand
      cursor_stack.count = cursor_stack.count - inserted

      -- Announce success
      local item_description = ItemInfo.item_info({
         name = item_name,
         count = inserted,
         quality = item_quality,
      })
      Speech.speak(pindex, { "fa.trash-sent-to-trash", item_description })

      if inserted < item_count then Speech.speak(pindex, { "fa.trash-full", tostring(item_count - inserted) }) end
   else
      Speech.speak(pindex, { "fa.trash-full-none-inserted" })
   end
end, EventManager.EVENT_KIND.WORLD)

-- Virtual train driving keys
-- TODO: Add these key definitions to data.lua
-- EventManager.on_event("fa-slash", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- EventManager.on_event("fa-alt-comma", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- EventManager.on_event("fa-shift-b", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- EventManager.on_event("fa-ctrl-m", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- EventManager.on_event("fa-ctrl-dot", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- EventManager.on_event("fa-shift-m", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- EventManager.on_event("fa-shift-dot", function(event)
--    VirtualTrainDriving.on_kb_descriptive_action_name(event)
-- end, EventManager.EVENT_KIND.WORLD)

-- Zoom controls (WORLD priority so UI bar handlers take precedence)
EventManager.on_event("fa-minus", function(event, pindex)
   Zoom.zoom_out(pindex)
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-equals", function(event, pindex)
   Zoom.zoom_in(pindex)
end, EventManager.EVENT_KIND.WORLD)

EventManager.on_event("fa-a-z", function(event, pindex)
   local mb = MessageBuilder.new()

   -- Add zoom info
   Zoom.append_zoom_info(pindex, mb)

   -- Add weapon info
   local gun_name, gun_proto = PlayerWeapon.get_selected_gun(pindex)
   if gun_name and gun_proto then
      mb:list_item()
      mb:fragment(gun_proto.localised_name)

      local ammo_name, ammo_proto = PlayerWeapon.get_selected_ammo(pindex)
      if ammo_name and ammo_proto then mb:fragment({ "fa.zoom-weapon-with-ammo", ammo_proto.localised_name }) end

      local max_range = PlayerWeapon.get_max_range(pindex)
      local soft_min = PlayerWeapon.get_soft_min_range(pindex)

      if soft_min and max_range then
         mb:fragment({ "fa.zoom-weapon-range-with-min", soft_min, max_range })
      elseif max_range then
         mb:fragment({ "fa.zoom-weapon-range", max_range })
      end
   else
      mb:list_item({ "fa.zoom-no-weapon" })
   end

   Speech.speak(pindex, mb:build())
end, EventManager.EVENT_KIND.WORLD)
