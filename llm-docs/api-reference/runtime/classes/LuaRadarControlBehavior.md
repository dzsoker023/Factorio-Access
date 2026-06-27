# LuaRadarControlBehavior

Control behavior for radars

**Parent:** [LuaControlBehavior](LuaControlBehavior.md)

## Attributes

### mode

Whether this radar is in universe (channel) or surface mode.

**Read type:** `defines.control_behavior.radar.mode`

**Write type:** `defines.control_behavior.radar.mode`

### universe_channel

The channel that is used in universe mode. Radars on the same force with the same channel in universe mode are connected to each other with hidden radar wires.

If the channel is empty or a [parameter](runtime:LuaPrototypeBase::parameter), the radar will be disconnected.

**Read type:** `SignalID`

**Write type:** `SignalID`

**Optional:** Yes

### valid

Is this object valid? This Lua object holds a reference to an object within the game engine. It is possible that the game-engine object is removed whilst a mod still holds the corresponding Lua object. If that happens, the object becomes invalid, i.e. this attribute will be `false`. Mods are advised to check for object validity if any change to the game state might have occurred between the creation of the Lua object and its access.

**Read type:** `boolean`

### object_name

The class name of this object. Available even when `valid` is false. For LuaStruct objects it may also be suffixed with a dotted path to a member of the struct.

**Read type:** `string`

