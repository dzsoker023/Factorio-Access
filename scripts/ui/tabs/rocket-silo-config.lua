--[[
Rocket silo configuration tab.

Provides controls for:
- Rocket parts progress (read-only label)
- Launching the rocket's cargo/pilot to an existing space platform
- Creating a new space platform from a starter pack loaded in the silo
- Auto-launch and orbit-request settings
]]

local FormBuilder = require("scripts.ui.form-builder")
local UiKeyGraph = require("scripts.ui.key-graph")
local Router = require("scripts.ui.router")
local UiSounds = require("scripts.ui.sounds")
local PlatformSelector = require("scripts.ui.selectors.platform-selector")

---Apply the starter pack currently loaded in the silo's rocket to create a
---new space platform.
---@param name string
---@param silo LuaEntity
---@return LuaSpacePlatform?
local function new_platform_from_silo(name, silo)
   local inventory = silo.get_inventory(defines.inventory.rocket_silo_rocket)
   local pack = nil
   for _, item in pairs(inventory.get_contents()) do
      if prototypes.item[item.name].type == "space-platform-starter-pack" then
         pack = item
         break
      end
   end
   if not pack then return nil end

   return silo.force.create_space_platform({
      name = name,
      planet = silo.surface.planet.name,
      starter_pack = pack,
   })
end

---Whether either of the silo's rocket-cargo inventories currently weighs more
---than the rocket can lift. There are two: rocket_silo_rocket (rocket parts /
---starter pack, built up while the rocket is under construction) and
---rocket_silo_attached_cargo_unit (the separate cargo pod attached once the
---rocket is ready - see defines.inventory.rocket_silo_attached_cargo_unit).
---Both are weight-restricted, not slot-restricted, once the silo can launch to
---space platforms - LuaInventory.max_weight is only present on this kind of
---weight-limited inventory, so its absence means there's no weight cap to
---check (e.g. a non-platform-launching rocket silo).
---Kept as defense-in-depth even though the main way to overload the rocket
---(manually inserting via the generic "Rocket Cargo" inventory tab for the
---attached cargo unit) has been closed off in entity-ui.lua - see
---BLOCKED_GENERIC_INVENTORY_NAMES there.
---@param silo LuaEntity
---@return boolean
local function rocket_is_overloaded(silo)
   local inv_types = { defines.inventory.rocket_silo_rocket, defines.inventory.rocket_silo_attached_cargo_unit }
   for _, inv_type in ipairs(inv_types) do
      -- inv_type can be nil if this define doesn't exist on the running game
      -- version (rocket_silo_attached_cargo_unit is newer than some 2.x
      -- releases) - get_inventory(nil) would error, so skip it.
      if inv_type then
         local inventory = silo.get_inventory(inv_type)
         if inventory and inventory.max_weight and inventory.weight > inventory.max_weight then return true end
      end
   end
   return false
end

-- [LAUNCH-PLAYER-INVENTORY-CHECK] Whether a character is carrying anything
-- vanilla's own "Travel to platform" launch does not allow along. Per the
-- official wiki (wiki.factorio.com/Rocket_silo, "Travel to platform"):
-- "the rocket will launch to any orbiting platform with the player as its
-- sole payload. The player can only bring any equipped armor, their
-- installed modules, and any weapons, but no ammo for those weapons." So
-- the main inventory ("pockets") and any loaded ammo must be empty before
-- launching; equipped armor (with its own equipment grid/modules) and
-- weapons (character_guns) are always allowed and are NOT checked here.
--
-- `LuaEntity.launch_rocket` - the underlying script API this mod calls to
-- launch a player - does not enforce this restriction itself; per its own
-- API doc it only takes an optional `character` parameter and returns
-- whether the launch happened, nothing about what that character is
-- carrying. This is a vanilla GUI-side precondition, not something the
-- game engine blocks on its own when called from a script - so without
-- this check, a player could click "launch self" here with a full main
-- inventory and reach a state the real "Travel to platform" button would
-- never have allowed in the first place. Reported live: launching self
-- worked even with items on hand, which the user correctly identified as
-- this mod skipping a check vanilla's own UI performs.
--
-- Exception: blueprints, blueprint books, deconstruction planners, and
-- upgrade planners are allowed to stay in the main inventory without
-- blocking the launch. These tools are really references into the
-- player's personal Blueprint Library - accessible from anywhere, not
-- tied to physically holding a copy - rather than ordinary cargo, and
-- the scripting API gives us no way to check whether a given blueprint-
-- type item's contents are already safely stored there. Being strict
-- about them here would just be needless friction with no real
-- consistency benefit, so they're exempt.
local LAUNCH_ALLOWED_MAIN_INVENTORY_ITEM_TYPES = {
   ["blueprint"] = true,
   ["blueprint-book"] = true,
   ["deconstruction-item"] = true,
   ["upgrade-item"] = true,
}

