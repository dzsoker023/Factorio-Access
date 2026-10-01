#!/usr/bin/env python3
"""
One-command updater for llm-docs/api-reference/.

Re-generates it from the JSON API docs that ship *inside the Factorio game
install itself* (doc-html/runtime-api.json and doc-html/prototype-api.json -
these are static files bundled with every Factorio install, not something
downloaded from the web, and they always match the exact engine version
installed - see json_to_markdown.py / README_json_to_markdown.md, which
already do the JSON -> markdown conversion this script wraps.

Usage:
    python update_api_docs.py
    python update_api_docs.py --factorio-root "C:\\Path\\To\\Factorio"
    python update_api_docs.py --clean

Why this exists: json_to_markdown.py already does the real conversion work,
but using it means remembering two multi-line commands, finding doc-html/
by hand, and (per its own README) separately deleting the old generated
tree first if you want removed API members to show up as deletions. This
wraps all of that into one command and prints an old-version -> new-version
report so it's obvious whether anything even changed.

Scope note: this only regenerates the per-page files under
llm-docs/api-reference/runtime/ and llm-docs/api-reference/prototypes/ (the
git-tracked, canonical output of json_to_markdown.py). It does NOT touch the
separate, larger consolidated files referenced from llm-docs/index.md
(classes.md, concepts.md, runtime-api.md, etc.) - those were assembled by
hand in an earlier session and have no automated generator yet.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
# Same assumption launch_factorio.py makes (FACTORIO_REL_PATH = "../../bin/x64/factorio.exe"):
# this file's mod folder is expected to sit directly inside the Factorio install root, i.e.
# a sibling of bin/, data/ and doc-html/. Checked first since it's the most specific guess
# for THIS repo (matches how launch_factorio.py is already wired up here).
RELATIVE_DEFAULT_ROOT = (SCRIPT_DIR / ".." / "..").resolve()

# Common Windows install locations, checked if the relative guess above doesn't pan out.
# Sources (Factorio Wiki, "Application directory" page):
#   - Steam default:      C:\Program Files (x86)\Steam\steamapps\common\Factorio
#   - Standalone/non-Steam Windows installer default: C:\Program Files\Factorio
#     (NOT "Program Files (x86)" - the standalone installer targets the 64-bit Program
#     Files dir despite what you might expect from other older Windows software).
WINDOWS_INSTALL_CANDIDATES = [
    Path(r"C:\Program Files\Factorio"),
    Path(r"C:\Program Files (x86)\Steam\steamapps\common\Factorio"),
]

OUTPUT_DIR = SCRIPT_DIR / "llm-docs" / "api-reference"
CONVERTER = SCRIPT_DIR / "json_to_markdown.py"


def candidate_roots():
    """Ordered, de-duplicated list of places to look for a Factorio install."""
    candidates = [RELATIVE_DEFAULT_ROOT, *WINDOWS_INSTALL_CANDIDATES]
    seen = set()
    result = []
    for c in candidates:
        try:
            key = c.resolve()
        except OSError:
            key = c
        if key in seen:
            continue
        seen.add(key)
        result.append(c)
    return result


def has_doc_html(root: Path) -> bool:
    return (root / "doc-html" / "runtime-api.json").exists() and (
        root / "doc-html" / "prototype-api.json"
    ).exists()


def choose_factorio_root():
    """Auto-detect a Factorio install among the known candidate locations.

    Returns (root_or_None, source_description, tried_candidates). If more than one
    candidate has a valid doc-html/ (e.g. a dev/manual install AND a separate Steam
    install both present - plausible for someone who keeps both a "dev" and a
    "player" copy), asks interactively which one to use rather than silently
    picking one.
    """
    tried = candidate_roots()
    found = [c for c in tried if has_doc_html(c)]

    if not found:
        return None, "auto-detect - none of the candidates had doc-html/", tried
    if len(found) == 1:
        return found[0], "auto-detected", tried

    print("Found more than one Factorio install with doc-html/:")
    for i, c in enumerate(found, 1):
        print(f"  {i}. {c}")

    if not sys.stdin.isatty():
        print(
            f"(not running interactively - defaulting to #1: {found[0]}; "
            "pass --factorio-root to pick a specific one instead)",
            file=sys.stderr,
        )
        return found[0], "auto-detected (non-interactive, first match)", tried

    while True:
        choice = input(f"Which one should I use? [1-{len(found)}]: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(found):
            return found[int(choice) - 1], "chosen interactively", tried
        print("Please enter a number from the list above.")


def read_current_version():
    """Best-effort read of the currently-generated docs' version line, for the report."""
    meta = OUTPUT_DIR / "runtime" / "metadata.md"
    if not meta.exists():
        return None
    try:
        text = meta.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped and ("version" in stripped.lower()):
            return stripped
    lines = text.splitlines()
    return lines[0].strip() if lines else None


