# LabelStyleSpecification

Root style: `"label"`

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"label_style"`

**Required:** Yes

### font

Name of a [FontPrototype](prototype:FontPrototype).

Required on the root style.

**Type:** `string`

**Optional:** Yes

### font_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### hovered_font_color

**Type:** `Color`

**Optional:** Yes

**Default:** "Value of `font_color`"

### game_controller_hovered_font_color

**Type:** `Color`

**Optional:** Yes

**Default:** "Value of `font_color`"

### clicked_font_color

**Type:** `Color`

**Optional:** Yes

**Default:** "Value of `font_color`"

### disabled_font_color

**Type:** `Color`

**Optional:** Yes

**Default:** "Value of `font_color`"

### parent_hovered_font_color

**Type:** `Color`

**Optional:** Yes

**Default:** "Value of `font_color`"

### rich_text_setting

Required on the root style.

**Type:** `RichTextSetting`

**Optional:** Yes

### single_line

Required on the root style.

**Type:** `boolean`

**Optional:** Yes

### underlined

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### rich_text_highlight_error_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### rich_text_highlight_warning_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### rich_text_highlight_ok_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

