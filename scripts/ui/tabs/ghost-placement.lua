--[[
Ghost placement tab.

Lets the player pick an item to place as a ghost via the cursor ghost (LuaControl.cursor_ghost),
for situations where there is no character to craft with or manage a personal inventory for -
e.g. remote view, or riding a space platform while it's travelling between locations (both use
the "remote" controller). Space platforms don't carry a character until they land, but ghosts
can still be dropped for construction bots to build once they do.

The item chooser lists both entity-placing items (e.g. a storage tank) and tile-placing items
(e.g. space platform foundation, landfill) - both become the corresponding kind of ghost.

Once an item is chosen here, the normal build key (fa-leftbracket) places ghosts of it, same as
it already does for a normal held item - see kb_click_hand in control.lua. Ghost placement itself
goes through mod.place_ghost_via_script in building-tools.lua rather than the usual
build_from_cursor path: as of Factorio 2.0.72, LuaPlayer.can_build_from_cursor/build_from_cursor
ignore LuaControl.cursor_ghost entirely (confirmed engine bug, fixed for 2.1), so those can't be
used for a cursor-ghost-only build right now.
]]

local KeyGraph = require("scripts.ui.key-graph")
local Localising = require("scripts.localising")
local Menu = require("scripts.ui.menu")
local Router = require("scripts.ui.router")
local ItemChooser = require("scripts.ui.tabs.item-chooser")
local Viewpoint = require("scripts.viewpoint")
local dirs = defines.direction

local mod = {}

---@param ctx fa.ui.graph.Ctx
local function render_ghost_placement(ctx)
   local builder = Menu.MenuBuilder.new()
   local player = game.get_player(ctx.pindex)

   builder:add_clickable("choose_ghost_item", function(label_ctx)
      local ghost = player.cursor_ghost
      if ghost then
         -- `ghost.name` is already a LuaItemPrototype when read (unlike when writing it below,
         -- where a plain item name string is what's expected) - no `prototypes.item[...]` lookup
         -- needed or correct here.
         label_ctx.message:fragment({
            "fa.ghost-placement-current",
            Localising.get_localised_name_with_fallback(ghost.name),
         })
      else
         label_ctx.message:fragment({ "fa.ghost-placement-choose-item" })
      end
   end, {
      on_click = function(click_ctx)
         click_ctx.controller:open_child_ui(
            Router.UI_NAMES.ITEM_CHOOSER,
            { filter_type = ItemChooser.FILTER_TYPES.PLACEABLE },
            { node = "choose_ghost_item" }
         )
      end,
      on_child_result = function(result_ctx, item_name)
         if not item_name then return end
         local p = game.get_player(result_ctx.pindex)
         p.cursor_ghost = { name = item_name }
         -- Reset direction and flip state, same as picking up a new real item does (see
         -- on_cursor_stack_changed in cursor-changes.lua) - setting cursor_ghost doesn't fire that
         -- handler (it only watches cursor_stack), so without this a freshly chosen ghost item
         -- would otherwise keep whatever direction/flip was last left over from something else
         -- entirely - e.g. a leftover flipped_horizontal=true from a blueprint used earlier in the
         -- session gets passed straight through to can_build_from_cursor's flip_horizontal
         -- parameter for this entity too, and can silently make an otherwise valid placement fail.
         local vp = Viewpoint.get_viewpoint(result_ctx.pindex)
         vp:set_hand_direction(dirs.north)
         vp:set_flipped_horizontal(false)
         vp:set_flipped_vertical(false)
         local proto = prototypes.item[item_name]
         result_ctx.controller.message:fragment({
            "fa.ghost-item-selected",
            proto and Localising.get_localised_name_with_fallback(proto) or item_name,
         })
         -- Close back to the game so the build key can be used right away.
         result_ctx.controller:close()
      end,
      on_clear = function(clear_ctx)
         if not player.cursor_ghost then
            clear_ctx.controller.message:fragment({ "fa.ghost-placement-nothing-to-clear" })
            return
         end
         player.cursor_ghost = nil
         clear_ctx.controller.message:fragment({ "fa.ghost-placement-cleared" })
      end,
   })

   return builder:build()
end

mod.ghost_placement_tab = KeyGraph.declare_graph({
   name = "ghost-placement",
   title = { "fa.ghost-placement-title" },
   render_callback = render_ghost_placement,
})

return mod
