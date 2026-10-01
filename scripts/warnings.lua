--Here: functions about the warnings menu
local LightningZones = require("scripts.lightning-zones")
local Viewpoint = require("scripts.viewpoint")
local Speech = require("scripts.speech")
local MessageBuilder = Speech.MessageBuilder

local mod = {}

local WARNING_TYPES = {
   NO_FUEL = "no-fuel",
   NO_MINABLE_RESOURCES = "no-minable-resources",
   NO_POWER = "no-power",
   NO_RECIPE = "no-recipe",
   NOT_CONNECTED = "not-connected",
   LIGHTNING_HOLE = "lightning-hole",
   LIGHTNING_SHORE_GAP = "lightning-shore-gap",
   LIGHTNING_UNPROTECTED_BUILDING = "lightning-unprotected-building",
}

mod.WARNING_TYPES = WARNING_TYPES

---Turns a { position, label } entry from LightningZones.get_warning_entries
---into something the warnings menu can render as an "entity". It isn't a
---real LuaEntity - there's no entity to point at, only a spot in the world -
---so render_warnings (scripts/ui/menus/warnings.lua) checks is_synthetic and
---reads the ready-made label instead of trying to look up an entity name.
---valid/position/unit_number are set because those are the only fields the
---rest of the menu (distance sorting, click-to-jump, entity_key) touches.
---@param entry {position: MapPosition, label: LocalisedString}
local function synthetic_warning_entity(entry)
   return {
      valid = true,
      position = entry.position,
      unit_number = nil,
      is_synthetic = true,
      label = entry.label,
   }
end

