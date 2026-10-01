--[[
[GLEBA-SOIL] Scanner backend for Gleba's crop soil tiles (yumako and jellynut).

These are ordinary walkable land tiles, not entities, so - like water and
icebergs - they need their own tile-based backend rather than the entity-based
BACKEND_LUT/BACKEND_NAME_OVERRIDES dispatch in surface-scanner.lua. This file
closely mirrors backends/iceberg.lua (a single TileClusterer walking newly
scanned chunks and grouping same-category tiles by proximity), except it runs
TWO independent clusterers - one for yumako soil, one for jellynut soil - so
that a yumako patch and a jellynut patch sitting right next to each other on
the same farm are still announced as two separate scanner entries, per
explicit request ("külön bejegyzést... a zselére és a jumákóra").

Both crops' soil is placed under the TERRAIN category (the same category
cliffs and icebergs use), since it is exactly that: a kind of terrain, not a
buildable/produced thing.
]]
local SC = require("scripts.scanner.scanner-consts")
local TileClusterer = require("ds.tile-clusterer")

local mod = {}

---@class fa.scanner.backends.GlebaSoilBackendData
---@field aabb fa.AABB

---@class fa.scanner.GlebaSoilBackend: fa.scanner.ScannerBackend
---@field surface LuaSurface
---@field yumako_clusterer fa.ds.TileClusterer
---@field jellynut_clusterer fa.ds.TileClusterer
local GlebaSoilBackend = {}
local GlebaSoilBackend_meta = { __index = GlebaSoilBackend }
mod.GlebaSoilBackend = GlebaSoilBackend
if script then script.register_metatable("fa.scanner.GlebaSoilBackend", GlebaSoilBackend_meta) end

---@param surface LuaSurface
function GlebaSoilBackend.new(surface)
   return setmetatable({
      surface = surface,
      yumako_clusterer = TileClusterer.TileClusterer.new({ track_interior = true }),
      jellynut_clusterer = TileClusterer.TileClusterer.new({ track_interior = true }),
      entry_cache = {},
   }, GlebaSoilBackend_meta)
end

---@param e LuaEntity
function GlebaSoilBackend:on_new_entity(e) end

---@param player LuaPlayer
---@param e fa.scanner.ScanEntry
function GlebaSoilBackend:validate_entry(player, e)
   if player.surface.index ~= self.surface.index then return false end

   -- Soil can be tilled over / revert to plain Gleba ground, so re-check like
   -- water/iceberg do for landfill.
   local protos = e.backend_data.crop == "yumako" and SC.YUMAKO_SOIL_PROTOS or SC.JELLYNUT_SOIL_PROTOS
   return player.surface.count_tiles_filtered({
      area = e.backend_data.aabb,
      name = protos,
      limit = 1,
   }) > 0
end

function GlebaSoilBackend:update_entry(player, e) end

function GlebaSoilBackend:readout_entry(player, e)
   local bb = e.backend_data.aabb
   local w = bb.right_bottom.x - bb.left_top.x
   local h = bb.right_bottom.y - bb.left_top.y
   if e.backend_data.crop == "yumako" then
      return { "fa.scanner-yumako-soil", w, h }
   else
      return { "fa.scanner-jellynut-soil", w, h }
   end
end

---@param player LuaPlayer
---@param callback fun(fa.scanner.ScanEntry)
---@param clusterer fa.ds.TileClusterer
---@param crop string
function GlebaSoilBackend:dump_clusterer_to_callback(player, callback, clusterer, crop)
   ---@param group fa.ds.TileClusterer.Group
   clusterer:get_groups(function(group)
      local tlx = math.huge
      local tly = math.huge
      local brx = -math.huge
      local bry = -math.huge

      local closest_dist = math.huge
      local e_x, e_y
      local px, py = player.position.x, player.position.y

      for x, children in pairs(group.edge_tiles) do
         tlx = tlx < x and tlx or x
         brx = brx > x and brx or x

         for y in pairs(children) do
            tly = tly < y and tly or y
            bry = bry > y and bry or y

            local dist = (px - x) ^ 2 + (py - y) ^ 2
            if dist < closest_dist then
               closest_dist = dist
               e_x = x
               e_y = y
            end
         end
      end

      -- Top-left corner of the bottom-right tile -> bottom right corner.
      brx = brx + 1
      bry = bry + 1

      callback({
         -- Offset to tile center; see iceberg.lua/water.lua for why (avoids a
         -- cursor-handling off-by-one-tile quirk on the raw tile corner).
         position = { x = e_x + 0.5, y = e_y + 0.5 },
         backend_data = {
            aabb = {
               left_top = { x = tlx, y = tly },
               right_bottom = { x = brx, y = bry },
            },
            crop = crop,
         },
         backend = self,
         category = SC.CATEGORIES.TERRAIN,
         subcategory = crop .. "-soil",
      })
   end)
end

---@param player LuaPlayer
---@param callback fun(fa.scanner.ScanEntry)
function GlebaSoilBackend:dump_entries_to_callback(player, callback)
   self:dump_clusterer_to_callback(player, callback, self.yumako_clusterer, "yumako")
   self:dump_clusterer_to_callback(player, callback, self.jellynut_clusterer, "jellynut")
end

---@param chunk ChunkPositionAndArea
function GlebaSoilBackend:on_new_chunk(chunk)
   local yumako_tiles = self.surface.find_tiles_filtered({
      area = chunk.area,
      name = SC.YUMAKO_SOIL_PROTOS,
   })
   local yumako_xy = {}
   for i = 1, #yumako_tiles do
      table.insert(yumako_xy, yumako_tiles[i].position)
   end
   self.yumako_clusterer:submit_points(yumako_xy)

   local jellynut_tiles = self.surface.find_tiles_filtered({
      area = chunk.area,
      name = SC.JELLYNUT_SOIL_PROTOS,
   })
   local jellynut_xy = {}
   for i = 1, #jellynut_tiles do
      table.insert(jellynut_xy, jellynut_tiles[i].position)
   end
   self.jellynut_clusterer:submit_points(jellynut_xy)
end

function GlebaSoilBackend:get_aabb(e)
   local aabb = e.backend_data.aabb
   local lt = aabb.left_top
   local rb = aabb.right_bottom
   return lt.x, lt.y, rb.x, rb.y
end

function GlebaSoilBackend:is_huge(e)
   return true
end

return mod
