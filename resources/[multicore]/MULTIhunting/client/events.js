// MULTIhunting :: reads the game's event data (GET_EVENT_DATA 0x57EC5FA4D4D6AFCA) into a list of
// 32-bit numbers, so Lua can read the loot event. Lua cannot pass a struct buffer to a native.
// Based on rsg-hunting's DataViewNativeGetEventData (RSG v2, GPL v3, Rexshack-RedM and contributors;
// see CREDITS.md).
exports('GetEventData', (eventGroup, index, argStructSize) => {
    const buffer = new ArrayBuffer(256);
    const view = new DataView(buffer);
    Citizen.invokeNative('0x57EC5FA4D4D6AFCA', eventGroup, index, view, argStructSize, Citizen.returnResultAnyway());
    return Array.from(new Int32Array(buffer));
});
