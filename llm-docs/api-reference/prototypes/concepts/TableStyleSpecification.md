# TableStyleSpecification

Root style: `"table"`

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"table_style"`

**Required:** Yes

### horizontal_spacing

Required on the root style.

**Type:** `int32` | Array[`SpacingItem`]

**Optional:** Yes

### vertical_spacing

Required on the root style.

**Type:** `int32` | Array[`SpacingItem`]

**Optional:** Yes

### cell_padding

Sets `top_cell_padding`, `right_cell_padding`, `bottom_cell_padding` and `left_cell_padding` to the same value.

**Type:** `int16`

**Optional:** Yes

### top_cell_padding

**Type:** `int16`

**Optional:** Yes

**Default:** 0

### right_cell_padding

**Type:** `int16`

**Optional:** Yes

**Default:** 0

### bottom_cell_padding

**Type:** `int16`

**Optional:** Yes

**Default:** 0

### left_cell_padding

**Type:** `int16`

**Optional:** Yes

**Default:** 0

### apply_row_graphical_set_per_column

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### wide_as_column_count

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### column_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### default_row_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### even_row_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### odd_row_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### hovered_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### clicked_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### selected_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### selected_hovered_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### selected_clicked_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### background_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "Not drawn"

### column_alignments

**Type:** Array[`ColumnAlignment`]

**Optional:** Yes

### column_widths

**Type:** `ColumnWidthItem` | Array[`ColumnWidth`]

**Optional:** Yes

### hovered_row_color

**Type:** `Color`

**Optional:** Yes

**Default:** "`{0, 0, 0, 0}`"

### selected_row_color

**Type:** `Color`

**Optional:** Yes

**Default:** "`{110, 110, 110}`"

### vertical_line_color

**Type:** `Color`

**Optional:** Yes

**Default:** "`{110, 110, 110}`"

### horizontal_line_color

**Type:** `Color`

**Optional:** Yes

**Default:** "`{0, 0, 0, 0}`"

### column_ordering_ascending_button_style

**Type:** `ButtonStyleSpecification`

**Optional:** Yes

### column_ordering_descending_button_style

**Type:** `ButtonStyleSpecification`

**Optional:** Yes

### inactive_column_ordering_ascending_button_style

**Type:** `ButtonStyleSpecification`

**Optional:** Yes

### inactive_column_ordering_descending_button_style

**Type:** `ButtonStyleSpecification`

**Optional:** Yes

### border

Required on the root style.

**Type:** `BorderImageSet`

**Optional:** Yes

