# CargoBayConnections

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### tileset

An array of LayeredSpriteVariations groups. One tile can have a maximum of two groups. A group is selected based on tile position and a random variation is picked from that group. This allows having interleaved variations and makes sure the same variation isn't picked for surrounding tiles.

Supports at most 255 items.

**Type:** Array[Array[`LayeredSpriteVariations`]]

**Optional:** Yes

### tileset_mapping

A mapping from a bitmask index to a tileset index. A bitmask index mapped to 0 won't be drawn.

Tile bitmask uses 8 bits. Bits are assigned from the top-left corner and going clockwise (top-left tile has bit 0 and right tile has bit 7).

Mandatory if `tileset` is defined.

**Type:** Dictionary[`uint8`, `uint8` | Array[`uint8`]]

**Optional:** Yes

### bridge_horizontal_narrow

**Type:** `LayeredSpriteVariations`

**Optional:** Yes

### bridge_horizontal_wide

**Type:** `LayeredSpriteVariations`

**Optional:** Yes

### bridge_vertical_narrow

**Type:** `LayeredSpriteVariations`

**Optional:** Yes

### bridge_vertical_wide

**Type:** `LayeredSpriteVariations`

**Optional:** Yes

### bridge_crossing

**Type:** `LayeredSpriteVariations`

**Optional:** Yes

