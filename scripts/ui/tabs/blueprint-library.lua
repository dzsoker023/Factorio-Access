--[[
Blueprint Library tabs: browse the two shelves the scripting API exposes -
game.blueprints ("game blueprints", shared/in-save) and player.blueprints
("my blueprints", per-player). Embedded as a section of the main inventory
view (E) - reach it with Ctrl+Tab to "Blueprint Library", then plain Tab
to switch between the two shelves.

[BLUEPRINT-LIBRARY-TAB] api limitations, library access:
  - LuaRecord is only ever "a reference to a record IN the blueprint
    library" (its own doc's wording) - there is no constructor for one
    anywhere in the API, and game.blueprints/player.blueprints only have
    a Read type, no Write type. So this tab can browse, rename, and copy
    EXISTING entries, but scripting can never add a brand new one to
    either shelf. In vanilla the only way an entry is created is the
    player dragging a blueprint onto the library window with a mouse -
    which is exactly the interaction this mod exists to route around, so
    for now the shelves stay populated only by however they already got
    filled (e.g. another player's doing, in multiplayer). Renaming an
    EXISTING "game blueprints" entry does work from script - LuaRecord's
    doc calls those specific records read/write - it's only entry
    creation that's unreachable.
  - LuaControl.cursor_record has no "Write type" in the API docs (only a
    Read type), so a library record can never be linked live into the
    player's hand from script. "Activating" a record below therefore makes
    an ordinary, disconnected COPY in the cursor - the same
    set_stack + import_stack sequence scripts/blueprints.lua already uses
    for blueprint import - rather than a true reference back into the
    library entry.
  - LuaRecord has no per-record delete/destroy method, and defines.
    input_action's delete_blueprint_record/drop_blueprint_record entries
    (the internal actions the native GUI sends when a player drags a
    blueprint in or out) aren't reachable through any script.raise_*
    call - that whitelist doesn't include them. The only deletion-related
    call anywhere in the API is LuaGameScript.delete_blueprint_library
    (player), which wipes a whole shelf at once - far too destructive for
    a "delete this one blueprint" action, so no delete action is offered
    here.
  - Records in the "my blueprints" shelf (player.blueprints) are
    documented as read-only, so only "game blueprints" records can be
    renamed from here.
]]

local KeyGraph = require("scripts.ui.key-graph")
local Menu = require("scripts.ui.menu")
local Speech = require("scripts.speech")

local mod = {}

local ACTIVATE_RESULT = {
   SUCCESS = "success",
   HAND_NOT_EMPTY = "hand_not_empty",
   FAILED = "failed",
}

---Short spoken label for a library record.
---@param record LuaRecord
---@return LocalisedString
local function record_label(record)
   if record.is_preview then return { "fa.blueprint-library-preview" } end
   return record.label or { "fa.unnamed" }
end

---Fuller description of a library record, based on its planner type.
---@param record LuaRecord
---@return LocalisedString
local function describe_record(record)
   local mb = Speech.MessageBuilder.new()

   if record.is_preview then
      mb:fragment({ "fa.blueprint-library-preview" })
      return mb:build()
   end

   if record.type == "blueprint" then
      mb:fragment(record.label or { "fa.unnamed" })
   elseif record.type == "blueprint-book" then
      mb:fragment(record.label or { "fa.unnamed-book" })
   elseif record.type == "deconstruction-planner" then
      mb:fragment(record.label or { "item-name.deconstruction-planner" })
   elseif record.type == "upgrade-planner" then
      mb:fragment(record.label or { "item-name.upgrade-planner" })
   else
      mb:fragment({ "fa.unknown-item" })
   end

   return mb:build()
end

---Put a disconnected copy of a library record into the player's cursor.
---See the [BLUEPRINT-LIBRARY-TAB] comment above for why this can't be a
---live link back to the library entry.
---@param pindex number
---@param record LuaRecord
---@return string result one of ACTIVATE_RESULT
local function activate_record(pindex, record)
   local player = game.get_player(pindex)
   if not player then return ACTIVATE_RESULT.FAILED end

   local cursor = player.cursor_stack
   if not cursor then return ACTIVATE_RESULT.FAILED end
   if cursor.valid_for_read then return ACTIVATE_RESULT.HAND_NOT_EMPTY end

   if not cursor.set_stack({ name = record.type, count = 1 }) then return ACTIVATE_RESULT.FAILED end

   local import_result = cursor.import_stack(record.export_record())
   if import_result == 1 then
      cursor.set_stack(nil)
      return ACTIVATE_RESULT.FAILED
   end

   -- This is now an ordinary owned copy, not a throwaway - keep it even if
   -- the cursor is later cleared without being placed down.
   player.cursor_stack_temporary = false

   return ACTIVATE_RESULT.SUCCESS
end

---Render one blueprint-library shelf as a list of activate (and, if
---writable, rename) rows.
---@param records LuaRecord[]
---@param writable boolean whether records in this shelf can be renamed
---@param info_message LocalisedString always-shown note about what this shelf can/can't do
---@param empty_message LocalisedString
---@return fa.ui.graph.Render
local function render_shelf(records, writable, info_message, empty_message)
   local builder = Menu.MenuBuilder.new()

   builder:add_label("shelf-info", info_message)

   local any = false
   for idx, record in ipairs(records) do
      if record.valid then
         any = true
         builder:start_row("record")

         builder:add_clickable("record-" .. idx, function(c)
            c.message:fragment(describe_record(record))
            c.message:fragment({ "fa.blueprint-library-activate-hint" })
         end, {
            on_click = function(c)
               if record.is_preview then
                  c.message:fragment({ "fa.blueprint-library-preview-cannot-open" })
                  return
               end

               local result = activate_record(c.pindex, record)
               if result == ACTIVATE_RESULT.SUCCESS then
                  c.message:fragment({ "fa.blueprint-library-opened", record_label(record) })
               elseif result == ACTIVATE_RESULT.HAND_NOT_EMPTY then
                  c.message:fragment({ "fa.blueprint-library-hand-not-empty" })
               else
                  c.message:fragment({ "fa.blueprint-library-open-failed" })
               end
            end,
         })

         if writable and not record.is_preview then
            builder:add_clickable("rename-" .. idx, function(c)
               c.message:fragment({ "fa.blueprint-library-rename" })
               c.message:fragment(record.label or { "fa.unnamed" })
            end, {
               on_click = function(c)
                  c.controller:open_textbox("", "rename-" .. idx)
               end,
               on_child_result = function(c, result)
                  record.label = result
                  c.message:fragment({ "fa.blueprint-library-renamed", result })
               end,
            })
         end

         builder:end_row()
      end
   end

   if not any then builder:add_label("empty", empty_message) end

   return builder:build()
end

---@type fun(fa.ui.graph.Ctx): fa.ui.graph.Render?
local function render_game_blueprints(ctx)
   return render_shelf(
      game.blueprints,
      true,
      { "fa.blueprint-library-game-info" },
      { "fa.blueprint-library-game-empty" }
   )
end

---@type fun(fa.ui.graph.Ctx): fa.ui.graph.Render?
local function render_my_blueprints(ctx)
   local player = game.get_player(ctx.pindex)
   if not player then return nil end
   return render_shelf(
      player.blueprints,
      false,
      { "fa.blueprint-library-mine-info" },
      { "fa.blueprint-library-mine-empty" }
   )
end

mod.game_blueprints_tab = KeyGraph.declare_graph({
   name = "game_blueprints",
   title = { "fa.blueprint-library-game-title" },
   render_callback = render_game_blueprints,
})

mod.my_blueprints_tab = KeyGraph.declare_graph({
   name = "my_blueprints",
   title = { "fa.blueprint-library-mine-title" },
   render_callback = render_my_blueprints,
})

return mod
