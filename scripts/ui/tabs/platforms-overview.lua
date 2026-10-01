--[[
Platforms overview tab for the main (world) menu.

Mirrors trains-overview.lua's pattern: one row per space platform, with a
main clickable (opens the platform's own configuration tab - see
platform-config.lua), a "move cursor" action, and a manual/automatic mode
checkbox.

Unlike trains, there's no "surface" split (a platform IS its own surface,
so "platforms on my current surface" isn't a meaningful distinct list) -
just one tab listing every platform belonging to the player's force.
]]

local Menu = require("scripts.ui.menu")
local KeyGraph = require("scripts.ui.key-graph")
local Controls = require("scripts.ui.controls")
local EntityUi = require("scripts.ui.entity-ui")
local Viewpoint = require("scripts.viewpoint")
local Graphics = require("scripts.graphics")
local Router = require("scripts.ui.router")
local UiSounds = require("scripts.ui.sounds")

local mod = {}

-- [PLATFORMS-NEW-BUTTON] "New Platform" button (github issue #285): lets the
-- player pick a planet and a name from this world-menu tab and submits the
-- platform-creation request, instead of requiring them to first navigate to
-- a specific already-built rocket silo and open ITS config tab (the only way
-- to do this before - see rocket-silo-config.lua's create_platform item).
--
-- [PLATFORMS-NEW-BUTTON-V2] First version of this button required a rocket
-- silo on the chosen planet with a starter pack ALREADY physically loaded,
-- reasoning that LuaForce.create_space_platform's starter_pack argument
-- meant a real, already-in-hand item was mandatory. The user pointed out
-- this isn't how vanilla actually works - per the Factorio wiki's Space
-- platform page, "players may order the creation of a space platform from
-- the remote view [...] in which case the necessary space platform starter
-- pack is treated as a REQUEST from a not-yet-existing space platform around
-- the specified planet" - i.e. vanilla itself lets you request a platform
-- for a planet with NO silo involved at all, and fulfills the request later
-- via the normal logistics network. Confirmed this is real (not GUI-only)
-- scripting behavior via the API docs: `starter_pack`'s type
-- (ItemWithQualityID) accepts a plain item NAME string, not just a real
-- LuaItemStack/inventory entry - and `defines.space_platform_state` has
-- dedicated values for exactly this in-between state
-- (waiting_for_starter_pack / starter_pack_requested /
-- starter_pack_on_the_way), plus LuaSpacePlatform:apply_starter_pack()
-- ("Applies the starter pack [...] if it hasn't already been applied") and
-- LuaSpacePlatform.hub being explicitly optional ("does not exist if the
-- platform has not had the starter pack applied"). So a platform created
-- this way is a REAL LuaSpacePlatform object from the moment
-- create_space_platform returns - just one without a hub yet, requesting
-- its starter pack the normal way (its hub's space_platform_hub_requester
-- logistic point) exactly like a requester chest - and the engine finishes
-- creating it (materializes the hub) once that request is fulfilled. No
-- rocket silo needs to exist anywhere for this - it's genuinely
-- silo-independent, matching what the player described. This replaces the
-- whole silo-scanning approach (find_eligible_silo etc.) from V1 - it's not
-- needed at all anymore.
--
-- Because a fresh request has no hub yet, it can't appear in the normal
-- per-platform rows below (those all key off hub.unit_number/hub.position).
-- build_pending_platform_rows below adds a second, separate section for
-- these - the player should be able to SEE a request they just submitted is
-- registered and check on/cancel it, not just wait and hope.

---Find an item prototype name for the space-platform-starter-pack TYPE
---(there's exactly one in vanilla, "space-platform-starter-pack" itself) -
---looked up by type rather than hardcoded by name, the same defensive
---pattern rocket-silo-config.lua's own starter-pack lookup already uses, in
---case a compatibility mod ever adds an alternate one.
---@return string? item_name
local function find_starter_pack_item_name()
   for name, item in pairs(prototypes.item) do
      if item.type == "space-platform-starter-pack" then return name end
   end
   return nil
end

---Human-readable label for the pending (hub-less) states a freshly requested
---platform passes through. Only these three are reachable on a hub-less
---platform - the rest of defines.space_platform_state (on_the_path, paused,
---etc.) only apply once a hub/schedule exists.
---@type table<defines.space_platform_state, LocalisedString>
local PENDING_STATE_LABELS = {
   [defines.space_platform_state.waiting_for_starter_pack] = { "fa.platforms-overview-pending-waiting" },
   [defines.space_platform_state.starter_pack_requested] = { "fa.platforms-overview-pending-requested" },
   [defines.space_platform_state.starter_pack_on_the_way] = { "fa.platforms-overview-pending-on-the-way" },
}

---@param state defines.space_platform_state
---@return LocalisedString
local function pending_state_label(state)
   return PENDING_STATE_LABELS[state] or { "fa.platforms-overview-pending-waiting" }
end

---Add the "New Platform" row: click opens the planet selector, then a name
---textbox, then submits the request. Uses the two-step on_child_result
---pattern (see logistic-group-selector.lua for the single-step version this
---builds on) - child_context.step distinguishes "we just got a planet back"
---from "we just got a name back", since both child dialogs report back to
---this same node.
---@param builder fa.ui.menu.MenuBuilder
local function build_new_platform_row(builder)
   builder:add_clickable("new_platform", function(ctx)
      ctx.message:fragment({ "fa.platforms-overview-new-platform" })
   end, {
      on_click = function(ctx)
         -- Fail fast on preconditions that don't depend on which planet is
         -- picked, rather than letting the player pick a planet and type a
         -- name only to be told at the very end it was never possible.
         local player = game.get_player(ctx.pindex)
         if not player.force.is_space_platforms_unlocked() then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.platforms-overview-not-unlocked" })
            return
         end
         if not find_starter_pack_item_name() then
            UiSounds.play_ui_edge(ctx.pindex)
            ctx.controller.message:fragment({ "fa.platforms-overview-no-starter-pack-item" })
            return
         end

         ctx.controller:open_child_ui(Router.UI_NAMES.PLANET_SELECTOR, {}, { node = "new_platform", step = "planet" })
      end,
      on_child_result = function(ctx, result)
         local step = ctx.child_context and ctx.child_context.step
         if step == "planet" then
            if result == nil then return end -- selector was closed without picking anything
            ctx.controller:open_textbox("", { node = "new_platform", step = "name", planet = result })
         elseif step == "name" then
            if not result or result == "" then
               UiSounds.play_ui_edge(ctx.pindex)
               ctx.controller.message:fragment({ "fa.platform-name-cannot-be-empty" })
               return
            end

            local player = game.get_player(ctx.pindex)
            -- Re-resolve the item name rather than trusting the on_click
            -- check still holds - unlikely to change mid-dialog, but cheap
            -- to re-verify and avoids trusting stale state.
            local pack_name = find_starter_pack_item_name()
            if not pack_name then
               UiSounds.play_ui_edge(ctx.pindex)
               ctx.controller.message:fragment({ "fa.platforms-overview-no-starter-pack-item" })
               return
            end

            local new_platform = player.force.create_space_platform({
               name = result,
               planet = ctx.child_context.planet,
               starter_pack = pack_name,
            })

            if new_platform then
               ctx.controller.message:fragment({ "fa.platforms-overview-created", result })
            else
               UiSounds.play_ui_edge(ctx.pindex)
               ctx.controller.message:fragment({ "fa.platforms-overview-create-failed" })
            end
         end
      end,
   })
end

---Get this force's platforms as a sorted array (by name, then hub unit_number for ties)
---@param force LuaForce
---@return LuaSpacePlatform[]
local function get_sorted_platforms(force)
   local platforms = {}
   for _, platform in pairs(force.platforms) do
      -- Defensive: a platform should always have a hub once created, but
      -- don't let a transient/edge-case nil hub crash this list.
      if platform.hub and platform.hub.valid then table.insert(platforms, platform) end
   end
   table.sort(platforms, function(a, b)
      if a.name ~= b.name then return a.name < b.name end
      return a.hub.unit_number < b.hub.unit_number
   end)
   return platforms
end

---Build platform rows
---@param builder fa.ui.menu.MenuBuilder
---@param platforms LuaSpacePlatform[]
local function build_platform_rows(builder, platforms)
   for _, platform in ipairs(platforms) do
      local hub = platform.hub
      local hub_id = hub.unit_number

      builder:start_row("platform")

      -- Main platform info (click to open the platform's configuration tab)
      builder:add_clickable("platform-" .. hub_id, function(ctx)
         local name = platform.name ~= "" and platform.name or { "fa.empty" }
         ctx.message:fragment(name)
         if platform.space_location then
            ctx.message:fragment({ "fa.platform-at-location", platform.space_location.localised_name })
         elseif platform.space_connection then
            ctx.message:fragment({ "fa.platform-in-transit", platform.space_connection.localised_name })
         else
            ctx.message:fragment({ "fa.platform-location-unknown" })
         end
         ctx.message:fragment({ "fa.platforms-overview-click-to-open" })
      end, {
         on_click = function(ctx)
            ctx.controller:close()
            EntityUi.open_entity_ui(ctx.pindex, hub)
         end,
      })

      -- Move cursor action
      builder:add_clickable("cursor-" .. hub_id, function(ctx)
         ctx.message:fragment({ "fa.platforms-overview-move-cursor" })
      end, {
         on_click = function(ctx)
            local vp = Viewpoint.get_viewpoint(ctx.pindex)
            vp:set_cursor_pos(hub.position)
            Graphics.draw_cursor_highlight(ctx.pindex, nil, nil)
            local name = platform.name ~= "" and platform.name or { "fa.empty" }
            ctx.message:fragment({ "fa.platforms-overview-cursor-moved", name })
         end,
      })

      -- Manual/automatic mode checkbox (paused thrust = manual mode, same concept as locomotive.manual_mode)
      builder:add_item(
         "manual-" .. hub_id,
         Controls.checkbox({
            label = { "fa.platforms-overview-manual-mode" },
            get = function()
               return platform.paused
            end,
            set = function(v)
               platform.paused = v
            end,
         })
      )

      builder:end_row()
   end
end

-- [PLATFORMS-NEW-BUTTON-V2] Platforms this force has REQUESTED but that
-- haven't materialized a hub yet (see the big comment above
-- build_new_platform_row) - get_sorted_platforms above deliberately excludes
-- these (everything in build_platform_rows needs a real hub), so they need
-- their own list and their own row layout.
---Get this force's still-pending (hub-less) platforms, sorted by name then index.
---@param force LuaForce
---@return LuaSpacePlatform[]
local function get_pending_platforms(force)
   local pending = {}
   for _, platform in pairs(force.platforms) do
      if not (platform.hub and platform.hub.valid) then table.insert(pending, platform) end
   end
   table.sort(pending, function(a, b)
      if a.name ~= b.name then return a.name < b.name end
      return a.index < b.index
   end)
   return pending
end

---Build rows for pending (hub-less) platforms: name + current wait state,
---with Ctrl+Backspace to cancel the request (LuaSpacePlatform:destroy works
---even without a hub - "Schedules this space platform for deletion").
---Nothing to click-to-open or move the cursor to yet, since there's no hub
---and no position - clicking just re-announces (the on_click->label
---fallback in key-graph.lua already does this with no handler needed).
---@param builder fa.ui.menu.MenuBuilder
---@param pending LuaSpacePlatform[]
local function build_pending_platform_rows(builder, pending)
   for _, platform in ipairs(pending) do
      local idx = platform.index
      builder:add_clickable("pending-" .. idx, function(ctx)
         local name = platform.name ~= "" and platform.name or { "fa.empty" }
         ctx.message:fragment(name)
         ctx.message:fragment(pending_state_label(platform.state))
      end, {
         on_dangerous_delete = function(ctx)
            local name = platform.name ~= "" and platform.name or { "fa.empty" }
            platform.destroy()
            UiSounds.play_menu_move(ctx.pindex)
            ctx.controller.message:fragment({ "fa.platforms-overview-pending-cancelled", name })
         end,
      })
   end
end

---Render the platforms tab
---@param ctx fa.ui.graph.Ctx
---@return fa.ui.graph.Render?
local function render_platforms(ctx)
   local builder = Menu.MenuBuilder.new()
   local player = game.get_player(ctx.pindex)
   if not player then return builder:add_label("error", { "fa.platforms-overview-error" }):build() end

   local platforms = get_sorted_platforms(player.force)
   local pending = get_pending_platforms(player.force)

   if #platforms == 0 and #pending == 0 then
      builder:add_label("empty", { "fa.platforms-overview-no-platforms" })
   else
      build_platform_rows(builder, platforms)
      build_pending_platform_rows(builder, pending)
   end

   -- [PLATFORMS-NEW-BUTTON] Always present, even with zero existing
   -- platforms - that's exactly the situation where a player most wants it.
   build_new_platform_row(builder)

   return builder:build()
end

-- Tab for all platforms
mod.all_platforms_tab = KeyGraph.declare_graph({
   name = "all_platforms",
   title = { "fa.platforms-overview-all-title" },
   render_callback = render_platforms,
})

return mod
