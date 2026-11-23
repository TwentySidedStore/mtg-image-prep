# Feature: WPN Image Prep

> **Branch:** `wpn-image-prep`
> **Status:** In Progress (Stage 2/4)

## Problem

`prep.rb` prepares the product images from a WPN zip for the Shopify store. It works only with Magic zips:

- It takes the set code from the zip name for the output folder.
- It swaps each `_01`/`_02` pair.
- It keeps only the files that are in a complete pair.

WPN also has zips for Dungeons & Dragons books and board games, for example:

- `https://media.wizards.com/2024/wpn/marketing_materials/ddosiris/mm24_pds_en.zip`
- `https://media.wizards.com/2025/wpn/marketing_materials/ebr/eberron_product_shots.zip`
- `https://media.wizards.com/2025/wpn/marketing_materials/hfc/pds_hfc_en.zip`
- `https://media.wizards.com/2026/wpn/marketing_materials/avh/furyofdracula_pdp.zip`

These zips have no set code and no shared file name pattern. Three of them have no `_01`/`_02` pair, so the script asks for a set code and then stops with an error. `pds_hfc_en.zip` has `DnD_WHC_SetupBx_01.png` and `_02.png`, which look like a Magic pair. The script swaps these two, drops the other 8 images, and writes `output/PDS/`.

Most of the images are transparent PNGs. `FuryOfDracula_open.png` is an opaque photo. The images also vary in framing and size: the `mm24` products sit inside a wide transparent border in a 900×900 frame, and 4 of the `furyofdracula` images are 5000×5000.

## Solution

- **Magic is the default.** Without a flag, the script works as now: set code, `_01`/`_02` swap, only complete pairs.
- **`-g`, `--general`.** The script converts each PNG in the zip with its own name, in name order. It does no swap and needs no set code. A flag is used, not a detection from the file names, because the Hellfire Club names look like Magic pairs.
- **Output folder.** `default_output_dir(zip_basename, general)` returns `output/<SETCODE>` for Magic and `output/<zip name without .zip>` in general mode, for example `output/furyofdracula_pdp`. `run` uses `options[:output] || default_output_dir(...)`. As for Magic, the script deletes the default folder and makes it again on each run. With `-o`, the script no longer asks for a set code, because it does not need one.
- **One framing for each image.** The conversion trims the transparent edges, adds a white margin of 5% of the long side on each side, makes the image square, makes it 2048px or smaller, and writes a JPEG with the `-q` quality (default 85). The 1px transparent border before `-trim` makes the trim remove only transparent edges: an opaque image keeps all its pixels. The size limit is the last step, so that the margin does not make the image larger than 2048px. An image smaller than 2048px is not enlarged. The ImageMagick command is:

  ```bash
  magick SRC -bordercolor none -border 1 -trim +repage \
    -background white -gravity center \
    -extent '%[fx:max(w,h)*1.1]x%[fx:max(w,h)*1.1]' \
    -flatten -resize '2048x2048>' -quality QUALITY DEST.jpg
  ```

- **Help.** `./prep.rb -h` explains both modes, the framing and the options, with one example for each mode. When a Magic run finds no complete pair, the error says to use `-g` for a non-Magic zip. `README.md` holds the setup, the usage and the same explanation.
- **Tests.** Minitest 5, in one file, `test/prep_test.rb`, run with `ruby test/prep_test.rb`. The file requires `prep.rb` first, then `minitest/autorun`. The `__FILE__` guard stops `prep.rb` from running. The tests:
  - build small zips and PNGs in a temporary folder;
  - call the methods of `prep.rb`, but never `run`, `preflight` or `ensure_output_dir`, because `ensure_output_dir` deletes folders under `output/`;
  - make the output folder in the temporary folder;
  - capture the progress output;
  - compare JPEG colours with a tolerance;
  - need ImageMagick on the PATH, as the script does.
- **Docs.** The plan convention is `docs/plans/` while a feature is in progress and `docs/implementations/YYYY-MM-DD_<feature>.md` after it is complete. `PLAN.md` is the spec of the first version, so it moves to `docs/implementations/2026-04-17_mtg-image-prep.md`. `CLAUDE.md` holds only the purpose, the commands and the pointer to `docs/`.

### Files to Read

- `prep.rb` — the full pipeline
- `PLAN.md` — the spec of the Magic version: steps, failure cases, progress output
- `CLAUDE.md` — the style rules

### Files to Touch

| File | Change | Why |
|------|--------|-----|
| `prep.rb` | `--general`, `default_output_dir`, new framing, help text, error hint | The feature |
| `Gemfile`, `Gemfile.lock` | `gem 'minitest', '~> 5.25'` | Tests |
| `test/prep_test.rb` | New: helpers and all tests | Tests |
| `PLAN.md` | Moved to `docs/implementations/2026-04-17_mtg-image-prep.md` | Docs convention |
| `CLAUDE.md` | Rewritten, a few lines | Docs |
| `README.md` | New: setup, usage, modes, framing, tests | Docs |

## Risks

- **Magic output changes.** Magic images now have a 5% margin. Before, the margin was about 1% on the long side. The margin also makes more images reach the 2048px limit: 104 of the 288 Magic JPEGs in `output/`, against 14 now. A product that is 2000px now becomes about 1862px. New Magic sets look different from the earlier ones in the store.
- **A non-Magic zip without `-g`.** A zip name with a 3-letter first part gives a set code. Thus `pds_hfc_en.zip` without `-g` writes 2 swapped images to `output/PDS/` and shows no error. Another non-Magic zip asks for a set code, deletes `output/<code>/` and then stops, so an existing set code typed at the prompt empties that set folder.
- **Trim on a faint shadow.** The trim keeps each pixel that is not fully transparent. A faint shadow or a soft edge stays in the image, so the product can look smaller. The transparent images in the four sample zips trim correctly.

