--[[
[GHOST-ITEM-REQUESTS] Ghost item requests: lets the player pre-load an
entity ghost with ammo/modules/fuel before it's even built, the same way
vanilla's own (mouse-driven) ghost GUI lets you drag an item onto a
ghost's preview slot. Construction bots deliver the requested items the
moment the ghost is revived.

api limitations, library access (matching the style of the earlier
[LAUNCH-PLAYER-INVENTORY-CHECK]/[BLUEPRINT-LIBRARY-TAB] comments): unlike
the blueprint library, this one IS fully scriptable - LuaEntity.
insert_plan has both a Read type and a Write type (Array[BlueprintInsertPlan]),
so this tab can both show and change requests, not just browse them. The
underlying mechanism is exactly what LuaGameScript/LuaPlayer use for a
placed blueprint's own item requests.

Scope of this first version: ammo, module, and fuel slots only (matching
turret/artillery/car/spidertron ammo; assembling-machine/furnace/lab/
beacon/mining-drill modules; and any burner entity's fuel). Equipment
grid requests (armor/vehicle ghosts) are NOT covered - that needs grid
position math this version doesn't attempt. Ammo compatibility for car/
spidertron ghosts can't be narrowed to "what fits the gun" the way a
turret's built-in attack can, because the gun itself is just another item
that hasn't been placed yet on a ghost - so those offer every ammo item,
not just compatible ones (see the AMMO filter's `categories == nil`
fallback in item-chooser.lua). A request's count can be changed directly
by pressing enter on its row again (ammo/fuel only - a single module slot
always holds exactly one module, so that row isn't editable, only
removable with Backspace).

[GHOST-REQUESTS-MODULE-ALIAS-FIX]: defines.inventory numeric values are
NOT unique per meaning - the engine reuses the same raw integer across
different entity types' inventories (confirmed on the Factorio forums:
e.g. defines.inventory.character_ammo and defines.inventory.
assembling_machine_modules can both equal 4 - they're just two names for
"inventory slot 4", which means something different on each entity type).
That let a gun turret - which only ever has a real turret_ammo inventory -
get offered a bogus "module" request too: LuaEntityPrototype.
get_inventory_size() doesn't know or care that we asked "does this have
a MODULE inventory", it only checks "does raw index N exist", and if
crafter_modules/beacon_modules/etc. happen to numerically alias with the
turret's real ammo index, the probe reports a false "yes". Fix:
get_request_slots now tracks which raw indices are already claimed by an
earlier, definitely-real slot (ammo is probed first) and refuses to also
count that same raw index as a module or fuel slot - see `used_indices`
below.
]]

local EntityAccess = require("scripts.entity-access")
local ItemChooser = require("scripts.ui.tabs.item-chooser")
local KeyGraph = require("scripts.ui.key-graph")
local Localising = require("scripts.localising")
local Menu = require("scripts.ui.menu")
local UiRouter = require("scripts.ui.router")
local UiSounds = require("scripts.ui.sounds")

local mod = {}

-- Candidate defines.inventory values to probe per request kind. At most one
-- of each list should ever exist on a given ghost prototype (they're
-- mutually exclusive by entity type), so `find_inventory` below just
-- returns the first match.
local AMMO_INVENTORIES = {
   defines.inventory.turret_ammo,
   defines.inventory.artillery_turret_ammo,
   defines.inventory.artillery_wagon_ammo,
   defines.inventory.car_ammo,
   defines.inventory.spider_ammo,
}
local MODULE_INVENTORIES = {
   defines.inventory.crafter_modules,
   defines.inventory.beacon_modules,
   defines.inventory.lab_modules,
   defines.inventory.mining_drill_modules,
   defines.inventory.agricultural_tower_modules,
}
local FUEL_INVENTORIES = { defines.inventory.fuel }

