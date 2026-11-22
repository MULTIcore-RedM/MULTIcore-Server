/* MULTIhelpers NUI: vorp_menu, vorp_inputs and vorp_progressbar stand-ins. Own code, GPL v3. */
(function () {
    'use strict';

    var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'MULTIhelpers';
    function post(name, data) {
        return fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }
    function $(id) { return document.getElementById(id); }

    // ------------------------------------------------------------ safe HTML
    // VORP scripts put small bits of HTML (spans, colours, <br>) in labels and descriptions.
    // Keep the markup, drop anything that runs code.
    var BAD_TAGS = { SCRIPT: 1, IFRAME: 1, OBJECT: 1, EMBED: 1, LINK: 1, META: 1, BASE: 1, FORM: 1, INPUT: 1, TEXTAREA: 1, BUTTON: 1, SELECT: 1 };
    function clean(node) {
        var kids = Array.prototype.slice.call(node.childNodes);
        kids.forEach(function (k) {
            if (k.nodeType !== 1) return;
            if (BAD_TAGS[k.tagName]) { k.remove(); return; }
            Array.prototype.slice.call(k.attributes).forEach(function (a) {
                var n = a.name.toLowerCase(), v = String(a.value).toLowerCase().replace(/\s+/g, '');
                if (n.indexOf('on') === 0 || v.indexOf('javascript:') >= 0) k.removeAttribute(a.name);
            });
            clean(k);
        });
    }
    function setHtml(el, html) {
        if (html === undefined || html === null) html = '';
        var t = document.createElement('template');
        t.innerHTML = String(html);
        clean(t.content);
        el.innerHTML = '';
        el.appendChild(t.content);
    }
    function esc(s) {
        return String(s === undefined || s === null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    // ================================================================ menu
    var M = null;            // view sent by Lua: { id, title, elements, index, ... }
    var scroll = 0;          // first row on screen
    var controls = [];       // extra keys from RegisterControls
    var GRID_COLS = 4;

    // ------------------------------------------------------------ language + settings (from config.lua)
    var TEXT = {};
    var CFG = { menu: { keys: {} }, inputs: {}, progress: {} };
    var KEYS = { Up: 'ArrowUp', Down: 'ArrowDown', Left: 'ArrowLeft', Right: 'ArrowRight', Select: 'Enter', Back: 'Backspace', Close: 'Escape', NextSlider: 'Tab' };
    var RESERVED = {};
    function T(key) { return TEXT[key] !== undefined ? TEXT[key] : key; }
    function keyName(k) { return TEXT['keyname_' + k] !== undefined ? TEXT['keyname_' + k] : k; }
    function applySettings(s) {
        s = s || {};
        TEXT = s.text || {};
        CFG.menu = s.menu || CFG.menu;
        CFG.inputs = s.inputs || CFG.inputs;
        CFG.progress = s.progress || CFG.progress;
        var k = CFG.menu.keys || {};
        Object.keys(KEYS).forEach(function (n) { if (k[n]) KEYS[n] = String(k[n]); });
        RESERVED = {};
        Object.keys(KEYS).forEach(function (n) { RESERVED[KEYS[n]] = n; });
        GRID_COLS = Math.max(1, Number(CFG.menu.gridColumns) || 4);
        document.querySelectorAll('.mc-root').forEach(function (r) { r.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(s.lang)); });
        var root = document.documentElement.style;
        if (CFG.menu.offsetTop) root.setProperty('--mh-menu-top', CFG.menu.offsetTop);
        if (CFG.menu.offsetSide) root.setProperty('--mh-menu-side', CFG.menu.offsetSide);
        if (CFG.menu.width) root.setProperty('--mh-menu-width', CFG.menu.width);
        if (CFG.inputs.width) root.setProperty('--mh-dialog-width', CFG.inputs.width);
        if (CFG.progress.bottom) root.setProperty('--mh-progress-bottom', CFG.progress.bottom);
        if (CFG.progress.width) root.setProperty('--mh-progress-width', CFG.progress.width);
        if (CFG.progress.circleSize) root.setProperty('--mh-circle-size', CFG.progress.circleSize);
        if (CFG.progress.color) root.setProperty('--mh-progress-color', CFG.progress.color);
        if (CFG.progress.trackColor) root.setProperty('--mh-progress-track', CFG.progress.trackColor);
        var gc = document.getElementById('menu-list'); if (gc) gc.style.setProperty('--mh-grid-cols', GRID_COLS);
    }
    window.addEventListener('load', function () {
        fetch('https://' + RES + '/ready', { method: 'POST', body: '{}' })
            .then(function (r) { return r.json(); })
            .then(function (s) { if (s && s.text) applySettings(s); })
            .catch(function () {});
    });

    function els() { return (M && M.elements) || []; }
    function selectable(e) { return e && !e.isNotSelectable; }
    function num(v, d) { v = Number(v); return isFinite(v) ? v : d; }
    function decimals(x) { var s = String(x); var i = s.indexOf('.'); return i < 0 ? 0 : s.length - i - 1; }
    function step(value, dir, min, max, hop) {
        hop = num(hop, 1) || 1;
        var v = num(value, min) + dir * hop;
        v = Math.max(min, Math.min(max, v));
        var d = Math.max(decimals(hop), decimals(min));
        return Number(v.toFixed(d));
    }
    function sliderRange(e) { return { min: num(e.min, 0), max: num(e.max, 100), hop: num(e.hop, 1) }; }

    function menuShow(view) {
        var same = M && M.id === view.id;
        M = view;
        if (!same) scroll = 0;
        var root = $('menu');
        var cyr = root.classList.contains('mc-cyrillic');
        root.className = 'mc-root mc-panel mh-menu align-' + (M.align || CFG.menu.align || 'top-left') + (M.isGrid ? ' grid' : '') + (cyr ? ' mc-cyrillic' : '');
        setHtml($('menu-title'), M.title);
        setHtml($('menu-subtext'), M.subtext);
        renderMenu();
    }

    function menuHide() {
        M = null;
        $('menu').classList.add('mc-hidden');
    }

    function visibleCount() { return Math.max(1, num(M.maxVisibleItems, 8)); }

    function keepInView() {
        var n = els().length, idx = M.index - 1;
        if (M.isGrid) {
            var rows = visibleCount();             // rows of tiles on screen
            var row = Math.floor(idx / GRID_COLS);
            if (row < scroll) scroll = row;
            if (row >= scroll + rows) scroll = row - rows + 1;
            return;
        }
        var vis = visibleCount();
        if (idx < scroll) scroll = idx;
        if (idx >= scroll + vis) scroll = idx - vis + 1;
        scroll = Math.max(0, Math.min(scroll, Math.max(0, n - vis)));
    }

    function rowRight(e, active) {
        var t = e.type, html = '';
        if (t === 'slider') {
            var r = sliderRange(e), v = num(e.value, r.min);
            html = '<span class="mh-arrow' + (v <= r.min ? ' off' : '') + '" data-dir="-1">&#8249;</span>' +
                   '<span class="mh-val">' + esc(v) + '</span>' +
                   '<span class="mh-arrow' + (v >= r.max ? ' off' : '') + '" data-dir="1">&#8250;</span>';
        } else if (t === 'label-slider') {
            var r2 = sliderRange(e), v2 = num(e.value, r2.min);
            var pct = r2.max > r2.min ? ((v2 - r2.min) / (r2.max - r2.min)) * 100 : 0;
            var at = e.attributes || {};
            html = '<span class="mh-arrow" data-dir="-1">&#8249;</span>' +
                   '<span class="mh-bar" style="' + (at.trackColor ? 'background:' + esc(at.trackColor) : '') + '"><div style="width:' + pct + '%;' +
                   (at.fillColor ? 'background:' + esc(at.fillColor) : '') + '"></div></span>' +
                   '<span class="mh-arrow" data-dir="1">&#8250;</span>';
        } else if (t === 'text-slider') {
            var list = e.textList || [], ti = num(e.textIndex, 1);
            var cur = list[ti - 1];
            html = '<span class="mh-arrow' + (ti <= 1 ? ' off' : '') + '" data-dir="-1">&#8249;</span>' +
                   '<span class="mh-val mh-html" data-html="1"></span>' +
                   '<span class="mh-arrow' + (ti >= list.length ? ' off' : '') + '" data-dir="1">&#8250;</span>';
            return { html: html, text: cur ? cur.label : '' };
        } else if (t === 'desc-slider') {
            html = '<span class="mh-arrow" data-dir="-1">&#8249;</span><span class="mh-arrow" data-dir="1">&#8250;</span>';
        } else if (t === 'tick-box') {
            var boxes = e.tickBoxes || [], on = 0;
            boxes.forEach(function (b) { if (b.value === 'ticked') on++; });
            html = '<span class="mh-val">' + on + '/' + boxes.length + '</span>';
        } else if (e.tickBox) {
            html = '<span class="mh-tick' + (e.value === 'ticked' ? ' on' : '') + '"></span>';
        }
        return { html: html };
    }

    function renderMenu() {
        if (!M) return;
        var list = $('menu-list'), all = els();
        M.index = Math.max(1, Math.min(all.length || 1, num(M.index, 1)));
        keepInView();
        list.className = 'mh-list' + (M.divider ? ' divider' : '') + (M.isGrid ? ' grid' : '');
        list.innerHTML = '';

        var vis = visibleCount();
        var from = M.isGrid ? scroll * GRID_COLS : scroll;
        var to = M.isGrid ? Math.min(all.length, from + vis * GRID_COLS) : Math.min(all.length, from + vis);

        for (var i = from; i < to; i++) {
            (function (i) {
                var e = all[i], idx = i + 1, active = idx === M.index;
                var row = document.createElement('div');
                if (M.isGrid) {
                    row.className = 'mh-tile' + (active ? ' active' : '') + (e.isDisabled ? ' disabled' : '');
                    if (e.image) { var img = document.createElement('img'); img.src = e.image; row.appendChild(img); }
                    var lb = document.createElement('div'); setHtml(lb, e.label); row.appendChild(lb);
                } else {
                    var cls = 'mc-row';
                    if (!selectable(e)) cls += ' unselectable';
                    else if (active) cls += ' active';
                    if (e.isDisabled) cls += ' disabled';
                    if ((e.labelPos || M.labelPos) === 'center') cls += ' center';
                    row.className = cls;
                    var h = e.itemHeight || M.itemHeight;
                    if (h) row.style.minHeight = h;
                    var label = document.createElement('span');
                    label.className = 'mh-label';
                    setHtml(label, e.label);
                    row.appendChild(label);
                    var right = rowRight(e, active);
                    if (right.html) {
                        var r = document.createElement('span');
                        r.className = 'mh-right';
                        r.innerHTML = right.html;
                        var slot = r.querySelector('[data-html]');
                        if (slot) setHtml(slot, right.text);
                        row.appendChild(r);
                    }
                }
                if (M.fixedHeight && !M.isGrid) row.style.flex = '0 0 auto';
                row.addEventListener('mouseenter', function () { if (M.cursor && selectable(e)) select(idx); });
                row.addEventListener('click', function (ev) {
                    if (!selectable(e)) return;
                    var dir = ev.target && ev.target.getAttribute && ev.target.getAttribute('data-dir');
                    if (dir) { select(idx); slide(Number(dir)); return; }
                    select(idx); submit();
                });
                list.appendChild(row);
            })(i);
        }

        // keep the list the same height when asked (fixedHeight), so the panel does not jump
        if (M.fixedHeight && !M.isGrid && list.firstChild) {
            list.style.minHeight = (list.firstChild.offsetHeight + 3) * vis + 'px';
        } else {
            list.style.minHeight = '';
        }

        var selCount = all.filter(selectable).length;
        var pos = all.slice(0, M.index).filter(selectable).length;
        $('menu-count').textContent = selCount > vis ? pos + ' / ' + selCount : '';
        renderDesc();
        renderButtons();
        renderKeys();
        $('menu').classList.remove('mc-hidden');
    }

    function renderDesc() {
        var e = els()[M.index - 1], box = $('menu-desc');
        box.innerHTML = '';
        if (!e) { box.classList.add('mc-hidden'); return; }
        var any = false;
        if (e.desc !== undefined && e.desc !== null && e.desc !== '') {
            var d = document.createElement('div'); setHtml(d, e.desc); box.appendChild(d); any = true;
        }
        if (e.type === 'desc-slider' && Array.isArray(e.sliders)) {
            var si = num(e.sliderIndex, 1);
            e.sliders.forEach(function (s, k) {
                var r = sliderRange(s), v = num(s.value, r.min);
                var pct = r.max > r.min ? ((v - r.min) / (r.max - r.min)) * 100 : 0;
                var at = s.attributes || {};
                var w = document.createElement('div');
                w.className = 'mh-sub' + (k + 1 === si ? ' active' : '');
                w.innerHTML = '<span class="mc-slider-label"></span><span class="mh-val">' + esc(v) + '</span>' +
                    '<span class="mh-bar"' + (at.trackColor ? ' style="background:' + esc(at.trackColor) + '"' : '') + '><div style="width:' + pct + '%;' +
                    (at.fillColor ? 'background:' + esc(at.fillColor) : '') + '"></div></span>';
                setHtml(w.firstChild, s.label);
                w.addEventListener('click', function (ev) {
                    var rect = w.querySelector('.mh-bar').getBoundingClientRect();
                    var dir = ev.clientX < rect.left + rect.width / 2 ? -1 : 1;
                    e.sliderIndex = k + 1;
                    slide(dir);
                });
                box.appendChild(w);
            });
            any = true;
        }
        if (e.type === 'tick-box' && Array.isArray(e.tickBoxes)) {
            var ti = num(e.tickBoxIndex, 1);
            var wrap = document.createElement('div'); wrap.className = 'mh-boxes';
            e.tickBoxes.forEach(function (b, k) {
                var it = document.createElement('div');
                it.className = 'mh-box' + (k + 1 === ti ? ' active' : '');
                it.innerHTML = '<span class="mh-tick' + (b.value === 'ticked' ? ' on' : '') + '"></span><span></span>';
                setHtml(it.lastChild, b.label);
                it.addEventListener('click', function () { e.tickBoxIndex = k + 1; submit(); });
                wrap.appendChild(it);
            });
            box.appendChild(wrap); any = true;
        }
        if (e.descPrice && typeof e.descPrice === 'object') {
            var p = document.createElement('div'); p.className = 'mh-price';
            var icon = e.descPrice.icon === 'gold' ? 'gold' : 'money';
            var amt = num(e.descPrice.amount, 0);
            p.innerHTML = '<span class="mh-coin ' + icon + '"></span><span>' +
                (icon === 'money' ? '$' + amt.toFixed(2) : esc(amt)) + '</span><span class="mc-note"></span>';
            setHtml(p.lastChild, e.descPrice.text);
            box.appendChild(p); any = true;
        }
        if (e.footerText) {
            var f = document.createElement('div'); f.className = 'mh-footer'; setHtml(f, e.footerText);
            box.appendChild(f); any = true;
        }
        box.classList.toggle('mc-hidden', !any);
    }

    function renderButtons() {
        var b = $('menu-buttons');
        b.innerHTML = '';
        var any = false;
        [['cancel', M.cancelButton], ['confirm', M.confirmButton]].forEach(function (pair) {
            var cfg = pair[1];
            if (!cfg || typeof cfg !== 'object') return;
            var btn = document.createElement('button');
            btn.className = 'mc-btn small' + (pair[0] === 'confirm' ? ' primary' : '');
            setHtml(btn, cfg.label || pair[0]);
            btn.addEventListener('click', function () { if (!dialogOpen()) post('menu', { ev: 'button', id: M.id, which: pair[0] }); });
            b.appendChild(btn); any = true;
        });
        b.classList.toggle('mc-hidden', !any);
    }

    function renderKeys() {
        var box = $('menu-keys');
        if (CFG.menu.keyHints === false) { box.innerHTML = ''; return; }
        var e = els()[M.index - 1] || {};
        function hint(keys, text) { return '<span><span class="mh-key">' + keys + '</span>' + esc(T(text)) + '</span>'; }
        var arrows = { ArrowUp: '&#8593;', ArrowDown: '&#8595;', ArrowLeft: '&#8592;', ArrowRight: '&#8594;' };
        function kn(k) { return arrows[k] || esc(keyName(k)); }
        var parts = [hint(kn(KEYS.Up) + kn(KEYS.Down), 'key_move')];
        if (/slider|tick-box/.test(e.type || '') || M.isGrid) parts.push(hint(kn(KEYS.Left) + kn(KEYS.Right), 'key_change'));
        if (e.type === 'desc-slider') parts.push(hint(kn(KEYS.NextSlider), 'key_next'));
        parts.push(hint(kn(KEYS.Select), 'key_select'));
        parts.push(hint(kn(M.lastmenu ? KEYS.Back : KEYS.Close), 'key_back'));
        box.innerHTML = parts.join('');
    }

    function select(idx) {
        if (!M || idx === M.index) return;
        M.index = idx;
        renderMenu();
        post('menu', { ev: 'select', id: M.id, index: idx });
    }

    function move(dir) {
        var all = els(), n = all.length;
        if (!n) return;
        var i = M.index;
        for (var k = 0; k < n; k++) {
            i += dir;
            if (i < 1) i = n;
            if (i > n) i = 1;
            if (selectable(all[i - 1])) break;
        }
        select(i);
    }

    function moveGrid(delta) {
        var n = els().length, i = M.index + delta;
        if (i < 1 || i > n) return;
        select(i);
    }

    function slide(dir) {
        var e = els()[M.index - 1];
        if (!e || e.isDisabled) return;
        var msg = { ev: 'slide', id: M.id, index: M.index, dir: dir < 0 ? 'left' : 'right' };
        var t = e.type;
        if (t === 'slider' || t === 'label-slider') {
            var r = sliderRange(e), nv = step(e.value, dir, r.min, r.max, r.hop);
            if (nv === num(e.value, r.min)) return;
            e.value = nv; msg.value = nv;
        } else if (t === 'text-slider') {
            var list = e.textList || [], ti = num(e.textIndex, 1) + dir;
            if (ti < 1 || ti > list.length) return;
            e.textIndex = ti; msg.textIndex = ti;
        } else if (t === 'desc-slider') {
            var si = num(e.sliderIndex, 1), s = (e.sliders || [])[si - 1];
            if (!s) return;
            var rr = sliderRange(s), sv = step(s.value, dir, rr.min, rr.max, rr.hop);
            if (sv === num(s.value, rr.min)) return;
            s.value = sv; msg.sliderIndex = si; msg.value = sv;
        } else if (t === 'tick-box') {
            var boxes = e.tickBoxes || [], bi = num(e.tickBoxIndex, 1) + dir;
            if (bi < 1 || bi > boxes.length) return;
            e.tickBoxIndex = bi; msg.tickBoxIndex = bi;
        } else {
            return;
        }
        renderMenu();
        post('menu', msg);
    }

    function cycleSub() {
        var e = els()[M.index - 1];
        if (!e || e.type !== 'desc-slider' || !Array.isArray(e.sliders) || !e.sliders.length) return;
        e.sliderIndex = (num(e.sliderIndex, 1) % e.sliders.length) + 1;
        renderDesc();
    }

    function submit() {
        var e = els()[M.index - 1];
        if (!e || e.isDisabled || !selectable(e)) return;
        var msg = { ev: 'submit', id: M.id, index: M.index };
        if (e.type === 'tick-box') msg.tickBoxIndex = num(e.tickBoxIndex, 1);
        post('menu', msg);
    }

    function control(name) {
        if (controls.indexOf(name) >= 0 || (name.indexOf('mousepress') === 0 && controls.indexOf('mousepress') >= 0)) {
            post('menu', { ev: 'control', name: name });
        }
    }

    // ================================================================ dialog
    var D = null;
    var PRESETS = {
        letters: { re: /^[\p{L}\s]*$/u, msg: 'err_letters' },
        numbers: { re: /^[0-9]*$/, msg: 'err_numbers' },
        alphanumeric: { re: /^[\p{L}0-9\s]*$/u, msg: 'err_alphanumeric' },
        'no-symbols': { re: /^[\p{L}0-9\s.,!?'\-]*$/u, msg: 'err_no_symbols' },
        username: { re: /^[A-Za-z0-9_.\-]{3,}$/, msg: 'err_username' },
        phone: { re: /^[0-9+\-\s()]*$/, msg: 'err_phone' },
        email: { re: /^[^\s@]+@[^\s@]+\.[^\s@]+$/, msg: 'err_email' },
        money: { re: /^\d+(\.\d{1,2})?$/, msg: 'err_money' },
        'no-special': { re: /^[\p{L}\p{N}\s]*$/u, msg: 'err_no_special' }
    };

    function dialogOpen() { return D !== null; }

    function openDialog(spec) {
        D = spec;
        $('dialog-title').innerHTML = '';
        setHtml($('dialog-title'), spec.header || '');
        $('dialog-title').classList.toggle('mc-hidden', !spec.header);
        setHtml($('dialog-desc'), spec.description || '');
        $('dialog-error').textContent = '';
        setHtml($('dialog-ok'), spec.button || T(spec.kind === 'yesno' ? 'yes' : 'confirm'));
        setHtml($('dialog-cancel'), spec.cancelButton || T(spec.kind === 'yesno' ? 'no' : 'cancel'));

        var field = $('dialog-field');
        field.innerHTML = '';
        if (spec.kind !== 'yesno') {
            var t = String(spec.inputType || 'text');
            var inp;
            if (t === 'textarea') {
                inp = document.createElement('textarea');
                inp.className = 'mc-textarea';
            } else {
                inp = document.createElement('input');
                inp.className = 'mc-input';
                inp.type = ['text', 'number', 'password', 'date', 'email', 'tel'].indexOf(t) >= 0 ? t : 'text';
            }
            inp.id = 'dialog-input';
            if (spec.placeholder) inp.placeholder = String(spec.placeholder);
            if (spec.pattern && !PRESETS[spec.pattern] && inp.tagName === 'INPUT') inp.pattern = String(spec.pattern);
            if (spec.title) inp.title = String(spec.title);
            if (spec.min !== undefined && spec.min !== null) inp.min = spec.min;
            if (spec.max !== undefined && spec.max !== null) inp.max = spec.max;
            if (spec.step !== undefined && spec.step !== null) inp.step = spec.step;
            if (spec.minLength) inp.minLength = Number(spec.minLength);
            if (spec.maxLength) inp.maxLength = Number(spec.maxLength);
            if (spec.value !== undefined && spec.value !== null) inp.value = String(spec.value);
            if (spec.style) inp.setAttribute('style', String(spec.style));
            field.appendChild(inp);
        }
        $('dialog-wrap').classList.remove('mc-hidden');
        var focusEl = $('dialog-input') || $('dialog-ok');
        setTimeout(function () { focusEl.focus(); }, 30);
    }

    function closeDialog() {
        D = null;
        $('dialog-wrap').classList.add('mc-hidden');
        $('dialog-field').innerHTML = '';
    }

    function answer(ok) {
        if (!D) return;
        var token = D.token;
        if (!ok) { closeDialog(); post('dialog', { token: token, result: 'cancel' }); return; }
        if (D.kind === 'yesno') { closeDialog(); post('dialog', { token: token, result: 'submit', value: 'yes' }); return; }
        var inp = $('dialog-input'), v = inp.value;
        var err = '';
        var preset = PRESETS[D.preset] || PRESETS[D.pattern];
        if (preset && !preset.re.test(v)) err = D.title || T(preset.msg);
        else if (D.preset && !PRESETS[D.preset]) {
            try { if (!new RegExp('^(?:' + D.preset + ')$').test(v)) err = D.title || T('err_not_allowed'); } catch (x) { /* bad pattern: ignore */ }
        }
        if (!err && inp.validity && inp.validity.badInput) err = D.title || T('err_numbers');
        if (!err && inp.checkValidity && !inp.checkValidity()) err = D.title || T('err_not_allowed');
        if (err) { $('dialog-error').textContent = err; inp.focus(); return; }
        closeDialog();
        post('dialog', { token: token, result: 'submit', value: v });
    }

    $('dialog').addEventListener('submit', function (ev) { ev.preventDefault(); answer(true); });
    $('dialog-cancel').addEventListener('click', function () { answer(false); });

    // ================================================================ progress
    var P = null, raf = 0;

    function progressShow(d) {
        P = d;
        var wrap = $('progress'), circle = d.theme === 'circle' || d.theme === 'innercircle';
        $('progress-linear').classList.toggle('mc-hidden', circle);
        $('progress-circle').classList.toggle('mc-hidden', !circle);
        $('progress-circle').classList.toggle('inner', d.theme === 'innercircle');
        setHtml($('progress-label'), d.label);
        setHtml($('progress-clabel'), d.label);
        var fill = $('progress-fill'), ring = $('progress-ring');
        fill.style.background = d.color || '';
        if (d.color) ring.style.setProperty('--c', d.color); else ring.style.removeProperty('--c');
        $('progress-linear').style.width = (!circle && d.width) || '';
        if (circle && d.width) { ring.style.width = d.width; ring.style.height = d.width; } else { ring.style.width = ''; ring.style.height = ''; }
        $('progress-pct').classList.toggle('mc-hidden', CFG.progress.showPercent === false);
        wrap.classList.remove('mc-hidden');
        var startAt = performance.now() - (Number(d.elapsed) || 0);
        var dur = Math.max(1, Number(d.duration) || 1);
        cancelAnimationFrame(raf);
        function tick(now) {
            if (P !== d) return;
            var pct = Math.min(100, ((now - startAt) / dur) * 100);
            fill.style.width = pct + '%';
            ring.style.setProperty('--p', pct.toFixed(1));
            $('progress-pct').textContent = Math.floor(pct) + '%';
            if (pct < 100) raf = requestAnimationFrame(tick);   // stops when the bar is full
        }
        raf = requestAnimationFrame(tick);
    }

    function progressHide() {
        P = null;
        cancelAnimationFrame(raf);
        $('progress').classList.add('mc-hidden');
    }

    // ================================================================ input
    window.addEventListener('keydown', function (ev) {
        if (D) {
            if (ev.key === 'Escape') { ev.preventDefault(); answer(false); }
            else if (ev.key === 'Enter' && D.kind === 'yesno') { ev.preventDefault(); answer(true); }
            else if (ev.key === 'Enter' && ev.target && ev.target.tagName === 'TEXTAREA' && ev.ctrlKey) { ev.preventDefault(); answer(true); }
            return;
        }
        if (!M) return;
        var k = RESERVED[ev.key];
        if (!k) { control(ev.key); return; }
        ev.preventDefault();
        if (M.isGrid) {
            if (k === 'Left') return moveGrid(-1);
            if (k === 'Right') return moveGrid(1);
            if (k === 'Up') return moveGrid(-GRID_COLS);
            if (k === 'Down') return moveGrid(GRID_COLS);
        }
        if (k === 'Up') move(-1);
        else if (k === 'Down') move(1);
        else if (k === 'Left') slide(-1);
        else if (k === 'Right') slide(1);
        else if (k === 'NextSlider') cycleSub();
        else if (k === 'Select') { if (!ev.repeat) submit(); }
        else if (k === 'Back') { if (!ev.repeat) post('menu', { ev: 'back', id: M.id }); }
        else if (k === 'Close') { if (!ev.repeat) post('menu', { ev: 'cancel', id: M.id }); }
    });

    window.addEventListener('wheel', function (ev) {
        if (D || !M) return;
        var dir = ev.deltaY > 0 ? 1 : -1;
        control(dir > 0 ? 'scrolldown' : 'scrollup');
        if (M.isGrid) moveGrid(dir * GRID_COLS); else move(dir);
    }, { passive: true });

    window.addEventListener('mousedown', function (ev) {
        if (D || !M) return;
        if (ev.button === 0) control('mousepress_left');
        else if (ev.button === 2) control('mousepress_right');
    });
    window.addEventListener('contextmenu', function (ev) { ev.preventDefault(); });

    // ================================================================ messages from Lua
    window.addEventListener('message', function (ev) {
        var m = ev.data || {};
        switch (m.action) {
            case 'menuShow': menuShow(m.data); break;
            case 'menuHide': menuHide(); break;
            case 'menuControls': controls = Array.isArray(m.data) ? m.data.map(String) : []; break;
            case 'dialogOpen': openDialog(m.data || {}); break;
            case 'dialogClose': closeDialog(); break;
            case 'progressShow': progressShow(m.data || {}); break;
            case 'progressHide': progressHide(); break;
        }
    });

    // for the render preview
    window.MH = { menuShow: menuShow, openDialog: openDialog, progressShow: progressShow, applySettings: applySettings };
})();
