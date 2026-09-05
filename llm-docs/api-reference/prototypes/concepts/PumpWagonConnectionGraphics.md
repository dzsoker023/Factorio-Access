# PumpWagonConnectionGraphics

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### base_animation_finished_at_progress

Value between 0 and 1 (both exclusive). The base animation will play up until the connecting progress reaches the value. Needs to be less than `clamp_animation_starts_at_progress`. The arm (`part_1` and `part_2`) will rotate and extend in the time in between.

**Type:** `double`

**Optional:** Yes

**Default:** 0.5

### clamp_animation_starts_at_progress

Value between 0 and 1 (both exclusive). The clamp animation will play up starting when the connecting progress reaches the value. Needs to be larger than `base_animation_finished_at_progress`. The arm (`part_1` and `part_2`) will rotate and extend in the time in between.

**Type:** `double`

**Optional:** Yes

**Default:** 0.75

### height_diff_to_wagon

**Type:** `float`

**Optional:** Yes

**Default:** 0.15

### part2_crop_adjustment

Adjusts where the sprites will be cropped

**Type:** `float`

**Optional:** Yes

**Default:** -0.05

### part2_shadow_crop_adjustment

Adjusts where the sprites will be cropped

**Type:** `float`

**Optional:** Yes

**Default:** -0.05

### clamp_y_shift

**Type:** `float`

**Optional:** Yes

**Default:** -0.375

### base

**Type:** `BasePumpWagonConnectionAnimations`

**Optional:** Yes

### part_1

Rotating top part.

**Type:** `RotatedSprite`

**Optional:** Yes

### part_1_shadow

**Type:** `RotatedSprite`

**Optional:** Yes

### part_2

Rotating arm.

**Type:** `RotatedSprite`

**Optional:** Yes

### part_2_shadow

**Type:** `RotatedSprite`

**Optional:** Yes

### suction_clamp

**Type:** `Animation`

**Optional:** Yes

### suction_clamp_shadow

**Type:** `Animation`

**Optional:** Yes

### part1_to_2_shift

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0, 0}`"

### top_pivot_shift

Relative projected render position of `part_1` to the parent pump position.

**Type:** `PumpWagonConnectionShift4Way`

**Optional:** Yes

### resting_position_shift

Projected render rest position of `suction_clamp` relative to the parent pump position.

**Type:** `PumpWagonConnectionShift4Way`

**Optional:** Yes

### shadow_shift

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0.8, 1.55}`"