## Out of Scope

- A new name for the GitHub repository and the local folder.
- JPG files in a zip.
- A sort that puts the front image first. The output keeps the names from the zip.
- An upload to Shopify or to c3po.

## Done When

- [ ] `ruby test/prep_test.rb` passes.
- [ ] The most recent Magic zip gives the swapped pairs in `output/<SETCODE>/`, with the new framing. This run deletes and makes again `output/<SETCODE>/`.
- [ ] `./prep.rb -g <url>` on each of the four zips in the Problem section gives one JPEG for each PNG in `output/<zip name without .zip>/`, each 2048px or smaller.
- [ ] `CLAUDE.md` is 10 lines or fewer.
- [ ] `./prep.rb -h` and `README.md` explain both modes.

## Implementation Stages

### Stage 1: Tests of the Magic rules

**Status:** Complete
**What:** Add Minitest and tests that hold the current Magic behaviour before the next stages change the code.
**Tests:** These tests pass at once.
- Through `process_zip`, the Magic selection keeps only complete `_01`/`_02` pairs and swaps them: the output folder holds only `a_01.jpg` and `a_02.jpg`, and `a_01.jpg` has the colour of `a_02.png`. It skips a file with only `_01`, a file with no suffix, a `.docx`, `__MACOSX` entries and dotfiles.
- `derive_set_code` takes a 3-character stem (`tmt_pds_en.zip` gives `TMT`) and an `MTG` stem (`MTGTMT_pds.zip` gives `TMT`). For another name it asks for the code and takes a 3-character answer, and it refuses an answer of another length. The test gives the answer through `$stdin`.
**Steps:**

1. Add `gem 'minitest', '~> 5.25'` to the `Gemfile`, and run `bundle install`.
2. Write `test/prep_test.rb`: require `prep.rb` and `minitest/autorun`, a helper that writes a zip from a hash of entry names to file bytes, and a helper that makes a PNG with an opaque shape of a given colour on a transparent canvas with `magick`.
3. Write the tests.

- [x] Tests passing
- [x] No regressions

### Stage 2: Framing

**Status:** Not Started
**What:** Trim the transparent edges, add the 5% margin, square, limit to 2048px, and write the JPEG.
**Tests:**
- A transparent 100×60 PNG with a red 20×10 rectangle off centre gives a 22×22 JPEG with a white corner and a red centre.
- A solid-colour opaque 3000×1000 PNG keeps all its pixels and gives a 2048×2048 JPEG: the colour at about (100,1024) and (1948,1024), white at about (80,1024) and (1024,700).
**Steps:**

1. Write the tests.
2. Change the `magick` arguments in `convert_to_jpeg` to the command in the Solution section, with `quality` for `QUALITY`.
3. Run the most recent Magic zip, and check the output.

- [ ] Tests passing
- [ ] No regressions

### Stage 3: General mode

**Status:** Not Started
**What:** Add `-g`, `--general`, which converts every PNG with its own name into `output/<zip name without .zip>/`.
**Tests:**
- `process_zip` in general mode, on a zip with `a_01.png` (red), `a_02.png` (blue) and `box.png`, gives `a_01.jpg`, `a_02.jpg` and `box.jpg`, and `a_01.jpg` is red: no swap.
- `default_output_dir` returns `output/TMT` for `tmt_pds_en.zip` in Magic mode, and `output/furyofdracula_pdp` for `furyofdracula_pdp.zip` in general mode.
**Steps:**

1. Write the tests.
2. Add `-g`, `--general` to `parse_options`, with the help line `Convert every PNG as-is (non-Magic zips)`. Change the `-o` help line to `Output directory (default: output/<SETCODE>/ or output/<zip name>/)`.
3. Add `default_output_dir(zip_basename, general:)`. It calls `derive_set_code` only in Magic mode. `run` uses it.
4. Change `process_zip` to `process_zip(zip_path, tmpdir, output_dir, quality, general:)`, and add `general: false` to the Stage 1 call. In general mode it converts every extracted PNG, sorted by name, prints no Swapping line, and the Done line counts the converted files. In Magic mode it keeps the pair selection and the swap.
5. Run `./prep.rb -g` on the four zips in the Problem section, and check the output.

- [ ] Tests passing
- [ ] No regressions

### Stage 4: Docs

**Status:** Not Started
**What:** Move `PLAN.md` to `docs/implementations/`, make `CLAUDE.md` thin, add `README.md`, and explain both modes in the CLI help.
**Tests:** None: no rule.
**Steps:**

1. `git mv PLAN.md docs/implementations/2026-04-17_mtg-image-prep.md`.
2. Rewrite `CLAUDE.md`: one line for the purpose, the run command with `-g`, `ruby test/prep_test.rb`, and "Plans: `docs/plans/`. Summaries: `docs/implementations/`."
3. Write `README.md`: requirements, setup, usage with both modes, the options, the framing, the tests.
4. Change the help of `parse_options` to explain both modes and the framing, with one example for each mode. Add "Use -g for a non-Magic zip." to the error when no complete pair is found.

The summary of this feature and the removal of this plan happen at completion.

- [ ] Tests passing
- [ ] No regressions
