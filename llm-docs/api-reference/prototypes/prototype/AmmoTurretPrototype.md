# AmmoTurretPrototype

A turret that consumes [ammo items](prototype:AmmoItemPrototype).

**Parent:** [TurretPrototype](TurretPrototype.md)
**Type name:** `ammo-turret`

## Properties

### energy_source

**Type:** `ElectricEnergySource`

**Optional:** Yes

### energy_per_shot

**Type:** `Energy`

**Optional:** Yes

### inventory_size

Size of the ammo inventory.

**Type:** `ItemStackIndex`

**Required:** Yes

### automated_ammo_count

The amount of ammo that inserters automatically insert into this turret.

**Type:** `ItemCountType`

**Required:** Yes

### prepare_with_no_ammo

**Type:** `boolean`

**Optional:** Yes

**Default:** True

