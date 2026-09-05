--[[
Main unified menu that combines inventory, guns, crafting, and research tabs.
This is the primary player interface accessed with the E key.
]]

local Functools = require("scripts.functools")
local TabList = require("scripts.ui.tab-list")
local UiRouter = require("scripts.ui.router")

-- Import all the individual tabs
local inventory = require("scripts.ui.menus.inventory")
local equipment_overview = require("scripts.ui.tabs.equipment-overview")
local equipment_grid = require("scripts.ui.tabs.equipment-grid")
local crafting = require("scripts.ui.menus.crafting")
local crafting_queue = require("scripts.ui.menus.crafting-queue")
local research = require("scripts.ui.menus.research")
local research_queue = require("scripts.ui.menus.research-queue")
local ghost_placement = require("scripts.ui.tabs.ghost-placement")
local InventoryGrid = require("scripts.ui.inventory-grid")

local mod = {}

-- Create the trash inventory tab
local TRASH_GRID = InventoryGrid.create_inventory_grid({
   name = "player_trash",
   title = { "fa.ui-inventory-trash-title" },
})

---Shared state setup function that combines state from all tabs
---@param pindex number
---@param params any
---@return table
local function setup_shared_state(pindex, params)
   return {}
end

---Build tabs for the inventories section
---@param pindex number
---@param params table
---@return fa.ui.TabDescriptor[]
local function build_inventory_tabs(pindex, params)
   local tabs = {
      inventory.inventory_tab,
   }

   -- Add trash tab if it's in the parameters
   if params.player_trash then table.insert(tabs, TRASH_GRID) end

   return tabs
end

-- Create the unified TabList with sections
mod.main_menu = TabList.declare_tablist({
   ui_name = UiRouter.UI_NAMES.MAIN,
   resets_to_first_tab_on_open = true,
   shared_state_setup = setup_shared_state,
   tabs_callback = function(pindex, params)
      local player = game.get_player(pindex)
      -- Remote view, or riding a space platform while it's travelling between locations, both
      -- use the "remote" controller - crafting and personal-inventory access don't work there
      -- even though the character entity can still exist (e.g. seated in the platform hub), so
      -- key off controller_type rather than player.character.
      local is_remote = player and player.controller_type == defines.controllers.remote
      local sections = {}

      if not is_remote and player and player.character then
         table.insert(sections, {
            name = "inventories",
            title = { "fa.section-inventories" },
            tabs = build_inventory_tabs(pindex, params),
         })

         -- Add crafting section
         table.insert(sections, {
            name = "crafting",
            title = { "fa.section-crafting" },
            tabs = {
               crafting.crafting_tab,
               crafting_queue.crafting_queue_tab,
            },
         })
      else
         -- Offer ghost placement instead, so ghosts can still be queued up for construction bots.
         table.insert(sections, {
            name = "ghost",
            title = { "fa.section-ghost-placement" },
            tabs = {
               ghost_placement.ghost_placement_tab,
            },
         })
      end

      -- Add research section
      table.insert(sections, {
         name = "research",
         title = { "fa.section-research" },
         tabs = {
            research.research_tab,
            research_queue.research_queue_tab,
         },
      })

      -- Equipment section - always visible, last
      local equipment_tabs = {
         equipment_overview.equipment_overview_tab,
      }
      -- Add grid tab if available
      if player and player.character and equipment_grid.is_available(player.character) then
         table.insert(equipment_tabs, equipment_grid.equipment_grid_tab)
      end

      table.insert(sections, {
         name = "equipment",
         title = { "fa.section-equipment" },
         tabs = equipment_tabs,
      })

      return sections
   end,
   get_binds = function(pindex, parameters)
      local player = game.get_player(pindex)
      if not player or not player.character or not player.character.valid then return nil end
      return { { kind = UiRouter.BIND_KIND.ENTITY, entity = player.character } }
   end,
})

---Open the main menu for a player
---@param pindex number Player index
---@return boolean success
function mod.open_main_menu(pindex)
   local player = game.get_player(pindex)
   if not player then return false end

   local is_remote = player.controller_type == defines.controllers.remote

   if not player.character and not is_remote then
      -- No character and not remote-controlling either (e.g. spectating) - nothing sensible
      -- to open the menu for.
      return false
   end

   if is_remote then
      -- Remote view, or riding a space platform in transit - the character may still exist
      -- (e.g. seated in the platform hub), but the remote controller can't craft or touch
      -- inventories, so skip straight to opening with the reduced (ghost placement) tab set
      -- that tabs_callback builds for this case.
      local router = UiRouter.get_router(pindex)
      router:open_ui(UiRouter.UI_NAMES.MAIN, {})
      return true
   end

   local params = {
      player_inventory = {
         entity = player.character,
         inventory_index = defines.inventory.character_main,
      },
   }

   -- Add trash inventory if personal logistics is enabled
   if player.force.character_logistic_requests then
      params.player_trash = {
         entity = player.character,
         inventory_index = defines.inventory.character_trash,
      }
   end

   local router = UiRouter.get_router(pindex)
   router:open_ui(UiRouter.UI_NAMES.MAIN, params)
   return true
end

-- Register with the UI event routing system
UiRouter.register_ui(mod.main_menu)

return mod
