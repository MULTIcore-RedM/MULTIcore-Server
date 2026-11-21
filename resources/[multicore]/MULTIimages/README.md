# MULTIimages

The item picture folder for MULTIinventory and MULTIstores.

```
ensure MULTIimages     # anywhere after MULTIcore
```

The inventory finds them at `nui://MULTIimages/images/` (the first entry of `Config.ImagePaths` in MULTIinventory's config.lua).

## Pictures included

Pictures for 1029 of MULTIcore's 1150 items (`MULTIcore/shared/items.lua`) are already in `images/`, including all the food, drink, medicine and ingredients made from this library. Each is named exactly as the item's `image` field (`bread.png`, `ammo_box_revolver.png` ...).

They are by **Tankie** (**The Icon Library Project**), a free RedM picture library: https://github.com/TankieTwitch/FREE-RedM-Image-Library. Thank you! If you like them, the library can be supported at https://ko-fi.com/theiconlibraryproject.

Not every item has a picture yet (most guns, canteens, backpacks, some herbs and orchids). Those show the inventory's plain placeholder until you add one.

## Adding or changing pictures

Put a `.png` (or `.webp`) in `images/`, named exactly as the item's `image` field. A file with the same name replaces the included one.

GPL-3.0-or-later, part of MULTIcore by RINGO (RINGOscripting). The pictures are under their own terms: the included ones are by Tankie (The Icon Library Project, free to use), and the ones you add are yours.
