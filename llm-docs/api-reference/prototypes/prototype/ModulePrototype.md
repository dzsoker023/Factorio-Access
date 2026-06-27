# ModulePrototype

A [module](https://wiki.factorio.com/Module). They are used to affect the capabilities of existing machines, for example by increasing the crafting speed of a [crafting machine](prototype:CraftingMachinePrototype).

**Parent:** [ItemPrototype](ItemPrototype.md)
**Type name:** `module`

## Properties

### category

Used when upgrading modules: Ctrl + click modules into an entity and it will replace lower tier modules of the same category with higher tier modules.

**Type:** `ModuleCategoryID`

**Required:** Yes

### tier

Tier of the module inside its category. Used when upgrading modules: Ctrl + click modules into an entity and it will replace lower tier modules with higher tier modules if they have the same category.

**Type:** `uint32`

**Required:** Yes

### effect

The effect of the module on the machine it's inserted in, such as increased pollution.

**Type:** `Effect`

**Required:** Yes

### requires_beacon_alt_mode

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### art_style

Chooses with what art style the module is shown inside [beacons](prototype:BeaconPrototype). See [BeaconModuleVisualizations::art_style](prototype:BeaconModuleVisualizations::art_style). Vanilla uses `"vanilla"` here.

**Type:** `string`

**Optional:** Yes

### beacon_tint

**Type:** `BeaconVisualizationTints`

**Optional:** Yes

### consumption_quality_multiplier

0.0 means that no quality scaling is applied (common for penalties). 1.0 means that the full scaling of the quality prototype applies.

Defaults to 1.0 if the module consumption effect is < 0, otherwise 0.0.

**Type:** `float`

**Optional:** Yes

### speed_quality_multiplier

0.0 means that no quality scaling is applied (common for penalties). 1.0 means that the full scaling of the quality prototype applies.

Defaults to 1.0 if the module speed effect is > 0, otherwise 0.0.

**Type:** `float`

**Optional:** Yes

### productivity_quality_multiplier

0.0 means that no quality scaling is applied (common for penalties). 1.0 means that the full scaling of the quality prototype applies.

Defaults to 1.0 if the module productivity effect is > 0, otherwise 0.0.

**Type:** `float`

**Optional:** Yes

### pollution_quality_multiplier

0.0 means that no quality scaling is applied (common for penalties). 1.0 means that the full scaling of the quality prototype applies.

Defaults to 1.0 if the module pollution effect is < 0, otherwise 0.0.

**Type:** `float`

**Optional:** Yes

### quality_quality_multiplier

0.0 means that no quality scaling is applied (common for penalties). 1.0 means that the full scaling of the quality prototype applies.

Defaults to 1.0 if the module quality effect is > 0, otherwise 0.0.

**Type:** `float`

**Optional:** Yes