---Find the first inventory define from `candidates` that actually exists on
---`prototype`, per LuaEntityPrototype::get_inventory_size - this is the same
---"verify before trusting" check the [SINGLE-FLUID-BOX-CRASH-FIX] lesson
---called for, just applied to inventories instead of control-behavior
---fields.
---
---`used` is a set of raw defines.inventory integer values already claimed
---by an earlier, confirmed-real slot on this same prototype - see
---[GHOST-REQUESTS-MODULE-ALIAS-FIX] at the top of this file. A candidate
---whose raw value is already in `used` is skipped even if get_inventory_size
---would report it as existing, since we already know that raw index means
---something else on this entity.
---@param prototype LuaEntityPrototype
---@param quality string
---@param candidates defines.inventory[]
---@param used table<defines.inventory, true>
---@return defines.inventory? inventory
---@return ItemStackIndex? size
local function find_inventory(prototype, quality, candidates, used)
   for _, inv in ipairs(candidates) do
      if not used[inv] then
         local size = prototype.get_inventory_size(inv, quality)
         if size and size > 0 then return inv, size end
      end
   end
   return nil, nil
end

---@param prototype LuaEntityPrototype
---@return table<string, true>? categories nil means "no restriction known"
local function ammo_categories_set(prototype)
   local ap = prototype.attack_parameters
   if not ap or not ap.ammo_categories then return nil end
   local set = {}
   for _, cat in ipairs(ap.ammo_categories) do
      set[cat] = true
   end
   return set
end

---@param prototype LuaEntityPrototype
---@return table<string, true>? categories
local function fuel_categories_set(prototype)
   local burner = prototype.burner_prototype
   if not burner then return nil end
   return burner.fuel_categories
end

---@class fa.GhostItemRequests.Slot
---@field kind "ammo"|"module"|"fuel"
---@field inventory defines.inventory
---@field size ItemStackIndex
---@field categories table<string, true>?
---@field kind_label LocalisedString
---@field filter_type string

---Work out which request "slots" (ammo/module/fuel) this ghost supports.
---@param entity LuaEntity
---@return fa.GhostItemRequests.Slot[]
local function get_request_slots(entity)
   local prototype = entity.ghost_prototype
   local quality = entity.quality.name
   local slots = {}
   -- Raw defines.inventory values already claimed by a confirmed-real slot this call -
   -- see [GHOST-REQUESTS-MODULE-ALIAS-FIX]. Checked in ammo -> module -> fuel order below,
   -- so a later category can never re-claim an index the earlier ones already found real.
   local used_indices = {}

   local ammo_inv, ammo_size = find_inventory(prototype, quality, AMMO_INVENTORIES, used_indices)
   if ammo_inv then
      used_indices[ammo_inv] = true
      table.insert(slots, {
         kind = "ammo",
         inventory = ammo_inv,
         size = ammo_size,
         categories = ammo_categories_set(prototype),
         kind_label = { "fa.ghost-requests-kind-ammo" },
         filter_type = ItemChooser.FILTER_TYPES.AMMO,
      })
   end

   local module_inv, module_size = find_inventory(prototype, quality, MODULE_INVENTORIES, used_indices)
   if module_inv then
      used_indices[module_inv] = true
      table.insert(slots, {
         kind = "module",
         inventory = module_inv,
         size = module_size,
         categories = prototype.allowed_module_categories,
         kind_label = { "fa.ghost-requests-kind-module" },
         filter_type = ItemChooser.FILTER_TYPES.MODULE,
      })
   end

   local fuel_inv, fuel_size = find_inventory(prototype, quality, FUEL_INVENTORIES, used_indices)
   -- Only offered when we actually know accepted fuel categories - without them we'd have to
   -- offer literally every fuel item in the game regardless of whether it could ever go in.
   local fuel_categories = fuel_inv and fuel_categories_set(prototype)
   if fuel_inv and fuel_categories then
      used_indices[fuel_inv] = true
      table.insert(slots, {
         kind = "fuel",
         inventory = fuel_inv,
         size = fuel_size,
         categories = fuel_categories,
         kind_label = { "fa.ghost-requests-kind-fuel" },
         filter_type = ItemChooser.FILTER_TYPES.FUEL,
      })
   end

   return slots
end

---@param entity LuaEntity
---@return boolean
function mod.is_available(entity)
   if not entity or not entity.valid or entity.type ~= "entity-ghost" then return false end
   return #get_request_slots(entity) > 0
end

