--[[
Fulgora lightning-protection coverage grid.

Full design write-up, including why this exists and why it's built this way
(grid instead of live circle math, how "land" is detected, why real/ruin
attractors are treated differently), is in changelog_dzsoker_claude.md under
"Fulgora lightning-attractor coverage grid". Read that first if you're trying
to understand *why*; this file is mostly the *how*.

Quick summary for orientation while reading the code below:

- Every lightning-attractor entity (lightning-rod, lightning-collector, and
  the decorative fulgoran-ruin-attractor scattered around the map) projects a
  circle of radius `prototype:get_attraction_range_elongation(quality)`. The
  union of all these circles, rasterized to whole tiles, is `covered`. This
  is the only thing K and the warnings menu read, and it's an O(1) table
  lookup for them - all the work happens once, here, on rebuild.
- Only lightning-rod and lightning-collector count as "real" attractors for
  grouping entities into islands and deciding whether to bother looking for
  gaps at all. Ruin attractors still contribute their circle to `covered`
  (they do protect), but are ignored for clustering/thresholds, or almost
  every scrap-strewn patch of the map would count as an "island" and spam
  gap warnings nobody asked for.
- Islands are found with one shared, multi-source flood fill over actual
  land tiles (not circle/attractor proximity), seeded from every real
  attractor's position, merging with union-find whenever two fills touch.
  Only islands with >= 2 real attractors get analyzed for gaps: a single
  circle is convex, so it can't have an interior hole, and a lone attractor
  giving a shore-side "you missed a spot" warning for every one of Fulgora's
  many ruin-only or single-collector scrap patches would be pure noise (this
  was explicitly cut for that reason - see the changelog section).
- Within a qualifying island, uncovered land tiles are grouped into
  connected components. A component with no non-land neighbor is fully
  enclosed by protection - an interior "hole" - and gets reported at its
  tile centroid, as close to "the middle of the hole" as a cheap centroid
  gets you. A component that does touch non-land is a shore-side gap, and
  gets reported with a compass direction relative to the island.

Call `mod.build_grid(surface)` once per full scanner refresh (the End key);
do not call it from a hot path. `mod.is_covered` and `mod.get_warning_entries`
are the read side and are both cheap.
]]

local FaUtils = require("scripts.fa-utils")

local mod = {}

-- Real, hard cap on how many land tiles the flood fill will visit in one
-- build_grid call, across all islands on the surface combined. This only
-- runs once per End press, not per tick, so a generous budget is fine - this
-- is purely a safety valve against an unexpectedly huge or maze-like
-- landmass, not a number we expect to actually hit on a normal Fulgora map.
local MAX_LAND_TILES_PER_BUILD = 150000

local NEIGHBOR_OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

---@alias fa.LightningZones.TileKey string -- "x,y", both floored to integers

---@param x number
---@param y number
---@return fa.LightningZones.TileKey
local function tile_key(x, y)
   return math.floor(x) .. "," .. math.floor(y)
end

---@param key fa.LightningZones.TileKey
---@return number, number
local function parse_tile_key(key)
   local sx, sy = key:match("^(-?%d+),(-?%d+)$")
   return tonumber(sx), tonumber(sy)
end

--------------------------------------------------------------------------------
-- Land detection
--------------------------------------------------------------------------------

---Is this tile part of real, standable landmass - as opposed to the void
---between Fulgora's scrap islands, or a body of (deep or shallow) oil ocean
---that the player can technically walk into but which isn't "land" for our
---purposes?
---
---We deliberately test the TILE PROTOTYPE's own collision mask
---(collision_mask.layers.water_tile) rather than asking "would the player
---entity collide here right now" (e.g. LuaTile.collides_with("player")).
---Those sound like the same question but aren't: the "player" layer also
---picks up whatever is currently built or growing on the tile, which is not
---what we want to know - a tile under a building or a rock is still land.
---Testing water_tile directly is a pure terrain question, independent of
---what's on top of it right now.
---
---This single check also happens to be exactly the "exclude oil ocean"
---filter dzsoker asked for, without hardcoding tile names: out-of-map,
---empty-space, oil-ocean-shallow and oil-ocean-deep all carry water_tile in
---their collision mask (confirmed via data-raw-dump.json), while every real
---fulgoran-* ground tile does not. Testing the property instead of the two
---names is more robust to a future game/mod update adding another walkable
---water-ish tile - it would be excluded automatically instead of silently
---slipping through.
---@param surface LuaSurface
---@param x number
---@param y number
---@return boolean
function mod.is_land(surface, x, y)
   local tile = surface.get_tile(x, y)
   if not tile or not tile.valid then return false end
   local mask = tile.prototype.collision_mask
   local layers = mask and mask.layers
   if layers and layers.water_tile then return false end
   return true
