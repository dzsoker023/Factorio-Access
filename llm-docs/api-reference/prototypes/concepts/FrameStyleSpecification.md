# FrameStyleSpecification

Root style: `"frame"`

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"frame_style"`

**Required:** Yes

### graphical_set

Required on the root style.

**Type:** `ElementImageSet`

**Optional:** Yes

### horizontal_flow_style

Required on the root style.

**Type:** `HorizontalFlowStyleSpecification`

**Optional:** Yes

### vertical_flow_style

Required on the root style.

**Type:** `VerticalFlowStyleSpecification`

**Optional:** Yes

### header_flow_style

Required on the root style.

**Type:** `HorizontalFlowStyleSpecification`

**Optional:** Yes

### header_filler_style

Required on the root style.

**Type:** `EmptyWidgetStyleSpecification`

**Optional:** Yes

### title_style

Required on the root style.

**Type:** `LabelStyleSpecification`

**Optional:** Yes

### use_header_filler

Required on the root style.

**Type:** `boolean`

**Optional:** Yes

### drag_by_title

Required on the root style.

**Type:** `boolean`

**Optional:** Yes

### header_background

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "not drawn"

### background_graphical_set

**Type:** `ElementImageSet`

**Optional:** Yes

**Default:** "not drawn"

### border

Required on the root style.

**Type:** `BorderImageSet`

**Optional:** Yes

