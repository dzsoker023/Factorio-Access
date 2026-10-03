---Scratch surface for rail developer tools
---
---The rail table extractor and the elevated rails probe both need to build and destroy rails freely. Doing that on
---the player's surface would wreck their base, so both tools work on a throwaway surface and force created here.
---The surface is a flat square of concrete with an optional water strip, with no entities on it.

local mod = {}

local GROUND_TILE = "refined-concrete"
local WATER_TILE = "water"

---@class fa.rails.ScratchSurface
---@field surface LuaSurface
---@field force LuaForce

---@class fa.rails.ScratchSurfaceOpts
---@field half_size integer Half the side length of the prepared square, in tiles
---@field water_x_min integer? First x of a water strip (inclusive)
---@field water_x_max integer? Last x of a water strip (exclusive)

---Create a scratch surface and force. Names get the current tick appended so repeated runs never collide with a surface
---that is still pending deletion.
---@param prefix string
---@param opts fa.rails.ScratchSurfaceOpts
---@return fa.rails.ScratchSurface
function mod.create(prefix, opts)
   local name = prefix .. "-" .. tostring(game.tick)
   local half = opts.half_size
   local surface = game.create_surface(name, {
      width = 2 * half,
      height = 2 * half,
      default_enable_all_autoplace_controls = false,
      no_enemies_mode = true,
      peaceful_mode = true,
   })
   surface.request_to_generate_chunks({ x = 0, y = 0 }, math.ceil(half / 32) + 1)
   surface.force_generate_chunk_requests()

   local tiles = {}
   for x = -half, half - 1 do
      local is_water = opts.water_x_min and x >= opts.water_x_min and x < opts.water_x_max
      local tile_name = is_water and WATER_TILE or GROUND_TILE
      for y = -half, half - 1 do
         table.insert(tiles, { name = tile_name, position = { x = x, y = y } })
      end
   end
   surface.set_tiles(tiles, true, true, true, false)

   for _, e in ipairs(surface.find_entities_filtered({ area = { { -half, -half }, { half, half } } })) do
      if e.valid then e.destroy() end
   end

   local force = game.create_force(name)
   force.rail_planner_allow_elevated_rails = true

   return { surface = surface, force = force }
end

---Destroy everything in a square around a point
---@param scratch fa.rails.ScratchSurface
---@param center MapPosition
---@param radius number
function mod.clear_around(scratch, center, radius)
   local ents = scratch.surface.find_entities_filtered({
      area = { { center.x - radius, center.y - radius }, { center.x + radius, center.y + radius } },
   })
   for _, e in ipairs(ents) do
      if e.valid then e.destroy() end
   end
end

---Queue the surface for deletion and fold the force into neutral. Both happen at the end of the tick.
---@param scratch fa.rails.ScratchSurface
function mod.destroy(scratch)
   game.delete_surface(scratch.surface)
   game.merge_forces(scratch.force, "neutral")
end

return mod
