--Here: Quickbar related functions
local Localising = require("scripts.localising")
local Speech = require("scripts.speech")
local MessageBuilder = Speech.MessageBuilder
local UiRouter = require("scripts.ui.router")

local mod = {}

---Get the item prototype name held in a quick bar slot, or nil if the slot is
---empty or holds a non-item (a blueprint record or spidertron remote).
---@param slot QuickBarSlot?
---@return string?
local function quick_bar_slot_item_name(slot)
   if not slot then return nil end
   if slot.type == "item" and slot.item then return slot.item.name end
   if slot.type == "filter" and slot.filter then
      if type(slot.filter) == "string" then return slot.filter end
      return slot.filter.name
   end
   return nil
end

---@param event EventData.CustomInputEvent
function mod.quickbar_get_handler(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   if
      storage.players[pindex].menu == "inventory"
      or storage.players[pindex].menu == "none"
      or (storage.players[pindex].menu == "building" or storage.players[pindex].menu == "vehicle")
   then
      local num = tonumber(string.sub(event.input_name, -1))
      if num == 0 then num = 10 end
      mod.read_quick_bar_slot(num, pindex)
   end
end

--all 10 quickbar slot setting event handlers
---@param event EventData.CustomInputEvent
function mod.quickbar_set_handler(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end
   local num = tonumber(string.sub(event.input_name, -1))
   if num == 0 then num = 10 end
   mod.set_quick_bar_slot(num, pindex)
end

--all 10 quickbar page setting event handlers
---@param event EventData.CustomInputEvent
function mod.quickbar_page_handler(event)
   local pindex = event.player_index
   if not check_for_player(pindex) then return end

   local num = tonumber(string.sub(event.input_name, -1))
   if num == 0 then num = 10 end
   mod.read_switched_quick_bar(num, pindex)
end

function mod.read_quick_bar_slot(index, pindex)
   local page = game.get_player(pindex).get_active_quick_bar_page(1)
   local item_name = quick_bar_slot_item_name(game.get_player(pindex).get_quick_bar_slot(page, index))
   if item_name ~= nil then
      local proto = prototypes.item[item_name]
      local count = game.get_player(pindex).get_main_inventory().get_item_count(item_name)
      local stack = game.get_player(pindex).cursor_stack
      if stack and stack.valid_for_read then
         count = count + stack.count
         local msg = MessageBuilder.new()
         msg:fragment({ "fa.quickbar-unselected" })
         msg:fragment(Localising.get_localised_name_with_fallback(proto))
         msg:fragment({ "fa.quickbar-count", count })
         Speech.speak(pindex, msg:build())
      else
         local msg = MessageBuilder.new()
         msg:fragment({ "fa.quickbar-selected" })
         msg:fragment(Localising.get_localised_name_with_fallback(proto))
         msg:fragment({ "fa.quickbar-count", count })
         Speech.speak(pindex, msg:build())
      end
   else
      Speech.speak(pindex, { "fa.quickbar-empty-slot" }) --does this print, maybe not working because it is linked to the game control?
   end
end

function mod.set_quick_bar_slot(index, pindex)
   local p = game.get_player(pindex)
   local router = UiRouter.get_router(pindex)
   local page = game.get_player(pindex).get_active_quick_bar_page(1)
   local stack_cur = game.get_player(pindex).cursor_stack
   local ent = p.selected
   if stack_cur and stack_cur.valid_for_read and stack_cur.valid == true then
      game.get_player(pindex).set_quick_bar_slot(page, index, stack_cur)
      local msg = MessageBuilder.new()
      msg:fragment({ "fa.quickbar-assigned", index })
      msg:fragment(Localising.get_localised_name_with_fallback(stack_cur))
      Speech.speak(pindex, msg:build())
   else
      --Clear the slot
      local item_name = quick_bar_slot_item_name(game.get_player(pindex).get_quick_bar_slot(page, index))
      local item_desc = nil
      if item_name ~= nil then item_desc = Localising.get_localised_name_with_fallback(prototypes.item[item_name]) end
      game.get_player(pindex).set_quick_bar_slot(page, index, nil)
      local msg = MessageBuilder.new()
      msg:fragment({ "fa.quickbar-unassigned", index })
      if item_desc then msg:fragment(item_desc) end
      Speech.speak(pindex, msg:build())
   end
end

function mod.read_switched_quick_bar(index, pindex)
   local item_name = quick_bar_slot_item_name(game.get_player(pindex).get_quick_bar_slot(index, 1))
   local msg = MessageBuilder.new()
   msg:fragment({ "fa.quickbar-page-selected", index })
   if item_name ~= nil then
      msg:fragment(Localising.get_localised_name_with_fallback(prototypes.item[item_name]))
   else
      msg:fragment({ "fa.quickbar-empty-slot" })
   end
   Speech.speak(pindex, msg:build())
end

return mod
