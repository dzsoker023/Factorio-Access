local Functools = require("scripts.functools")
local Memosort = require("scripts.memosort")
local ResourcePatchesBackend = require("scripts.scanner.backends.resource-patches")
local SimpleBackend = require("scripts.scanner.backends.simple")
local ScannerConsts = require("scripts.scanner.scanner-consts")
local StorageManager = require("scripts.storage-manager")
-- This is typed around 100 times and only used for the LUT, so we will shorten
-- it.
local SparseBitset = require("ds.sparse-bitset")
local SEB = require("scripts.scanner.backends.single-entity")
local GlebaSoilBackend = require("scripts.scanner.backends.gleba-soil")
local IcebergBackend = require("scripts.scanner.backends.iceberg")
local TerritoryBackend = require("scripts.scanner.backends.territory")
local TreeBackend = require("scripts.scanner.backends.trees")
local WaterBackend = require("scripts.scanner.backends.water")
local TH = require("scripts.table-helpers")
local WorkQueue = require("scripts.work-queue")

local mod = {}

local CHUNK_SIZE = 32

-- Entity types that legitimately belong to the "enemy" force but are just component
-- parts of a larger creature, not enemies worth listing on their own - so the
-- unknown-enemy safety net (below) should ignore them rather than list dozens of
-- meaningless individual entries. Confirmed via live testing: a Gleba pentapod
-- strafer/stomper's individual legs (reusing the same "spider-leg" entity type as
-- spider-vehicle/spidertron legs, per FFF-425 "Pentapods reuse the code that drives
-- Spidertron legs") were showing up as 25 separate "unregistered enemy" entries - these
-- are leg-parts of the (already correctly registered) "spider-unit" body, not individual
-- enemies.
local IGNORED_ENEMY_COMPONENT_TYPES = {
   ["spider-leg"] = true,
   -- Vulcanus demolisher breath/roar attack leaves a lingering "expanding ash cloud"
   -- ground effect (per FFF-429). Best-available research identifies its prototype type
   -- as "smoke-with-trigger" (Factorio's standard type for a timed, animated,
   -- trigger-running cloud effect like this) - this is an educated guess, not a
   -- confirmed exact type string, since the source data file was too large to fetch
   -- directly. Low risk either way: SmokeWithTriggerPrototype inherits plain
   -- EntityPrototype, not EntityWithHealthPrototype/EntityWithOwnerPrototype, so nothing
   -- of this type is ever shootable or a real target - excluding it here can only
   -- silence noise, never hide an actual threat. If this guess is wrong, the
   -- self-diagnosing unknown-enemy safety net below will still speak whatever the real
   -- type turns out to be next time a demolisher breathes near the player, the same way
   -- it originally caught "spider-leg" above.
   ["smoke-with-trigger"] = true,
}

