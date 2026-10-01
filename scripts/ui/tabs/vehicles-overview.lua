--[[
Vehicles overview tabs for the world menu (Alt+W).

Mirrors trains-overview.lua's pattern: two tabs (surface vehicles / all
vehicles), one row per vehicle, each row showing name/position/occupancy
plus a "Drive" action.

Scope: entity type "car" only - this covers both the vanilla "car" and
"tank" prototypes (and any mod-added vehicle that shares that type), which
is what the user asked about ("a tankok"). Spidertrons (type
"spider-vehicle") are deliberately NOT included here - they already have
their own, much richer vanilla remote-control system (the spidertron
remote item: waypoints, follow-entity, auto-targeting), so folding them
into this simple "drive it" list would be redundant at best and confusing
at worst. Ask if a similar entry is wanted for spidertrons specifically.

Driving mechanics (see the API research in the changelog for citations):
LuaEntity::set_driver(player) assigns a player as a vehicle's driver
directly, without any "in reach" requirement (unlike LuaControl.driving/
set_driving, which are for the vanilla walk-up-and-press-enter
interaction). The one hard constraint (confirmed via a 2.0.55 engine fix
for a related bug): set_driver only works when the vehicle is on the SAME
surface as the player's current controller (physical or remote camera) -
calling it across surfaces throws an error.

Crucially, calling set_driver while the player is PHYSICALLY embodied
(controller_type == character) makes the engine physically relocate the
character into the vehicle's seat - a teleport, both on entry and again on
exit, exactly as if they'd walked up to it (this was reported as a live
bug: "the character teleports in and out" even on the same surface, once
the reach requirement below was skipped). True remote driving - no
physical relocation, character stays wherever it physically was - only
happens when set_driver is called while the player is ALREADY in remote
view (controller_type == remote), camera centered on the vehicle. So the
rule this module follows: if the vehicle is within normal reach
(LuaPlayer::can_reach_entity - the same check entity-access.lua uses
everywhere else in the mod), drive it directly, exactly like walking up
and pressing enter. Otherwise (out of reach, whether on the same surface
or a different one), ALWAYS switch into remote view centered on the
vehicle first (the same pattern control.lua's Alt+I toggle uses), and only
then call set_driver - so the physical character never moves.

set_driver() alone only assigns the seat - it does not reliably turn on
actual steering-input routing (movement keys doing nothing to the vehicle,
reported live, was traced to this). LuaControl.driving (read/write) is the
member that activates "this control is now operating its vehicle" - the
existing K coordinate-readout code elsewhere in control.lua already reads
player.driving as the real signal driving controls are live, so we now set
it explicitly after set_driver() rather than assuming it followed
automatically. This matters specifically for the out-of-reach/remote-view
path, since the physically-embodied (in-reach) case may set it as a side
effect of the normal walk-up-and-enter interaction but a script-driven
remote assignment cannot be assumed to.

One more piece, NOT handled in this file: making the remote CAMERA actually
follow the vehicle continuously as it drives (reported live as "drove out
of the audible/visible zone" - the vehicle races off from wherever the
camera was left at drive-start, since set_controller below only snaps to a
static position once). That's LuaPlayer.centered_on ("the entity being
centered on in remote view", read-write) - set in control.lua's
on_player_driving_changed_state handler instead of here, since that event
fires for every way driving can start or stop (including this module's
set_driver()+driving=true path), so it's the one place that reliably
covers entry AND exit (clearing centered_on back to nil) without
duplicating the logic per entry point.
]]

local Menu = require("scripts.ui.menu")
local KeyGraph = require("scripts.ui.key-graph")
local EntityUi = require("scripts.ui.entity-ui")
local Localising = require("scripts.localising")
local Speech = require("scripts.speech")
local Viewpoint = require("scripts.viewpoint")
local Graphics = require("scripts.graphics")

local mod = {}

local VEHICLE_TYPE = "car"

