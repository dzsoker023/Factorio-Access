--[[
Virtual Machine for Syntrax language.

Executes bytecode to produce a list of rail placements with positions.
Uses railutils.Traverser for computing rail geometry.
]]

require("polyfill")

local Directions = require("syntrax.directions")
local Errors = require("syntrax.errors")
local Traverser = require("railutils.traverser")
local RailInfo = require("railutils.rail-info")
local SupportPlanner = require("railutils.support-planner")

local mod = {}

---@enum syntrax.vm.OperandKind
mod.OPERAND_KIND = {
   VALUE = "value",
   REGISTER = "register",
   MATH_OP = "math_op",
}

---@enum syntrax.vm.ValueType
mod.VALUE_TYPE = {
   NUMBER = "number",
}

---@enum syntrax.vm.BytecodeKind
mod.BYTECODE_KIND = {
   LEFT = "left",
   RIGHT = "right",
   STRAIGHT = "straight",
   FLIP = "flip",
   JNZ = "jnz",
   MATH = "math",
   MOV = "mov",
   RPUSH = "rpush",
   RPOP = "rpop",
   RESET = "reset",
   MARK = "mark",
   -- Signal commands
   SIGLEFT = "sigleft",
   SIGRIGHT = "sigright",
   CHAINLEFT = "chainleft",
   CHAINRIGHT = "chainright",
   SIG = "sig",
   CHAIN = "chain",
   SIGCHAIN = "sigchain",
   CHAINSIG = "chainsig",
   -- Elevated rails
   UP = "up",
   DOWN = "down",
   ELEV = "elev",
   SUP = "sup",
   NOSUP = "nosup",
   AUTOSUP = "autosup",
}

---@enum syntrax.vm.MathOp
mod.MATH_OP = {
   ADD = "+",
   SUB = "-",
   MUL = "*",
   DIV = "/",
}

---@enum syntrax.vm.RailKind
mod.RAIL_KIND = {
   LEFT = "left",
   RIGHT = "right",
   STRAIGHT = "straight",
   -- A ramp to the other layer
   CHANGE_LAYER = "change_layer",
}

---@class syntrax.vm.Operand
---@field kind syntrax.vm.OperandKind
---@field type syntrax.vm.ValueType? Only present for values
---@field argument number|string Register index, literal value, or operation string

---@class syntrax.vm.Bytecode
---@field kind syntrax.vm.BytecodeKind
---@field arguments syntrax.vm.Operand[]
---@field span syntrax.Span? Optional span for error reporting

---@class syntrax.vm.RailPlacement
---@field type "rail" Discriminator for placement type
---@field position fa.Point Position where the rail should be placed
---@field rail_type string "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail" or "rail-ramp"
---@field placement_direction number 0-15 direction for placement
---@field layer railutils.RailLayer Layer of the rail. For a ramp, the layer it leads to.
---@field span syntrax.Span? Source span for error reporting

---@class syntrax.vm.SupportPlacement
---@field type "support" Discriminator for placement type
---@field position fa.Point Rail end the support stands at
---@field direction number 0-15, even: supports face along the track
---@field explicit boolean True if the program asked for it with sup, false if the support planner added it
---@field span syntrax.Span? Source span for error reporting

---@class syntrax.vm.SignalPlacement
---@field type "signal" Discriminator for placement type
---@field position fa.Point Position where the signal should be placed
---@field signal_type "rail-signal"|"rail-chain-signal" Type of signal to place
---@field direction number 0-15 direction for placement
---@field layer railutils.RailLayer Layer of the rail the signal guards
---@field span syntrax.Span? Source span for error reporting

---@alias syntrax.vm.Placement syntrax.vm.RailPlacement|syntrax.vm.SignalPlacement|syntrax.vm.SupportPlacement
---@alias syntrax.vm.PlacementGroup syntrax.vm.Placement[][] Array of alternatives, each alternative is an array of placements

---@class syntrax.vm.RailStackEntry
---@field traverser railutils.Traverser Cloned traverser state
---@field piece integer? The piece the traverser was on

---@class syntrax.vm.SupportOpts
---@field support_range number Range of a rail support, from its prototype
---@field ramp_range number Range of a ramp, from its prototype
---@field start_reach number? Reach left at the starting end, if it is elevated. Defaults to 0.

---@class syntrax.vm.RunOpts
---@field initial_layer railutils.RailLayer? Layer of the starting rail, ground if omitted
---@field support syntrax.vm.SupportOpts? Plan supports under elevated rails. Without it only sup places supports.

