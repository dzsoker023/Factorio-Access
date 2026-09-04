--[[
Rocket silo configuration tab.

Provides controls for:
- Rocket parts progress (read-only label)
- Auto-launch setting
]]

local FormBuilder = require("scripts.ui.form-builder")
local UiKeyGraph = require("scripts.ui.key-graph")
local Router = require("scripts.ui.router")
local UiSounds = require("scripts.ui.sounds")

local function new_platform_from_silo(name,silo)
   local inventory=silo.get_inventory(defines.inventory.rocket_silo_rocket)
   local pack = nil
   for _,i in pairs(inventory.get_contents()) do
      if prototypes.item[i.name].type == 'space-platform-starter-pack' then
         pack = i
         break
      end
   end
   if not pack then
      UiSounds.play_ui_edge(ctx.pindex)
      ctx.controller.message:fragment("no platform starter pack found. ")

   end
   local args={
      name = name,
      planet = silo.surface.planet.name,
      starter_pack=pack
   }
   silo.force.create_space_platform(args)
end

local mod = {}


---Render the rocket silo configuration form
---@param ctx fa.ui.TabContext
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
         local player = game.get_player(ctx.pindex)
         if not player then return end
         ctx.message:fragment("launch item")
      end,
      on_click = function(ctx)
         local player = game.get_player(ctx.pindex)
         if not player then return end

         local platforms = entity.force.platforms
         if #platforms > 0 then
            ctx.controller:open_child_ui(Router.UI_NAMES.PLATFORM_SELECTOR, {ent = entity }, { node = "launch_item" })
         else
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.locomotive-no-groups-available" })
         end
      end,
      on_child_result = function(ctx, result)
         if result ~= nil then

            local target = {defines.cargo_destination.station, result}
            ctx.controller.message:fragment({ "fa.locomotive-group-set", result.name })
            ent.launch_rocket(target)
         end
      end,
   })

   form:add_item("launch_player", {
      label = function(ctx)
         local player = game.get_player(ctx.pindex)
         if not player then return end
         ctx.message:fragment("launch_player")
      end,
      on_click = function(ctx)
         local player = game.get_player(ctx.pindex)
         if not player then return end

         local platforms = entity.force.platforms
         if #platforms > 0 then
            ctx.controller:open_child_ui(Router.UI_NAMES.PLATFORM_SELECTOR, {ent = entity }, { node = "launch_player" })
         else
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.locomotive-no-groups-available" })
         end
      end,
      on_child_result = function(ctx, result)
         local player = game.get_player(ctx.pindex)
         if not player then return end
         if result ~= nil then

            local target = {type = defines.cargo_destination.station, station = result}
            ctx.controller.message:fragment({ "fa.locomotive-group-set", result.name })
            entity.launch_rocket(target, player.character)
         end
      end,
   })

   form:end_row()

   form:add_item("create_platform", {
      label = function(ctx)
         ctx.message:fragment("Create platform")
      end,
      on_click = function(ctx)
         ctx.controller:open_textbox("", "create_platform")
      end,
      on_child_result = function(ctx, result)
         if not result or result == "" then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.locomotive-name-cannot-be-empty" })
         else
            new_platform_from_silo(result,entity)
            ctx.controller.message:fragment(result)
         end
      end,
   })

   -- Auto-launch checkbox
   form:add_checkbox("auto_launch", { "fa.rocket-silo-auto-launch" }, function()
      return entity.send_to_orbit_automatically
   end, function(value)
      entity.send_to_orbit_automatically = value
   end)
   
   form:add_checkbox("auto_satisfy_requests", "satisfy requests from orbit", function()
      return entity.use_transitional_requests
   end, function(value)
      entity.use_transitional_requests= value
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