--Warnings menu: scans for problems in the production network it defines and creates the warnings list.
function mod.scan_for_warnings(L, H, pindex)
   local surf = game.get_player(pindex).surface
   local pos = Viewpoint.get_viewpoint(pindex):get_cursor_pos()
   local area = { { pos.x - L, pos.y - H }, { pos.x + L, pos.y + H } }
   local ents = surf.find_entities_filtered({ area = area, type = entity_types })
   local warnings = {}
   warnings[WARNING_TYPES.NO_FUEL] = {}
   warnings[WARNING_TYPES.NO_MINABLE_RESOURCES] = {}
   warnings[WARNING_TYPES.NO_POWER] = {}
   warnings[WARNING_TYPES.NO_RECIPE] = {}
   warnings[WARNING_TYPES.NOT_CONNECTED] = {}
   warnings[WARNING_TYPES.LIGHTNING_HOLE] = {}
   warnings[WARNING_TYPES.LIGHTNING_SHORE_GAP] = {}
   warnings[WARNING_TYPES.LIGHTNING_UNPROTECTED_BUILDING] = {}
   for i, ent in pairs(ents) do
      if ent.prototype.burner_prototype ~= nil then
         local fuel_inv = ent.get_fuel_inventory()
         if ent.energy == 0 and (fuel_inv == nil or (fuel_inv and fuel_inv.valid and fuel_inv.is_empty())) then
            table.insert(warnings[WARNING_TYPES.NO_FUEL], ent)
         end
      end

      if ent.prototype.electric_energy_source_prototype ~= nil and ent.is_connected_to_electric_network() == false then
         table.insert(warnings[WARNING_TYPES.NOT_CONNECTED], ent)
      elseif ent.prototype.electric_energy_source_prototype ~= nil and ent.energy == 0 then
         table.insert(warnings[WARNING_TYPES.NO_POWER], ent)
      end
      local recipe = nil
      if pcall(function()
         recipe = ent.get_recipe()
      end) then
         if recipe == nil and ent.type ~= "furnace" then table.insert(warnings[WARNING_TYPES.NO_RECIPE], ent) end
      end

      if ent.type == "mining-drill" and ent.status == defines.entity_status.no_minable_resources then
         table.insert(warnings[WARNING_TYPES.NO_MINABLE_RESOURCES], ent)
      end
   end

   -- Fulgora lightning-protection gaps, read from the grid cached at the
   -- last End refresh (see lightning-zones.lua and the changelog section
   -- "Fulgora lightning-attractor coverage grid"). Not entity-based like the
   -- warnings above - these are synthetic "positions" wrapped to look enough
   -- like an entity for the shared rendering code. Filtered to the same
   -- L,H box as everything else here for consistent behavior.
   do
      local holes, shore_gaps = LightningZones.get_warning_entries(surf)
      if holes then
         for _, entry in ipairs(holes) do
            local ex, ey = entry.position.x, entry.position.y
            if ex >= area[1][1] and ex <= area[2][1] and ey >= area[1][2] and ey <= area[2][2] then
               table.insert(warnings[WARNING_TYPES.LIGHTNING_HOLE], synthetic_warning_entity(entry))
            end
         end
      end
      if shore_gaps then
         for _, entry in ipairs(shore_gaps) do
            local ex, ey = entry.position.x, entry.position.y
            if ex >= area[1][1] and ex <= area[2][1] and ey >= area[1][2] and ey <= area[2][2] then
               table.insert(warnings[WARNING_TYPES.LIGHTNING_SHORE_GAP], synthetic_warning_entity(entry))
            end
         end
      end
   end

   -- [LIGHTNING-BUILDING] A real, placed building standing on unprotected
   -- ground - reported directly, as the building itself, rather than as a
   -- gap in the terrain. This catches cases LIGHTNING_HOLE/LIGHTNING_SHORE_GAP
   -- structurally cannot: build_grid only bothers computing holes/shore gaps
   -- for an island with 2+ real (rod/collector) attractors (see
   -- lightning-zones.lua - a single circle can't have an interior hole, and a
   -- lone-attractor shore-gap warning on every minor scrap patch would be
   -- pure noise), so a building sitting on an island with 0 or 1 real
   -- attractors - e.g. alone in the middle of a scrap island with no
   -- collector anywhere near it - never produces a hole/shore-gap entry at
   -- all, even though the building itself is 100% unprotected right now.
   -- Checking every real building against LightningZones.is_covered directly
   -- sidesteps that threshold entirely: it doesn't care about islands or
   -- attractor counts, only "is this exact tile inside some circle".
   --
   -- Uses the `building_types` global (populated in control.lua from every
   -- prototype with is_building = true, same pattern as `entity_types` just
   -- above) rather than `entity_types`, because entity_types is scoped to
   -- burner/electric/ammo prototypes + container for the fuel/power/recipe
   -- warnings above - a plain wall, rail signal, or beacon has no fuel or
   -- power source but can still be struck by lightning and is worth warning
   -- about. "character" is excluded even though building_types includes it
   -- (for an unrelated reason - see control.lua) - the player themselves is
   -- not a building and checking them would be both nonsensical and, since
   -- the player is virtually always somewhere on the map, extremely noisy.
   --
   -- is_covered returns nil (not false) when this surface has no lightning
   -- grid at all (no attractors anywhere, or End never pressed) - only an
   -- explicit `false` counts as "confirmed unprotected", so this is silently
   -- a no-op everywhere except Fulgora islands that actually have a grid.
   --
   -- [LIGHTNING-BUILDING-FORCE-FIX] `building_types` (is_building == true on
   -- the prototype) turned out to be broader than "things the player placed
   -- and might want protected": Fulgora's natural fulgurite/fulgurite-small
   -- ore deposits and the fulgoran-ruin-* decorations are ALSO flagged
   -- is_building on their prototypes (presumably for unrelated
   -- editor/blueprint reasons), so the first version of this warning fired
   -- on every unprotected rock and ruin scattered across a scrap island -
   -- not just actual player buildings, exactly the noise reported. Neither
   -- of those is something the player built or can meaningfully "protect"
   -- with an attractor. The fix: also require the entity's force to be the
   -- player's own force (same check as scripts/building-tools.lua:669's
   -- `ent.force == game.get_player(pindex).force`) - natural/neutral-force
   -- resources and decorations never match this, while every real built
   -- structure (including underground belts, walls, rail signals, etc.)
   -- always does. Passed straight to find_entities_filtered's own `force`
   -- parameter (like scripts/electrical.lua does) so the game does the
   -- filtering natively instead of a manual per-entity check in Lua.
   do
      local player_force = game.get_player(pindex).force
      local building_ents =
         surf.find_entities_filtered({ area = area, type = building_types, force = player_force })
      for _, ent in pairs(building_ents) do
         if ent.type ~= "character" and LightningZones.is_covered(surf, ent.position) == false then
            table.insert(warnings[WARNING_TYPES.LIGHTNING_UNPROTECTED_BUILDING], ent)
         end
      end
   end

   local result = {}
   local summary_message = MessageBuilder.new()
   local has_warnings = false

   for i, warning in pairs(warnings) do
      if #warning > 0 then
         has_warnings = true
         summary_message:list_item({ "fa.warning-type-" .. i })
         summary_message:fragment(tostring(#warning))
         table.insert(result, { name = i, ents = warning })
      end
   end

   local summary = summary_message:build()
   if not has_warnings then summary = { "fa.warnings-no-warnings-displayed" } end

   return { summary = summary, warnings = result }
end

return mod
