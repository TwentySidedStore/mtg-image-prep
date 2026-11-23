# Implementation: WPN Image Prep

> **Date:** 2026-11-22
> **Branch:** `wpn-image-prep`

## Summary

`prep.rb` now prepares the product images of any WPN zip, not only Magic zips. Magic stays the default. `-g` converts every PNG with its own name into `output/<zip name>/`. Each image is trimmed, gets a 5% white margin, is made square, is limited to 2048px and is saved as a JPEG.

## What Changed

- `prep.rb`:
  - `-g`, `--general`.
  - `default_output_dir(zip_basename, general:)`: `output/<SETCODE>` for Magic, `output/<zip name without .zip>` for general. `run` calls it only when `-o` is not given.
  - `process_zip(..., general:)`: in general mode it converts `all_pngs`, sorted by name. In Magic mode it converts `swapped_pairs`.
  - `convert_to_jpeg`: the new framing command. The 1px transparent border before `-trim` makes the trim remove only transparent edges.
  - `HELP` and `EXAMPLES`: the `-h` text explains both modes and the framing. The no-pairs error tells the user to use `-g` for a non-Magic zip.
- `test/prep_test.rb`: all the tests, run with `ruby test/prep_test.rb`. The tests write zips and PNGs to a temporary folder, call the methods of `prep.rb`, and never call `run` or `ensure_output_dir`.
- `Gemfile`, `Gemfile.lock`: `minitest ~> 5.25`.
- `README.md`: requirements, setup, usage, modes, framing, output, tests.
- `CLAUDE.md`: purpose, commands, docs folders.
- `docs/implementations/2026-04-17_mtg-image-prep.md`: the spec of the first version, moved from `PLAN.md`.

## Deviations from Plan

- No Magic zip was run during the work. The Magic path was checked with the tests and with a generated `MTG` zip through the full script.
- The four sample zips were run from local copies, not from their URLs. The download step did not change.

## Surprises & Lessons

- `-trim` removes the edges that match the corner colour, not only transparent edges. Without the 1px transparent border, a solid-colour image trims to 1×1 and `magick` exits 0 with only a warning.
- `FuryOfDracula_open.png` is an opaque photo. The border keeps all its pixels.
- In a Minitest test, `run` is `Minitest::Test#run`, not the method of `prep.rb`. The output folder rule is in `default_output_dir` so that a test can call it.
- With `-o`, the script no longer asks for a set code. Before, it asked even when it did not use the code.

## Watch List

- Magic images now have a 5% margin, against about 1% before, and more of them reach the 2048px limit. New Magic sets look slightly different from earlier ones in the store.
- A non-Magic zip run without `-g` can delete and make again a wrong folder: a zip name with a 3-character first part (`pds_hfc_en.zip`) gives `output/PDS/` with 2 swapped images. Another name asks for a set code, deletes `output/<code>/` and then stops.
- A faint shadow or a soft edge stays after the trim, so the product can look smaller.
- A fully transparent PNG gives a 1×1 JPEG with no error.
