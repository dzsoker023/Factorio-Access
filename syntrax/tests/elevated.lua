local lu = require("luaunit")
require("polyfill")

local Lexer = require("syntrax.lexer")
local Syntrax = require("syntrax")
local helpers = require("syntrax.tests.helpers")

local mod = {}

local SUPPORT_OPTS = { support = { support_range = 11, ramp_range = 9 } }

---@return syntrax.vm.Placement[]
local function run(source, opts)
   local groups, err = Syntrax.execute(source, nil, nil, nil, nil, opts)
   if err then lu.fail(string.format("%s: %s", source, err.message)) end
   assert(groups)
   return helpers.flatten_placements(groups)
end

local function run_fails(source, pattern, opts)
   local groups, err = Syntrax.execute(source, nil, nil, nil, nil, opts)
   lu.assertNil(groups)
   assert(err)
   lu.assertEquals(err.code, "runtime_error")
   lu.assertStrContains(err.message, pattern)
end

local function count(placements, kind)
   local n = 0
   for _, p in ipairs(placements) do
      if p.type == kind then n = n + 1 end
   end
   return n
end

local function token_types(source)
   local tokens = assert(Lexer.tokenize(source))
   local out = {}
   for _, t in ipairs(tokens) do
      table.insert(out, t.type)
   end
   return out
end

function mod.TestLexerWords()
   lu.assertEquals(token_types("up down elev sup"), { "up", "down", "elev", "sup" })
   lu.assertEquals(token_types("u d"), { "up", "down" })
end

function mod.TestLexerChords()
   lu.assertEquals(token_types("usx3d"), { "up", "s", "x", "number", "down" })
end

