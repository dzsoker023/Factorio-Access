local SC = require("scripts.scanner.scanner-consts")

local mod = {}

-- Same fixed value as surface-scanner.lua's own local CHUNK_SIZE - not imported from
-- there since that module doesn't export it, and it's a Factorio engine constant (chunks
-- are always 32x32 tiles), not something either file owns.
local CHUNK_SIZE = 32

---Live point-query, independent of anything the scanner has "discovered" via its chunk
---walk: is THIS specific position part of a territory right now, and if so is it
---currently guarded or abandoned? Unlike the scanner backend above (which only knows
---about territories under chunks it has already scanned), this calls the engine directly
---every time, so it works instantly anywhere, already-scanned or not - meant for a quick
---"am I standing in one right now" check (e.g. from the coordinate-readout key), not for
---listing/browsing.
---@param surface LuaSurface
---@param position MapPosition
---@return "active"|"abandoned"|nil status nil if the position isn't part of any territory at all
function mod.get_status_at(surface, position)
   local chunk_pos = { x = math.floor(position.x / CHUNK_SIZE), y = math.floor(position.y / CHUNK_SIZE) }
   local territory = surface.get_territory_for_chunk(chunk_pos)
   if not territory then return nil end

   local units = territory.get_segmented_units()
   for i = 1, #units do
      if units[i].valid then return "active" end
   end

   return "abandoned"
end

--[[
Vulcanus demolisher "territory" backend.

Per the maintainer's explicit request: this is NOT about whether a specific demolisher
entity is currently visible/alert - it's about being able to ask, for any spot the scanner
has walked past, "is this an active (guarded) territory, or a dead/abandoned one now that
its demolisher is gone". A LuaTerritory persists as a place even after all the
LuaSegmentedUnits guarding it have died (confirmed via the official API:
LuaTerritory:get_segmented_units() can legitimately return an empty array while the
territory itself is still .valid - see LuaTerritory:regenerate_segmented_units(), which
only makes sense if a territory can outlive its guards), so live/dead is NOT something we
can cache at scan time - it must be recomputed every time the entry is read out.

Discovery works by piggybacking on the existing per-chunk scan walk (on_new_chunk, called
exactly once per chunk ever - see surface-scanner.lua's seen_chunks dedup), same as
IcebergBackend/WaterBackend. A territory can span many chunks, so the first chunk that
finds it immediately claims every chunk it owns (via LuaTerritory:get_chunks()) to avoid
registering the same territory again from one of its other chunks later in the walk.
]]

---@class fa.scanner.backends.TerritoryBackendData
---@field territory LuaTerritory
---@field aabb fa.AABB

---@class fa.scanner.TerritoryBackend: fa.scanner.ScannerBackend
---@field surface LuaSurface
---@field known table<string, fa.scanner.backends.TerritoryBackendData>
---@field claimed_chunks table<number, table<number, true>>
local TerritoryBackend = {}
mod.TerritoryBackend = TerritoryBackend
local TerritoryBackend_meta = { __index = TerritoryBackend }
if script then script.register_metatable("fa.scanner.TerritoryBackend", TerritoryBackend_meta) end

---@param surface LuaSurface
function TerritoryBackend.new(surface)
   return setmetatable({
      surface = surface,
      known = {},
      claimed_chunks = {},
   }, TerritoryBackend_meta)
end

---@param e LuaEntity
function TerritoryBackend:on_new_entity(e) end

---@param cx number
---@param cy number
function TerritoryBackend:is_chunk_claimed(cx, cy)
   local row = self.claimed_chunks[cx]
   return row ~= nil and row[cy] == true
end

---@param cx number
---@param cy number
function TerritoryBackend:claim_chunk(cx, cy)
   local row = self.claimed_chunks[cx]
   if not row then
      row = {}
      self.claimed_chunks[cx] = row
   end
   row[cy] = true
end

---@param chunk ChunkPositionAndArea
function TerritoryBackend:on_new_chunk(chunk)
   local cx, cy = chunk.x, chunk.y
   if self:is_chunk_claimed(cx, cy) then return end

   local territory = self.surface.get_territory_for_chunk({ x = cx, y = cy })
   if not territory then return end

   -- Claim every chunk this territory owns right away, and compute its bounding box in
   -- the same pass, so the other chunks it spans don't create a duplicate entry later.
   local min_cx, min_cy = math.huge, math.huge
   local tlx, tly, brx, bry = math.huge, math.huge, -math.huge, -math.huge
   local chunks = territory.get_chunks()
   for i = 1, #chunks do
      local c = chunks[i]
      self:claim_chunk(c.x, c.y)

      if c.x < min_cx or (c.x == min_cx and c.y < min_cy) then
         min_cx, min_cy = c.x, c.y
      end

      local a = c.area
      tlx = math.min(tlx, a.left_top.x)
      tly = math.min(tly, a.left_top.y)
      brx = math.max(brx, a.right_bottom.x)
      bry = math.max(bry, a.right_bottom.y)
   end

   -- Nothing to key on (LuaTerritory has no id/unit_number) - the lowest chunk coordinate
   -- it owns is stable for as long as the territory exists, which is all we need.
   local key = string.format("%d,%d", min_cx, min_cy)
   if self.known[key] then return end

   self.known[key] = {
      territory = territory,
      aabb = {
         left_top = { x = tlx, y = tly },
         right_bottom = { x = brx, y = bry },
      },
   }
end

---@param player LuaPlayer
---@param e fa.scanner.ScanEntry
function TerritoryBackend:validate_entry(player, e)
   if player.surface.index ~= self.surface.index then return false end
   -- Only drop the entry if the territory itself is gone (destroy()'d/migrated away) -
   -- NOT based on whether it currently has live guards. "Dead but still a territory" is a
   -- real, meaningful state we want to keep reporting, not hide.
   return e.backend_data.territory.valid
end

function TerritoryBackend:update_entry(player, e) end

---@param player LuaPlayer
---@param e fa.scanner.ScanEntry
function TerritoryBackend:readout_entry(player, e)
   local territory = e.backend_data.territory
   local units = territory.get_segmented_units()

   local live_count = 0
   for i = 1, #units do
      if units[i].valid then live_count = live_count + 1 end
   end

   if live_count > 0 then
      return { "fa.scanner-territory-active", live_count }
   else
      return { "fa.scanner-territory-abandoned" }
   end
end

---@param player LuaPlayer
---@param callback fun(fa.scanner.ScanEntry)
function TerritoryBackend:dump_entries_to_callback(player, callback)
   for _, data in pairs(self.known) do
      if data.territory.valid then
         local aabb = data.aabb
         local cx = (aabb.left_top.x + aabb.right_bottom.x) / 2
         local cy = (aabb.left_top.y + aabb.right_bottom.y) / 2

         callback({
            position = { x = cx, y = cy },
            backend_data = data,
            backend = self,
            category = SC.CATEGORIES.ENEMIES,
            subcategory = "territory",
         })
      end
   end
end

function TerritoryBackend:get_aabb(e)
   local aabb = e.backend_data.aabb
   local lt = aabb.left_top
   local rb = aabb.right_bottom
   return lt.x, lt.y, rb.x, rb.y
end

function TerritoryBackend:is_huge(e)
   return true
end

return mod
