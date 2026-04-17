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
- `curl` — must be on PATH (used for URL downloads)

## Steps

1. **Preflight.** Check `magick` and `curl` are on PATH (`system('which magick', out: File::NULL)` etc.). If either is missing, print a clear message naming the tool and install hints, then abort before doing any work.

2. **Resolve input.** If the argument is an existing local file, use it directly. Otherwise treat as a URL, capture the basename via `File.basename(URI(url).path)` *before* downloading (for later set-code derivation), then `curl -fL --progress-bar -o <tmpfile> <url>` into a tempfile under `Dir.mktmpdir`. Use `system(..., exception: true)` so a failed download aborts.

3. **Derive set code** from the zip basename:
   - Take the chars before the first `_`. If exactly 3, use as the set code.
   - Fallback: if that segment starts with `MTG` followed by 3+ chars, strip `MTG` and take the next 3.
   - Otherwise, prompt the user to confirm/enter a 3-char code.
   - Uppercase the result. Default output is `output/<SETCODE>/`.
   - **Default path:** if it exists, `FileUtils.rm_rf` and recreate — no stragglers from prior runs.
   - **`-o DIR` override:** create if missing, otherwise write in place (overwriting same-named files, leaving unrelated files alone). User-supplied paths aren't ours to wipe.

4. **Unzip** all `*.png` entries into a scratch dir via `Dir.mktmpdir`. Flatten — discard internal zip directory structure using `File.basename(entry.name)`. Skip `__MACOSX/` entries and dotfiles. PNGs are intermediate and are not persisted.

5. **Swap `_01` ↔ `_02` suffixes** for complete pairs only. Filenames look like `MTGSOS_EN_Bstr_Play_03_01.png` and `MTGSOS_EN_Bstr_Play_03_02.png`. Group files by basename-minus-suffix:
   - Complete pair (both `_01` and `_02` present) → swap via three-pass rename:
     - `*_01.png` → `*_TMP.png`
     - `*_02.png` → `*_01.png`
     - `*_TMP.png` → `*_02.png`
   - Unpaired (only `_01` or only `_02`) → skip.
   - No `_01`/`_02` suffix → skip.

6. **Square + convert to JPEG.** For each surviving PNG, shell out to ImageMagick:

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

## Script structure

`prep.rb` skeleton:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'optparse'
require 'tmpdir'
require 'zip'

$stdout.sync = true

def preflight
  # check curl + magick on PATH, abort with clear message
end

def resolve_zip(source, tmpdir)
  # local file → return path; URL → curl into tmpdir
end

def derive_set_code(zip_basename)
  # 3-char segment / MTG-prefix fallback / prompt
end

def extract_pngs(zip_path, dest)
  # rubyzip, flat, skip __MACOSX + dotfiles
end

def swap_pairs(dir)
  # group by stem, swap complete pairs, return surviving files
end

def convert_to_jpeg(pngs, output_dir, quality)
  # shell out to magick, log [n/total] per file
end

def main
  # parse opts, run pipeline
end

if __FILE__ == $PROGRAM_NAME
  begin
    main
  rescue Interrupt
    warn "\nAborted."
    exit 130
  rescue => e
    warn "Error: #{e.message}"
    exit 1
  end
end
```

Conventions:
- Each top-level method does one thing, ≤15 lines.
- No class needed at this size — loose methods in the script file.
- Top-level `rescue` prints a clean one-liner and exits 1; no Ruby backtrace on expected failures.
- `$stdout.sync = true` so `curl`'s progress bar and per-file conversion lines appear in real time (not held in a buffer).
- `if __FILE__ == $PROGRAM_NAME` guard lets the file be `require`d for REPL poking without running.

## .gitignore

```
output/*
!output/.gitkeep
.bundle/
.DS_Store
```

- `output/` is tracked; processed set subdirs (and their JPEGs) are not.
- `.bundle/` — local bundler config.
- `.DS_Store` — macOS finder cruft.
- Downloaded zips live in `Dir.mktmpdir`, outside the repo, so no pattern needed.
- `Gemfile.lock` **is** committed (this is an app, not a library).

## Progress output

```
Downloading tmt_pds_en.zip
############################################# 100.0%
Extracting 47 PNGs
Swapping 23 pairs
Converting:
  [ 1/46] MTGTMT_EN_Bstr_Play_03_01.jpg
  [ 2/46] MTGTMT_EN_Bstr_Play_03_02.jpg
  ...
Done → output/TMT/ (46 JPEGs)
```

- Download bar is rendered by `curl --progress-bar` (hash marks + percentage, in-place).
- Download is skipped entirely when input is a local file.
- All other lines scroll — conversions are fast enough that scrolling feels responsive.

## Failure cases

Fail loudly (raise / abort) when:
- `magick` or `curl` CLI not on PATH (caught in preflight, names the missing tool).
- Zip is malformed or `curl` download exits non-zero.
- Set code can't be derived and user provides no valid 3-char code.
- Zip contains zero `*.png` entries.
- Every PNG is skipped (no complete `_01`/`_02` pairs) — output dir would be empty.
- Any `magick` conversion exits non-zero.

## License

MIT (already committed as `LICENSE`).

## Notes

- Input PNGs have transparent backgrounds; JPEG output is always flattened onto white (target is a white-themed Shopify store).
- Image dimensions vary per file — square size is the longer of `w` or `h`, evaluated per image.
- Only files that are part of a complete `_01`/`_02` pair are processed; everything else in the zip is skipped.
- Pin `.ruby-version` to the local `ruby -v` so contributors using rbenv/chruby/mise auto-match.
