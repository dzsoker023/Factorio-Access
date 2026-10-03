---Rail Table Extractor
---
---Extracts the geometric and connectivity data for every rail piece from the engine itself, so the rail navigation
---system (railutils) can understand rail geometry without hardcoding piece-specific logic. The output is the source
---of railutils/rail-data.lua.
---
---# What the Extracted Table Contains
---
---```
---[prototype_type][placement_direction] = {
---  grid_offset = { x, y },                          -- API placement offset from requested origin
---  bounding_box = { left_top, right_bottom, orientation? },
---  occupied_tiles = { {x, y}, ... },                -- Integer tile coordinates relative to entity
---  [end_direction] = {                              -- One entry per rail end
---    position = { x, y },
---    layer = "ground" | "elevated",                 -- rail-ramp only, see below
---    signal_locations = { in_signal, out_signal, alt_in_signal?, alt_out_signal? },
---    extensions = { [goal_direction] = { ... } },   -- Same-layer next pieces
---    ramp_up = { ... }?,                            -- Ramp leaving this end upwards (from a ground end)
---    ramp_down = { ... }?,                          -- Ramp leaving this end downwards (from an elevated end)
---  }
---}
---```
---
---Each extension holds prototype (always the ground piece type, e.g. "straight-rail"), position, direction,
---goal_position and goal_direction. Ramp extensions also hold goal_layer.
---
---# Layers
---
---Elevated rails have exactly the same geometry as their ground counterparts (same grid offsets, ends, signal
---locations and same-layer extensions). The extractor verifies that for every piece and direction, and then stores the
---geometry once under the ground type. The only layer-specific data is the ramp:
---
---- Every cardinal rail end can be extended by a rail-ramp. From a ground end the ramp goes up (ramp_up), from an
---  elevated end it goes down (ramp_down). Both share position and goal_position and differ only in direction. The
---  engine reports the ramp with the same goal direction as the straight extension, which is why ramps live in their
---  own fields instead of in the extensions table (they would otherwise overwrite the straight piece).
---- rail-ramp itself has its own entry, placeable in the four cardinal directions only. Its two ends are on different
---  layers, so ramp ends carry a layer field. Same-layer extensions of a ramp end are again stored by ground type.
---
---# Directions and Coordinates
---
---Rails use 16-way directions (defines.direction); rail pieces are placed in the 8 even directions and ramps in the 4
---cardinal ones. Directions are stored as names ("north", "eastnortheast", ...) in the extracted table;
---mod.serialize turns them back into defines.direction expressions for rail-data.lua.
---
---ALL coordinates are relative to the piece's actual position after placement, not the requested origin. grid_offset
---records actual_position - requested_position. Occupied tiles use integer tile indices.
---
---# How Data is Extracted
---
---Everything happens on a scratch surface and force (scripts/rails/scratch-surface.lua), never on the player's surface.
---For each piece type and direction: place it at the origin, record position, bounding box and occupied tiles, query
---both ends through LuaRailEnd (signal locations and get_rail_extensions), make all positions relative, destroy it.
---
---Called by the /railtable command to regenerate the table after game updates.

local ScratchSurface = require("scripts.rails.scratch-surface")

local mod = {}

---Direction number to string name mapping
local DIRECTION_NAMES = {
   [0] = "north",
   [1] = "northnortheast",
   [2] = "northeast",
   [3] = "eastnortheast",
   [4] = "east",
   [5] = "eastsoutheast",
   [6] = "southeast",
   [7] = "southsoutheast",
   [8] = "south",
   [9] = "southsouthwest",
   [10] = "southwest",
   [11] = "westsouthwest",
   [12] = "west",
   [13] = "westnorthwest",
   [14] = "northwest",
   [15] = "northnorthwest",
}

---Direction name to number, for the serializer
local DIRECTION_BY_NAME = {}
for number, name in pairs(DIRECTION_NAMES) do
   DIRECTION_BY_NAME[name] = number
end

---Ground rail piece prototype names
local GROUND_PIECES = {
   "straight-rail",
   "half-diagonal-rail",
   "curved-rail-a",
   "curved-rail-b",
}