---@class syntrax.vm.Piece: railutils.SupportPlanner.Piece
---@field group integer Index of the piece's group in placements
---@field span syntrax.Span?

---@class syntrax.vm.State
---@field registers table<number, syntrax.vm.Operand> Array of registers
---@field bytecode syntrax.vm.Bytecode[] Array of bytecode instructions
---@field placements syntrax.vm.PlacementGroup[] Output list of placement groups (each group has alternatives)
---@field pc number Program counter
---@field traverser railutils.Traverser? Current traverser (nil until first rail)
---@field position_to_index table<string, number> Position key to rail index for dedup
---@field rail_stack syntrax.vm.RailStackEntry[] Stack of saved traverser states
---@field initial_traverser railutils.Traverser? Initial traverser for reset
---@field mark_traverser railutils.Traverser? Current mark position (reset jumps here)
---@field pieces syntrax.vm.Piece[] Every rail placed, in order, with how they connect (for the support planner)
---@field current_piece integer? The piece the traverser is on, nil while on the starting rail
---@field mark_piece integer? The piece the mark is on
---@field support_keys table<string, boolean> Positions that already have a support
---@field start_support boolean sup was used on the starting rail
---@field autosup boolean Whether the support planner may put supports under rails placed now (autosup on/off)
local VM = {}
local VM_meta = { __index = VM }

---Create a key for deduplication (position + direction + rail type + layer). A ground and an elevated rail can share
---position and direction (track under a bridge), so the layer is part of the key.
---@param pos fa.Point
---@param direction number|defines.direction
---@param rail_type string
---@param layer string
---@return string
local function dedup_key(pos, direction, rail_type, layer)
   return string.format("%d,%d,%d,%s,%s", pos.x, pos.y, direction, rail_type, layer)
end

---@param pos fa.Point
---@return string
local function support_key(pos)
   return string.format("%s,%s", pos.x, pos.y)
end

---@return syntrax.vm.State
function mod.new()
   return setmetatable({
      registers = {},
      bytecode = {},
      placements = {},
      pc = 1,
      traverser = nil, -- Initialized on first rail or via run()
      position_to_index = {},
      rail_stack = {},
      initial_traverser = nil,
      mark_traverser = nil,
      pieces = {},
      current_piece = nil,
      mark_piece = nil,
      support_keys = {},
      start_support = false,
      autosup = true,
   }, VM_meta)
end

-- Helper to create operands
function mod.value(type, value)
   return {
      kind = mod.OPERAND_KIND.VALUE,
      type = type,
      argument = value,
   }
end

function mod.register(index)
   return {
      kind = mod.OPERAND_KIND.REGISTER,
      argument = index,
   }
end

function mod.math_op(op)
   return {
      kind = mod.OPERAND_KIND.MATH_OP,
      argument = op,
   }
end

-- Helper to create bytecode
function mod.bytecode(kind, ...)
   return {
      kind = kind,
      arguments = { ... },
   }
end

---@param operand syntrax.vm.Operand
---@return syntrax.vm.Operand
function VM:resolve_operand(operand)
   if operand.kind == mod.OPERAND_KIND.VALUE then
      return operand
   elseif operand.kind == mod.OPERAND_KIND.REGISTER then
      local value = self.registers[operand.argument]
      if not value then error(string.format("Register r%d not initialized", operand.argument)) end
      if value.kind == mod.OPERAND_KIND.REGISTER then error("Register contains another register reference") end
      return value
   elseif operand.kind == mod.OPERAND_KIND.MATH_OP then
      -- Operations are not resolved, they're used directly
      return operand
   else
      error("Unknown operand kind: " .. tostring(operand.kind))
   end
end

