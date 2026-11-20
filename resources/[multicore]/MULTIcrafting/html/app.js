/* MULTIcrafting screen (GPL v3, part of MULTIcore by RINGO (RINGOscripting)).
   Lua owns the data: this page draws what the server sent and asks Lua to
   craft. It never changes items itself. */
(function () {
    'use strict';

    var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIcrafting';
    var $ = function (id) { return document.getElementById(id); };

    var st = { locale: {}, lang: 'en', images: [], open: false, s: null, tab: null, sel: 0, busy: false, amount: 1 };
    var resolved = {};
    var progressTimer = null;

    // ---------- words ----------
    function L(key) {
        var s = st.locale[key];
        if (s === undefined) return key;
        var args = Array.prototype.slice.call(arguments, 1);
        return String(s).replace(/%[sd]/g, function (m) { return args.length ? args.shift() : m; });
    }
    function applyStatic() {
        document.querySelectorAll('[data-l]').forEach(function (el) { el.textContent = L(el.getAttribute('data-l')); });
        $('app').classList.toggle('mc-cyrillic', st.lang === 'ru');
    }

    function post(name, data) {
        return fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then(function (r) { return r.json(); }).catch(function () { return {}; });
    }

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function num(n) { n = Number(n); return isFinite(n) ? n : 0; }
    function secs(n) {
        n = Math.round(num(n));
        if (n < 60) return L('ui_seconds', n);
        return L('ui_minutes', Math.floor(n / 60), n % 60 < 10 ? '0' + (n % 60) : n % 60);
    }

    // ---------- pictures: the inventory's image folders in order, then a drawn mark ----------
    function imgHtml(image) {
        if (!image || !st.images.length || resolved[image] === -1) return '<i class="mcr-fallback"></i>';
        var i = resolved[image] !== undefined ? resolved[image] : 0;
        return '<img data-img="' + esc(image) + '" data-i="' + i + '" src="' + esc(st.images[i] + image) + '" alt="">';
    }
    function wireImages(root) {
        root.querySelectorAll('img[data-img]').forEach(function (img) {
            if (img._wired) return;
            img._wired = true;
            img.onload = function () { resolved[img.getAttribute('data-img')] = num(img.getAttribute('data-i')); };
            img.onerror = function () {
                var name = img.getAttribute('data-img'), i = num(img.getAttribute('data-i')) + 1;
                if (i < st.images.length) { img.setAttribute('data-i', i); img.src = st.images[i] + name; return; }
                resolved[name] = -1;
                var f = document.createElement('i'); f.className = 'mcr-fallback';
                if (img.parentNode) img.parentNode.replaceChild(f, img);
            };
        });
    }

    // ---------- what is shown ----------
    function categories() {
        var seen = {}, out = [];
        (st.s && st.s.recipes || []).forEach(function (r) {
            if (!seen[r.category]) { seen[r.category] = true; out.push(r.category); }
        });
        return out;
    }
    function rows() {
        if (!st.s) return [];
        return (st.s.recipes || []).filter(function (r) { return r.category === st.tab; });
    }
    function current() { return rows()[st.sel] || null; }
    function catLabel(c) { var k = 'cat_' + c; var t = L(k); return t === k ? L('cat_other') : t; }

    function drawTabs() {
        var cats = categories();
        if (cats.indexOf(st.tab) < 0) { st.tab = cats[0] || null; st.sel = 0; }
        $('tabs').innerHTML = cats.map(function (c) {
            return '<button class="mc-tab' + (c === st.tab ? ' active' : '') + '" data-c="' + esc(c) + '" type="button">' + esc(catLabel(c)) + '</button>';
        }).join('');
        $('tabs').classList.toggle('mc-hidden', cats.length < 2);
        $('tabs').querySelectorAll('.mc-tab').forEach(function (b) {
            b.onclick = function () { st.tab = b.getAttribute('data-c'); st.sel = 0; st.amount = 1; draw(); };
        });
    }

    function drawList() {
        var list = rows();
        if (st.sel >= list.length) st.sel = Math.max(0, list.length - 1);
        if (!list.length) {
            $('list').innerHTML = '<div class="mcr-empty">' + esc(L('ui_nothing')) + '</div>';
            return;
        }
        $('list').innerHTML = list.map(function (r, i) {
            var can = r.max > 0;
            var sub = !r.jobOk ? L('ui_job_only', r.jobLabel || '') : (can ? L('ui_can_make', r.max) : L('ui_missing'));
            return '<div class="mc-row mcr-row' + (i === st.sel ? ' active' : '') + (can ? '' : ' cant') + '" data-i="' + i + '">' +
                '<div class="mcr-pic">' + imgHtml(r.output.image) + '</div>' +
                '<div class="mcr-text"><div class="mcr-label">' + esc(r.label) + '</div>' +
                '<div class="mcr-sub' + (can ? '' : ' cant') + '">' + esc(sub) + '</div></div>' +
                '<div class="mcr-count">×' + num(r.output.amount) + '</div></div>';
        }).join('');
        wireImages($('list'));
        $('list').querySelectorAll('.mcr-row').forEach(function (el) {
            el.onclick = function () { st.sel = num(el.getAttribute('data-i')); st.amount = 1; draw(); };
            el.ondblclick = function () { craft(); };
        });
        var act = $('list').querySelector('.mcr-row.active');
        if (act && act.scrollIntoView) act.scrollIntoView({ block: 'nearest' });
    }

    function clampAmount(r) {
        var max = r ? Math.max(1, num(r.max)) : 1;
        st.amount = Math.min(Math.max(1, Math.floor(num(st.amount) || 1)), max);
    }

    function drawDetail() {
        var r = current();
        $('detail').classList.toggle('none', !r);
        if (!r) {
            $('dName').textContent = ''; $('dDesc').textContent = ''; $('dNeeds').innerHTML = '';
            $('dJob').classList.add('mc-hidden'); $('dGo').disabled = true;
            return;
        }
        clampAmount(r);
        $('dName').textContent = r.label + (r.output.amount > 1 ? '  ×' + r.output.amount : '');
        $('dDesc').textContent = r.output.desc || '';
        var needs = r.inputs.map(function (i) {
            var need = i.amount * st.amount, short = num(i.have) < need;
            return '<div class="mcr-need' + (short ? ' short' : '') + '"><div class="mcr-pic">' + imgHtml(i.image) + '</div>' +
                '<span>' + esc(i.label) + '</span><span class="mcr-have">' + num(i.have) + ' / ' + need + '</span></div>';
        });
        if (r.tool) {
            needs.push('<div class="mcr-need' + (r.tool.have ? '' : ' short') + '"><div class="mcr-pic">' + imgHtml(r.tool.image) + '</div>' +
                '<span>' + esc(r.tool.label) + '<span class="mcr-kept">' + esc(L('ui_tool_kept')) + '</span></span>' +
                '<span class="mcr-have">' + (r.tool.have ? '1' : '0') + ' / 1</span></div>');
        }
        $('dNeeds').innerHTML = needs.join('');
        wireImages($('dNeeds'));
        var job = $('dJob');
        if (r.jobLabel) {
            job.textContent = L('ui_job_only', r.jobLabel);
            job.classList.remove('mc-hidden');
            job.classList.toggle('cant', !r.jobOk);
        } else job.classList.add('mc-hidden');
        $('dTime').textContent = secs(num(r.time) * st.amount);
        $('dAmount').value = st.amount;
        $('dGo').disabled = st.busy || r.max < 1;
    }

    function drawFire() {
        var f = st.s && st.s.fire;
        $('fireRow').classList.toggle('mc-hidden', !(f && f.canPutOut));
    }

    function draw() {
        if (!st.s) return;
        $('title').textContent = st.s.station && st.s.station.label || '';
        drawTabs(); drawList(); drawDetail(); drawFire();
    }

    function setErr(text) { $('dErr').textContent = text || ''; }

    // ---------- actions ----------
    function craft() {
        var r = current();
        if (!r || st.busy || r.max < 1) return;
        st.busy = true; setErr(''); drawDetail();
        post('craft', { id: r.id, amount: st.amount }).then(function (res) {
            st.busy = false;
            if (!res || !res.ok) { setErr(res && res.err || ''); drawDetail(); }
        });
    }
    function step(d) { var r = current(); if (!r) return; st.amount = num(st.amount) + d; clampAmount(r); drawDetail(); }
    function move(d) {
        var list = rows();
        if (!list.length) return;
        st.sel = (st.sel + d + list.length) % list.length;
        st.amount = 1; setErr(''); drawList(); drawDetail();
    }
    function nextTab() {
        var cats = categories();
        if (cats.length < 2) return;
        st.tab = cats[(cats.indexOf(st.tab) + 1) % cats.length]; st.sel = 0; st.amount = 1; draw();
    }
    function close() { if (st.open) post('close'); }

    $('dMinus').onclick = function () { step(-1); };
    $('dPlus').onclick = function () { step(1); };
    $('dAmount').oninput = function () { st.amount = $('dAmount').value; var r = current(); clampAmount(r); drawDetail(); };
    $('dGo').onclick = craft;
    $('fireOut').onclick = function () { var f = st.s && st.s.fire; if (f) post('putOut', { id: f.id }); };

    document.addEventListener('keydown', function (e) {
        if (!st.open) return;
        if (e.key === 'Escape' || e.key === 'Backspace' && e.target.tagName !== 'INPUT') { e.preventDefault(); close(); }
        else if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
        else if (e.key === 'ArrowRight') { e.preventDefault(); step(1); }
        else if (e.key === 'ArrowLeft') { e.preventDefault(); step(-1); }
        else if (e.key === 'Tab') { e.preventDefault(); nextTab(); }
        else if (e.key === 'Enter') { e.preventDefault(); craft(); }
    });

    // ---------- progress ----------
    function progress(label, duration) {
        var fill = $('pFill');
        $('pLabel').textContent = label || '';
        fill.style.transition = 'none'; fill.style.width = '0%';
        $('progress').classList.remove('mc-hidden');
        void fill.offsetWidth;
        fill.style.transition = 'width ' + Math.max(0, num(duration)) + 'ms linear';
        fill.style.width = '100%';
        clearTimeout(progressTimer);
        progressTimer = setTimeout(function () { $('progress').classList.add('mc-hidden'); }, num(duration) + 3000);
    }

    // ---------- messages from Lua ----------
    window.addEventListener('message', function (ev) {
        var d = ev.data || {};
        if (d.action === 'setup') {
            st.locale = d.locale || {}; st.lang = d.lang || 'en'; st.images = d.images || [];
            if (d.cancelKey) $('pKey').textContent = d.cancelKey;
            applyStatic();
        } else if (d.action === 'open') {
            var keepTab = st.s && st.s.station && d.state && d.state.station && st.s.station.label === d.state.station.label;
            st.s = d.state; st.open = true; st.busy = false;
            if (!keepTab) { st.tab = null; st.sel = 0; st.amount = 1; }
            setErr('');
            $('menu').classList.remove('mc-hidden');
            draw();
        } else if (d.action === 'state') {
            st.s = d.state; draw();
        } else if (d.action === 'close') {
            st.open = false;
            $('menu').classList.add('mc-hidden');
        } else if (d.action === 'progress') {
            progress(d.label, d.duration);
        } else if (d.action === 'progressEnd') {
            clearTimeout(progressTimer);
            $('progress').classList.add('mc-hidden');
        }
    });
})();
