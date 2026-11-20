// MULTIloading
// Progress comes from the messages CitizenFX sends to a loading screen
// (docs.fivem.net, Scripting manual > NUI development > Loading screens). Used here:
//   loadProgress           { loadFraction }
//   startInitFunctionOrder { type, order, count }
//   initFunctionInvoking   { type, name, idx }
//   startDataFileEntries   { count }
//   onDataFileEntry        { name, type, isNew }
//   performMapLoadFunction, endDataFileEntries, endInitFunction (name only)
//   onLogLine              { message }
(function () {
    'use strict';
    const C = window.MULTILOADING || {};
    const $ = (id) => document.getElementById(id);

    // ---------- language: chosen language, English fills gaps ----------
    const all = C.texts || {};
    const lang = String(C.language || 'en').toLowerCase();
    const T = Object.assign({}, all.en || {}, all[lang] || {});
    if (lang === 'ru') document.body.classList.add('mc-cyrillic');
    document.documentElement.lang = lang;

    // ---------- static text ----------
    const handover = window.nuiHandoverData || {};
    $('name').textContent = (C.useHandoverName !== false && handover.name) ? handover.name : (C.serverName || '');
    if (C.logo === '' || C.logo === false) $('logo').remove();
    else if (C.logo) $('logo').src = String(C.logo);
    $('subtitle').textContent = T.subtitle || '';
    $('tipLabel').textContent = T.tipLabel || '';
    $('status').textContent = T.loadingLabel || '';
    if (C.background) {
        $('bg').style.backgroundImage = `url("${String(C.background).replace(/"/g, '')}")`;
        $('shade').style.opacity = String(Math.min(1, Math.max(0, Number(C.backgroundShade) || 0)));
    }

    // ---------- tips ----------
    const tips = Array.isArray(T.tips) ? T.tips.filter(Boolean) : [];
    let tipIdx = Math.floor(Math.random() * Math.max(1, tips.length));
    function showTip() {
        if (!tips.length) { $('tipBox').style.display = 'none'; return; }
        $('tip').textContent = tips[tipIdx % tips.length];
    }
    showTip();
    if (tips.length > 1) {
        const fade = Number(C.tipFadeMs) || 0;
        const every = Math.max(Number(C.tipMinSeconds) || 1, Number(C.tipSeconds) || 1) * 1000;
        setInterval(() => {
            $('tipBox').classList.add('out');
            setTimeout(() => { tipIdx++; showTip(); $('tipBox').classList.remove('out'); }, fade);
        }, every);
    }

    // ---------- progress ----------
    // The engine's loadFraction drives the bar. Init-function and data-file
    // messages only feed the status line.
    let shown = 0;
    let initCount = 0;
    let dataCount = 0;
    let dataDone = 0;

    function setProgress(f) {
        f = Math.min(1, Math.max(0, Number(f) || 0));
        if (f < shown) return;        // never run backwards
        shown = f;
        $('fill').style.width = (f * 100).toFixed(1) + '%';
        $('percent').textContent = Math.round(f * 100) + '%';
        if (f >= 1) $('status').textContent = T.readyLabel || '';
    }
    function setStatus(text) {
        if (shown >= 1) return;
        $('status').textContent = text ? `${T.loadingLabel || ''}: ${text}` : (T.loadingLabel || '');
    }

    const handlers = {
        loadProgress: (d) => setProgress(d.loadFraction),
        startInitFunctionOrder: (d) => { initCount = Number(d.count) || 0; setStatus(String(d.type || '').toLowerCase()); },
        initFunctionInvoking: (d) => setStatus(`${d.name || ''}${initCount ? ` (${(Number(d.idx) || 0) + 1}/${initCount})` : ''}`),
        startDataFileEntries: (d) => { dataCount = Number(d.count) || 0; dataDone = 0; },
        onDataFileEntry: (d) => { dataDone++; setStatus(`${String(d.name || '').split(/[\\/]/).pop()}${dataCount ? ` (${dataDone}/${dataCount})` : ''}`); },
        performMapLoadFunction: () => setStatus(T.mapLabel || ''),
        endDataFileEntries: () => {},
        endInitFunction: () => {},
        onLogLine: (d) => { if (d.message) setStatus(String(d.message).replace(/\.+$/, '')); },
    };

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        const h = handlers[d.eventName];
        if (h) h(d);
    });
})();