---Place a rail and update traverser state
---@param kind syntrax.vm.RailKind "left", "right", "straight" or "change_layer"
---@param span syntrax.Span? Source span for error reporting
function VM:place_rail(kind, span)
   local parent = self.current_piece
   local parent_end = self.traverser:get_direction()

   -- Move the traverser based on rail kind
   if kind == mod.RAIL_KIND.LEFT then
      self.traverser:move_left()
   elseif kind == mod.RAIL_KIND.RIGHT then
      self.traverser:move_right()
   elseif kind == mod.RAIL_KIND.CHANGE_LAYER then
      self.traverser:move_change_layer()
   else -- STRAIGHT
      self.traverser:move_forward()
   end

   -- Get the new rail info from traverser
   local pos = self.traverser:get_position()
   local rail_type = self.traverser:get_rail_kind()
   local placement_dir = self.traverser:get_placement_direction()
   local layer = self.traverser:get_layer()

   -- Create dedup key including position, direction, rail type and layer. Both ends of a ramp are one piece.
   local key_layer = rail_type == RailInfo.RailType.RAMP and "ramp" or layer
   local key = dedup_key(pos, placement_dir, rail_type, key_layer)

   -- Check for deduplication - if we've already placed this exact rail, skip
   local existing = self.position_to_index[key]
   if existing then
      self.current_piece = existing
      return -- Already have this exact rail
   end

   local rail = {
      type = "rail",
      position = pos,
      rail_type = rail_type, -- Already a string like "straight-rail"
      placement_direction = placement_dir,
      layer = layer,
      span = span,
   }

   -- Wrap in new format: one group with one alternative containing one entity
   table.insert(self.placements, { { rail } })
   table.insert(self.pieces, {
      rail_type = rail_type,
      placement_direction = placement_dir,
      position = pos,
      end_direction = self.traverser:get_direction(),
      layer = layer,
      parent = parent,
      parent_end = parent and parent_end or nil,
      group = #self.placements,
      span = span,
      forbid_support = not self.autosup or nil,
   })
   self.current_piece = #self.pieces
   self.position_to_index[key] = #self.pieces
end

---@param span syntrax.Span?
---@param message string
---@return syntrax.Error
local function runtime_error(span, message)
   return Errors.error_builder(Errors.ERROR_CODE.RUNTIME_ERROR, message, span):build()
end

---Place a ramp to the other layer
---@param target railutils.RailLayer? Layer the program expects to reach, nil for either (elev)
---@param span syntrax.Span?
---@return syntrax.Error?
function VM:change_layer(target, span)
   local layer = self.traverser:get_layer()
   if target and layer == target then
      return runtime_error(span, string.format("Already on the %s layer", layer))
   end
   if not self.traverser:can_change_layer() then
      return runtime_error(
         span,
         string.format(
            "A ramp can only start from a north, east, south or west end, this end faces %s",
            Directions.to_name(self.traverser:get_direction())
         )
      )
   end
   self:place_rail(mod.RAIL_KIND.CHANGE_LAYER, span)
   return nil
end

---Place a support at the current end
---@param span syntrax.Span?
---@return syntrax.Error?
function VM:place_support(span)
   if self.traverser:get_layer() ~= RailInfo.RailLayer.ELEVATED then
      return runtime_error(span, "Supports hold elevated rails, this end is on the ground")
   end
   local dir = self.traverser:get_direction()
   if dir % 2 ~= 0 then
      return runtime_error(
         span,
         string.format("A support cannot stand at an end facing %s, only at 8-way ends", Directions.to_name(dir))
      )
   end

   local pos = self.traverser:get_end_position()
   local key = support_key(pos)
   if self.current_piece then
      self.pieces[self.current_piece].explicit_support = true
   else
      self.start_support = true
   end
   if self.support_keys[key] then return nil end
   self.support_keys[key] = true

   table.insert(self.placements, {
      { { type = "support", position = pos, direction = dir, explicit = true, span = span } },
   })
   return nil
end

---Keep the support planner away from the current end
---@param span syntrax.Span?
---@return syntrax.Error?
function VM:forbid_support(span)
   if self.traverser:get_layer() ~= RailInfo.RailLayer.ELEVATED then
      return runtime_error(span, "nosup only means something on elevated rails, this end is on the ground")
   end
   -- On the starting rail there is nothing for the planner to place anyway
   if self.current_piece then self.pieces[self.current_piece].forbid_support = true end
   return nil
end

---Signals cannot go on ramps
---@param span syntrax.Span?
---@return syntrax.Error?
function VM:check_signal_allowed(span)
   if self.traverser:get_rail_kind() == RailInfo.RailType.RAMP then
      return runtime_error(span, "Signals cannot be placed on a ramp, add a rail after it first")
   end
   return nil
end