--[[
List all prototypes the scanner should care about. Any prototype not in this
table will not be processed by the scanner.

We keep these in alphabetical order. To do so in a blind friendly manner, wrap
all keys in `[""]` even if they don't contain -, then select the contents of
this table and ask VSCode to "sort lines ascending".  That's important: it lets
us see if a prototype is listed yet.

Rocks are a special case; the next table is where you can drop name overrides
for things like that.
]]
---@type table<string, fa.scanner.ScannerBackend>
local BACKEND_LUT = {
   ["accumulator"] = SEB.LogisticsAndPower,
   ["ammo-turret"] = SEB.Military,
   ["arithmetic-combinator"] = SEB.LogisticsAndPower,
   ["artillery-flare"] = SEB.Military,
   ["artillery-turret"] = SEB.Military,
   ["artillery-wagon"] = SEB.TrainsNamed,
   ["assembling-machine"] = SEB.CraftingMachine,
   ["beacon"] = SEB.Production,
   ["boiler"] = SEB.LogisticsAndPower,
   ["burner-generator"] = SEB.LogisticsAndPower,
   ["car"] = SEB.Vehicle,
   ["cargo-wagon"] = SEB.TrainsNamed,
   ["character-corpse"] = SEB.Other,
   ["character"] = SEB.Character,
   ["cliff"] = SEB.Terrain,
   ["combat-robot"] = SEB.Military,
   ["constant-combinator"] = SEB.LogisticsAndPower,
   ["construction-robot"] = SEB.LogisticsAndPower,
   ["container"] = SEB.Containers,
   ["corpse"] = SEB.Corpses,
   ["curved-rail-a"] = SEB.TrainsSimple,
   ["curved-rail-b"] = SEB.TrainsSimple,
   ["decider-combinator"] = SEB.LogisticsAndPower,
   ["electric-energy-interface"] = SEB.LogisticsAndPower,
   ["electric-pole"] = SEB.LogisticsAndPower,
   ["electric-turret"] = SEB.Military,
   ["elevated-curved-rail-a"] = SEB.TrainsSimple,
   ["elevated-curved-rail-b"] = SEB.TrainsSimple,
   ["elevated-half-diagonal-rail"] = SEB.TrainsSimple,
   ["elevated-straight-rail"] = SEB.TrainsSimple,
   ["entity-ghost"] = SEB.Ghosts,
   ["fire"] = SEB.Other,
   ["fish"] = SEB.Other,
   ["flame-thrower-explosion"] = SEB.Other,
   ["fluid-turret"] = SEB.Military,
   ["fluid-wagon"] = SEB.TrainsNamed,
   ["furnace"] = SEB.Furnace,
   ["gate"] = SEB.Military,
   ["generator"] = SEB.LogisticsAndPower,
   ["half-diagonal-rail"] = SEB.TrainsSimple,
   ["heat-interface"] = SEB.LogisticsAndPower,
   ["heat-pipe"] = SEB.LogisticsAndPower,
   ["infinity-container"] = SEB.Containers,
   ["infinity-pipe"] = SEB.LogisticsWithFluid,
   ["inserter"] = SEB.LogisticsAndPower,
   ["item-entity"] = SEB.Other,
   ["lab"] = SEB.Production,
   ["lamp"] = SEB.LogisticsAndPower,
   ["legacy-curved-rail"] = SEB.TrainsSimple,
   ["legacy-straight-rail"] = SEB.TrainsSimple,
   ["land-mine"] = SEB.Military,
   ["linked-belt"] = SEB.LogisticsAndPower,
   ["linked-container"] = SEB.LogisticsAndPower,
   ["loader-1x1"] = SEB.LogisticsAndPower,
   ["loader"] = SEB.LogisticsAndPower,
   ["locomotive"] = SEB.TrainsNamed,
   ["logistic-container"] = SEB.Containers,
   ["logistic-robot"] = SEB.LogisticsAndPower,
   ["market"] = SEB.LogisticsAndPower,
   ["mining-drill"] = SEB.MiningDrill,
   ["offshore-pump"] = SEB.Production,
   ["pipe-to-ground"] = SEB.LogisticsWithFluid,
   ["pipe"] = SEB.Pipe,
   ["player-port"] = SEB.Other,
   ["power-switch"] = SEB.LogisticsAndPower,
   ["programmable-speaker"] = SEB.LogisticsAndPower,
   ["projectile"] = SEB.Other,
   ["pump"] = SEB.LogisticsAndPower,
   ["radar"] = SEB.Military,
   ["rail-chain-signal"] = SEB.TrainsSimple,
   ["rail-ramp"] = SEB.TrainsSimple,
   ["rail-remmnants"] = SEB.Remnants,
   ["rail-signal"] = SEB.TrainsSimple,
   ["rail-support"] = SEB.TrainsSimple,
   ["reactor"] = SEB.LogisticsAndPower,
   ["resource"] = ResourcePatchesBackend.ResourcePatchesBackend,
   ["roboport"] = SEB.Roboport,
   ["rocket-silo-rocket-shadow"] = SEB.Other,
   ["rocket-silo-rocket"] = SEB.Other,
   ["rocket-silo"] = SEB.Production,
   -- Space Age (Vulcanus) demolishers. These are NOT a plain "unit" - they use the
   -- separate "segmented-unit"/"segment" prototype family (one segmented-unit "head"
   -- entity plus many individual "segment" body-part entities, all sharing one health
   -- pool via LuaSegmentedUnit). Both types are routed to SEB.Demolisher, which groups
   -- every segment of the SAME demolisher into one subcategory (like SEB.TrainsNamed
   -- does for a train's carriages) - so a demolisher shows up as one scanner entry with
   -- shift+pgup/pgdown cycling through its head/body segments, not dozens of unrelated
   -- entries.
   ["segment"] = SEB.Demolisher,
   ["segmented-unit"] = SEB.Demolisher,
   ["simple-entity-with-force"] = SEB.Other,
   ["simple-entity-with-owner"] = SEB.Other,
   ["simple-entity"] = SEB.Other,
   ["solar-panel"] = SEB.LogisticsAndPower,
   -- Space Age (Gleba) pentapod strafers/stompers. Confirmed via Factorio bug-tracker
   -- reports (e.g. forums.factorio.com viewtopic t=123538, and the spider-unit tint bug
   -- naming stompers/strafers explicitly) that these reuse the SAME leg-animation engine
   -- as spider-vehicle (per FFF-424: "leggy tech from spidertrons"), and are their own
   -- "spider-unit" prototype type - NOT a plain "unit" like biters/wrigglers, and also not
   -- multi-entity like a demolisher (one spider-unit is one single entity, so it just
   -- needs a normal single-entry backend like SEB.Unit, not the Demolisher grouping).
   ["spider-unit"] = SEB.Unit,
   ["spider-vehicle"] = SEB.Spidertron,
   ["splitter"] = SEB.LogisticsAndPower,
   ["storage-tank"] = SEB.LogisticsWithFluid,
   ["straight-rail"] = SEB.TrainsSimple,
   ["tile-ghost"] = SEB.Ghosts,
   ["train-stop"] = SEB.TrainsSimple,
   ["transport-belt"] = SEB.LogisticsAndPower,
   ["tree"] = TreeBackend.TreeBackend,
   ["turret"] = SEB.Unit,
   ["underground-belt"] = SEB.LogisticsAndPower,
   ["unit-spawner"] = SEB.Spawner,
   ["unit"] = SEB.Unit,
   ["wall"] = SEB.Military,
}

---@type fun(): table<string, fa.scanner.ScannerBackend>
local BACKEND_NAME_OVERRIDES = Functools.cached(function()
   local bno = {}

   -- All our kinds of rocks.
   TH.merge_mappings(bno, {
      ["big-rock"] = SEB.Rock,
      ["big-sand-rock"] = SEB.Rock,
      ["huge-rock"] = SEB.Rock,
      ["medium-rock"] = SEB.Rock,
      ["medium-sand-rock"] = SEB.Rock,
      ["small-rock"] = SEB.Rock,
      ["small-sand-rock"] = SEB.Rock,
      ["tiny-rock"] = SEB.Rock,
   })

   -- Space Age: the same treatment as Nauvis rocks above, extended to every other
   -- planet's minable decorative entities that yield a real crafting material (verified
   -- against wube/factorio-data's space-age/prototypes/decorative/decoratives-*.lua
   -- source files - only entities with an actual `minable` block are listed; the many
   -- purely-cosmetic optimized-decorative entries on each planet have no `minable` field
   -- and are correctly left out).
   TH.merge_mappings(bno, {
      -- Vulcanus: stone/iron/copper/tungsten-ore rocks, plus volcanic-vent "chimney"
      -- decoratives which are mechanically identical to rocks in the data
      -- (count_as_rock_for_filtered_deconstruction = true) and yield stone + sulfur.
      ["big-volcanic-rock"] = SEB.Rock,
      ["big-volcanic-rock-hot"] = SEB.Rock,
      ["huge-volcanic-rock"] = SEB.Rock,
      ["huge-volcanic-rock-hot"] = SEB.Rock,
      ["vulcanus-chimney"] = SEB.Rock,
      ["vulcanus-chimney-cold"] = SEB.Rock,
      ["vulcanus-chimney-faded"] = SEB.Rock,
      ["vulcanus-chimney-short"] = SEB.Rock,
      ["vulcanus-chimney-truncated"] = SEB.Rock,

      -- Fulgora: ruins (scrap + steel-plate + iron-gear-wheel + iron-stick +
      -- copper-cable + stone) and fulgurite (stone + holmium-ore).
      ["fulgora-sunk-ruin-big"] = SEB.Rock,
      ["fulgora-sunk-ruin-medium-tall"] = SEB.Rock,
      ["fulgoran-ruin-attractor"] = SEB.Rock,
      ["fulgoran-ruin-big"] = SEB.Rock,
      ["fulgoran-ruin-colossal"] = SEB.Rock,
      ["fulgoran-ruin-huge"] = SEB.Rock,
      ["fulgoran-ruin-medium"] = SEB.Rock,
      ["fulgoran-ruin-small"] = SEB.Rock,
      ["fulgoran-ruin-stonehenge"] = SEB.Rock,
      ["fulgoran-ruin-vault"] = SEB.Rock,
      ["fulgurite"] = SEB.Rock,
      ["fulgurite-small"] = SEB.Rock,

      -- Gleba: stromatolites (stone + iron-ore + iron-bacteria / stone + copper-ore +
      -- copper-bacteria). The only two minable non-tree decoratives on this planet.
      ["copper-stromatolite"] = SEB.Rock,
      ["iron-stromatolite"] = SEB.Rock,

      -- [GLEBA-SOIL] Gleba's yumako and jellynut plants. These are prototype
      -- *type* "plant" (confirmed via data-raw-dump.json), a type that has no
      -- entry anywhere in BACKEND_LUT above (unlike "resource", "tree", etc.)
      -- and is not on the "enemy" force, so before this they were silently
      -- dropped by the scanner entirely - not even caught by the
      -- unknown-enemy safety net. Routed to SEB.Rock (RESOURCES category,
      -- one entry per prototype name) as the closest existing precedent: the
      -- same backend already used above for every other planet's minable,
      -- harvest-by-mining-action decorative (Vulcanus volcanic rocks, Fulgora
      -- ruins, the Gleba stromatolites just above, Aquilo lithium icebergs).
      ["yumako-tree"] = SEB.Rock,
      ["jellystem"] = SEB.Rock,

      -- Aquilo: lithium icebergs (ice-platform + ice + lithium). The only minable
      -- decoratives on this planet.
      ["lithium-iceberg-big"] = SEB.Rock,
      ["lithium-iceberg-huge"] = SEB.Rock,
   })

   -- remnants
   for proto in pairs(prototypes.entity) do
      if proto:match("-remnants$") then bno[proto] = SEB.Remnants end
   end

   return bno
end)
---@class fa.scanner.SurfaceBackends
---@field lut table<string, fa.scanner.ScannerBackend>
---@field name_lut table<string, fa.scanner.ScannerBackend>
---@field iceberg_backend fa.scanner.IcebergBackend
---@field water_backend fa.scanner.WaterBackend
---@field gleba_soil_backend fa.scanner.GlebaSoilBackend
---@field territory_backend fa.scanner.TerritoryBackend
---@field unknown_enemy_backend fa.scanner.ScannerBackend