end

--------------------------------------------------------------------------------
-- Grid build (call this from the scanner's End-key refresh)
--------------------------------------------------------------------------------

---@param covered table<fa.LightningZones.TileKey, true>
---@param center MapPosition
---@param radius number
local function rasterize_circle(covered, center, radius)
   if radius <= 0 then return end
   local cx, cy = center.x, center.y
   local r2 = radius * radius
   local min_x, max_x = math.floor(cx - radius), math.ceil(cx + radius)
   local min_y, max_y = math.floor(cy - radius), math.ceil(cy + radius)
   for tx = min_x, max_x do
      for ty = min_y, max_y do
         -- Distance from the circle's center to the CLOSEST point of this
         -- tile's square (not the tile's own center or a corner), so a tile
         -- counts as covered exactly when the circle actually reaches into
         -- it anywhere - no under- or over-counting at the boundary.
         local dx = math.max(tx - cx, 0, cx - (tx + 1))
         local dy = math.max(ty - cy, 0, cy - (ty + 1))
         if dx * dx + dy * dy <= r2 then covered[tile_key(tx, ty)] = true end
      end
   end
end

---Multi-source flood fill over land tiles, seeded from every real
---attractor's position, merging seeds with union-find whenever two fills
---meet on the same tile. One shared pass gives us both the true island
---grouping (by real land connectivity, not attractor-distance guessing) and
---each island's land tile set, in one bounded walk.
---@param surface LuaSurface
---@param real_attractors LuaEntity[]
---@return table<fa.LightningZones.TileKey, integer> land_owner tile key -> owning component id (not necessarily the root - call find() to resolve)
---@return integer[] comp_parent union-find parent array, indexed by component id
local function flood_fill_islands(surface, real_attractors)
   local comp_parent = {}
   local land_owner = {}

   local function find(id)
      while comp_parent[id] ~= id do
         comp_parent[id] = comp_parent[comp_parent[id]]
         id = comp_parent[id]
      end
      return id
   end

   local function union(a, b)
      local ra, rb = find(a), find(b)
      if ra ~= rb then comp_parent[ra] = rb end
   end

   local queue = {}
   local qcount = 0

   for i, ent in ipairs(real_attractors) do
      comp_parent[i] = i
      local tx, ty = math.floor(ent.position.x), math.floor(ent.position.y)
      local tk = tile_key(tx, ty)
      local owner = land_owner[tk]
      if owner == nil then
         if mod.is_land(surface, tx, ty) then
            land_owner[tk] = i
            qcount = qcount + 1
            queue[qcount] = { x = tx, y = ty, comp = i }
         end
         -- If an attractor somehow isn't sitting on land (shouldn't happen -
         -- attractors are player-built on buildable ground), it just stays a
         -- component of its own that never grows any land or merges with
         -- anything. Harmless.
      else
         union(i, owner)
      end
   end

   local qhead = 1
   local visited = 0
   while qhead <= qcount and visited < MAX_LAND_TILES_PER_BUILD do
      local cur = queue[qhead]
      qhead = qhead + 1
      visited = visited + 1
      for _, d in ipairs(NEIGHBOR_OFFSETS) do
         local nx, ny = cur.x + d[1], cur.y + d[2]
         local ntk = tile_key(nx, ny)
         local owner = land_owner[ntk]
         if owner == nil then
            if mod.is_land(surface, nx, ny) then
               land_owner[ntk] = cur.comp
               qcount = qcount + 1
               queue[qcount] = { x = nx, y = ny, comp = cur.comp }
            end
         else
            union(cur.comp, owner)
         end
      end
   end

   return land_owner, comp_parent
end

---@param group fa.LightningZones.TileKey[]
---@return MapPosition
local function tile_group_centroid(group)
   local sum_x, sum_y = 0, 0
   for _, tk in ipairs(group) do
      local gx, gy = parse_tile_key(tk)
      sum_x = sum_x + gx
      sum_y = sum_y + gy
   end
   local n = #group
   -- +0.5 to land on the tile's center rather than its northwest corner.
   return { x = sum_x / n + 0.5, y = sum_y / n + 0.5 }