---Place a single signal with alternatives for regular/alt positions
---@param side railutils.SignalSide LEFT or RIGHT
---@param signal_type "rail-signal"|"rail-chain-signal"
---@param span syntrax.Span?
function VM:place_signal(side, signal_type, span)
   local alternatives = {}

   -- Regular position (always exists)
   local pos = self.traverser:get_signal_pos(side)
   local dir = self.traverser:get_signal_direction(side)
   table.insert(alternatives, {
      {
         type = "signal",
         position = pos,
         signal_type = signal_type,
         direction = dir,
         layer = self.traverser:get_layer(),
         span = span,
      },
   })

   -- Alt position (may not exist)
   local alt_pos = self.traverser:get_alt_signal_pos(side)
   if alt_pos then
      table.insert(alternatives, {
         {
            type = "signal",
            position = alt_pos,
            signal_type = signal_type,
            direction = dir, -- Same direction as regular
            layer = self.traverser:get_layer(),
            span = span,
         },
      })
   end

   table.insert(self.placements, alternatives)
end

---Place a pair of signals with all valid alternative combinations
---@param left_type "rail-signal"|"rail-chain-signal"
---@param right_type "rail-signal"|"rail-chain-signal"
---@param span syntrax.Span?
function VM:place_signal_pair(left_type, right_type, span)
   local left_pos = self.traverser:get_signal_pos(Traverser.SignalSide.LEFT)
   local right_pos = self.traverser:get_signal_pos(Traverser.SignalSide.RIGHT)
   local left_dir = self.traverser:get_signal_direction(Traverser.SignalSide.LEFT)
   local right_dir = self.traverser:get_signal_direction(Traverser.SignalSide.RIGHT)
   local left_alt = self.traverser:get_alt_signal_pos(Traverser.SignalSide.LEFT)
   local right_alt = self.traverser:get_alt_signal_pos(Traverser.SignalSide.RIGHT)

   -- Build list of left positions
   local left_positions = { { pos = left_pos } }
   if left_alt then table.insert(left_positions, { pos = left_alt }) end

   -- Build list of right positions
   local right_positions = { { pos = right_pos } }
   if right_alt then table.insert(right_positions, { pos = right_alt }) end

   local layer = self.traverser:get_layer()

   -- Generate cartesian product of alternatives
   local alternatives = {}
   for _, lp in ipairs(left_positions) do
      for _, rp in ipairs(right_positions) do
         table.insert(alternatives, {
            {
               type = "signal",
               position = lp.pos,
               signal_type = left_type,
               direction = left_dir,
               layer = layer,
               span = span,
            },
            {
               type = "signal",
               position = rp.pos,
               signal_type = right_type,
               direction = right_dir,
               layer = layer,
               span = span,
            },
         })
      end
   end

   table.insert(self.placements, alternatives)
end

---@param instr syntrax.vm.Bytecode
function VM:execute_jnz(instr)
   local value = self:resolve_operand(instr.arguments[1])
   local offset = self:resolve_operand(instr.arguments[2])

   if value.argument ~= 0 then
      self.pc = self.pc + offset.argument
   else
      self.pc = self.pc + 1
   end
end

---@param instr syntrax.vm.Bytecode
function VM:execute_math(instr)
   local dest = instr.arguments[1]
   if dest.kind ~= mod.OPERAND_KIND.REGISTER then error("MATH destination must be a register") end

   local left = self:resolve_operand(instr.arguments[2])
   local right = self:resolve_operand(instr.arguments[3])
   local op = instr.arguments[4]

   if op.kind ~= mod.OPERAND_KIND.MATH_OP then error("MATH operation must be a MATH_OP operand") end

   local result
   if op.argument == mod.MATH_OP.ADD then
      result = left.argument + right.argument
   elseif op.argument == mod.MATH_OP.SUB then
      result = left.argument - right.argument
   elseif op.argument == mod.MATH_OP.MUL then
      result = left.argument * right.argument
   elseif op.argument == mod.MATH_OP.DIV then
      result = left.argument / right.argument
   else
      error("Unknown math operation: " .. tostring(op.argument))
   end

   self.registers[dest.argument] = mod.value(mod.VALUE_TYPE.NUMBER, result)
   self.pc = self.pc + 1
end

---@param instr syntrax.vm.Bytecode
function VM:execute_mov(instr)
   local dest = instr.arguments[1]
   if dest.kind ~= mod.OPERAND_KIND.REGISTER then error("MOV destination must be a register") end

   local value = self:resolve_operand(instr.arguments[2])
   self.registers[dest.argument] = value
   self.pc = self.pc + 1
end

---@param instr syntrax.vm.Bytecode
---@return nil, syntrax.Error?
function VM:execute_rpush(instr)
   -- Push a clone of the current traverser to the stack
   local entry = {
      traverser = self.traverser:clone(),
      piece = self.current_piece,
   }
   table.insert(self.rail_stack, entry)
   return nil, nil
end

