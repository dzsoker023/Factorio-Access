# on_gui_inventory_action

Called when a player interacts with a custom inventory GUI.

## Event Data

### action

**Type:** `defines.inventory_actions`

The action performed.

### alt

**Type:** `boolean`

If alt was pressed.

### button

**Type:** `defines.mouse_button_type`

The final mouse button used if any.

### control

**Type:** `boolean`

If control was pressed.

### element

**Type:** `LuaGuiElement`

The inventory element interacted with.

### item

**Type:** `LuaItemPrototype` *(optional)*

The item clicked on.

### item_number

**Type:** `uint32` *(optional)*

The item number clicked on (if it had one).

### name

**Type:** `defines.events`

Identifier of the event.

### player_index

**Type:** `uint32`

The player doing the action.

### quality

**Type:** `LuaQualityPrototype` *(optional)*

The item quality clicked on.

### shift

**Type:** `boolean`

If shift was pressed.

### slot

**Type:** `uint32`

The slot index that was interacted with.

### tick

**Type:** `MapTick`

Tick the event was generated.

