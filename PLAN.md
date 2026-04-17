# Plan: mtg-image-prep

## Purpose

One-command CLI that takes a zip of transparent PNGs (WPN product art), swaps paired `_01` / `_02` filename suffixes, squares each image on a white background, and exports compressed JPEGs for a Shopify store.

## Usage

```bash
bundle install                                    # once
chmod +x prep.rb                                  # once
./prep.rb <zip-path-or-url> [options]
```

`prep.rb` starts with `#!/usr/bin/env ruby` and `require 'bundler/setup'` so gems resolve from the Gemfile without needing `bundle exec`.

Options:
- `-q, --quality N` — JPEG quality 1–100 (default: 85)
- `-o, --output DIR` — output directory (default: `output/<SETCODE>/`)

## Dependencies

- Ruby 3.x
- `rubyzip` gem (`require: 'zip'`)
- ImageMagick 7+ — `magick` CLI must be on PATH

## Steps

1. **Resolve input.** If the argument is an existing local file, use it directly. Otherwise treat as a URL and download via `URI.open` into a tempfile under `Dir.mktmpdir`.

2. **Derive set code** from the zip basename:
   - Take the chars before the first `_`. If exactly 3, use as the set code.
   - Fallback: if that segment starts with `MTG` followed by 3+ chars, strip `MTG` and take the next 3.
   - Otherwise, prompt the user to confirm/enter a 3-char code.
   - Uppercase the result. Default output is `output/<SETCODE>/`. Overwrite silently if it exists.

3. **Unzip** all `*.png` entries into a scratch dir via `Dir.mktmpdir`. Flatten — discard internal zip directory structure using `File.basename(entry.name)`. Skip `__MACOSX/` entries and dotfiles. PNGs are intermediate and are not persisted.

4. **Swap `_01` ↔ `_02` suffixes** for complete pairs only. Filenames look like `MTGSOS_EN_Bstr_Play_03_01.png` and `MTGSOS_EN_Bstr_Play_03_02.png`. Group files by basename-minus-suffix:
   - Complete pair (both `_01` and `_02` present) → swap via three-pass rename:
     - `*_01.png` → `*_TMP.png`
     - `*_02.png` → `*_01.png`
     - `*_TMP.png` → `*_02.png`
   - Unpaired (only `_01` or only `_02`) → skip.
   - No `_01`/`_02` suffix → skip.

5. **Square + convert to JPEG.** For each surviving PNG, shell out to ImageMagick:

   ```bash
   magick SRC -background white -gravity center \
     -extent '%[fx:max(w,h)]x%[fx:max(w,h)]' \
     -flatten -quality 85 DEST.jpg
   ```

   Write to `output/<SETCODE>/` with the same basename + `.jpg`. Use `system(..., exception: true)` so a failed conversion aborts the run.

## Project layout

```
mtg-image-prep/
├── .gitignore
├── Gemfile
├── CLAUDE.md
├── PLAN.md
├── prep.rb
└── output/
    └── .gitkeep
```

## Gemfile

```ruby
source 'https://rubygems.org'
gem 'rubyzip', '~> 3.0', require: 'zip'
```

## .gitignore

```
output/*
!output/.gitkeep
```

The `output/` directory is tracked; processed set subdirs (and their JPEGs) are not. Downloaded zips live in `Dir.mktmpdir`, outside the repo.

## Notes

- Input PNGs have transparent backgrounds; JPEG output is always flattened onto white (target is a white-themed Shopify store).
- Image dimensions vary per file — square size is the longer of `w` or `h`, evaluated per image.
- Only files that are part of a complete `_01`/`_02` pair are processed; everything else in the zip is skipped.
- Progress output to stdout is fine; a single line per converted file is plenty.