---@param instr syntrax.vm.Bytecode
---@return nil, syntrax.Error?
function VM:execute_rpop(instr)
   if #self.rail_stack == 0 then
      -- Runtime error - empty stack
      return nil,
         Errors.error_builder(Errors.ERROR_CODE.RUNTIME_ERROR, "Cannot rpop from empty rail stack", instr.span):build()
   end

   -- Pop and restore the traverser
   local entry = table.remove(self.rail_stack)
   self.traverser = entry.traverser
   self.current_piece = entry.piece
   return nil, nil
end

---@param instr syntrax.vm.Bytecode
---@return nil, syntrax.Error?
function VM:execute_reset(instr)
   -- Go to the mark (like rpop without the pop)
   if self.mark_traverser then
      self.traverser = self.mark_traverser:clone()
      self.current_piece = self.mark_piece
   end
   return nil, nil
end

---@param instr syntrax.vm.Bytecode
---@return nil, syntrax.Error?
function VM:execute_mark(instr)
   -- Set current position as the mark
   if self.traverser then
      self.mark_traverser = self.traverser:clone()
      self.mark_piece = self.current_piece
   end
   return nil, nil
end

---@param instr syntrax.vm.Bytecode
---@return nil, syntrax.Error?
function VM:execute_flip(instr)
   -- Flip to the other end of the current rail
   self.traverser:flip_ends()
   return nil, nil
end

