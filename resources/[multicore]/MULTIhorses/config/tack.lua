-- ============================================================
-- MULTIhorses :: tack (a small choice of saddles and blankets)
-- Hashes from femga tack_catalog.lua (horse shop components, from
-- rdr3_discoveries cloth_hash_names.lua). The metaCategory is the
-- category tag the game removes when a piece is taken off (the same
-- values rsg-horses uses in Config.ComponentHash).
-- Tack is put on at a stable for its price; it is never refunded.
-- Prices: 1899 dollars (RDR2's saddle and blanket range).
--
-- label: locale key; hash: shop item hash; price: dollars
-- ============================================================

Config.Tack = {
    Enabled = true,                 -- default true (false = no tack menu at the stables)
    Categories = {
        {
            key = 'saddle',
            label = 'tack_saddles',
            metaCategory = 0xBAA7E618,
            items = {
                { label = 'saddle_gerden_worn',     hash = 0x534A7D59, price = 20.00 }, -- HORSE_EQUIPMENT_WESTERN_04_STOCK_USED_SADDLE_000
                { label = 'saddle_gerden_stock',    hash = 0x2E3F3A62, price = 35.00 }, -- HORSE_EQUIPMENT_WESTERN_04_STOCK_NEW_SADDLE_000
                { label = 'saddle_dakota_stock',    hash = 0xEC882931, price = 38.00 }, -- HORSE_EQUIPMENT_WESTERN_02_STOCK_NEW_SADDLE_000
                { label = 'saddle_mcclellan_stock', hash = 0xD97573C1, price = 37.00 }, -- HORSE_EQUIPMENT_MCCLELLAN_01_STOCK_NEW_SADDLE_000
                { label = 'saddle_roping_stock',    hash = 0x8DABACD7, price = 45.00 }, -- HORSE_EQUIPMENT_WESTERN_03_STOCK_NEW_SADDLE_000
                { label = 'saddle_dakota_improved', hash = 0xB9BE555D, price = 62.00 }, -- HORSE_EQUIPMENT_WESTERN_02_IMPROVED_NEW_SADDLE_000
            },
        },
        {
            key = 'blanket',
            label = 'tack_blankets',
            metaCategory = 0x17CEB41A,
            items = {
                { label = 'blanket_riobravo',  hash = 0x269583CA, price = 4.00 }, -- HORSE_EQUIPMENT_HORSE_BLANKET_01_NEW_001
                { label = 'blanket_bayou',     hash = 0x533A022A, price = 4.00 }, -- HORSE_EQUIPMENT_HORSE_BLANKET_02_NEW_002
                { label = 'blanket_cholla',    hash = 0x342916F3, price = 4.00 }, -- HORSE_EQUIPMENT_HORSE_BLANKET_03_NEW_004
                { label = 'blanket_ironcloud', hash = 0xC097E12C, price = 4.50 }, -- HORSE_EQUIPMENT_HORSE_BLANKET_06_NEW_001
                { label = 'blanket_owanjila',  hash = 0x53B325B7, price = 6.00 }, -- HORSE_EQUIPMENT_HORSE_BLANKET_11_NEW_002
                { label = 'blanket_diablo',    hash = 0x7951D487, price = 8.00 }, -- HORSE_EQUIPMENT_HORSE_BLANKET_05_NEW_000
            },
        },
    },
}
