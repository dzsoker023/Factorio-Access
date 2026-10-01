--[[
Space platform selector UI.

Allows selecting one of this force's built space platforms (by hub entity),
for use as a rocket/cargo launch destination.
]]

local OptionsSelector = require("scripts.ui.selectors.options-selector")
local Router = require("scripts.ui.router")

local mod = {}

--[[
Whether a platform is a legal launch destination from a silo at silo_location: it must have
its hub built (nil while the starter pack hasn't been applied yet) and be currently PARKED
(not mid-travel - space_location is nil while travelling, see space_connection in
platform-config.lua) at that same location.

This is the single source of truth for that check - shared between get_available_platforms
below (which builds the actual selector menu) and has_available_platform (which
rocket-silo-config.lua uses to decide whether to even open the selector). The two used to be
two independently-written checks that drifted apart: rocket-silo-config.lua's old
force_has_platforms only checked "does this force have ANY platform at all", which can be
true while zero of them are valid destinations for THIS silo (e.g. all mid-travel, or parked
at a different planet) - the selector would then open with a genuinely empty option list,
which crashes MenuBuilder:build() ("Menus must have at least one item", see menu.lua) rather
than degrading gracefully. Routing both checks through one predicate makes that drift
impossible going forward.
]]
---@param platform LuaSpacePlatform
---@param silo_location LuaSpaceLocation?
---@return boolean
local function is_valid_destination(platform, silo_location)
   return platform.hub ~= nil
      and platform.space_location ~= nil
      and silo_location ~= nil
      and platform.space_location.name == silo_location.name
end

---Whether ANY of this force's platforms is currently a valid launch destination from the
---given silo surface. Use this to gate opening the selector (and give a spoken reason when
---there's nothing to select) instead of the selector's own empty-options fallback, which
---closes silently - see options-selector.lua.
---@param force LuaForce
---@param silo_surface LuaSurface
---@return boolean
function mod.has_available_platform(force, silo_surface)
   local silo_location = silo_surface and silo_surface.planet
   for _, platform in pairs(force.platforms) do
      if is_valid_destination(platform, silo_location) then return true end
   end
   return false
end

---Get this force's platform options for the selector
---@param pindex number
---@param parameters table
---@return fa.ui.selectors.OptionsResult
local function get_available_platforms(pindex, parameters)
   local player = game.get_player(pindex)
   if not player then return { options = {} } end

   local options = {}

   -- A rocket launched from a silo can only reach a platform that is currently
   -- parked at (in orbit of) the same location the silo itself is at. Filter the
   -- option list down to only those up front, so the player can never even
   -- select an illegal destination in the first place.
   local silo_surface = parameters.ent.surface
   local silo_location = silo_surface and silo_surface.planet

   -- force.platforms is a dictionary keyed by platform index, not an array
   local platforms = parameters.ent.force.platforms
   for _, platform in pairs(platforms) do
      if is_valid_destination(platform, silo_location) then
         table.insert(options, {
            label = platform.name,
            value = platform.hub,
         })
      end
   end

   return { options = options }
end

-- Create and register the platform selector UI
mod.platform_selector_ui = OptionsSelector.declare_options_selector({
   ui_name = Router.UI_NAMES.PLATFORM_SELECTOR,
   title = { "fa.platform-select" },
   get_options = get_available_platforms,
})

Router.register_ui(mod.platform_selector_ui)

return mod