---Elevated counterpart of each ground piece
local ELEVATED_OF = {
   ["straight-rail"] = "elevated-straight-rail",
   ["half-diagonal-rail"] = "elevated-half-diagonal-rail",
   ["curved-rail-a"] = "elevated-curved-rail-a",
   ["curved-rail-b"] = "elevated-curved-rail-b",
}

---Prototype type to the ground type its geometry is stored under
local GROUND_TYPE_OF = {
   ["straight-rail"] = "straight-rail",
   ["half-diagonal-rail"] = "half-diagonal-rail",
   ["curved-rail-a"] = "curved-rail-a",
   ["curved-rail-b"] = "curved-rail-b",
   ["elevated-straight-rail"] = "straight-rail",
   ["elevated-half-diagonal-rail"] = "half-diagonal-rail",
   ["elevated-curved-rail-a"] = "curved-rail-a",
   ["elevated-curved-rail-b"] = "curved-rail-b",
   ["rail-ramp"] = "rail-ramp",
}

local RAMP_NAME = "rail-ramp"

---8-way placement directions for rail pieces (even values only)
local PLACEMENT_DIRECTIONS = { 0, 2, 4, 6, 8, 10, 12, 14 }

---Ramps are 4-way
local RAMP_DIRECTIONS = { 0, 4, 8, 12 }

---Fields whose string values are direction names
local DIRECTION_FIELDS = {
   direction = true,
   goal_direction = true,
}

---@param layer defines.rail_layer
---@return "ground"|"elevated"
local function layer_name(layer)
   if layer == defines.rail_layer.elevated then return "elevated" end
   return "ground"
end

---@param a any
---@param b any
---@return boolean
local function deep_equal(a, b)
   if type(a) ~= type(b) then return false end
   if type(a) ~= "table" then return a == b end
   for k, v in pairs(a) do
      if not deep_equal(v, b[k]) then return false end
   end
   for k in pairs(b) do
      if a[k] == nil then return false end
   end
   return true
end

---@param pos MapPosition
---@param origin MapPosition
---@return MapPosition
local function relative(pos, origin)
   return { x = pos.x - origin.x, y = pos.y - origin.y }
end

---@param loc RailLocation
---@param origin MapPosition
local function signal_entry(loc, origin)
   return { position = relative(loc.position, origin), direction = DIRECTION_NAMES[loc.direction] }
end

---@param report string[]
---@param fmt string
local function problem(report, fmt, ...)
   table.insert(report, string.format(fmt, ...))
end

---Extract one rail end
---@param rail_end LuaRailEnd
---@param origin MapPosition
---@param context string For problem messages
---@param report string[]
---@return table end_data, string end_dir_str
local function extract_end(rail_end, origin, context, report)
   local loc = rail_end.location
   local own_layer = loc.rail_layer
   local end_dir_str = DIRECTION_NAMES[loc.direction]

   local end_data = {
      position = relative(loc.position, origin),
      signal_locations = {
         in_signal = signal_entry(rail_end.in_signal_location, origin),
         out_signal = signal_entry(rail_end.out_signal_location, origin),
      },
      extensions = {},
   }
   if rail_end.alternative_in_signal_location then
      end_data.signal_locations.alt_in_signal = signal_entry(rail_end.alternative_in_signal_location, origin)
   end
   if rail_end.alternative_out_signal_location then
      end_data.signal_locations.alt_out_signal = signal_entry(rail_end.alternative_out_signal_location, origin)
   end

   for _, ext in ipairs(rail_end.get_rail_extensions("rail")) do
      local ext_type = prototypes.entity[ext.name].type
      local entry = {
         prototype = GROUND_TYPE_OF[ext_type],
         position = relative(ext.position, origin),
         direction = DIRECTION_NAMES[ext.direction],
         goal_position = relative(ext.goal.position, origin),
         goal_direction = DIRECTION_NAMES[ext.goal.direction],
      }
      if not entry.prototype then
         problem(report, "%s end %s: unknown extension prototype %s", context, end_dir_str, ext.name)
      elseif ext.goal.rail_layer ~= own_layer then
         if ext_type ~= RAMP_NAME then
            problem(report, "%s end %s: layer change through %s, expected only ramps", context, end_dir_str, ext.name)
         end
         entry.goal_layer = layer_name(ext.goal.rail_layer)
         local key = own_layer == defines.rail_layer.elevated and "ramp_down" or "ramp_up"
         if end_data[key] then problem(report, "%s end %s: two %s extensions", context, end_dir_str, key) end
         end_data[key] = entry
      else
         if end_data.extensions[entry.goal_direction] then
            local dir = entry.goal_direction
            problem(report, "%s end %s: two same-layer extensions towards %s", context, end_dir_str, dir)
         end
         end_data.extensions[entry.goal_direction] = entry
      end
   end

   return end_data, end_dir_str
