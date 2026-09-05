# ImageStyleSpecification

Root style: `"image"`

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"image_style"`

**Required:** Yes

### graphical_set

Required on the root style.

**Type:** `ElementImageSet`

**Optional:** Yes

### stretch_image_to_widget_size

Required on the root style.

**Type:** `boolean`

**Optional:** Yes

### invert_colors_of_picture_when_hovered_or_toggled

**Type:** `boolean`

**Optional:** Yes

**Default:** False

## Examples

```
```
data.raw["gui-style"]["default"]["stretchy-sprite"] =
{
  type = "image_style",
  vertically_stretchable = "on",
  horizontally_stretchable = "on",
  stretch_image_to_widget_size = true,
}
```
```

