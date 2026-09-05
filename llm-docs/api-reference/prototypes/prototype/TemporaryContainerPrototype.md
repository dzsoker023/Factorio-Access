# TemporaryContainerPrototype

A container that can automatically destroy itself when it is emptied or after it has existed for a certain time.

**Parent:** [ContainerPrototype](ContainerPrototype.md)
**Type name:** `temporary-container`

## Properties

### destroy_on_empty

Whether the container is automatically destroyed when it is emptied.

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### time_to_live

Duration after which the container and its contents are automatically destroyed. In ticks, 0 for infinite.

**Type:** `uint32`

**Optional:** Yes

**Default:** 0

### alert_after_time

If the container has existed for this long, [an alert](prototype:UtilitySprites::unclaimed_cargo_icon) is show on it. In ticks, 0 for no alert.

**Type:** `uint32`

**Optional:** Yes

**Default:** 0