end

---Place one piece at the origin of the scratch surface and extract it
---@param scratch fa.rails.ScratchSurface
---@param name string
---@param dir integer
---@param report string[]
---@return table? piece_data, table<string, defines.rail_layer>? end_layers
local function extract_piece(scratch, name, dir, report)
   local origin = { x = 0, y = 0 }
   local surface = scratch.surface
   ScratchSurface.clear_around(scratch, origin, 24)

   local rail = surface.create_entity({
      name = name,
      position = origin,
      direction = dir --[[@as defines.direction]],
      force = scratch.force,
      raise_built = false,
      create_build_effect_smoke = false,
   })
   if not rail then
      problem(report, "%s %s: create_entity failed", name, DIRECTION_NAMES[dir])
      return nil, nil
   end

   local actual_position = rail.position
   local raw_bbox = rail.bounding_box
   local bounding_box = {
      left_top = relative(raw_bbox.left_top, actual_position),
      right_bottom = relative(raw_bbox.right_bottom, actual_position),
   }
   if raw_bbox.orientation then bounding_box.orientation = raw_bbox.orientation end

   -- Scan tiles to find which tiles contain this entity, with the same small per-tile area as entity selection
   local occupied_tiles = {}
   for tx = -16, 16 do
      for ty = -16, 16 do
         local tile_x = math.floor(actual_position.x) + tx
         local tile_y = math.floor(actual_position.y) + ty
         local search_area = {
            { x = tile_x + 0.001, y = tile_y + 0.001 },
            { x = tile_x + 0.999, y = tile_y + 0.999 },
         }
         for _, ent in ipairs(surface.find_entities_filtered({ area = search_area })) do
            if ent == rail then
               table.insert(occupied_tiles, { x = tile_x - actual_position.x, y = tile_y - actual_position.y })
               break
            end
         end
      end
   end

   local piece_data = {
      grid_offset = relative(actual_position, origin),
      bounding_box = bounding_box,
      occupied_tiles = occupied_tiles,
   }
   local end_layers = {}
   local context = name .. " " .. DIRECTION_NAMES[dir]
   for _, rail_direction in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local rail_end = rail.get_rail_end(rail_direction)
      local end_data, end_dir_str = extract_end(rail_end, actual_position, context, report)
      piece_data[end_dir_str] = end_data
      end_layers[end_dir_str] = rail_end.location.rail_layer
   end

   rail.destroy()
   return piece_data, end_layers
end

---Merge an elevated piece into its ground twin: verify the shared geometry, then take its ramp_down extensions
---@param ground table
---@param elevated table
---@param context string
---@param report string[]
local function merge_elevated(ground, elevated, context, report)
   for _, field in ipairs({ "grid_offset", "bounding_box", "occupied_tiles" }) do
      if not deep_equal(ground[field], elevated[field]) then
         problem(report, "%s: elevated %s differs from ground", context, field)
      end
   end
   for key, g_end in pairs(ground) do
      if DIRECTION_BY_NAME[key] then
         local e_end = elevated[key]
         if not e_end then
            problem(report, "%s: elevated piece has no end %s", context, key)
         else
            for _, field in ipairs({ "position", "signal_locations", "extensions" }) do
               if not deep_equal(g_end[field], e_end[field]) then
                  problem(report, "%s end %s: elevated %s differs from ground", context, key, field)
               end
            end
            if e_end.ramp_up then problem(report, "%s end %s: elevated end reports a ramp_up", context, key) end
            g_end.ramp_down = e_end.ramp_down
         end
      end
   end
end