end

---Finds gaps in coverage within one island's land: interior holes (fully
---enclosed by covered land - impossible to see from outside the coverage
---area) and shore-side gaps (uncovered land that borders non-land, i.e. the
---player could walk up to the edge of protection without any warning ever
---firing from building damage, since there may be nothing built there yet).
---@param surface LuaSurface
---@param land_tiles table<fa.LightningZones.TileKey, true>
---@param covered table<fa.LightningZones.TileKey, true>
---@param island_centroid MapPosition
---@return fa.LightningZones.Hole[], fa.LightningZones.ShoreGap[]
local function find_gaps(surface, land_tiles, covered, island_centroid)
   local uncovered = {}
   for tk in pairs(land_tiles) do
      if not covered[tk] then uncovered[tk] = true end
   end

   local holes, shore_gaps = {}, {}
   local seen = {}

   for start_tk in pairs(uncovered) do
      if not seen[start_tk] then
         seen[start_tk] = true
         local group = { start_tk }
         local touches_non_land = false
         local qhead = 1

         while qhead <= #group do
            local cur_tk = group[qhead]
            qhead = qhead + 1
            local cx, cy = parse_tile_key(cur_tk)
            for _, d in ipairs(NEIGHBOR_OFFSETS) do
               local nx, ny = cx + d[1], cy + d[2]
               local ntk = tile_key(nx, ny)
               if uncovered[ntk] then
                  if not seen[ntk] then
                     seen[ntk] = true
                     table.insert(group, ntk)
                  end
               elseif not land_tiles[ntk] then
                  -- Not part of this island's known land. Almost always
                  -- means it's real non-land (void/ocean), but double check
                  -- against the actual tile in case the flood fill's tile
                  -- budget was hit before reaching this far - we don't want
                  -- a budget cutoff to be mistaken for a shoreline.
                  if not mod.is_land(surface, nx, ny) then touches_non_land = true end
               end
               -- else: neighbor is covered land - an interior boundary, not
               -- a reason to call this group a shore gap.
            end
         end

         if touches_non_land then
            local centroid = tile_group_centroid(group)
            table.insert(shore_gaps, {
               sample_pos = centroid,
               tile_count = #group,
               direction = FaUtils.get_direction_precise(centroid, island_centroid),
            })
         else
            table.insert(holes, {
               center = tile_group_centroid(group),
               tile_count = #group,
            })
         end
      end
   end

   return holes, shore_gaps
end

---@class fa.LightningZones.Hole
---@field center MapPosition
---@field tile_count integer

---@class fa.LightningZones.ShoreGap
---@field sample_pos MapPosition
---@field tile_count integer
---@field direction defines.direction

---@class fa.LightningZones.Island
---@field attractor_count integer
---@field holes fa.LightningZones.Hole[]
---@field shore_gaps fa.LightningZones.ShoreGap[]

---@class fa.LightningZones.Grid
---@field covered table<fa.LightningZones.TileKey, true>
---@field islands fa.LightningZones.Island[]

