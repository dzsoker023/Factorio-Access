# TileCollisionMaskConnector

The base game provides common collision mask functions in a Lua file in the core [lualib](https://github.com/wube/factorio-data/blob/master/core/lualib/collision-mask-util.lua).

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### layers

Every key in the dictionary is the name of one [layer](prototype:CollisionLayerPrototype) the object collides with. The value is meaningless and always `true`. An empty table means that no layers are set.

**Type:** Dictionary[`CollisionLayerID`, `True`]

**Required:** Yes

