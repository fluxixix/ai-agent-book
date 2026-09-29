#!/usr/bin/env bash
# Build the Chinese (zh-CN) EPUB 3 edition from the Markdown sources.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

for command in pandoc pdftoppm python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: $command is required." >&2
        exit 1
    fi
done

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-agent-book-epub.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

language="zh-CN"
directory="book"
title="深入理解 AI Agent：设计原理与工程实践"
author="李博杰"
pdf="深入理解-AI-Agent-李博杰-v2.0.pdf"
output="深入理解-AI-Agent-李博杰-v2.0.epub"
title_label="扉页"
toc_label="目录"
chapters=(introduction.md chapter{1..10}.md afterword.md)

edition_dir="$ROOT/$directory"
for chapter in "${chapters[@]}" "$pdf"; do
    if [ ! -f "$edition_dir/$chapter" ]; then
        echo "Error: $directory/$chapter not found." >&2
        exit 1
    fi
done

cover="$TMP_DIR/cover-$language.jpg"
pdftoppm -f 1 -singlefile -jpeg -r 160 \
    "$edition_dir/$pdf" "${cover%.jpg}"

echo "Building $language EPUB..."
(
    cd "$edition_dir"
    pandoc "${chapters[@]}" \
        -o "$output" \
        --from markdown+lists_without_preceding_blankline \
        --to epub3 \
        --standalone \
        --toc \
        --toc-depth=3 \
        --number-sections \
        --mathml \
        --split-level=1 \
        --highlight-style=kate \
        --lua-filter="$ROOT/epub_external_links.lua" \
        --css="$ROOT/epub.css" \
        --epub-cover-image="$cover" \
        --metadata title="$title" \
        --metadata author="$author" \
        --metadata lang="$language" \
        --metadata dir="ltr" \
        --metadata identifier="https://github.com/bojieli/ai-agent-book#$language"
)

python3 "$ROOT/flatten_epub_toc.py" \
    "$edition_dir/$output" "$title_label" "$toc_label"

if command -v epubcheck >/dev/null 2>&1; then
    epubcheck "$edition_dir/$output"
else
    echo "Built $directory/$output (install epubcheck to validate it)."
fi
