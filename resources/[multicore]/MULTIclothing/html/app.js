/* MULTIclothing store page. Lua owns the ped; this page keeps the choices,
   shows the basket and asks Lua to preview, frame the camera, rotate and buy. */
(function () {
    'use strict';

    var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIclothing';
    var $ = function (id) { return document.getElementById(id); };

    var st = {
        open: false, cats: [], byKey: {}, saved: {}, work: {}, names: {},
        active: null, cash: 0, recolour: 0, colours: true, palettes: 0, busy: false,
        locale: {}, currency: "$", previewDelay: 0
    };

    // ---------- language: every word comes from the table Lua sends ----------
    function L(key) {
        var s = st.locale[key];
        if (s === undefined) return key;
        var args = Array.prototype.slice.call(arguments, 1);
        return String(s).replace(/%[sd]/g, function (m) { return args.length ? args.shift() : m; });
    }
    function has(key) { return st.locale[key] !== undefined; }
    function niceKey(k) { return k.replace(/_/g, " ").replace(/w/g, function (c) { return c.toUpperCase(); }); }
    function catLabel(key) { return has("cat_" + key) ? L("cat_" + key) : niceKey(key); }
    function groupLabel(g) { return has("group_" + g) ? L("group_" + g) : niceKey(g); }
    function styleName(key, index) { return st.names[key] || L("ui_style_n", index); }
    function applyStatic() {
        document.querySelectorAll("[data-l]").forEach(function (el) { el.textContent = L(el.getAttribute("data-l")); });
        document.querySelectorAll("[data-l-title]").forEach(function (el) { el.title = L(el.getAttribute("data-l-title")); });
        document.querySelectorAll("[data-l-placeholder]").forEach(function (el) { el.placeholder = L(el.getAttribute("data-l-placeholder")); });
    }

    function post(name, data) {
        return fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then(function (r) { return r.json(); }).catch(function () { return {}; });
    }

    function money(n) { return st.currency + (Math.round(n * 100) / 100).toFixed(2); }
    function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
    function copy(p) { return p ? JSON.parse(JSON.stringify(p)) : null; }

    // ---------- pricing (the server works this out again) ----------
    function sameColour(a, b) {
        return (a.palette || 0) === (b.palette || 0) && (a.tint0 || 0) === (b.tint0 || 0)
            && (a.tint1 || 0) === (b.tint1 || 0) && (a.tint2 || 0) === (b.tint2 || 0);
    }
    function lineFor(c) {
        var w = st.work[c.key], o = st.saved[c.key];
        if (!w) return o ? { kind: 'off', price: 0 } : null;
        if (!o || o.index !== w.index) return { kind: 'new', price: c.price };
        if (!sameColour(o, w)) return { kind: 'colour', price: c.price * st.recolour };
        return null;
    }

    // ---------- render ----------
    function renderCats() {
        var html = '', group = null;
        st.cats.forEach(function (c) {
            if (c.group !== group) { group = c.group; html += '<div class="mcl-group">' + esc(groupLabel(group)) + '</div>'; }
            var changed = lineFor(c) ? '<span class="mcl-dot"></span>' : '';
            html += '<div class="mc-row' + (st.active === c.key ? ' active' : '') + '" data-cat="' + esc(c.key) + '">'
                + '<span>' + changed + esc(catLabel(c.key)) + '</span><span class="mc-sub">' + c.count + '</span></div>';
        });
        $('catList').innerHTML = html;
    }

    function renderEditor() {
        var c = st.byKey[st.active];
        if (!c) return;
        var w = st.work[c.key];
        $("catTitle").textContent = catLabel(c.key);
        $('catPrice').textContent = money(c.price);
        $("pieceName").textContent = w ? styleName(c.key, w.index) : L("ui_none");
        $('pieceCount').textContent = (w ? w.index : 0) + ' / ' + c.count;
        $('pieceReset').disabled = !st.saved[c.key] && !w;
        var showColour = st.colours && !!w;
        $('colourBox').classList.toggle('mc-hidden', !showColour);
        if (showColour) {
            $('palName').textContent = w.palette ? L("ui_palette_n", w.palette, st.palettes) : L("ui_original");
            $('tints').classList.toggle('mc-hidden', !w.palette);
            ['tint0', 'tint1', 'tint2'].forEach(function (t, i) {
                $('t' + i).value = w[t] || 0;
                $('t' + i + 'v').textContent = w[t] || 0;
            });
        }
        document.querySelectorAll('#cams .mc-tab').forEach(function (b) {
            b.classList.toggle('active', b.getAttribute('data-cam') === st.cam);
        });
    }

    function renderBasket() {
        var html = '', total = 0;
        st.cats.forEach(function (c) {
            var l = lineFor(c);
            if (!l) return;
            total += l.price;
            var what = l.kind === "off" ? L("ui_taken_off") : l.kind === "colour" ? L("ui_new_colour") : styleName(c.key, st.work[c.key].index);
            html += '<div class="mc-row"><span>' + esc(catLabel(c.key)) + ' <span class="mc-sub">' + esc(what) + '</span></span>'
                + '<span class="mc-money">' + (l.price > 0 ? money(l.price) : L("ui_free")) + '</span></div>';
        });
        total = Math.round(total * 100) / 100;
        $('basket').innerHTML = html || '<div class="mc-empty">' + esc(L("ui_empty")) + '</div>';
        $('total').textContent = money(total);
        $('cash').textContent = money(st.cash);
        $('cash').parentNode.classList.toggle('short', total > st.cash);
        $('btnBuy').disabled = st.busy || total > st.cash;
        $("btnBuy").textContent = total > 0 ? L("ui_pay") : L("ui_keep");
    }

    function renderAll() { renderCats(); renderEditor(); renderBasket(); }

    function msg(text) {
        $('msg').textContent = text || '';
        $('msg').classList.toggle('mc-hidden', !text);
    }

    // ---------- actions ----------
    var previewTimer = null;
    function preview(key, now) {
        clearTimeout(previewTimer);
        var send = function () {
            post('preview', { cat: key, piece: st.work[key] }).then(function (r) {
                if (r && r.name) st.names[key] = r.name; else if (!st.work[key]) delete st.names[key];
                if (key === st.active) renderEditor();
                renderBasket();
            });
        };
        if (now) send(); else previewTimer = setTimeout(send, st.previewDelay);
    }

    function setCam(region) {
        if (!region || region === st.cam) return;
        st.cam = region;
        post('camera', { region: region });
    }

    function select(key) {
        if (!st.byKey[key]) return;
        st.active = key;
        setCam(st.byKey[key].cam);
        msg('');
        renderAll();
    }

    function setIndex(i) {
        var c = st.byKey[st.active];
        if (!c) return;
        if (i < 0) i = c.count; else if (i > c.count) i = 0;
        if (i === 0) {
            st.work[c.key] = null;
        } else {
            var w = st.work[c.key] || {};
            st.work[c.key] = { index: i, palette: w.palette, tint0: w.tint0, tint1: w.tint1, tint2: w.tint2 };
            if (!st.work[c.key].palette) st.work[c.key] = { index: i };
        }
        renderAll();
        preview(c.key);
    }

    function step(d) {
        var w = st.work[st.active];
        setIndex((w ? w.index : 0) + d);
    }

    function setPalette(d) {
        var w = st.work[st.active];
        if (!w) return;
        var p = (w.palette || 0) + d;
        if (p < 0) p = st.palettes; else if (p > st.palettes) p = 0;
        if (p === 0) { delete w.palette; delete w.tint0; delete w.tint1; delete w.tint2; }
        else { w.palette = p; w.tint0 = w.tint0 || 0; w.tint1 = w.tint1 || 0; w.tint2 = w.tint2 || 0; }
        renderEditor(); renderBasket();
        preview(st.active);
    }

    function buy() {
        if (st.busy) return;
        st.busy = true; renderBasket(); msg('');
        post('buy').then(function (r) {
            st.busy = false;
            if (r && r.ok) { close(); return; }
            msg((r && r.msg) || L("failed"));
            renderBasket();
        });
    }

    function cancel() { close(); post('cancel'); }

    function close() {
        st.open = false;
        $('app').classList.add('mc-hidden');
    }

    function open(d) {
        st.cats = d.categories || [];
        st.byKey = {}; st.work = {}; st.names = {};
        st.saved = d.saved || {};
        st.cats.forEach(function (c) {
            st.byKey[c.key] = c;
            st.work[c.key] = copy(c.current);
            if (c.name) st.names[c.key] = c.name;
        });
        st.cash = Number(d.cash) || 0;
        st.recolour = Number(d.recolour) || 0;
        st.colours = d.colours !== false;
        st.palettes = Number(d.palettes) || 0;
        st.busy = false; st.cam = 'full';
        st.locale = d.locale || {};
        st.currency = d.currency || "";
        st.previewDelay = Number(d.previewDelay) || 0;
        $("app").classList.toggle("mc-cyrillic", d.lang === "ru");
        applyStatic();
        $("storeName").textContent = d.store || "";
        msg('');
        st.open = true;
        $('app').classList.remove('mc-hidden');
        st.active = null;
        if (st.cats.length) select(st.cats[0].key);
    }

    // ---------- events ----------
    $('catList').addEventListener('click', function (e) {
        var row = e.target.closest('[data-cat]');
        if (row) select(row.getAttribute('data-cat'));
    });
    $('pieceDown').onclick = function () { step(-1); };
    $('pieceUp').onclick = function () { step(1); };
    $('pieceNone').onclick = function () { setIndex(0); };
    $('pieceReset').onclick = function () {
        st.work[st.active] = copy(st.saved[st.active]);
        renderAll(); preview(st.active, true);
    };
    $('pieceJump').addEventListener('change', function () {
        var n = parseInt(this.value, 10);
        if (!isNaN(n)) setIndex(Math.max(0, Math.min(n, st.byKey[st.active].count)));
        this.value = '';
    });
    $('palDown').onclick = function () { setPalette(-1); };
    $('palUp').onclick = function () { setPalette(1); };
    [0, 1, 2].forEach(function (i) {
        $('t' + i).addEventListener('input', function () {
            var w = st.work[st.active];
            if (!w || !w.palette) return;
            w['tint' + i] = parseInt(this.value, 10) || 0;
            $('t' + i + 'v').textContent = w['tint' + i];
            renderBasket(); renderCats();
            preview(st.active);
        });
    });
    document.querySelectorAll('[data-cam]').forEach(function (b) {
        b.onclick = function () { setCam(b.getAttribute('data-cam')); renderEditor(); };
    });
    document.querySelectorAll('[data-rot]').forEach(function (b) {
        b.onclick = function () { post('rotate', { dir: Number(b.getAttribute('data-rot')) }); };
    });
    $('btnBuy').onclick = buy;
    $('btnCancel').onclick = cancel;

    document.addEventListener('keydown', function (e) {
        if (!st.open || e.target.tagName === 'INPUT' && e.target.type === 'number') return;
        var k = e.key.toLowerCase();
        if (k === 'escape') cancel();
        else if (k === 'a') post('rotate', { dir: -1 });
        else if (k === 'd') post('rotate', { dir: 1 });
        else if (k === 'arrowleft') step(-1);
        else if (k === 'arrowright') step(1);
    });

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.action === 'open') open(d);
        else if (d.action === 'close') close();
    });

    window.MULTIclothing = { open: open }; // for the preview mock
})();
