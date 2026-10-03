---Elevated rails probe (developer tool)
---
---Runs the in-game experiments that the elevated rails plan needs before implementation
---(ELEVATED_RAILS_TERV_REVIEW.md, section 4.2). Everything happens on a throwaway surface
---and a throwaway force, so the player's own world, force and research are never touched.
---The surface is deleted and the force merged into "neutral" at the end.
---
---Results go to script-output/elevated-probe.txt. Called by the /elevprobe command.
---
---Each experiment runs under pcall, so one failing probe does not hide the others.

local ScratchSurface = require("scripts.rails.scratch-surface")

local mod = {}

local AREA = 96
local WATER_X_MIN = 50
local WATER_X_MAX = 70

local PIECES = {
   ground = { "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b" },
   elevated = {
      "elevated-straight-rail",
      "elevated-half-diagonal-rail",
      "elevated-curved-rail-a",
      "elevated-curved-rail-b",
   },
}

local INTERESTING_BLUEPRINT_NAMES = {
   ["rail-signal"] = true,
   ["straight-rail"] = true,
   ["elevated-straight-rail"] = true,
   ["rail-support"] = true,
}

local DIR_NAMES = {}
for name, value in pairs(defines.direction) do
   DIR_NAMES[value] = name
end

local LAYER_NAMES = {}
for name, value in pairs(defines.rail_layer) do
   LAYER_NAMES[value] = name
end

local CHECK_NAMES = {}
for name, value in pairs(defines.build_check_type) do
   CHECK_NAMES[value] = name
end

---@param d defines.direction?
---@return string
local function dir_name(d)
   if d == nil then return "nil" end
   return DIR_NAMES[d] or tostring(d)
end

---@param l defines.rail_layer?
---@return string
local function layer_name(l)
   if l == nil then return "nil" end
   return LAYER_NAMES[l] or tostring(l)
end

---@param p MapPosition
---@param origin MapPosition?
---@return string
local function pos_str(p, origin)
   if origin then return string.format("(%g, %g)", p.x - origin.x, p.y - origin.y) end
   return string.format("(%g, %g)", p.x, p.y)
end

---@class fa.ElevProbe.Ctx
---@field lines string[]
---@field errors integer
---@field surface LuaSurface
---@field force LuaForce

---@param ctx fa.ElevProbe.Ctx
---@param fmt string
local function out(ctx, fmt, ...)
   table.insert(ctx.lines, string.format(fmt, ...))
end

---@param ctx fa.ElevProbe.Ctx
---@param title string
---@param fn fun(ctx: fa.ElevProbe.Ctx)
local function section(ctx, title, fn)
   out(ctx, "")
   out(ctx, "## %s", title)
   local ok, err = pcall(fn, ctx)
   if not ok then
      ctx.errors = ctx.errors + 1
      out(ctx, "ERROR: %s", tostring(err))
   end
end

---Destroy everything in a square around a point (the probe surface only)
---@param ctx fa.ElevProbe.Ctx
---@param center MapPosition
---@param radius number
local function clear_around(ctx, center, radius)
   local ents = ctx.surface.find_entities_filtered({
      area = { { center.x - radius, center.y - radius }, { center.x + radius, center.y + radius } },
   })
   for _, e in ipairs(ents) do
      if e.valid then e.destroy() end
   end
end

---@param ctx fa.ElevProbe.Ctx
---@param name string
---@param position MapPosition
---@param direction defines.direction?
---@return LuaEntity?
local function make(ctx, name, position, direction)
   return ctx.surface.create_entity({
      name = name,
      position = position,
      direction = direction or defines.direction.north,
      force = ctx.force,
      raise_built = false,
      create_build_effect_smoke = false,
   })
end

---@param ctx fa.ElevProbe.Ctx
---@param name string
---@param position MapPosition
---@param direction defines.direction
---@param check defines.build_check_type
---@param inner_name string?
---@return boolean
local function can_place(ctx, name, position, direction, check, inner_name)
   return ctx.surface.can_place_entity({
      name = name,
      inner_name = inner_name,
      position = position,
      direction = direction,
      force = ctx.force,
      build_check_type = check,
   })
end

