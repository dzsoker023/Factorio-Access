# GraphStyleSpecification

Root style: `"graph"`

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"graph_style"`

**Required:** Yes

### background_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### line_colors

Required on the root style.

**Type:** Array[`Color`]

**Optional:** Yes

### horizontal_label_style

Required on the root style.

**Type:** `LabelStyleSpecification`

**Optional:** Yes

### vertical_label_style

Required on the root style.

**Type:** `LabelStyleSpecification`

**Optional:** Yes

### minimal_horizontal_label_spacing

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### minimal_vertical_label_spacing

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### horizontal_labels_margin

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### vertical_labels_margin

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### graph_top_margin

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### graph_right_margin

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### data_line_highlight_distance

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### selection_dot_radius

Required on the root style.

**Type:** `uint32`

**Optional:** Yes

### grid_lines_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### guide_lines_color

Required on the root style.

**Type:** `Color`

**Optional:** Yes

### font

Name of a [FontPrototype](prototype:FontPrototype).

Required on the root style.

**Type:** `string`

**Optional:** Yes

