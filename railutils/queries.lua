---Rail Traversal Utilities
---
---Functions for finding rail connection points and navigating rail networks

require("polyfill")

local RailData = require("railutils.rail-data")
local RailInfo = require("railutils.rail-info")

local mod = {}

---Map from defines.direction to direction name
---@type table<defines.direction, string>
mod.DIRECTION_NAMES = {
   [defines.direction.north] = "north",
   [defines.direction.northnortheast] = "northnortheast",
   [defines.direction.northeast] = "northeast",
   [defines.direction.eastnortheast] = "eastnortheast",
   [defines.direction.east] = "east",
   [defines.direction.eastsoutheast] = "eastsoutheast",
   [defines.direction.southeast] = "southeast",
   [defines.direction.southsoutheast] = "southsoutheast",
   [defines.direction.south] = "south",
   [defines.direction.southsouthwest] = "southsouthwest",
   [defines.direction.southwest] = "southwest",
   [defines.direction.westsouthwest] = "westsouthwest",
   [defines.direction.west] = "west",
   [defines.direction.westnorthwest] = "westnorthwest",
   [defines.direction.northwest] = "northwest",
   [defines.direction.northnorthwest] = "northnorthwest",
}

---Map from defines.direction to cardinal name (only for cardinals)
---@type table<defines.direction, string>
mod.CARDINAL_NAMES = {
   [defines.direction.north] = "north",
   [defines.direction.east] = "east",
   [defines.direction.south] = "south",
   [defines.direction.west] = "west",
}

---Map from defines.direction to diagonal name (only for diagonals)
---@type table<defines.direction, string>
mod.DIAGONAL_NAMES = {
   [defines.direction.northeast] = "northeast",
   [defines.direction.southeast] = "southeast",
   [defines.direction.southwest] = "southwest",
   [defines.direction.northwest] = "northwest",
}

---Get direction name
---@param direction defines.direction
---@return string
function mod.get_direction_name(direction)
   return mod.DIRECTION_NAMES[direction] or "unknown"
end

---Get cardinal name (only for cardinal directions)
---@param direction defines.direction
---@return string|nil
function mod.get_cardinal_name(direction)
   return mod.CARDINAL_NAMES[direction]
end

---Get diagonal name (only for diagonal directions)
---@param direction defines.direction
---@return string|nil
function mod.get_diagonal_name(direction)
   return mod.DIAGONAL_NAMES[direction]
end

-- Bidirectional mapping between RailType and prototype names
local RAIL_TYPE_TO_PROTOTYPE = {
   [RailInfo.RailType.STRAIGHT] = "straight-rail",
   [RailInfo.RailType.CURVE_A] = "curved-rail-a",
   [RailInfo.RailType.CURVE_B] = "curved-rail-b",
   [RailInfo.RailType.HALF_DIAGONAL] = "half-diagonal-rail",
   [RailInfo.RailType.RAMP] = "rail-ramp",
}

-- Elevated prototype types. Their geometry lives in RailData under the ground type.
local ELEVATED_PROTOTYPE_OF = {
   [RailInfo.RailType.STRAIGHT] = "elevated-straight-rail",
   [RailInfo.RailType.CURVE_A] = "elevated-curved-rail-a",
   [RailInfo.RailType.CURVE_B] = "elevated-curved-rail-b",
   [RailInfo.RailType.HALF_DIAGONAL] = "elevated-half-diagonal-rail",
}

local ELEVATED_PROTOTYPE_TO_RAIL_TYPE = {}
for rail_type, prototype in pairs(ELEVATED_PROTOTYPE_OF) do
   ELEVATED_PROTOTYPE_TO_RAIL_TYPE[prototype] = rail_type
end

local PROTOTYPE_TO_RAIL_TYPE = {}
for rail_type, prototype in pairs(RAIL_TYPE_TO_PROTOTYPE) do
   PROTOTYPE_TO_RAIL_TYPE[prototype] = rail_type
end

---Map RailType to prototype type string for table lookup
---@param rail_type railutils.RailType
---@return string
function mod.rail_type_to_prototype_type(rail_type)
   local result = RAIL_TYPE_TO_PROTOTYPE[rail_type]
   if not result then error("Unknown rail type: " .. tostring(rail_type)) end
   return result
end