-- Instantiate a set of backends, later wired up to a surface, by iterating over
-- the LUT and making backends for each thing.
---@param surface LuaSurface
---@return fa.scanner.SurfaceBackends
local function instantiate_backends(surface)
   local instantiated = {}
   local lut = {}
   local name_lut = {}

   for proto, backend in pairs(BACKEND_LUT) do
      local b = instantiated[backend] or backend.new(surface)
      instantiated[backend] = b
      lut[proto] = b
   end

   for name, backend in pairs(BACKEND_NAME_OVERRIDES()) do
      local b = instantiated[backend] or backend.new(surface)
      instantiated[backend] = b
      name_lut[name] = b
   end

   return {
      lut = lut,
      name_lut = name_lut,
      iceberg_backend = IcebergBackend.IcebergBackend.new(surface),
      water_backend = WaterBackend.WaterBackend.new(surface),
      gleba_soil_backend = GlebaSoilBackend.GlebaSoilBackend.new(surface),
      territory_backend = TerritoryBackend.TerritoryBackend.new(surface),
      -- Safety net: an entity whose type is not in BACKEND_LUT is normally just silently
      -- dropped (this is exactly how Vulcanus demolishers and Gleba pentapods went
      -- unnoticed for a while - a type gap here is otherwise invisible until someone
      -- happens to report "I don't see X"). For entities on the "enemy" force
      -- specifically, route them here instead of dropping them, so an unrecognized enemy
      -- type still shows up (under Enemies, labelled "unregistered") with its raw
      -- prototype type/name spoken aloud - which is exactly the ground truth needed to
      -- add proper support for it, instead of guessing from documentation.
      unknown_enemy_backend = SEB.UnknownEnemy.new(surface),
   }
