---Elevated reach of built track
---
---How much more elevated track the supports and ramps already standing in the world can hold past a rail end. The
---engine rule (measured with /elevprobe): an elevated rail can be built if it connects through built track to a support
---or the top of a ramp, and the distance along the track from that anchor to the far end of the rail is within the
---anchor's range. So the reach at an end is the best (range - distance) over the anchors behind it.
---
---Only real rails are walked: ghosts hold nothing.

local Queries = require("railutils.queries")
local RailInfo = require("railutils.rail-info")
local SupportPlanner = require("railutils.support-planner")

local mod = {}

local CONNECTIONS = {
   defines.rail_connection_direction.left,
   defines.rail_connection_direction.straight,
   defines.rail_connection_direction.right,
}

---@class fa.rails.ElevatedRanges
---@field support_range number
---@field ramp_range number

---@param rail LuaEntity
---@return railutils.SupportPlanner.Piece
local function piece_of(rail)
   local rail_type = Queries.prototype_type_to_rail_type_and_layer(rail.type)
   return {
      rail_type = rail_type,
      placement_direction = rail.direction,
      position = { x = rail.position.x, y = rail.position.y },
   }
end

---Whether a support stands exactly at a rail end, facing along the track
---@param surface LuaSurface
---@param location RailLocation
---@return boolean
local function has_support_at(surface, location)
   if location.direction % 2 ~= 0 then return false end
   local supports =
      surface.find_entities_filtered({ position = location.position, radius = 0.5, type = "rail-support" })
   for _, s in ipairs(supports) do
      if
         s.position.x == location.position.x
         and s.position.y == location.position.y
         and s.direction % 8 == location.direction % 8
      then
         return true
      end
   end
   return false
end

---Layer of the end of a ramp a rail end points out of
---@param ramp LuaEntity
---@param direction defines.direction
---@return railutils.RailLayer?
local function ramp_end_layer(ramp, direction)
   return Queries.get_ramp_end_layer(RailInfo.RailType.RAMP, ramp.direction, direction)
end

---Reach left at one end of a built rail
---@param rail LuaEntity A real elevated rail or ramp
---@param end_direction defines.direction Map direction of the end, as the virtual train sees it
---@param ranges fa.rails.ElevatedRanges
---@return number reach 0 if nothing behind holds anything more
function mod.reach_at_end(rail, end_direction, ranges)
   local max_range = math.max(ranges.support_range, ranges.ramp_range)
   local surface = rail.surface
   local best = 0
   local function consider(distance, range)
      if range - distance > best then best = range - distance end
   end

   local start_end, back_end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = rail.get_rail_end(rd)
      if e.location.direction == end_direction then
         start_end = e
      else
         back_end = e
      end
   end
   if not start_end or not back_end then return 0 end

   -- The end itself
   if has_support_at(surface, start_end.location) then consider(0, ranges.support_range) end
   if rail.type == "rail-ramp" then
      -- The top of a ramp holds what is built off it; standing on the ground end, there is nothing elevated here
      if ramp_end_layer(rail, end_direction) == RailInfo.RailLayer.ELEVATED then consider(0, ranges.ramp_range) end
      return best
   end

   -- The other end of this rail, then walk back
   local first_length = SupportPlanner.length(piece_of(rail))
   if has_support_at(surface, back_end.location) then consider(first_length, ranges.support_range) end

   local visited = { [rail.unit_number] = true }
   local queue = { { rail_end = back_end, distance = first_length } }
   while #queue > 0 do
      local item = table.remove(queue)
      for _, connection in ipairs(CONNECTIONS) do
         local next_end = item.rail_end.make_copy()
         if next_end.move_forward(connection) then
            local next_rail = next_end.rail
            if not visited[next_rail.unit_number] then
               visited[next_rail.unit_number] = true
               if next_rail.type == "rail-ramp" then
                  -- Reached through its top only if its far end is on the ground
                  if ramp_end_layer(next_rail, next_end.location.direction) == RailInfo.RailLayer.GROUND then
                     consider(item.distance, ranges.ramp_range)
                  end
               elseif Queries.is_known_rail_prototype_type(next_rail.type) then
                  local _, layer = Queries.prototype_type_to_rail_type_and_layer(next_rail.type)
                  if layer == RailInfo.RailLayer.ELEVATED then
                     local distance = item.distance + SupportPlanner.length(piece_of(next_rail))
                     if has_support_at(surface, next_end.location) then consider(distance, ranges.support_range) end
                     if distance < max_range then table.insert(queue, { rail_end = next_end, distance = distance }) end
                  end
               end
            end
         end
      end
   end

   return best
end

return mod
