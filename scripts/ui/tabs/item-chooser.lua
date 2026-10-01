local TreeChooser = require("scripts.ui.tree-chooser")
local KeyGraph = require("scripts.ui.key-graph")
local TabList = require("scripts.ui.tab-list")
local UiRouter = require("scripts.ui.router")
local SignalHelpers = require("scripts.ui.signal-helpers")

local mod = {}

-- Predefined filter types for item chooser
mod.FILTER_TYPES = {
   MODULE = "module",
   PLACEABLE = "placeable",
   -- [GHOST-ITEM-REQUESTS] Added for ghost-requests-config.lua: same idea as MODULE, but for
   -- ammo/fuel items. Both take an optional `params.categories` (Dictionary[string, true]) to
   -- narrow results to specific ammo/fuel categories - see the FILTERS factory functions below.
   AMMO = "ammo",
   FUEL = "fuel",
}

---Sentinel result returned when "No module" is picked instead of a real
---module item. Not a valid item name, so it can never collide with one.
---Used by the upgrade planner menu's module rule flow to represent an empty
---module slot as a mapper source/destination - see UpgradeMapperSource's
---`name` field being optional in the API docs, and
---scripts/upgrade-planner.lua's get_mapper_name, which already speaks that
---case back as "No module" when reading an existing rule.
mod.NO_MODULE_RESULT = "__fa_no_module__"

-- Filter FACTORY functions by type. Each takes `params` (the global_parameters table passed to
-- open_child_ui) and returns a plain `function(proto): boolean` predicate - that single-arg shape
-- is what SignalHelpers.add_item_signals expects as its extra_filter. Going through a factory
-- (rather than a flat function(proto) like before [GHOST-ITEM-REQUESTS]) lets callers narrow a
-- filter with their own parameters, e.g. `{filter_type = FILTER_TYPES.AMMO, categories = {...}}`,
-- following the same (proto, params) pattern already used in entity-chooser.lua's FILTERS.
local FILTERS = {
   [mod.FILTER_TYPES.MODULE] = function(params)
      -- `params.categories` (Dictionary[string, true], optional): restricts to module items whose
      -- own `.category` (a LuaModuleCategoryPrototype name) is in the set - used by
      -- ghost-requests-config.lua to match LuaEntityPrototype.allowed_module_categories. Omitted
      -- (as the upgrade planner's calls still do) means no restriction, same as before this change.
      local categories = params and params.categories
      return function(proto)
         if proto.type ~= "module" then return false end
         if not categories then return true end
         return proto.category ~= nil and categories[proto.category] == true
      end
   end,
   -- Items that can be placed as a ghost - either an entity (e.g. a storage tank) or a tile
   -- (e.g. space platform foundation, landfill). Ghosts of both are placed directly via
   -- LuaSurface.create_entity (see mod.place_ghost_via_script in building-tools.lua), not through
   -- LuaPlayer.build_from_cursor - which, as of Factorio 2.0.72, ignores cursor_ghost entirely
   -- (confirmed engine bug, fixed for 2.1).
   [mod.FILTER_TYPES.PLACEABLE] = function(params)
      return function(proto)
         return proto.place_result ~= nil or proto.place_as_tile_result ~= nil
      end
   end,
   -- [GHOST-ITEM-REQUESTS] `params.categories`: LuaAmmoCategoryPrototype names accepted by the
   -- target (from LuaEntityPrototype.attack_parameters.ammo_categories, turned into a set by the
   -- caller). Omitted means "any ammo item" - used when the target has no attack_parameters to
   -- consult (car/spidertron: their ammo compatibility depends on a gun item that isn't placed yet
   -- on a ghost, so there is nothing narrower to filter by).
   [mod.FILTER_TYPES.AMMO] = function(params)
      local categories = params and params.categories
      return function(proto)
         if proto.type ~= "ammo" then return false end
         if not categories then return true end
         return proto.ammo_category ~= nil and categories[proto.ammo_category.name] == true
      end
   end,
   -- [GHOST-ITEM-REQUESTS] `params.categories`: fuel category names accepted by the target's
   -- burner (from LuaBurnerPrototype.fuel_categories, already a Dictionary[string, true] - see
   -- ghost-requests-config.lua). Always required in practice; treated as "no restriction" if
   -- omitted only for symmetry with the other filters here.
   [mod.FILTER_TYPES.FUEL] = function(params)
      local categories = params and params.categories
      return function(proto)
         if not proto.fuel_category then return false end
         if not categories then return true end
         return categories[proto.fuel_category] == true
      end
   end,
}

---@param ctx fa.ui.graph.Ctx
local function build_item_tree(ctx)
   local builder = TreeChooser.TreeChooserBuilder.new()
   local player = game.get_player(ctx.pindex)
   local force = player.force --[[@as LuaForce]]

   -- Get filter type from global parameters (passed to open_child_ui)
   local params = ctx.global_parameters or {}
   local filter_type = params.filter_type
   local filter_factory = filter_type and FILTERS[filter_type]
   local extra_filter = filter_factory and filter_factory(params)

   -- For the module chooser specifically, also offer "No module" as its own
   -- choice, alongside the real module items - vanilla's upgrade planner can
   -- map an empty module slot to a module, or a module to an empty slot
   -- (removing it), and without this there was no way to pick that. Make it
   -- the first thing the player lands on (rather than just a root-level
   -- sibling buried alongside category groups like "Production") so it's
   -- actually discoverable without first going down into a category and
   -- back up.
   -- Gated on `params.offer_no_module` (not just filter_type == MODULE) since
   -- [GHOST-ITEM-REQUESTS] the MODULE filter is now also used for ghost module requests, where
   -- "No module" makes no sense (a ghost request is either present or simply not added - there is
   -- no "request nothing" entry to pick). Only the upgrade planner menu passes this flag.
   if filter_type == mod.FILTER_TYPES.MODULE and params.offer_no_module then
      builder:add_node("no_module", TreeChooser.ROOT, {
         label = function(node_ctx)
            node_ctx.message:fragment({ "fa.upgrade-mapper-no-module" })
         end,
         on_click = function(click_ctx)
            click_ctx.controller:close_with_result(mod.NO_MODULE_RESULT)
         end,
      })
      builder:set_start_key("no_module")
   end

   -- Use signal helper to add items (with unlocked filter and optional extra filter)
   -- Pass converter to return just the name string, not SignalID
   SignalHelpers.add_item_signals(builder, TreeChooser.ROOT, true, force, function(name)
      return name
   end, extra_filter)

   return builder:build()
end

local item_chooser_tab = KeyGraph.declare_graph({
   name = "item_chooser",
   render_callback = build_item_tree,
   title = { "fa.item-chooser-title" },
})

mod.item_chooser_menu = TabList.declare_tablist({
   ui_name = UiRouter.UI_NAMES.ITEM_CHOOSER,
   resets_to_first_tab_on_open = true,
   tabs_callback = function()
      return {
         {
            name = "item_chooser",
            tabs = { item_chooser_tab },
         },
      }
   end,
})

UiRouter.register_ui(mod.item_chooser_menu)

return mod