end

---@class fa.scanner.GlobalSurfaceState
---@field backends fa.scanner.SurfaceBackends
---@field seen_entities fa.ds.SparseBitset
---@field seen_chunks table<number, table<number, true>>

---@return fa.scanner.GlobalSurfaceState
local function new_empty_surface(key)
   local surf = game.get_surface(key)
   assert(surf)

   ---@type fa.scanner.GlobalSurfaceState
   local ret = {
      backends = instantiate_backends(surf),
      seen_entities = SparseBitset.SparseBitset.new(),
      seen_chunks = TH.defaulting_table(),
   }

   return ret
end

---@type table<number, fa.scanner.GlobalSurfaceState>
local surface_state = StorageManager.declare_storage_module(
   "scanner",
   new_empty_surface,
   -- Bumped 12 -> 13 -> 14 -> 15 -> 16 -> 17: same reasoning each time (see git history) -
   -- the "seen" bitset/seen_chunks below permanently remember dispatch/scan decisions, so
   -- any change to WHERE an already-encountered entity gets routed, OR any new per-chunk
   -- backend hook added to scan_chunk's "if not state.seen_chunks[cx][cy]" block, needs a
   -- full state reset to actually take effect on chunks already walked, not just new
   -- ones. 15: adds the Vulcanus/Fulgora/Gleba/Aquilo resource rocks to
   -- BACKEND_NAME_OVERRIDES, and excludes "smoke-with-trigger" (demolisher ash cloud)
   -- from the unknown-enemy catch-all. 16: adds territory_backend's on_new_chunk hook -
   -- without this bump, territories under already-scanned chunks would never be
   -- discovered until those chunks somehow got re-scanned. [GLEBA-SOIL] 17: adds
   -- gleba_soil_backend's on_new_chunk hook (same reasoning as 16, for the same reason),
   -- and routes "yumako-tree"/"jellystem" (prototype type "plant", previously unrouted by
   -- any BACKEND_LUT/BACKEND_NAME_OVERRIDES entry and so silently dropped) to SEB.Rock via
   -- BACKEND_NAME_OVERRIDES.
   { root_field = "surfaces", ephemeral_state_version = 17 }
)

