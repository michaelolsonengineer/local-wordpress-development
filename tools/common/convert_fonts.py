#!/usr/bin/env python3
"""
convert_fonts.py

Given one or more font files (OTF or TTF), produces all missing web-font
variants alongside the source file:

    source.otf  →  source.ttf, source.woff, source.woff2
    source.ttf  →  source.woff, source.woff2

Already-present variants are skipped.

Requirements:
    python3-fonttools   (apt:  sudo apt-get install -y python3-fonttools)
    python3-brotli      (apt:  sudo apt-get install -y python3-brotli)
    -- OR --
    pip install fonttools brotli

Usage:
    python3 convert_fonts.py <font-file> [<font-file> ...]
    python3 convert_fonts.py path/to/AlphonseMucha.otf
"""

import sys
import os

try:
    from fontTools.ttLib import TTFont
except ModuleNotFoundError:
    sys.exit(
        "ERROR: fontTools not found.\n"
        "  Install with:  sudo apt-get install -y python3-fonttools python3-brotli\n"
        "           or:   pip install fonttools brotli"
    )

# Map of output flavor → file extension  (None = plain TTF binary)
VARIANTS = [
    (None,    ".ttf"),
    ("woff",  ".woff"),
    ("woff2", ".woff2"),
]


def convert(src_path: str) -> None:
    src_path = os.path.abspath(src_path)
    if not os.path.isfile(src_path):
        print(f"  SKIP (not found): {src_path}", file=sys.stderr)
        return

    base, ext = os.path.splitext(src_path)
    ext_lower = ext.lower()

    if ext_lower not in (".otf", ".ttf"):
        print(f"  SKIP (unsupported extension '{ext}'): {src_path}", file=sys.stderr)
        return

    print(f"Loading: {os.path.basename(src_path)}")
    font = TTFont(src_path)

    for flavor, out_ext in VARIANTS:
        # Don't overwrite the source file itself
        if out_ext == ext_lower and flavor is None:
            continue

        out_path = base + out_ext
        if os.path.isfile(out_path):
            print(f"  EXISTS  {os.path.basename(out_path)}")
            continue

        font.flavor = flavor
        try:
            font.save(out_path)
        except Exception as exc:  # noqa: BLE001
            print(f"  ERROR   {os.path.basename(out_path)}: {exc}", file=sys.stderr)
            # woff2 needs brotli; give a helpful hint
            if "brotli" in str(exc).lower():
                print(
                    "          Install brotli:  sudo apt-get install -y python3-brotli",
                    file=sys.stderr,
                )
            continue

        size_kb = os.path.getsize(out_path) // 1024
        print(f"  CREATED {os.path.basename(out_path)}  ({size_kb} KB)")


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    for path in sys.argv[1:]:
        convert(path)


if __name__ == "__main__":
    main()