---@return boolean, syntrax.Error? True if execution should continue, error if runtime error
function VM:execute_instruction()
   if self.pc < 1 or self.pc > #self.bytecode then
      return false -- Program complete
   end

   local instr = self.bytecode[self.pc]

   if instr.kind == mod.BYTECODE_KIND.LEFT then
      self:place_rail(mod.RAIL_KIND.LEFT, instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.RIGHT then
      self:place_rail(mod.RAIL_KIND.RIGHT, instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.STRAIGHT then
      self:place_rail(mod.RAIL_KIND.STRAIGHT, instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.FLIP then
      local _, err = self:execute_flip(instr)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.JNZ then
      self:execute_jnz(instr)
   elseif instr.kind == mod.BYTECODE_KIND.MATH then
      self:execute_math(instr)
   elseif instr.kind == mod.BYTECODE_KIND.MOV then
      self:execute_mov(instr)
   elseif instr.kind == mod.BYTECODE_KIND.RPUSH then
      local _, err = self:execute_rpush(instr)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.RPOP then
      local _, err = self:execute_rpop(instr)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.RESET then
      local _, err = self:execute_reset(instr)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.MARK then
      local _, err = self:execute_mark(instr)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.SIGLEFT then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal(Traverser.SignalSide.LEFT, "rail-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.SIGRIGHT then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal(Traverser.SignalSide.RIGHT, "rail-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.CHAINLEFT then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal(Traverser.SignalSide.LEFT, "rail-chain-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.CHAINRIGHT then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal(Traverser.SignalSide.RIGHT, "rail-chain-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.SIG then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal_pair("rail-signal", "rail-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.CHAIN then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal_pair("rail-chain-signal", "rail-chain-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.SIGCHAIN then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal_pair("rail-signal", "rail-chain-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.CHAINSIG then
      local err = self:check_signal_allowed(instr.span)
      if err then return false, err end
      self:place_signal_pair("rail-chain-signal", "rail-signal", instr.span)
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.UP then
      local err = self:change_layer(RailInfo.RailLayer.ELEVATED, instr.span)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.DOWN then
      local err = self:change_layer(RailInfo.RailLayer.GROUND, instr.span)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.ELEV then
      local err = self:change_layer(nil, instr.span)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.SUP then
      local err = self:place_support(instr.span)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.NOSUP then
      local err = self:forbid_support(instr.span)
      if err then return false, err end
      self.pc = self.pc + 1
   elseif instr.kind == mod.BYTECODE_KIND.AUTOSUP then
      self.autosup = self:resolve_operand(instr.arguments[1]).argument ~= 0
      self.pc = self.pc + 1
   else
      error("Unknown bytecode kind: " .. tostring(instr.kind))
   end

   return true
end

---Plan supports under the elevated rails and insert them right after the group of the piece they stand at
---@param opts syntrax.vm.SupportOpts
---@return syntrax.Error?
function VM:add_planned_supports(opts)
   local start_reach = opts.start_reach or 0
   if self.start_support then start_reach = opts.support_range end
   local supports, problems = SupportPlanner.plan(self.pieces, {
      support_range = opts.support_range,
      ramp_range = opts.ramp_range,
      start_reach = start_reach,
   })

   if problems[1] then
      local piece = self.pieces[problems[1].piece]
      if problems[1].reason == "forbidden" then
         return runtime_error(
            piece.span,
            "Nothing holds this rail: the supports it needs are ruled out by nosup or autosup off"
         )
      end
      return runtime_error(piece.span, "No place for a support within reach of this rail")
   end

   local after_group = {}
   for _, support in ipairs(supports) do
      local key = support_key(support.position)
      if not self.support_keys[key] then
         self.support_keys[key] = true
         local group = self.pieces[support.piece].group
         after_group[group] = after_group[group] or {}
         table.insert(after_group[group], {
            {
               {
                  type = "support",
                  position = support.position,
                  direction = support.direction,
                  explicit = false,
                  span = self.pieces[support.piece].span,
               },
            },
         })
      end
   end

   local merged = {}
   for i, group in ipairs(self.placements) do
      table.insert(merged, group)
      for _, extra in ipairs(after_group[i] or {}) do
         table.insert(merged, extra)
      end
   end
   self.placements = merged
   return nil
end

---Run the VM with the given starting position
---@param initial_position fa.Point? Starting position (default: {x=0, y=0})
---@param initial_direction number? Starting direction 0-15 (default: north/0)
---@param initial_rail_type railutils.RailType? Starting rail type (default: STRAIGHT)
---@param initial_placement_direction number? Placement direction of the starting rail
---@param opts syntrax.vm.RunOpts?
---@return syntrax.vm.PlacementGroup[]?, syntrax.Error?
function VM:run(initial_position, initial_direction, initial_rail_type, initial_placement_direction, opts)
   opts = opts or {}
   -- Default to origin facing north on a straight rail
   local pos = initial_position or { x = 0, y = 0 }
   local dir = initial_direction or defines.direction.north
   local rail_type = initial_rail_type or RailInfo.RailType.STRAIGHT

   -- Compute default placement_direction from end_direction for straight rails
   -- For straight rails, opposite ends share a placement direction:
   -- north/south share north, east/west share east, etc.
   local placement_dir = initial_placement_direction
   if not placement_dir then
      if rail_type == RailInfo.RailType.STRAIGHT then
         -- For straight rails, placement = end_direction if end < 8, else end - 8
         placement_dir = dir >= 8 and (dir - 8) or dir
      else
         -- For other rails, caller must provide placement_direction
         error("placement_direction required for non-straight rails when no initial context")
      end
   end

   -- Create the initial traverser at the starting position/direction/rail_type
   self.traverser = Traverser.new(rail_type, pos, placement_dir, dir, opts.initial_layer)
   self.initial_traverser = self.traverser:clone()
   self.mark_traverser = self.traverser:clone()

   -- Execute instructions until done or error
   while true do
      local continue, err = self:execute_instruction()
      if err then return nil, err end
      if not continue then break end
   end

   if opts.support then
      local err = self:add_planned_supports(opts.support)
      if err then return nil, err end
   end

   return self.placements, nil
end

-- Pretty printing support
function mod.format_operand(operand)
   if operand.kind == mod.OPERAND_KIND.VALUE then
      return string.format("v(%s)", tostring(operand.argument))
   elseif operand.kind == mod.OPERAND_KIND.REGISTER then
      return string.format("r(%d)", operand.argument)
   elseif operand.kind == mod.OPERAND_KIND.MATH_OP then
      return string.format("op(%s)", operand.argument)
   else
      return "?"
   end
end

function mod.format_bytecode(bc, index, labels)
   local parts = {}

   -- Add label if present
   if labels and labels[index] then table.insert(parts, labels[index] .. ":") end

   -- Add bytecode kind
   table.insert(parts, string.upper(bc.kind))

   -- Add arguments
   for i, arg in ipairs(bc.arguments) do
      -- Special handling for jump targets
      if bc.kind == mod.BYTECODE_KIND.JNZ and i == 2 and arg.kind == mod.OPERAND_KIND.VALUE then
         -- Try to find label for target
         local target = index + arg.argument
         if labels and labels[target] then
            table.insert(parts, labels[target])
         else
            table.insert(parts, mod.format_operand(arg))
         end
      else
         table.insert(parts, mod.format_operand(arg))
      end
   end

   return table.concat(parts, " ")
end

-- Re-export direction formatting for convenience
mod.format_direction = Directions.to_name

return mod
