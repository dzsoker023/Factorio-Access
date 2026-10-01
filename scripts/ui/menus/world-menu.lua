--[[
World menu for global/cross-surface information.
Accessed with Alt+W.
]]

local TabList = require("scripts.ui.tab-list")
local UiRouter = require("scripts.ui.router")

local trains_overview = require("scripts.ui.tabs.trains-overview")
local platforms_overview = require("scripts.ui.tabs.platforms-overview")
local vehicles_overview = require("scripts.ui.tabs.vehicles-overview")
local alerts_tabs = require("scripts.ui.tabs.alerts")

local mod = {}

mod.world_menu = TabList.declare_tablist({
   ui_name = UiRouter.UI_NAMES.WORLD,
   resets_to_first_tab_on_open = true,
   tabs_callback = function(pindex, params)
      local sections = {
         {
            name = "alerts",
            title = { "fa.section-alerts" },
            tabs = alerts_tabs.build_alert_tabs(pindex),
         },
         {
            name = "trains",
            title = { "fa.section-trains" },
            tabs = {
               trains_overview.all_trains_tab,
            },
         },
         {
            name = "platforms",
            title = { "fa.section-platforms" },
            tabs = {
               platforms_overview.all_platforms_tab,
            },
         },
         {
            name = "vehicles",
            title = { "fa.section-vehicles" },
            tabs = {
               vehicles_overview.surface_vehicles_tab,
               vehicles_overview.all_vehicles_tab,
            },
         },
      }

      return sections
   end,
})

---Open the world menu for a player
---@param pindex number Player index
---@return boolean success
function mod.open_world_menu(pindex)
   local player = game.get_player(pindex)
   assert(player)

   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.WORLD, {})
   return true
end

UiRouter.register_ui(mod.world_menu)

return mod
