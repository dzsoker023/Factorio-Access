# BlueprintLogisticFilter

**Type:** Table

## Parameters

### comparator

The comparator for quality. `nil` if any quality.

**Type:** `ComparatorString`

**Optional:** Yes

### count

**Type:** `int32`

**Required:** Yes

### import_from

**Type:** `string`

**Optional:** Yes

### index

**Type:** `LogisticFilterIndex`

**Required:** Yes

### max_count

**Type:** `ItemCountType`

**Optional:** Yes

### minimum_delivery_count

Defaults to `0`.

**Type:** `ItemCountType`

**Optional:** Yes

### name

Name of the logistic filter.

**Type:** `string`

**Optional:** Yes

### quality

The prototype name of the quality. `nil` for any quality.

**Type:** `string`

**Optional:** Yes

### request_from

From which sources items should be requested for space platforms. Defaults to `"planet"`.

**Type:** `RequestFromLocation`

**Optional:** Yes

### type

The type of the logistic filter.

**Type:** `SignalIDType`

**Optional:** Yes

