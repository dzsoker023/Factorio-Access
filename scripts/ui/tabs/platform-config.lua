--[[
Space platform hub configuration tab.

Provides a configuration form for space platform hubs with:
- Manual/automatic mode toggle (pauses thrust, halts the schedule)
- Platform name
- Schedule editing, shared with the locomotive schedule editor
- Platform location/travel and damage status
- Landing the current player on the platform's current planet
]]

local FormBuilder = require("scripts.ui.form-builder")
local UiKeyGraph = require("scripts.ui.key-graph")
local Router = require("scripts.ui.router")
local UiSounds = require("scripts.ui.sounds")

local mod = {}

---@class fa.ui.PlatformTabContext: fa.ui.TabContext
---@field tablist_shared_state fa.ui.EntityUI.SharedState

---Render the space platform hub configuration form
---@param ctx fa.ui.PlatformTabContext
---@return fa.ui.graph.Render?
local function render_platform_config(ctx)
   local entity = ctx.tablist_shared_state.entity
   if not entity or not entity.valid then return nil end
   assert(entity.type == "space-platform-hub", "render: entity is not a space platform hub")

   local platform = entity.surface and entity.surface.platform
   if not platform then return nil end

   local builder = FormBuilder.FormBuilder.new()

   -- Platform name field
   builder:add_item("name", {
      label = function(ctx)
         local name = platform.name
         local value_text = name ~= "" and name or { "fa.empty" }
         ctx.message:fragment(value_text)
         ctx.message:fragment({ "fa.platform-name" })
      end,
      on_click = function(ctx)
         ctx.controller:open_textbox(platform.name or "", "name")
      end,
      on_child_result = function(ctx, result)
         if not result or result == "" then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.platform-name-cannot-be-empty" })
         else
            platform.name = result
            ctx.controller.message:fragment(result)
         end
      end,
   })

   builder:start_row("controls")

   -- Manual/automatic mode checkbox (paused thrust = manual mode, same concept as locomotive.manual_mode)
   builder:add_checkbox("manual_mode", { "fa.platform-manual-mode" }, function()
      return platform.paused
   end, function(value)
      platform.paused = value
   end)

   -- Edit schedule button, shared with locomotives (see schedule-editor.lua)
   builder:add_action("edit_schedule", { "fa.platform-edit-schedule" }, function(controller)
      controller:open_child_ui(Router.UI_NAMES.SCHEDULE_EDITOR, { entity = entity })
   end)

   builder:end_row()

   -- Land the current player on the platform's current planet, if any
   builder:add_item("land_on_planet", {
      label = function(ctx)
         ctx.message:fragment({ "fa.platform-land-on-planet" })
      end,
      on_click = function(ctx)
         local player = game.get_player(ctx.pindex)
         if not player then return end

         local landed = player.land_on_planet()
         if not landed then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.platform-cannot-land" })
         end
      end,
   })

   -- Status label: current/last known location and travel state
   builder:add_label("location", function(label_ctx)
      local location = platform.space_location
      if location then
         label_ctx.message:fragment({ "fa.platform-at-location", location.localised_name })
      elseif platform.space_connection then
         label_ctx.message:fragment({ "fa.platform-in-transit", platform.space_connection.localised_name })
      else
         label_ctx.message:fragment({ "fa.platform-location-unknown" })
      end
   end)

   -- Damage label: how many of the platform's foundation tiles are currently damaged
   builder:add_label("damage", function(label_ctx)
      label_ctx.message:fragment({ "fa.platform-damaged-tiles", #platform.damaged_tiles })
   end)

   return builder:build()
end

-- Create the tab descriptor
mod.platform_config_tab = UiKeyGraph.declare_graph({
   name = "platform-config",
   title = { "fa.platform-config-title" },
   render_callback = render_platform_config,
})

return mod
