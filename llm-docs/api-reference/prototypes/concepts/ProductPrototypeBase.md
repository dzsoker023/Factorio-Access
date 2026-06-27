# ProductPrototypeBase

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### independent_probability

Value between 0 and 1. When a product has probability set, a probability roll is performed when trying to give product: if probability roll fails then product is not given. This value controls threshold of the independent probability roll, which means if there are multiple products to be given, they may use different roll value causing products to all be given, some of them given or none of them given at all.

**Type:** `double`

**Optional:** Yes

**Default:** 1

### shared_probability

A range of values where lower end is at at least at value of 0 and upper end is at most at value of 1. This range is used as part of shared probability test: When a set of products is attempted to be given, there is a single random generator roll performed that gives a value from range `[0, 1)`. This rolled value is compared to ranges of all products that are given at the same time. In order for the product to be given, the roll must test to be within this range, meaning `roll >= min && roll < max` must be true. If the test fails, then the product is not given.

Note: for a product to be given, both independent_probability test and shared_probability tests must pass. That means probability values seen in gui are equal to `independent_probability * (shared_probability.max - shared_probability.min)`

Note: ranges between different products are independent, that means they are allowed to overlap. This may be used to create set of products that are always given in pairs if ranges are equal or to make products that are given exclusively (one or the other) if the ranges do not overlap.

**Type:** `SharedProbabilityDefinition`

**Optional:** Yes

**Default:** "`{ min = 0, max = 1 }`"

### show_details_in_recipe_tooltip

When hovering over a recipe in the crafting menu the recipe tooltip will be shown. An additional item tooltip will be shown for every product, as a separate tooltip, if the item tooltip has a description and/or properties to show and if `show_details_in_recipe_tooltip` is `true`.

**Type:** `boolean`

**Optional:** Yes

**Default:** True