---Extract the complete rail table on a scratch surface
---@return table rail_data Table keyed [prototype_type][direction_name]
---@return string[] report Problems found; empty when everything matched expectations
function mod.extract_rail_table()
   local report = {}
   local rail_data = {}
   local scratch = ScratchSurface.create("fa-rail-table", { half_size = 48 })

   local ok, err = pcall(function()
      for _, ground_name in ipairs(GROUND_PIECES) do
         local prototype_type = prototypes.entity[ground_name].type
         rail_data[prototype_type] = {}
         local has_elevated = prototypes.entity[ELEVATED_OF[ground_name]] ~= nil
         for _, dir in ipairs(PLACEMENT_DIRECTIONS) do
            local dir_str = DIRECTION_NAMES[dir]
            local ground = extract_piece(scratch, ground_name, dir, report)
            if ground then
               if has_elevated then
                  local elevated = extract_piece(scratch, ELEVATED_OF[ground_name], dir, report)
                  if elevated then merge_elevated(ground, elevated, ground_name .. " " .. dir_str, report) end
               end
               rail_data[prototype_type][dir_str] = ground
            end
         end
      end

      if prototypes.entity[RAMP_NAME] then
         rail_data[RAMP_NAME] = {}
         for _, dir in ipairs(RAMP_DIRECTIONS) do
            local ramp, end_layers = extract_piece(scratch, RAMP_NAME, dir, report)
            if ramp and end_layers then
               for end_dir_str, layer in pairs(end_layers) do
                  ramp[end_dir_str].layer = layer_name(layer)
               end
               rail_data[RAMP_NAME][DIRECTION_NAMES[dir]] = ramp
            end
         end
      end
   end)
   ScratchSurface.destroy(scratch)
   if not ok then problem(report, "extraction aborted: %s", tostring(err)) end

   return rail_data, report
end

---@param key any
---@return string
local function sort_name(key)
   return tostring(key)
end

---@param value number
---@return string
local function number_literal(value)
   if value == math.floor(value) and math.abs(value) < 2 ^ 53 then return string.format("%d", value) end
   return string.format("%.17g", value)
end

---@param t table
---@return boolean
local function is_array(t)
   local n = #t
   if n == 0 then return false end
   for k in pairs(t) do
      if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then return false end
   end
   return true
end

---@param value any
---@param indent string
---@param field_name string?
---@param lines string[]
---@param prefix string
local function serialize_value(value, indent, field_name, lines, prefix)
   local t = type(value)
   if t == "table" then
      table.insert(lines, prefix .. "{")
      local inner = indent .. "   "
      if is_array(value) then
         for _, item in ipairs(value) do
            serialize_value(item, inner, nil, lines, inner)
         end
      else
         local keys = {}
         for k in pairs(value) do
            table.insert(keys, k)
         end
         table.sort(keys, function(a, b)
            return sort_name(a) < sort_name(b)
         end)
         for _, k in ipairs(keys) do
            local key_text
            if type(k) == "string" and DIRECTION_BY_NAME[k] then
               key_text = "[defines.direction." .. k .. "] = "
            elseif type(k) == "string" and k:match("^[%a_][%w_]*$") then
               key_text = k .. " = "
            else
               key_text = string.format("[%q] = ", k)
            end
            serialize_value(value[k], inner, type(k) == "string" and k or nil, lines, inner .. key_text)
         end
      end
      table.insert(lines, indent .. "},")
   elseif t == "string" then
      if field_name and DIRECTION_FIELDS[field_name] and DIRECTION_BY_NAME[value] then
         table.insert(lines, prefix .. "defines.direction." .. value .. ",")
      else
         table.insert(lines, prefix .. string.format("%q", value) .. ",")
      end
   elseif t == "number" then
      table.insert(lines, prefix .. number_literal(value) .. ",")
   else
      table.insert(lines, prefix .. tostring(value) .. ",")
   end
end

---Turn an extracted table into the Lua source of railutils/rail-data.lua
---@param rail_data table
---@return string
function mod.serialize(rail_data)
   local lines = { 'require("polyfill")', "", "return {" }
   local types = {}
   for k in pairs(rail_data) do
      table.insert(types, k)
   end
   table.sort(types)
   for _, type_name in ipairs(types) do
      serialize_value(rail_data[type_name], "   ", nil, lines, string.format('   [%q] = ', type_name))
   end
   table.insert(lines, "}")
   table.insert(lines, "")
   return table.concat(lines, "\n")
end

return mod