---Map prototype type string to RailType
---@param prototype string Prototype type string like "curved-rail-a"
---@return railutils.RailType
function mod.prototype_type_to_rail_type(prototype)
   local result = PROTOTYPE_TO_RAIL_TYPE[prototype]
   if not result then error("Unknown prototype: " .. tostring(prototype)) end
   return result
end

---Map a RailType and layer to the prototype type to build. Ramps ignore the layer.
---@param rail_type railutils.RailType
---@param layer railutils.RailLayer
---@return string
function mod.rail_type_to_layered_prototype_type(rail_type, layer)
   if layer == RailInfo.RailLayer.ELEVATED and rail_type ~= RailInfo.RailType.RAMP then
      local result = ELEVATED_PROTOTYPE_OF[rail_type]
      if not result then error("Unknown rail type: " .. tostring(rail_type)) end
      return result
   end
   return mod.rail_type_to_prototype_type(rail_type)
end

---Map any rail prototype type (ground, elevated or ramp) to its RailType and layer. The layer is nil for ramps,
---because the two ends of a ramp are on different layers.
---@param prototype string
---@return railutils.RailType, railutils.RailLayer?
function mod.prototype_type_to_rail_type_and_layer(prototype)
   local elevated = ELEVATED_PROTOTYPE_TO_RAIL_TYPE[prototype]
   if elevated then return elevated, RailInfo.RailLayer.ELEVATED end
   local rail_type = mod.prototype_type_to_rail_type(prototype)
   if rail_type == RailInfo.RailType.RAMP then return rail_type, nil end
   return rail_type, RailInfo.RailLayer.GROUND
end

---Whether a prototype type is any rail piece railutils understands. For entry points that see arbitrary entities.
---@param prototype string
---@return boolean
function mod.is_known_rail_prototype_type(prototype)
   return PROTOTYPE_TO_RAIL_TYPE[prototype] ~= nil or ELEVATED_PROTOTYPE_TO_RAIL_TYPE[prototype] ~= nil
end

---Layer of a ramp end. Returns nil for every other rail type, whose ends take the layer of the piece.
---@param rail_type railutils.RailType
---@param placement_direction defines.direction
---@param end_direction defines.direction
---@return railutils.RailLayer?
function mod.get_ramp_end_layer(rail_type, placement_direction, end_direction)
   if rail_type ~= RailInfo.RailType.RAMP then return nil end
   local end_data = RailData[RAIL_TYPE_TO_PROTOTYPE[rail_type]][placement_direction][end_direction]
   if not end_data then error("Invalid end_direction for ramp: " .. tostring(end_direction)) end
   return end_data.layer
end

---Get the grid-adjusted position where a rail will actually be placed
---
---Rails have parity requirements and the game snaps them to the grid by applying
---a grid_offset. This function returns the actual position where the rail will end up.
---
---@param rail_type railutils.RailType Type of rail to place
---@param position fa.Point Requested position
---@param direction defines.direction Direction to place the rail
---@return fa.Point The actual position after grid adjustment
function mod.get_adjusted_position(rail_type, position, direction)
   local prototype_type = mod.rail_type_to_prototype_type(rail_type)
   local rail_entry = RailData[prototype_type]
   if not rail_entry then error("Unknown rail prototype: " .. prototype_type) end

   local direction_entry = rail_entry[direction]
   if not direction_entry then error("Invalid direction for rail type: " .. direction) end

   local grid_offset = direction_entry.grid_offset
   if not grid_offset then error("No grid_offset found for rail") end

   return {
      x = position.x + grid_offset.x,
      y = position.y + grid_offset.y,
   }
end

---Get both end directions for a rail
---
---Every rail has two ends. This returns the directions of both ends.
---
---@param rail_type railutils.RailType Type of rail
---@param placement_direction defines.direction Direction the rail is placed
---@return defines.direction[] Array of two end directions
function mod.get_end_directions(rail_type, placement_direction)
   local prototype_type = mod.rail_type_to_prototype_type(rail_type)
   local rail_entry = RailData[prototype_type]
   if not rail_entry then error("Unknown rail prototype: " .. prototype_type) end

   local direction_entry = rail_entry[placement_direction]
   if not direction_entry then error("Invalid placement direction for rail type: " .. placement_direction) end

   local end_directions = {}
   for key, value in pairs(direction_entry) do
      -- End directions are numeric keys with extension data
      if type(key) == "number" and value.extensions then table.insert(end_directions, key) end
   end

   if #end_directions ~= 2 then error("Expected 2 ends, found " .. #end_directions) end

   return end_directions
