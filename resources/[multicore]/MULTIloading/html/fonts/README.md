# Game fonts for the loading screen (optional)

The loading screen looks most like Red Dead Redemption 2 with the game's own style of fonts. They are not included in the public release, because the font files belong to their owners.

A loading screen can only use its own files, so it cannot borrow MULTIcore's fonts. Put a copy of the same files in this folder, with exactly these names:

| File | Used for | What to use |
|---|---|---|
| `title.ttf` | the big server name | the RDR "Lino" / "Chinese Rocks" style title font |
| `body.ttf` | tips | Hapna Slab Serif (regular) |
| `body-medium.ttf` | labels | Hapna Slab Serif (medium) |
| `body-bold.ttf` | the tip label, the percentage | Hapna Slab Serif (bold) |

These are the same four files MULTIcore uses in `MULTIcore/html/theme/fonts/`, so you can copy them from there. Then add them to the `files` list in `fxmanifest.lua` if it does not already include `html/fonts/*`.

Without them, MULTIloading uses close free fonts (Oswald for the title, Zilla Slab for text, PT Serif for Russian), so everything still works.
