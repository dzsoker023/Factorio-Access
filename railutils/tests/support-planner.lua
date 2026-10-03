local lu = require("luaunit")
require("polyfill")

local RailInfo = require("railutils.rail-info")
local SupportPlanner = require("railutils.support-planner")
local Traverser = require("railutils.traverser")

local mod = {}

local OPTS = { support_range = 11, ramp_range = 9 }

---Build pieces the way the Syntrax VM does, from a ground straight rail at the origin facing north.
---Words: s, l, r, up, down, sup (support at the far end of the last piece)
local function build(words)
   local trav =
      Traverser.new(RailInfo.RailType.STRAIGHT, { x = 1, y = 1 }, defines.direction.north, defines.direction.north)
   local pieces = {}
   local current = nil
   for _, word in ipairs(words) do
      if word == "sup" then
         pieces[current].explicit_support = true
      else
         local parent_end = trav:get_direction()
         if word == "s" then
            trav:move_forward()
         elseif word == "l" then
            trav:move_left()
         elseif word == "r" then
            trav:move_right()
         elseif word == "up" or word == "down" then
            trav:move_change_layer()
         else
            error("unknown word " .. word)
         end
         table.insert(pieces, {
            rail_type = trav:get_rail_kind(),
            placement_direction = trav:get_placement_direction(),
            position = trav:get_position(),
            end_direction = trav:get_direction(),
            layer = trav:get_layer(),
            parent = current,
            parent_end = current and parent_end or nil,
         })
         current = #pieces
      end
   end
   return pieces
end

local function rep(word, n)
   local out = {}
   for i = 1, n do
      out[i] = word
   end
   return out
end

local function concat(...)
   local out = {}
   for _, list in ipairs({ ... }) do
      for _, w in ipairs(list) do
         table.insert(out, w)
      end
   end
   return out
end

local function support_pieces(supports)
   local out = {}
   for _, s in ipairs(supports) do
      table.insert(out, s.piece)
   end
   return out
end

function mod.TestLengths()
   local pieces = build({ "s", "r", "r" })
   lu.assertAlmostEquals(SupportPlanner.length(pieces[1]), 2, 1e-9)
   -- curved-a then curved-b
   lu.assertTrue(SupportPlanner.length(pieces[2]) > 5.09)
   lu.assertTrue(SupportPlanner.length(pieces[3]) > 5.0)
end

