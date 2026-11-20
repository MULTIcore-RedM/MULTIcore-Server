/* MULTIinventory satchel page (GPL v3, part of MULTIcore by RINGO (RINGOscripting)).
   Lua owns the data: this page draws what the server sent and asks Lua to
   move, use, give, drop and split. It never changes an inventory itself;
   the next server push redraws it. */
(function () {
    'use strict';

    var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIinventory';
    var $ = function (id) { return document.getElementById(id); };

    var st = {
        locale: {}, lang: 'en', images: [], hotbarSize: 5, giveEnabled: true, dropEnabled: true,
        open: false, p: null, o: null, sel: null, busy: false,
        tradeButton: true, t: null, tSig: '', tChangedAt: 0
    };
    var tTimer = null;
    var resolved = {};   // image -> index into st.images that worked, or -1 (none worked)

    // ---------- language: every word comes from the table Lua sends ----------
    function L(key) {
        var s = st.locale[key];
        if (s === undefined) return key;
        var args = Array.prototype.slice.call(arguments, 1);
        return String(s).replace(/%[sd]/g, function (m) { return args.length ? args.shift() : m; });
    }
    function has(key) { return st.locale[key] !== undefined; }
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
    function kg(g) { return (num(g) / 1000).toFixed(1); }
    function pretty(k) { return String(k).replace(/^AMMO_/, '').replace(/_/g, ' ').toLowerCase().replace(/\b\w/g, function (c) { return c.toUpperCase(); }); }

    // ---------- inventories ----------
    function bySlot(inv) {
        var m = {};
        if (inv && inv.items) inv.items.forEach(function (it) { m[it.slot] = it; });
        return m;
    }
    function weightOf(inv) {
        var w = 0;
        if (inv && inv.items) inv.items.forEach(function (it) { w += num(it.weight) * num(it.amount); });
        return w;
    }
    // trade mode: 't' = my offer, 'u' = the other player's offer (slots are offer lines 1..n)
    function tradeInv(p) {
        if (!st.t) return null;
        var s = p === 't' ? st.t.mine : st.t.theirs;
        return { id: 'trade:' + p, items: (s && s.items) || [], slots: num(st.t.maxItems), kind: 'trade' };
    }
    function paneInv(p) {
        if (p === 't' || p === 'u') return tradeInv(p);
        return p === 'p' ? st.p : st.o;
    }
    // satchel slots offered in the trade (locked on the server until it ends)
    function lockedSlots() {
        var m = {};
        if (st.t && st.t.mine) st.t.mine.items.forEach(function (it) { m[it.from] = it; });
        return m;
    }
    function money(n) {
        n = num(n);
        var parts = Math.abs(n).toFixed(2).split('.');
        return (n < 0 ? '-' : '') + '$' + parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',') + '<span class="mc-cents">' + parts[1] + '</span>';
    }
    function itemAt(p, slot) { return bySlot(paneInv(p))[slot]; }
    function maxSlot(inv) {
        var n = num(inv && inv.slots), m = 0;
        if (inv && inv.items) inv.items.forEach(function (it) { if (it.slot > m) m = it.slot; });
        return Math.max(n, m);
    }
    function firstFree(inv) {
        var m = bySlot(inv), n = maxSlot(inv);
        for (var i = 1; i <= n; i++) if (!m[i]) return i;
        return null;
    }

    // ---------- pictures: Config.ImagePaths in order, then a drawn fallback ----------
    function imgHtml(image) {
        if (!image || !st.images.length || resolved[image] === -1) return '<i class="mi-fallback"></i>';
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
                var f = document.createElement('i'); f.className = 'mi-fallback';
                if (img.parentNode) img.parentNode.replaceChild(f, img);
            };
        });
    }

    // ---------- tiles ----------
    function tileHtml(p, slot, it) {
        var cls = 'mi-tile', inner = '';
        if ((p === 'p' || p === 'h') && slot <= st.hotbarSize) inner += '<span class="mi-key">' + slot + '</span>';
        if (it) {
            cls += ' filled';
            if (st.sel && st.sel.pane === p && st.sel.slot === slot) cls += ' selected';
            if (p === 'p' && st.t && lockedSlots()[slot]) cls += ' locked';
            inner += '<div class="mi-img">' + imgHtml(it.image) + '</div>';
            var q = it.info && it.info.quality !== undefined ? num(it.info.quality) : null;
            if (q !== null && it.type === 'weapon') {
                cls += ' has-cond';
                inner += '<span class="mi-cond"><i style="width:' + Math.max(0, Math.min(100, q)) + '%"></i></span>';
            }
            if (num(it.amount) > 1 || !it.unique) inner += '<span class="mi-count">' + num(it.amount) + '</span>';
            if (it.equipped) inner += '<span class="mi-equip"></span>';
        }
        return '<div class="' + cls + '" data-pane="' + p + '" data-slot="' + slot + '">' + inner + '</div>';
    }

    function renderStats(p, inv) {
        var w = weightOf(inv), max = num(inv.maxWeight);
        var pct = max > 0 ? Math.min(100, w / max * 100) : 0;
        $(p + 'Bar').style.width = pct + '%';
        $(p + 'Bar').parentNode.classList.toggle('full', max > 0 && w >= max);
        $(p + 'Weight').textContent = max > 0 ? kg(w) + ' / ' + kg(max) + ' ' + L('ui_kg') : kg(w) + ' ' + L('ui_kg');
        var used = inv.items ? inv.items.length : 0;
        $(p + 'Slots').textContent = L('ui_slots') + ' ' + used + ' / ' + num(inv.slots);
    }

    function renderGrid(p) {
        var inv = paneInv(p), grid = $(p + 'Grid');
        var m = bySlot(inv), n = maxSlot(inv), html = '';
        for (var i = 1; i <= n; i++) html += tileHtml(p, i, m[i]);
        grid.innerHTML = html;
        wireImages(grid);
    }

    // long titles shrink to fit their pane (one line, like the game)
    function fitTitle(el) {
        el.style.fontSize = '';
        var size = parseFloat(getComputedStyle(el).fontSize), min = size * 0.55;
        while (el.scrollWidth > el.clientWidth + 1 && size > min) { size -= 1; el.style.fontSize = size + 'px'; }
    }

    function renderPanes() {
        if (st.p) {
            $('pTitle').textContent = st.p.label && st.p.kind !== 'player' ? st.p.label : L('ui_satchel');
            renderStats('p', st.p);
            renderGrid('p');
        }
        $('tradeBtn').classList.toggle('mc-hidden', !st.tradeButton || !!st.t);
        $('kDbl').textContent = L(st.t ? 'ui_trade_offer' : 'ui_use');
        $('paneT').classList.toggle('mc-hidden', !st.t);
        if (st.t) {
            $('paneO').classList.add('mc-hidden');
            renderTrade();
            fitTitle($('pTitle')); fitTitle($('tTitle'));
            return;
        }
        var o = st.o, ground = !o && st.dropEnabled;
        $('paneO').classList.toggle('mc-hidden', !o && !ground);
        $('oGrid').classList.toggle('mc-hidden', !o);
        $('oGround').classList.toggle('mc-hidden', !ground);
        $('oStats').classList.toggle('mc-hidden', !o);
        if (o) {
            $('oTitle').textContent = o.label || L('ui_kind_' + o.kind);
            renderStats('o', o);
            renderGrid('o');
        } else {
            $('oTitle').textContent = L('ui_ground');
        }
        fitTitle($('pTitle')); fitTitle($('oTitle'));
    }

    // ---------- trade window ----------
    function acceptWait() {
        if (!st.t) return 0;
        return Math.max(0, st.tChangedAt + num(st.t.acceptDelay) - Date.now());
    }

    function renderTrade() {
        var t = st.t, mine = t.mine, theirs = t.theirs;
        $('tTitle').textContent = L('ui_trade_with', t.partner || '');
        renderGrid('t');
        renderGrid('u');
        $('uName').textContent = t.partner || '';
        $('tOk').classList.toggle('mc-hidden', !mine.accepted);
        $('uOk').classList.toggle('mc-hidden', !theirs.accepted);
        $('uCash').innerHTML = money(theirs.cash);
        if (document.activeElement !== $('tCash')) $('tCash').value = num(mine.cash) > 0 ? num(mine.cash).toFixed(2) : '';
        $('tHave').innerHTML = esc(L('ui_trade_have')) + ' <span class="mc-money">' + money(t.myCash) + '</span>';
        var wait = acceptWait();
        var btn = $('tAccept');
        btn.textContent = L(mine.accepted ? 'ui_trade_unaccept' : 'ui_trade_accept');
        btn.disabled = !mine.accepted && wait > 0;
        var hint = 'ui_trade_hint';
        if (mine.accepted && !theirs.accepted) hint = 'ui_trade_wait_them';
        else if (theirs.accepted && !mine.accepted) hint = 'ui_trade_they_accepted';
        $('tHint').textContent = L(hint);
        clearTimeout(tTimer);
        if (wait > 0) tTimer = setTimeout(function () { if (st.open && st.t) renderTrade(); }, wait + 30);
    }

    // content of both offers; when it changes the accept delay starts again (the server enforces it too)
    function tradeSig(t) {
        if (!t) return '';
        function side(s) { return s.items.map(function (it) { return it.from + ':' + it.name + ':' + it.amount; }).join(',') + '|' + num(s.cash).toFixed(2); }
        return side(t.mine) + '#' + side(t.theirs);
    }

    // ---------- detail ----------
    var HIDDEN_META = { id: 1, image: 1, label: 1, description: 1, components: 1, componentshash: 1, slot: 1, serial: 1, serie: 1, ammo: 1, quality: 1, ammoType: 1 };
    function metaRows(it) {
        var info = it.info || {}, rows = [];
        if (info.serie || info.serial) rows.push([L('meta_serie'), info.serie || info.serial]);
        if (info.ammo !== undefined && it.type === 'weapon') rows.push([L('meta_ammo'), num(info.ammo)]);
        if (info.ammoType) rows.push([L('meta_ammotype'), pretty(info.ammoType)]);
        if (info.quality !== undefined) rows.push([L('meta_quality'), Math.round(num(info.quality)) + '%']);
        Object.keys(info).forEach(function (k) {
            var v = info[k];
            if (HIDDEN_META[k] || v === null || typeof v === 'object' || v === '') return;
            rows.push([has('meta_' + k) ? L('meta_' + k) : pretty(k), typeof v === 'boolean' ? L(v ? 'ui_yes' : 'ui_no') : v]);
        });
        var stack = num(it.amount) > 1 ? '  (' + kg(num(it.weight) * num(it.amount)) + ' ' + L('ui_kg') + ')' : '';
        rows.push([L('meta_weight'), kg(it.weight) + ' ' + L('ui_kg') + stack]);
        return rows;
    }

    function button(label, act, cls, disabled) {
        return '<button class="mc-btn ' + (cls || '') + '" data-act="' + act + '"' + (disabled ? ' disabled' : '') + '>' + esc(label) + '</button>';
    }

    function amountWanted(it, fallback) {
        var v = parseInt($('dAmount').value, 10);
        if (!isFinite(v) || v <= 0) return fallback;
        return Math.min(v, Math.max(1, num(it.amount) || v));
    }

    function renderDetail() {
        var sel = st.sel, it = sel && itemAt(sel.pane, sel.slot);
        var buttons = '';
        $('dTag').classList.add('mc-hidden');
        $('dLock').classList.add('mc-hidden');
        if (!it) {
            st.sel = null;
            $('dName').innerHTML = '<span class="mi-empty">' + esc(L('ui_select_hint')) + '</span>';
            $('dDesc').textContent = '';
            $('dMeta').innerHTML = '';
            $('dAmountBox').classList.add('mc-hidden');
            $('dButtons').innerHTML = '';
            return;
        }
        $('dName').textContent = it.label;
        $('dDesc').textContent = it.description || '';
        $('dTag').classList.toggle('mc-hidden', !it.equipped);
        $('dMeta').innerHTML = metaRows(it).map(function (r) {
            return '<div><span>' + esc(r[0]) + '</span>' + esc(r[1]) + '</div>';
        }).join('');
        $('dAmountBox').classList.toggle('mc-hidden', it.unique || num(it.amount) <= 1 || sel.pane === 'u' || sel.pane === 't' || (sel.pane === 'p' && !!st.t && !!lockedSlots()[sel.slot]));
        $('dAmount').placeholder = String(num(it.amount));

        if (st.t) {
            // trade mode: offer from the satchel, take back from my offer
            var locked = sel.pane === 'p' && lockedSlots()[sel.slot];
            $('dLock').classList.toggle('mc-hidden', !locked);
            if (sel.pane === 'p' && !locked) buttons += button(L('ui_trade_offer'), 'offer', 'primary');
            if (sel.pane === 't' || locked) buttons += button(L('ui_trade_back'), 'untrade');
        } else if (sel.pane === 'p') {
            var weapon = it.type === 'weapon' || it.type === 'weapon_thrown';
            if (weapon) buttons += button(L(it.equipped ? 'ui_unequip' : 'ui_equip'), it.equipped ? 'unequip' : 'use', 'primary');
            else if (it.type === 'ammo') buttons += button(L('ui_load'), 'ammo', 'primary');
            else if (it.usable) buttons += button(L('ui_use'), 'use', 'primary');
            if (!it.unique && num(it.amount) > 1) buttons += button(L('ui_split'), 'split');
            if (st.o) buttons += button(L('ui_store'), 'store');
            if (st.giveEnabled) buttons += button(L('ui_give'), 'give');
            if (st.dropEnabled) buttons += button(L('ui_drop'), 'drop', 'danger');
        } else {
            buttons += button(L('ui_take'), 'take', 'primary');
            if (!it.unique && num(it.amount) > 1) buttons += button(L('ui_split'), 'split');
        }
        $('dButtons').innerHTML = buttons;
    }

    function renderAll() { renderPanes(); renderDetail(); }

    // ---------- requests (the server answers with a fresh push) ----------
    function request(name, data) {
        if (st.busy) return;
        st.busy = true;
        post(name, data).then(function () { st.busy = false; renderDetail(); });
    }
    function move(fromPane, fromSlot, toPane, toSlot, amount) {
        var from = paneInv(fromPane);
        if (!from) return;
        var toId = toPane === 'ground' ? 'ground' : (paneInv(toPane) || {}).id;
        if (!toId) return;
        request('move', { fromInv: from.id, fromSlot: fromSlot, toInv: toId, toSlot: toSlot || null, amount: amount || 0 });
    }

    function act(kind) {
        var sel = st.sel, it = sel && itemAt(sel.pane, sel.slot);
        if (!it) return;
        var n = amountWanted(it, num(it.amount));
        if (kind === 'offer') request('tradeItem', { slot: sel.slot, amount: n });
        else if (kind === 'untrade') request('tradeItem', { slot: sel.pane === 't' ? it.from : sel.slot, amount: 0 });
        else if (kind === 'use') request('use', { slot: sel.slot });
        else if (kind === 'unequip') request('unequip', { slot: sel.slot });
        else if (kind === 'ammo') request('ammo', { slot: sel.slot });
        else if (kind === 'give') request('give', { slot: sel.slot, amount: n });
        else if (kind === 'drop') request('drop', { slot: sel.slot, amount: n });
        else if (kind === 'store') move('p', sel.slot, 'o', null, n);
        else if (kind === 'take') move('o', sel.slot, 'p', null, n);
        else if (kind === 'split') {
            var inv = paneInv(sel.pane), free = firstFree(inv);
            var half = amountWanted(it, Math.floor(num(it.amount) / 2));
            if (half >= num(it.amount)) half = Math.floor(num(it.amount) / 2);
            if (free && half > 0) move(sel.pane, sel.slot, sel.pane, free, half);
        }
        $('dAmount').value = '';
    }

    function select(pane, slot) {
        var changed = !st.sel || st.sel.pane !== pane || st.sel.slot !== slot;
        st.sel = { pane: pane, slot: slot };
        if (changed) $('dAmount').value = '';
        document.querySelectorAll('.mi-grid .mi-tile.selected').forEach(function (t) { t.classList.remove('selected'); });
        var t = document.querySelector('.mi-grid .mi-tile[data-pane="' + pane + '"][data-slot="' + slot + '"]');
        if (t) t.classList.add('selected');
        renderDetail();
    }

    // shift-click: the whole stack to the other side
    function quickMove(pane, slot) {
        var it = itemAt(pane, slot);
        if (!it) return;
        if (st.t) {
            if (pane === 'p' && !lockedSlots()[slot]) request('tradeItem', { slot: slot, amount: num(it.amount) });
            else if (pane === 't') request('tradeItem', { slot: it.from, amount: 0 });
            return;
        }
        if (!st.o) return;
        move(pane, slot, pane === 'p' ? 'o' : 'p', null, num(it.amount));
    }

    // ---------- drag and drop ----------
    var drag = null;
    function tileFrom(el) { return el && el.closest ? el.closest('.mi-grid .mi-tile') : null; }

    document.addEventListener('mousedown', function (e) {
        if (!st.open || e.button !== 0) return;
        var t = tileFrom(e.target);
        if (!t || !t.classList.contains('filled')) return;
        drag = { pane: t.getAttribute('data-pane'), slot: num(t.getAttribute('data-slot')), x: e.clientX, y: e.clientY, started: false, el: t, shift: e.shiftKey };
        e.preventDefault();
    });

    var overEl = null;
    function setOver(el) {
        if (overEl === el) return;
        if (overEl) overEl.classList.remove('drop-over');
        overEl = el;
        if (overEl) overEl.classList.add('drop-over');
    }

    function dropTarget(x, y) {
        var el = document.elementFromPoint(x, y);
        if (!el) return null;
        var t = tileFrom(el);
        if (t) return { pane: t.getAttribute('data-pane'), slot: num(t.getAttribute('data-slot')), el: t };
        if (el.closest('#oGround')) return { pane: 'ground', slot: null, el: $('oGround') };
        var pane = el.closest('.mi-pane');
        if (pane) return { pane: pane.getAttribute('data-pane'), slot: null, el: null };
        return null;
    }

    document.addEventListener('mousemove', function (e) {
        if (!drag) return;
        if (!drag.started) {
            if (Math.abs(e.clientX - drag.x) + Math.abs(e.clientY - drag.y) < 6) return;
            drag.started = true;
            var it = itemAt(drag.pane, drag.slot);
            $('ghost').innerHTML = '<div class="mi-img">' + imgHtml(it && it.image) + '</div>'
                + (it && num(it.amount) > 1 ? '<span class="mi-count">' + amountWanted(it, num(it.amount)) + '</span>' : '');
            wireImages($('ghost'));
            $('ghost').classList.remove('mc-hidden');
            drag.el.classList.add('dragging');
        }
        $('ghost').style.transform = 'translate(' + (e.clientX - 37) + 'px,' + (e.clientY - 37) + 'px)';
        var tg = dropTarget(e.clientX, e.clientY);
        setOver(tg && tg.el && tg.el !== drag.el ? tg.el : null);
    });

    document.addEventListener('mouseup', function (e) {
        if (!drag) return;
        var d = drag; drag = null;
        setOver(null);
        $('ghost').classList.add('mc-hidden');
        d.el.classList.remove('dragging');
        if (!d.started) {
            if (e.shiftKey) quickMove(d.pane, d.slot);
            else select(d.pane, d.slot);
            return;
        }
        var tg = dropTarget(e.clientX, e.clientY);
        if (!tg) return;
        if (tg.pane === d.pane && tg.slot === d.slot) return;
        var it = itemAt(d.pane, d.slot);
        if (!it) return;
        var n = st.sel && st.sel.pane === d.pane && st.sel.slot === d.slot ? amountWanted(it, num(it.amount)) : num(it.amount);
        if (st.t) {
            // trade mode: satchel -> my offer offers, my offer -> satchel takes back, satchel -> satchel moves
            if (d.pane === 'p' && tg.pane === 't') return request('tradeItem', { slot: d.slot, amount: n });
            if (d.pane === 't' && tg.pane === 'p') return request('tradeItem', { slot: it.from, amount: 0 });
            if (d.pane === 'p' && tg.pane === 'p') return move('p', d.slot, 'p', tg.slot, n);
            return;
        }
        if (tg.pane === 'ground') return move(d.pane, d.slot, 'ground', null, n);
        move(d.pane, d.slot, tg.pane, tg.slot, n);
    });

    document.addEventListener('dblclick', function (e) {
        var t = tileFrom(e.target);
        if (!t || !t.classList.contains('filled')) return;
        var pane = t.getAttribute('data-pane'), slot = num(t.getAttribute('data-slot'));
        if (st.t) { quickMove(pane, slot); return; }
        if (pane === 'p') {
            var it = itemAt('p', slot);
            if (!it) return;
            if (it.type === 'ammo') request('ammo', { slot: slot });
            else if (it.equipped) request('unequip', { slot: slot });
            else request('use', { slot: slot });
        } else quickMove(pane, slot);
    });

    $('dButtons').addEventListener('click', function (e) {
        var b = e.target.closest('[data-act]');
        if (b && !b.disabled) act(b.getAttribute('data-act'));
    });
    $('dAll').onclick = function () {
        var it = st.sel && itemAt(st.sel.pane, st.sel.slot);
        if (!it) return;
        $('dAmount').value = num(it.amount);
        renderDetail();
    };

    document.addEventListener('keydown', function (e) {
        if (!st.open) return;
        if (e.key === 'Escape') { close(true); return; }
        if (e.target.tagName === 'INPUT') {
            if (e.key === 'Enter' && e.target.id === 'tCash') setCash();
            return;
        }
        if (e.key === 'Enter' && st.sel && st.sel.pane === 'p') act(st.t ? 'offer' : 'use');
    });

    // trade buttons
    function setCash() {
        var v = $('tCash').value.trim().replace(',', '.');
        if (v === '') v = '0';
        if (!/^\d{1,7}(\.\d{1,2})?$/.test(v)) { $('tCash').value = ''; return; }
        request('tradeCash', { amount: v });
        $('tCash').blur();
    }
    $('tCashSet').onclick = setCash;
    $('tAccept').onclick = function () {
        if (!st.t || $('tAccept').disabled) return;
        request('tradeAccept', { state: !st.t.mine.accepted });
    };
    $('tCancel').onclick = function () { close(true); };
    $('tradeBtn').onclick = function () { post('tradeStart'); };

    // ---------- open / update / close ----------
    function setup(d) {
        st.locale = d.locale || st.locale;
        st.lang = d.lang || st.lang;
        st.images = (d.images || []).map(function (p) { p = String(p); return /\/$/.test(p) ? p : p + '/'; });
        st.hotbarSize = num(d.hotbarSize) || 5;
        st.giveEnabled = d.giveEnabled !== false;
        st.dropEnabled = d.dropEnabled !== false;
        st.tradeButton = d.tradeButton !== false;
        resolved = {};
        applyStatic();
    }

    function load(d) {
        st.p = d.player || st.p;
        st.o = d.other || null;
        st.t = d.trade || null;
        var sig = tradeSig(st.t);
        if (st.t && sig !== st.tSig) st.tChangedAt = Date.now();
        st.tSig = sig;
        if (st.sel && !itemAt(st.sel.pane, st.sel.slot)) st.sel = null;
        if (st.sel && st.sel.pane === 'o' && !st.o) st.sel = null;
        if (st.sel && (st.sel.pane === 't' || st.sel.pane === 'u') && !st.t) st.sel = null;
    }

    function open(d) {
        load(d);
        st.sel = null; st.busy = false;
        $('dAmount').value = '';
        st.open = true;
        $('inv').classList.remove('mc-hidden');
        renderAll();
    }

    function update(d) {
        load(d);
        if (st.open) renderAll();
    }

    function close(tell) {
        if (!st.open) return;
        st.open = false;
        drag = null;
        $('ghost').classList.add('mc-hidden');
        $('inv').classList.add('mc-hidden');
        if (tell) post('close');
    }

    // ---------- item pop-ups ----------
    function itembox(d) {
        var box = document.createElement('div');
        var sign = d.kind === 'remove' ? '−' : d.kind === 'add' ? '+' : '';
        box.className = 'mi-box';
        box.innerHTML = '<div class="mi-box-kind">' + esc(L('ui_box_' + d.kind)) + '</div>'
            + '<div class="mi-box-img">' + imgHtml(d.item && d.item.image) + '</div>'
            + '<div class="mi-box-label">' + esc(d.item && d.item.label) + '</div>'
            + (d.kind === 'use' ? '' : '<div class="mi-box-amt">' + sign + num(d.amount || 1) + '</div>');
        var host = $('itembox');
        host.appendChild(box);
        wireImages(box);
        while (host.children.length > (num(d.max) || 5)) host.removeChild(host.firstChild);
        var t = num(d.time) || 3500;
        setTimeout(function () { box.classList.add('out'); }, t);
        setTimeout(function () { if (box.parentNode) box.parentNode.removeChild(box); }, t + 400);
    }

    // ---------- hotbar ----------
    var hotTimer = null;
    function hotbar(d) {
        var bar = $('hotbar');
        clearTimeout(hotTimer);
        if (!d.show) { bar.classList.add('mc-hidden'); return; }
        var m = {};
        (d.items || []).forEach(function (it) { m[it.slot] = it; });
        var html = '';
        for (var i = 1; i <= st.hotbarSize; i++) {
            html += tileHtml('h', i, m[i]).replace('class="mi-tile', 'class="mi-tile' + (d.active === i ? ' active' : ''));
        }
        bar.innerHTML = html;
        wireImages(bar);
        bar.classList.remove('mc-hidden', 'fading');
        if (!d.pinned) {
            hotTimer = setTimeout(function () {
                bar.classList.add('fading');
                hotTimer = setTimeout(function () { bar.classList.add('mc-hidden'); }, 300);
            }, num(d.time) || 2500);
        }
    }

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.action === 'setup') setup(d);
        else if (d.action === 'open') open(d);
        else if (d.action === 'update') update(d);
        else if (d.action === 'close') close(false);
        else if (d.action === 'itembox') itembox(d);
        else if (d.action === 'hotbar') hotbar(d);
    });

    window.MULTIinventory = { select: select }; // for the preview mock
})();
