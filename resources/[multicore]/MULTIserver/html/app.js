// MULTIserver page: player list and server info. Shows what the server sends.
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('ms');
    let L = {};
    let mode = null;
    let list = null;
    let busy = false;

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
    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIserver';
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({}));
    }

    // ---------- player list ----------
    // column order and widths; a column shows only when the server sent it
    const COLS = [
        { key: 'id', label: 'ui_col_id', width: '56px' },
        { key: 'name', label: 'ui_col_name', width: 'minmax(120px, 1.2fr)' },
        { key: 'char', label: 'ui_col_char', width: 'minmax(120px, 1.2fr)' },
        { key: 'job', label: 'ui_col_job', width: 'minmax(90px, 1fr)' },
        { key: 'citizenid', label: 'ui_col_citizenid', width: '110px' },
        { key: 'license', label: 'ui_col_license', width: 'minmax(120px, 1fr)' },
        { key: 'ping', label: 'ui_col_ping', width: '64px' },
    ];
    function shownCols() { return COLS.filter((c) => list && list.columns && list.columns[c.key]); }

    function renderPlayers() {
        const cols = shownCols();
        const board = $('players');
        board.style.setProperty('--cols', cols.map((c) => c.width).join(' '));
        board.classList.toggle('staff', !!list.admin);
        $('plCount').textContent = list.max ? t('ui_count', list.count, list.max) : t('ui_count_only', list.count);
        $('plStaff').textContent = list.admin ? t('ui_staff_view') : '';
        $('plHead').innerHTML = cols.map((c) => `<span class="c-${c.key}">${esc(t(c.label))}</span>`).join('');
        const q = $('plSearch').value.trim().toLowerCase();
        const rows = (list.players || []).filter((p) => !q || cols.some((c) => String(p[c.key] ?? '').toLowerCase().includes(q)));
        if (!rows.length) { $('plRows').innerHTML = `<div class="empty">${esc(t(q ? 'ui_no_match' : 'ui_nobody'))}</div>`; return; }
        $('plRows').innerHTML = rows.map((p) => {
            const cells = cols.map((c) => {
                let v = p[c.key];
                let cls = `c-${c.key}`;
                if (c.key === 'ping') {
                    v = Number(v) || 0;
                    if (v >= 250) cls += ' ping-bad'; else if (v >= 120) cls += ' ping-mid';
                }
                if (c.key === 'job' && !v) v = t('ui_no_job');
                return `<span class="${cls}" title="${esc(v)}">${esc(v)}</span>`;
            }).join('');
            return `<div class="row${p.id === list.me ? ' me' : ''}">${cells}</div>`;
        }).join('');
    }

    async function refresh() {
        if (busy || mode !== 'players') return;
        busy = true;
        const data = await post('refresh');
        busy = false;
        if (data && data.players) { list = data; renderPlayers(); }
    }

    // ---------- server info ----------
    function renderInfo(d) {
        $('inName').textContent = d.name || '';
        $('inCount').textContent = d.count != null ? t('ui_count', d.count, d.max) : '';
        $('inDesc').textContent = d.desc || '';
        const links = [['ui_rules', d.rules], ['ui_discord', d.discord], ['ui_website', d.website]].filter((l) => l[1]);
        $('inLinks').innerHTML = links.map((l, i) =>
            `<div class="mc-row"><span class="lbl">${esc(t(l[0]))}</span><span class="url">${esc(l[1])}</span>` +
            `<button class="mc-btn small" data-copy="${i}">${esc(t('ui_copy'))}</button></div>`).join('');
        $('inLinks').querySelectorAll('[data-copy]').forEach((b) => {
            b.onclick = () => {
                const ta = document.createElement('textarea');
                ta.value = links[Number(b.dataset.copy)][1];
                document.body.appendChild(ta);
                ta.select();
                let ok = false;
                try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
                ta.remove();
                $('inMsg').textContent = ok ? t('ui_copied') : t('ui_copy_failed');
            };
        });
        $('inMsg').textContent = '';
    }

    // ---------- open / close ----------
    function close() {
        root.classList.add('mc-hidden');
        mode = null;
        post('close');
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'close') { root.classList.add('mc-hidden'); mode = null; return; }
        if (m.action !== 'open') return;
        L = m.L || L;
        root.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(m.lang));
        applyLocale();
        mode = m.mode;
        $('players').classList.toggle('mc-hidden', mode !== 'players');
        $('info').classList.toggle('mc-hidden', mode !== 'info');
        if (mode === 'players') { list = m.data || { players: [] }; $('plSearch').value = ''; renderPlayers(); }
        else renderInfo(m.data || {});
        root.classList.remove('mc-hidden');
    });

    $('plSearch').addEventListener('input', () => { if (list) renderPlayers(); });
    document.addEventListener('keydown', (e) => {
        if (!mode) return;
        if (e.key === 'Escape' || e.key === 'Backspace' && document.activeElement !== $('plSearch')) { close(); return; }
        if (mode === 'players' && (e.key === 'r' || e.key === 'R') && document.activeElement !== $('plSearch')) refresh();
    });
})();
