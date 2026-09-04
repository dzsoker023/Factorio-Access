--[[
Train group selector UI.

Allows selecting a train group from existing groups or typing a new one.
Returns the selected group name to the parent UI.
]]

local OptionsSelector = require("scripts.ui.selectors.options-selector")
local Router = require("scripts.ui.router")

local mod = {}

---Get train group options for the selector
---@param pindex number
---@param parameters table
---@return fa.ui.selectors.OptionsResult
local function get_available_platforms(pindex, parameters)
   local player = game.get_player(pindex)
   if not player then return { options = {} } end

   local options = {}

   -- Get existing groups and add them
   local platforms = parameters.ent.force.platforms
   for _, platform in ipairs(platforms) do
      table.insert(options, {
         label = platform.name,
         value = platform.hub,
      })
   end

   return { options = options }
end

-- Create and register the train group selector UI
mod.group_selector_ui = OptionsSelector.declare_options_selector({
   ui_name = Router.UI_NAMES.PLATFORM_SELECTOR,
   title = { "fa.train-select-group" },
   get_options = get_available_platforms,
})

Router.register_ui(mod.group_selector_ui)

return mod
