# ModData

Block of arbitrary data set by mods in prototype stage.

During runtime stage, this arbitrary data can be accessed through [LuaPrototypes::mod_data](runtime:LuaPrototypes::mod_data).

**Parent:** [Prototype](Prototype.md)
**Type name:** `mod-data`

## Examples

```
{
  type = "mod-data",
  name = "my-own-great-mod-data",
  data_type = "my-mod.my-data-type",
  data =
  {
    a_string = "a string",
    a_number = 6.7,
    a_table = {x=2, y=3, z="yes"},
    a_bool = true,
  }
}
```

## Properties

### data_type

Arbitrary string that mods can use to declare type of data. Can be used for mod compatibility when one mod declares block of data that is expected to be discovered by another mod.

**Type:** `string`

**Optional:** Yes

**Examples:**

```
data_type = "my-mod.my_structure"
```

### data

**Type:** Dictionary[`string`, `AnyBasic`]

**Required:** Yes

