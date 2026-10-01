--[[
Deconstruction Planner Menu
Main menu for configuring deconstruction planner settings and filters.
3 tabs: settings, entity filters, tile filters.
]]

local Menu = require("scripts.ui.menu")
local FormBuilder = require("scripts.ui.form-builder")
local TabList = require("scripts.ui.tab-list")
local KeyGraph = require("scripts.ui.key-graph")
local UiRouter = require("scripts.ui.router")
local Localising = require("scripts.localising")
local EntityChooser = require("scripts.ui.tabs.entity-chooser")
local LauncherCommands = require("scripts.launcher-commands")
local PlannerUtils = require("scripts.planner-utils")

local mod = {}

---Make the planner permanent (not temporary cursor item)
---@param pindex number
local function make_permanent(pindex)
   local player = game.get_player(pindex)
   if player then player.cursor_stack_temporary = false end
end

-- Tile selection mode choices for FormBuilder
local TILE_MODE_CHOICES = {
   { label = { "fa.decon-tiles-normal" }, value = defines.deconstruction_item.tile_selection_mode.normal },
   { label = { "fa.decon-tiles-always" }, value = defines.deconstruction_item.tile_selection_mode.always },
   { label = { "fa.decon-tiles-never" }, value = defines.deconstruction_item.tile_selection_mode.never },
   { label = { "fa.decon-tiles-only" }, value = defines.deconstruction_item.tile_selection_mode.only, default = true },
}

--[[
Confirmed Wube engine bug (forums.factorio.com/viewtopic.php?p=698072, reported on
2.1.9): LuaItemStack.set_entity_filter/set_tile_filter raise "Index out of bounds" when
the index is one past the item's CURRENT entity_filter_count/tile_filter_count - i.e.
exactly the "add a new filter to the first empty slot" case this menu needs, since that
empty slot's index (rendered as entity_filter_count + 1, see render_entities_tab below)
does not exist yet as far as the direct setter is concerned. Quoting the original report:
"set_entity_filter (and ::set_tile_filter) were changed such that if the given index
doesn't exist, it generates an error 'Index out of bounds'. The only way to use these 2
functions is to call entity_filters (or item_filters) with an entire array of filters,
then set_entity_filter is able to change a filter at an existing index." Wube (Rseding91)
confirmed it as a bug and said the fix "will be in the next release" (posted after
2.1.9) - it is NOT confirmed whether the mod's 2.1.8 baseline, or the player's actual
live Factorio version, already has that fix, so both helpers below sidestep the question
entirely: overwriting/clearing an EXISTING index still uses the direct setter (fine per
the report), but adding a genuinely new one always goes through the whole-array write
instead, which the report confirms is unaffected either way.
]]

---@param planner LuaItemStack
---@param idx number
---@param value string|nil
local function set_entity_filter_safe(planner, idx, value)
   if idx <= planner.entity_filter_count then
      planner.set_entity_filter(idx, value)
   elseif value ~= nil then
      local filters = planner.entity_filters
      filters[idx] = value
      planner.entity_filters = filters
   end
   -- else: idx is past the end and value is nil - nothing to clear, no-op.
end

---@param planner LuaItemStack
---@param idx number
---@param value string|nil
local function set_tile_filter_safe(planner, idx, value)
   if idx <= planner.tile_filter_count then
      planner.set_tile_filter(idx, value)
   elseif value ~= nil then
      local filters = planner.tile_filters
      filters[idx] = value
      planner.tile_filters = filters
   end
end

---Get entity filter as name string
---@param planner LuaItemStack
---@param index number
---@return string|nil
local function get_entity_filter_name(planner, index)
   -- Confirmed live crash report: get_entity_filter (like set_entity_filter, see the
   -- Wube bug comment above) ALSO throws "Index out of bounds" when index is past the
   -- current entity_filter_count - not just the setter. The render loop deliberately
   -- calls this one index PAST the count (the "next empty slot" - see
   -- render_entities_tab), so that case must be short-circuited here without ever
   -- calling the engine getter at all; there is nothing there to read yet regardless.
   if index > planner.entity_filter_count then return nil end

   local filter = planner.get_entity_filter(index)
   if not filter then return nil end
   -- filter can be string or table with name field
   if type(filter) == "string" then return filter end
   if type(filter) == "table" and filter.name then return filter.name end
   return nil