---Get this force's car/tank-type vehicles on a given surface (or every surface if nil), sorted
---by localised name then unit_number for stable ordering.
---@param force LuaForce
---@param surface LuaSurface? Restrict to this surface, or nil for every surface
---@return LuaEntity[]
local function get_sorted_vehicles(force, surface)
   local vehicles = {}

   local function scan(surf)
      local found = surf.find_entities_filtered({ type = VEHICLE_TYPE, force = force })
      for _, v in ipairs(found) do
         table.insert(vehicles, v)
      end
   end

   if surface then
      scan(surface)
   else
      for _, surf in pairs(game.surfaces) do
         scan(surf)
      end
   end

   table.sort(vehicles, function(a, b)
      local name_a = Localising.get_localised_name_with_fallback(a)
      local name_b = Localising.get_localised_name_with_fallback(b)
      -- LocalisedString can't be compared directly - fall back to the raw prototype/entity
      -- name (always a plain string) for ordering, only using unit_number as the final
      -- tiebreak. Good enough for stable, deterministic order; not meant to sort by the
      -- player-visible translated text.
      local key_a = (a.valid and a.name) or ""
      local key_b = (b.valid and b.name) or ""
      if key_a ~= key_b then return key_a < key_b end
      return (a.unit_number or 0) < (b.unit_number or 0)
   end)

   return vehicles
end

---Attempt to put the player in the driver's seat of the given vehicle, switching their remote
---view to the vehicle's surface first if necessary.
---@param pindex number
---@param vehicle LuaEntity
local function drive_vehicle(pindex, vehicle)
   local player = game.get_player(pindex)
   if not player then return end

   if not vehicle.valid then
      Speech.speak(pindex, { "fa.vehicles-overview-drive-failed" })
      return
   end

   if player.vehicle == vehicle then
      Speech.speak(pindex, { "fa.vehicles-overview-already-driving-this" })
      return
   end

   local existing_driver = vehicle.get_driver()
   if existing_driver then
      Speech.speak(pindex, { "fa.vehicles-overview-occupied", Localising.get_localised_name_with_fallback(vehicle) })
      return
   end

   -- Decide HOW to enter based on reach, not just surface. Entering from a physically
   -- embodied state (controller_type == character) makes the engine teleport the character
   -- into the seat and back out again - fine and expected when the vehicle is genuinely
   -- within reach (this is what walking up and pressing enter would do anyway), but jarring
   -- and wrong when it's far away. So: within reach -> drive directly. Out of reach (same
   -- surface or not) -> always go through remote view first, so the physical character never
   -- moves; set_driver then does true remote driving instead of a long-distance teleport.
   local was_out_of_reach = not player.can_reach_entity(vehicle)
   if was_out_of_reach then
      player.set_controller({
         type = defines.controllers.remote,
         surface = vehicle.surface,
         position = vehicle.position,
      })
   end

   vehicle.set_driver(player)

   -- set_driver() alone assigns the SEAT (who is allowed to drive), but does not reliably
   -- flip on actual steering-input routing for a player who was not physically embodied when
   -- it was called (the remote-driving path above). LuaControl.driving (read/write - see
   -- changelog citation) is the member that activates "this control is now operating its
   -- vehicle", and existing FA code elsewhere (the K coordinate-readout) already treats
   -- player.driving as the real signal that driving controls are live. Setting it explicitly
   -- here, rather than assuming set_driver did it, is what actually makes movement keys steer
   -- the vehicle in the remote case instead of just panning/idling.
   if player.vehicle == vehicle and not player.driving then player.driving = true end

   if player.vehicle == vehicle and player.driving then
      if was_out_of_reach then
         -- Still in remote view, now centered on (and steering) the vehicle instead of the
         -- physical character - do NOT clear remote_view, the sound chart-gating and other
         -- remote_view-driven branches still apply here.
         local vp = Viewpoint.get_viewpoint(pindex)
         local pos = vehicle.position
         vp:set_cursor_pos({ x = math.floor(pos.x), y = math.floor(pos.y) })
         Graphics.draw_cursor_highlight(pindex, nil, nil)
         Graphics.sync_build_cursor_graphics(pindex)

         -- Best-effort centered_on assignment (see control.lua's on_player_driving_changed_state,
         -- which is the primary place this gets set). CONFIRMED via live diagnostic (changelog
         -- 18, Kiegészítés 3) that this is NOT actually what keeps the camera on the vehicle
         -- while driving - centered_on reads back nil again within a few seconds of assignment
         -- (most likely cleared by the engine itself once real steering input starts, since
         -- entity-follow and active piloting are presumably mutually exclusive camera modes),
         -- yet the camera tracked the vehicle with ZERO drift for the entire logged drive
         -- regardless. So LuaPlayer.position while remote-driving is apparently kept in sync
         -- with the vehicle natively by the engine, independent of centered_on entirely. Kept
         -- here anyway (harmless) for the one case that might still need it: a passenger/gunner
         -- seat, where player.driving is false even though player.vehicle is set, so the native
         -- driving-camera-follow this discovery relies on may not apply.
         if player.controller_type == defines.controllers.remote then player.centered_on = vehicle end
      else
         -- Genuinely physically embodied (was in reach) - same as walking up and pressing
         -- enter, so sync the same way the Alt+I exit branch does when leaving remote view
         -- back into a physical character.
         storage.players[pindex].remote_view = false
         local vp = Viewpoint.get_viewpoint(pindex)
         local pos = vehicle.position
         vp:set_cursor_pos({ x = math.floor(pos.x), y = math.floor(pos.y) })
         Graphics.draw_cursor_highlight(pindex, nil, nil)
         Graphics.sync_build_cursor_graphics(pindex)
      end

      local start_message = { "fa.vehicles-overview-driving-started", Localising.get_localised_name_with_fallback(vehicle) }
      local fuel_inv = vehicle.get_fuel_inventory()
      if fuel_inv and fuel_inv.is_empty() then
         Speech.speak(pindex, { "fa.vehicles-overview-driving-started-no-fuel", Localising.get_localised_name_with_fallback(vehicle) })
      else
         Speech.speak(pindex, start_message)
      end
   else
      Speech.speak(pindex, { "fa.vehicles-overview-drive-failed" })
   end
