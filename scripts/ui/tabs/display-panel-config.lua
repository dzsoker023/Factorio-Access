--[[
Display panel configuration tab.

Lets players browse and edit the message records of a display-panel entity's
control behavior. Each record is {condition, icon, text} - see
llm-docs/api-reference/runtime/classes/LuaDisplayPanelControlBehavior.md and
.../concepts/DisplayPanelMessageDefinition.md.

CONFIRMED IN-GAME (Factorio 2.1.17): the real attribute/method names are
records / records_count / max_records_count / get_record / set_record /
add_record / remove_record / move_record. This repo's local llm-docs mirror
says messages / get_message / set_message for this one class - that's wrong
for the installed game version (crashes with "doesn't contain key messages").
Don't "fix" this back to messages without retesting in-game first.

CONFIRMED IN-GAME: entity.get_control_behavior() is nil for a display panel
with no circuit wire connected at all - there's no records array to read in
that state, not just an empty one. Per LuaEntity.display_panel_text/
display_panel_icon ("Can be written only when it is not set by control
behavior"), that's exactly when the entity-level display_panel_text/
display_panel_icon fields become the editable single static message. So:
- no control behavior, or a control behavior with zero records: edit the
  single static message directly via entity.display_panel_text/icon. It has
  no condition - there's nothing to configure there, and no add-record
  button either.
- control behavior with at least one record: edit the records list; the
  static fields go back to being read-only (driven by whichever record's
  condition is currently true), so the static row is hidden.
Removing the last record makes the static fields writable again.

The game evaluates records top to bottom and shows only the first one whose
condition is currently true, so their order matters. Reordering uses the
same Shift+W / Shift+S drag keys already used for the blueprint book list
(on_drag_up/on_drag_down), mirroring LuaDisplayPanelControlBehavior.move_record.

Each message (static or record) is shown as a row: text, icon, full summary
- navigate between them left/right like any other row; [ (on_click) opens
text/icon for editing, same as everywhere else.

For a real record (never the static message - it has no condition), the
whole row also carries the combinator-style condition quick keys: M
(on_action1) opens the first signal chooser, comma (on_action2) cycles the
comparator (Shift+comma reverses), dot (on_action3) opens the second signal
chooser (Shift+dot opens a textbox for a constant instead) - same mapping
as decider-combinator.lua's condition row, just working from any item in
the row instead of needing a dedicated condition column.

There's no separate "unconfigured" condition readout anywhere. The full
summary (last item) only gets an " if <signal> <comparator> <signal or
number>" suffix once the condition actually has a first signal set - an
unconfigured condition on a record that already has a message shows no
different from one with no condition at all.
]]

local CircuitNetwork = require("scripts.circuit-network")
local FormBuilder = require("scripts.ui.form-builder")
local Speech = require("scripts.speech")
local UiKeyGraph = require("scripts.ui.key-graph")
local UiRouter = require("scripts.ui.router")
local UiSounds = require("scripts.ui.sounds")

local mod = {}

---A freshly added record still needs *some* condition table, since the
---field is required. An empty condition reads first_signal as absent
---(value 0) and defaults comparator to "<", so `{}` alone would compare
---0 < 0 = false and the message would never show until the player
---configured it. Defaulting to "=" instead makes it 0 = 0 = true, so a
---brand new record is immediately visible with whatever icon/text is set.
---@return CircuitConditionDefinition
local function default_condition()
   return { comparator = "=" }
end

---`icon` is a required field on DisplayPanelMessageDefinition, so "no icon"
---has to be written back as an empty SignalID table rather than nil - if we
---dropped the key entirely (which is what `t.icon = nil` does to a Lua
---table) the record we write back would be missing a required field.
---@return SignalID
local function no_icon()
   return {}
end

---@param control_behavior LuaDisplayPanelControlBehavior
---@param index integer
---@param field "condition"|"icon"|"text"
---@return any
local function get_record_field(control_behavior, index, field)
   local record = control_behavior.get_record(index)
   if not record then return nil end
   return record[field]
end

---Read-modify-write a single field of one record, since records are plain
---tables (not live references back into the control behavior).
---@param control_behavior LuaDisplayPanelControlBehavior
---@param index integer
---@param field "condition"|"icon"|"text"
---@param value any
local function set_record_field(control_behavior, index, field, value)
   local record = control_behavior.get_record(index) or { condition = default_condition(), icon = no_icon(), text = "" }
   if field == "icon" and value == nil then value = no_icon() end
   record[field] = value
   control_behavior.set_record(index, record)
end

---Icon+text preview, shared by the static message and every record, with
---an " if <signal> <comparator> <signal-or-number>" suffix when `condition`
---is given and actually configured (has a first signal). No suffix at all
---otherwise - an unconfigured condition is not called out as such.
---@param icon SignalID?
---@param text string?
---@param condition CircuitConditionDefinition?
---@return LocalisedString
local function summarize_message(icon, text, condition)
   local mb = Speech.MessageBuilder.new()

   if icon and icon.name then
      local signal_type = icon.type or "item"
      mb:fragment({ "fa.signal-type-name", signal_type, icon.name })
   end

   if text and text ~= "" then
      -- Rich text processing happens globally in Speech.speak.
      mb:fragment(text)
   else
      mb:fragment({ "fa.empty" })
   end

   if condition and condition.first_signal and condition.first_signal.name then
      mb:fragment({ "fa.display-panel-condition-if" })
      mb:fragment(CircuitNetwork.localise_signal(condition.first_signal))
      mb:fragment(CircuitNetwork.localise_comparator(condition.comparator))
      if condition.second_signal and condition.second_signal.name then
         mb:fragment(CircuitNetwork.localise_signal(condition.second_signal))
      else
         mb:fragment(tostring(condition.constant or 0))
      end
   end

   return mb:build()
end

---Combinator-style quick-key condition actions (M/comma/dot), meant to be
---merged into every item of a record's row so the whole row responds to
---them, not one dedicated column. Mirrors decider-combinator.lua's
---condition row mapping. `item_key` is the specific row item these are
---attached to (its own key doubles as the child-UI/textbox context so
---results route back to it).
---@param item_key string
---@param get_condition fun(): CircuitConditionDefinition?
---@param set_condition fun(CircuitConditionDefinition)
---@return { on_action1: fun(ctx), on_action2: fun(ctx), on_action3: fun(ctx), is_own_result: fun(ctx): boolean, handle_result: fun(ctx, result) }
local function condition_quick_actions(item_key, get_condition, set_condition)
   return {
      on_action1 = function(ctx)
         ctx.controller:open_child_ui(UiRouter.UI_NAMES.SIGNAL_CHOOSER, {}, { node = item_key, target = "first_signal" })
      end,
      on_action2 = function(ctx)
         local condition = get_condition() or default_condition()
         local current_op = condition.comparator or "="
         local new_op = (ctx.modifiers and ctx.modifiers.shift) and CircuitNetwork.get_prev_comparison_operator(current_op)
            or CircuitNetwork.get_next_comparison_operator(current_op)
         condition.comparator = new_op
         set_condition(condition)
         ctx.controller.message:fragment(CircuitNetwork.localise_comparator(new_op))
      end,
      on_action3 = function(ctx)
         if ctx.modifiers and ctx.modifiers.shift then
            ctx.controller:open_textbox(
               "",
               { node = item_key, target = "constant" },
               { intro_message = { "fa.display-panel-enter-constant" } }
            )
         else
            ctx.controller:open_child_ui(UiRouter.UI_NAMES.SIGNAL_CHOOSER, {}, { node = item_key, target = "second_signal" })
         end
      end,
      -- The same item may open OTHER child UIs/textboxes too (e.g. the
      -- text item's own rich textbox, the icon item's own signal chooser)
      -- whose contexts aren't shaped like this. Only a condition quick
      -- action's context carries `.target`, so that's how each item's own
      -- on_child_result tells the two apart before deferring here.
      is_own_result = function(ctx)
         return type(ctx.child_context) == "table" and ctx.child_context.target ~= nil
      end,
      handle_result = function(ctx, result)
         local target = ctx.child_context.target
         local condition = get_condition() or default_condition()
         if target == "first_signal" then
            condition.first_signal = result
            set_condition(condition)
            ctx.controller.message:fragment(CircuitNetwork.localise_signal(result))
         elseif target == "second_signal" then
            condition.second_signal = result
            condition.constant = nil
            set_condition(condition)
            ctx.controller.message:fragment(CircuitNetwork.localise_signal(result))
         elseif target == "constant" then
            local num = tonumber(result)
            if num then
               condition.second_signal = nil
               condition.constant = math.floor(num)
               set_condition(condition)
               ctx.controller.message:fragment(tostring(math.floor(num)))
            else
               -- Not fa.error-invalid-number: that key doesn't exist in
               -- locale (decider-combinator.lua references it too, but
               -- it's wrong there as well - the real key is this one).
               ctx.controller.message:fragment({ "fa.condition-error-invalid-number" })
            end
         end
      end,
   }
end

---Add one message row: [text] [icon] [full summary]. When opts.condition
---is given (real records only - the static message has no condition), the
---combinator quick keys (M/comma/dot) are merged into all three items so
---they work no matter which one currently has focus.
---@param builder fa.ui.form.FormBuilder
---@param key_prefix string
---@param opts {
---get_text: fun(): string?, set_text: fun(string),
---get_icon: fun(): SignalID?, set_icon: fun(SignalID?),
---condition: { get: fun(): CircuitConditionDefinition?, set: fun(CircuitConditionDefinition) }?,
---full_label: fun(ctx: fa.ui.graph.Ctx),
---on_clear_full: (fun(ctx: fa.ui.graph.Ctx))?,
---on_drag_up: fa.ui.graph.SimpleCallback?,
---on_drag_down: fa.ui.graph.SimpleCallback?,
---on_dangerous_delete: fa.ui.graph.SimpleCallback?,
---}
local function add_message_row(builder, key_prefix, opts)
   builder:start_row(key_prefix)

   local text_key = key_prefix .. "_text"
   local text_quick = opts.condition and condition_quick_actions(text_key, opts.condition.get, opts.condition.set)

   builder:add_item(text_key, {
      label = function(ctx)
         local text = opts.get_text()
         ctx.message:fragment(text and text ~= "" and text or { "fa.empty" })
         ctx.message:fragment({ "fa.display-panel-record-text-label" })
      end,
      on_click = function(ctx)
         ctx.controller:open_textbox("", text_key, { rich_text = true })
      end,
      on_action1 = text_quick and text_quick.on_action1,
      on_action2 = text_quick and text_quick.on_action2,
      on_action3 = text_quick and text_quick.on_action3,
      on_child_result = function(ctx, result)
         if text_quick and text_quick.is_own_result(ctx) then
            text_quick.handle_result(ctx, result)
            return
         end
         if type(result) == "table" and result.errors then
            UiSounds.play_ui_edge(ctx.pindex)
            for _, error_msg in ipairs(result.errors) do
               ctx.controller.message:fragment(error_msg)
            end
            return
         end
         local value = (type(result) == "table" and result.value) or ""
         opts.set_text(value)
         ctx.controller.message:fragment(value ~= "" and value or { "fa.empty" })
      end,
      on_clear = function(ctx)
         opts.set_text("")
         ctx.controller.message:fragment({ "fa.cleared" })
      end,
   })

   local icon_key = key_prefix .. "_icon"
   local icon_quick = opts.condition and condition_quick_actions(icon_key, opts.condition.get, opts.condition.set)

   builder:add_item(icon_key, {
      label = function(ctx)
         local icon = opts.get_icon()
         if icon and icon.name then
            local signal_type = icon.type or "item"
            ctx.message:fragment({ "fa.signal-type-name", signal_type, icon.name })
         else
            ctx.message:fragment({ "fa.empty" })
         end
         ctx.message:fragment({ "fa.display-panel-record-icon-label" })
      end,
      on_click = function(ctx)
         ctx.controller:open_child_ui(UiRouter.UI_NAMES.SIGNAL_CHOOSER, {}, { node = icon_key })
      end,
      on_action1 = icon_quick and icon_quick.on_action1,
      on_action2 = icon_quick and icon_quick.on_action2,
      on_action3 = icon_quick and icon_quick.on_action3,
      on_child_result = function(ctx, result)
         if icon_quick and icon_quick.is_own_result(ctx) then
            icon_quick.handle_result(ctx, result)
            return
         end
         opts.set_icon(result)
         if result and result.name then
            local signal_type = result.type or "item"
            ctx.controller.message:fragment({ "fa.signal-type-name", signal_type, result.name })
         else
            ctx.controller.message:fragment({ "fa.empty" })
         end
      end,
      on_clear = function(ctx)
         opts.set_icon(nil)
         ctx.controller.message:fragment({ "fa.empty" })
      end,
   })

   local full_key = key_prefix .. "_full"
   local full_quick = opts.condition and condition_quick_actions(full_key, opts.condition.get, opts.condition.set)

   builder:add_item(full_key, {
      label = opts.full_label,
      on_clear = opts.on_clear_full,
      on_drag_up = opts.on_drag_up,
      on_drag_down = opts.on_drag_down,
      on_dangerous_delete = opts.on_dangerous_delete,
      on_action1 = full_quick and full_quick.on_action1,
      on_action2 = full_quick and full_quick.on_action2,
      on_action3 = full_quick and full_quick.on_action3,
      on_child_result = full_quick
         and function(ctx, result)
            if full_quick.is_own_result(ctx) then full_quick.handle_result(ctx, result) end
         end,
   })

   builder:end_row()
end

---@param ctx fa.ui.graph.Ctx
---@return fa.ui.graph.Render?
local function render_display_panel_config(ctx)
   local entity = (ctx.global_parameters and ctx.global_parameters.entity)
      or (ctx.tablist_shared_state and ctx.tablist_shared_state.entity)
   if not entity or not entity.valid then return nil end

   local control_behavior = entity.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior?]]
   local count = control_behavior and control_behavior.records_count or 0

   local builder = FormBuilder.FormBuilder.new()

   -- These two live on the entity itself, not the control behavior - see
   -- LuaEntity.display_panel_always_show and .display_panel_show_in_chart.
   builder:add_checkbox("always_show", { "fa.display-panel-always-show-label" }, function()
      return entity.display_panel_always_show or false
   end, function(value)
      entity.display_panel_always_show = value
   end)

   builder:add_checkbox("show_in_chart", { "fa.display-panel-show-in-chart-label" }, function()
      return entity.display_panel_show_in_chart or false
   end, function(value)
      entity.display_panel_show_in_chart = value
   end)

   if count == 0 then
      -- No record is driving the display, so the entity-level static
      -- text/icon are writable - this is the only message the panel shows.
      add_message_row(builder, "static_message", {
         get_text = function()
            return entity.display_panel_text
         end,
         set_text = function(value)
            entity.display_panel_text = value
         end,
         get_icon = function()
            return entity.display_panel_icon
         end,
         set_icon = function(value)
            entity.display_panel_icon = value
         end,
         full_label = function(ctx2)
            ctx2.message:fragment(summarize_message(entity.display_panel_icon, entity.display_panel_text))
         end,
         on_clear_full = function(ctx2)
            entity.display_panel_text = ""
            entity.display_panel_icon = nil
            ctx2.controller.message:fragment({ "fa.cleared" })
         end,
      })

      if control_behavior then
         builder:add_label("no_records_note", function(ctx2)
            ctx2.message:fragment({ "fa.display-panel-no-records-note" })
         end)
      else
         builder:add_label("no_wire_note", function(ctx2)
            ctx2.message:fragment({ "fa.display-panel-no-wire-note" })
         end)
      end
   end

   if control_behavior then
      local max_count = control_behavior.max_records_count

      if count > 0 then
         builder:add_label("record_count", function(ctx2)
            ctx2.message:fragment({ "fa.display-panel-records-count", count, max_count })
         end)

         for i = 1, count do
            local key_prefix = "record_" .. i

            add_message_row(builder, key_prefix, {
               get_text = function()
                  return get_record_field(control_behavior, i, "text")
               end,
               set_text = function(value)
                  set_record_field(control_behavior, i, "text", value)
               end,
               get_icon = function()
                  return get_record_field(control_behavior, i, "icon")
               end,
               set_icon = function(value)
                  set_record_field(control_behavior, i, "icon", value)
               end,
               condition = {
                  get = function()
                     return get_record_field(control_behavior, i, "condition")
                  end,
                  set = function(value)
                     set_record_field(control_behavior, i, "condition", value)
                  end,
               },
               full_label = function(ctx2)
                  ctx2.message:fragment({ "fa.display-panel-record-header", i })
                  ctx2.message:fragment(summarize_message(
                     get_record_field(control_behavior, i, "icon"),
                     get_record_field(control_behavior, i, "text"),
                     get_record_field(control_behavior, i, "condition")
                  ))
               end,
               on_clear_full = function(ctx2)
                  set_record_field(control_behavior, i, "text", "")
                  set_record_field(control_behavior, i, "icon", nil)
                  ctx2.controller.message:fragment({ "fa.cleared" })
               end,
               on_drag_up = function(ctx2)
                  if i == 1 then
                     ctx2.controller.message:fragment({ "fa.display-panel-record-already-first" })
                     return
                  end
                  control_behavior.move_record(i, i - 1)
                  UiSounds.play_menu_move(ctx2.pindex)
                  ctx2.controller.message:fragment({ "fa.display-panel-record-moved-to-position", i - 1 })
                  ctx2.graph_controller:suggest_move("record_" .. (i - 1) .. "_full")
               end,
               on_drag_down = function(ctx2)
                  if i == count then
                     ctx2.controller.message:fragment({ "fa.display-panel-record-already-last" })
                     return
                  end
                  control_behavior.move_record(i, i + 1)
                  UiSounds.play_menu_move(ctx2.pindex)
                  ctx2.controller.message:fragment({ "fa.display-panel-record-moved-to-position", i + 1 })
                  ctx2.graph_controller:suggest_move("record_" .. (i + 1) .. "_full")
               end,
               on_dangerous_delete = function(ctx2)
                  control_behavior.remove_record(i)
                  ctx2.controller.message:fragment({ "fa.display-panel-record-deleted", i })
                  ctx2.graph_controller:suggest_move("record_count")
               end,
            })
         end
      end

      builder:add_item("add_record", {
         label = function(ctx2)
            ctx2.message:fragment({ "fa.display-panel-add-record" })
         end,
         on_click = function(ctx2)
            local new_index = count + 1
            local added = control_behavior.add_record({
               condition = default_condition(),
               icon = no_icon(),
               text = "",
            })
            UiSounds.play_menu_move(ctx2.pindex)
            if added then
               ctx2.controller.message:fragment({ "fa.display-panel-record-added", new_index })
               ctx2.graph_controller:suggest_move("record_" .. new_index .. "_full")
            else
               ctx2.controller.message:fragment({ "fa.display-panel-record-full" })
            end
         end,
      })
   end

   return builder:build()
end

mod.display_panel_config_tab = UiKeyGraph.declare_graph({
   name = "display-panel-config",
   title = { "fa.display-panel-config-title" },
   render_callback = render_display_panel_config,
})

---Check if this tab is available for the given entity
---@param entity LuaEntity
---@return boolean
function mod.is_available(entity)
   return entity and entity.valid and entity.type == "display-panel"
end

return mod
