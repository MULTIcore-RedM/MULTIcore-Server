# Credits for MULTIfarming

MULTIfarming is GPL v3, part of MULTIcore by RINGO (RINGOscripting). It is written from scratch for MULTIcore.
No code from any other framework or paid script is used. Its structure follows MULTIgathering (also MULTIcore).

## Game data
- Crop and item models checked against redm-info `objects.lua`: `crp_seedling_aa_sim`, `crp_cornstalks_ab_sim`,
  `crp_cornstalks_cb_sim`, `crp_potato_sap_aa_sim`, `crp_potato_aa_sim`, `crp_tomatoes_sap_aa_sim`,
  `crp_tomatoes_aa_sim`, `crp_carrots_sap_ba_sim`, `crp_carrots_ba_sim`, `crp_wheat_sap_ac`,
  `crp_wheat_sap_long_aa_sim`, `crp_wheat_dry_long_aa_sim`, `crp_lettuce_aa_sim`, `crp_tobaccoplant_aa_sim`,
  `crp_tobaccoplant_ab_sim`, `crp_tobaccoplant_ac_sim`, `crp_tobaccoburnt_bb_sim` (rdr_inst_crops.rpf);
  `p_oniongreen02x`, `p_pumpkin_01x` (p_food.rpf).
- Scenarios checked against redm-info `Scenarios.lua`: `WORLD_HUMAN_FARMER_WEEDING`, `WORLD_HUMAN_FARMER_RAKE`,
  `WORLD_HUMAN_BUCKET_POUR_LOW`, `WORLD_HUMAN_CROUCH_INSPECT`.
- Natives checked against femga `natives.json`: `TASK_START_SCENARIO_IN_PLACE_HASH`, `_GET_MAP_ZONE_AT_COORDS`
  (type TOWN), `_GET_WATER_MAP_ZONE_AT_COORDS`, `IS_POINT_ON_ROAD`, `IS_ENTITY_IN_WATER`, `IS_PED_SWIMMING`,
  `GET_INTERIOR_FROM_ENTITY`, `GET_GROUND_Z_FOR_3D_COORD`, `PLACE_OBJECT_ON_GROUND_PROPERLY`.