---Find a stack index (0-based) in `inventory` not already used by an
---existing request on this ghost.
---@param entity LuaEntity
---@param inventory defines.inventory
---@param size ItemStackIndex
---@return ItemStackIndex?
local function find_free_stack(entity, inventory, size)
   local used = {}
   for _, entry in ipairs(entity.insert_plan or {}) do
      for _, pos in ipairs(entry.items.in_inventory or {}) do
         if pos.inventory == inventory then used[pos.stack] = true end
      end
   end
   for i = 0, size - 1 do
      if not used[i] then return i end
   end
   return nil
end

---Rebuild entity.insert_plan with one (inventory, stack) position removed -
---insert_plan always replaces the whole array, so this reads the current
---plan, drops just the matching position (and the whole entry if that was
---its only position), and writes the rest back.
---@param entity LuaEntity
---@param inventory defines.inventory
---@param stack ItemStackIndex
local function remove_request(entity, inventory, stack)
   local new_plan = {}
   for _, entry in ipairs(entity.insert_plan or {}) do
      local kept = {}
      for _, pos in ipairs(entry.items.in_inventory or {}) do
         if not (pos.inventory == inventory and pos.stack == stack) then table.insert(kept, pos) end
      end
      if #kept > 0 then table.insert(new_plan, { id = entry.id, items = { in_inventory = kept } }) end
   end
   entity.insert_plan = new_plan
end

---Append a new single-position request to entity.insert_plan.
---@param entity LuaEntity
---@param item_name string
---@param inventory defines.inventory
---@param stack ItemStackIndex
---@param count number
local function add_request(entity, item_name, inventory, stack, count)
   local new_plan = {}
   for _, entry in ipairs(entity.insert_plan or {}) do
      table.insert(new_plan, entry)
   end
   table.insert(new_plan, {
      id = { name = item_name, quality = "normal" },
      items = { in_inventory = { { inventory = inventory, stack = stack, count = count } } },
   })
   entity.insert_plan = new_plan
end

---Change the requested count at an existing (inventory, stack) position,
---keeping the same item id. Same rebuild-the-whole-array approach as
---remove_request/add_request, since insert_plan has no in-place update.
---@param entity LuaEntity
---@param inventory defines.inventory
---@param stack ItemStackIndex
---@param count number
local function set_request_count(entity, inventory, stack, count)
   local new_plan = {}
   for _, entry in ipairs(entity.insert_plan or {}) do
      local kept = {}
      for _, pos in ipairs(entry.items.in_inventory or {}) do
         if pos.inventory == inventory and pos.stack == stack then
            table.insert(kept, { inventory = pos.inventory, stack = pos.stack, count = count })
         else
            table.insert(kept, pos)
         end
      end
      if #kept > 0 then table.insert(new_plan, { id = entry.id, items = { in_inventory = kept } }) end
   end
   entity.insert_plan = new_plan
end

---@param kind "ammo"|"module"|"fuel"
---@param item_name string
---@return integer
local function default_request_count(kind, item_name)
   if kind == "module" then return 1 end
   local proto = prototypes.item[item_name]
   return (proto and proto.stack_size) or 1
end