---Rebuilds the lightning-protection grid for a surface. Call this once per
---full scanner refresh (the End key) - it does a bounded but real flood
---fill and is not meant to run every tick or every K press. Everything that
---reads the grid afterwards (K, the warnings menu) is O(1).
---@param surface LuaSurface
function mod.build_grid(surface)
   storage.lightning_zones = storage.lightning_zones or {}

   local attractors = surface.find_entities_filtered({ type = "lightning-attractor" })
   if #attractors == 0 then
      -- No attractors at all on this surface - nothing to protect, nothing
      -- to warn about. Drop any stale grid so is_covered() correctly
      -- returns "unknown" instead of a leftover answer from before the last
      -- attractor here was removed.
      storage.lightning_zones[surface.index] = nil
      return
   end

   -- Coverage circles: every attractor counts, including decorative
   -- fulgoran-ruin-attractor entities - they do project a protection
   -- circle, and that's the only thing that matters for "is this spot
   -- covered", regardless of who or what placed the attractor.
   local covered = {}
   for _, ent in ipairs(attractors) do
      local radius = ent.prototype.get_attraction_range_elongation(ent.quality) or 0
      rasterize_circle(covered, ent.position, radius)
   end

   -- Island grouping and gap analysis: only lightning-rod and
   -- lightning-collector count. See the file header and the changelog for
   -- why ruin attractors are excluded here specifically.
   local real_attractors = {}
   for _, ent in ipairs(attractors) do
      if ent.name == "lightning-rod" or ent.name == "lightning-collector" then
         table.insert(real_attractors, ent)
      end
   end

   local islands = {}

   if #real_attractors > 0 then
      local land_owner, comp_parent = flood_fill_islands(surface, real_attractors)

      local function find(id)
         while comp_parent[id] ~= id do
            comp_parent[id] = comp_parent[comp_parent[id]]
            id = comp_parent[id]
         end
         return id
      end

      local land_by_component = {}
      for tk, owner in pairs(land_owner) do
         local root = find(owner)
         land_by_component[root] = land_by_component[root] or {}
         land_by_component[root][tk] = true
      end

      local attractors_by_component = {}
      for i, ent in ipairs(real_attractors) do
         local root = find(i)
         attractors_by_component[root] = attractors_by_component[root] or {}
         table.insert(attractors_by_component[root], ent)
      end

      for root, comp_attractors in pairs(attractors_by_component) do
         -- A single circle is convex, so it can never have an interior
         -- hole, and (per dzsoker's call) a lone attractor's shore gap
         -- isn't worth reporting either - Fulgora islands are thick with
         -- single ruin/collector scrap patches nobody is trying to protect,
         -- and warning about every one of them would be pure noise. Only
         -- islands with 2+ real, player-relevant attractors get analyzed.
         if #comp_attractors >= 2 then
            local land_tiles = land_by_component[root] or {}

            local sum_x, sum_y = 0, 0
            for _, ent in ipairs(comp_attractors) do
               sum_x = sum_x + ent.position.x
               sum_y = sum_y + ent.position.y
            end
            local island_centroid = { x = sum_x / #comp_attractors, y = sum_y / #comp_attractors }

            local holes, shore_gaps = find_gaps(surface, land_tiles, covered, island_centroid)

            table.insert(islands, {
               attractor_count = #comp_attractors,
               holes = holes,
               shore_gaps = shore_gaps,
            })
         end
      end
   end

   ---@type fa.LightningZones.Grid
   storage.lightning_zones[surface.index] = { covered = covered, islands = islands }
end

--------------------------------------------------------------------------------
-- Read side (cheap - O(1) table lookups against the last build_grid result)
--------------------------------------------------------------------------------

---Is this position inside some attractor's protection circle, per the grid
---built at the last End refresh?
---
---Returns nil (not true/false) when this surface has no cached grid at all
---(no lightning-attractor entities exist here, or End hasn't been pressed
---since the first one was placed) - callers should treat nil as "don't say
---anything", not as "unprotected", since lightning protection isn't even a
---concept on a surface with no attractors.
---@param surface LuaSurface
---@param position MapPosition
---@return boolean?
function mod.is_covered(surface, position)
   local grid = storage.lightning_zones and storage.lightning_zones[surface.index]
   if not grid then return nil end
   return grid.covered[tile_key(position.x, position.y)] == true
end

---Flat list of every hole and shore gap known for this surface, each shaped
---as { position = MapPosition, label = LocalisedString }, ready to become a
---synthetic warnings-menu entry. Returns two empty tables (not nil) when
---there's a grid but nothing wrong; returns nil, nil when there's no grid at
---all for this surface.
---@param surface LuaSurface
---@return {position: MapPosition, label: LocalisedString}[]?, {position: MapPosition, label: LocalisedString}[]?
function mod.get_warning_entries(surface)
   local grid = storage.lightning_zones and storage.lightning_zones[surface.index]
   if not grid then return nil, nil end

   local holes, shore_gaps = {}, {}
   for _, island in ipairs(grid.islands) do
      for _, hole in ipairs(island.holes) do
         table.insert(holes, { position = hole.center, label = { "fa.lightning-hole-label" } })
      end
      for _, gap in ipairs(island.shore_gaps) do
         table.insert(shore_gaps, {
            position = gap.sample_pos,
            label = { "fa.lightning-shore-gap-label", FaUtils.direction_lookup(gap.direction) },
         })
      end
   end
   return holes, shore_gaps
end

return mod