-- Given a backend setup and an array of entities, dispatch the entities to the
-- backends.  Assumes the entities are valid.
---@param backends fa.scanner.SurfaceBackends
---@param ents LuaEntity[]
local function dispatch_entities(backends, ents)
   for i = 1, #ents do
      local e = ents[i]

      if backends.name_lut[e.name] then
         backends.name_lut[e.name]:on_new_entity(e)
      elseif backends.lut[e.type] then
         backends.lut[e.type]:on_new_entity(e)
      elseif e.force and e.force.name == "enemy" and not IGNORED_ENEMY_COMPONENT_TYPES[e.type] then
         -- Unrecognized type, but hostile - surface it instead of silently dropping it.
         backends.unknown_enemy_backend:on_new_entity(e)
      end
   end
end

---@class fa.scanner.SurfaceScannerChunkScan
---@field surface LuaSurface
---@field chunk ChunkPositionAndArea

---@param cmd fa.scanner.SurfaceScannerChunkScan
local function scan_chunk(cmd)
   if not cmd.surface.valid then return end

   local surf = cmd.surface
   local state = surface_state[surf.index]
   local chunk = cmd.chunk
   local cx, cy = chunk.x, chunk.y

   local ents = surf.find_entities(chunk.area)

   -- We just got these from the surface with no gap, so do everything assuming
   -- it's valid.
   TH.retain_unordered(ents, function(item)
      local dest_req = script.register_on_object_destroyed(item)
      if state.seen_entities:test(dest_req) then return false end

      -- The entity may not have the center in this chunk.
      if not math.floor(item.position.x / CHUNK_SIZE) == cx and math.floor(item.position.y / CHUNK_SIZE) == cy then
         return false
      end

      state.seen_entities:set(dest_req)
      return true
   end)

   -- Sorting from a corner with manhattan distance causes the scan to proceed
   -- in an ark from the corner outward.  This doesn't matter for anything but
   -- resources, but for resources it helps the clustering algo extend clusters
   -- rather than having to create many small ones to merge later.
   local ref_x, ref_y = cx * CHUNK_SIZE, cy * CHUNK_SIZE
   Memosort.memosort(ents, function(e)
      local p = e.position
      return (p.x - ref_x) + (p.y - ref_y)
   end)

   dispatch_entities(state.backends, ents)

   if not state.seen_chunks[cx][cy] then
      state.seen_chunks[cx][cy] = true
      state.backends.iceberg_backend:on_new_chunk(chunk)
      state.backends.water_backend:on_new_chunk(chunk)
      state.backends.gleba_soil_backend:on_new_chunk(chunk)
      state.backends.territory_backend:on_new_chunk(chunk)
   end
