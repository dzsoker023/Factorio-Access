--[[
Planet (space location) selector UI.

Lists space locations that the player's force has already discovered/unlocked,
for use as space platform schedule destinations. Unlike trains, platforms
travel between space locations rather than named stations, and only locations
the force has already unlocked make sense to offer here.
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

   for name, location in pairs(prototypes.space_location) do
      if force.is_space_location_unlocked(name) then
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
