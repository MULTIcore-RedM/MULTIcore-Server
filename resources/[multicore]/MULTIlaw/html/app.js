// MULTIlaw pages: the bounty board, criminal records, and the jail timer.
// Shows what the server sends; every button goes back to the server, which checks everything.
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('root');
    const app = $('app');
    let L = {};
    let page = null;      // 'board' | 'records'
    let list = [];
    let law = false;
    let sel = null;
    let person = null;    // records: the open page
    let busy = false;
    let armed = null;
    let timerEnd = 0;
    let timerId = null;

    function t(key, ...args) {
        let i = 0;
        const s = L[key] != null ? String(L[key]) : key;
        return s.replace(/%%|%[sd]/g, (m) => (m === '%%' ? '%' : (args[i++] ?? '')));
    }
    function applyLocale() {
        document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
        document.querySelectorAll('[data-lp]').forEach((el) => { el.placeholder = t(el.dataset.lp); });
    }
    function setLang(lang) { root.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(lang)); }
    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    }
    function money(n) {
        n = Number(n) || 0;
        const [d, c] = n.toFixed(2).split('.');
        return `<span class="mc-money">$${d.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}<span class="mc-cents">${c}</span></span>`;
    }
    function date(sec) {
        if (!sec) return '';
        const d = new Date(sec * 1000);
        const p = (x) => String(x).padStart(2, '0');
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
    }
    function span(sec) {
        sec = Math.max(0, Math.floor(sec || 0));
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        if (h >= 24) return t('ui_days', Math.floor(h / 24));
        if (h >= 1) return t('ui_hours', h);
        return t('ui_minutes', Math.max(1, m));
    }
    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIlaw';
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false }));
    }
    function say(text, ok) {
        const m = $('msg');
        m.textContent = text || '';
        m.className = 'msg ' + (text ? (ok ? 'ok' : 'bad') : '');
    }
    function close() {
        app.classList.add('mc-hidden');
        page = null;
        post('close');
    }

    // ---------- bounty board ----------
    function renderBoard() {
        $('title').textContent = t('ui_board_title');
        $('subtitle').textContent = list.length ? t('ui_board_count', list.length) : '';
        let html = '';
        if (!list.length) html = `<div class="empty">${esc(t('ui_board_empty'))}</div>`;
        else {
            html = '<div class="posters mc-scroll">';
            list.forEach((b) => {
                html += `<div class="poster${sel === b.id ? ' active' : ''}" data-id="${b.id}">` +
                    `<div class="p-head">${esc(t('ui_wanted'))}</div>` +
                    `<div class="p-name">${esc(b.name)}</div>` +
                    `<div class="p-reward"><span>${esc(t('ui_reward'))}</span><b>${money(b.reward)}</b></div>` +
                    `<div class="p-reason">${esc(b.reason)}</div>` +
                    `<div class="p-foot"><span>${esc(t('ui_posted_by', b.poster || ''))}</span><span>${esc(t('ui_comes_down', span(b.left)))}</span></div>` +
                    `</div>`;
            });
            html += '</div>';
        }
        $('body').innerHTML = html;
        let left = '';
        if (law) left += `<button class="mc-btn small" data-act="post">${esc(t('ui_post_bounty'))}</button>`;
        const cur = list.find((b) => b.id === sel);
        if (cur && cur.canCancel) {
            left += `<button class="mc-btn small danger" data-act="cancel">${esc(armed === 'cancel' ? t('ui_sure') : t('ui_take_down'))}</button>`;
        }
        $('footLeft').innerHTML = left;
    }

    // ---------- records ----------
    function kindLabel(k) { return t('kind_' + k); }
    function renderRecords() {
        $('title').textContent = t('ui_records_title');
        $('subtitle').textContent = t('ui_records_sub');
        let rows = '';
        if (!list.length) rows = `<div class="empty">${esc(t('ui_records_none'))}</div>`;
        list.forEach((p) => {
            rows += `<div class="mc-row${sel === p.cid ? ' active' : ''}" data-cid="${esc(p.cid)}">` +
                `<div class="main"><b>${esc(p.name)}</b><span class="mc-sub">${esc(t('ui_counts', p.arrests, p.fines, p.minutes))}</span></div>` +
                `<div class="side faint">${esc(date(p.last).slice(0, 10))}</div></div>`;
        });
        let detail = `<div class="empty">${esc(t('ui_pick_person'))}</div>`;
        if (person) {
            detail = `<h2>${esc(person.name)}</h2><div class="lead">${esc(person.cid)}</div>` +
                `<div class="facts">` +
                `<span>${esc(t('ui_status'))}</span><b>${esc(person.jailed ? t('ui_in_jail', span(person.jailLeft)) : t('ui_free'))}</b>` +
                `<span>${esc(t('ui_unpaid'))}</span><b>${esc(t('ui_unpaid_val', person.unpaid))} · ${money(person.owed)}</b>` +
                `<span>${esc(t('ui_bounties'))}</span><b>${person.bounties.length ? person.bounties.map((b) => money(b.reward)).join(', ') : esc(t('ui_none'))}</b>` +
                `</div><div class="entries">`;
            if (!person.entries.length) detail += `<div class="empty">${esc(t('ui_no_entries'))}</div>`;
            person.entries.forEach((e) => {
                let extra = '';
                if (e.amount != null) extra += ` · ${money(e.amount)}`;
                if (e.minutes != null) extra += ` · ${esc(t('ui_minutes_n', e.minutes))}`;
                detail += `<div class="entry"><div class="e-top"><span class="pill">${esc(kindLabel(e.kind))}</span>` +
                    `<span class="faint">${esc(date(e.at))}</span></div>` +
                    `<div class="e-text">${esc(e.detail)}${extra}</div>` +
                    (e.officer ? `<div class="e-by faint">${esc(t('ui_by', e.officer))}</div>` : '') + `</div>`;
            });
            detail += '</div>';
        }
        $('body').innerHTML = `<div class="split"><section class="col"><input class="mc-input search" id="q" data-lp="ui_search">` +
            `<div class="mc-list mc-scroll list">${rows}</div></section><section class="col detail mc-scroll">${detail}</section></div>`;
        const q = $('q');
        q.placeholder = t('ui_search');
        q.value = lastQuery;
        $('footLeft').innerHTML = '';
    }
    let lastQuery = '';
    let searchTimer = null;

    function render() {
        if (page === 'board') renderBoard();
        else if (page === 'records') renderRecords();
    }

    // ---------- clicks ----------
    document.addEventListener('click', (ev) => {
        if (!page || busy) return;
        const card = ev.target.closest('[data-id]');
        if (card && page === 'board') { sel = Number(card.dataset.id); armed = null; render(); return; }
        const row = ev.target.closest('[data-cid]');
        if (row && page === 'records') {
            sel = row.dataset.cid;
            busy = true;
            post('records_get', { cid: sel }).then((res) => {
                busy = false;
                if (res && res.ok) { person = res.page; say(''); } else say(res && res.msg, false);
                render();
            });
            return;
        }
        const btn = ev.target.closest('[data-act]');
        if (!btn) return;
        const act = btn.dataset.act;
        if (act === 'post') { post('board_post'); app.classList.add('mc-hidden'); page = null; return; }
        if (act === 'cancel') {
            if (armed !== 'cancel') { armed = 'cancel'; render(); return; }
            armed = null;
            busy = true;
            post('board_cancel', { id: sel }).then((res) => {
                busy = false;
                if (res && res.msg) say(res.msg, res.ok);
                if (res && res.ok && res.list) { list = res.list; sel = null; }
                render();
            });
        }
    });
    document.addEventListener('input', (ev) => {
        if (ev.target.id !== 'q') return;
        lastQuery = ev.target.value;
        clearTimeout(searchTimer);
        searchTimer = setTimeout(() => {
            post('records_search', { q: lastQuery }).then((res) => {
                if (res && res.ok) { list = res.list || []; render(); const q = $('q'); q.focus(); q.setSelectionRange(q.value.length, q.value.length); }
            });
        }, 300);
    });
    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && page) close(); });

    // ---------- jail timer ----------
    function tick() {
        const left = Math.max(0, Math.round((timerEnd - Date.now()) / 1000));
        const m = Math.floor(left / 60), s = left % 60;
        $('timerTime').textContent = `${m}:${String(s).padStart(2, '0')}`;
        if (left <= 0) { clearInterval(timerId); timerId = null; }
    }

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.L) { L = d.L; applyLocale(); }
        if (d.lang) setLang(d.lang);
        if (d.action === 'open') {
            page = d.page; list = d.list || []; law = !!d.law; sel = null; person = null; armed = null; lastQuery = '';
            say('');
            app.classList.remove('mc-hidden');
            render();
        } else if (d.action === 'close') {
            app.classList.add('mc-hidden');
            page = null;
        } else if (d.action === 'timer') {
            if (d.seconds == null || d.seconds < 0) {
                $('timer').classList.add('mc-hidden');
                if (timerId) clearInterval(timerId);
                timerId = null;
                return;
            }
            timerEnd = Date.now() + d.seconds * 1000;
            $('timer').classList.remove('mc-hidden');
            tick();
            if (!timerId) timerId = setInterval(tick, 1000);
        }
    });
})();
