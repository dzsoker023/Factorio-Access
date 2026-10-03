---Surface Helper for Rails
---
---Provides convenient access to GameSurface with rail planner descriptions

local GameSurface = require("railutils.surface-impls.game-surface")

local mod = {}

---Which description field each rail prototype type fills
local FIELD_OF_TYPE = {
   ["straight-rail"] = "straight_rail_name",
   ["curved-rail-a"] = "curved_rail_a_name",
   ["curved-rail-b"] = "curved_rail_b_name",
   ["half-diagonal-rail"] = "half_diagonal_rail_name",
   ["elevated-straight-rail"] = "elevated_straight_rail_name",
   ["elevated-curved-rail-a"] = "elevated_curved_rail_a_name",
   ["elevated-curved-rail-b"] = "elevated_curved_rail_b_name",
   ["elevated-half-diagonal-rail"] = "elevated_half_diagonal_rail_name",
   ["rail-ramp"] = "ramp_name",
}

---Fields needed to build elevated rails
local ELEVATED_FIELDS = {
   "elevated_straight_rail_name",
   "elevated_curved_rail_a_name",
   "elevated_curved_rail_b_name",
   "elevated_half_diagonal_rail_name",
   "ramp_name",
   "support_name",
}

---Whether a planner description can build elevated rails
---@param description railutils.RailPlannerDescription
---@return boolean
function mod.has_elevated(description)
   return description.ramp_name ~= nil
end

---Extract rail planner description from a rail planner item prototype
---@param rail_planner_prototype LuaItemPrototype
---@return railutils.RailPlannerDescription|nil
function mod.get_planner_description(rail_planner_prototype)
   if not rail_planner_prototype.rails then return nil end

   local rails = rail_planner_prototype.rails

   -- Map rail prototypes to the description structure
   -- Rails array contains LuaEntityPrototype objects for each rail type
   local description = {
      straight_rail_name = nil,
      curved_rail_a_name = nil,
      curved_rail_b_name = nil,
      half_diagonal_rail_name = nil,
   }

   for _, rail_proto in ipairs(rails) do
      local field = FIELD_OF_TYPE[rail_proto.type]
      if field then description[field] = rail_proto.name end
   end

   -- Elevated support is all or nothing: a planner that can only build some of the pieces cannot build a bridge
   local support = rail_planner_prototype.support
   description.support_name = support and support.name or nil
   local has_elevated = true
   for _, field in ipairs(ELEVATED_FIELDS) do
      if not description[field] then has_elevated = false end
   end
   if not has_elevated then
      for _, field in ipairs(ELEVATED_FIELDS) do
         description[field] = nil
      end
   end

   -- Validate we got all rail types
   if
      not description.straight_rail_name
      or not description.curved_rail_a_name
      or not description.curved_rail_b_name
      or not description.half_diagonal_rail_name
   then
      return nil
   end

   return description
end

---Wrap a surface for rail queries using the player's current rail planner
---@param surface LuaSurface
---@param player LuaPlayer
---@return railutils.GameSurface|nil
function mod.wrap_surface_for_player(surface, player)
   if not player.cursor_stack or not player.cursor_stack.valid_for_read then return nil end

   local prototype = player.cursor_stack.prototype
   if not prototype.rails then return nil end

   local planner_description = mod.get_planner_description(prototype)
   if not planner_description then return nil end

   return GameSurface.wrap_surface(surface, {
      planner_description = planner_description,
   })
end

---Vanilla rail names, with the elevated ones and the ramp when they exist (Space Age or the elevated rails mod)
---@return railutils.RailPlannerDescription
local function vanilla_description()
   local description = {
      straight_rail_name = "straight-rail",
      curved_rail_a_name = "curved-rail-a",
      curved_rail_b_name = "curved-rail-b",
      half_diagonal_rail_name = "half-diagonal-rail",
   }
   local elevated = {
      elevated_straight_rail_name = "elevated-straight-rail",
      elevated_curved_rail_a_name = "elevated-curved-rail-a",
      elevated_curved_rail_b_name = "elevated-curved-rail-b",
      elevated_half_diagonal_rail_name = "elevated-half-diagonal-rail",
      ramp_name = "rail-ramp",
      support_name = "rail-support",
   }
   for field, name in pairs(elevated) do
      if not prototypes.entity[name] then return description end
   end
   for field, name in pairs(elevated) do
      description[field] = name
   end
   return description
end

---Wrap a surface for rail queries using vanilla rail names (both layers when elevated rails exist)
---@param surface LuaSurface
---@return railutils.GameSurface
function mod.wrap_surface_vanilla(surface)
   return GameSurface.wrap_surface(surface, {
      planner_description = vanilla_description(),
   })
end

---Wrap a surface for ghost rail queries using vanilla rail names (both layers when elevated rails exist)
---@param surface LuaSurface
---@return railutils.GameSurface
function mod.wrap_surface_vanilla_ghosts(surface)
   return GameSurface.wrap_surface(surface, {
      planner_description = vanilla_description(),
      ghosts_only = true,
   })
end

return mod