function mod.TestGroundNeedsNothing()
   local supports, problems = SupportPlanner.plan(build(rep("s", 30)), OPTS)
   lu.assertEquals(#supports, 0)
   lu.assertEquals(#problems, 0)
end

function mod.TestRampCarriesFour()
   -- ramp + 4 straights: held by the ramp, no support
   local supports = SupportPlanner.plan(build(concat({ "up" }, rep("s", 4))), OPTS)
   lu.assertEquals(#supports, 0)
end

function mod.TestFifthRailAfterRampNeedsSupportAtItsEnd()
   -- Nothing after the 5th rail, so the support goes at its far end
   local pieces = build(concat({ "up" }, rep("s", 5)))
   local supports = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(support_pieces(supports), { 6 })
   lu.assertEquals(supports[1].direction, defines.direction.north)
   lu.assertEquals(supports[1].position, SupportPlanner.end_position(pieces[6], pieces[6].end_direction))
end

function mod.TestRampEightRampNeedsNone()
   -- 4 held by each ramp
   local supports = SupportPlanner.plan(build(concat({ "up" }, rep("s", 8), { "down" })), OPTS)
   lu.assertEquals(#supports, 0)
end

function mod.TestRampNineRampNeedsOne()
   local supports = SupportPlanner.plan(build(concat({ "up" }, rep("s", 9), { "down" })), OPTS)
   lu.assertEquals(#supports, 1)
end

function mod.TestRampTwentyRamp()
   -- Pieces: 1 ramp, 2..21 straights, 22 ramp. Two supports, spread evenly between the ramp tops: after s7 and s13
   -- (pieces 8 and 14), so the gaps are 7, 6 and 7 rails.
   local supports, problems = SupportPlanner.plan(build(concat({ "up" }, rep("s", 20), { "down" })), OPTS)
   lu.assertEquals(support_pieces(supports), { 8, 14 })
   lu.assertEquals(#problems, 0)
end

function mod.TestRampTenRampIsSymmetric()
   -- One support in the middle: 5 rails on each side
   local supports = SupportPlanner.plan(build(concat({ "up" }, rep("s", 10), { "down" })), OPTS)
   lu.assertEquals(support_pieces(supports), { 6 })
end

function mod.TestLongRunSpacing()
   -- After the first support at s9, each next support is 10 rails further
   local supports = SupportPlanner.plan(build(concat({ "up" }, rep("s", 40))), OPTS)
   lu.assertEquals(support_pieces(supports), { 10, 20, 30, 40 })
end

function mod.TestExplicitSupportIsUsed()
   -- A support the user placed at s7 holds s5..s7 from the front and s8..s12 behind
   local pieces = build(concat({ "up" }, rep("s", 7), { "sup" }, rep("s", 5)))
   local supports = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(#supports, 0)
end

function mod.TestExplicitSupportTooFarIsNotEnough()
   -- s5 is 12 track units from a support at s10: too far, a planned one is needed. It goes halfway between the ramp
   -- top and the explicit support: after s5 (piece 6).
   local pieces = build(concat({ "up" }, rep("s", 10), { "sup" }))
   local supports = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(support_pieces(supports), { 6 })
end

function mod.TestCurvesAfterRamp()
   -- The ramp holds one curved-a; the next curve (curved-b) needs a support
   local pieces = build({ "up", "r", "r" })
   local supports, problems = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(#problems, 0)
   lu.assertEquals(#supports, 1)
   -- curved-b ends on a diagonal, which can hold a support
   lu.assertEquals(supports[1].piece, 3)
   lu.assertEquals(supports[1].direction % 2, 0)
end

function mod.TestSupportNeverOnHalfDiagonalEnd()
   -- up, then a right curve and a long stretch of track: every support sits on an 8-way end
   local pieces = build(concat({ "up" }, rep("s", 4), { "r", "r", "r", "r" }, rep("s", 6)))
   local supports, problems = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(#problems, 0)
   for _, s in ipairs(supports) do
      lu.assertEquals(s.direction % 2, 0)
   end
end

function mod.TestBranchesGetSupported()
   -- Fork after the ramp: two branches of 6 straights each, written by hand
   local pieces = build(concat({ "up" }, rep("s", 6)))
   local branch = build(concat({ "up" }, rep("s", 6)))
   -- Second branch reuses pieces 2..7 shifted as children of the ramp: emulate by duplicating the chain
   local offset = #pieces
   for i = 2, #branch do
      local p = branch[i]
      p.parent = p.parent == 1 and 1 or p.parent + offset - 1
      table.insert(pieces, p)
   end
   local supports, problems = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(#problems, 0)
   -- The fork is at the ramp, so each branch needs its own support
   lu.assertEquals(#supports, 2)
end

function mod.TestStartReach()
   -- Starting on elevated track with reach 11 (standing on a support): 5 rails fine, the 6th is not
   local trav = Traverser.new(
      RailInfo.RailType.STRAIGHT,
      { x = 1, y = 1 },
      defines.direction.north,
      defines.direction.north,
      RailInfo.RailLayer.ELEVATED
   )
   local pieces = {}
   for i = 1, 6 do
      local parent_end = trav:get_direction()
      trav:move_forward()
      table.insert(pieces, {
         rail_type = trav:get_rail_kind(),
         placement_direction = trav:get_placement_direction(),
         position = trav:get_position(),
         end_direction = trav:get_direction(),
         layer = trav:get_layer(),
         parent = i > 1 and i - 1 or nil,
         parent_end = i > 1 and parent_end or nil,
      })
   end
   local opts = { support_range = 11, ramp_range = 9, start_reach = 11 }
   lu.assertEquals(support_pieces(SupportPlanner.plan({ table.unpack(pieces, 1, 5) }, opts)), {})
   lu.assertEquals(support_pieces(SupportPlanner.plan(pieces, opts)), { 6 })
end

---Check a plan against the engine rule on a single unbranched chain: every elevated rail must have an anchor (ramp
---top or support at a rail end) with the distance along the track to its far end within the anchor's range.
local function assert_chain_held(pieces, supports)
   local anchors = {}
   local pos = 0
   local starts, ends = {}, {}
   local support_at = {}
   for _, s in ipairs(supports) do
      support_at[s.piece] = true
   end
   for i, p in ipairs(pieces) do
      starts[i] = pos
      pos = pos + SupportPlanner.length(p)
      ends[i] = pos
      if p.rail_type == RailInfo.RailType.RAMP then
         if p.layer == RailInfo.RailLayer.ELEVATED then
            table.insert(anchors, { at = ends[i], range = OPTS.ramp_range })
         else
            table.insert(anchors, { at = starts[i], range = OPTS.ramp_range })
         end
      end
      if support_at[i] or p.explicit_support then
         table.insert(anchors, { at = ends[i], range = OPTS.support_range })
      end
   end
   for i, p in ipairs(pieces) do
      if p.rail_type ~= RailInfo.RailType.RAMP and p.layer == RailInfo.RailLayer.ELEVATED then
         local ok = false
         for _, a in ipairs(anchors) do
            if a.at >= ends[i] - 1e-6 and a.at - starts[i] <= a.range + 1e-6 then ok = true end
            if a.at <= starts[i] + 1e-6 and ends[i] - a.at <= a.range + 1e-6 then ok = true end
         end
         lu.assertTrue(ok, "piece " .. i .. " is not held")
      end
   end
end

function mod.TestRandomBridgesAreHeld()
   -- Pseudo-random bridges of straights and 45 degree turns (which end on 8-way ends), down at the end when the last
   -- end is cardinal
   local seed = 12345
   local function rand(n)
      seed = (seed * 1103515245 + 12345) % 2147483648
      return seed % n
   end
   local moves = { { "s" }, { "s" }, { "s" }, { "l", "l" }, { "r", "r" } }
   for _ = 1, 300 do
      local words = { "up" }
      for _ = 1, 4 + rand(40) do
         for _, w in ipairs(moves[rand(#moves) + 1]) do
            table.insert(words, w)
         end
      end
      local pieces = build(words)
      if pieces[#pieces].end_direction % 4 == 0 and rand(2) == 0 then pieces = build(concat(words, { "down" })) end
      local supports, problems = SupportPlanner.plan(pieces, OPTS)
      lu.assertEquals(#problems, 0, table.concat(words, " "))
      assert_chain_held(pieces, supports)
   end
end

function mod.TestLongHalfDiagonalRunHasNoSpot()
   -- Half-diagonal track has only 16-way ends, where a support cannot stand
   local _, problems = SupportPlanner.plan(build({ "up", "s", "l", "s", "s", "s", "s" }), OPTS)
   lu.assertTrue(#problems >= 1)
   lu.assertEquals(problems[1].reason, "no-spot")
end

function mod.TestForbiddenSpotMovesTheSupport()
   -- ramp + 10 + ramp puts its support after s5 (piece 6); forbid that end and it goes elsewhere
   local pieces = build(concat({ "up" }, rep("s", 10), { "down" }))
   pieces[6].forbid_support = true
   local supports, problems = SupportPlanner.plan(pieces, OPTS)
   lu.assertEquals(#problems, 0)
   lu.assertEquals(#supports, 1)
   lu.assertNotEquals(supports[1].piece, 6)
   assert_chain_held(pieces, supports)
end

function mod.TestAllSpotsForbiddenIsReported()
   local pieces = build(concat({ "up" }, rep("s", 12), { "down" }))
   for i = 2, 13 do
      pieces[i].forbid_support = true
   end
   local _, problems = SupportPlanner.plan(pieces, OPTS)
   lu.assertTrue(#problems >= 1)
   lu.assertEquals(problems[1].reason, "forbidden")
end

function mod.TestEvenNeverUsesMoreSupportsThanGreedy()
   for n = 1, 60 do
      local supports = SupportPlanner.plan(build(concat({ "up" }, rep("s", n), { "down" })), OPTS)
      -- 4 rails held by each ramp, 10 more per support
      local needed = math.max(0, math.ceil((n - 8) / 10))
      lu.assertEquals(#supports, needed, "n = " .. n)
   end
end

return mod
