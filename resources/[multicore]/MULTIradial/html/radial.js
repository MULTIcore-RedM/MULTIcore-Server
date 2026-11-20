// MULTIradial page. Messages from client/main.lua:
//   { action: 'open', items: [ { id, text, icon, items? } ], scale, locale }
//   { action: 'close' }
// The page only names a button by id; the client decides what it does.
(function () {
    'use strict';

    var root = document.getElementById('radial');
    var left = document.getElementById('left');
    var right = document.getElementById('right');
    var title = document.getElementById('title');
    var cancel = document.getElementById('cancel');
    var cancelText = document.getElementById('cancelText');

    var locale = {};
    var stack = [];      // [{ items, text }] - the menus we came through

    function T(k, d) { return locale[k] || d; }

    function post(name, body) {
        if (typeof GetParentResourceName !== 'function') return;
        fetch('https://' + GetParentResourceName() + '/' + name, { method: 'POST', body: JSON.stringify(body || {}) }).catch(function () {});
    }

    function iconName(i) {
        i = String(i || 'circle').replace(/^fa[srb]?\s+|^fa-solid\s+|^fa-regular\s+/, '').replace(/^fa-/, '');
        return /^[a-z0-9-]+$/.test(i) ? i : 'circle';
    }

    function button(b) {
        var el = document.createElement('button');
        el.type = 'button';
        el.className = 'mr-btn' + (b.items ? ' mr-sub' : '');
        var inner = document.createElement('span');
        inner.className = 'mr-in';
        var ic = document.createElement('i');
        ic.className = 'fa-solid fa-' + iconName(b.icon);
        var tx = document.createElement('b');
        tx.textContent = b.text || '';
        inner.appendChild(ic);
        inner.appendChild(tx);
        el.appendChild(inner);
        el.addEventListener('click', function () { pick(b); });
        return el;
    }

    function show() {
        var cur = stack[stack.length - 1];
        left.innerHTML = '';
        right.innerHTML = '';
        var items = cur.items || [];
        var half = Math.ceil(items.length / 2);
        items.forEach(function (b, i) { (i < half ? left : right).appendChild(button(b)); });
        title.textContent = stack.length > 1 ? cur.text : '';
        cancelText.textContent = stack.length > 1 ? T('back', 'Back') : T('cancel', 'Cancel');
        cancel.querySelector('i').className = 'fa-solid ' + (stack.length > 1 ? 'fa-arrow-left' : 'fa-xmark');
    }

    function pick(b) {
        if (b.items) {
            stack.push({ items: b.items, text: b.text });
            show();
            return;
        }
        post('select', { id: b.id });
    }

    function back() {
        if (stack.length > 1) { stack.pop(); show(); return; }
        post('close');
    }

    cancel.addEventListener('click', back);
    window.addEventListener('contextmenu', function (e) { e.preventDefault(); if (!root.classList.contains('mc-hidden')) back(); });
    window.addEventListener('keydown', function (e) {
        if (root.classList.contains('mc-hidden')) return;
        if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); back(); }
    });

    window.addEventListener('message', function (e) {
        var m = e.data || {};
        if (m.action === 'open') {
            if (m.locale) locale = m.locale;
            root.style.setProperty('--mr-scale', Number(m.scale) || 1);
            stack = [{ items: m.items || [], text: '' }];
            show();
            root.classList.remove('mc-hidden');
        } else if (m.action === 'close') {
            root.classList.add('mc-hidden');
            stack = [];
        }
    });
})();
