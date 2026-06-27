# ProgressBarStyleSpecification

Root style: `"progressbar"`

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"progressbar_style"`

**Required:** Yes

### bar_width

The thickness of the bar, not the horizontal size.

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### other_colors

Required on the root style.

**Type:** Array[`OtherColors`]

**Optional:** Yes

### bar

Required on the root style.

**Type:** `ElementImageSet`

**Optional:** Yes

### bar_background

Required on the root style.

**Type:** `ElementImageSet`

**Optional:** Yes

### font

Name of a [FontPrototype](prototype:FontPrototype).

Required on the root style.

**Type:** `string`

**Optional:** Yes

### font_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### filled_font_color

**Type:** `Color`

**Optional:** Yes

**Default:** "Uses font_color for all text"

### embed_text_in_bar

Required on the root style.

**Type:** `boolean`

**Optional:** Yes

### side_text_padding

Required on the root style.

**Type:** `int16`

**Optional:** Yes

