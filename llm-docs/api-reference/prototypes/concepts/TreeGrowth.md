# TreeGrowth

[TreePrototype](prototype:TreePrototype)s develop over time. To introduce visual fidelity, the shape of the plant is shrunk and distorted using a warp texture, and it slowly retracts back into its grown state.

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### growth_warp

Encodes the initial UV offset at a given pixel, used to sample [TreeGrowth::trunk_warp](prototype:TreeGrowth::trunk_warp).

The offset is calculated like in the following pseudocode: 
```
vec2 growthWarpLinear = vec2((growthWarp.r - 0.5) * 2 * pow(time, 2.546872), 0);
vec2 growthWarpQuadratic = (uv - vec2(0.3, 0.2)) * pow(growthWarp.g * pow(time, 4.06187), 2) * 1000;
vec2 growthWarpUVOffset = clamp(growthWarpLinear + growthWarpQuadratic + uv, 0, 1);
```

**Type:** `Sprite`

**Required:** Yes

### trunk_warp

Encodes the UV offset at a given pixel, used to sample the trunk texture, and [TreeGrowth::harvest_warp](prototype:TreeGrowth::harvest_warp).

The final UV is calculated like in the following pseudocode: 
```
vec2 trunkWarpLinear = (trunkWarp.rg - 0.5) * 2 * pow(time, 2.546872);
vec2 trunkUV = clamp(growthWarpUVOffset + trunkWarpLinear + growthWarpQuadratic, 0, 1);
```

See [TreeGrowth::growth_warp](prototype:TreeGrowth::growth_warp) for how `growthWarpQuadratic` and `growthWarpUVOffset` are calculated.

**Type:** `Sprite`

**Required:** Yes

### harvest_warp

Encodes the UV offset at a given pixel, used to sample the leaves texture.

The final UV is calculated like in the following pseudocode: 
```
vec2 harvestWarpLinear = (harvestWarp.rg - 0.5) * 2 * pow(time, 2.546872);
vec2 harvestUV = clamp(trunkUV + harvestWarpLinear, 0, 1);
```

See [TreeGrowth::trunk_warp](prototype:TreeGrowth::trunk_warp) for how `trunkUV` is calculated.

**Type:** `Sprite`

**Required:** Yes

### shadow_warp

Encodes the UV offset at a given pixel, used to sample the shadow texture.

The final UV is calculated like in the following pseudocode: 
```
vec2 shadowWarpLinear = (shadowWarp.rg - 0.5) * 2 * pow(time, 2.546872);
vec2 shadowUV = clamp(uv + shadowWarpLinear, 0, 1);
```

**Type:** `Sprite`

**Required:** Yes

### trunk_alpha

Encodes the point in time (0-1) since the plant started growing, at which a given pixel of the *trunk* texture becomes visible.

This is a grayscale texture where white is t=0 (beginning of growth) and black is t=1 (end of growth).

**Type:** `Sprite`

**Required:** Yes

### harvest_alpha

Encodes the point in time (0-1) since the plant started growing, at which a given pixel of the *leaves* texture becomes visible.

This is a grayscale texture where white is t=0 (beginning of growth) and black is t=1 (end of growth).

**Type:** `Sprite`

**Required:** Yes

### shadow_alpha

Encodes the point in time (0-1) since the plant started growing, at which a given pixel of the *shadow* texture becomes visible.

This is a grayscale texture where white is t=0 (beginning of growth) and black is t=1 (end of growth).

**Type:** `Sprite`

**Required:** Yes

### progress_exponent

Exponent for the easing function of the growth progress (progress ^ progressExponent) which is used by the growth animation.

**Type:** `float`

**Required:** Yes

