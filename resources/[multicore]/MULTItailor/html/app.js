/* MULTItailor NUI - MULTIcore base-game look (black panels, white text).
 *
 * Lua -> JS : { action:'open', view, data, strings? } · { action:'update', view, data } · { action:'close' }
 *             { action:'busy', on, text }
 * JS -> Lua : POST action { view, act, ... } -> reply  ·  POST close {}
 * Views     : designer (docked, fitting dummy) · store (docked, try-on on yourself)
 *             sew · counter · boss (centred plates)
 * Every price, stock count and item is decided by the server; this page only shows and asks.
 */
(function () {
    'use strict';

    const IN_GAME = typeof window.GetParentResourceName === 'function';
    const RES = IN_GAME ? window.GetParentResourceName() : 'MULTItailor';
    const root = document.getElementById('tlApp');
    const busyEl = document.getElementById('tlBusy');
    const toastsEl = document.getElementById('tlToasts');

    let STR = {};
    let cur = null;      // open view name
    let S = null;        // state of the open view
    const timers = {};

    const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const t = (key, fallback, ...args) => {
        let s = STR[key] || fallback || key;
        args.forEach((a) => {
            s = s.replace(/%(\.\d+f|s|d)/, (m) => (m.endsWith('f') ? Number(a || 0).toFixed(Number(m[2]) || 2) : String(a)));
        });
        return s;
    };
    const money = (n) => { const v = Number(n) || 0; return `${v < 0 ? "-" : ""}$${Math.abs(v).toFixed(2)}`; };
    const clampInt = (v, lo, hi) => {
        let n = Math.floor(Number(v));
        if (!Number.isFinite(n)) n = lo;
        return Math.max(lo, Math.min(hi, n));
    };
    const throttle = (key, ms, fn) => { clearTimeout(timers[key]); timers[key] = setTimeout(fn, ms); };
    const CLOSE_SVG = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M3 3l10 10M13 3L3 13" stroke="currentColor" stroke-width="2" fill="none"/></svg>';


    async function post(name, body) {
        if (!IN_GAME) return Mock.reply(name, body || {});
        try {
            const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body || {}) });
            return await r.json();
        } catch (e) { return { ok: false }; }
    }
    const act = (name, data) => post('action', Object.assign({ view: cur, act: name }, data || {}));

    function toast(text, kind) {
        if (!text) return;
        const el = document.createElement('div');
        el.className = `ib-toast ib-toast--${kind || 'info'}`;
        el.textContent = text;
        toastsEl.appendChild(el);
        requestAnimationFrame(() => el.classList.add('is-in'));
        setTimeout(() => { el.classList.remove('is-in'); setTimeout(() => el.remove(), 250); }, 3800);
    }

    function msg(text, kind) {
        const m = root.querySelector('[data-msg]');
        if (!m) return;
        m.textContent = text || '';
        m.className = `ib-msg tl-msg${kind ? ` ib-msg--${kind}` : ''}`;
    }

    function head(eyebrow, title, rule) {
        return `
          <header class="tl-head">
            <div class="ib-plaque tl-plaque">
              <p class="ib-eyebrow">${esc(eyebrow)}</p>
              <h1 class="ib-title">${esc(title)}</h1>
              <div class="ib-rule">${esc(rule)}</div>
            </div>
            <button type="button" class="ib-close" data-act="close" title="${esc(t('ui_close', 'Close'))}">${CLOSE_SVG}</button>
          </header>`;
    }

    function keepScroll(fn) {
        const lists = Array.from(root.querySelectorAll('.ib-scroll')).map((el) => el.scrollTop);
        const inputs = {};
        root.querySelectorAll('[data-keep]').forEach((el) => { inputs[el.dataset.keep] = el.value; });
        fn();
        root.querySelectorAll('.ib-scroll').forEach((el, i) => { if (lists[i] != null) el.scrollTop = lists[i]; });
        root.querySelectorAll('[data-keep]').forEach((el) => { if (inputs[el.dataset.keep] != null) el.value = inputs[el.dataset.keep]; });
    }

    function render() {
        if (!cur || !S) return;
        keepScroll(() => { root.innerHTML = Views[cur].render(); });
    }

    function open(view, data) {
        if (!Views[view]) return;
        cur = view;
        S = Views[view].init(data || {});
        root.className = Views[view].docked ? 'tl-dock' : 'tl-center';
        root.dataset.view = view;
        render();
        root.hidden = false;
    }

    function close(postIt) {
        if (!cur) return;
        root.hidden = true;
        root.innerHTML = '';
        cur = null;
        S = null;
        busyEl.hidden = true;
        if (postIt) post('close', {});
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.strings) STR = m.strings;
        if (m.action === 'open') open(m.view, m.data);
        else if (m.action === 'close') close(false);
        else if (m.action === 'update' && m.view === cur && Views[cur].update) { Views[cur].update(m.data); render(); }
        else if (m.action === 'busy') {
            busyEl.hidden = !m.on;
            const tx = busyEl.querySelector('[data-busy-text]');
            if (tx && m.text) tx.textContent = m.text;
        }
    });

    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && cur) { e.preventDefault(); close(true); }
    });

    root.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-act]');
        if (!btn || btn.disabled || !cur) return;
        if (btn.dataset.act === 'close') return close(true);
        if (Views[cur].click) Views[cur].click(btn, e);
    });
    root.addEventListener('input', (e) => { if (cur && Views[cur].input) Views[cur].input(e.target, e); });
    root.addEventListener('change', (e) => { if (cur && Views[cur].change) Views[cur].change(e.target, e); });

    /* ================================================================== designer */
    const GROUPS = [
        ['Head', 'ui_grp_head', 'Head & Neck'],
        ['Upper', 'ui_grp_upper', 'Shirts, Vests & Coats'],
        ['Lower', 'ui_grp_lower', 'Trousers, Skirts & Boots'],
        ['Hands', 'ui_grp_hands', 'Gloves & Jewellery'],
        ['Gear', 'ui_grp_gear', 'Belts & Gear'],
    ];
    const VIEWS = [['full', 'ui_view_full', 'Full'], ['head', 'ui_view_head', 'Head'], ['torso', 'ui_view_torso', 'Torso'], ['legs', 'ui_view_legs', 'Legs']];

    function viewBar(state) {
        return `
          <div class="ib-row ib-row--nowrap tl-viewbar">
            <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="rotate" data-dir="-1" title="${esc(t('ui_turn_left', 'Turn left'))}">&#x21BA;</button>
            ${VIEWS.map(([k, key, l]) => `<button type="button" class="ib-btn ib-btn--sm${state.view === k ? ' ib-btn--primary' : ' ib-btn--ghost'}" data-act="view" data-view="${k}">${esc(t(key, l))}</button>`).join('')}
            <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="rotate" data-dir="1" title="${esc(t('ui_turn_right', 'Turn right'))}">&#x21BB;</button>
          </div>`;
    }

    /* NPC clothing section of the designer (optional NPC clothing resource): search confirmed NPC pieces, try them on the
       dummy, name each piece, cut one garment or an outfit (min..max pieces). The server re-checks everything. */
    const Npc = {
        fresh() { return { rows: null, q: '', cat: '', page: 1, pages: 1, total: 0, cats: [], pinned: [], outfitName: '', loading: false, busy: false }; },
        cfg() { return S.data.npc || { min: 3, max: 14, nameMax: 40 }; },
        pin(id) { return S.npc.pinned.find((p) => p.id === id); },
        refocus(field) {
            if (!field) return;
            const el = root.querySelector(`[data-field="${field}"]`);
            if (el) { el.focus(); const n = el.value.length; try { el.setSelectionRange(n, n); } catch (e) { /* number inputs */ } }
        },
        async load() {
            const n = S.npc;
            const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.field : null;
            n.loading = true;
            Designer.refresh();
            Npc.refocus(focused);
            const res = await act('npcList', { q: n.q, cat: n.cat, page: n.page });
            if (!S || S.npc !== n) return;
            n.loading = false;
            if (res && res.ok) {
                n.rows = res.rows || []; n.page = res.page || 1; n.pages = res.pages || 1; n.total = res.total || 0; n.cats = res.cats || [];
            } else {
                n.rows = [];
                msg((res && res.error) || t('ui_npc_off', 'NPC clothing is not available right now.'), 'bad');
            }
            const still = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.field : null;
            Designer.refresh();
            Npc.refocus(still || focused);
        },
        mats(list) {
            return (list || []).map((x) => `${x.amount} ${esc(Designer.label(x.item))}`).join(', ');
        },
        renderList() {
            const n = S.npc;
            const opts = n.cats.map((c) => `<option value="${esc(c.id)}"${n.cat === c.id ? ' selected' : ''}>${esc(c.label)} (${Number(c.count) || 0})</option>`).join('');
            const bar = `
              <div class="ib-row ib-row--nowrap tl-npc-bar">
                <input class="ib-input ib-grow" type="search" maxlength="48" placeholder="${esc(t('ui_npc_search', 'Search NPC clothing...'))}" value="${esc(n.q)}" data-field="npcq">
                <select class="ib-select" data-field="npccat"><option value="">${esc(t('ui_npc_all', 'Every kind'))}</option>${opts}</select>
              </div>`;
            if (n.rows === null) return `${bar}<div class="ib-empty">${esc(t('ui_npc_loading', 'Fetching the pattern drawers...'))}</div>`;
            if (!n.rows.length) return `${bar}<div class="ib-empty">${esc(n.loading ? t('ui_npc_loading', 'Fetching the pattern drawers...') : t('ui_npc_none', 'No NPC clothing matches for this figure.'))}</div>`;
            const rows = n.rows.map((r) => {
                const p = Npc.pin(r.id);
                return `
                  <div class="tl-cat${p ? ' is-on' : ''}" data-npc="${esc(r.id)}">
                    <div class="tl-cat__head">
                      <span class="tl-cat__name">${esc(r.label)}</span>
                      <span class="tl-cat__sel ib-faint">${esc(r.sub || '')} · ${esc(t('ui_npc_looks', '%d looks', Number(r.vars) || 1))}</span>
                    </div>
                    <div class="tl-cat__ctrl">
                      <button type="button" class="ib-btn ib-btn--sm${p ? ' ib-btn--primary' : ''}" data-act="${p ? 'npcunpin' : 'npcpin'}">${esc(p ? t('ui_npc_pinned', 'On the dummy ✓') : t('ui_npc_pin', 'Try on & pin'))}</button>
                    </div>
                    <div class="tl-cat__mats ib-faint">${Npc.mats(r.materials)}</div>
                  </div>`;
            }).join('');
            const pager = n.pages > 1 ? `
              <div class="ib-row ib-row--nowrap tl-npc-pager">
                <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="npcpage" data-d="-1"${n.page > 1 ? '' : ' disabled'}>&#x2039;</button>
                <span class="ib-faint ib-grow">${esc(t('ui_npc_page', 'Page %d of %d · %d pieces', n.page, n.pages, n.total))}</span>
                <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="npcpage" data-d="1"${n.page < n.pages ? '' : ' disabled'}>&#x203A;</button>
              </div>` : '';
            return bar + rows + pager;
        },
        renderFoot() {
            const n = S.npc;
            const c = Npc.cfg();
            const max = Number(c.nameMax) || 40;
            const pins = n.pinned.map((p) => {
                const vl = (p.vlabels && p.vlabels[p.v - 1]) || t('ui_npc_look', 'Look %d', p.v);
                return `
                  <div class="tl-npc-pin ib-card ib-card--inset" data-npc="${esc(p.id)}">
                    <div class="ib-row ib-row--nowrap">
                      <input class="ib-input ib-grow" type="text" maxlength="${max}" placeholder="${esc(t('ui_npc_name_ph', 'Name this piece'))}" value="${esc(p.name)}" data-field="npcname">
                      <div class="ib-stepper">
                        <button type="button" data-act="npcv" data-d="-1"${p.vars > 1 ? '' : ' disabled'}>&#x2039;</button>
                        <input type="number" min="1" max="${p.vars}" value="${p.v}" data-field="npcv"${p.vars > 1 ? '' : ' disabled'}>
                        <button type="button" data-act="npcv" data-d="1"${p.vars > 1 ? '' : ' disabled'}>&#x203A;</button>
                      </div>
                    </div>
                    <div class="ib-row ib-row--nowrap">
                      <span class="ib-faint ib-grow">${esc(p.label)} · ${esc(vl)}</span>
                      <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="npclook" title="${esc(t('ui_npc_look_at', 'Show it on the dummy'))}">&#x1F441;</button>
                      <button type="button" class="ib-btn ib-btn--sm" data-act="npccutone"${n.busy ? ' disabled' : ''}>${esc(t('ui_npc_cut_one', 'Cut garment'))}</button>
                      <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="npcunpin">&#x2715;</button>
                    </div>
                  </div>`;
            }).join('');
            const need = {};
            n.pinned.forEach((p) => (p.materials || []).forEach((m) => { need[m.item] = (need[m.item] || 0) + Number(m.amount || 0); }));
            const keys = Object.keys(need).sort();
            const pockets = S.data.pockets || {};
            const mats = keys.length ? `<div class="tl-mats"><div class="ib-label">${esc(t('ui_npc_mats', 'Materials for the whole outfit'))}</div><div class="tl-mats__grid">${keys.map((k) => {
                const have = Number(pockets[k] || 0);
                return `<span class="tl-mat${have >= need[k] ? '' : ' is-short'}"><span>${esc(Designer.label(k))}</span><b class="ib-mono">${have}/${need[k]}</b></span>`;
            }).join('')}</div></div>` : '';
            const count = n.pinned.length;
            return `
              ${count ? `<div class="tl-npc-pins ib-scroll">${pins}</div>` : `<div class="ib-hint">${esc(t('ui_npc_hint', 'Try NPC pieces on the dummy and pin them. Name each piece; cut one garment, or %d to %d pieces as an outfit.', c.min, c.max))}</div>`}
              ${mats}
              <div class="ib-field">
                <label class="ib-label" for="tlNpcOutfit">${esc(t('ui_npc_outfit_name', 'Name the outfit'))}</label>
                <input id="tlNpcOutfit" class="ib-input" type="text" maxlength="${Number(S.data.nameMax) || 40}" placeholder="${esc(t('ui_name_ph', "e.g. Sunday Best, Drover's Rig"))}" value="${esc(n.outfitName)}" data-field="npcoutfit">
              </div>
              <div class="ib-row tl-actions">
                <button type="button" class="ib-btn ib-btn--primary ib-grow" data-act="npccut"${count >= c.min && count <= c.max && !n.busy ? '' : ' disabled'}>${esc(t('ui_npc_cut_outfit', 'Cut outfit (%d of min %d)', count, c.min))}</button>
                <button type="button" class="ib-btn ib-btn--ghost ib-btn--danger" data-act="npcclear"${count ? '' : ' disabled'}>${esc(t('ui_clear', 'Clear'))}</button>
              </div>`;
        },
        async show(p, focus) {
            const res = await act('npcShow', { id: p.id, v: p.v, focus: focus !== false });
            if (!S) return false;
            if (!res || !res.ok) { msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad'); return false; }
            if (res.view) S.view = res.view;
            p.gcat = res.gcat || p.gcat;
            // one piece per body slot: a new hat replaces the pinned hat
            const clash = S.npc.pinned.filter((o) => o !== p && o.gcat && o.gcat === p.gcat);
            for (const o of clash) {
                S.npc.pinned = S.npc.pinned.filter((x) => x !== o);
                await act('npcRemove', { id: o.id });
                msg(t('ui_npc_replaced', '"%s" replaced "%s" (same place on the body).', p.name, o.name), 'warn');
            }
            return true;
        },
        async cut(mode, pieces, name) {
            const n = S.npc;
            n.busy = true;
            Designer.refresh();
            msg(t('ui_cutting', 'Cutting and stitching...'), '');
            const res = await act('npcCut', { mode, name, pieces });
            if (!S) return;
            n.busy = false;
            if (res && res.ok) {
                if (res.pockets) S.data.pockets = res.pockets;
                Designer.refresh();
                msg(t('ui_cut_done', '"%s" is finished (%s) and in your pockets.', mode === 'outfit' ? name : pieces[0].name, res.quality || ''), 'ok');
            } else {
                Designer.refresh();
                msg((res && res.error) || t('ui_cut_failed', 'The outfit could not be finished.'), 'bad');
            }
        },
        async click(btn) {
            const a = btn.dataset.act;
            const n = S.npc;
            const el = btn.closest('[data-npc]');
            const id = el && el.dataset.npc;
            const p = id && Npc.pin(id);
            if (a === 'npcpage') { n.page = Math.max(1, Math.min(n.pages, n.page + Number(btn.dataset.d))); return Npc.load(); }
            if (a === 'npcpin') {
                const r = (n.rows || []).find((x) => x.id === id);
                if (!r || p) return;
                if (n.pinned.length >= Npc.cfg().max) return msg(t('ui_npc_max', 'An outfit takes at most %d pieces.', Npc.cfg().max), 'bad');
                const pin = { id: r.id, label: r.label, name: r.label, v: 1, vars: Number(r.vars) || 1, vlabels: r.vlabels || [], materials: r.materials || [], gcat: null };
                n.pinned.push(pin);
                Designer.refresh();
                if (!(await Npc.show(pin, true)) && S) n.pinned = n.pinned.filter((x) => x !== pin);
                return S && Designer.refresh();
            }
            if (a === 'npcunpin') {
                if (!p) return;
                n.pinned = n.pinned.filter((x) => x !== p);
                Designer.refresh();
                return act('npcRemove', { id: p.id });
            }
            if (a === 'npcv') {
                if (!p || p.vars < 2) return;
                let v = p.v + Number(btn.dataset.d);
                if (v < 1) v = p.vars;
                if (v > p.vars) v = 1;
                p.v = v;
                Designer.refresh();
                return throttle(`npcv:${p.id}`, 120, () => Npc.show(p, true).then(() => S && Designer.refresh()));
            }
            if (a === 'npclook') { if (p) { await Npc.show(p, true); if (S) Designer.refresh(); } return; }
            if (a === 'npccutone') {
                if (!p) return;
                if (String(p.name || '').trim().length < 2) return msg(t('ui_npc_name_first', 'Give every piece a proper name first.'), 'bad');
                return Npc.cut('garment', [{ id: p.id, v: p.v, name: p.name }]);
            }
            if (a === 'npccut') {
                const c = Npc.cfg();
                if (n.pinned.length < c.min) return msg(t('ui_npc_min', 'An outfit needs at least %d pieces.', c.min), 'bad');
                if (n.pinned.some((x) => String(x.name || '').trim().length < 2)) return msg(t('ui_npc_name_first', 'Give every piece a proper name first.'), 'bad');
                if (String(n.outfitName || '').trim().length < 2) return msg(t('ui_name_first', 'Give the outfit a proper name first.'), 'bad');
                return Npc.cut('outfit', n.pinned.map((x) => ({ id: x.id, v: x.v, name: x.name })), n.outfitName);
            }
            if (a === 'npcclear') {
                if (btn.dataset.confirm !== '1') { btn.dataset.confirm = '1'; btn.textContent = t('ui_sure', 'Sure?'); setTimeout(() => { if (btn.isConnected) { btn.dataset.confirm = ''; btn.textContent = t('ui_clear', 'Clear'); } }, 3000); return; }
                const old = n.pinned;
                n.pinned = [];
                Designer.refresh();
                for (const o of old) await act('npcRemove', { id: o.id });
            }
        },
        input(el) {
            const f = el.dataset.field;
            const n = S.npc;
            if (f === 'npcq') { n.q = el.value; n.page = 1; return throttle('npcq', 400, () => Npc.load()); }
            if (f === 'npcoutfit') { n.outfitName = el.value; return; }
            if (f === 'npcname') {
                const holder = el.closest('[data-npc]');
                const p = holder && Npc.pin(holder.dataset.npc);
                if (p) p.name = el.value;
            }
        },
        change(el) {
            const f = el.dataset.field;
            const n = S.npc;
            if (f === 'npccat') { n.cat = el.value; n.page = 1; return Npc.load(); }
            if (f === 'npcv') {
                const holder = el.closest('[data-npc]');
                const p = holder && Npc.pin(holder.dataset.npc);
                if (!p) return;
                p.v = clampInt(el.value, 1, p.vars);
                Designer.refresh();
                Npc.show(p, true).then(() => S && Designer.refresh());
            }
        },
    };

    const Designer = {
        docked: true,
        init(data) {
            const st = { data, sex: data.sex === 'female' ? 'female' : 'male', group: 'Head', view: 'full', pieces: {}, tintOpen: null, busy: false, name: '' , npc: Npc.fresh() };
            const has = (g) => Designer.cats(st).some((c) => c.group === g);
            if (!has(st.group)) { const g = GROUPS.find(([k]) => has(k)); if (g) st.group = g[0]; }
            return st;
        },
        cats(st) {
            const s = st || S;
            const avail = (s.data.catalogue && s.data.catalogue[s.sex]) || {};
            return (s.data.categories || []).filter((c) => avail[c.id]);
        },
        info(id) { return ((S.data.catalogue || {})[S.sex] || {})[id] || { variants: [], titles: [] }; },
        def(id) { return (S.data.categories || []).find((c) => c.id === id); },
        label(item) { return (S.data.itemLabels && S.data.itemLabels[item]) || item; },
        materials() {
            const need = {};
            Object.keys(S.pieces).forEach((id) => {
                const c = Designer.def(id);
                ((c && c.materials) || []).forEach((m) => { need[m.item] = (need[m.item] || 0) + Number(m.amount || 0); });
            });
            return need;
        },
        render() {
            const d = S.data;
            const sexLabels = d.sexLabels || { male: "Gentleman's", female: "Lady's" };
            const pinned = Object.keys(S.pieces).length;
            return `
              <div class="tl-plate">
                <div class="ib-accent"></div>
                ${head(`${d.townLabel ? `${d.townLabel} · ` : ''}${d.businessLabel || 'Tailor'}`, t('ui_designer', 'Outfit Designer'), t('ui_made_to_measure', 'Made to measure'))}
                <div class="tl-bar">
                  <div class="ib-chips">
                    ${['male', 'female'].map((s) => `<button type="button" class="ib-chip${S.sex === s ? ' is-active' : ''}" data-act="sex" data-sex="${s}">${esc(sexLabels[s] || s)}</button>`).join('')}
                  </div>
                  ${viewBar(S)}
                </div>
                <div class="ib-chips tl-groups">
                  ${GROUPS.map(([g, key, l]) => {
                      const list = Designer.cats().filter((c) => c.group === g);
                      if (!list.length) return '';
                      const n = list.filter((c) => S.pieces[c.id]).length;
                      return `<button type="button" class="ib-chip${S.group === g ? ' is-active' : ''}" data-act="group" data-group="${g}">${esc(t(key, l))}${n ? ` <span class="ib-chip__count">${n}</span>` : ''}</button>`;
                  }).join('')}
                  ${d.npc ? `<button type="button" class="ib-chip${S.group === 'NPC' ? ' is-active' : ''}" data-act="group" data-group="NPC">${esc(t('ui_grp_npc', 'NPC clothing'))}${S.npc.pinned.length ? ` <span class="ib-chip__count">${S.npc.pinned.length}</span>` : ''}</button>` : ''}
                </div>
                <div class="tl-list ib-scroll">${S.group === 'NPC' ? Npc.renderList() : Designer.renderCats()}</div>
                <footer class="tl-foot">
                  ${S.group === 'NPC' ? Npc.renderFoot() : `
                  ${Designer.renderMaterials()}
                  <div class="ib-field">
                    <label class="ib-label" for="tlName">${esc(t('ui_name_outfit', 'Name the outfit'))}</label>
                    <input id="tlName" class="ib-input" type="text" maxlength="${Number(d.nameMax) || 40}" placeholder="${esc(t('ui_name_ph', "e.g. Sunday Best, Drover's Rig"))}" value="${esc(S.name || '')}" data-field="name">
                  </div>
                  <div class="ib-row tl-actions">
                    <button type="button" class="ib-btn ib-btn--primary ib-grow" data-act="cut"${pinned && !S.busy ? '' : ' disabled'}>${esc(t('ui_cut', 'Cut & stitch (%d)', pinned))}</button>
                    <button type="button" class="ib-btn" data-act="save"${pinned ? '' : ' disabled'}>${esc(t('ui_save_pattern', 'Save pattern'))}</button>
                    <button type="button" class="ib-btn ib-btn--ghost ib-btn--danger" data-act="clear"${pinned ? '' : ' disabled'}>${esc(t('ui_clear', 'Clear'))}</button>
                  </div>
                  ${Designer.renderPatterns()}
                  `}
                  <p class="ib-msg tl-msg" data-msg></p>
                </footer>
              </div>`;
        },
        renderCats() {
            const list = Designer.cats().filter((c) => c.group === S.group);
            if (!list.length) return `<div class="ib-empty">${esc(t('ui_nothing_here', 'Nothing in this section for this figure.'))}</div>`;
            return list.map((c) => {
                const info = Designer.info(c.id);
                const styles = info.variants.length;
                const p = S.pieces[c.id];
                const m = p ? p.m : 0;
                const colours = m ? (info.variants[m - 1] || 1) : 0;
                const title = m && info.titles && info.titles[m - 1] ? ` · "${esc(info.titles[m - 1])}"` : '';
                const mats = (c.materials || []).map((x) => `${x.amount} ${esc(Designer.label(x.item))}`).join(', ');
                const open = S.tintOpen === c.id && p;
                return `
                  <div class="tl-cat${p ? ' is-on' : ''}" data-cat="${esc(c.id)}">
                    <div class="tl-cat__head">
                      <span class="tl-cat__name">${esc(c.label)}${c.keep ? ` <span class="ib-faint">(${esc(t('ui_optional', 'optional'))})</span>` : ''}</span>
                      <span class="tl-cat__sel">${m ? esc(t('ui_style_of', 'Style %d of %d', m, styles)) + title : `<span class="ib-faint">${esc(t('ui_none_styles', 'None · %d styles', styles))}</span>`}</span>
                    </div>
                    <div class="tl-cat__ctrl">
                      <span class="tl-ctl-label">${esc(t('ui_style', 'Style'))}</span>
                      <div class="ib-stepper">
                        <button type="button" data-act="m" data-d="-1">&#x2039;</button>
                        <input type="number" min="0" max="${styles}" value="${m}" data-field="m">
                        <button type="button" data-act="m" data-d="1">&#x203A;</button>
                      </div>
                      <span class="tl-ctl-label">${esc(t('ui_colour', 'Colour'))}</span>
                      <div class="ib-stepper">
                        <button type="button" data-act="v" data-d="-1"${m ? '' : ' disabled'}>&#x2039;</button>
                        <input type="number" min="1" max="${colours || 1}" value="${m ? p.v : 0}" data-field="v"${m ? '' : ' disabled'}>
                        <button type="button" data-act="v" data-d="1"${m ? '' : ' disabled'}>&#x203A;</button>
                      </div>
                      <button type="button" class="ib-btn ib-btn--sm${open ? ' ib-btn--primary' : ' ib-btn--ghost'}" data-act="tint"${m ? '' : ' disabled'}>${esc(t('ui_dye', 'Dye'))}</button>
                      <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="none"${m ? '' : ' disabled'}>&#x2715;</button>
                    </div>
                    ${open ? Designer.renderTint(p) : ''}
                    <div class="tl-cat__mats ib-faint">${mats}</div>
                  </div>`;
            }).join('');
        },
        renderTint(p) {
            const pal = S.data.palettes || [];
            const slider = (k, key, l) => `
              <label class="tl-tint__row"><span>${esc(t(key, l))}</span>
                <input type="range" min="0" max="254" value="${Number(p[k]) || 0}" data-field="${k}"${p.p ? '' : ' disabled'}>
                <span class="ib-mono tl-tint__val">${Number(p[k]) || 0}</span></label>`;
            return `
              <div class="tl-tint ib-card ib-card--inset">
                <label class="ib-field"><span class="ib-label">${esc(t('ui_dye_lot', 'Dye lot'))}</span>
                  <select class="ib-select" data-field="p">
                    <option value="0"${p.p ? '' : ' selected'}>${esc(t('ui_undyed', 'As woven (no dye)'))}</option>
                    ${pal.map((x) => `<option value="${x.hash}"${Number(p.p) === Number(x.hash) ? ' selected' : ''}>${esc(x.label)}</option>`).join('')}
                  </select></label>
                ${slider('t0', 'ui_primary', 'Primary')}${slider('t1', 'ui_secondary', 'Secondary')}${slider('t2', 'ui_trim', 'Trim')}
              </div>`;
        },
        renderMaterials() {
            const need = Designer.materials();
            const keys = Object.keys(need).sort();
            if (!keys.length) return `<div class="ib-hint">${esc(t('ui_mats_hint', 'Pin garments on the dummy; the cloth and notions they take are listed here.'))}</div>`;
            const pockets = S.data.pockets || {};
            return `<div class="tl-mats"><div class="ib-label">${esc(t('ui_mats', 'Materials for this outfit'))}</div><div class="tl-mats__grid">${keys.map((k) => {
                const have = Number(pockets[k] || 0);
                return `<span class="tl-mat${have >= need[k] ? '' : ' is-short'}"><span>${esc(Designer.label(k))}</span><b class="ib-mono">${have}/${need[k]}</b></span>`;
            }).join('')}</div></div>`;
        },
        renderPatterns() {
            const list = S.data.patterns || [];
            if (!S.data.businessId) return '';
            if (!list.length) return `<div class="ib-hint">${esc(t('ui_book_empty', 'The pattern book is empty. Save a design to cut it again later.'))}</div>`;
            const sexLabels = S.data.sexLabels || {};
            return `
              <div class="ib-row ib-row--nowrap tl-patterns">
                <select class="ib-select ib-grow" data-field="pattern">
                  ${list.map((p) => `<option value="${p.id}">${esc(p.name)} · ${esc(sexLabels[p.sex] || p.sex)} · ${p.count}</option>`).join('')}
                </select>
                <button type="button" class="ib-btn ib-btn--sm" data-act="pload">${esc(t('ui_dress_dummy', 'Dress dummy'))}</button>
                <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="pdel">${esc(t('ui_strike', 'Strike'))}</button>
              </div>`;
        },
        sendPiece(id) {
            const p = S.pieces[id];
            throttle(`set:${id}`, 90, () => act('set', { c: id, m: p ? p.m : 0, v: p ? p.v : 1 }));
        },
        sendTint(id) {
            const p = S.pieces[id];
            if (!p) return;
            throttle(`tint:${id}`, 120, () => act('tint', { c: id, p: Number(p.p) || 0, t0: p.t0, t1: p.t1, t2: p.t2 }));
        },
        setStyle(id, m) {
            const n = Designer.info(id).variants.length;
            if (m < 0) m = n;
            if (m > n) m = 0;
            if (m === 0) { delete S.pieces[id]; if (S.tintOpen === id) S.tintOpen = null; }
            else S.pieces[id] = Object.assign({ p: 0, t0: 0, t1: 0, t2: 0 }, S.pieces[id] || {}, { m, v: 1 });
            Designer.sendPiece(id);
            Designer.refresh();
        },
        setColour(id, v) {
            const p = S.pieces[id];
            if (!p) return;
            const n = Designer.info(id).variants[p.m - 1] || 1;
            if (v < 1) v = n;
            if (v > n) v = 1;
            p.v = v;
            Designer.sendPiece(id);
            Designer.refresh();
        },
        refresh() {
            const nameEl = root.querySelector('[data-field="name"]');
            if (nameEl) S.name = nameEl.value;
            render();
        },
        async click(btn) {
            const a = btn.dataset.act;
            const catEl = btn.closest('[data-cat]');
            const id = catEl && catEl.dataset.cat;
            if (a.startsWith('npc')) return Npc.click(btn);
            if (a === 'group') { S.group = btn.dataset.group; S.tintOpen = null; if (S.group === 'NPC' && !S.npc.rows) Npc.load(); return Designer.refresh(); }
            if (a === 'view') { S.view = btn.dataset.view; act('view', { view: S.view }); return Designer.refresh(); }
            if (a === 'rotate') return act('rotate', { dir: Number(btn.dataset.dir) || 1 });
            if (a === 'sex') {
                const sex = btn.dataset.sex;
                if (sex === S.sex) return;
                if (Object.keys(S.pieces).length && btn.dataset.confirm !== '1') {
                    btn.dataset.confirm = '1';
                    msg(t('ui_sex_confirm', 'Changing the figure unpins every garment. Click again to change.'), 'warn');
                    setTimeout(() => { if (btn.isConnected) btn.dataset.confirm = ''; }, 3000);
                    return;
                }
                S.sex = sex; S.pieces = {}; S.tintOpen = null; S.npc = Npc.fresh();
                if (S.group !== 'NPC' && !Designer.cats().some((c) => c.group === S.group)) S.group = GROUPS[0][0];
                Designer.refresh();
                await act('sex', { sex });
                if (S && S.group === 'NPC') Npc.load();
                return;
            }
            if (a === 'm') return Designer.setStyle(id, ((S.pieces[id] && S.pieces[id].m) || 0) + Number(btn.dataset.d));
            if (a === 'v') return Designer.setColour(id, ((S.pieces[id] && S.pieces[id].v) || 1) + Number(btn.dataset.d));
            if (a === 'none') return Designer.setStyle(id, 0);
            if (a === 'tint') { S.tintOpen = S.tintOpen === id ? null : id; return Designer.refresh(); }
            if (a === 'clear') {
                if (btn.dataset.confirm !== '1') { btn.dataset.confirm = '1'; btn.textContent = t('ui_sure', 'Sure?'); setTimeout(() => { if (btn.isConnected) { btn.dataset.confirm = ''; btn.textContent = t('ui_clear', 'Clear'); } }, 3000); return; }
                S.pieces = {}; S.tintOpen = null;
                Designer.refresh();
                return act('clear', {});
            }
            if (a === 'cut') {
                const name = (root.querySelector('[data-field="name"]') || {}).value || '';
                if (name.trim().length < 2) return msg(t('ui_name_first', 'Give the outfit a proper name first.'), 'bad');
                S.name = name; S.busy = true;
                Designer.refresh();
                msg(t('ui_cutting', 'Cutting and stitching...'), '');
                const res = await act('cut', { name });
                if (!S) return;
                S.busy = false;
                if (res && res.ok) {
                    if (res.pockets) S.data.pockets = res.pockets;
                    Designer.refresh();
                    msg(t('ui_cut_done', '"%s" is finished (%s) and in your pockets.', name, res.quality || ''), 'ok');
                } else {
                    Designer.refresh();
                    msg((res && res.error) || t('ui_cut_failed', 'The outfit could not be finished.'), 'bad');
                }
                return;
            }
            if (a === 'save') {
                const name = (root.querySelector('[data-field="name"]') || {}).value || '';
                if (name.trim().length < 2) return msg(t('ui_name_book', 'Name the design before you enter it in the book.'), 'bad');
                S.name = name;
                const res = await act('patternSave', { name });
                if (res && res.ok) { S.data.patterns = res.patterns || S.data.patterns; Designer.refresh(); msg(res.message, 'ok'); }
                else msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad');
                return;
            }
            if (a === 'pload' || a === 'pdel') {
                const sel = root.querySelector('[data-field="pattern"]');
                const pid = sel && Number(sel.value);
                if (!pid) return;
                if (a === 'pdel') {
                    if (btn.dataset.confirm !== '1') { btn.dataset.confirm = '1'; btn.textContent = t('ui_sure', 'Sure?'); setTimeout(() => { if (btn.isConnected) { btn.dataset.confirm = ''; btn.textContent = t('ui_strike', 'Strike'); } }, 3000); return; }
                    const res = await act('patternDelete', { id: pid });
                    if (res && res.ok) { S.data.patterns = res.patterns || []; Designer.refresh(); msg(res.message, 'ok'); }
                    else msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad');
                    return;
                }
                const res = await act('patternLoad', { id: pid });
                if (res && res.ok) {
                    S.sex = res.sex || S.sex;
                    S.pieces = {};
                    (res.pieces || []).forEach((p) => {
                        const tt = Array.isArray(p.t) ? p.t : [];
                        S.pieces[p.c] = { m: Number(p.m), v: Number(p.v), p: Number(p.p) || 0, t0: Number(tt[0]) || 0, t1: Number(tt[1]) || 0, t2: Number(tt[2]) || 0 };
                    });
                    S.name = res.name || S.name;
                    S.tintOpen = null;
                    Designer.refresh();
                    msg(t('ui_pattern_pinned', 'Pattern "%s" pinned on the dummy.', res.name || ''), 'ok');
                } else msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad');
            }
        },
        input(el) {
            const f = el.dataset && el.dataset.field;
            if (f && f.startsWith('npc')) return Npc.input(el);
            const catEl = el.closest('[data-cat]');
            const id = catEl && catEl.dataset.cat;
            if (f === 't0' || f === 't1' || f === 't2') {
                const p = S.pieces[id];
                if (!p) return;
                p[f] = clampInt(el.value, 0, 254);
                const val = el.parentElement.querySelector('.tl-tint__val');
                if (val) val.textContent = p[f];
                Designer.sendTint(id);
            }
        },
        change(el) {
            const f = el.dataset && el.dataset.field;
            if (f && f.startsWith('npc')) return Npc.change(el);
            const catEl = el.closest('[data-cat]');
            const id = catEl && catEl.dataset.cat;
            if (f === 'm') return Designer.setStyle(id, clampInt(el.value, 0, Designer.info(id).variants.length));
            if (f === 'v') return Designer.setColour(id, clampInt(el.value, 1, 999));
            if (f === 'p') {
                const p = S.pieces[id];
                if (!p) return;
                p.p = Number(el.value) || 0;
                if (!p.p) { p.t0 = 0; p.t1 = 0; p.t2 = 0; }
                Designer.sendTint(id);
                Designer.refresh();
            }
        },
    };

    /* ================================================================== sewing */
    const Sew = {
        docked: false,
        init(data) {
            const amounts = {};
            (data.recipes || []).forEach((r) => { amounts[r.id] = 1; });
            return { data, amounts, busy: false };
        },
        label(item) { return (S.data.itemLabels && S.data.itemLabels[item]) || item; },
        render() {
            const d = S.data;
            const pockets = d.pockets || {};
            return `
              <div class="tl-plate">
                <div class="ib-accent"></div>
                ${head(d.businessLabel || 'Tailor', t('ui_sew_title', 'Cloth & Notions'), t('ui_sew_rule', 'Sewn at the cutting table'))}
                <div class="tl-body ib-scroll">
                  <p class="ib-intro">${esc(t('ui_sew_intro', 'Each batch is a short piece of needlework. Miss every stitch and the batch comes out half as big.'))}</p>
                  <div class="tl-recipes">
                    ${(d.recipes || []).map((r) => {
                        const n = S.amounts[r.id] || 1;
                        const ok = r.required.every((m) => Number(pockets[m.item] || 0) >= m.amount * n);
                        return `
                          <div class="ib-card tl-recipe" data-recipe="${esc(r.id)}">
                            <div class="ib-card__title">${esc(r.label)}</div>
                            <div class="ib-card__meta">${esc(t('ui_makes', 'Makes %d %s', r.amount * n, Sew.label(r.receive)))}</div>
                            <div class="tl-mats__grid">
                              ${r.required.map((m) => {
                                  const have = Number(pockets[m.item] || 0);
                                  return `<span class="tl-mat${have >= m.amount * n ? '' : ' is-short'}"><span>${esc(Sew.label(m.item))}</span><b class="ib-mono">${have}/${m.amount * n}</b></span>`;
                              }).join('')}
                            </div>
                            <div class="ib-row tl-recipe__act">
                              <div class="ib-stepper">
                                <button type="button" data-act="amt" data-d="-1">&#x2039;</button>
                                <input type="number" min="1" max="${d.maxBatch || 10}" value="${n}" data-field="amt">
                                <button type="button" data-act="amt" data-d="1">&#x203A;</button>
                              </div>
                              <button type="button" class="ib-btn ib-btn--primary ib-grow" data-act="craft"${ok && !S.busy ? '' : ' disabled'}>${esc(t('ui_sew', 'Sew'))}</button>
                            </div>
                          </div>`;
                    }).join('')}
                  </div>
                  <p class="ib-msg tl-msg" data-msg></p>
                </div>
              </div>`;
        },
        async click(btn) {
            const card = btn.closest('[data-recipe]');
            const id = card && card.dataset.recipe;
            if (!id) return;
            const max = S.data.maxBatch || 10;
            if (btn.dataset.act === 'amt') { S.amounts[id] = clampInt((S.amounts[id] || 1) + Number(btn.dataset.d), 1, max); return render(); }
            if (btn.dataset.act === 'craft') {
                S.busy = true;
                render();
                const res = await act('craft', { recipe: id, amount: S.amounts[id] || 1 });
                if (!S) return;
                S.busy = false;
                if (res && res.ok) { if (res.pockets) S.data.pockets = res.pockets; render(); msg(t('ui_sew_done', 'Done: %d made.', res.made || 0), 'ok'); }
                else { render(); msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad'); }
            }
        },
        change(el) {
            const card = el.closest('[data-recipe]');
            if (card && el.dataset.field === 'amt') { S.amounts[card.dataset.recipe] = clampInt(el.value, 1, S.data.maxBatch || 10); render(); }
        },
    };

    /* ================================================================== counter */
    const Counter = {
        docked: false,
        init(data) { return { data, tab: 'shelf', qty: {}, busy: false }; },
        update(data) { S.data = data; },
        tabs() {
            const d = S.data;
            const list = [['shelf', t('ui_tab_shelf', 'For sale')]];
            if (d.ordersEnabled) list.push(['order', t('ui_tab_order', 'Order made to measure')]);
            if (d.staff) {
                list.push(['stock', t('ui_tab_stock', 'Stock the shelf')]);
                if (d.ordersEnabled) list.push(['orders', t('ui_tab_orders', 'Order book (%d)', (d.orders || []).length)]);
            }
            return list;
        },
        render() {
            const d = S.data;
            const body = { shelf: Counter.shelf, order: Counter.order, stock: Counter.stock, orders: Counter.orders }[S.tab] || Counter.shelf;
            return `
              <div class="tl-plate">
                <div class="ib-accent"></div>
                ${head(d.town || '', d.businessLabel || 'Tailor', t('ui_counter_rule', "Tailor's counter"))}
                <div class="tl-bar">
                  <div class="ib-chips">${Counter.tabs().map(([k, l]) => `<button type="button" class="ib-chip${S.tab === k ? ' is-active' : ''}" data-act="tab" data-tab="${k}">${esc(l)}</button>`).join('')}</div>
                  <span class="ib-badge ib-badge--muted">${esc(t('ui_cash', 'Cash %s', money(d.cash)))}</span>
                </div>
                <div class="tl-body ib-scroll">${body()}</div>
                <footer class="tl-foot"><p class="ib-msg tl-msg" data-msg></p></footer>
              </div>`;
        },
        shelf() {
            const d = S.data;
            const lines = d.lines || [];
            if (!lines.length) return `<div class="ib-empty">${esc(t('ui_shelf_empty', 'Nothing on the shelf right now. Leave an order and the tailor will make it.'))}</div>`;
            return `<div class="ib-list">${lines.map((l) => {
                const q = S.qty[l.id] || 1;
                return `
                  <div class="ib-item tl-line" data-line="${l.id}">
                    <div class="ib-grow">
                      <div class="ib-item__name">${esc(l.label)}</div>
                      <div class="ib-item__sub">${[l.quality, l.maker ? t('ui_by', 'by %s', l.maker) : '', l.sex ? (l.sex === 'female' ? t('ui_ladies', "Lady's") : t('ui_gents', "Gentleman's")) : '', l.unique ? '' : t('ui_left', '%d left', l.qty)].filter(Boolean).map(esc).join(' · ')}</div>
                      ${l.description ? `<div class="ib-item__sub tl-desc">${esc(l.description)}</div>` : ''}
                    </div>
                    <span class="ib-item__price">${money(l.price)}</span>
                    ${l.unique ? '' : `<div class="ib-stepper"><button type="button" data-act="q" data-d="-1">&#x2039;</button><input type="number" min="1" max="${Math.min(l.qty, 100)}" value="${q}" data-field="q"><button type="button" data-act="q" data-d="1">&#x203A;</button></div>`}
                    <button type="button" class="ib-btn ib-btn--primary ib-btn--sm" data-act="buy"${S.busy ? ' disabled' : ''}>${esc(t('ui_buy', 'Buy'))}</button>
                    ${d.staff ? `<input class="ib-input ib-input--sm" type="number" step="0.05" min="${d.minPrice}" max="${d.maxPrice}" value="${l.price}" data-field="reprice" data-keep="rp${l.id}">
                      <button type="button" class="ib-btn ib-btn--sm" data-act="reprice">${esc(t('ui_set_price', 'Price'))}</button>
                      <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="unstock">${esc(t('ui_take_back', 'Take back'))}</button>` : ''}
                  </div>`;
            }).join('')}</div>`;
        },
        order() {
            const d = S.data;
            const mine = d.mine || [];
            return `
              <div class="ib-card">
                <div class="ib-card__title">${esc(t('ui_order_title', 'Leave an order with the tailor'))}</div>
                <p class="ib-intro">${esc(t('ui_order_intro', 'Describe what you would like made: garments, colours, the occasion. The tailor writes back when it is ready to collect here.'))}</p>
                <div class="ib-row">
                  <select class="ib-select" data-field="osex" data-keep="osex">
                    <option value="male"${d.sex === 'male' ? ' selected' : ''}>${esc(t('ui_gents', "Gentleman's"))}</option>
                    <option value="female"${d.sex === 'female' ? ' selected' : ''}>${esc(t('ui_ladies', "Lady's"))}</option>
                  </select>
                </div>
                <textarea class="ib-input tl-textarea" maxlength="${d.textMax || 300}" data-field="otext" data-keep="otext" placeholder="${esc(t('ui_order_ph', 'A brown three-piece suit with a bowler hat, for church on Sunday.'))}"></textarea>
                <div class="ib-row"><button type="button" class="ib-btn ib-btn--primary" data-act="oplace">${esc(t('ui_order_place', 'Leave the order'))}</button></div>
              </div>
              <div class="ib-section-title">${esc(t('ui_my_orders', 'Your orders here'))}</div>
              ${mine.length ? `<div class="ib-list">${mine.map((o) => `
                <div class="ib-item" data-order="${o.id}">
                  <span class="ib-dot ib-dot--${o.status === 'done' ? 'ok' : (o.status === 'declined' || o.status === 'cancelled') ? 'bad' : 'warn'}"></span>
                  <div class="ib-grow"><div class="tl-order__text">${esc(o.request)}</div><div class="ib-item__sub">${esc(Counter.status(o.status))}${o.handledBy ? ` · ${esc(o.handledBy)}` : ''}</div></div>
                  ${(o.status === 'open' || o.status === 'accepted') ? `<button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="ocancel">${esc(t('ui_cancel', 'Withdraw'))}</button>` : ''}
                </div>`).join('')}</div>` : `<div class="ib-hint">${esc(t('ui_no_orders', 'No orders yet.'))}</div>`}`;
        },
        status(s) {
            return { open: t('ui_st_open', 'Waiting'), accepted: t('ui_st_accepted', 'Being made'), done: t('ui_st_done', 'Ready to collect'),
                declined: t('ui_st_declined', 'Declined'), cancelled: t('ui_st_cancelled', 'Withdrawn') }[s] || s;
        },
        stock() {
            const list = S.data.pockets || [];
            if (!list.length) return `<div class="ib-empty">${esc(t('ui_nothing_to_stock', 'You carry nothing the counter sells (outfits, clothing, cloth).'))}</div>`;
            return `<p class="ib-intro">${esc(t('ui_stock_intro', 'Put garments from your pockets on the shelf. Sales go into the shop till.'))}</p>
              <div class="ib-list">${list.map((it) => `
                <div class="ib-item" data-item="${esc(it.id)}" data-name="${esc(it.name)}">
                  <div class="ib-grow"><div class="ib-item__name">${esc(it.label)}</div><div class="ib-item__sub">${[it.quality, it.plain ? t('ui_carrying', 'carrying %d', it.count) : t('ui_one_off', 'one of a kind')].filter(Boolean).map(esc).join(' · ')}</div></div>
                  ${it.plain ? `<input class="ib-input ib-input--sm" type="number" min="1" max="${it.count}" value="${it.count}" data-field="sqty" data-keep="sq${esc(it.id)}">` : ''}
                  <span class="ib-faint">$</span><input class="ib-input ib-input--sm" type="number" step="0.05" min="${S.data.minPrice}" max="${S.data.maxPrice}" value="${Number(it.suggest || 1).toFixed(2)}" data-field="sprice" data-keep="sp${esc(it.id)}">
                  <button type="button" class="ib-btn ib-btn--sm ib-btn--primary" data-act="stock">${esc(t('ui_put_on_shelf', 'Put on shelf'))}</button>
                </div>`).join('')}</div>`;
        },
        orders() {
            const list = S.data.orders || [];
            if (!list.length) return `<div class="ib-empty">${esc(t('ui_book_clear', 'No open orders.'))}</div>`;
            return `<div class="ib-list">${list.map((o) => `
                <div class="ib-item tl-order" data-order="${o.id}">
                  <div class="ib-grow">
                    <div class="ib-item__name">${esc(o.customer)} · ${esc(o.sex === 'female' ? t('ui_ladies', "Lady's") : t('ui_gents', "Gentleman's"))}</div>
                    <div class="tl-order__text">${esc(o.request)}</div>
                    <div class="ib-item__sub">${esc(Counter.status(o.status))}${o.handledBy ? ` · ${esc(o.handledBy)}` : ''}</div>
                  </div>
                  ${o.status === 'open' ? `<button type="button" class="ib-btn ib-btn--sm" data-act="oset" data-status="accepted">${esc(t('ui_accept', 'Take it on'))}</button>` : ''}
                  <button type="button" class="ib-btn ib-btn--sm ib-btn--primary" data-act="oset" data-status="done">${esc(t('ui_ready', 'Ready'))}</button>
                  <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="oset" data-status="declined">${esc(t('ui_decline', 'Decline'))}</button>
                </div>`).join('')}</div>`;
        },
        async run(name, data) {
            S.busy = true;
            const res = await act(name, data);
            if (!S) return res;
            S.busy = false;
            if (res && res.ok && res.payload) S.data = res.payload;
            render();
            if (res && !res.ok) msg(res.error || t('ui_failed', 'That did not work.'), 'bad');
            return res;
        },
        async click(btn) {
            const a = btn.dataset.act;
            if (a === 'tab') { S.tab = btn.dataset.tab; return render(); }
            const line = btn.closest('[data-line]');
            const lid = line && Number(line.dataset.line);
            if (a === 'q' && lid) {
                const l = (S.data.lines || []).find((x) => x.id === lid);
                S.qty[lid] = clampInt((S.qty[lid] || 1) + Number(btn.dataset.d), 1, Math.min(100, l ? l.qty : 1));
                return render();
            }
            if (a === 'buy' && lid) {
                const res = await Counter.run('buy', { lineId: lid, qty: S.qty[lid] || 1 });
                if (res && res.ok) msg(t('ui_bought', 'Bought. It is in your pockets.'), 'ok');
                return;
            }
            if (a === 'reprice' && lid) {
                const v = Number((line.querySelector('[data-field="reprice"]') || {}).value);
                const res = await Counter.run('reprice', { lineId: lid, price: v });
                if (res && res.ok) msg(t('ui_repriced', 'Price changed.'), 'ok');
                return;
            }
            if (a === 'unstock' && lid) { await Counter.run('unstock', { lineId: lid }); return; }
            if (a === 'stock') {
                const row = btn.closest('[data-item]');
                const qty = Number((row.querySelector('[data-field="sqty"]') || {}).value || 1);
                const price = Number((row.querySelector('[data-field="sprice"]') || {}).value);
                const res = await Counter.run('stock', { itemId: row.dataset.item, name: row.dataset.name, qty, price });
                if (res && res.ok) msg(t('ui_stocked', 'On the shelf.'), 'ok');
                return;
            }
            if (a === 'oplace') {
                const text = (root.querySelector('[data-field="otext"]') || {}).value || '';
                const sex = (root.querySelector('[data-field="osex"]') || {}).value || 'male';
                if (text.trim().length < 5) return msg(t('ui_order_short', 'Write a little more about what you want.'), 'bad');
                const res = await Counter.run('orderPlace', { request: text, sex });
                if (res && res.ok) { const ta = root.querySelector('[data-field="otext"]'); if (ta) ta.value = ''; msg(t('ui_order_left', 'Order left with the tailor.'), 'ok'); }
                return;
            }
            const ord = btn.closest('[data-order]');
            const oid = ord && Number(ord.dataset.order);
            if (a === 'ocancel' && oid) { await Counter.run('orderCancel', { id: oid }); return; }
            if (a === 'oset' && oid) { await Counter.run('orderSet', { id: oid, status: btn.dataset.status }); }
        },
        change(el) {
            const line = el.closest('[data-line]');
            if (line && el.dataset.field === 'q') {
                const l = (S.data.lines || []).find((x) => x.id === Number(line.dataset.line));
                S.qty[Number(line.dataset.line)] = clampInt(el.value, 1, Math.min(100, l ? l.qty : 1));
            }
        },
    };

    /* ================================================================== boss */
    const Boss = {
        docked: false,
        init(data) { return { data }; },
        render() {
            const d = S.data;
            const hist = d.history || [];
            return `
              <div class="tl-plate">
                <div class="ib-accent"></div>
                ${head(d.town || '', d.businessLabel || 'Tailor', t('ui_office', "Proprietor's office"))}
                <div class="tl-body ib-scroll">
                  <div class="ib-stats">
                    <div class="ib-stat"><span class="ib-stat__lbl">${esc(t('ui_till', 'Till'))}</span><span class="ib-stat__val ib-stat__val--silver">${money(d.balance)}</span></div>
                    <div class="ib-stat"><span class="ib-stat__lbl">${esc(t('ui_your_cash', 'Your cash'))}</span><span class="ib-stat__val">${money(d.cash)}</span></div>
                    <div class="ib-stat"><span class="ib-stat__lbl">${esc(t('ui_staff_on', 'Staff about'))}</span><span class="ib-stat__val">${(d.staff || []).length}</span></div>
                  </div>
                  <div class="ib-card tl-till">
                    <div class="ib-card__title">${esc(t('ui_till_title', 'Till'))}</div>
                    <div class="ib-row">
                      <span class="ib-faint">$</span><input class="ib-input" type="number" step="0.05" min="0.05" max="${d.maxTx || 5000}" placeholder="0.00" data-field="amount" data-keep="amount">
                      <button type="button" class="ib-btn ib-btn--primary" data-act="withdraw">${esc(t('ui_withdraw', 'Take out'))}</button>
                      <button type="button" class="ib-btn" data-act="deposit">${esc(t('ui_deposit', 'Pay in'))}</button>
                    </div>
                  </div>
                  <div class="ib-grid-2">
                    <div class="ib-card">
                      <div class="ib-card__title">${esc(t('ui_staff', 'Staff on hand'))}</div>
                      ${(d.staff || []).length ? `<div class="ib-list">${d.staff.map((s) => `
                        <div class="ib-item" data-target="${s.id}">
                          <div class="ib-grow"><div class="ib-item__name">${esc(s.name)}</div><div class="ib-item__sub">${esc(t('ui_grade', 'Grade %d', s.grade))}</div></div>
                          <select class="ib-select ib-select--sm" data-field="grade">${Array.from({ length: Math.max(1, Number(d.bossGrade) || 4) }, (_, g) => `<option value="${g}"${g === s.grade ? ' selected' : ''}>${g}</option>`).join('')}</select>
                          <button type="button" class="ib-btn ib-btn--sm" data-act="grade">${esc(t('ui_set', 'Set'))}</button>
                          <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost ib-btn--danger" data-act="fire">${esc(t('ui_fire', 'Let go'))}</button>
                        </div>`).join('')}</div>` : `<div class="ib-hint">${esc(t('ui_no_staff', 'Nobody from the shop is about.'))}</div>`}
                    </div>
                    <div class="ib-card">
                      <div class="ib-card__title">${esc(t('ui_hire', 'Take someone on'))}</div>
                      ${(d.nearby || []).length ? `<div class="ib-list">${d.nearby.map((s) => `
                        <div class="ib-item" data-target="${s.id}">
                          <div class="ib-grow ib-item__name">${esc(s.name)}</div>
                          <button type="button" class="ib-btn ib-btn--sm ib-btn--primary" data-act="hire">${esc(t('ui_hire_btn', 'Hire'))}</button>
                        </div>`).join('')}</div>` : `<div class="ib-hint">${esc(t('ui_nobody_near', 'Nobody is standing in the office with you.'))}</div>`}
                      <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="refresh">${esc(t('ui_refresh', 'Look again'))}</button>
                    </div>
                  </div>
                  <div class="ib-section-title">${esc(t('ui_book', 'Till book'))}</div>
                  <div class="ib-table-wrap"><table class="ib-table">
                    <thead><tr><th>${esc(t('ui_when', 'When'))}</th><th>${esc(t('ui_what', 'What'))}</th><th>${esc(t('ui_who', 'Who'))}</th><th class="ib-num">${esc(t('ui_amount', 'Amount'))}</th></tr></thead>
                    <tbody>${hist.length ? hist.map((h) => `<tr><td>${esc(new Date(h.at * 1000).toLocaleString())}</td><td>${esc(h.type)}${h.note ? ` · <span class="ib-faint">${esc(h.note)}</span>` : ''}</td><td>${esc(h.by || '')}</td><td class="ib-num">${money(h.amount)}</td></tr>`).join('') : `<tr><td colspan="4" class="ib-faint">${esc(t('ui_book_none', 'Nothing written yet.'))}</td></tr>`}</tbody>
                  </table></div>
                </div>
                <footer class="tl-foot"><p class="ib-msg tl-msg" data-msg></p></footer>
              </div>`;
        },
        async click(btn) {
            const a = btn.dataset.act;
            const row = btn.closest('[data-target]');
            const target = row && Number(row.dataset.target);
            let res;
            if (a === 'withdraw' || a === 'deposit') {
                const amount = Number((root.querySelector('[data-field="amount"]') || {}).value);
                if (!(amount > 0)) return msg(t('ui_amount_first', 'Enter an amount first.'), 'bad');
                res = await act(a, { amount });
            } else if (a === 'hire' || a === 'fire') res = await act(a, { target });
            else if (a === 'grade') res = await act('grade', { target, grade: Number((row.querySelector('[data-field="grade"]') || {}).value) });
            else if (a === 'refresh') res = await act('refresh', {});
            else return;
            if (!S) return;
            if (res && res.ok && res.payload) { S.data = res.payload; render(); msg(t('ui_done', 'Done.'), 'ok'); }
            else msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad');
        },
    };

    /* ================================================================== clothes store */
    const Store = {
        docked: true,
        init(data) {
            const sex = data.sex === 'female' ? 'female' : 'male';
            const st = { data, sex, cat: null, view: 'full', pick: {}, worn: {}, busy: false };
            (data.lines || []).forEach((l) => { st.pick[l.id] = (l.colours[0] || {}).n || 1; });
            st.cat = Store.cats(st)[0] || null;
            return st;
        },
        cats(st) {
            const s = st || S;
            const seen = [];
            (s.data.lines || []).forEach((l) => { if (l.sex === s.sex && !seen.includes(l.cat)) seen.push(l.cat); });
            return seen;
        },
        catLabel(cat) { const l = (S.data.lines || []).find((x) => x.cat === cat); return l ? l.catLabel : cat; },
        render() {
            const d = S.data;
            const sexLabels = d.sexLabels || { male: "Gentleman's", female: "Lady's" };
            const lines = (d.lines || []).filter((l) => l.sex === S.sex && l.cat === S.cat);
            const canTry = S.sex === d.pedSex;
            const worn = Object.keys(S.worn).length;
            return `
              <div class="tl-plate">
                <div class="ib-accent"></div>
                ${head(d.town || '', d.label || 'Clothes Store', t('ui_ready_made', 'Ready-made clothing'))}
                <div class="tl-bar">
                  <div class="ib-chips">${['male', 'female'].map((s) => `<button type="button" class="ib-chip${S.sex === s ? ' is-active' : ''}" data-act="sex" data-sex="${s}">${esc(sexLabels[s] || s)}</button>`).join('')}</div>
                  ${viewBar(S)}
                </div>
                <div class="ib-chips tl-groups">${Store.cats().map((c) => `<button type="button" class="ib-chip${S.cat === c ? ' is-active' : ''}" data-act="cat" data-cat="${esc(c)}">${esc(Store.catLabel(c))}</button>`).join('')}</div>
                ${canTry ? '' : `<div class="ib-hint tl-pad">${esc(t('ui_no_try', 'You can buy these as a gift, but not try them on.'))}</div>`}
                <div class="tl-list ib-scroll">
                  ${lines.length ? lines.map((l) => {
                      const pick = S.pick[l.id];
                      const col = l.colours.find((c) => c.n === pick) || l.colours[0];
                      const on = S.worn[l.cat] === l.id;
                      const soldOut = col && col.left === 0;
                      return `
                        <div class="tl-cat tl-ware${on ? ' is-on' : ''}" data-line="${esc(l.id)}">
                          <div class="tl-cat__head">
                            <span class="tl-cat__name">${esc(l.label)}</span>
                            <span class="ib-item__price">${money(l.price)}</span>
                          </div>
                          <div class="tl-cat__ctrl">
                            <span class="tl-ctl-label">${esc(t('ui_colour', 'Colour'))}</span>
                            <div class="tl-swatches">${l.colours.map((c) => `<button type="button" class="tl-swatch${c.n === pick ? ' is-active' : ''}${c.left === 0 ? ' is-out' : ''}" data-act="colour" data-n="${c.n}" title="${esc(t('ui_colour_n', 'Colour %d', c.n))}">${c.n}</button>`).join('')}</div>
                            <span class="ib-grow"></span>
                            ${canTry ? `<button type="button" class="ib-btn ib-btn--sm${on ? ' ib-btn--primary' : ' ib-btn--ghost'}" data-act="try">${esc(on ? t('ui_trying', 'Trying on') : t('ui_try', 'Try on'))}</button>` : ''}
                            <button type="button" class="ib-btn ib-btn--sm ib-btn--primary" data-act="buy"${S.busy || soldOut ? ' disabled' : ''}>${esc(soldOut ? t('ui_sold_out', 'Sold out') : t('ui_buy', 'Buy'))}</button>
                          </div>
                          ${col && col.left != null ? `<div class="tl-cat__mats ib-faint">${esc(t('ui_left', '%d left', col.left))}</div>` : ''}
                        </div>`;
                  }).join('') : `<div class="ib-empty">${esc(t('ui_store_empty', 'Nothing of this kind for sale here.'))}</div>`}
                </div>
                <footer class="tl-foot">
                  <div class="ib-row ib-row--between">
                    <span class="ib-badge ib-badge--muted">${esc(t('ui_cash', 'Cash %s', money(d.cash)))}</span>
                    <button type="button" class="ib-btn ib-btn--sm ib-btn--ghost" data-act="undress"${worn ? '' : ' disabled'}>${esc(t('ui_take_off', 'Take off what I tried (%d)', worn))}</button>
                  </div>
                  <div class="ib-hint">${esc(d.format === 'multi' ? t('ui_store_hint_multi', 'Bought clothes go into your pockets: put them on from the equipment panel of your inventory.') : t('ui_store_hint_outfit', 'Bought clothes go into your pockets: use the garment to put it on.'))}</div>
                  <p class="ib-msg tl-msg" data-msg></p>
                </footer>
              </div>`;
        },
        async click(btn) {
            const a = btn.dataset.act;
            if (a === 'sex') { S.sex = btn.dataset.sex; S.cat = Store.cats()[0] || null; return render(); }
            if (a === 'cat') { S.cat = btn.dataset.cat; return render(); }
            if (a === 'view') { S.view = btn.dataset.view; act('view', { view: S.view }); return render(); }
            if (a === 'rotate') return act('rotate', { dir: Number(btn.dataset.dir) || 1 });
            if (a === 'undress') { S.worn = {}; render(); return act('unpreview', {}); }
            const row = btn.closest('[data-line]');
            const id = row && row.dataset.line;
            const l = id && (S.data.lines || []).find((x) => x.id === id);
            if (!l) return;
            if (a === 'colour') {
                S.pick[id] = Number(btn.dataset.n);
                render();
                if (S.sex === S.data.pedSex) { S.worn[l.cat] = id; render(); throttle('preview', 120, () => act('preview', { lineId: id, colour: S.pick[id] })); }
                return;
            }
            if (a === 'try') {
                if (S.worn[l.cat] === id) { delete S.worn[l.cat]; render(); return act('unpreview', { cat: l.cat }); }
                S.worn[l.cat] = id;
                render();
                const res = await act('preview', { lineId: id, colour: S.pick[id] });
                if (res && !res.ok && res.error) msg(res.error, 'bad');
                return;
            }
            if (a === 'buy') {
                S.busy = true;
                render();
                const res = await act('buy', { lineId: id, colour: S.pick[id] });
                if (!S) return;
                S.busy = false;
                if (res && res.ok) {
                    if (res.cash != null) S.data.cash = res.cash;
                    const col = l.colours.find((c) => c.n === S.pick[id]);
                    if (col && col.left != null && res.left != null) col.left = res.left;
                    render();
                    msg(t('ui_store_bought', '%s bought for %s.', l.label, money(l.price)), 'ok');
                } else { render(); msg((res && res.error) || t('ui_failed', 'That did not work.'), 'bad'); }
            }
        },
    };

    const Views = { designer: Designer, sew: Sew, counter: Counter, boss: Boss, store: Store };

    /* ================================================================== browser preview (not in game) */
    const Mock = {
        reply(name, body) {
            if (name === 'close') return Promise.resolve({ ok: true });
            const a = body.act;
            if (a === 'buy' && body.view === 'store') return Promise.resolve({ ok: true, cash: 12.5 });
            if (a === 'cut') return Promise.resolve({ ok: true, quality: 'Fine' });
            if (a === 'craft') return Promise.resolve({ ok: true, made: 4 });
            return Promise.resolve({ ok: true });
        },
    };
    window.MULTItailorMock = { open, close, Views };
})();