end

---@param queue fa.WorkQueueHandle
local function redispatch(queue)
   -- For each surface, for each chunk in that surface, dispatch a task.
   local tasks = {}

   for _, s in pairs(game.surfaces) do
      for c in s.get_chunks() do
         local task = {
            surface = s,

            chunk = c,
         }
         table.insert(tasks, task)
      end
   end

   -- Take that and sort it by the distance to any player, so that chunks near
   -- players are scanned first on initial scans of large saves.
   local players = {}
   for _, p in pairs(game.players) do
      table.insert(players, p)
   end

   Memosort.memosort(tasks, function(t)
      if not next(players) then return 0 end

      local cx, cy = t.chunk.x * CHUNK_SIZE, t.chunk.y * CHUNK_SIZE

      local best = math.huge
      for _, p in pairs(players) do
         local dist = math.sqrt((cx - p.position.x) ^ 2 + (cy - p.position.y) ^ 2)
         if dist < best then best = dist end
      end
      return best
   end)

   for _, t in pairs(tasks) do
      queue:enqueue(t)
   end
end

-- This work queue will get a chunk per task.
local work_queue = WorkQueue.declare_work_queue({
   name = "fa.scanner.surface-scanner",
   per_tick = 4,
   worker_function = scan_chunk,
   idle_function = redispatch,
})

---@param event EventData.on_object_destroyed
function mod.on_entity_destroyed(event)
   for _, s in pairs(surface_state) do
      if s.seen_entities:remove(event.registration_number) then
         local b = s.backends

         for _, b in pairs(b.lut) do
            b:on_entity_destroyed(event)
         end

         for _, b in pairs(b.name_lut) do
            b:on_entity_destroyed(event)
         end

         s.backends.unknown_enemy_backend:on_entity_destroyed(event)
      end
   end
end

---@param ent LuaEntity
function mod.on_new_entity(surface_index, ent)
   if not ent.valid then return end

   local state = surface_state[surface_index]
   local dest_req = script.register_on_object_destroyed(ent)

   if state.seen_entities:test(dest_req) then return end
   state.seen_entities:set(dest_req)

   dispatch_entities(state.backends, { ent })
end

---@param surface_index number
---@param player LuaPlayer
---@param callback fun(fa.scanner.ScanEntry)
---@returns table<fa.scanner.ScanEntry, true>
function mod.get_entries_snapshot(surface_index, player, callback)
   local state = surface_state[surface_index]

   -- Important to only ask backends once each.
   local checked_backends = {}

   local backends = state.backends

   for proto, backend in pairs(backends.lut) do
      if not checked_backends[backend] then
         checked_backends[backend] = true
         backend:dump_entries_to_callback(player, callback)
      end
   end

   for proto, backend in pairs(backends.name_lut) do
      if not checked_backends[backend] then
         checked_backends[backend] = true
         backend:dump_entries_to_callback(player, callback)
      end
   end

   state.backends.iceberg_backend:dump_entries_to_callback(player, callback)
   state.backends.water_backend:dump_entries_to_callback(player, callback)
   state.backends.gleba_soil_backend:dump_entries_to_callback(player, callback)
   state.backends.territory_backend:dump_entries_to_callback(player, callback)
   state.backends.unknown_enemy_backend:dump_entries_to_callback(player, callback)
end

function mod.on_new_surface(index)
   surface_state[index] = new_empty_surface(index)
end

function mod.on_surface_delete(index)
   surface_state[index] = nil
end

return mod
