---Support Planner
---
---Decides where rail supports go under a planned run of elevated rails. Pure: works on a list of pieces, not on a
---surface, so it can be tested offline.
---
---# The engine rule (measured with /elevprobe, see ELEVATED_RAILS_TERV_REVIEW.md)
---
---An elevated rail can be built only if it connects through built track to an anchor, and the distance along the track
---from the anchor to the far end of the rail is at most the anchor's range. Anchors are rail supports (range 11 in
---vanilla) and the elevated end of a ramp (range 9). A support only counts when it stands at a rail end facing along
---the track, and it reaches both ways. Supports are 8-directional, so they cannot stand at the 16-way ends that half
---diagonals and curves have.
---
---Pieces are built as ghosts and revived repeatedly until nothing more revives, so a support may sit ahead of the rails
---it holds: rails behind it get built backwards from it.
---
---# The plan
---
---Pieces are visited in order. An elevated piece is fine if what is left of the reach behind it covers its length.
---Otherwise the planner looks ahead along the unbranched track starting at that piece and:
---- does nothing if a down ramp or an explicit support ahead is close enough to hold it from the front,
---- else places one support as far ahead as it can while still holding the piece (furthest end within support range
---  that a support can stand on).
---This is greedy and gives the fewest supports on a straight run: up to 9 rails after a ramp and 10 rails between two
---supports.

require("polyfill")

local RailData = require("railutils.rail-data")
local RailInfo = require("railutils.rail-info")
local Queries = require("railutils.queries")

local mod = {}

---Curves are a little longer than the straight line between their ends. Overestimating only costs a support.
local CURVE_LENGTH_FACTOR = 1.0065

---Reach comparisons are on sums of square roots
local EPSILON = 1e-6

---@class railutils.SupportPlanner.Piece
---@field rail_type railutils.RailType
---@field placement_direction defines.direction
---@field position fa.Point Grid-adjusted position
---@field end_direction defines.direction Direction of the far end (the end the track continues from)
---@field layer railutils.RailLayer Layer of the far end. For a ramp: elevated going up, ground going down.
---@field parent integer? Index of the piece this one continues from, nil for the first piece
---@field parent_end defines.direction? Which end of the parent it continues from
---@field explicit_support boolean? The user asked for a support at the far end
---@field forbid_support boolean? The planner must not put a support at the far end (nosup, or autosup off)

---@class railutils.SupportPlanner.Opts
---@field support_range number
---@field ramp_range number
---@field start_reach number? Reach left at the start of the first piece, if the run starts on elevated track

---@class railutils.SupportPlanner.Support
---@field piece integer Index of the piece whose far end gets the support
---@field position fa.Point
---@field direction defines.direction

---@class railutils.SupportPlanner.Problem
---@field piece integer
---@field reason "no-spot"|"forbidden" No end within range can take a support; "forbidden" if one could, but the
---program ruled it out (nosup or autosup off)

---@param piece railutils.SupportPlanner.Piece
---@return table
local function entry_of(piece)
   local prototype = Queries.rail_type_to_prototype_type(piece.rail_type)
   return RailData[prototype][piece.placement_direction]
end

---Absolute position of one end of a piece
---@param piece railutils.SupportPlanner.Piece
---@param end_direction defines.direction
---@return fa.Point
function mod.end_position(piece, end_direction)
   local end_data = entry_of(piece)[end_direction]
   if not end_data then error("Invalid end direction " .. tostring(end_direction) .. " for " .. piece.rail_type) end
   return { x = piece.position.x + end_data.position.x, y = piece.position.y + end_data.position.y }
end

---Track length of a piece, for comparing with support ranges
---@param piece railutils.SupportPlanner.Piece
---@return number
function mod.length(piece)
   local ends = Queries.get_end_directions(piece.rail_type, piece.placement_direction)
   local a = mod.end_position(piece, ends[1])
   local b = mod.end_position(piece, ends[2])
   local chord = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
   if piece.rail_type == RailInfo.RailType.CURVE_A or piece.rail_type == RailInfo.RailType.CURVE_B then
      return chord * CURVE_LENGTH_FACTOR
   end
   return chord
end

