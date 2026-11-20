// MULTIgathering :: puts one of the game's herb plants into the world (_CREATE_HERB_COMPOSITES 0x5B4BBE80AD5972DC).
// The native wants a buffer, which Lua cannot pass. Based on rsg-herbalist's NativeCreateComposite
// (RSG v2, GPL v3, RexShack and contributors; see CREDITS.md).
exports('CreateHerb', (compositeHash, x, y, z, onGround) => {
    const buffer = new ArrayBuffer(4 * 8);
    const view = new DataView(buffer);
    return Citizen.invokeNative('0x5B4BBE80AD5972DC', compositeHash, x, y, z, 0.0, onGround ? 0 : 2, view, -1);
});
