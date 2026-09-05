# EntityTransferTipTrigger

Triggered when a player fast-transfers something to or from an entity, similar to the [on_player_fast_transferred](runtime:on_player_fast_transferred) event.

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"entity-transfer"`

**Required:** Yes

### transfer

Whether the transfer should be into or out of the player.

**Type:** `"in"` | `"out"`

**Optional:** Yes

**Default:** "any transfer"

