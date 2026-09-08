--[[
Display panel configuration tab.

Lets players browse and edit the message records of a display-panel entity's
control behavior. Each record is {condition, icon, text} - see
llm-docs/api-reference/runtime/classes/LuaDisplayPanelControlBehavior.md and
.../concepts/DisplayPanelMessageDefinition.md.

The game evaluates records top to bottom and shows only the first one whose
condition is currently true, so their order matters. Reordering uses the
same Shift+W / Shift+S drag keys already used for the blueprint book list
(on_drag_up/on_drag_down), mirroring LuaDisplayPanelControlBehavior.move_record.
]]

local FormBuilder = require("scripts.ui.form-builder")
local Speech = require("scripts.speech")
local UiKeyGraph = require("scripts.ui.key-graph")
local UiSounds = require("scripts.ui.sounds")

local mod = {}

---A freshly added record still needs *some* condition table, since the
---field is required. An empty condition reads first_signal as absent
---(value 0) and defaults comparator to "<", so `{}` alone would compare
---0 < 0 = false and the message would never show until the player
---configured it. Defaulting to "=" instead makes it 0 = 0 = true, so a
---brand new message is immediately visible with whatever icon/text is set,
---exactly like the simple "no circuit connected" case described to the
---player earlier.
---@return CircuitConditionDefinition
local function default_condition()
   return { comparator = "=" }
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

---@param control_behavior LuaDisplayPanelControlBehavior
---@param index integer
---@param field "condition"|"icon"|"text"
---@param value any
local function set_record_field(control_behavior, index, field, value)
   local record = control_behavior.get_record(index) or { condition = default_condition(), icon = nil, text = "" }
   record[field] = value
   control_behavior.set_record(index, record)
end

---Short summary for a record's header row: its icon and text.
---@param control_behavior LuaDisplayPanelControlBehavior
---@param index integer
---@return LocalisedString
local function record_summary(control_behavior, index)
   local record = control_behavior.get_record(index)
   if not record then return { "fa.empty" } end

   local mb = Speech.MessageBuilder.new()

   if record.icon and record.icon.name then
      local signal_type = record.icon.type or "item"
      mb:fragment({ "fa.signal-type-name", signal_type, record.icon.name })
   end

   if record.text and record.text ~= "" then
      -- Rich text processing happens globally in Speech.speak.
      mb:fragment(record.text)
   else
      mb:fragment({ "fa.empty" })
   end

   return mb:build()
end

---@param ctx fa.ui.graph.Ctx
---@return fa.ui.graph.Render?
local function render_display_panel_config(ctx)
   local entity = (ctx.global_parameters and ctx.global_parameters.entity)
      or (ctx.tablist_shared_state and ctx.tablist_shared_state.entity)
   if not entity or not entity.valid then return nil end

   local control_behavior = entity.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior]]
   if not control_behavior then return nil end

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

   local count = control_behavior.records_count
   local max_count = control_behavior.max_records_count

   builder:add_label("record_count", function(ctx2)
      ctx2.message:fragment({ "fa.display-panel-records-count", count, max_count })
   end)

   for i = 1, count do
      local header_key = "record_" .. i .. "_header"

      builder:add_item(header_key, {
         label = function(ctx2)
            ctx2.message:fragment({ "fa.display-panel-record-header", i })
            ctx2.message:fragment(record_summary(control_behavior, i))
         end,
         on_drag_up = function(ctx2)
            if i == 1 then
               ctx2.controller.message:fragment({ "fa.display-panel-record-already-first" })
               return
            end
            control_behavior.move_record(i, i - 1)
            UiSounds.play_menu_move(ctx2.pindex)
            ctx2.controller.message:fragment({ "fa.display-panel-record-moved-to-position", i - 1 })
            ctx2.graph_controller:suggest_move("record_" .. (i - 1) .. "_header")
         end,
         on_drag_down = function(ctx2)
            if i == count then
               ctx2.controller.message:fragment({ "fa.display-panel-record-already-last" })
               return
            end
            control_behavior.move_record(i, i + 1)
            UiSounds.play_menu_move(ctx2.pindex)
            ctx2.controller.message:fragment({ "fa.display-panel-record-moved-to-position", i + 1 })
            ctx2.graph_controller:suggest_move("record_" .. (i + 1) .. "_header")
         end,
         on_dangerous_delete = function(ctx2)
            control_behavior.remove_record(i)
            ctx2.controller.message:fragment({ "fa.display-panel-record-deleted", i })
            ctx2.graph_controller:suggest_move("record_count")
         end,
      })

      builder:add_signal("record_" .. i .. "_icon", { "fa.display-panel-record-icon-label" }, function()
         return get_record_field(control_behavior, i, "icon")
      end, function(value)
         set_record_field(control_behavior, i, "icon", value)
      end)

      builder:add_condition("record_" .. i .. "_condition", function()
         return get_record_field(control_behavior, i, "condition")
      end, function(value)
         set_record_field(control_behavior, i, "condition", value)
      end)

      builder:add_rich_textfield("record_" .. i .. "_text", {
         label = { "fa.display-panel-record-text-label" },
         get_value = function()
            return get_record_field(control_behavior, i, "text") or ""
         end,
         set_value = function(value)
            set_record_field(control_behavior, i, "text", value)
         end,
      })
   end

   builder:add_item("add_record", {
      label = function(ctx2)
         ctx2.message:fragment({ "fa.display-panel-add-record" })
      end,
      on_click = function(ctx2)
         local new_index = count + 1
         local added = control_behavior.add_record({
            condition = default_condition(),
            icon = nil,
            text = "",
         })
         UiSounds.play_menu_move(ctx2.pindex)
         if added then
            ctx2.controller.message:fragment({ "fa.display-panel-record-added", new_index })
            ctx2.graph_controller:suggest_move("record_" .. new_index .. "_header")
         else
            ctx2.controller.message:fragment({ "fa.display-panel-record-full" })
         end
      end,
   })

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