end

---Get tile filter as name string. Same out-of-bounds guard as get_entity_filter_name
---above, for the same reason - get_tile_filter throws past the current count too.
---@param planner LuaItemStack
---@param index number
---@return string|nil
local function get_tile_filter_name(planner, index)
   if index > planner.tile_filter_count then return nil end
   return planner.get_tile_filter(index)
end

-- ============================================================================
-- Tab 1: Settings
-- ============================================================================

---@param ctx fa.ui.graph.Ctx
local function render_settings_tab(ctx)
   local planner = PlannerUtils.get_decon_planner(ctx.pindex)
   if not planner then return nil end

   local builder = FormBuilder.FormBuilder.new()

   -- Rename
   builder:add_textfield("rename", {
      label = { "fa.decon-rename" },
      get_value = function()
         return planner.label or ""
      end,
      set_value = function(value)
         planner.label = value
         make_permanent(ctx.pindex)
      end,
   })

   -- Trees and rocks only toggle
   builder:add_checkbox("trees_rocks", { "fa.decon-trees-rocks-only" }, function()
      return planner.trees_and_rocks_only
   end, function(value)
      planner.trees_and_rocks_only = value
      make_permanent(ctx.pindex)
   end)

   -- Tiles mode cycle
   builder:add_choice_field("tiles_mode", { "fa.decon-tiles-mode" }, function()
      return planner.tile_selection_mode
   end, function(value)
      planner.tile_selection_mode = value
      make_permanent(ctx.pindex)
   end, TILE_MODE_CHOICES)

   -- Clear all
   builder:add_action("clear_all", { "fa.decon-clear-all" }, function(controller)
      planner.clear_deconstruction_item()
      make_permanent(ctx.pindex)
      controller.message:fragment({ "fa.decon-all-cleared" })
   end)

   -- Import (needs on_child_result, so use add_item directly)
   builder:add_item("import", {
      label = function(label_ctx)
         label_ctx.message:fragment({ "fa.decon-import" })
      end,
      on_click = function(click_ctx)
         click_ctx.controller:open_textbox("", "import")
      end,
      on_child_result = function(click_ctx, result)
         if result and result ~= "" then
            local status = planner.import_stack(result)
            if status == 0 then
               make_permanent(ctx.pindex)
               click_ctx.controller.message:fragment({ "fa.decon-planner-imported" })
            elseif status == -1 then
               make_permanent(ctx.pindex)
               click_ctx.controller.message:fragment({ "fa.decon-planner-imported-with-errors" })
            else
               click_ctx.controller.message:fragment({ "fa.decon-planner-import-failed" })
            end
         end
      end,
   })

   -- Export
   builder:add_action("export", { "fa.decon-export" }, function(controller)
      LauncherCommands.copy_to_clipboard(ctx.pindex, planner.export_stack())
      controller.message:fragment({ "fa.decon-planner-exported" })
   end)

   return builder:build()
end

local settings_tab = KeyGraph.declare_graph({
   name = "decon_settings",
   render_callback = render_settings_tab,
   title = { "fa.decon-settings-tab" },
})

-- ============================================================================
-- Tab 2: Entity Filters
-- ============================================================================

---Render entity filter slot
---@param builder fa.ui.menu.MenuBuilder
---@param planner LuaItemStack
---@param slot_index number
---@param pindex number
local function render_entity_slot(builder, planner, slot_index, pindex)
   local row_key = "entity_slot_" .. slot_index

   local filter_name = get_entity_filter_name(planner, slot_index)

   builder:add_clickable(row_key, function(label_ctx)
      if filter_name then
         local proto = prototypes.entity[filter_name]
         if proto then
            label_ctx.message:fragment(Localising.get_localised_name_with_fallback(proto))
         else
            label_ctx.message:fragment(filter_name)
         end
      else
         label_ctx.message:fragment({ "fa.decon-empty-slot", slot_index })
      end
   end, {
      on_click = function(click_ctx)
         click_ctx.controller:open_child_ui(UiRouter.UI_NAMES.ENTITY_CHOOSER, {
            filter_type = EntityChooser.FILTER_TYPES.DECONSTRUCTABLE,
         }, {
            node = row_key,
            slot_index = slot_index,
         })
      end,
      on_clear = function(click_ctx)
         set_entity_filter_safe(planner, slot_index, nil)
         make_permanent(pindex)
         click_ctx.message:fragment({ "fa.decon-filter-removed" })
      end,
      on_child_result = function(click_ctx, result)
         local child_ctx = click_ctx.child_context
         local idx = child_ctx.slot_index
         set_entity_filter_safe(planner, idx, result)
         make_permanent(pindex)
         click_ctx.message:fragment({ "fa.decon-filter-set" })
      end,
   })
