for name, proto in pairs(data.raw.container) do
   proto.open_sound = proto.open_sound or { filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.43 }
   proto.close_sound = proto.close_sound or { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.43 }
end

---Apply universal belt immunity
data.raw.character.character.has_belt_immunity = true

---Make the character unlikely to be selected by the mouse pointer when overlapping with entities
data.raw.character.character.selection_priority = 2

-- Modifications to Kruise Kontrol inputs (no longer needed)
-- We will handle Kruise Kontrol driving through the remote API.  It binds
-- everything to the mouse, which we don't use.  The exception is enter, which
-- cancels.  We also cancel on enter, but double-cancel doesn't do anything.
-- This file used to modify those inputs, but we don't need to since things
-- already work.  If we do need to revisit that, note that we will need to move
-- KK inputs to a dummy key, or alternatively try setting [alt]_key_sequence to
-- the empty string.  Other solutions (e.g. removal, setting them to disabled)
-- break KK because Factorio will not let KK register events.

--Modifications to Pavement Driving Assist Continued inputs
data:extend({
   {
      type = "custom-input",
      name = "toggle_drive_assistant",
      key_sequence = "L",
      consuming = "game-only",
   },
   {
      type = "custom-input",
      name = "toggle_cruise_control",
      key_sequence = "O",
      consuming = "game-only",
   },
   {
      type = "custom-input",
      name = "set_cruise_control_limit",
      key_sequence = "CONTROL + O",
      consuming = "game-only",
   },
   {
      type = "custom-input",
      name = "confirm_set_cruise_control_limit",
      key_sequence = "",
      linked_game_control = "confirm-gui",
   },
})

--[[
NOTE on vanilla's "previous-surface"/"next-surface" controls (Up/Down in remote view,
which conflicts with vehicle steering during remote driving - see changelog):

These are NOT data.raw["custom-input"] prototypes - confirmed by a live diagnostic dump
that also checked known comparison controls (toggle-menu/Escape, toggle-driving, build,
mine, confirm-gui): NONE of them exist in data.raw either. So this isn't specific to the
surface controls - essentially every built-in vanilla control (the whole LinkedGameControl
list) lives outside data.raw entirely, and data-stage Lua genuinely cannot rebind any of
them. linked_game_control only lets a mod's OWN new custom-input additionally trigger a
built-in action - it can't touch the built-in's own default key.

The real, working lever turned out to be a different file entirely: Factorio's own
config.ini (Roaming/Factorio/config/config.ini), which has a [controls] section storing
"control-name=KEY" lines for whichever controls have ever been customized (e.g. this
installation already had toggle-menu=SHIFT + ESCAPE there from some earlier change - not
this mod's doing). next-surface/previous-surface weren't listed there yet (never
customized), but simply adding them works the same as changing them in Settings >
Controls. This has been done directly on the user's config.ini as a one-off (NOT
something this mod's data stage can do at data-stage time, so it's not automated here -
see the changelog for exactly what was added and why).
]]

--Modify base prototypes to remove their default descriptions
--(science packs became plain items in 2.1, so they live in data.raw.item now)
for name, pack in pairs(data.raw.item) do
   if pack.localised_description and pack.localised_description[1] == "item-description.science-pack" then
      pack.localised_description = nil
   end
end

for name, mod in pairs(data.raw.module) do
   if
      mod.localised_description and mod.localised_description[1] == "item-description.effectivity-module"
      or mod.localised_description and mod.localised_description[1] == "item-description.productivity-module"
      or mod.localised_description and mod.localised_description[1] == "item-description.speed-module"
   then
      mod.localised_description = nil
   end
end

---Make selected vanilla objects not collide with players
local function remove_player_collision(ent_p)
   --todo: this won't work for entities that don't have their collision_mask defined since the vanilla default collision mask include the player.
   (ent_p.collision_mask or {})["player"] = nil
end
for _, ent_type in pairs({ "pipe", "pipe-to-ground", "constant-combinator", "inserter" }) do
   for _, ent_p in pairs(data.raw[ent_type]) do
      remove_player_collision(ent_p)
   end
end
--TODO:should probably just filter electric poles by their collision_box size...
remove_player_collision(data.raw["electric-pole"]["small-electric-pole"])
remove_player_collision(data.raw["electric-pole"]["medium-electric-pole"])
