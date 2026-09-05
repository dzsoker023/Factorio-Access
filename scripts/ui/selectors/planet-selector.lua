--[[
Planet (space location) selector UI.

Lists space locations that the player's force has already discovered/unlocked, for use as
space platform schedule destinations. Unlike trains, platforms travel between space locations
(not just planets - a destination can be any space-location, planet or not) rather than named
stations, and only locations the force has already unlocked make sense to offer here.

We deliberately do NOT restrict this to `game.planets` (real, landable planets): platforms can
also be scheduled to non-planet locations such as the solar system edge, and some of those are
meant to be player-facing (e.g. a "shattered planet" ruin you can visit but not land on) even
though they aren't a `LuaPlanet`. Instead we use the `hidden` flag every space-location prototype
has - "Hides the space location from the planet selection lists and the space map" - which is
exactly the flag the game itself uses to keep internal/technical registrations (such as another
mod registering a non-visitable surface as a space location for its own compatibility reasons)
out of UIs like this one.
]]

local OptionsSelector = require("scripts.ui.selectors.options-selector")
local Router = require("scripts.ui.router")

local mod = {}

---Get discovered, non-hidden space location options for the selector
---@param pindex number
---@param parameters table
---@return fa.ui.selectors.OptionsResult
local function get_discovered_planets(pindex, parameters)
   local player = game.get_player(pindex)
   if not player then return { options = {} } end

   local force = player.force
   local options = {}

   for name, location in pairs(prototypes.space_location) do
      if not location.hidden and force.is_space_location_unlocked(name) then
         table.insert(options, {
            label = location.localised_name,
            value = name,
         })
      end
   end

   table.sort(options, function(a, b)
      return a.value < b.value
   end)

   return { options = options }
end

-- Create and register the planet selector UI
mod.planet_selector_ui = OptionsSelector.declare_options_selector({
   ui_name = Router.UI_NAMES.PLANET_SELECTOR,
   title = { "fa.planet-select" },
   get_options = get_discovered_planets,
})

Router.register_ui(mod.planet_selector_ui)

return mod
