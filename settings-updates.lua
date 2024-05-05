data:extend({
   {
      type = "int-setting",
      name = "VehicleSnap_amount",
      setting_type = "runtime-per-user",
      minimum_value = 4,
      default_value = 8,
   },
   {
      type = "string-setting",
      name = "aai-loaders-mode",
      setting_type = "startup",
      default_value = "expensive",
      allowed_values = { "lubricated", "expensive", "graphics-only" },
      order = "a",
   },
   {
      type = "bool-setting",
      name = "PDA-setting-smart-roads-enabled",
      setting_type = "startup",
      default_value = true,
      order = "ab",
   },
   {
      type = "int-setting",
      name = "PDA-setting-assist-min-speed",
      setting_type = "runtime-global",
      default_value = 9,
      minimum_value = 6,
      maximum_value = 10000,
      order = "d",
   },
})
