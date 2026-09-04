--[[
Space platform selector UI.

Allows selecting one of this force's built space platforms (by hub entity),
for use as a rocket/cargo launch destination.
]]

local OptionsSelector = require("scripts.ui.selectors.options-selector")
local Router = require("scripts.ui.router")

local mod = {}

---Get this force's platform options for the selector
---@param pindex number
---@param parameters table
---@return fa.ui.selectors.OptionsResult
local function get_available_platforms(pindex, parameters)
   local player = game.get_player(pindex)
   if not player then return { options = {} } end

   local options = {}

   -- force.platforms is a dictionary keyed by platform index, not an array
   local platforms = parameters.ent.force.platforms
   for _, platform in pairs(platforms) do
      -- hub can be nil if the starter pack hasn't been applied yet
      if platform.hub then
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
