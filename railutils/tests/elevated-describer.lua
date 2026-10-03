local lu = require("luaunit")
require("polyfill")

local TestSurface = require("railutils.surface-impls.test-surface")
local RailDescriber = require("railutils.rail-describer")
local RailInfo = require("railutils.rail-info")
local Traverser = require("railutils.traverser")

local mod = {}

local ELEVATED = RailInfo.RailLayer.ELEVATED

---Build a run with a traverser from a ground straight rail at (1, 1) facing north, putting every piece on the surface.
---Returns the pieces as { rail_type, placement_direction, position, layer }.
local function build(surface, words)
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, defines.direction.north, defines.direction.north)
   surface:add_rail_at(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, defines.direction.north)
   local pieces = {}
   for _, w in ipairs(words) do
      if w == "s" then
         trav:move_forward()
      elseif w == "l" then
         trav:move_left()
      elseif w == "r" then
         trav:move_right()
      else
         trav:move_change_layer()
      end
      local piece = {
         rail_type = trav:get_rail_kind(),
         placement_direction = trav:get_placement_direction(),
         position = trav:get_position(),
         layer = trav:get_layer(),
      }
      surface:add_rail_at(piece.rail_type, piece.position, piece.placement_direction, piece.layer)
      table.insert(pieces, piece)
   end
   return pieces
end

local function describe(surface, piece)
   return RailDescriber.describe_rail(surface, piece.rail_type, piece.placement_direction, piece.position, piece.layer)
end

function mod.TestRampIsDescribedByWhereItClimbs()
   local surface = TestSurface.new()
   local pieces = build(surface, { "up" })
   local desc = describe(surface, pieces[1])
   lu.assertEquals(desc.kind, "ramp-rising-north")
   lu.assertNil(desc.layer)
   -- Connected to the ground rail behind, nothing on top yet
   lu.assertFalse(desc.lonely)
   lu.assertEquals(desc.end_direction, defines.direction.north)
end

function mod.TestElevatedRailConnectsToRampTop()
   local surface = TestSurface.new()
   local pieces = build(surface, { "up", "s", "s" })
   local desc = describe(surface, pieces[2])
   lu.assertEquals(desc.kind, "vertical")
   lu.assertEquals(desc.layer, ELEVATED)
   -- Both ends connected: ramp behind, straight ahead
   lu.assertFalse(desc.lonely)
   lu.assertNil(desc.end_direction)
   -- The ramp now has rails on both ends
   lu.assertNil(describe(surface, pieces[1]).end_direction)
end

function mod.TestGroundRailEndsAtRamp()
   local surface = TestSurface.new()
   build(surface, { "up" })
   local desc = RailDescriber.describe_rail(
      surface,
      RailInfo.RailType.STRAIGHT,
      defines.direction.north,
      { x = 1, y = 1 },
      RailInfo.RailLayer.GROUND
   )
   -- North end continues onto the ramp, south end is open
   lu.assertEquals(desc.end_direction, defines.direction.south)
end

function mod.TestBridgeOverGroundTrackIsNotConnected()
   -- Ground straights under the bridge share positions with elevated straights but are not connected to them
   local surface = TestSurface.new()
   local pieces = build(surface, { "up", "s" })
   local elevated = pieces[2]
   -- A lone ground straight right under the first elevated straight
   surface:add_rail_at(RailInfo.RailType.STRAIGHT, elevated.position, elevated.placement_direction)
   local ground = RailDescriber.describe_rail(
      surface,
      RailInfo.RailType.STRAIGHT,
      elevated.placement_direction,
      elevated.position,
      RailInfo.RailLayer.GROUND
   )
   lu.assertTrue(ground.lonely)
   -- The elevated one keeps its ramp connection and an open end ahead
   local desc = describe(surface, elevated)
   lu.assertFalse(desc.lonely)
   lu.assertEquals(desc.end_direction, defines.direction.north)
end

function mod.TestElevatedTurnIsDescribedLikeGroundTurn()
   -- The same 90 degree turn on the bridge and on the ground get the same names
   local elevated_surface = TestSurface.new()
   local elevated = build(elevated_surface, { "up", "l", "l", "l", "l" })
   local ground_surface = TestSurface.new()
   local ground = build(ground_surface, { "l", "l", "l", "l" })
   for i = 1, 4 do
      local e = describe(elevated_surface, elevated[i + 1])
      local g = describe(ground_surface, ground[i])
      lu.assertStrContains(e.kind, "-turn")
      lu.assertEquals(e.kind, g.kind)
      lu.assertEquals(e.layer, ELEVATED)
   end
end

return mod
