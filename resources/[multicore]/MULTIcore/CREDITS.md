# MULTIcore

**Founder and creator: RINGO (RINGOscripting).** MULTIcore, its own scripts (the MULTI resources), MULTItarget, MULTIchat and the MULTIcore look were founded and created by RINGO.

Copyright (C) 2026 RINGO (RINGOscripting). Licensed GPL-3.0-or-later. Parts are based on the work listed below; their authors keep their copyright.

---

# Credits for rsg-core

This resource comes from the project and commit listed in the repository's NOTICE.md. Its original authors keep their copyright. The text below is carried over from the original project.

Original project: https://github.com/Rexshack-RedM/rsg-core

	Thanks to Kakarot and the QB Team for the original work https://discord.gg/qbcore

# License

    RSG RedM Framework
    Copyright (C) 2015-2022 ESX (Jérémie N'gadi), Joshua Eger

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>

# Credits for the look library (client/multi/look.lua) and data/appearance.lua

- How a character is drawn is ported from RSG v2's **rsg-appearance** (https://github.com/Rexshack-RedM/rsg-appearance, GPL v3):
  the base outfit preset 7 and taking off the preset's clothing tags (LoadModel / FixIssues), one skin tone for head and bodies (LoadBoody),
  the variation update sequence (NativeUpdatePedVariation), build and waist as meta ped outfits (LoadBodyFeature, body_size / body_waist lists),
  face overlays drawn on the worn head's own texture with RSG's layer order and colour types (ApplyOverlays, overlay_all_layers, LoadOverlays),
  clothing with _REFRESH_META_PED_SHOP_ITEMS, outfit tints and the body piece kept under uncovered parts (ApplyClothes, BODY_CATEGORY_MAP),
  the fallback head textures (texture_types) and the light-to-dark tone order (GetHashHead).
- Body proportion sliders follow VORP's idea (arms, chest, waist ... sliders); the MetaPedExpression ids are from femga's rdr3_discoveries.
- Overlay, palette, face slider and clothing data: femga's rdr3_discoveries.
