# Feature: WPN Image Prep

> **Branch:** `wpn-image-prep`
> **Status:** Draft

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

These zips have transparent PNGs, as the Magic zips do, but they have no set code and no shared file name pattern. `pds_hfc_en.zip` has `DnD_WHC_SetupBx_01.png` and `_02.png`, which look like a Magic pair, and 8 other images. Thus the Magic rules drop most of the images or swap the wrong ones.

The images also vary in framing and size. The `mm24` products fill about 60% of a 900×900 frame. The `furyofdracula` images are 5000×5000.

## Solution

- **Magic is the default.** Without a flag, the script works as now: set code, `_01`/`_02` swap, only complete pairs.
- **`-g`, `--general`.** The script converts each PNG in the zip with its own name. It does no swap and needs no set code. The default output folder is `output/<zip name without .zip>/`. A flag is used, not a detection from the file names, because the Hellfire Club names look like Magic pairs.
- **One framing for each image.** The conversion trims the transparent edges, adds a white margin of 5% of the long side on each side, makes the image square, makes it 2048px or smaller, and writes a JPEG at quality 85. The size limit is the last step, so that the margin does not make the image larger than 2048px. An image smaller than 2048px is not enlarged. The ImageMagick command is:

  ```bash
  magick SRC -trim +repage -background white -gravity center \
    -extent '%[fx:max(w,h)*1.1]x%[fx:max(w,h)*1.1]' \
    -flatten -resize '2048x2048>' -quality 85 DEST.jpg
  ```

- **Same names refused.** When two PNGs in different folders of the zip have the same file name, the run stops with an error. The extraction flattens the folders, so one file would replace the other.
- **Tests.** Minitest and Rake. The tests build small zips and PNGs in a temporary folder. They require `prep.rb`, which does not run because of the `__FILE__` guard, and call its methods. They do not call `preflight` or `curl`.
- **Docs.** The plan convention is `docs/plans/` while a feature is in progress and `docs/implementations/YYYY-MM-DD_<feature>.md` after it is complete. `PLAN.md` is the spec of the first version, so it moves to `docs/implementations/2026-04-17_mtg-image-prep.md`. `CLAUDE.md` holds only the purpose, the commands and the pointer to `docs/`.

### Files to Read

- `prep.rb` — the full pipeline
- `PLAN.md` — the spec of the Magic version: steps, failure cases, progress output
- `CLAUDE.md` — the style rules

### Files to Touch

| File | Change | Why |
|------|--------|-----|
| `prep.rb` | `--general`, new framing, same-name refusal, output folder for general | The feature |
| `Gemfile`, `Gemfile.lock` | `minitest` and `rake` in a `:test` group | Tests |
| `Rakefile` | `Rake::TestTask` for `test/**/*_test.rb` | `bundle exec rake test` |
| `test/test_helper.rb` | Require `prep.rb`, helpers to build a zip and a PNG | Tests |
| `test/extraction_test.rb` | Selection, swap, same-name refusal | Tests |
| `test/output_dir_test.rb` | Set code and general output folder | Tests |
| `test/conversion_test.rb` | Framing | Tests |
| `PLAN.md` | Moved to `docs/implementations/2026-04-17_mtg-image-prep.md` | Docs convention |
| `CLAUDE.md` | Rewritten, a few lines | Docs |

## Risks

- **Magic output changes.** Magic images now have a 5% margin. Before, the margin was about 1% on the long side. New Magic sets look different from the earlier ones in the store.
- **Trim on a faint shadow.** `-trim` keeps each pixel that is not fully transparent. A faint shadow or a soft edge stays in the image, so the product can look smaller. The four sample zips trim correctly.

## Out of Scope

- A new name for the GitHub repository and the local folder.
- JPG files in a zip.
- A sort that puts the front image first. The output keeps the names from the zip.
- An upload to Shopify or to c3po.

## Done When

- [ ] `bundle exec rake test` passes.
- [ ] A Magic zip gives the swapped pairs in `output/<SETCODE>/`, with the new framing.
- [ ] `./prep.rb -g <url>` on each of the four zips in the Problem section gives one JPEG for each PNG in `output/<zip name>/`, each 2048px or smaller.
- [ ] `CLAUDE.md` is 10 lines or fewer.

## Implementation Stages

### Stage 1: Tests and extraction

**Status:** Not Started
**What:** Add the test setup, the tests of the Magic selection, and the refusal of two PNGs with the same name.
**Tests:**
- The Magic selection keeps only complete `_01`/`_02` pairs and swaps them. It skips a file with only `_01`, a file with no suffix, `__MACOSX` entries and dotfiles. These tests pass at once: they protect the current behaviour before the next stages change the code.
- `derive_set_code` takes a 3-letter stem (`tmt_pds_en.zip` gives `TMT`) and an `MTG` stem (`MTGTMT_pds.zip` gives `TMT`).
- The extraction stops with an error when two PNGs in different folders have the same file name, and names the file.
**Steps:**

1. Add `minitest` and `rake` to a `:test` group in the `Gemfile`, add the `Rakefile`, and run `bundle install`.
2. Write `test/test_helper.rb`: require `prep.rb`, a helper that writes a zip from a hash of entry names to PNG bytes, and a helper that makes a small transparent PNG with `magick`.
3. Write the tests.
4. Make `extract_pngs` raise on a second entry with the same file name.

- [ ] Tests passing
- [ ] No regressions

### Stage 2: Framing

**Status:** Not Started
**What:** Trim, add the 5% margin, square, limit to 2048px, and write the JPEG.
**Tests:**
- A transparent 100×60 PNG with a red 20×10 rectangle off centre gives a 22×22 JPEG with a white corner and a red centre.
- A 3000×1000 opaque PNG gives a 2048×2048 JPEG.
**Steps:**

1. Write the tests.
2. Change the `magick` arguments in `convert_to_jpeg` to the command in the Solution section.

- [ ] Tests passing
- [ ] No regressions

### Stage 3: General mode

**Status:** Not Started
**What:** Add `-g`, `--general`, which converts every PNG with its own name into `output/<zip name>/`.
**Tests:**
- In general mode, a zip with `a_01.png`, `a_02.png` and `box.png` gives `a_01.jpg`, `a_02.jpg` and `box.jpg` with no swap: the JPEG of `a_01.png` has the pixels of `a_01.png`.
- The default output folder is `output/<SETCODE>` for Magic and `output/<zip name without .zip>` in general mode, for example `output/furyofdracula_pdp`. `-o` replaces both.
**Steps:**

1. Write the tests.
2. Add the option to `parse_options`, with the banner `Usage: prep.rb <zip-path-or-url> [options]` and the help line `Convert every PNG as-is (non-Magic zips)`.
3. Add the output folder rule for general mode, without `derive_set_code`.
4. In `process_zip`, convert every extracted PNG in general mode, and keep the pair selection and the swap for Magic.

- [ ] Tests passing
- [ ] No regressions

### Stage 4: Docs

**Status:** Not Started
**What:** Move `PLAN.md` to `docs/implementations/` and make `CLAUDE.md` thin.
**Tests:** None: no rule.
**Steps:**

1. `git mv PLAN.md docs/implementations/2026-04-17_mtg-image-prep.md`.
2. Rewrite `CLAUDE.md`: one line for the purpose, the run command with `-g`, `bundle exec rake test`, and "Plans: `docs/plans/`. Summaries: `docs/implementations/`."
3. Run the four zips and one Magic zip, and check the output.

- [ ] Tests passing
- [ ] No regressions