end

---@param ctx fa.ui.graph.Ctx
local function render_entities_tab(ctx)
   local planner = PlannerUtils.get_decon_planner(ctx.pindex)
   if not planner then return nil end

   local builder = Menu.MenuBuilder.new()

   -- Row 1: Whitelist/Blacklist toggle + Clear button
   builder:start_row("header")

   -- Whitelist/Blacklist toggle
   builder:add_clickable("filter_mode", function(label_ctx)
      if planner.entity_filter_mode == defines.deconstruction_item.entity_filter_mode.whitelist then
         label_ctx.message:fragment({ "fa.decon-whitelist" })
      else
         label_ctx.message:fragment({ "fa.decon-blacklist" })
      end
   end, {
      on_click = function(click_ctx)
         if planner.entity_filter_mode == defines.deconstruction_item.entity_filter_mode.whitelist then
            planner.entity_filter_mode = defines.deconstruction_item.entity_filter_mode.blacklist
            click_ctx.message:fragment({ "fa.decon-blacklist" })
         else
            planner.entity_filter_mode = defines.deconstruction_item.entity_filter_mode.whitelist
            click_ctx.message:fragment({ "fa.decon-whitelist" })
         end
         make_permanent(ctx.pindex)
      end,
   })

   -- Clear entities button
   builder:add_clickable("clear_entities", { "fa.decon-clear-entities" }, {
      on_click = function(click_ctx)
         for i = 1, planner.entity_filter_count do
            set_entity_filter_safe(planner, i, nil)
         end
         make_permanent(ctx.pindex)
         click_ctx.message:fragment({ "fa.decon-filters-cleared" })
      end,
   })

   builder:end_row()

   -- Filter slots. entity_filter_count is how many filters are CURRENTLY SET, not a
   -- fixed capacity (confirmed by the reported bug this fixes: on a fresh planner with
   -- zero filters, entity_filter_count is 0, so a loop bounded by it alone renders zero
   -- rows - the tab looks completely empty and there is no way to add a first filter at
   -- all). Rendering one slot PAST the current count always leaves exactly one empty
   -- "next" slot available to fill; once it's filled, entity_filter_count grows by one on
   -- the next render, which then exposes a new empty slot after it, and so on - the same
   -- pattern the game's own 2.0+ GUI uses for this list instead of a fixed grid.
   -- NOTE: no hard cap is applied here (unlike the old, likely-outdated wiki-documented
   -- "30 slots" figure for the pre-2.0 fixed-grid UI) since the current real upper bound
   -- isn't confirmed - if filling far enough in ever silently fails to persist, that
   -- number is the real cap and this loop should be clamped to it.
   for i = 1, planner.entity_filter_count + 1 do
      render_entity_slot(builder, planner, i, ctx.pindex)
   end

   return builder:build()
end

local entities_tab = KeyGraph.declare_graph({
   name = "decon_entities",
   render_callback = render_entities_tab,
   title = { "fa.decon-entities-tab" },
})

-- ============================================================================
-- Tab 3: Tile Filters
-- ============================================================================

