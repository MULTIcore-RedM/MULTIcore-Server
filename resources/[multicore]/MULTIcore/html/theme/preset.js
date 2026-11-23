// MULTIcore UI preset for every MULTI page.
// Load it right after the theme:
//   <link rel="stylesheet" href="nui://MULTIcore/html/theme/multi.css">
//   <script src="nui://MULTIcore/html/theme/preset.js"></script>
// It asks MULTIcore which preset the server uses (MULTIConfig.UIPreset in config_multi.lua)
// and puts the class mc-preset-classic / mc-preset-parchment / mc-preset-modern on <html>.
// Pages can style their own parts for a preset with  html.mc-preset-parchment .my-part { ... }
// GPL v3, part of MULTIcore by RINGO (RINGOscripting).
(function () {
    'use strict';
    var KNOWN = { classic: 1, parchment: 1, modern: 1 };
    var KEY = 'mc_ui_preset';
    var root = document.documentElement;

    function apply(name) {
        name = String(name || '').toLowerCase();
        if (!KNOWN[name]) name = 'classic';
        for (var k in KNOWN) root.classList.toggle('mc-preset-' + k, k === name);
        root.setAttribute('data-mc-preset', name);
        try { localStorage.setItem(KEY, name); } catch (e) { }
        try { window.dispatchEvent(new CustomEvent('mcpreset', { detail: name })); } catch (e) { }
    }
    window.MCApplyPreset = apply;

    // the last known preset first, so a page never flashes the wrong look
    var cached = null;
    try { cached = localStorage.getItem(KEY); } catch (e) { }
    apply(cached || 'classic');

    function ask(tries) {
        fetch('https://MULTIcore/mcUiPreset', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: '{}'
        }).then(function (r) { return r.json(); }).then(function (d) {
            if (d && d.preset) apply(d.preset);
        }).catch(function () {
            if (tries > 0) setTimeout(function () { ask(tries - 1); }, 1500);
        });
    }
    ask(5);

    // a page may also be told directly: window.postMessage({ mcUiPreset: 'modern' })
    window.addEventListener('message', function (e) {
        if (e.data && typeof e.data.mcUiPreset === 'string') apply(e.data.mcUiPreset);
    });
})();
