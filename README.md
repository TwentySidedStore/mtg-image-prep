# mtg-image-prep

Prepares the product images of a WPN zip for the Shopify store. The script reads a zip of transparent PNGs from a URL or a local file and writes square JPEGs to `output/`.

## Requirements

- Ruby (see `.ruby-version`)
- ImageMagick 7, with `magick` on the PATH
- `curl` on the PATH

## Setup

```bash
bundle install
```

## Usage

```bash
./prep.rb <zip-path-or-url> [options]
```

| Option | Effect |
|--------|--------|
| `-g`, `--general` | Convert every PNG as-is (non-Magic zips) |
| `-q`, `--quality N` | JPEG quality 1–100 (default: 85) |
| `-o`, `--output DIR` | Output folder (default: `output/mtg/<SETCODE>/` or `output/general/<zip name>/`) |
| `-h`, `--help` | Show the help |

### Magic (default)

```bash
./prep.rb ~/Downloads/tmt_pds_en.zip
```

- The set code comes from the zip name: a 3-character first part (`tmt_pds_en.zip` gives `TMT`) or an `MTG` prefix (`MTGTMT_pds.zip` gives `TMT`). When the name gives no set code, the script asks for it.
- Each `_01`/`_02` pair is swapped.
- Files that are not in a complete pair are skipped.
- The output folder is `output/mtg/<SETCODE>/`.

### General (`-g`)

```bash
./prep.rb -g https://media.wizards.com/2026/wpn/marketing_materials/avh/furyofdracula_pdp.zip
```

- Every PNG is converted with its own name.
- The output folder is `output/general/<zip name without .zip>/`, for example `output/general/furyofdracula_pdp/`.

Use `-g` for Dungeons & Dragons, board game and other non-Magic zips. Without `-g`, such a zip can ask for a set code and stop with "No complete _01/_02 pairs found", or give a few swapped images in a wrong folder.

## Framing

Each image is processed in this sequence:

1. The transparent edges are trimmed. An opaque image keeps all its pixels.
2. A white margin of 5% of the long side is added on each side, and the image is made square.
3. An image larger than 2048px is made 2048px. A smaller image is not made larger.
4. The image is saved as a JPEG.

## Output

The default output folder of the set or the zip is deleted and made again on each run. The other folders in `output/mtg/` and `output/general/` stay. A folder given with `-o` is not deleted: files with the same name are replaced, and other files stay. `output/` is not in git.

## Tests

```bash
ruby test/prep_test.rb
```

The tests need ImageMagick. They write only to a temporary folder.
