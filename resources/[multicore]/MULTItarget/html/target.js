// MULTItarget page (works like rsg-target). Messages from client/main.lua:
//   { action: 'on', scale, text }  { action: 'off' }
//   { action: 'list', items: [ { label, icon, description, iconColor, sub, back } ], title, sub, found }
//   { action: 'cursor', on }
// With the cursor out, click an option; right mouse or Esc cancels.
(function () {
    'use strict';
    var root = document.getElementById('target');
    var card = document.getElementById('card');
    var list = document.getElementById('list');
    var title = document.getElementById('title');
    var sub = document.getElementById('sub');
    var cursor = false;

    function post(name, body) {
        if (typeof GetParentResourceName !== 'function') return;
        fetch('https://' + GetParentResourceName() + '/' + name, { method: 'POST', body: JSON.stringify(body || {}) }).catch(function () {});
    }

    function iconClass(i) {
        i = String(i || '').trim();
        if (!/^[a-z0-9 -]+$/i.test(i)) return 'fa-solid fa-circle-dot';
        if (!/\bfa-(solid|regular|brands)\b|\bfa[srb]\b/.test(i)) i = 'fa-solid ' + (i.indexOf('fa-') === 0 ? i : 'fa-' + i);
        return i;
    }

    function render(m) {
        list.innerHTML = '';
        title.textContent = m.title || '';
        sub.textContent = m.sub || '';
        (m.items || []).forEach(function (it, i) {
            var row = document.createElement('div');
            row.className = 'mt-row';
            var ic = document.createElement('i');
            ic.className = iconClass(it.icon);
            if (it.iconColor && /^#[0-9a-f]{3,8}$|^[a-z]+$/i.test(it.iconColor)) ic.style.color = it.iconColor;
            var l = document.createElement('span');
            l.className = 'mt-l';
            l.textContent = it.label || '';
            if (it.description) {
                var d = document.createElement('span');
                d.className = 'mt-d';
                d.textContent = it.description;
                l.appendChild(d);
            }
            row.appendChild(ic);
            row.appendChild(l);
            if (it.sub) {
                var mo = document.createElement('i');
                mo.className = 'fa-solid fa-chevron-right mt-more';
                row.appendChild(mo);
            }
            row.addEventListener('click', function () { if (cursor) post('pick', { index: i + 1 }); });
            list.appendChild(row);
        });
        var found = !!m.found;
        root.classList.toggle('mt-found', found);
        card.classList.toggle('mc-hidden', !found);
    }

    function cancel() { post('release'); }

    window.addEventListener('contextmenu', function (e) { e.preventDefault(); if (cursor) cancel(); });
    window.addEventListener('mousedown', function (e) { if (cursor && e.button === 2) { e.preventDefault(); cancel(); } });
    window.addEventListener('keydown', function (e) {
        if (cursor && (e.key === 'Escape' || e.key === 'Backspace')) { e.preventDefault(); cancel(); }
    });

    window.addEventListener('message', function (e) {
        var m = e.data || {};
        if (m.action === 'on') {
            root.style.setProperty('--mt-scale', Number(m.scale) || 1);
            cursor = false;
            root.classList.remove('mt-cursor', 'mt-found');
            card.classList.add('mc-hidden');
            root.classList.remove('mc-hidden');
        } else if (m.action === 'off') {
            root.classList.add('mc-hidden');
            root.classList.remove('mt-cursor');
            cursor = false;
            list.innerHTML = '';
        } else if (m.action === 'list') {
            render(m);
        } else if (m.action === 'cursor') {
            cursor = !!m.on;
            root.classList.toggle('mt-cursor', cursor);
        }
    });
})();
