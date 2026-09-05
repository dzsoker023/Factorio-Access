# Factorio JSON to Markdown Converter

This script converts Factorio's JSON API documentation into organized, human-readable markdown files.

## Usage

### Convert Runtime API Documentation

```bash
python json_to_markdown.py --type runtime \
    --input path/to/runtime-api.json \
    --output path/to/output/directory
```

### Convert Prototype API Documentation

```bash
python json_to_markdown.py --type prototype \
    --input path/to/prototype-api.json \
    --output path/to/output/directory
```

## Example

From the FactorioAccess mod directory (the JSON dumps ship with the Factorio
install at `../../doc-html/` and update when you upgrade the game):

```bash
# Convert runtime docs
python json_to_markdown.py \
    --type runtime \
    --input ../../doc-html/runtime-api.json \
    --output llm-docs/api-reference

# Convert prototype docs
python json_to_markdown.py \
    --type prototype \
    --input ../../doc-html/prototype-api.json \
    --output llm-docs/api-reference
```

**Note:** the generator only creates and overwrites files; it never deletes.
To pick up APIs removed by a game upgrade (so `git diff` shows the deletions),
clear the generated subdirs first, preserving the hand-written
`llm-docs/api-reference/CLAUDE.md`:

```bash
git rm -r --quiet llm-docs/api-reference/runtime llm-docs/api-reference/prototypes
# ...then run the two commands above and `git add -A llm-docs/api-reference`
```

## Output Structure

### Runtime API

```
output/
├── runtime/
│   ├── classes/
│   │   ├── LuaEntity.md
│   │   ├── LuaPlayer.md
│   │   └── ...
│   ├── concepts/
│   │   ├── Position.md
│   │   └── ...
│   ├── events/
│   │   ├── on_tick.md
│   │   └── ...
│   ├── defines/
│   │   ├── index.md
│   │   ├── alert_type.md
│   │   └── ...
│   ├── builtin_types/
│   │   └── ...
│   └── metadata.md
```

### Prototype API

```
output/
├── prototypes/
│   ├── prototype/
│   │   ├── TransportBeltPrototype.md
│   │   ├── ItemPrototype.md
│   │   └── ...
│   ├── concepts/
│   │   └── ...
│   └── metadata.md
```

## Features

- **Complete conversion**: Captures ALL information from the JSON docs
- **Organized structure**: Files organized by type (classes, prototypes, concepts, etc.)
- **Human-readable**: Clean markdown formatting with proper headings and tables
- **Cross-references**: Links to related classes/prototypes preserved
- **Type formatting**: Complex types (unions, arrays, tuples) formatted clearly
- **Metadata preservation**: All optional/required flags, defaults, examples, etc. included

## Statistics

For Factorio 2.0.73:
- **Runtime API**: 933 files (148 classes, 417 concepts, 219 events, 60 defines)
- **Prototype API**: 965 files (278 prototypes, 686 types/concepts)
- **Total**: 1898 markdown files

## Requirements

- Python 3.6+
- No external dependencies (uses only standard library)
