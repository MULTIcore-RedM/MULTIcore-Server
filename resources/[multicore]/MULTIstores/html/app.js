/* MULTIstores store screen (GPL v3, part of MULTIcore by RINGO (RINGOscripting)).
   Lua owns the data: this page draws what the server sent and asks Lua to
   buy or sell. It never changes money or stock itself; the server's answer
   (a fresh state) redraws it. */
(function () {
    'use strict';

    var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIstores';
    var $ = function (id) { return document.getElementById(id); };
    var SELL = '__sell';

    var st = {
        locale: {}, lang: 'en', images: [], sign: '$', max: 100,
        open: false, s: null, tab: null, sel: 0, busy: false
    };
    var resolved = {};

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
    // game money: $12 with small raised cents
    function money(n) {
        n = Math.round(num(n) * 100) / 100;
        var whole = Math.floor(n), cents = Math.round((n - whole) * 100);
        return esc(st.sign) + whole + '<span class="mc-cents">' + (cents < 10 ? '0' : '') + cents + '</span>';
    }

    // ---------- pictures: the inventory's image folders in order, then a drawn mark ----------
    function imgHtml(image) {
        if (!image || !st.images.length || resolved[image] === -1) return '<i class="ms-fallback"></i>';
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
                var f = document.createElement('i'); f.className = 'ms-fallback';
                if (img.parentNode) img.parentNode.replaceChild(f, img);
            };
        });
    }

    // ---------- what is shown ----------
    function selling() { return st.tab === SELL; }
    function rows() {
        if (!st.s) return [];
        if (selling()) return st.s.sell || [];
        return (st.s.items || []).filter(function (it) { return it.category === st.tab; });
    }
    function current() { return rows()[st.sel] || null; }
    function limitFor(it) {
        if (!it) return 1;
        var lim = st.max;
        if (selling()) lim = Math.min(lim, num(it.amount));
        else {
            if (it.stock !== undefined && it.stock !== null) lim = Math.min(lim, num(it.stock));
            if (num(it.price) > 0) lim = Math.min(lim, Math.max(1, Math.floor(num(st.s.cash) / num(it.price) + 1e-9)));
        }
        return Math.max(1, lim);
    }
    function amount() {
        var v = parseInt($('dAmount').value, 10);
        if (!isFinite(v) || v < 1) v = 1;
        return v;
    }

    function renderTabs() {
        var html = '';
        (st.s.categories || []).forEach(function (c) {
            html += '<button class="mc-tab' + (st.tab === c.key ? ' active' : '') + '" data-tab="' + esc(c.key) + '">' + esc(c.label) + '</button>';
        });
        if (st.s.buys) html += '<button class="mc-tab sell' + (selling() ? ' active' : '') + '" data-tab="' + SELL + '">' + esc(L('ui_sell')) + '</button>';
        $('tabs').innerHTML = html;
    }

    function rowHtml(it, i) {
        var cls = 'mc-row ms-row' + (i === st.sel ? ' active' : ''), sub = '', price;
        if (selling()) {
            sub = L('ui_you_have', num(it.amount));
            if (it.quality !== undefined && it.quality !== null) sub += ' &middot; ' + esc(L('ui_condition')) + ' ' + Math.round(num(it.quality)) + '%';
            price = money(it.price);
            if (it.tooPoor) cls += ' soldout';
        } else {
            var out = it.stock !== undefined && it.stock !== null && num(it.stock) <= 0;
            if (it.stock === undefined || it.stock === null) sub = '';
            else if (out) sub = '<span class="ms-sub out">' + esc(L('ui_sold_out')) + '</span>';
            else sub = esc(L('ui_in_stock', num(it.stock)));
            if (out) cls += ' soldout';
            if (num(it.price) > num(st.s.cash)) cls += ' cant';
            price = num(it.price) === 0 ? esc(L('ui_free')) : money(it.price);
        }
        return '<div class="' + cls + '" data-i="' + i + '">'
            + '<div class="ms-pic">' + imgHtml(it.image) + '</div>'
            + '<div class="ms-text"><div class="ms-label">' + esc(it.label) + '</div><div class="ms-sub">' + sub + '</div></div>'
            + '<div class="mc-money ms-price">' + price + '</div></div>';
    }

    function renderList() {
        var list = rows(), html = '';
        if (st.sel >= list.length) st.sel = Math.max(0, list.length - 1);
        list.forEach(function (it, i) { html += rowHtml(it, i); });
        if (!list.length) html = '<div class="ms-empty">' + esc(L(selling() ? 'ui_nothing_to_sell' : 'ui_nothing_for_sale')) + '</div>';
        $('list').innerHTML = html;
        wireImages($('list'));
        var a = $('list').querySelector('.ms-row.active');
        if (a && a.scrollIntoView) a.scrollIntoView({ block: 'nearest' });
    }

    function renderDetail() {
        var it = current(), d = $('detail');
        d.classList.toggle('none', !it);
        $('pGo').textContent = L(selling() ? 'ui_sell' : 'ui_buy');
        $('dGo').textContent = L(selling() ? 'ui_sell' : 'ui_buy');
        if (!it) {
            $('dName').textContent = '';
            $('dDesc').textContent = '';
            $('dCant').classList.add('mc-hidden');
            return;
        }
        var n = Math.min(amount(), limitFor(it));
        if (String(n) !== $('dAmount').value) $('dAmount').value = n;
        $('dName').textContent = it.label;
        $('dDesc').textContent = selling() ? '' : (it.desc || '');
        $('dEachLabel').textContent = L(selling() ? 'ui_pays_each' : 'ui_price_each');
        $('dEach').innerHTML = money(it.price);
        $('dTotalLabel').textContent = L(selling() ? 'ui_you_get' : 'ui_total');
        var total = Math.round(n * num(it.price) * 100) / 100;
        $('dTotal').innerHTML = money(total);
        var cant = false, blocked = false;
        if (selling()) blocked = !!it.tooPoor;
        else {
            cant = total > num(st.s.cash) + 1e-9;
            blocked = it.stock !== undefined && it.stock !== null && num(it.stock) <= 0;
        }
        $('dTotalLine').classList.toggle('cant', cant);
        $('dCant').classList.toggle('mc-hidden', !cant && !blocked);
        $('dCant').textContent = cant ? L('ui_cant_afford') : (selling() ? L('ui_too_poor') : L('ui_sold_out'));
        $('dGo').disabled = cant || blocked || st.busy;
    }

    function render() {
        if (!st.s) return;
        $('type').textContent = st.s.typeLabel || '';
        $('title').textContent = st.s.label || '';
        fitTitle($('title'));
        $('cash').innerHTML = money(st.s.cash);
        renderTabs();
        renderList();
        renderDetail();
    }

    // long names shrink to fit the column (one line, like the game)
    function fitTitle(el) {
        el.style.fontSize = '';
        var size = parseFloat(getComputedStyle(el).fontSize), min = size * 0.55;
        while (el.scrollWidth > el.clientWidth + 1 && size > min) { size -= 1; el.style.fontSize = size + 'px'; }
    }

    function firstTab() {
        var c = st.s.categories || [];
        if (c.length) return c[0].key;
        return st.s.buys ? SELL : null;
    }
    function tabKeys() {
        var keys = (st.s.categories || []).map(function (c) { return c.key; });
        if (st.s.buys) keys.push(SELL);
        return keys;
    }
    function setTab(key) {
        if (key === st.tab) return;
        st.tab = key; st.sel = 0;
        $('dAmount').value = 1;
        render();
    }
    function select(i) {
        var n = rows().length;
        if (!n) return;
        st.sel = Math.max(0, Math.min(n - 1, i));
        $('dAmount').value = 1;
        renderList();
        renderDetail();
    }
    function step(d) {
        var it = current();
        if (!it) return;
        $('dAmount').value = Math.max(1, Math.min(limitFor(it), amount() + d));
        renderDetail();
    }

    // ---------- buy / sell ----------
    function go() {
        var it = current();
        if (!it || st.busy || $('dGo').disabled) return;
        st.busy = true;
        renderDetail();
        var req = selling() ? post('sell', { slot: it.slot, amount: amount() }) : post('buy', { i: it.i, amount: amount() });
        req.then(function (r) {
            st.busy = false;
            if (r && r.state) setState(r.state, true);
            else renderDetail();
        });
    }

    function setState(s, keep) {
        var oldKey = selling() ? null : (current() || {}).name;
        st.s = s;
        if (!keep || (st.tab !== SELL && !(s.categories || []).some(function (c) { return c.key === st.tab; })) || (st.tab === SELL && !s.buys)) {
            st.tab = firstTab(); st.sel = 0;
        }
        if (keep && oldKey) {
            var idx = rows().map(function (r) { return r.name; }).indexOf(oldKey);
            if (idx >= 0) st.sel = idx;
        }
        render();
    }

    // ---------- input ----------
    $('tabs').addEventListener('click', function (e) {
        var b = e.target.closest('[data-tab]');
        if (b) setTab(b.getAttribute('data-tab'));
    });
    $('list').addEventListener('click', function (e) {
        var r = e.target.closest('.ms-row');
        if (r) select(num(r.getAttribute('data-i')));
    });
    $('list').addEventListener('dblclick', function (e) {
        if (e.target.closest('.ms-row')) go();
    });
    $('dMinus').onclick = function () { step(-1); };
    $('dPlus').onclick = function () { step(1); };
    $('dAmount').addEventListener('input', renderDetail);
    $('dGo').onclick = go;

    document.addEventListener('keydown', function (e) {
        if (!st.open) return;
        if (e.key === 'Escape' || e.key === 'Backspace' && e.target.tagName !== 'INPUT') { close(true); return; }
        if (e.key === 'Enter') { go(); e.preventDefault(); return; }
        if (e.target.tagName === 'INPUT' && e.key !== 'ArrowUp' && e.key !== 'ArrowDown' && e.key !== 'Tab') return;
        if (e.key === 'ArrowUp') { select(st.sel - 1); e.preventDefault(); }
        else if (e.key === 'ArrowDown') { select(st.sel + 1); e.preventDefault(); }
        else if (e.key === 'ArrowLeft') { step(-1); e.preventDefault(); }
        else if (e.key === 'ArrowRight') { step(1); e.preventDefault(); }
        else if (e.key === 'Tab') {
            var keys = tabKeys(), i = keys.indexOf(st.tab);
            if (keys.length) setTab(keys[(i + (e.shiftKey ? keys.length - 1 : 1)) % keys.length]);
            e.preventDefault();
        }
    });

    // ---------- messages from Lua ----------
    function setup(d) {
        st.locale = d.locale || st.locale;
        st.lang = d.lang || st.lang;
        st.images = (d.images || []).map(function (p) { p = String(p); return /\/$/.test(p) ? p : p + '/'; });
        st.sign = d.sign !== undefined ? d.sign : st.sign;
        st.max = num(d.max) || 100;
        resolved = {};
        applyStatic();
    }
    function open(d) {
        st.open = true; st.busy = false; st.sel = 0; st.tab = null;
        $('dAmount').value = 1;
        $('store').classList.remove('mc-hidden');
        setState(d.state, false);
    }
    function close(tell) {
        if (!st.open) return;
        st.open = false;
        $('store').classList.add('mc-hidden');
        if (tell) post('close');
    }
    function stock(d) {
        if (!st.s) return;
        (st.s.items || []).forEach(function (it) { if (it.i === d.i) it.stock = d.stock; });
        renderList(); renderDetail();
    }

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.action === 'setup') setup(d);
        else if (d.action === 'open') open(d);
        else if (d.action === 'state') { if (st.open) setState(d.state, true); }
        else if (d.action === 'stock') stock(d);
        else if (d.action === 'close') close(false);
    });

    window.MULTIstores = { setTab: setTab, select: select, step: step }; // for the preview mock
})();