---Render tile filter slot
---@param builder fa.ui.menu.MenuBuilder
---@param planner LuaItemStack
---@param slot_index number
---@param pindex number
local function render_tile_slot(builder, planner, slot_index, pindex)
   local row_key = "tile_slot_" .. slot_index

   local filter_name = get_tile_filter_name(planner, slot_index)

   builder:add_clickable(row_key, function(label_ctx)
      if filter_name then
         local proto = prototypes.tile[filter_name]
         if proto then
            label_ctx.message:fragment(Localising.get_localised_name_with_fallback(proto))
         else
            label_ctx.message:fragment(filter_name)
         end
      else
         label_ctx.message:fragment({ "fa.decon-empty-slot", slot_index })
      end
   end, {
      on_click = function(click_ctx)
         click_ctx.controller:open_child_ui(UiRouter.UI_NAMES.TILE_CHOOSER, {}, {
            node = row_key,
            slot_index = slot_index,
         })
      end,
      on_clear = function(click_ctx)
         set_tile_filter_safe(planner, slot_index, nil)
         make_permanent(pindex)
         click_ctx.message:fragment({ "fa.decon-filter-removed" })
      end,
      on_child_result = function(click_ctx, result)
         local child_ctx = click_ctx.child_context
         local idx = child_ctx.slot_index
         set_tile_filter_safe(planner, idx, result)
         make_permanent(pindex)
         click_ctx.message:fragment({ "fa.decon-filter-set" })
      end,
   })
end

---@param ctx fa.ui.graph.Ctx
local function render_tiles_tab(ctx)
   local planner = PlannerUtils.get_decon_planner(ctx.pindex)
   if not planner then return nil end

   local builder = Menu.MenuBuilder.new()

   -- Row 1: Whitelist/Blacklist toggle + Clear button
   builder:start_row("header")

   -- Whitelist/Blacklist toggle
   builder:add_clickable("filter_mode", function(label_ctx)
      if planner.tile_filter_mode == defines.deconstruction_item.tile_filter_mode.whitelist then
         label_ctx.message:fragment({ "fa.decon-whitelist" })
      else
         label_ctx.message:fragment({ "fa.decon-blacklist" })
      end
   end, {
      on_click = function(click_ctx)
         if planner.tile_filter_mode == defines.deconstruction_item.tile_filter_mode.whitelist then
            planner.tile_filter_mode = defines.deconstruction_item.tile_filter_mode.blacklist
            click_ctx.message:fragment({ "fa.decon-blacklist" })
         else
            planner.tile_filter_mode = defines.deconstruction_item.tile_filter_mode.whitelist
            click_ctx.message:fragment({ "fa.decon-whitelist" })
         end
         make_permanent(ctx.pindex)
      end,
   })

   -- Clear tiles button
   builder:add_clickable("clear_tiles", { "fa.decon-clear-tiles" }, {
      on_click = function(click_ctx)
         for i = 1, planner.tile_filter_count do
            set_tile_filter_safe(planner, i, nil)
         end
         make_permanent(ctx.pindex)
         click_ctx.message:fragment({ "fa.decon-filters-cleared" })
      end,
   })

   builder:end_row()

   -- Filter slots. Same "current count is not a capacity" issue as the entity filters
   -- tab above - render one slot past the current count so there's always an empty
   -- "next" one available to add a new tile filter to.
   for i = 1, planner.tile_filter_count + 1 do
      render_tile_slot(builder, planner, i, ctx.pindex)
   end

   return builder:build()
end

local tiles_tab = KeyGraph.declare_graph({
   name = "decon_tiles",
   render_callback = render_tiles_tab,
   title = { "fa.decon-tiles-tab" },
})

-- ============================================================================
-- TabList declaration
-- ============================================================================

mod.decon_planner_menu = TabList.declare_tablist({
   ui_name = UiRouter.UI_NAMES.DECON_PLANNER,
   resets_to_first_tab_on_open = true,
   get_binds = function(pindex, parameters)
      return { { kind = UiRouter.BIND_KIND.HAND_CONTENTS } }
   end,
   tabs_callback = function(pindex)
      local planner = PlannerUtils.get_decon_planner(pindex)
      if not planner then
         return {
            {
               name = "decon_planner",
               tabs = { settings_tab },
            },
         }
      end

      -- If tiles mode is "only", hide entity filters tab
      local show_entities = planner.tile_selection_mode ~= defines.deconstruction_item.tile_selection_mode.only

      local tabs = { settings_tab }
      if show_entities then table.insert(tabs, entities_tab) end
      table.insert(tabs, tiles_tab)

      return {
         {
            name = "decon_planner",
            tabs = tabs,
         },
      }
   end,
})

UiRouter.register_ui(mod.decon_planner_menu)

return mod
