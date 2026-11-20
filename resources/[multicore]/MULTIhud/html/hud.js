// MULTIhud NUI. Messages from client/main.lua:
//   { action: 'config', style, position, offsetX, offsetY, scale, numbers, low, order, show, size, gap, colors,
//     locale (_LT()), cyrillic, money }
//   { action: 'visible', show }
//   { action: 'update', data: { health, healthCore, stamina, staminaCore, hunger, thirst, stress, cleanliness,
//                               temp, tempUnit, tempBand, horse: {...}, voice: {...}, money: {...} } }
(function () {
    'use strict';

    var hud = document.getElementById('hud');
    var rowPlayer = document.getElementById('player');
    var rowHorse = document.getElementById('horse');
    var moneyEl = document.getElementById('money');

    var cfg = {
        style: 'ring', position: 'bottom-center', offsetX: 2, offsetY: 2.5, scale: 1, layout: null, minScale: 0.5, maxScale: 2, numbers: true, low: 20,
        order: ['health', 'stamina', 'hunger', 'thirst', 'stress', 'cleanliness', 'temperature'],
        show: { health: true, stamina: true, hunger: true, thirst: true, stress: true, cleanliness: true, temperature: true, horse: true, voice: true },
        size: 40, gap: 5, colors: {}, cyrillic: false,
        money: { gold: true, bank: true, bloodmoney: false }
    };
    var locale = {};     // _LT() from the client: every visible word comes from locales/<lang>.lua

    function T(key) { return locale['label_' + key] || ''; }
    var items = {};      // key -> { el, num, lvl, label }

    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    }

    function makeGauge(key, label) {
        var item = el('div', 'mh-item k-' + key);
        var g = el('div', 'mh-g');
        var fill = el('div', 'mh-fill');
        var lvl = el('div', 'mh-lvl');
        fill.appendChild(lvl);
        var num = el('div', 'mh-num', '');
        g.appendChild(fill);
        g.appendChild(num);
        var lab = el('div', 'mh-label', label);
        item.appendChild(g);
        item.appendChild(lab);
        items[key] = { el: item, num: num, label: lab };
        return item;
    }

    function build() {
        rowPlayer.innerHTML = '';
        rowHorse.innerHTML = '';
        items = {};
        cfg.order.forEach(function (k) {
            if (cfg.show[k]) rowPlayer.appendChild(makeGauge(k, T(k)));
        });
        if (cfg.show.voice) {
            var v = makeGauge('voice', T('voice'));
            v.classList.add('mc-hidden');
            rowPlayer.appendChild(v);
        }
        if (cfg.show.horse) {
            rowHorse.appendChild(el('div', 'mh-tag', T('horse')));
            rowHorse.appendChild(makeGauge('horseHealth', T('horseHealth')));
            rowHorse.appendChild(makeGauge('horseStamina', T('horseStamina')));
        }

        var s = hud.style;
        s.setProperty('--mh-size', cfg.size + 'px');
        s.setProperty('--mh-gap', cfg.gap + 'px');
        Object.keys(cfg.colors || {}).forEach(function (k) { s.setProperty('--mh-c-' + k, cfg.colors[k]); });
        place();
    }

    // where the HUD sits: the player's own layout (/hudedit) wins over the config position
    function place() {
        var lay = edit.on ? edit.layout : cfg.layout;
        var pos = lay ? 'custom' : cfg.position;
        var keep = ['mh-off', 'mh-editing', 'mh-dragging'].filter(function (c) { return hud.classList.contains(c); });
        hud.className = 'mc-root mh-hud pos-' + pos + ' style-' + (cfg.style === 'bar' ? 'bar' : 'ring') +
            (cfg.numbers ? '' : ' mh-hidenum') + (cfg.cyrillic ? ' mc-cyrillic' : '') +
            (keep.length ? ' ' + keep.join(' ') : '');
        var s = hud.style;
        s.left = s.right = s.top = s.bottom = '';
        if (lay) {
            s.left = lay.x + 'vw';
            s.top = lay.y + 'vh';
            s.transform = 'scale(' + lay.scale + ')';
            return;
        }
        var p = cfg.position.split('-');
        s[p[0]] = cfg.offsetY + 'vh';
        if (p[1] === 'center') {
            s.left = '50%';
            s.transform = 'translateX(-50%) scale(' + (cfg.scale || 1) + ')';
        } else {
            s[p[1]] = cfg.offsetX + 'vw';
            s.transform = 'scale(' + (cfg.scale || 1) + ')';
        }
    }

    // ---------- /hudedit ----------
    var edit = { on: false, layout: null, drag: null };
    var editBar = document.getElementById('edit');

    // the HUD's current top-left corner and size as a layout, whatever position it uses now
    function currentLayout() {
        var r = hud.getBoundingClientRect();
        var sc = (edit.on && edit.layout) ? edit.layout.scale : (cfg.layout ? cfg.layout.scale : (cfg.scale || 1));
        return { x: r.left / window.innerWidth * 100, y: r.top / window.innerHeight * 100, scale: sc };
    }

    function clampLayout(l) {
        var r = hud.getBoundingClientRect();
        var wPct = r.width / window.innerWidth * 100, hPct = r.height / window.innerHeight * 100;
        l.x = Math.max(0, Math.min(100 - wPct, l.x));
        l.y = Math.max(0, Math.min(100 - hPct, l.y));
        return l;
    }

    function startEdit() {
        edit.on = true;
        edit.layout = currentLayout();
        hud.classList.add('mh-editing');
        document.getElementById('editHint').textContent = locale.edit_hint || '';
        document.getElementById('editSave').textContent = locale.edit_save || 'Save';
        document.getElementById('editReset').textContent = locale.edit_reset || 'Reset';
        document.getElementById('editCancel').textContent = locale.edit_cancel || 'Cancel';
        editBar.classList.remove('mc-hidden');
        place();
    }

    function stopEdit() {
        edit.on = false;
        edit.drag = null;
        hud.classList.remove('mh-editing', 'mh-dragging');
        editBar.classList.add('mc-hidden');
        place();
    }

    function finish(what) {
        if (!edit.on) return;
        var body = { save: what === 'save', reset: what === 'reset', layout: edit.layout };
        stopEdit();
        if (typeof GetParentResourceName === 'function') {
            fetch('https://' + GetParentResourceName() + '/editDone', { method: 'POST', body: JSON.stringify(body) }).catch(function () {});
        }
    }

    hud.addEventListener('mousedown', function (e) {
        if (!edit.on || e.button !== 0) return;
        edit.drag = { mx: e.clientX, my: e.clientY, x: edit.layout.x, y: edit.layout.y };
        hud.classList.add('mh-dragging');
        e.preventDefault();
    });
    window.addEventListener('mousemove', function (e) {
        if (!edit.on || !edit.drag) return;
        edit.layout.x = edit.drag.x + (e.clientX - edit.drag.mx) / window.innerWidth * 100;
        edit.layout.y = edit.drag.y + (e.clientY - edit.drag.my) / window.innerHeight * 100;
        place();
        clampLayout(edit.layout);
        place();
    });
    window.addEventListener('mouseup', function () {
        if (!edit.drag) return;
        edit.drag = null;
        hud.classList.remove('mh-dragging');
    });
    window.addEventListener('wheel', function (e) {
        if (!edit.on) return;
        var step = e.deltaY < 0 ? 0.05 : -0.05;
        edit.layout.scale = Math.round(Math.max(cfg.minScale, Math.min(cfg.maxScale, edit.layout.scale + step)) * 100) / 100;
        place();
        clampLayout(edit.layout);
        place();
    }, { passive: true });
    window.addEventListener('keydown', function (e) {
        if (!edit.on) return;
        if (e.key === 'Enter') finish('save');
        else if (e.key === 'Escape') finish('cancel');
        else if (e.key === 'r' || e.key === 'R') finish('reset');
    });
    editBar.addEventListener('click', function (e) {
        var b = e.target.closest('button[data-act]');
        if (b) finish(b.getAttribute('data-act'));
    });

    function setGauge(key, value, core, opts) {
        var it = items[key];
        if (!it) return;
        opts = opts || {};
        var v = Math.max(0, Math.min(100, Number(value) || 0));
        it.el.style.setProperty('--p', opts.full ? 100 : v);
        it.el.style.setProperty('--core', core === undefined || core === null ? 0 : Math.max(0, Math.min(100, core)));
        it.num.textContent = opts.text !== undefined ? opts.text : String(Math.round(v));
        var low = opts.inverse ? v >= 100 - cfg.low : v <= cfg.low;
        it.el.classList.toggle('low', !opts.noLow && low);
    }

    function money(n) {
        n = Number(n) || 0;
        var s = n.toFixed(2).split('.');   // game style: 12 with small raised cents
        return s[0] + '<span class="mc-cents">' + s[1] + '</span>';
    }

    function renderMoney(m) {
        if (!m) { moneyEl.classList.add('mc-hidden'); return; }
        var html = '';
        function cell(cls, label, value) {
            html += '<div class="mh-m ' + cls + '"><small>' + label + '</small><b>' + value + '</b></div>';
        }
        cell('cash', T('cash'), '$' + money(m.cash));
        if (cfg.money.gold) cell('gold', T('gold'), money(m.gold));
        if (cfg.money.bank) cell('bank', T('bank'), '$' + money(m.bank));
        if (cfg.money.bloodmoney) cell('blood', T('bloodmoney'), '$' + money(m.bloodmoney));
        moneyEl.innerHTML = html;
        moneyEl.classList.remove('mc-hidden');
    }

    function update(d) {
        setGauge('health', d.health, d.healthCore);
        setGauge('stamina', d.stamina, d.staminaCore);
        setGauge('hunger', d.hunger);
        setGauge('thirst', d.thirst);
        setGauge('stress', d.stress, null, { inverse: true });
        setGauge('cleanliness', d.cleanliness);

        var t = items.temperature;
        if (t) {
            if (d.temp === undefined || d.temp === null) {
                t.el.classList.add('mc-hidden');
            } else {
                t.el.classList.remove('mc-hidden');
                t.el.classList.toggle('t-cold', d.tempBand === 'cold');
                t.el.classList.toggle('t-hot', d.tempBand === 'hot');
                setGauge('temperature', 100, null, { full: true, noLow: true, text: d.temp + '°' + (d.tempUnit || '') });
            }
        }

        if (d.horse && items.horseHealth) {
            rowHorse.classList.remove('mc-hidden');
            setGauge('horseHealth', d.horse.health, d.horse.healthCore);
            setGauge('horseStamina', d.horse.stamina, d.horse.staminaCore);
        } else {
            rowHorse.classList.add('mc-hidden');
        }

        var v = items.voice;
        if (v) {
            if (d.voice) {
                v.el.classList.remove('mc-hidden');
                v.el.classList.toggle('talking', !!d.voice.talking);
                v.el.classList.toggle('radio', !!d.voice.radio);
                v.label.textContent = d.voice.radio ? T('radio') : (d.voice.mode || T('voice'));
                setGauge('voice', 100, null, { full: true, noLow: true, text: d.voice.talking ? '●' : '○' });
            } else {
                v.el.classList.add('mc-hidden');
            }
        }

        renderMoney(d.money);
    }

    window.addEventListener('message', function (e) {
        var m = e.data || {};
        if (m.action === 'config') {
            ['style', 'position', 'offsetX', 'offsetY', 'scale', 'numbers', 'low', 'order', 'size', 'gap', 'colors', 'cyrillic', 'minScale', 'maxScale'].forEach(function (k) {
                if (m[k] !== undefined && m[k] !== null) cfg[k] = m[k];
            });
            if (m.show) cfg.show = m.show;
            if (m.locale) locale = m.locale;
            if (m.money) cfg.money = m.money;
            cfg.layout = m.layout ? m.layout : null;
            build();
        } else if (m.action === 'edit') {
            if (m.on) startEdit(); else if (edit.on) stopEdit();
        } else if (m.action === 'visible') {
            hud.classList.toggle('mh-off', !m.show);
        } else if (m.action === 'update' && m.data) {
            update(m.data);
        }
    });

    build();

    // tell the client the page is ready for its config
    if (typeof GetParentResourceName === 'function') {
        fetch('https://' + GetParentResourceName() + '/ready', { method: 'POST', body: '{}' }).catch(function () {});
    }
})();