function mod.TestUpPlacesRampAndElevatedRails()
   local p = run("up s s")
   lu.assertEquals(#p, 3)
   lu.assertEquals(p[1].rail_type, "rail-ramp")
   lu.assertEquals(p[1].layer, "elevated")
   lu.assertEquals(p[2].rail_type, "straight-rail")
   lu.assertEquals(p[2].layer, "elevated")
   lu.assertEquals(p[3].layer, "elevated")
end

function mod.TestGroundRailsHaveGroundLayer()
   local p = run("s l")
   lu.assertEquals(p[1].layer, "ground")
   lu.assertEquals(p[2].layer, "ground")
end

function mod.TestDownReturnsToGround()
   local p = run("u s d s")
   lu.assertEquals(p[3].rail_type, "rail-ramp")
   lu.assertEquals(p[3].layer, "ground")
   lu.assertEquals(p[4].layer, "ground")
end

function mod.TestElevToggles()
   local p = run("elev s elev s")
   lu.assertEquals(p[1].layer, "elevated")
   lu.assertEquals(p[3].layer, "ground")
end

function mod.TestUpTwiceFails()
   run_fails("up s up", "Already on the elevated layer")
end

function mod.TestDownOnGroundFails()
   run_fails("down", "Already on the ground layer")
end

function mod.TestRampFromDiagonalFails()
   run_fails("r up", "A ramp can only start from a north, east, south or west end")
end

function mod.TestResetReturnsToGround()
   -- The mark is on the ground; after reset the next ramp goes up again
   local p = run("m up s ; up s")
   lu.assertEquals(count(p, "rail"), 2 + 0)
   -- The second up is the same ramp and the same rail, so both are deduplicated
   lu.assertEquals(p[1].rail_type, "rail-ramp")
end

function mod.TestBridgeOverGroundTrackIsNotDeduplicated()
   -- The ramp is 8 straights long, so the 9th ground straight shares position and direction with the first elevated
   -- one. Both are kept.
   local p = run("m up s ; s x 9")
   lu.assertEquals(count(p, "rail"), 11)
   lu.assertEquals(p[2].position, p[11].position)
   lu.assertEquals(p[2].placement_direction, p[11].placement_direction)
   lu.assertEquals(p[11].layer, "ground")
end

function mod.TestExplicitSupport()
   local p = run("up s x 5 sup")
   lu.assertEquals(count(p, "support"), 1)
   local support = p[#p]
   lu.assertEquals(support.type, "support")
   lu.assertTrue(support.explicit)
   lu.assertEquals(support.direction, defines.direction.north)
end

function mod.TestSupportOnGroundFails()
   run_fails("s sup", "this end is on the ground")
end

function mod.TestSupportOnHalfDiagonalEndFails()
   -- A right turn ends facing north-northeast
   run_fails("up r sup", "only at 8-way ends")
end

function mod.TestSignalOnRampFails()
   run_fails("up sig", "Signals cannot be placed on a ramp")
end

function mod.TestSignalsCarryLayer()
   local p = run("up s sig")
   lu.assertEquals(p[3].type, "signal")
   lu.assertEquals(p[3].layer, "elevated")
   lu.assertEquals(p[4].layer, "elevated")
end

function mod.TestNoPlannerWithoutOpts()
   local p = run("up s x 20 down")
   lu.assertEquals(count(p, "support"), 0)
end

function mod.TestPlannerAddsSupports()
   local p = run("up s x 20 down", SUPPORT_OPTS)
   lu.assertEquals(count(p, "support"), 2)
   -- Each planned support comes right after the rail it stands at. Spread evenly between the ramp tops: after the
   -- 7th and 13th straight.
   lu.assertEquals(p[9].type, "support")
   lu.assertFalse(p[9].explicit)
   lu.assertEquals(p[16].type, "support")
end

function mod.TestPlannerShortBridgeNeedsNone()
   local p = run("up s x 8 down", SUPPORT_OPTS)
   lu.assertEquals(count(p, "support"), 0)
end

function mod.TestPlannerUsesExplicitSupport()
   local p = run("up s x 7 sup s x 5", SUPPORT_OPTS)
   lu.assertEquals(count(p, "support"), 1)
end

function mod.TestPlannerStartsElevated()
   -- Starting on elevated track with nothing known behind it: the first stretch needs its own support
   local opts = { initial_layer = "elevated", support = { support_range = 11, ramp_range = 9 } }
   local p = run("s x 5", opts)
   lu.assertEquals(count(p, "support"), 1)
   -- sup on the starting rail makes it an anchor
   p = run("sup s x 5", opts)
   lu.assertEquals(count(p, "support"), 1)
   lu.assertTrue(p[1].explicit)
end

function mod.TestPlannerBranches()
   -- Fork on the bridge: rpush/rpop keep the piece, both branches get held
   local p = run("up s x 4 rpush l45 s x 6 rpop r45 s x 6", SUPPORT_OPTS)
   lu.assertTrue(count(p, "support") >= 2)
end

function mod.TestLexerSupportSwitches()
   lu.assertEquals(token_types("nosup autosup off"), { "nosup", "autosup", "identifier" })
end

function mod.TestNosupMovesTheSupport()
   -- up s x 10 down puts its support after the 5th straight (placement 7: ramp, s1..s5, support)
   local p = run("up s x 5 nosup s x 5 down", SUPPORT_OPTS)
   lu.assertEquals(count(p, "support"), 1)
   lu.assertNotEquals(p[7].type, "support")
end

function mod.TestAutosupOffNeedsExplicitSupports()
   run_fails("up autosup off s x 12 down", "ruled out by nosup or autosup off", SUPPORT_OPTS)
   -- With the support written by hand it builds, and Syntrax adds nothing
   local p = run("up autosup off s x 6 sup s x 6 down", SUPPORT_OPTS)
   lu.assertEquals(count(p, "support"), 1)
   lu.assertTrue(p[8].explicit)
end

function mod.TestAutosupOnAgain()
   -- Off for the first stretch, on for the rest: the planner only uses the second stretch
   local p = run("up autosup off s x 4 autosup on s x 8 down", SUPPORT_OPTS)
   lu.assertEquals(count(p, "support"), 1)
end

function mod.TestAutosupNeedsOnOrOff()
   local groups, err = Syntrax.execute("autosup maybe")
   lu.assertNil(groups)
   assert(err)
   lu.assertEquals(err.code, "unexpected_token")
   lu.assertStrContains(err.message, "Expected on or off")
end

function mod.TestNosupOnGroundFails()
   run_fails("s nosup", "only means something on elevated rails")
end

return mod
