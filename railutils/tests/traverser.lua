local lu = require("luaunit")
require("polyfill")

local Traverser = require("railutils.traverser")
local RailInfo = require("railutils.rail-info")

local mod = {}

function mod.TestTraverser_Creation()
   -- Create a traverser on a straight rail facing north
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   -- Should have a rail type, direction, and position
   lu.assertNotNil(trav:get_rail_kind())
   lu.assertNotNil(trav:get_direction())
   lu.assertNotNil(trav:get_position())

   -- Position should remain as-is (grid adjustment happens after placement, not in Traverser)
   local pos = trav:get_position()
   lu.assertEquals(pos.x, 0)
   lu.assertEquals(pos.y, 0)
end

function mod.TestTraverser_MoveForward()
   -- Start with a straight rail facing north
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   local initial_dir = trav:get_direction()
   local initial_pos = trav:get_position()

   -- Move forward (should place another straight rail in same direction)
   trav:move_forward()

   -- Direction should remain the same when moving straight
   lu.assertEquals(trav:get_direction(), initial_dir)

   -- Rail type should still be straight
   lu.assertEquals(trav:get_rail_kind(), RailInfo.RailType.STRAIGHT)

   -- Position should have changed (either x or y or both)
   local new_pos = trav:get_position()
   lu.assertTrue(
      new_pos.x ~= initial_pos.x or new_pos.y ~= initial_pos.y,
      "Position should change after moving forward"
   )
end

function mod.TestTraverser_TurnRight()
   -- Start with a straight rail facing north
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   local initial_dir = trav:get_direction()

   -- Turn right
   trav:move_right()

   -- Direction should have increased by 1 (mod 16)
   local new_dir = trav:get_direction()
   lu.assertEquals(new_dir, (initial_dir + 1) % 16)

   -- Should have placed a curved rail
   local rail_type = trav:get_rail_kind()
   lu.assertTrue(
      rail_type == RailInfo.RailType.CURVE_A or rail_type == RailInfo.RailType.CURVE_B,
      "Turning should place a curved rail"
   )
end

function mod.TestTraverser_TurnLeft()
   -- Start with a straight rail facing north
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   local initial_dir = trav:get_direction()

   -- Turn left
   trav:move_left()

   -- Direction should have decreased by 1 (mod 16)
   local new_dir = trav:get_direction()
   lu.assertEquals(new_dir, (initial_dir - 1 + 16) % 16)

   -- Should have placed a curved rail
   local rail_type = trav:get_rail_kind()
   lu.assertTrue(
      rail_type == RailInfo.RailType.CURVE_A or rail_type == RailInfo.RailType.CURVE_B,
      "Turning should place a curved rail"
   )
end

function mod.TestTraverser_FlipEnds()
   -- Start with a straight rail facing north
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   local initial_dir = trav:get_direction()
   local initial_pos = trav:get_position()

   -- Flip to the other end
   trav:flip_ends()

   -- Direction should have changed to the opposite end
   local new_dir = trav:get_direction()
   lu.assertNotEquals(new_dir, initial_dir)

   -- Position should remain the same
   local new_pos = trav:get_position()
   lu.assertEquals(new_pos.x, initial_pos.x)
   lu.assertEquals(new_pos.y, initial_pos.y)

   -- Rail type should remain the same
   lu.assertEquals(trav:get_rail_kind(), RailInfo.RailType.STRAIGHT)

   -- For a straight rail, opposite end should be 180 degrees (south direction offset)
   lu.assertEquals(new_dir, (initial_dir + defines.direction.south) % 16)
end

function mod.TestTraverser_GetSignalPos()
   -- Start with a straight rail facing north
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   -- Should be able to get signal positions
   local left_signal = trav:get_signal_pos(Traverser.SignalSide.LEFT)
   local right_signal = trav:get_signal_pos(Traverser.SignalSide.RIGHT)

   lu.assertNotNil(left_signal)
   lu.assertNotNil(right_signal)

   -- Signals should have different positions
   lu.assertTrue(left_signal.x ~= right_signal.x or left_signal.y ~= right_signal.y)
end

function mod.TestTraverser_Movement_Sequence()
   -- Test a sequence of movements
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, defines.direction.north, defines.direction.north)

   -- Move forward 3 times, then turn right, then forward again
   trav:move_forward()
   trav:move_forward()
   trav:move_forward()

   local dir_before_turn = trav:get_direction()

   trav:move_right()

   -- After turning right, direction should have increased
   lu.assertEquals(trav:get_direction(), (dir_before_turn + 1) % 16)

   trav:move_forward()

   -- After moving forward, direction should stay the same
   lu.assertEquals(trav:get_direction(), (dir_before_turn + 1) % 16)
end