def read_new_version(runtime_json: Path):
    data = json.loads(runtime_json.read_text(encoding="utf-8"))
    return data.get("application_version"), data.get("api_version")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--factorio-root",
        type=Path,
        default=None,
        help=(
            "Path to the Factorio install root (the folder that directly contains "
            "bin/, data/ and doc-html/). If omitted, auto-detects among a few common "
            "locations (the same relative guess launch_factorio.py makes, the standalone "
            "Windows installer default, and the Steam default) and, if more than one "
            "looks valid, asks interactively which to use."
        ),
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help=(
            "Delete the existing generated runtime/ and prototypes/ subfolders first, "
            "so API members removed by a game upgrade show up as deletions in "
            "`git status`/`git diff`, per README_json_to_markdown.md's own recommendation. "
            "Never touches the hand-written llm-docs/api-reference/CLAUDE.md."
        ),
    )
    args = parser.parse_args()

    tried = []
    if args.factorio_root is not None:
        factorio_root = args.factorio_root
        source = "given via --factorio-root"
    else:
        factorio_root, source, tried = choose_factorio_root()
        if factorio_root is None:
            # Nothing found anywhere we know to look - fall back to the relative guess
            # purely so the error message below has a sensible primary path to report.
            factorio_root = RELATIVE_DEFAULT_ROOT

    doc_html = factorio_root / "doc-html"
    runtime_json = doc_html / "runtime-api.json"
    prototype_json = doc_html / "prototype-api.json"

    missing = [p for p in (runtime_json, prototype_json) if not p.exists()]
    if missing:
        print("ERROR: could not find the Factorio JSON API docs.", file=sys.stderr)
        for p in missing:
            print(f"  missing: {p}", file=sys.stderr)
        if tried:
            print("\nAlso checked these common locations, none had a doc-html/ with both files:", file=sys.stderr)
            for c in tried:
                print(f"  {c}", file=sys.stderr)
        print(
            "\nThese ship inside the Factorio GAME install itself (doc-html/), which is "
            "usually a different folder from wherever this mod's files live (e.g. your "
            "Steam library vs. %APPDATA%\\Factorio\\mods). Pass --factorio-root pointing "
            "at the actual Factorio install directory, e.g.:\n"
            '  python update_api_docs.py --factorio-root '
            '"C:\\Program Files (x86)\\Steam\\steamapps\\common\\Factorio"',
            file=sys.stderr,
        )
        sys.exit(1)

    old_version = read_current_version()
    new_app_version, new_api_version = read_new_version(runtime_json)

    print(f"Factorio install ({source}): {factorio_root}")
    print(
        "Previously generated docs (llm-docs/api-reference/runtime/metadata.md): "
        f"{old_version or '(none found - first run?)'}"
    )
    print(f"New JSON docs report: application_version={new_app_version}, api_version={new_api_version}")

    if args.clean:
        for sub in ("runtime", "prototypes"):
            target = OUTPUT_DIR / sub
            if target.exists():
                print(f"Removing {target} ...")
                shutil.rmtree(target)

    for kind, src in (("runtime", runtime_json), ("prototype", prototype_json)):
        cmd = [
            sys.executable,
            str(CONVERTER),
            "--type",
            kind,
            "--input",
            str(src),
            "--output",
            str(OUTPUT_DIR),
        ]
        print(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            print(f"ERROR: {kind} conversion failed (exit code {result.returncode})", file=sys.stderr)
            sys.exit(result.returncode)

    print("\nDone. llm-docs/api-reference/ now reflects:")
    print(f"  {runtime_json}")
    print(f"  {prototype_json}")
    print(
        "\nNote: this only regenerates the per-page files under runtime/ and prototypes/. "
        "It does NOT touch the separately consolidated top-level files referenced from "
        "llm-docs/index.md (classes.md, concepts.md, runtime-api.md, etc.) - those were "
        "assembled by hand in an earlier session and have no automated generator yet."
    )
    print("Review with `git status` / `git diff` before committing, especially with --clean.")


if __name__ == "__main__":
    main()
