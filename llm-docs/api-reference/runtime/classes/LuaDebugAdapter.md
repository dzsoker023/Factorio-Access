# LuaDebugAdapter

Factorio provides a [Debug Adapter](https://microsoft.github.io/debug-adapter-protocol/overview) for compatible tools in single-session mode on stdin/stdout when launched with the `--dap` command line argument.

The Debug Adapter supports a Launch request with the following arguments:

- `factorioArgs` :: array[[string](runtime:string)]? : Command line arguments for the debug session

- `followSymlinks` :: [boolean](runtime:boolean)? : Follow symlinks when emitting locations (stack traces, etc) (default: true)

- `tags` :: [Any](runtime:Any)? : Extra debug session tags, see also [tags](runtime:LuaDebugAdapter::tags)

Metatable methods may be used to customize debug views:

- `__tostring`(`self`) -> [string](runtime:string) : Called when the object appears as a value.

- `__debugcounts`(`self`) -> `indexedVariables` :: [int32](runtime:int32) , `namedVariables` :: [int32](runtime:int32) : Called when the object appears in a parent object's listing, to estimate the size of this object's listing, and enabled paged listing for large indexed objects.

- `__debugchildren`(`self`, `filters` :: [DebugVariablesFilter](runtime:DebugVariablesFilter)) -> array([DebugVariable](runtime:DebugVariable)) : Called when the object itself is opened for a debug listing. If `__debugcounts` was implemented, the client may choose to fetch Indexed and Named children separately, and Indexed children in pages as-needed for display. See also [describe_field](runtime:LuaDebugAdapter::describe_field).

This class also provides debug session APIs, as the global object `debugadapter` in all stages.

## Attributes

### tags

The value from the `tags` property of the current session's launch request

**Read type:** `AnyBasic`

### valid

Is this object valid? This Lua object holds a reference to an object within the game engine. It is possible that the game-engine object is removed whilst a mod still holds the corresponding Lua object. If that happens, the object becomes invalid, i.e. this attribute will be `false`. Mods are advised to check for object validity if any change to the game state might have occurred between the creation of the Lua object and its access.

**Read type:** `boolean`

### object_name

The class name of this object. Available even when `valid` is false. For LuaStruct objects it may also be suffixed with a dotted path to a member of the struct.

**Read type:** `string`

## Methods

### start_profile

Start recording profiler timings. If there is a previous recording session running, it will be stopped first.

**Parameters:**

- `show_hook_events` `boolean` *(optional)* - Include events to indicate time spent in hooks

### stop_profile

Stop recording profiler timings and save to script_output.

### describe_field

Prepare a default debug view entry for a field, to assist in preparing custom listings.

**Parameters:**

- `name` `string` - The name of the field
- `value` `Any` - The value of the field

**Returns:**

- `DebugVariable`

