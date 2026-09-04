--[[
Planet selector UI.

Lists actual planets (not every space location - e.g. the solar system edge,
or a non-planet surface some other mod happens to register as a space
location) that the player's force has already discovered/unlocked, for use
as space platform schedule destinations. Unlike trains, platforms travel
between space locations rather than named stations, and only locations the
force has already unlocked make sense to offer here.
]]

local OptionsSelector = require("scripts.ui.selectors.options-selector")
local Router = require("scripts.ui.router")

local mod = {}

---Get discovered planet options for the selector
---@param pindex number
---@param parameters table
---@return fa.ui.selectors.OptionsResult
local function get_discovered_planets(pindex, parameters)
   local player = game.get_player(pindex)
   if not player then return { options = {} } end

   local force = player.force
   local options = {}

   -- `game.planets` is the runtime's own list of actual planets (LuaPlanet), as opposed to
   -- `prototypes.space_location`, which is a superset that also includes non-planet space
   -- locations (e.g. the solar system edge) and, depending on other installed mods, surfaces
   -- that were registered as a space location for unrelated reasons without being real planets.
   for name, planet in pairs(game.planets) do
      if force.is_space_location_unlocked(name) then
         table.insert(options, {
            label = planet.prototype.localised_name,
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