---Describe one rail end and its extensions, positions relative to the rail
---@param ctx fa.ElevProbe.Ctx
---@param rail LuaEntity
---@param rail_direction defines.rail_direction
local function describe_end(ctx, rail, rail_direction)
   local rail_end = rail.get_rail_end(rail_direction)
   local loc = rail_end.location
   out(
      ctx,
      "  end %s: at %s facing %s layer %s",
      rail_direction == defines.rail_direction.front and "front" or "back",
      pos_str(loc.position, rail.position),
      dir_name(loc.direction),
      layer_name(loc.rail_layer)
   )
   out(
      ctx,
      "    in_signal %s facing %s layer %s; out_signal %s facing %s layer %s",
      pos_str(rail_end.in_signal_location.position, rail.position),
      dir_name(rail_end.in_signal_location.direction),
      layer_name(rail_end.in_signal_location.rail_layer),
      pos_str(rail_end.out_signal_location.position, rail.position),
      dir_name(rail_end.out_signal_location.direction),
      layer_name(rail_end.out_signal_location.rail_layer)
   )
   local exts = rail_end.get_rail_extensions("rail")
   out(ctx, "    %d extensions:", #exts)
   local seen = {}
   for _, ext in ipairs(exts) do
      local key = tostring(ext.goal.direction)
      local dup = seen[key] and " DUPLICATE-GOAL-DIRECTION" or ""
      seen[key] = true
      out(
         ctx,
         "      %s at %s dir %s -> goal %s facing %s layer %s%s",
         ext.name,
         pos_str(ext.position, rail.position),
         dir_name(ext.direction),
         pos_str(ext.goal.position, rail.position),
         dir_name(ext.goal.direction),
         layer_name(ext.goal.rail_layer),
         dup
      )
   end
end

---@param ctx fa.ElevProbe.Ctx
---@param name string
---@param direction defines.direction
---@param center MapPosition
---@return LuaEntity?
local function describe_piece(ctx, name, direction, center)
   clear_around(ctx, center, 24)
   local rail = make(ctx, name, center, direction)
   if not rail then
      out(ctx, "%s dir %s: create_entity returned nil", name, dir_name(direction))
      return nil
   end
   out(
      ctx,
      "%s dir %s: placed at %s (requested %s), real direction %s",
      name,
      dir_name(direction),
      pos_str(rail.position),
      pos_str(center),
      dir_name(rail.direction)
   )
   describe_end(ctx, rail, defines.rail_direction.front)
   describe_end(ctx, rail, defines.rail_direction.back)
   return rail
end

---@param ctx fa.ElevProbe.Ctx
local function probe_meta(ctx)
   out(
      ctx,
      "base version %s, elevated-rails %s",
      script.active_mods["base"],
      tostring(script.active_mods["elevated-rails"])
   )
   out(ctx, "feature_flags.rail_bridges = %s", tostring(script.feature_flags.rail_bridges))
   for _, item in ipairs({ "rail", "rail-ramp" }) do
      local proto = prototypes.item[item]
      if proto then
         local names = {}
         for _, r in ipairs(proto.rails or {}) do
            table.insert(names, r.name)
         end
         out(
            ctx,
            "item %s: type %s, rails {%s}, support %s",
            item,
            proto.type,
            table.concat(names, ", "),
            proto.support and proto.support.name or "nil"
         )
      else
         out(ctx, "item %s: missing", item)
      end
   end
   for _, ent in ipairs({ "rail-support", "rail-ramp", "dummy-rail-support", "dummy-rail-ramp" }) do
      local proto = prototypes.entity[ent]
      if proto then
         local flags = {}
         for flag in pairs(proto.flags or {}) do
            table.insert(flags, flag)
         end
         table.sort(flags)
         out(
            ctx,
            "entity %s: support_range %s, collision_box %s, flags {%s}",
            ent,
            tostring(proto.support_range),
            serpent.line(proto.collision_box),
            table.concat(flags, ", ")
         )
      else
         out(ctx, "entity %s: missing", ent)
      end
   end
   for _, p in pairs(game.players) do
      out(
         ctx,
         "player %s force %s: rail_planner_allow_elevated_rails = %s, rail_support_on_deep_oil_ocean = %s",
         p.name,
         p.force.name,
         tostring(p.force.rail_planner_allow_elevated_rails),
         tostring(p.force.rail_support_on_deep_oil_ocean)
      )
   end
end

---E8 / E11 / E2a: what the engine reports for every piece type
---@param ctx fa.ElevProbe.Ctx
local function probe_extensions(ctx)
   local center = { x = 0, y = 0 }
   local function try_piece(name, dir)
      local ok, err = pcall(describe_piece, ctx, name, dir, center)
      if not ok then
         ctx.errors = ctx.errors + 1
         out(ctx, "ERROR in %s dir %s: %s", name, dir_name(dir), tostring(err))
      end
   end
   for _, layer in ipairs({ "ground", "elevated" }) do
      for _, name in ipairs(PIECES[layer]) do
         for _, dir in ipairs({ defines.direction.north, defines.direction.northeast }) do
            try_piece(name, dir)
         end
      end
   end
   for _, dir in ipairs({ defines.direction.north, defines.direction.east, defines.direction.northeast }) do
      try_piece("rail-ramp", dir)
   end
   clear_around(ctx, center, 24)
end

---E10: does get_rail_extensions depend on the research flag?
---@param ctx fa.ElevProbe.Ctx
local function probe_research_flag(ctx)
   local center = { x = 0, y = 0 }
   for _, flag in ipairs({ false, true }) do
      ctx.force.rail_planner_allow_elevated_rails = flag
      clear_around(ctx, center, 24)
      local rail = make(ctx, "straight-rail", center, defines.direction.north)
      if rail then
         local exts = rail.get_rail_end(defines.rail_direction.front).get_rail_extensions("rail")
         local names = {}
         for _, ext in ipairs(exts) do
            table.insert(names, ext.name .. "/" .. layer_name(ext.goal.rail_layer))
         end
         out(ctx, "flag %s: %d extensions {%s}", tostring(flag), #exts, table.concat(names, ", "))
      end
   end
   ctx.force.rail_planner_allow_elevated_rails = true
   clear_around(ctx, center, 24)
end

---E2b: can an unsupported elevated rail (or its ghost) be placed at all?
---@param ctx fa.ElevProbe.Ctx
local function probe_unsupported(ctx)
   local center = { x = 0, y = 0 }
   clear_around(ctx, center, 24)
   for _, check in ipairs({
      defines.build_check_type.manual,
      defines.build_check_type.manual_ghost,
      defines.build_check_type.script,
      defines.build_check_type.script_ghost,
      defines.build_check_type.blueprint_ghost,
   }) do
      out(
         ctx,
         "can_place elevated-straight-rail, no support, check %s: %s; as entity-ghost: %s",
         CHECK_NAMES[check],
         tostring(can_place(ctx, "elevated-straight-rail", center, defines.direction.north, check)),
         tostring(can_place(ctx, "entity-ghost", center, defines.direction.north, check, "elevated-straight-rail"))
      )
   end
   for _, check in ipairs({ defines.build_check_type.manual, defines.build_check_type.manual_ghost }) do
      out(
         ctx,
         "can_place rail-support on empty ground, check %s: %s",
         CHECK_NAMES[check],
         tostring(can_place(ctx, "rail-support", center, defines.direction.north, check))
      )
   end
   local ghost = ctx.surface.create_entity({
      name = "entity-ghost",
      inner_name = "elevated-straight-rail",
      position = center,
      direction = defines.direction.north,
      force = ctx.force,
   })
   out(ctx, "create_entity entity-ghost(elevated-straight-rail) without support: %s", ghost and "created" or "nil")
   if ghost then
      local revived, entity = ghost.silent_revive()
      out(ctx, "  silent_revive without support: %s", entity and "revived" or tostring(revived))
   end
   clear_around(ctx, center, 24)
end

---The end of a rail that faces the given direction
---@param rail LuaEntity
---@param facing defines.direction
---@return LuaRailEnd
local function end_facing(rail, facing)
   local rail_end = rail.get_rail_end(defines.rail_direction.front)
   if rail_end.location.direction ~= facing then rail_end = rail.get_rail_end(defines.rail_direction.back) end
   return rail_end
end

---Walk straight elevated rails in one direction, checking manual placement each step.
---Returns how many pieces were accepted and the last placed rail.
---@param ctx fa.ElevProbe.Ctx
---@param start LuaEntity
---@param travel defines.direction
---@param max_pieces integer
---@return integer, LuaEntity
local function walk_elevated(ctx, start, travel, max_pieces)
   local last = start
   for i = 1, max_pieces do
      local rail_end = end_facing(last, travel)
      local next_ext
      for _, ext in ipairs(rail_end.get_rail_extensions("rail")) do
         if ext.goal.direction == travel and ext.name == "elevated-straight-rail" then next_ext = ext end
      end
      if not next_ext then
         out(ctx, "    step %d: no straight elevated extension", i)
         return i - 1, last
      end
      local ok_manual =
         can_place(ctx, next_ext.name, next_ext.position, next_ext.direction, defines.build_check_type.manual)
      if not ok_manual then
         out(ctx, "    step %d at %s: manual placement refused", i, pos_str(next_ext.position))
         return i - 1, last
      end
      local placed = make(ctx, next_ext.name, next_ext.position, next_ext.direction)
      if not placed then
         out(ctx, "    step %d: create_entity failed after can_place said yes", i)
         return i - 1, last
      end
      last = placed
   end
   return max_pieces, last
end

---E4: how many straight elevated rails a ramp and then one support carry
---@param ctx fa.ElevProbe.Ctx
local function probe_coverage(ctx)
   local center = { x = 0, y = 40 }
   clear_around(ctx, center, 60)
   local ramp = make(ctx, "rail-ramp", center, defines.direction.north)
   if not ramp then
      out(ctx, "ramp create failed")
      return
   end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = ramp.get_rail_end(rd)
      out(
         ctx,
         "ramp end %s at %s facing %s layer %s",
         rd == defines.rail_direction.front and "front" or "back",
         pos_str(e.location.position),
         dir_name(e.location.direction),
         layer_name(e.location.rail_layer)
      )
   end
   local up_end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = ramp.get_rail_end(rd)
      if e.location.rail_layer == defines.rail_layer.elevated then up_end = e end
   end
   if not up_end then
      out(ctx, "no elevated end on ramp")
      return
   end
   -- First elevated piece straight off the ramp's elevated end
   local first
   for _, ext in ipairs(up_end.get_rail_extensions("rail")) do
      if ext.name == "elevated-straight-rail" then first = ext end
   end
   if not first then
      out(ctx, "no elevated straight extension from ramp top")
      return
   end
   out(ctx, "ramp top extension: %s at %s dir %s", first.name, pos_str(first.position), dir_name(first.direction))
   if not can_place(ctx, first.name, first.position, first.direction, defines.build_check_type.manual) then
      out(ctx, "even the first piece after the ramp is refused (manual)")
      return
   end
   local first_rail = make(ctx, first.name, first.position, first.direction)
   if not first_rail then
      out(ctx, "first piece create failed")
      return
   end
   local travel = up_end.location.direction
   out(ctx, "walking %s from the ramp top", dir_name(travel))
   local n, last = walk_elevated(ctx, first_rail, travel, 40)
   out(ctx, "ramp alone carries 1 + %d straight elevated rails (each 2 tiles)", n)
   local spot = end_facing(last, travel).location.position
   out(ctx, "last carried rail end at %s; trying supports around it", pos_str(spot))

   -- E5: which positions/directions accept a support near the chain end, and where it lands
   for dy = -4, 4, 2 do
      for _, dir in ipairs({ defines.direction.north, defines.direction.east, defines.direction.northnortheast }) do
         local p = { x = spot.x, y = spot.y + dy }
         local ok = can_place(ctx, "rail-support", p, dir, defines.build_check_type.manual)
         out(ctx, "  support at end%+d facing %s: manual %s", dy, dir_name(dir), tostring(ok))
      end
   end
   local support = make(ctx, "rail-support", spot, defines.direction.north)
   if not support then
      out(ctx, "support create at chain end failed")
      return
   end
   out(
      ctx,
      "support created at %s (requested %s) facing %s",
      pos_str(support.position),
      pos_str(spot),
      dir_name(support.direction)
   )
   local m = walk_elevated(ctx, last, travel, 40)
   out(ctx, "after one support at the chain end: %d more straight elevated rails accepted", m)

   -- Off-spot creation: does script creation snap?
   local off = { x = spot.x + 1.5, y = spot.y + 1 }
   local s2 = make(ctx, "rail-support", off, defines.direction.north)
   out(ctx, "support requested off-spot at %s landed at %s", pos_str(off), s2 and pos_str(s2.position) or "nil")
   clear_around(ctx, center, 60)
end

---E3: signals on stacked ground and elevated rails, and what a blueprint records
---@param ctx fa.ElevProbe.Ctx
local function probe_signals(ctx)
   local center = { x = -40, y = 0 }
   clear_around(ctx, center, 30)
   local ground = make(ctx, "straight-rail", center, defines.direction.north)
   local support = make(ctx, "rail-support", { x = center.x + 8, y = center.y }, defines.direction.north)
   local elevated = make(ctx, "elevated-straight-rail", center, defines.direction.north)
   out(
      ctx,
      "stacked at same spot: ground %s, elevated %s, support %s",
      ground and pos_str(ground.position) or "nil",
      elevated and pos_str(elevated.position) or "nil",
      support and "ok" or "nil"
   )
   if not (ground and elevated) then return end
   local g_end = ground.get_rail_end(defines.rail_direction.front)
   local e_end = elevated.get_rail_end(defines.rail_direction.front)
   out(
      ctx,
      "ground front in_signal %s, elevated front in_signal %s",
      pos_str(g_end.in_signal_location.position),
      pos_str(e_end.in_signal_location.position)
   )
   local s_e = make(ctx, "rail-signal", e_end.in_signal_location.position, e_end.in_signal_location.direction)
   out(
      ctx,
      "signal at elevated location: %s, rail_layer %s",
      s_e and "created" or "nil",
      s_e and layer_name(s_e.rail_layer) or "-"
   )
   local s_g = make(ctx, "rail-signal", g_end.in_signal_location.position, g_end.in_signal_location.direction)
   out(
      ctx,
      "signal at ground location (same xy?): %s, rail_layer %s",
      s_g and "created" or "nil",
      s_g and layer_name(s_g.rail_layer) or "-"
   )
   local found = ctx.surface.find_entities_filtered({
      name = "rail-signal",
      position = e_end.in_signal_location.position,
      radius = 0.5,
   })
   out(ctx, "find_entities_filtered at that xy finds %d signals", #found)
   local single = ctx.surface.find_entity("rail-signal", e_end.in_signal_location.position)
   out(ctx, "find_entity at that xy returns layer %s", single and layer_name(single.rail_layer) or "nil")

   local inv = game.create_inventory(1)
   local ok, err = pcall(function()
      local stack = inv[1]
      stack.set_stack({ name = "blueprint" })
      stack.create_blueprint({
         surface = ctx.surface,
         force = ctx.force,
         area = { { center.x - 12, center.y - 12 }, { center.x + 12, center.y + 12 } },
      })
      for _, be in ipairs(stack.get_blueprint_entities() or {}) do
         if INTERESTING_BLUEPRINT_NAMES[be.name] then
            out(ctx, "  blueprint entity: %s", serpent.line(be))
         end
      end
   end)
   inv.destroy()
   if not ok then out(ctx, "blueprint step failed: %s", tostring(err)) end
   clear_around(ctx, center, 30)
end

---E9: water
---@param ctx fa.ElevProbe.Ctx
local function probe_water(ctx)
   local p = { x = (WATER_X_MIN + WATER_X_MAX) / 2, y = 0 }
   for _, name in ipairs({ "straight-rail", "elevated-straight-rail", "rail-support", "rail-ramp" }) do
      out(
         ctx,
         "%s over water: manual %s, manual_ghost %s",
         name,
         tostring(can_place(ctx, name, p, defines.direction.north, defines.build_check_type.manual)),
         tostring(can_place(ctx, name, p, defines.direction.north, defines.build_check_type.manual_ghost))
      )
   end
end

---Actual position the engine gives a piece requested at a spot (placed and removed again)
---@param ctx fa.ElevProbe.Ctx
---@param name string
---@param position MapPosition
---@param direction defines.direction
---@return MapPosition?
local function snapped(ctx, name, position, direction)
   local e = make(ctx, name, position, direction)
   if not e then return nil end
   local p = e.position
   e.destroy()
   return p
end

---E4b E4c: which single elevated pieces (no neighbours) one support carries, by distance from the support
---@param ctx fa.ElevProbe.Ctx
local function probe_isolated_coverage(ctx)
   local dirs = defines.direction
   local center = { x = 0, y = -60 }
   local configs = {
      {
         label = "support north, vertical straight, going north",
         sdir = dirs.north,
         piece = "elevated-straight-rail",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
      },
      {
         label = "support north, vertical straight, going south",
         sdir = dirs.north,
         piece = "elevated-straight-rail",
         pdir = dirs.north,
         step = { x = 0, y = 2 },
      },
      {
         label = "support north, horizontal straight, going east",
         sdir = dirs.north,
         piece = "elevated-straight-rail",
         pdir = dirs.east,
         step = { x = 2, y = 0 },
      },
      {
         label = "support east, vertical straight, going north",
         sdir = dirs.east,
         piece = "elevated-straight-rail",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
      },
      {
         label = "support northeast, vertical straight, going north",
         sdir = dirs.northeast,
         piece = "elevated-straight-rail",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
      },
      {
         label = "support north, diagonal straight, going northeast",
         sdir = dirs.north,
         piece = "elevated-straight-rail",
         pdir = dirs.northeast,
         step = { x = 2, y = -2 },
      },
      {
         label = "support north, curved-a north, going north",
         sdir = dirs.north,
         piece = "elevated-curved-rail-a",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
      },
      {
         label = "support north, half-diagonal north, going north",
         sdir = dirs.north,
         piece = "elevated-half-diagonal-rail",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
      },
      {
         label = "support GHOST only, vertical straight, going north",
         sdir = dirs.north,
         piece = "elevated-straight-rail",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
         ghost = true,
      },
      {
         label = "support off-grid (+1, +1), vertical straight, going north",
         sdir = dirs.north,
         piece = "elevated-straight-rail",
         pdir = dirs.north,
         step = { x = 0, y = -2 },
         offset = { x = 1, y = 1 },
      },
   }
   for _, cfg in ipairs(configs) do
      clear_around(ctx, center, 40)
      local sp = center
      if cfg.offset then sp = { x = center.x + cfg.offset.x, y = center.y + cfg.offset.y } end
      local support
      if cfg.ghost then
         support = ctx.surface.create_entity({
            name = "entity-ghost",
            inner_name = "rail-support",
            position = sp,
            direction = cfg.sdir,
            force = ctx.force,
         })
      else
         support = make(ctx, "rail-support", sp, cfg.sdir)
      end
      if not support then
         out(ctx, "%s: support create failed", cfg.label)
      else
         local sx, sy = support.position.x, support.position.y
         local results = {}
         for k = 0, 12 do
            local req = { x = sx + cfg.step.x * k, y = sy + cfg.step.y * k }
            local p = snapped(ctx, cfg.piece, req, cfg.pdir)
            if p then
               local ok = can_place(ctx, cfg.piece, p, cfg.pdir, defines.build_check_type.manual)
               local d = math.sqrt((p.x - sx) ^ 2 + (p.y - sy) ^ 2)
               table.insert(results, string.format("%s%.2f", ok and "+" or "-", d))
            end
         end
         out(ctx, "%s, support at %s: %s", cfg.label, pos_str(support.position), table.concat(results, " "))
      end
   end
   clear_around(ctx, center, 40)
end

---E3b: a signal next to an elevated-only rail, what its blueprint looks like, and what that blueprint builds on a
---spot where ground and elevated rails are stacked
---@param ctx fa.ElevProbe.Ctx
local function probe_elevated_signal(ctx)
   local dirs = defines.direction
   local a = { x = -40, y = -40 }
   local b = { x = -40, y = 40 }
   clear_around(ctx, a, 30)
   clear_around(ctx, b, 30)

   make(ctx, "rail-support", a, dirs.north)
   local elevated = make(ctx, "elevated-straight-rail", a, dirs.north)
   if not elevated then
      out(ctx, "elevated-only rail create failed")
      return
   end
   local loc = elevated.get_rail_end(defines.rail_direction.front).in_signal_location
   local sig = make(ctx, "rail-signal", loc.position, loc.direction)
   out(
      ctx,
      "signal next to an elevated-only rail: %s, rail_layer %s",
      sig and "created" or "nil",
      sig and layer_name(sig.rail_layer) or "-"
   )

   local inv = game.create_inventory(1)
   local ok, err = pcall(function()
      local stack = inv[1]
      stack.set_stack({ name = "blueprint" })
      stack.create_blueprint({
         surface = ctx.surface,
         force = ctx.force,
         area = { { a.x - 12, a.y - 12 }, { a.x + 12, a.y + 12 } },
      })
      local captured
      for _, be in ipairs(stack.get_blueprint_entities() or {}) do
         out(ctx, "  captured: %s", serpent.line(be))
         if be.name == "rail-signal" then captured = be end
      end

      -- Stacked spot: ground rail, elevated rail and a support at b
      make(ctx, "straight-rail", b, dirs.north)
      make(ctx, "rail-support", b, dirs.north)
      local elev_b = make(ctx, "elevated-straight-rail", b, dirs.north)
      if not (captured and elev_b) then
         out(
            ctx,
            "  stacked setup incomplete: captured %s, elevated %s",
            tostring(captured ~= nil),
            tostring(elev_b ~= nil)
         )
         return
      end
      local target = elev_b.get_rail_end(defines.rail_direction.front).in_signal_location
      local variants = {
         { label = "as captured", entity = captured },
         { label = "with rail_layer = elevated added", extra = { rail_layer = "elevated" } },
      }
      for _, v in ipairs(variants) do
         local be = {}
         for k, val in pairs(captured) do
            be[k] = val
         end
         for k, val in pairs(v.extra or {}) do
            be[k] = val
         end
         be.entity_number = 1
         be.position = { x = 0, y = 0 }
         stack.set_blueprint_entities({ be })
         local built = stack.build_blueprint({
            surface = ctx.surface,
            force = ctx.force,
            position = target.position,
            build_mode = defines.build_mode.forced,
         })
         out(ctx, "  build %s at %s: %d ghosts", v.label, pos_str(target.position), #built)
         for _, g in ipairs(built) do
            out(
               ctx,
               "    ghost %s at %s, rail_layer %s",
               g.ghost_name,
               pos_str(g.position),
               layer_name(g.rail_layer)
            )
            g.destroy()
         end
      end
   end)
   inv.destroy()
   if not ok then
      ctx.errors = ctx.errors + 1
      out(ctx, "ERROR: %s", tostring(err))
   end
   clear_around(ctx, a, 30)
   clear_around(ctx, b, 30)
end

---E5b K3: a whole elevated run (ramp, rails, support) as one blueprint; where the support ghost lands, and which
---revive order works
---@param ctx fa.ElevProbe.Ctx
local function probe_blueprint_run(ctx)
   local dirs = defines.direction
   local center = { x = 30, y = 40 }
   clear_around(ctx, center, 40)

   -- Build the source run with script creation: ramp facing north, 8 elevated straight rails, support at rail 5
   local ramp = make(ctx, "rail-ramp", center, dirs.north)
   if not ramp then
      out(ctx, "ramp create failed")
      return
   end
   local top = ramp.get_rail_end(defines.rail_direction.back)
   if top.location.rail_layer ~= defines.rail_layer.elevated then
      top = ramp.get_rail_end(defines.rail_direction.front)
   end
   local last_end = top
   local rails = {}
   for _ = 1, 8 do
      local next_ext
      for _, ext in ipairs(last_end.get_rail_extensions("rail")) do
         if ext.name == "elevated-straight-rail" then next_ext = ext end
      end
      local r = make(ctx, next_ext.name, next_ext.position, next_ext.direction)
      table.insert(rails, r)
      last_end = r.get_rail_end(defines.rail_direction.front)
      if last_end.location.direction ~= top.location.direction then
         last_end = r.get_rail_end(defines.rail_direction.back)
      end
   end
   local spot = rails[5].position
   local requested = { x = spot.x + 1, y = spot.y }
   local support = make(ctx, "rail-support", requested, dirs.north)
   out(
      ctx,
      "source: ramp at %s, rail 5 at %s relative to ramp, support requested at %s, created at %s",
      pos_str(ramp.position),
      pos_str(spot, ramp.position),
      pos_str(requested, ramp.position),
      support and pos_str(support.position, ramp.position) or "nil"
   )

   local inv = game.create_inventory(1)
   local ok, err = pcall(function()
      local stack = inv[1]
      stack.set_stack({ name = "blueprint" })
      stack.create_blueprint({
         surface = ctx.surface,
         force = ctx.force,
         area = { { center.x - 6, center.y - 30 }, { center.x + 6, center.y + 10 } },
      })
      local bp_entities = stack.get_blueprint_entities() or {}
      out(ctx, "blueprint has %d entities", #bp_entities)
      for _, be in ipairs(bp_entities) do
         if be.name == "rail-support" then out(ctx, "  blueprint support entry: %s", serpent.line(be)) end
      end

      for _, order in ipairs({ "blueprint order", "supports first" }) do
         clear_around(ctx, center, 40)
         local ghosts = stack.build_blueprint({
            surface = ctx.surface,
            force = ctx.force,
            position = ramp.valid and ramp.position or center,
            build_mode = defines.build_mode.normal,
         })
         out(ctx, "%s: build_blueprint made %d ghosts", order, #ghosts)
         local ramp_ghost
         for _, g in ipairs(ghosts) do
            if g.ghost_name == "rail-ramp" then ramp_ghost = g end
         end
         for _, g in ipairs(ghosts) do
            if g.ghost_name == "rail-support" then
               local rel_to = ramp_ghost and ramp_ghost.position
               out(ctx, "  support ghost at %s relative to the ramp ghost", pos_str(g.position, rel_to))
            end
         end
         if order == "supports first" then
            table.sort(ghosts, function(x, y)
               local xs = (x.ghost_name == "rail-support" or x.ghost_name == "rail-ramp") and 0 or 1
               local ys = (y.ghost_name == "rail-support" or y.ghost_name == "rail-ramp") and 0 or 1
               return xs < ys
            end)
         end
         local revived, failed = 0, {}
         for _, g in ipairs(ghosts) do
            if g.valid then
               local name = g.ghost_name
               local _, entity = g.silent_revive()
               if entity then
                  revived = revived + 1
               else
                  table.insert(failed, name)
               end
            end
         end
         out(ctx, "%s: revived %d, failed {%s}", order, revived, table.concat(failed, ", "))
      end
   end)
   inv.destroy()
   if not ok then
      ctx.errors = ctx.errors + 1
      out(ctx, "ERROR: %s", tostring(err))
   end
   clear_around(ctx, center, 40)
end

---Unit vector (in rail lengths of 2 tiles) for a cardinal travel direction
local TRAVEL_STEP = {
   [defines.direction.north] = { x = 0, y = -2 },
   [defines.direction.east] = { x = 2, y = 0 },
   [defines.direction.south] = { x = 0, y = 2 },
   [defines.direction.west] = { x = -2, y = 0 },
}

---Ramp facing north at center plus the elevated chain the ramp alone carries
---@param ctx fa.ElevProbe.Ctx
---@param center MapPosition
---@return LuaEntity? last_rail, defines.direction? travel, integer carried
local function ramp_with_carried_chain(ctx, center)
   local ramp = make(ctx, "rail-ramp", center, defines.direction.north)
   if not ramp then return nil, nil, 0 end
   local up_end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = ramp.get_rail_end(rd)
      if e.location.rail_layer == defines.rail_layer.elevated then up_end = e end
   end
   local first
   for _, ext in ipairs(up_end.get_rail_extensions("rail")) do
      if ext.name == "elevated-straight-rail" then first = ext end
   end
   local first_rail = make(ctx, first.name, first.position, first.direction)
   local travel = up_end.location.direction
   local n, last = walk_elevated(ctx, first_rail, travel, 40)
   return last, travel, n + 1
end

---E12: how far ahead of the carried chain a standalone support may stand so that the chain still grows up to it and
---past it. The support goes on a future rail end (a "spot") k rails ahead of the last carried rail.
---@param ctx fa.ElevProbe.Ctx
local function probe_support_ahead(ctx)
   local center = { x = 0, y = 60 }
   local variants = {}
   for k = 1, 8 do
      table.insert(variants, { k = k, label = string.format("on the spot %d rails ahead", k) })
   end
   table.insert(variants, { k = 3, dir = defines.direction.east, label = "3 ahead, support facing east" })
   table.insert(variants, { k = 3, side = 1, label = "3 ahead, 1 tile off the track axis" })
   table.insert(variants, { k = 3, along = -1, label = "3 ahead, at a rail center instead of a rail end" })
   for _, v in ipairs(variants) do
      clear_around(ctx, center, 60)
      local last, travel, carried = ramp_with_carried_chain(ctx, center)
      if not last or not travel then
         out(ctx, "%s: setup failed", v.label)
      else
         local step = TRAVEL_STEP[travel]
         local spot = end_facing(last, travel).location.position
         local side = v.side or 0
         local along = (v.along or 0) / 2
         local sp = {
            x = spot.x + step.x * (v.k + along) + (step.y ~= 0 and side or 0),
            y = spot.y + step.y * (v.k + along) + (step.x ~= 0 and side or 0),
         }
         local support = make(ctx, "rail-support", sp, v.dir or travel)
         if not support then
            out(ctx, "%s: support create failed at %s", v.label, pos_str(sp))
         else
            local more = walk_elevated(ctx, last, travel, 20)
            out(
               ctx,
               "%s (ramp carried %d): support at %s, then %d more rails accepted",
               v.label,
               carried,
               pos_str(support.position, center),
               more
            )
         end
      end
   end
   clear_around(ctx, center, 60)
end

---E13: build a long elevated run (ramp, 14 rails, support at the end of rail 9) as one blueprint and revive it in
---track order, once with all supports first and once with supports revived only when a rail fails
---@param ctx fa.ElevProbe.Ctx
local function probe_track_order_revive(ctx)
   local center = { x = 30, y = -40 }
   clear_around(ctx, center, 50)
   local ramp = make(ctx, "rail-ramp", center, defines.direction.north)
   if not ramp then
      out(ctx, "ramp create failed")
      return
   end
   local up_end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = ramp.get_rail_end(rd)
      if e.location.rail_layer == defines.rail_layer.elevated then up_end = e end
   end
   local travel = up_end.location.direction
   local last_end = up_end
   local rails = {}
   for i = 1, 14 do
      local next_ext
      for _, ext in ipairs(last_end.get_rail_extensions("rail")) do
         if ext.name == "elevated-straight-rail" then next_ext = ext end
      end
      local r = make(ctx, next_ext.name, next_ext.position, next_ext.direction)
      rails[i] = r
      last_end = end_facing(r, travel)
   end
   local support_spot = end_facing(rails[9], travel).location.position
   make(ctx, "rail-support", support_spot, travel)
   local ramp_pos = ramp.position

   local inv = game.create_inventory(1)
   local ok, err = pcall(function()
      local stack = inv[1]
      stack.set_stack({ name = "blueprint" })
      stack.create_blueprint({
         surface = ctx.surface,
         force = ctx.force,
         area = { { center.x - 6, center.y - 50 }, { center.x + 6, center.y + 10 } },
      })
      local strategies = { "supports first, then rails in track order", "rails in track order, support on demand" }
      for _, strategy in ipairs(strategies) do
         clear_around(ctx, center, 50)
         local ghosts = stack.build_blueprint({
            surface = ctx.surface,
            force = ctx.force,
            position = ramp_pos,
            build_mode = defines.build_mode.normal,
         })
         local ramp_g, supports, rail_ghosts = nil, {}, {}
         for _, g in ipairs(ghosts) do
            if g.ghost_name == "rail-ramp" then
               ramp_g = g
            elseif g.ghost_name == "rail-support" then
               table.insert(supports, g)
            else
               table.insert(rail_ghosts, g)
            end
         end
         local origin = ramp_g.position
         table.sort(rail_ghosts, function(x, y)
            local dx = (x.position.x - origin.x) ^ 2 + (x.position.y - origin.y) ^ 2
            local dy = (y.position.x - origin.x) ^ 2 + (y.position.y - origin.y) ^ 2
            return dx < dy
         end)
         local log = {}
         local _, ramp_e = ramp_g.silent_revive()
         table.insert(log, ramp_e and "ramp" or "RAMP-FAILED")
         if strategy:find("supports first") then
            for _, sg in ipairs(supports) do
               local _, se = sg.silent_revive()
               table.insert(log, se and "support" or "SUPPORT-FAILED")
            end
         end
         for i, rg in ipairs(rail_ghosts) do
            local _, re = rg.silent_revive()
            if not re and not strategy:find("supports first") and #supports > 0 and supports[1].valid then
               local _, se = supports[1].silent_revive()
               table.insert(log, se and ("support-after-" .. i) or "SUPPORT-FAILED")
               if rg.valid then
                  _, re = rg.silent_revive()
               end
            end
            table.insert(log, re and tostring(i) or ("X" .. i))
         end
         out(ctx, "%s: %s", strategy, table.concat(log, " "))
      end
   end)
   inv.destroy()
   if not ok then
      ctx.errors = ctx.errors + 1
      out(ctx, "ERROR: %s", tostring(err))
   end
   clear_around(ctx, center, 50)
end

---Revive a ghost and report the rail layer of the result
---@param ghost LuaEntity?
---@return string
local function revive_layer(ghost)
   if not ghost or not ghost.valid then return "no ghost" end
   local _, entity = ghost.silent_revive()
   if not entity then return "revive failed" end
   return "revived, layer " .. layer_name(entity.rail_layer)
end

---E14: elevated signals and supports. The user remembers that elevated signals only work when they stand on a
---support. Tests create_entity and a blueprint with rail_layer = "elevated", at a rail end with a support under it,
---at a rail end without one, and on a spot where ground and elevated rails are stacked.
---@param ctx fa.ElevProbe.Ctx
local function probe_signals_on_supports(ctx)
   local center = { x = -40, y = 0 }
   local inv = game.create_inventory(1)
   local ok, err = pcall(function()
      local stack = inv[1]
      for _, case in ipairs({ "support at the end", "no support at the end", "stacked with ground rail, support" }) do
         clear_around(ctx, center, 40)
         -- A carried elevated chain needs a ramp; use the ramp and pick the end of the 2nd rail
         local ramp = make(ctx, "rail-ramp", center, defines.direction.north)
         local up_end
         for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
            local e = ramp.get_rail_end(rd)
            if e.location.rail_layer == defines.rail_layer.elevated then up_end = e end
         end
         local travel = up_end.location.direction
         local last_end = up_end
         local rails = {}
         for i = 1, 3 do
            local next_ext
            for _, ext in ipairs(last_end.get_rail_extensions("rail")) do
               if ext.name == "elevated-straight-rail" then next_ext = ext end
            end
            rails[i] = make(ctx, next_ext.name, next_ext.position, next_ext.direction)
            last_end = end_facing(rails[i], travel)
         end
         local target_end = end_facing(rails[2], travel)
         if case ~= "no support at the end" then make(ctx, "rail-support", target_end.location.position, travel) end
         if case:find("stacked") then make(ctx, "straight-rail", rails[2].position, rails[2].direction) end
         local loc = target_end.in_signal_location

         local sig = make(ctx, "rail-signal", loc.position, loc.direction)
         local direct = sig and ("created, layer " .. layer_name(sig.rail_layer)) or "nil"
         if sig then sig.destroy() end

         stack.set_stack({ name = "blueprint" })
         stack.set_blueprint_entities({
            {
               entity_number = 1,
               name = "rail-signal",
               position = { x = 0, y = 0 },
               direction = loc.direction,
               rail_layer = "elevated",
            },
         })
         local ghosts = stack.build_blueprint({
            surface = ctx.surface,
            force = ctx.force,
            position = loc.position,
            build_mode = defines.build_mode.forced,
         })
         local via_bp = #ghosts == 0 and "no ghost"
            or string.format("ghost at %s, %s", pos_str(ghosts[1].position, loc.position), revive_layer(ghosts[1]))
         out(ctx, "%s: create_entity %s; blueprint with rail_layer elevated: %s", case, direct, via_bp)
      end
   end)
   inv.destroy()
   if not ok then
      ctx.errors = ctx.errors + 1
      out(ctx, "ERROR: %s", tostring(err))
   end
   clear_around(ctx, center, 40)
end

---Elevated straight extension of a rail end, or nil
---@param rail_end LuaRailEnd
---@return RailExtensionData?
local function straight_ext(rail_end)
   for _, ext in ipairs(rail_end.get_rail_extensions("rail")) do
      if ext.name == "elevated-straight-rail" then return ext end
   end
   return nil
end

---Positions and directions of n future straight elevated rails continuing in a straight line from a rail end
---@param from_end LuaRailEnd
---@param travel defines.direction
---@param n integer
---@return {position: MapPosition, direction: defines.direction}[]
local function future_rails(from_end, travel, n)
   local first = straight_ext(from_end)
   local step = TRAVEL_STEP[travel]
   local result = {}
   for i = 1, n do
      result[i] = {
         position = { x = first.position.x + step.x * (i - 1), y = first.position.y + step.y * (i - 1) },
         direction = first.direction,
      }
   end
   return result
end

---Place a list of planned straight rails in a given order with a manual placement check; returns a string like
---"5+ 6+ 7-" in the order tried
---@param ctx fa.ElevProbe.Ctx
---@param planned {position: MapPosition, direction: defines.direction}[]
---@param order integer[]
---@return string, integer
local function place_in_order(ctx, planned, order)
   local log, placed = {}, 0
   for _, i in ipairs(order) do
      local pr = planned[i]
      local ok = can_place(ctx, "elevated-straight-rail", pr.position, pr.direction, defines.build_check_type.manual)
      if ok then
         make(ctx, "elevated-straight-rail", pr.position, pr.direction)
         placed = placed + 1
      end
      table.insert(log, tostring(i) .. (ok and "+" or "-"))
   end
   return table.concat(log, " "), placed
end

---E15 E16: a support k rails beyond what the ramp carries, then rails built from the support back towards the chain
---and then onwards. Also the support's direction at k = 1 and k = 5.
---@param ctx fa.ElevProbe.Ctx
local function probe_backward_fill(ctx)
   local center = { x = 0, y = 60 }
   local variants = {}
   for k = 1, 7 do
      table.insert(variants, { k = k })
   end
   for _, k in ipairs({ 1, 5 }) do
      table.insert(variants, { k = k, dir = defines.direction.east, label = "support facing east" })
      table.insert(variants, { k = k, dir = defines.direction.northeast, label = "support facing northeast" })
      table.insert(variants, { k = k, dir = defines.direction.south, label = "support facing south" })
   end
   for _, v in ipairs(variants) do
      clear_around(ctx, center, 70)
      local last, travel, carried = ramp_with_carried_chain(ctx, center)
      if not last or not travel then
         out(ctx, "k=%d: setup failed", v.k)
      else
         local planned = future_rails(end_facing(last, travel), travel, v.k + 8)
         -- The support stands on the far end of planned rail k, half a rail beyond its center
         local step = TRAVEL_STEP[travel]
         local k_rail = planned[v.k]
         local spot = { x = k_rail.position.x + step.x / 2, y = k_rail.position.y + step.y / 2 }
         make(ctx, "rail-support", spot, v.dir or travel)
         local order = {}
         for i = v.k, 1, -1 do
            table.insert(order, i)
         end
         for i = v.k + 1, v.k + 8 do
            table.insert(order, i)
         end
         local log, placed = place_in_order(ctx, planned, order)
         out(
            ctx,
            "k=%d%s (ramp carried %d): support at %s; backward then forward: %s; %d of %d placed",
            v.k,
            v.label and (", " .. v.label) or "",
            carried,
            pos_str(spot, center),
            log,
            placed,
            #order
         )
      end
   end
   clear_around(ctx, center, 70)
end

---E17: the E13 run revived with repeated passes until a pass makes no progress
---@param ctx fa.ElevProbe.Ctx
local function probe_fixpoint_revive(ctx)
   local center = { x = 30, y = -40 }
   clear_around(ctx, center, 50)
   local ramp = make(ctx, "rail-ramp", center, defines.direction.north)
   local up_end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = ramp.get_rail_end(rd)
      if e.location.rail_layer == defines.rail_layer.elevated then up_end = e end
   end
   local travel = up_end.location.direction
   local last_end = up_end
   local rails = {}
   for i = 1, 20 do
      local ext = straight_ext(last_end)
      rails[i] = make(ctx, ext.name, ext.position, ext.direction)
      last_end = end_facing(rails[i], travel)
   end
   -- Supports at the far ends of rails 9 and 19: 4 carried by the ramp + 5 back from each support + 5 forward
   for _, i in ipairs({ 9, 19 }) do
      make(ctx, "rail-support", end_facing(rails[i], travel).location.position, travel)
   end
   local ramp_pos = ramp.position

   local inv = game.create_inventory(1)
   local ok, err = pcall(function()
      local stack = inv[1]
      stack.set_stack({ name = "blueprint" })
      stack.create_blueprint({
         surface = ctx.surface,
         force = ctx.force,
         area = { { center.x - 6, center.y - 60 }, { center.x + 6, center.y + 10 } },
      })
      clear_around(ctx, center, 70)
      local ghosts = stack.build_blueprint({
         surface = ctx.surface,
         force = ctx.force,
         position = ramp_pos,
         build_mode = defines.build_mode.normal,
      })
      local remaining = {}
      for _, g in ipairs(ghosts) do
         table.insert(remaining, g)
      end
      local passes, revived = 0, 0
      local per_pass = {}
      while #remaining > 0 do
         passes = passes + 1
         local still, this_pass = {}, 0
         for _, g in ipairs(remaining) do
            if g.valid then
               local _, entity = g.silent_revive()
               if entity then
                  this_pass = this_pass + 1
               else
                  table.insert(still, g)
               end
            end
         end
         table.insert(per_pass, tostring(this_pass))
         revived = revived + this_pass
         remaining = still
         if this_pass == 0 then break end
      end
      out(
         ctx,
         "%d ghosts, %d revived in %d passes (per pass %s), %d left",
         #ghosts,
         revived,
         passes,
         table.concat(per_pass, ", "),
         #remaining
      )
   end)
   inv.destroy()
   if not ok then
      ctx.errors = ctx.errors + 1
      out(ctx, "ERROR: %s", tostring(err))
   end
   clear_around(ctx, center, 70)
end

---E18: how many curved pieces a ramp and a support carry (right turns from the ramp top, then from a support)
---@param ctx fa.ElevProbe.Ctx
local function probe_curve_coverage(ctx)
   local center = { x = -40, y = -40 }
   clear_around(ctx, center, 50)
   local ramp = make(ctx, "rail-ramp", center, defines.direction.north)
   local up_end
   for _, rd in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = ramp.get_rail_end(rd)
      if e.location.rail_layer == defines.rail_layer.elevated then up_end = e end
   end
   ---Turn right as far as manual placement allows
   ---@param from_end LuaRailEnd
   ---@return integer count, LuaRailEnd last_end, string names
   local function turn_right(from_end)
      local last_end = from_end
      local names = {}
      for i = 1, 12 do
         local goal = (last_end.location.direction + 1) % 16
         local next_ext
         for _, ext in ipairs(last_end.get_rail_extensions("rail")) do
            if ext.goal.direction == goal and ext.goal.rail_layer == defines.rail_layer.elevated then next_ext = ext end
         end
         if not next_ext then return i - 1, last_end, table.concat(names, ", ") end
         local manual = defines.build_check_type.manual
         if not can_place(ctx, next_ext.name, next_ext.position, next_ext.direction, manual) then
            return i - 1, last_end, table.concat(names, ", ")
         end
         local r = make(ctx, next_ext.name, next_ext.position, next_ext.direction)
         table.insert(names, (next_ext.name:gsub("elevated%-", "")))
         -- Continue from the end that is not the one we came from
         local e1 = r.get_rail_end(defines.rail_direction.front)
         local e2 = r.get_rail_end(defines.rail_direction.back)
         last_end = (e1.location.direction == goal) and e1 or e2
      end
      return 12, last_end, table.concat(names, ", ")
   end
   local n1, end1, names1 = turn_right(up_end)
   out(ctx, "ramp top, turning right: %d pieces carried {%s}", n1, names1)
   local spot = end1.location.position
   local support = make(ctx, "rail-support", spot, end1.location.direction)
   out(ctx, "support at the last carried end %s facing %s", pos_str(spot, center), dir_name(end1.location.direction))
   if support then
      local n2, _, names2 = turn_right(end1)
      out(ctx, "after the support, turning right: %d more pieces {%s}", n2, names2)
   end
   clear_around(ctx, center, 50)
end

---Run the probes and write the report
---@param pindex integer
---@param round string? "1" to "4" to run one round only; nil runs everything
---@return integer errors, string filename
function mod.run(pindex, round)
   local scratch = ScratchSurface.create("fa-elevated-probe", {
      half_size = AREA,
      water_x_min = WATER_X_MIN,
      water_x_max = WATER_X_MAX,
   })

   ---@type fa.ElevProbe.Ctx
   local ctx = { lines = {}, errors = 0, surface = scratch.surface, force = scratch.force }
   out(ctx, "# FactorioAccess elevated rails probe, tick %d, player %d, round %s", game.tick, pindex, round or "all")
   out(ctx, "Positions in extension lists are relative to the rail they belong to.")

   local sections = {
      { "1", "meta (prototypes, research, feature flag)", probe_meta },
      { "1", "E8 E11 E2a: ends and extensions of every piece", probe_extensions },
      { "1", "E10: research flag and extensions", probe_research_flag },
      { "1", "E2b: unsupported elevated rail and ghosts", probe_unsupported },
      { "1", "E4 E5: ramp and support coverage, support snapping", probe_coverage },
      { "2", "E4b E4c: isolated pieces carried by one support (+ accepted, - refused)", probe_isolated_coverage },
      { "1", "E3: stacked signals and blueprint fields", probe_signals },
      { "2", "E3b: elevated-only signal, blueprint, building it on a stacked spot", probe_elevated_signal },
      { "2", "E5b K3: a whole elevated run as one blueprint, revive order", probe_blueprint_run },
      { "1", "E9: water", probe_water },
      { "3", "E12: how far ahead a standalone support may stand", probe_support_ahead },
      { "3", "E13: one-blueprint run revived in track order", probe_track_order_revive },
      { "3", "E14: elevated signals and supports", probe_signals_on_supports },
      { "4", "E15 E16: support k rails ahead, filled backwards then forwards; support direction", probe_backward_fill },
      { "4", "E17: one-blueprint run with two supports, revived in repeated passes", probe_fixpoint_revive },
      { "4", "E18: curves carried by a ramp and by a support", probe_curve_coverage },
   }
   for _, entry in ipairs(sections) do
      if not round or round == entry[1] then section(ctx, entry[2], entry[3]) end
   end

   out(ctx, "")
   out(ctx, "errors: %d", ctx.errors)

   local filename = "elevated-probe.txt"
   helpers.write_file(filename, table.concat(ctx.lines, "\n"), false)

   ScratchSurface.destroy(scratch)

   return ctx.errors, filename
end

return mod
