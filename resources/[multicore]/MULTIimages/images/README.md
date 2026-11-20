# Item pictures

Put one picture per item in this folder, named exactly as the item's `image` field
(for bread that is `bread.png`; see `MULTIcore/shared/items.lua`).

- PNG (or WEBP), square, about 100 x 100 pixels or larger, transparent background.
- MULTIinventory and MULTIstores look here first (`Config.ImagePaths` in MULTIinventory's config.lua).
- Items without a picture show a plain icon, so nothing breaks while the folder is empty.
- After adding pictures, restart the server (or `refresh` then `ensure MULTIimages`) and reconnect.