---@param ctx fa.ui.graph.Ctx
---@return fa.ui.graph.Render?
local function render_ghost_item_requests(ctx)
   local entity = ctx.global_parameters and ctx.global_parameters.entity
   if not entity or not entity.valid then return nil end

   local slots = get_request_slots(entity)
   if #slots == 0 then return nil end

   local builder = Menu.MenuBuilder.new()

   for _, slot in ipairs(slots) do
      builder:add_label("kind-" .. slot.kind, slot.kind_label)

      local any = false
      for _, entry in ipairs(entity.insert_plan or {}) do
         for _, pos in ipairs(entry.items.in_inventory or {}) do
            if pos.inventory == slot.inventory then
               any = true
               local item_name, count, stack = entry.id.name, pos.count, pos.stack
               local key = string.format("req-%s-%d", slot.kind, stack)

               -- A module slot always holds exactly one module (each module has its own
               -- slot), so editing "count" there is meaningless - only ammo/fuel rows
               -- get the enter-to-edit-count behavior. See top-of-file comment.
               local editable_count = slot.kind ~= "module"

               builder:add_clickable(key, function(c)
                  c.message:fragment(Localising.get_localised_name_with_fallback(prototypes.item[item_name]))
                  if editable_count then
                     c.message:fragment({ "fa.ghost-requests-item-row", tostring(count) })
                  else
                     c.message:fragment({ "fa.ghost-requests-item-row-module" })
                  end
               end, {
                  on_click = editable_count and function(c)
                     local check = EntityAccess.can_write_to_entity(c.pindex, entity)
                     if not check.allowed then
                        UiSounds.play_ui_edge(c.pindex)
                        c.message:fragment(check.reason)
                        return
                     end
                     c.controller:open_textbox(tostring(count), {
                        node = key,
                        kind = slot.kind,
                        inventory = slot.inventory,
                        stack = stack,
                        item_name = item_name,
                     }, { "fa.ghost-requests-enter-count" })
                  end or nil,
                  on_child_result = editable_count and function(c, result)
                     local num = tonumber(result)
                     if not num or num < 1 or math.floor(num) ~= num then
                        UiSounds.play_ui_edge(c.pindex)
                        c.message:fragment({ "fa.invalid-number" })
                        return
                     end

                     local check = EntityAccess.can_write_to_entity(c.pindex, entity)
                     if not check.allowed then
                        UiSounds.play_ui_edge(c.pindex)
                        c.message:fragment(check.reason)
                        return
                     end

                     local item_proto = prototypes.item[item_name]
                     local max_count = (item_proto and item_proto.stack_size) or 1
                     local new_count = num
                     local clamped = false
                     if new_count > max_count then
                        new_count = max_count
                        clamped = true
                     end

                     set_request_count(entity, slot.inventory, stack, new_count)
                     if clamped then
                        c.message:fragment({ "fa.ghost-requests-count-clamped", tostring(max_count) })
                     else
                        c.message:fragment({ "fa.ghost-requests-count-updated", tostring(new_count) })
                     end
                     UiSounds.play_menu_click(c.pindex)
                  end or nil,
                  on_clear = function(c)
                     local check = EntityAccess.can_write_to_entity(c.pindex, entity)
                     if not check.allowed then
                        UiSounds.play_ui_edge(c.pindex)
                        c.message:fragment(check.reason)
                        return
                     end
                     remove_request(entity, slot.inventory, stack)
                     c.message:fragment({
                        "fa.ghost-requests-removed",
                        Localising.get_localised_name_with_fallback(prototypes.item[item_name]),
                     })
                     UiSounds.play_menu_click(c.pindex)
                  end,
               })
            end
         end
      end

      if not any then builder:add_label("none-" .. slot.kind, { "fa.ghost-requests-none-for-kind" }) end

      builder:add_clickable("add-" .. slot.kind, { "fa.ghost-requests-add" }, {
         on_click = function(c)
            local check = EntityAccess.can_write_to_entity(c.pindex, entity)
            if not check.allowed then
               UiSounds.play_ui_edge(c.pindex)
               c.message:fragment(check.reason)
               return
            end

            c.controller:open_child_ui(UiRouter.UI_NAMES.ITEM_CHOOSER, {
               filter_type = slot.filter_type,
               categories = slot.categories,
            }, {
               node = "add-" .. slot.kind,
               kind = slot.kind,
               inventory = slot.inventory,
               size = slot.size,
            })
         end,
         on_child_result = function(c, result)
            if not result or result == ItemChooser.NO_MODULE_RESULT then return end

            local check = EntityAccess.can_write_to_entity(c.pindex, entity)
            if not check.allowed then
               UiSounds.play_ui_edge(c.pindex)
               c.message:fragment(check.reason)
               return
            end

            local child_ctx = c.child_context
            local stack = find_free_stack(entity, child_ctx.inventory, child_ctx.size)
            if not stack then
               UiSounds.play_ui_edge(c.pindex)
               c.message:fragment({ "fa.ghost-requests-slot-full" })
               return
            end

            local count = default_request_count(child_ctx.kind, result)
            add_request(entity, result, child_ctx.inventory, stack, count)
            c.message:fragment({
               "fa.ghost-requests-added",
               Localising.get_localised_name_with_fallback(prototypes.item[result]),
               tostring(count),
            })
            UiSounds.play_menu_click(c.pindex)
         end,
      })
   end

   return builder:build()
end

mod.ghost_item_requests_tab = KeyGraph.declare_graph({
   name = "ghost_item_requests",
   title = { "fa.ghost-requests-title" },
   render_callback = render_ghost_item_requests,
})

return mod
