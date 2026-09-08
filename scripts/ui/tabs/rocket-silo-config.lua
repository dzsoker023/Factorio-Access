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

---Whether the force has any built platforms (force.platforms is a dictionary,
---not an array, so this can't just check #platforms)
---@param force LuaForce
---@return boolean
local function force_has_platforms(force)
   return next(force.platforms) ~= nil
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
         if force_has_platforms(entity.force) then
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

         if force_has_platforms(entity.force) then
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