end

---Build vehicle rows
---@param builder fa.ui.menu.MenuBuilder
---@param vehicles LuaEntity[]
local function build_vehicle_rows(builder, vehicles)
   for _, vehicle in ipairs(vehicles) do
      local id = vehicle.unit_number

      builder:start_row("vehicle")

      -- Main vehicle info (click to open its configuration/inventory UI)
      builder:add_clickable("vehicle-" .. id, function(ctx)
         ctx.message:fragment(Localising.get_localised_name_with_fallback(vehicle))
         local pos = vehicle.position
         ctx.message:fragment({ "fa.vehicles-overview-at-position", math.floor(pos.x), math.floor(pos.y) })
         if vehicle.get_driver() then
            ctx.message:fragment({ "fa.vehicles-overview-has-driver" })
         end
         ctx.message:fragment({ "fa.vehicles-overview-click-to-open" })
      end, {
         on_click = function(ctx)
            ctx.controller:close()
            EntityUi.open_entity_ui(ctx.pindex, vehicle)
         end,
      })

      -- Drive action
      builder:add_clickable("drive-" .. id, function(ctx)
         ctx.message:fragment({ "fa.vehicles-overview-drive" })
      end, {
         on_click = function(ctx)
            ctx.controller:close()
            drive_vehicle(ctx.pindex, vehicle)
         end,
      })

      builder:end_row()
   end
end

---Render a vehicles tab
---@param surface_getter (fun(player: LuaPlayer): LuaSurface?)? Returns surface or nil for all
---@return fun(ctx: fa.ui.graph.Ctx): fa.ui.graph.Render
local function make_render_callback(surface_getter)
   return function(ctx)
      local builder = Menu.MenuBuilder.new()
      local player = game.get_player(ctx.pindex)
      if not player then return builder:add_label("error", { "fa.vehicles-overview-error" }):build() end

      local surface = surface_getter and surface_getter(player) or nil
      local vehicles = get_sorted_vehicles(player.force, surface)

      if #vehicles == 0 then
         builder:add_label("empty", { "fa.vehicles-overview-no-vehicles" })
         return builder:build()
      end

      build_vehicle_rows(builder, vehicles)
      return builder:build()
   end
end

-- Tab for vehicles on the player's current physical surface
mod.surface_vehicles_tab = KeyGraph.declare_graph({
   name = "surface_vehicles",
   title = { "fa.vehicles-overview-surface-title" },
   render_callback = make_render_callback(function(player)
      return player.physical_surface
   end),
})

-- Tab for every vehicle across every surface
mod.all_vehicles_tab = KeyGraph.declare_graph({
   name = "all_vehicles",
   title = { "fa.vehicles-overview-all-title" },
   render_callback = make_render_callback(nil),
})

return mod