---Whether the main inventory contains anything other than the exempt
---blueprint-library tool types above.
---@param main_inv LuaInventory
---@return boolean
local function main_inventory_has_blocking_items(main_inv)
   -- get_contents() returns an array of {name, count, quality} entries
   -- (see new_platform_from_silo above for the same iteration pattern).
   for _, entry in pairs(main_inv.get_contents()) do
      local proto = prototypes.item[entry.name]
      local item_type = proto and proto.type
      if not (item_type and LAUNCH_ALLOWED_MAIN_INVENTORY_ITEM_TYPES[item_type]) then return true end
   end
   return false
end

---@param character LuaEntity
---@return boolean
local function character_has_unlaunchable_items(character)
   local main_inv = character.get_inventory(defines.inventory.character_main)
   if main_inv and not main_inv.is_empty() and main_inventory_has_blocking_items(main_inv) then return true end

   local ammo_inv = character.get_inventory(defines.inventory.character_ammo)
   if ammo_inv and not ammo_inv.is_empty() then return true end

   return false
end

local mod = {}

---Render the rocket silo configuration form
---@param ctx fa.ui.graph.Ctx
---@return fa.ui.graph.Render?
local function render_rocket_silo_config(ctx)
   local entity = ctx.tablist_shared_state.entity
   if not entity or not entity.valid then return nil end

   local form = FormBuilder.FormBuilder.new()

   -- Rocket parts progress label
   form:add_label("rocket_parts", function(ctx)
      local parts = entity.rocket_parts
      local max_parts = entity.prototype.rocket_parts_required
      ctx.message:fragment({ "fa.rocket-silo-parts-progress", parts, max_parts })
   end)

   form:start_row("controls")

   form:add_item("launch_item", {
      label = function(ctx)
         ctx.message:fragment({ "fa.rocket-silo-launch-item" })
      end,
      on_click = function(ctx)
         if PlatformSelector.has_available_platform(entity.force, entity.surface) then
            ctx.controller:open_child_ui(Router.UI_NAMES.PLATFORM_SELECTOR, { ent = entity }, { node = "launch_item" })
         else
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-no-platforms-available" })
         end
      end,
      on_child_result = function(ctx, result)
         if result == nil then return end

         if rocket_is_overloaded(entity) then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-overloaded" })
            return
         end

         -- result is the target platform's hub entity (see platform-selector.lua)
         local target = { type = defines.cargo_destination.station, station = result }
         -- launch_rocket returns whether the launch actually happened - don't
         -- assume success and announce a launch that didn't occur.
         if entity.launch_rocket(target) then
            ctx.controller.message:fragment({ "fa.rocket-silo-launching-to", result.surface.platform.name })
            -- Close back to the game on a successful launch, so a stray extra
            -- press of the same button (or accidentally reopening this tab)
            -- can't immediately re-trigger another launch.
            ctx.controller:close()
         else
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-launch-failed" })
         end
      end,
   })

   form:add_item("launch_player", {
      label = function(ctx)
         ctx.message:fragment({ "fa.rocket-silo-launch-player" })
      end,
      on_click = function(ctx)
         -- Launching yourself requires actually being there - remote view (or any
         -- other non-physical controller) lets you interact with this entity's UI
         -- from anywhere, but there's no character present at the silo to put in
         -- the rocket. controller_type == character means the player is normally,
         -- physically embodied (see the ghost-placement remote/character gating
         -- for the same distinction elsewhere in the mod).
         local player = game.get_player(ctx.pindex)
         if not player or player.controller_type ~= defines.controllers.character then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-must-be-present-to-launch-self" })
            return
         end

         -- [LAUNCH-PLAYER-INVENTORY-CHECK] See the helper's comment above -
         -- vanilla only lets a launching player bring equipped armor,
         -- modules, and weapons; no main-inventory items or ammo.
         if player.character and character_has_unlaunchable_items(player.character) then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-must-empty-inventory-to-launch-self" })
            return
         end

         if PlatformSelector.has_available_platform(entity.force, entity.surface) then
            ctx.controller:open_child_ui(Router.UI_NAMES.PLATFORM_SELECTOR, { ent = entity }, { node = "launch_player" })
         else
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-no-platforms-available" })
         end
      end,
      on_child_result = function(ctx, result)
         local player = game.get_player(ctx.pindex)
         if not player or result == nil then return end

         -- Re-check: the player could have switched to remote view (or otherwise
         -- left their body) while the platform selector was open.
         if player.controller_type ~= defines.controllers.character then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-must-be-present-to-launch-self" })
            return
         end

         -- [LAUNCH-PLAYER-INVENTORY-CHECK] Re-check too: the player could have
         -- picked something up (or been given items) while the platform
         -- selector was open.
         if player.character and character_has_unlaunchable_items(player.character) then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-must-empty-inventory-to-launch-self" })
            return
         end

         if rocket_is_overloaded(entity) then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-overloaded" })
            return
         end

         local target = { type = defines.cargo_destination.station, station = result }
         -- launch_rocket returns whether the launch actually happened - don't
         -- assume success and announce a launch that didn't occur.
         if entity.launch_rocket(target, player.character) then
            ctx.controller.message:fragment({ "fa.rocket-silo-launching-to", result.surface.platform.name })
            -- Close back to the game on a successful launch (this one launches the
            -- player themselves!) so a stray extra press can't queue up another one.
            ctx.controller:close()
         else
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.rocket-silo-launch-failed" })
         end
      end,
   })

   form:end_row()

   form:add_item("create_platform", {
      label = function(ctx)
         ctx.message:fragment({ "fa.rocket-silo-create-platform" })
      end,
      on_click = function(ctx)
         ctx.controller:open_textbox("", "create_platform")
      end,
      on_child_result = function(ctx, result)
         if not result or result == "" then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.locomotive-name-cannot-be-empty" })
         else
            local new_platform = new_platform_from_silo(result, entity)
            if new_platform then
               ctx.controller.message:fragment(result)
            else
               UiSounds.play_ui_edge(ctx.pindex)
               ctx.controller.message:fragment({ "fa.rocket-silo-no-starter-pack" })
            end
         end
      end,
   })

   -- Auto-launch checkbox
   form:add_checkbox("auto_launch", { "fa.rocket-silo-auto-launch" }, function()
      return entity.send_to_orbit_automatically
   end, function(value)
      entity.send_to_orbit_automatically = value
   end)

   form:add_checkbox("auto_satisfy_requests", { "fa.rocket-silo-satisfy-requests" }, function()
      return entity.use_transitional_requests
   end, function(value)
      entity.use_transitional_requests = value
   end)

   return form:build()
end

-- Create the tab descriptor
mod.rocket_silo_config_tab = UiKeyGraph.declare_graph({
   name = "rocket-silo-config",
   title = { "fa.rocket-silo-config-title" },
   render_callback = render_rocket_silo_config,
})

---Check if this tab is available for the given entity
---@param entity LuaEntity
---@return boolean
function mod.is_available(entity)
   return entity.type == "rocket-silo"
end

return mod