end

---Extension point information
---@class railutils.ExtensionPoint
---@field rail_unit_number number Unit number of the rail this extension is from
---@field end_position fa.Point Absolute position of the rail end
---@field end_direction defines.direction Direction the rail end faces
---@field goal_direction defines.direction Direction of the extension
---@field next_rail_prototype string Prototype type to place for this extension
---@field next_rail_position fa.Point Absolute position to place next rail
---@field next_rail_direction defines.direction Direction to place next rail
---@field next_rail_goal_position fa.Point Absolute position of far end of next rail
---@field next_rail_goal_direction defines.direction Direction of far end of next rail
---@field next_rail_goal_layer railutils.RailLayer? Layer of the far end, set only for ramp extensions

---Get extension points from a specific end of a specific rail configuration
---
---@param position fa.Point Rail's grid-adjusted position
---@param rail_type railutils.RailType Type of rail
---@param placement_direction defines.direction Direction the rail is placed
---@param end_direction defines.direction Which end to get extensions from
---@return railutils.ExtensionPoint[] Array of extensions from this end
function mod.get_extensions_from_end(position, rail_type, placement_direction, end_direction)
   local prototype_type = mod.rail_type_to_prototype_type(rail_type)
   local rail_entry = RailData[prototype_type]
   if not rail_entry then error("Unknown rail prototype: " .. prototype_type) end

   local direction_entry = rail_entry[placement_direction]
   if not direction_entry then error("Invalid placement direction for rail type: " .. placement_direction) end

   local end_data = direction_entry[end_direction]
   if not end_data or not end_data.extensions then
      error("Invalid end_direction or no extensions for this end: " .. end_direction)
   end

   local extensions = {}

   -- Calculate absolute position of the end
   local end_abs_position = {
      x = position.x + end_data.position.x,
      y = position.y + end_data.position.y,
   }

   -- Iterate over all extensions from this end
   for goal_dir, extension in pairs(end_data.extensions) do
      -- Calculate absolute positions for the extension
      local next_rail_abs_position = {
         x = position.x + extension.position.x,
         y = position.y + extension.position.y,
      }

      local next_rail_goal_abs_position = {
         x = position.x + extension.goal_position.x,
         y = position.y + extension.goal_position.y,
      }

      local ext_point = {
         rail_unit_number = nil, -- Not relevant when querying by configuration
         end_position = end_abs_position,
         end_direction = end_direction,
         goal_direction = goal_dir,
         next_rail_prototype = extension.prototype,
         next_rail_position = next_rail_abs_position,
         next_rail_direction = extension.direction,
         next_rail_goal_position = next_rail_goal_abs_position,
         next_rail_goal_direction = extension.goal_direction,
      }

      table.insert(extensions, ext_point)
   end

   return extensions
end

---Get the ramp that can extend a specific end, if any. Only cardinal ends have one: a ramp up from a ground end, a
---ramp down from an elevated end.
---
---@param position fa.Point Rail's grid-adjusted position
---@param rail_type railutils.RailType Type of rail
---@param placement_direction defines.direction Direction the rail is placed
---@param end_direction defines.direction Which end to extend
---@param layer railutils.RailLayer Layer of that end
---@return railutils.ExtensionPoint?
function mod.get_ramp_extension_from_end(position, rail_type, placement_direction, end_direction, layer)
   local prototype_type = mod.rail_type_to_prototype_type(rail_type)
   local end_data = RailData[prototype_type][placement_direction][end_direction]
   if not end_data then error("Invalid end_direction: " .. tostring(end_direction)) end

   local ramp = layer == RailInfo.RailLayer.ELEVATED and end_data.ramp_down or end_data.ramp_up
   if not ramp then return nil end

   return {
      rail_unit_number = nil,
      end_position = { x = position.x + end_data.position.x, y = position.y + end_data.position.y },
      end_direction = end_direction,
      goal_direction = ramp.goal_direction,
      next_rail_prototype = ramp.prototype,
      next_rail_position = { x = position.x + ramp.position.x, y = position.y + ramp.position.y },
      next_rail_direction = ramp.direction,
      next_rail_goal_position = { x = position.x + ramp.goal_position.x, y = position.y + ramp.goal_position.y },
      next_rail_goal_direction = ramp.goal_direction,
      next_rail_goal_layer = ramp.goal_layer,
   }
end

return mod
