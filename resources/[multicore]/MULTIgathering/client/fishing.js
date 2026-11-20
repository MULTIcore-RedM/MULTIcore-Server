// MULTIgathering :: reads and writes the game's fishing task data (_GET_TASK_FISHING 0xF3735ACD11ACD500,
// _SET_TASK_FISHING 0xF3735ACD11ACD501). Lua cannot pass a struct buffer to a native.
// Based on rsg-fishing's GET_TASK_FISHING_DATA_EXTRA / SET_TASK_FISHING_DATA_EXTRA (RSG v2, GPL v3,
// Rexshack-RedM and contributors, originally from FRP_Framework; see CREDITS.md).

exports('GetFishingData', () => {
    const buffer = new ArrayBuffer(256);
    const view = new DataView(buffer);
    const on = Citizen.invokeNative('0xF3735ACD11ACD500', PlayerPedId(), view);
    return [on, Array.from(new Int32Array(buffer)), Array.from(new Float32Array(buffer))];
});

// fields stored as floats (the rest are whole numbers)
const FLOAT_FIELDS = new Set([1, 2, 3, 4, 8, 9, 13, 14, 15, 17, 20, 21, 22, 23, 24, 25, 26, 27]);

function floatBits(num) {
    const view = new DataView(new ArrayBuffer(4));
    view.setFloat32(0, num, false);
    return view.getInt32(0);
}

exports('SetFishingData', (struct) => {
    const buffer = new ArrayBuffer(256);
    const view = new DataView(buffer);
    for (let i = 0; i <= 27; i++) {
        let v = struct[`f_${i}`];
        if (v === undefined || v === null) v = 0;
        if (FLOAT_FIELDS.has(i)) v = floatBits(v);
        view.setUint32(i * 8, v, true);
    }
    Citizen.invokeNative('0xF3735ACD11ACD501', PlayerPedId(), view);
});
