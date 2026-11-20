// MULTIcharacter NUI
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'MULTIcharacter';
    const post = (name, data) => fetch(`https://${res}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
    }).catch(() => {});

    let T = {};
    let chars = [];
    let slots = 5;
    let selected = 1;
    let places = [];
    let place = null;
    let busy = false;
    let throttle = 30; // ms between drag turns sent to the game; Lua sends Config.Scene.rotateThrottleMs

    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const fill = (s, v) => String(s || '').replace(/\{(\w+)\}/g, (m, k) => (v[k] != null ? v[k] : m));
    const num = (n) => {
        const v = Number(n) || 0;
        try { return v.toLocaleString(T.number_locale || undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }); } catch (e) { return v.toFixed(2); }
    };
    const money = (n) => fill(T.cash_format || '{amount}', { amount: num(n) });
    const gold = (n) => fill(T.gold_format || '{amount}', { amount: num(n) });

    function applyText() {
        document.querySelectorAll('[data-t]').forEach((el) => {
            const k = el.getAttribute('data-t');
            if (T[k]) el.textContent = T[k];
        });
    }

    function setBusy(b) {
        busy = b;
        $('btnPlay').disabled = b || !chars.length;
        $('btnSpawn').disabled = b || !place;
    }

    function renderList() {
        $('slots').textContent = fill(T.slots || '', { n: chars.length, max: slots });
        const box = $('cards');
        let html = '';
        chars.forEach((c) => {
            html += `<div class="card${c.index === selected ? ' active' : ''}" data-i="${c.index}">
                <div class="name">${esc(c.name)}</div>
                <div class="job">${esc(c.job || T.no_job || '')}</div>
                <div class="meta">
                    <span class="money"><span class="mc-money">${esc(money(c.cash))}</span><span class="mc-money mc-gold">${esc(gold(c.gold))}</span></span>
                    <span>${c.birthdate ? esc(fill(T.born || '{date}', { date: c.birthdate })) : ''}</span>
                </div>
            </div>`;
        });
        for (let i = chars.length; i < slots; i++) {
            html += `<div class="card empty${busy ? ' locked' : ''}" data-new="1">+ ${esc(T.empty || '')}</div>`;
        }
        box.innerHTML = html;
        $('btnNew').disabled = chars.length >= slots;
        $('btnDelete').disabled = !chars.length;
        $('btnPlay').disabled = busy || !chars.length;
    }

    function renderPlaces() {
        let html = '';
        places.forEach((p) => {
            html += `<div class="mc-row place${place === p.id ? ' active' : ''}" data-id="${esc(p.id)}">
                <span>${esc(p.label)}<span class="mc-sub">${esc(p.desc || '')}</span></span>
                ${p.id === '__last' ? '<span class="pin">&#9679;</span>' : ''}
            </div>`;
        });
        $('places').innerHTML = html;
        $('btnSpawn').disabled = busy || !place;
    }

    function show(view) {
        $('select').classList.toggle('mc-hidden', view !== 'select');
        $('playBar').classList.toggle('mc-hidden', view !== 'select');
        $('spawn').classList.toggle('mc-hidden', view !== 'spawn');
    }

    // ---------- events from Lua ----------
    window.addEventListener('message', (e) => {
        const d = e.data || {};
        switch (d.action) {
            case 'open':
                T = d.text || T;
                document.body.classList.toggle('mc-cyrillic', d.lang === 'ru');
                $('app').classList.toggle('mc-cyrillic', d.lang === 'ru');
                if (d.rotateThrottle) throttle = Number(d.rotateThrottle) || throttle;
                applyText();
                show('select');
                setBusy(false);
                $('app').classList.remove('mc-hidden');
                break;
            case 'close':
                $('app').classList.add('mc-hidden');
                $('delModal').classList.add('mc-hidden');
                break;
            case 'list':
                chars = d.characters || [];
                slots = d.slots || slots;
                selected = d.selected || 1;
                setBusy(false);
                renderList();
                break;
            case 'spawn':
                places = d.locations || [];
                place = places.length ? places[0].id : null;
                setBusy(false);
                show('spawn');
                renderPlaces();
                break;
            case 'unbusy':
                setBusy(false);
                break;
        }
    });

    // ---------- clicks ----------
    $('cards').addEventListener('click', (e) => {
        const card = e.target.closest('.card');
        if (!card || busy) return;
        if (card.dataset.new) { if (chars.length < slots) { setBusy(true); post('new'); } return; }
        const i = Number(card.dataset.i);
        if (i && i !== selected) { selected = i; renderList(); post('select', { index: i }); }
    });
    $('cards').addEventListener('dblclick', (e) => {
        const card = e.target.closest('.card');
        if (card && card.dataset.i && !busy) { setBusy(true); post('play', { index: Number(card.dataset.i) }); }
    });
    $('btnPlay').addEventListener('click', () => { if (!busy && chars.length) { setBusy(true); post('play', { index: selected }); } });
    $('btnNew').addEventListener('click', () => { if (!busy && chars.length < slots) { setBusy(true); post('new'); } });

    $('places').addEventListener('click', (e) => {
        const row = e.target.closest('.place');
        if (!row || busy) return;
        place = row.dataset.id;
        renderPlaces();
    });
    $('places').addEventListener('dblclick', (e) => {
        const row = e.target.closest('.place');
        if (row && !busy) { place = row.dataset.id; setBusy(true); post('spawn', { id: place }); }
    });
    $('btnSpawn').addEventListener('click', () => { if (!busy && place) { setBusy(true); post('spawn', { id: place }); } });

    // ---------- delete with typed name ----------
    const norm = (s) => String(s || '').trim().replace(/\s+/g, ' ').toLowerCase();
    function selectedChar() { return chars.find((c) => c.index === selected); }
    $('btnDelete').addEventListener('click', () => {
        const c = selectedChar();
        if (!c || busy) return;
        $('delHint').innerHTML = esc(fill(T.delete_hint || '{name}', { name: '\u0001' })).replace('\u0001', `<b>${esc(c.name)}</b>`);
        $('delInput').value = '';
        $('delInput').placeholder = T.delete_placeholder || '';
        $('delOk').disabled = true;
        $('delModal').classList.remove('mc-hidden');
        $('delInput').focus();
    });
    $('delInput').addEventListener('input', () => {
        const c = selectedChar();
        $('delOk').disabled = !c || norm($('delInput').value) !== norm(c.name);
    });
    $('delCancel').addEventListener('click', () => $('delModal').classList.add('mc-hidden'));
    $('delOk').addEventListener('click', () => {
        const c = selectedChar();
        if (!c || norm($('delInput').value) !== norm(c.name)) return;
        $('delModal').classList.add('mc-hidden');
        setBusy(true);
        post('delete', { index: c.index, typed: $('delInput').value });
    });
    $('delInput').addEventListener('keydown', (e) => { if (e.key === 'Enter' && !$('delOk').disabled) $('delOk').click(); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') $('delModal').classList.add('mc-hidden'); });

    // ---------- drag to turn the preview character ----------
    let dragX = null;
    let acc = 0;
    let timer = null;
    const drag = $('drag');
    drag.addEventListener('mousedown', (e) => { dragX = e.clientX; drag.classList.add('dragging'); });
    window.addEventListener('mouseup', () => { dragX = null; drag.classList.remove('dragging'); });
    window.addEventListener('mousemove', (e) => {
        if (dragX === null) return;
        acc += e.clientX - dragX;
        dragX = e.clientX;
        if (!timer) timer = setTimeout(() => { timer = null; if (acc) { post('rotate', { dx: acc }); acc = 0; } }, throttle);
    });
})();
