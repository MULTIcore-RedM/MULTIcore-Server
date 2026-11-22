// MULTIemotes menu. Shows what the client sends; every action goes back to the client script.
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('em');
    let L = {};
    let data = null;     // { cats, items, walks, favs, walk, cancelKey }
    let tabs = [];       // 'favourites', each category, 'walk'
    let tab = 0;
    let sel = 0;         // selected row index
    let rows = [];       // what the list shows now: { type: 'emote' | 'walk' | 'reset', id }

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
    function post(name, body) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIemotes';
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false }));
    }
    function say(text, bad) {
        const m = $('msg');
        m.textContent = text || '';
        m.className = 'msg' + (text && bad ? ' bad' : '');
    }

    const label = (id) => t('emote_' + id);
    const walkLabel = (id) => t('walk_' + id);
    const isFav = (id) => data.favs.indexOf(id) !== -1;
    const norm = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

    function buildRows() {
        const name = tabs[tab];
        const q = norm($('search').value.trim());
        if (name === 'walk') {
            const list = data.walks.filter((w) => !q || norm(walkLabel(w.id)).includes(q) || w.id.includes(q));
            rows = (q ? [] : [{ type: 'reset' }]).concat(list.map((w) => ({ type: 'walk', id: w.id })));
            return;
        }
        let list;
        if (q) list = data.items.filter((e) => norm(label(e.id)).includes(q) || e.id.includes(q));
        else if (name === 'favourites') list = data.favs.map((id) => data.items.find((e) => e.id === id)).filter(Boolean);
        else list = data.items.filter((e) => e.cat === name);
        rows = list.map((e) => ({ type: 'emote', id: e.id, kind: e.kind }));
    }

    function render() {
        const name = tabs[tab];
        const searching = $('search').value.trim() !== '';
        // while searching emotes, the list spans every category
        $('catName').textContent = searching && name !== 'walk' ? t('ui_search') : t('cat_' + name);
        $('catCount').textContent = name === 'walk' ? (data.walk ? walkLabel(data.walk) : t('ui_walk_none')) : t('ui_count', rows.length);
        $('dots').innerHTML = tabs.map((_, i) => `<i class="${i === tab ? 'on' : ''}" data-i="${i}"></i>`).join('');
        $('dots').querySelectorAll('i').forEach((el) => { el.onclick = () => go(Number(el.dataset.i)); });

        const box = $('list');
        if (!rows.length) {
            const empty = name === 'favourites' && !searching ? t('ui_no_favs') : t('ui_no_results');
            box.innerHTML = `<div class="empty">${esc(empty)}</div>`;
            return;
        }
        if (sel >= rows.length) sel = rows.length - 1;
        if (sel < 0) sel = 0;
        box.innerHTML = rows.map((r, i) => {
            const active = i === sel ? ' active' : '';
            if (r.type === 'reset') {
                return `<div class="mc-row reset${active}" data-i="${i}"><div class="names"><span>${esc(t('ui_walk_reset'))}</span></div></div>`;
            }
            if (r.type === 'walk') {
                const used = data.walk === r.id ? `<span class="inuse">${esc(t('ui_walk_current'))}</span>` : '';
                return `<div class="mc-row${active}" data-i="${i}"><div class="names"><span>${esc(walkLabel(r.id))}</span></div>${used}</div>`;
            }
            const sub = r.kind === 'emote' ? t('ui_once') : t('ui_loop');
            const on = isFav(r.id);
            return `<div class="mc-row${active}" data-i="${i}">
                <div class="names"><span>${esc(label(r.id))}</span><span class="mc-sub">${esc(sub)}</span></div>
                <button class="star${on ? ' on' : ''}" data-fav="${esc(r.id)}" title="${esc(t('ui_fav'))}">${on ? '&#9733;' : '&#9734;'}</button>
            </div>`;
        }).join('');
        box.querySelectorAll('.mc-row').forEach((el) => {
            el.onclick = (ev) => {
                if (ev.target.closest('.star')) return;
                sel = Number(el.dataset.i);
                choose();
            };
        });
        box.querySelectorAll('.star').forEach((el) => { el.onclick = () => toggleFav(el.dataset.fav); });
        const cur = box.querySelector('.mc-row.active');
        if (cur) cur.scrollIntoView({ block: 'nearest' });
    }

    function refresh() { buildRows(); render(); }
    function go(i) {
        tab = (i + tabs.length) % tabs.length;
        sel = 0;
        $('search').value = '';
        say('');
        refresh();
    }

    async function choose() {
        const r = rows[sel];
        if (!r) return;
        render();
        if (r.type === 'emote') {
            const res = await post('play', { id: r.id });
            say(res && !res.ok ? res.msg : '', true);
        } else {
            const res = await post('walk', { id: r.type === 'walk' ? r.id : false });
            if (res && res.ok) data.walk = res.walk || null;
            say(res && !res.ok ? res.msg : '', true);
            render();
        }
    }

    async function toggleFav(id) {
        const res = await post('fav', { id, on: !isFav(id) });
        if (res && res.favs) data.favs = res.favs;
        say(res && !res.ok ? res.msg : '', true);
        refresh();
    }

    function open(d) {
        L = d.L || {};
        data = { cats: d.cats || [], items: d.items || [], walks: d.walks || [], favs: d.favs || [], walk: d.walk || null };
        tabs = ['favourites'].concat(data.cats, ['walk']);
        const want = d.tab ? tabs.indexOf(d.tab) : -1;
        tab = want >= 0 ? want : (data.favs.length ? 0 : 1);
        sel = 0;
        root.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(d.lang));
        applyLocale();
        $('stopKey').textContent = d.cancelKey || '';
        $('stopPrompt').classList.toggle('mc-hidden', !d.cancelKey);
        $('search').value = '';
        say('');
        root.classList.remove('mc-hidden');
        refresh();
    }
    function close() { root.classList.add('mc-hidden'); }

    $('catPrev').onclick = () => go(tab - 1);
    $('catNext').onclick = () => go(tab + 1);
    $('search').addEventListener('input', () => { sel = 0; refresh(); });

    document.addEventListener('keydown', (e) => {
        if (root.classList.contains('mc-hidden')) return;
        const typing = document.activeElement === $('search');
        if (e.key === 'Escape') { post('close'); return; }
        if (e.key === 'ArrowDown') { e.preventDefault(); sel = Math.min(sel + 1, rows.length - 1); render(); return; }
        if (e.key === 'ArrowUp') { e.preventDefault(); sel = Math.max(sel - 1, 0); render(); return; }
        if (e.key === 'Enter') { e.preventDefault(); choose(); return; }
        if (typing) return;
        if (e.key === 'ArrowLeft') { go(tab - 1); return; }
        if (e.key === 'ArrowRight') { go(tab + 1); return; }
        const stop = $('stopKey').textContent;
        if (stop && e.key.toUpperCase() === stop.toUpperCase()) post('stop');
    });

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'open') open(d);
        else if (d.action === 'close') close();
    });
})();
