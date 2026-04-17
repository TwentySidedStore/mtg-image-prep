# mtg-image-prep

Small Ruby CLI that processes WPN image zips for Magic: The Gathering product releases. Run every ~2 months when a new set ships.

See `PLAN.md` for the implementation spec.

## Style
- Ruby 3.x, stdlib-first (OptionParser, not Thor).
- Functions do one thing; keep them ≤15 lines.
- No code comments — self-document via naming.
- Don't overguard. Fail loudly if ImageMagick is missing or the zip is malformed.