function mod.TestTraverser_GetAltSignalPos()
   -- Start with a curved rail which might have alt signals
   -- For CURVE_A, placement=south has end=north
   local trav =
      Traverser.new(RailInfo.RailType.CURVE_A, { x = 0, y = 0 }, defines.direction.south, defines.direction.north)

   -- Alt signal might or might not exist
   local alt_left = trav:get_alt_signal_pos(Traverser.SignalSide.LEFT)
   local alt_right = trav:get_alt_signal_pos(Traverser.SignalSide.RIGHT)

   -- Just verify it doesn't crash and returns nil or a position
   -- (alt signals don't always exist)
   if alt_left then
      lu.assertNotNil(alt_left.x)
      lu.assertNotNil(alt_left.y)
   end

   if alt_right then
      lu.assertNotNil(alt_right.x)
      lu.assertNotNil(alt_right.y)
   end
end

function mod.TestTraverser_DefaultLayerIsGround()
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, defines.direction.north, defines.direction.north)
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.GROUND)
end

function mod.TestTraverser_RampUpAndDown()
   local dirs = defines.direction
   local trav = Traverser.new(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, dirs.north, dirs.north)
   lu.assertTrue(trav:can_change_layer())

   -- Up: a ramp continues from the north end, its top end faces north and is elevated
   trav:move_change_layer()
   lu.assertEquals(trav:get_rail_kind(), RailInfo.RailType.RAMP)
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.ELEVATED)
   lu.assertEquals(trav:get_direction(), dirs.north)
   lu.assertEquals(trav:get_placement_direction(), dirs.north)
   lu.assertEquals(trav:get_position(), { x = 1, y = -8 })

   -- Straight on top of the ramp stays elevated
   trav:move_forward()
   lu.assertEquals(trav:get_rail_kind(), RailInfo.RailType.STRAIGHT)
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.ELEVATED)
   lu.assertEquals(trav:get_direction(), dirs.north)
   lu.assertEquals(trav:get_position(), { x = 1, y = -17 })

   -- Down: the ramp is placed facing the other way and ends on the ground
   lu.assertTrue(trav:can_change_layer())
   trav:move_change_layer()
   lu.assertEquals(trav:get_rail_kind(), RailInfo.RailType.RAMP)
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.GROUND)
   lu.assertEquals(trav:get_direction(), dirs.north)
   lu.assertEquals(trav:get_placement_direction(), dirs.south)

   trav:move_forward()
   lu.assertEquals(trav:get_rail_kind(), RailInfo.RailType.STRAIGHT)
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.GROUND)
   lu.assertEquals(trav:get_direction(), dirs.north)
end

function mod.TestTraverser_NoRampFromDiagonalEnd()
   local dirs = defines.direction
   local trav = Traverser.new(RailInfo.RailType.STRAIGHT, { x = 0, y = 0 }, dirs.northeast, dirs.northeast)
   lu.assertFalse(trav:can_change_layer())
   lu.assertError(function()
      trav:move_change_layer()
   end)
end

function mod.TestTraverser_ElevatedTurnsKeepLayer()
   local dirs = defines.direction
   local trav = Traverser.new(
      RailInfo.RailType.STRAIGHT,
      { x = 1, y = 1 },
      dirs.north,
      dirs.north,
      RailInfo.RailLayer.ELEVATED
   )
   trav:move_left()
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.ELEVATED)
   -- Not a cardinal end any more, so no ramp from here
   lu.assertFalse(trav:can_change_layer())
end

function mod.TestTraverser_FlipOnRampChangesLayer()
   local dirs = defines.direction
   local trav = Traverser.new(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, dirs.north, dirs.north)
   trav:move_change_layer()
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.ELEVATED)
   trav:flip_ends()
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.GROUND)
   lu.assertEquals(trav:get_direction(), dirs.south)
   trav:flip_ends()
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.ELEVATED)
end

function mod.TestTraverser_FlipKeepsLayerOnNormalRail()
   local dirs = defines.direction
   local trav = Traverser.new(
      RailInfo.RailType.STRAIGHT,
      { x = 1, y = 1 },
      dirs.north,
      dirs.north,
      RailInfo.RailLayer.ELEVATED
   )
   trav:flip_ends()
   lu.assertEquals(trav:get_layer(), RailInfo.RailLayer.ELEVATED)
end

function mod.TestTraverser_RampLayerComesFromTheEnd()
   local dirs = defines.direction
   -- A north-facing ramp has its elevated end to the north and its ground end to the south,
   -- whatever layer the caller passes
   local top = Traverser.new(RailInfo.RailType.RAMP, { x = 1, y = 0 }, dirs.north, dirs.north)
   lu.assertEquals(top:get_layer(), RailInfo.RailLayer.ELEVATED)
   local bottom =
      Traverser.new(RailInfo.RailType.RAMP, { x = 1, y = 0 }, dirs.north, dirs.south, RailInfo.RailLayer.ELEVATED)
   lu.assertEquals(bottom:get_layer(), RailInfo.RailLayer.GROUND)
end

function mod.TestTraverser_CloneKeepsLayer()
   local dirs = defines.direction
   local trav = Traverser.new(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, dirs.north, dirs.north)
   trav:move_change_layer()
   local copy = trav:clone()
   lu.assertEquals(copy:get_layer(), RailInfo.RailLayer.ELEVATED)
   trav:flip_ends()
   lu.assertEquals(copy:get_layer(), RailInfo.RailLayer.ELEVATED)
end

return mod
