// MULTItelegram page. Shows what the server sends; every action goes back to the server.
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('tg');
    let L = {};
    let state = null;
    let tab = 'inbox';
    let selected = null;      // telegram id shown on the right
    let busy = false;
    let confirmDelete = false;

    // locale line; %s markers are filled in order, %% is a literal %
    function t(key, ...args) {
        let i = 0;
        const s = L[key] != null ? String(L[key]) : key;
        return s.replace(/%%|%[sd]/g, (m) => (m === '%%' ? '%' : (args[i++] ?? '')));
    }
    function applyLocale() {
        document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
        document.querySelectorAll('[data-lp]').forEach((el) => { el.placeholder = t(el.dataset.lp); });
    }
    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    }
    function money(n) { return '$' + (Number(n) || 0).toFixed(2); }

    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTItelegram';
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
    async function act(action, data) {
        if (busy) return null;
        busy = true;
        const res = await post('action', { action, data });
        busy = false;
        if (res && res.state) { state = res.state; render(); }
        if (res && (res.msg || !res.ok)) say(res.msg, res.ok);
        return res;
    }

    // ---------- inbox ----------
    function current() { return (state.inbox || []).find((m) => m.id === selected) || null; }

    function renderInbox() {
        const list = state.inbox || [];
        const unread = list.filter((m) => m.unread).length;
        $('unread').textContent = unread ? `(${unread})` : '';
        const box = $('inboxList');
        if (!state.canRead) { box.innerHTML = `<div class="empty">${esc(t('ui_read_at_office'))}</div>`; }
        else if (!list.length) { box.innerHTML = `<div class="empty">${esc(t('ui_inbox_empty'))}</div>`; }
        else {
            box.innerHTML = list.map((m) => `
                <div class="mc-row mail ${m.unread ? 'unread' : 'read'} ${m.id === selected ? 'active' : ''}" data-id="${m.id}">
                    <div class="top"><span class="who">${esc(m.sendername)}</span><span class="when">${esc(m.date)}</span></div>
                    <span class="mc-sub">${esc(m.subject)}${m.parcel && !m.parcel.collected ? ` <span class="tag">· ${esc(t('ui_parcel'))}</span>` : ''}</span>
                </div>`).join('');
            box.querySelectorAll('.mail').forEach((el) => { el.onclick = () => select(Number(el.dataset.id)); });
        }
        renderReader();
    }

    function renderReader() {
        const m = state && current();
        $('readerEmpty').textContent = t('ui_select');
        $('readerEmpty').classList.toggle('mc-hidden', !!m);
        $('readerBody').classList.toggle('mc-hidden', !m);
        $('readerActions').classList.toggle('mc-hidden', !m);
        if (!m) return;
        $('rFrom').textContent = m.sendername;
        $('rTo').textContent = state.me ? state.me.name : '';
        $('rDate').textContent = m.date;
        $('rSubject').textContent = m.subject;
        $('rText').textContent = m.message;
        const p = m.parcel;
        $('rParcel').textContent = p ? t(p.collected ? 'ui_parcel_done' : 'ui_parcel_waiting', p.amount, p.label) : '';
        $('btnCollect').classList.toggle('mc-hidden', !(p && !p.collected));
        $('btnCollect').disabled = !state.atOffice;
        $('btnReply').disabled = !m.sender || m.sender === 'system';
        confirmDelete = false;
        $('btnDelete').textContent = t('ui_delete');
    }

    async function select(id) {
        selected = id;
        const m = current();
        renderInbox();
        if (m && m.unread) await act('read', { id });
    }

    // ---------- compose ----------
    function renderCompose() {
        const box = $('pickList');
        const list = state.contacts || [];
        box.innerHTML = list.length ? list.map((c) => `
            <div class="mc-row pick" data-cid="${esc(c.citizenid)}"><span>${esc(c.name)}</span><span class="mc-sub">${esc(c.citizenid)}</span></div>`).join('')
            : `<div class="empty">${esc(t('ui_contacts_empty'))}</div>`;
        box.querySelectorAll('.pick').forEach((el) => {
            el.onclick = () => { $('cTo').value = el.dataset.cid; $('cFound').textContent = el.querySelector('span').textContent; };
        });
        const lim = state.limits || {};
        $('cTo').maxLength = lim.recipient || 60;
        $('cSubject').maxLength = lim.subject || 60;
        $('cMessage').maxLength = lim.message || 1000;
        const parcel = state.parcel;
        $('cParcelBox').classList.toggle('mc-hidden', !(parcel && state.atOffice));
        if (parcel) {
            const sel = $('cParcel');
            const keep = sel.value;
            sel.innerHTML = `<option value="">${esc(t('ui_parcel_none'))}</option>` +
                (parcel.items || []).map((it) => `<option value="${it.slot}">${esc(it.label)} (${it.amount})</option>`).join('');
            if ([...sel.options].some((o) => o.value === keep)) sel.value = keep;
        }
        $('cAway').textContent = state.atOffice ? '' : t('ui_send_at_office');
        $('btnSend').disabled = !state.atOffice;
        updatePrice();
        updateChars();
    }
    function updatePrice() {
        if (!state) return;
        let s = t('ui_price', money(state.price));
        if (state.parcel && $('cParcel').value) s += ', ' + t('ui_price_parcel', money(state.parcel.price));
        $('cPrice').textContent = s;
    }
    function updateChars() {
        const max = (state && state.limits && state.limits.message) || 1000;
        $('cChars').textContent = t('ui_chars', $('cMessage').value.length, max);
    }

    // ---------- contacts ----------
    function renderContacts() {
        const box = $('contactList');
        const list = state.contacts || [];
        box.innerHTML = list.length ? list.map((c) => `
            <div class="mc-row contact">
                <div class="names"><span>${esc(c.name)}</span><span class="mc-sub">${esc(c.citizenid)}</span></div>
                <div class="mc-btn-row">
                    <button class="mc-btn small" data-write="${esc(c.citizenid)}">${esc(t('ui_write_to'))}</button>
                    <button class="mc-btn small danger" data-remove="${esc(c.citizenid)}">${esc(t('ui_remove'))}</button>
                </div>
            </div>`).join('') : `<div class="empty">${esc(t('ui_contacts_empty'))}</div>`;
        box.querySelectorAll('[data-write]').forEach((b) => {
            b.onclick = () => { showTab('compose'); $('cTo').value = b.dataset.write; $('cFound').textContent = ''; };
        });
        box.querySelectorAll('[data-remove]').forEach((b) => {
            b.onclick = () => act('contact_remove', { citizenid: b.dataset.remove });
        });
        $('aTo').maxLength = (state.limits && state.limits.recipient) || 60;
        $('aName').maxLength = (state.limits && state.limits.name) || 40;
    }

    // ---------- whole page ----------
    function render() {
        if (!state) return;
        $('office').textContent = state.office || t('ui_away');
        $('myNumber').textContent = state.me && state.me.id ? t('ui_your_number', state.me.id) : '';
        $('cash').textContent = t('ui_cash', money(state.cash));
        if (selected && !current()) selected = null;
        renderInbox();
        renderCompose();
        renderContacts();
    }

    function showTab(name) {
        tab = name;
        document.querySelectorAll('.mc-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
        document.querySelectorAll('[data-pane]').forEach((p) => p.classList.toggle('mc-hidden', p.dataset.pane !== name));
        say('');
    }

    // ---------- wiring ----------
    document.querySelectorAll('.mc-tab').forEach((b) => { b.onclick = () => showTab(b.dataset.tab); });
    $('btnReply').onclick = () => {
        const m = current();
        if (!m) return;
        showTab('compose');
        $('cTo').value = m.sender;
        $('cFound').textContent = m.sendername;
        $('cSubject').value = t('ui_re', m.subject).slice(0, (state.limits && state.limits.subject) || 60);
        $('cMessage').focus();
    };
    $('btnDelete').onclick = async () => {
        const m = current();
        if (!m) return;
        if (!confirmDelete) { confirmDelete = true; $('btnDelete').textContent = t('ui_sure'); return; }
        const res = await act('delete', { id: m.id });
        if (res && res.ok) { selected = null; renderInbox(); }
    };
    $('btnCollect').onclick = () => { const m = current(); if (m) act('collect', { id: m.id }); };
    $('cLookup').onclick = async () => {
        $('cFound').textContent = '';
        const to = $('cTo').value.trim();
        if (!to) return;
        const res = await post('action', { action: 'lookup', data: { to } });
        if (res && res.ok && res.extra) { $('cFound').textContent = t('ui_found', res.extra.name, res.extra.id); say(''); }
        else say(res && res.msg, false);
    };
    $('cTo').oninput = () => { $('cFound').textContent = ''; };
    $('cMessage').oninput = updateChars;
    $('cParcel').onchange = updatePrice;
    $('btnSend').onclick = async () => {
        const data = { to: $('cTo').value.trim(), subject: $('cSubject').value.trim(), message: $('cMessage').value.trim() };
        if (state.parcel && $('cParcel').value) {
            data.parcel = { slot: Number($('cParcel').value), amount: Math.floor(Number($('cAmount').value) || 0) };
        }
        const res = await act('send', data);
        if (res && res.ok) {
            $('cTo').value = ''; $('cSubject').value = ''; $('cMessage').value = ''; $('cFound').textContent = '';
            $('cParcel').value = ''; $('cAmount').value = '1';
            updateChars(); updatePrice();
        }
    };
    $('btnAdd').onclick = async () => {
        const res = await act('contact_add', { to: $('aTo').value.trim(), name: $('aName').value.trim() });
        if (res && res.ok) { $('aTo').value = ''; $('aName').value = ''; }
    };
    $('close').onclick = () => post('close');

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !root.classList.contains('mc-hidden')) post('close');
    });

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'open') {
            L = d.L || {};
            root.classList.toggle('mc-cyrillic', d.lang === 'ru');
            applyLocale();
            state = d.state || {};
            selected = null;
            render();
            showTab(d.mode || 'inbox');
            if (d.prefill) {
                if (d.prefill.to) $('cTo').value = d.prefill.to;
                if (d.prefill.subject) $('cSubject').value = d.prefill.subject;
            }
            root.classList.remove('mc-hidden');
        } else if (d.action === 'close') {
            root.classList.add('mc-hidden');
            state = null;
        }
    });
})();