---Whether a support can stand at the far end of a piece
---@param piece railutils.SupportPlanner.Piece
---@return boolean
local function can_stand_support(piece)
   return piece.end_direction % 2 == 0
end

---Whether the planner may put a support at the far end of a piece
---@param piece railutils.SupportPlanner.Piece
---@return boolean
local function can_hold_support(piece)
   return can_stand_support(piece) and not piece.forbid_support
end

---@param piece railutils.SupportPlanner.Piece
local function is_ramp(piece)
   return piece.rail_type == RailInfo.RailType.RAMP
end

---@param piece railutils.SupportPlanner.Piece
local function is_elevated_rail(piece)
   return not is_ramp(piece) and piece.layer == RailInfo.RailLayer.ELEVATED
end

---Plan supports for a list of pieces
---@param pieces railutils.SupportPlanner.Piece[]
---@param opts railutils.SupportPlanner.Opts
---@return railutils.SupportPlanner.Support[] supports In piece order
---@return railutils.SupportPlanner.Problem[] problems
function mod.plan(pieces, opts)
   local support_range = opts.support_range
   local ramp_range = opts.ramp_range

   -- Children that continue from the far end. Anything else (a flip back onto a near end) is not a chain.
   local children = {}
   for i, piece in ipairs(pieces) do
      local parent = piece.parent and pieces[piece.parent]
      if parent and piece.parent_end == parent.end_direction then
         children[piece.parent] = children[piece.parent] or {}
         table.insert(children[piece.parent], i)
      end
   end

   local lengths = {}
   for i, piece in ipairs(pieces) do
      lengths[i] = mod.length(piece)
   end

   -- reach[i]: how much further track the anchors behind can hold, measured from the far end of piece i
   local reach = {}
   -- covered[i]: held from the front by a ramp or support ahead, found while looking ahead
   local covered = {}
   -- anchor[i]: a support stands at the far end of piece i (planned or explicit)
   local anchor = {}
   for i, piece in ipairs(pieces) do
      if piece.explicit_support then anchor[i] = true end
   end

   -- back[i]: track distance from the far end of piece i back to the anchor behind it
   local back = {}

   local supports = {}
   local problems = {}

   ---Reach at the start of a piece
   local function incoming_reach(i)
      local piece = pieces[i]
      if not piece.parent then return opts.start_reach or 0 end
      local parent = pieces[piece.parent]
      -- From a near end we would have to know the reach behind the parent; assume none
      if piece.parent_end ~= parent.end_direction then return 0 end
      return reach[piece.parent] or 0
   end

   ---Unbranched elevated rails starting at i, and what ends the run
   ---@return integer[] chain, integer? next_piece
   local function chain_from(i)
      local chain = { i }
      local current = i
      while true do
         local kids = children[current]
         if not kids or #kids ~= 1 then return chain, nil end
         local next_piece = kids[1]
         if not is_elevated_rail(pieces[next_piece]) then return chain, next_piece end
         table.insert(chain, next_piece)
         current = next_piece
      end
   end

   ---Distance back from the start of a piece to the anchor behind it, 0 if unknown
   local function incoming_back(i)
      local piece = pieces[i]
      if not piece.parent then return 0 end
      local parent = pieces[piece.parent]
      if piece.parent_end ~= parent.end_direction then return 0 end
      return back[piece.parent] or 0
   end

   ---Supports for a run of pieces, as indices into the run. cum[k] is the distance from the start of the run to the far
   ---end of its k-th piece; end_range is the range of the anchor at the end of the run (nil for an open run).
   ---Greedy: each support as far ahead as it can stand while still holding the first piece nobody holds.
   ---@return integer[]? picks nil if some piece has no spot
   ---@return integer? failed_at
   ---@return ("no-spot"|"forbidden")? reason
   local function greedy_picks(run, cum, end_range)
      local total = cum[#run]
      local picks = {}
      local k = 1
      while k <= #run do
         local start = k > 1 and cum[k - 1] or 0
         if end_range and total - start <= end_range + EPSILON then break end
         local best = nil
         local forbidden = false
         for q = k, #run do
            if cum[q] - start > support_range + EPSILON then break end
            if can_hold_support(pieces[run[q]]) then
               best = q
            elseif can_stand_support(pieces[run[q]]) then
               forbidden = true
            end
         end
         if not best then return nil, k, forbidden and "forbidden" or "no-spot" end
         table.insert(picks, best)
         k = best + 1
         while k <= #run and cum[k] - cum[best] <= support_range + EPSILON do
            k = k + 1
         end
      end
      return picks
   end

   ---Whether every piece of a run is held by the picks or the anchor at its end
   local function holds_all(run, cum, end_range, picks)
      local total = cum[#run]
      for k = 1, #run do
         local start = k > 1 and cum[k - 1] or 0
         local ok = end_range ~= nil and total - start <= end_range + EPSILON
         for _, q in ipairs(picks) do
            if ok then break end
            if q >= k and cum[q] - start <= support_range + EPSILON then ok = true end
            if q < k and cum[k] - cum[q] <= support_range + EPSILON then ok = true end
         end
         if not ok then return false end
      end
      return true
   end

   ---The same number of supports as greedy, spread evenly between the anchor behind the run (offset behind its start)
   ---and the anchor at its end. Nil if the even spots do not hold everything.
   local function even_picks(run, cum, end_range, count, offset)
      local span = offset + cum[#run]
      local picks = {}
      local previous = 0
      for j = 1, count do
         local target = span * j / (count + 1) - offset
         local best, best_diff = nil, math.huge
         for q = previous + 1, #run do
            local diff = math.abs(cum[q] - target)
            if can_hold_support(pieces[run[q]]) and diff < best_diff - EPSILON then
               best, best_diff = q, diff
            end
         end
         if not best then return nil end
         table.insert(picks, best)
         previous = best
      end
      if holds_all(run, cum, end_range, picks) then return picks end
      return nil
   end

   ---Look ahead from an uncovered piece and hold it. A run closed by a down ramp or a support the program placed gets
   ---its supports spread evenly; an open run (the track may go on later) gets them as far ahead as possible, so the
   ---last one is useful for whatever is built next.
   local function hold_from_front(i)
      local chain, after = chain_from(i)

      local run = {}
      local end_range = nil
      for _, idx in ipairs(chain) do
         table.insert(run, idx)
         if anchor[idx] then
            end_range = support_range
            break
         end
      end
      if not end_range and after and is_ramp(pieces[after]) and pieces[after].layer == RailInfo.RailLayer.GROUND then
         end_range = ramp_range
      end

      local cum = {}
      local total = 0
      for k, idx in ipairs(run) do
         total = total + lengths[idx]
         cum[k] = total
      end

      local picks, failed_at, reason = greedy_picks(run, cum, end_range)
      if not picks then
         table.insert(problems, { piece = run[failed_at], reason = reason })
         covered[i] = true
         return
      end

      if not end_range then
         -- Open run: only the first support is placed now, the rest of the chain is planned as it comes
         picks = { picks[1] }
         local first = picks[1]
         for m = 1, first do
            covered[run[m]] = true
         end
      else
         if #picks > 0 then
            picks = even_picks(run, cum, end_range, #picks, incoming_back(i)) or picks
         end
         for _, idx in ipairs(run) do
            covered[idx] = true
         end
      end

      for _, q in ipairs(picks) do
         local target = run[q]
         anchor[target] = true
         local piece = pieces[target]
         table.insert(supports, {
            piece = target,
            position = mod.end_position(piece, piece.end_direction),
            direction = piece.end_direction,
         })
      end
   end

   for i, piece in ipairs(pieces) do
      if is_ramp(piece) then
         -- Going up, the top of the ramp is an anchor. Going down, the ramp ends on the ground.
         reach[i] = piece.layer == RailInfo.RailLayer.ELEVATED and ramp_range or nil
         back[i] = 0
      elseif piece.layer == RailInfo.RailLayer.ELEVATED then
         local left = incoming_reach(i) - lengths[i]
         if left < -EPSILON and not covered[i] then hold_from_front(i) end
         if anchor[i] then
            reach[i] = support_range
            back[i] = 0
         else
            -- Pieces held from the front have nothing left behind them
            reach[i] = math.max(left, 0)
            back[i] = incoming_back(i) + lengths[i]
         end
      end
   end

   table.sort(supports, function(a, b)
      return a.piece < b.piece
   end)
   return supports, problems
end

return mod
