/* MULTIadmin NUI. Every button asks the Lua side, which asks the server.
   All text comes from the locale table the server sends on open (L). */
(function () {
    'use strict';

    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIadmin';
    const $ = (s, r) => (r || document).querySelector(s);
    const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));

    const S = {
        allowed: {}, players: [], jobs: [], groups: [], moneyTypes: [], banDurations: [],
        weatherTypes: [], notifyTypes: [], notifyStyles: [], spawnPresets: { horses: [], wagons: [] },
        selected: null, state: {}, world: {}, filter: '', ui: { ConfirmMs: 3000, RefreshDelayMs: 300 },
    };
    let L = {};

    // translated line; %s / %d filled in order
    function T(key) {
        const args = Array.prototype.slice.call(arguments, 1);
        let s = L[key] != null ? String(L[key]) : key;
        return s.replace(/%[sd]/g, () => (args.length ? String(args.shift()) : ''));
    }
    function translatePage() {
        $$('[data-l]').forEach(e => { e.textContent = T(e.dataset.l); });
        $$('[data-lp]').forEach(e => { e.placeholder = T(e.dataset.lp); });
        $$('[data-lt]').forEach(e => { e.title = T(e.dataset.lt); });
    }

    function post(name, body) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then(r => r.json()).catch(() => ({}));
    }

    // player names come from players: always escape
    function esc(v) {
        return String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    }
    function money(n, gold) {
        const v = Number(n || 0).toFixed(2);
        return gold ? v : '$' + v;
    }
    function durText(h) {
        if (h === 0) return T('dur_perm');
        if (h % 24 === 0) return T(h === 24 ? 'dur_day' : 'dur_days', h / 24);
        return T(h === 1 ? 'dur_hour' : 'dur_hours', h);
    }
    const pad = n => String(n).padStart(2, '0');

    // ---------------------------------------------------------- open / close
    function open(d) {
        L = d.locale || {};
        S.allowed = d.allowed || {};
        S.players = d.players || [];
        S.jobs = d.jobs || [];
        S.groups = d.groups || [];
        S.moneyTypes = d.moneyTypes || [];
        S.items = d.items || [];
        S.kits = d.kits || [];
        let dl = $('#ma-items');
        if (!dl) { dl = document.createElement('datalist'); dl.id = 'ma-items'; document.body.appendChild(dl); }
        dl.innerHTML = S.items.map(i => `<option value="${esc(i.name)}">${esc(i.label)}</option>`).join('');
        S.banDurations = d.banDurations || [];
        S.weatherTypes = d.weatherTypes || [];
        S.notifyTypes = d.notifyTypes || [];
        S.notifyStyles = d.notifyStyles || [];
        S.spawnPresets = d.spawnPresets || { horses: [], wagons: [] };
        S.world = d.world || {};
        S.ui = Object.assign(S.ui, d.ui || {});
        $('#app').classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(d.localeCode));
        translatePage();
        $('#level').textContent = T(d.level === 'admin' ? 'level_admin' : 'level_mod');
        applyPerms();
        buildSelfTab();
        buildNotifyForm();
        setState(d.state || {});
        renderList();
        renderDetail();
        $('#app').classList.remove('mc-hidden');
    }
    function close() {
        $('#app').classList.add('mc-hidden');
    }

    function applyPerms() {
        $$('[data-perm]').forEach(el => el.classList.toggle('mc-hidden', !S.allowed[el.dataset.perm]));
    }

    // ---------------------------------------------------------- tabs
    $$('.mc-tab').forEach(t => t.addEventListener('click', () => {
        $$('.mc-tab').forEach(x => x.classList.toggle('active', x === t));
        $$('.ma-tab').forEach(s => s.classList.toggle('mc-hidden', s.id !== 'tab-' + t.dataset.tab));
        if (t.dataset.tab === 'self' && S.allowed.coords) selfTool('coords');
        if (t.dataset.tab === 'settings') loadSettings();
        if (t.dataset.tab === 'perf') fillPerfTargets();
    }));

    // ---------------------------------------------------------- player list
    function matches(p) {
        const f = S.filter.trim().toLowerCase();
        if (!f) return true;
        return [p.id, p.name, p.charName, p.citizenid, p.charId, p.job].some(v => v != null && String(v).toLowerCase().includes(f));
    }

    function renderList() {
        const list = S.players.filter(matches);
        $('#plist').innerHTML = list.map(p => `
            <div class="mc-row ma-prow ${S.selected === p.id ? 'active' : ''}" data-id="${Number(p.id)}">
                <span class="ma-id">${Number(p.id)}</span>
                <span class="ma-names">
                    <div>${esc(p.charName || T('no_char'))}</div>
                    <div class="mc-sub">${esc(p.name)}</div>
                </span>
                <span>${p.frozen ? `<span class="ma-tag frozen">${esc(T('tag_frozen'))}</span> ` : ''}${p.staff ? `<span class="ma-tag ${p.staff === 'admin' ? 'admin' : 'mod'}">${esc(T(p.staff === 'admin' ? 'level_admin' : 'level_mod'))}</span>` : ''}</span>
            </div>`).join('') || `<p class="mc-note">${esc(T('nobody_matches'))}</p>`;
        $('#pcount').textContent = T('online_count', S.players.length);
        $$('#plist .ma-prow').forEach(r => r.addEventListener('click', () => {
            S.selected = Number(r.dataset.id);
            renderList();
            renderDetail();
        }));
        fillNotifyTargets();
        if (S.allowed.perf) fillPerfTargets();
    }

    $('#search').addEventListener('input', e => { S.filter = e.target.value; renderList(); });
    $('#refresh').addEventListener('click', refresh);

    function refresh() {
        return post('refresh').then(list => {
            if (Array.isArray(list)) S.players = list;
            renderList();
            renderDetail();
        });
    }

    // ---------------------------------------------------------- player detail
    function can(a) { return !!S.allowed[a]; }

    function btn(action, key, cls, confirm) {
        if (!can(action)) return '';
        return `<button class="mc-btn small ${cls || ''}" data-act="${action}" ${confirm ? 'data-confirm="1"' : ''}>${esc(T(key))}</button>`;
    }
    function opts(list, label, selected) {
        return list.map(v => `<option value="${esc(v)}" ${v === selected ? 'selected' : ''}>${esc(label ? label(v) : v)}</option>`).join('');
    }
    function form(perm, headKey, inner) {
        return can(perm) ? `<div class="ma-form"><h3 class="mc-heading">${esc(T(headKey))}</h3><div class="ma-inline">${inner}</div></div>` : '';
    }

    function renderDetail() {
        const p = S.players.find(x => x.id === S.selected);
        const el = $('#detail');
        if (!p) {
            el.innerHTML = `<p class="mc-note ma-empty">${esc(T(S.selected ? 'player_left' : 'pick_player'))}</p>`;
            return;
        }
        const hasChar = !!p.citizenid;
        const jobOpts = S.jobs.map(j => `<option value="${esc(j.name)}" ${j.name === p.job ? 'selected' : ''}>${esc(j.label)} (${esc(j.name)})</option>`).join('');
        const info = (key, value, cls) => `<div><label>${esc(T(key))}</label><span class="${cls || ''}">${value}</span></div>`;
        el.innerHTML = `
            <div class="ma-who">
                <h2>${esc(p.charName || T('no_char'))}</h2>
                <span class="mc-note">${esc(p.name)} &middot; ${esc(T('lbl_ping', p.id, p.ping))}</span>
            </div>
            <div class="ma-info">
                ${info('lbl_serverid', Number(p.id))}
                ${info('lbl_citizenid', esc(p.citizenid || '-'))}
                ${info('lbl_charid', esc(p.charId != null ? p.charId : '-'))}
                ${info('lbl_group', esc(p.group || '-'))}
                ${info('lbl_job', hasChar ? esc((p.jobLabel || p.job || '-') + ' / ' + (p.gradeName || p.grade)) : '-')}
                ${info('lbl_cash', hasChar ? money(p.cash) : '-', 'mc-money')}
                ${info('lbl_bank', hasChar ? money(p.bank) : '-', 'mc-money')}
                ${info('lbl_goldrol', hasChar ? money(p.gold, true) + ' / ' + money(p.rol, true) : '-', 'mc-money mc-gold')}
                ${info('lbl_warnings', Number(p.warnings || 0))}
            </div>

            <div class="mc-btn-row ma-actions">
                ${btn('goto', 'btn_goto')}${btn('bring', 'btn_bring')}
                ${btn('freeze', p.frozen ? 'btn_unfreeze' : 'btn_freeze')}${btn('spectate', 'btn_spectate')}
                ${btn('heal', 'btn_heal')}${btn('revive', 'btn_revive')}
                ${btn('kill', 'btn_kill', 'danger', true)}
                ${hasChar ? btn('charmenu', 'btn_charmenu', 'danger', true) : ''}
            </div>

            <div class="ma-forms">
                ${form('kick', 'h_kick', `<input class="mc-input" id="kick-reason" placeholder="${esc(T('ph_reason'))}">${btn('kick', 'btn_kick', 'danger', true)}`)}
                ${form('warn', 'h_warn', `<input class="mc-input" id="warn-reason" placeholder="${esc(T('ph_reason'))}">${btn('warn', 'btn_warn')}`)}
                ${form('ban', 'h_ban', `<select class="mc-select" id="ban-hours">${S.banDurations.map(h => `<option value="${Number(h)}">${esc(durText(h))}</option>`).join('')}</select>
                    <input class="mc-input" id="ban-reason" placeholder="${esc(T('ph_reason'))}">${btn('ban', 'btn_ban', 'danger', true)}`)}
                ${hasChar ? form('money', 'h_money', `<select class="mc-select ma-num" id="money-type">${opts(S.moneyTypes)}</select>
                    <input class="mc-input" id="money-amount" type="number" min="0" step="0.01" placeholder="${esc(T('ph_amount'))}">
                    <button class="mc-btn small" data-money="give">${esc(T('btn_give'))}</button>
                    <button class="mc-btn small danger" data-money="take">${esc(T('btn_take'))}</button>`) : ''}
                ${hasChar ? form('item', 'h_item', `<input class="mc-input" id="item-name" list="ma-items" autocomplete="off" placeholder="${esc(T('ph_item'))}">
                    <input class="mc-input ma-num" id="item-amount" type="number" min="1" step="1" value="1">
                    <button class="mc-btn small" data-item="give">${esc(T('btn_give'))}</button>
                    <button class="mc-btn small danger" data-item="take">${esc(T('btn_take'))}</button>`) : ''}
                ${hasChar && S.kits.length ? form('kit', 'h_kit', `<select class="mc-select" id="kit">${S.kits.map(k => `<option value="${Number(k.id)}">${esc(k.label)}</option>`).join('')}</select>
                    <button class="mc-btn small" data-kit="1">${esc(T('btn_give'))}</button>`) : ''}
                ${hasChar ? form('job', 'h_job', `<select class="mc-select" id="job">${jobOpts}</select>
                    <select class="mc-select ma-grade" id="grade"></select>${btn('job', 'btn_set')}`) : ''}
                ${form('group', 'h_group', `<select class="mc-select" id="group">${opts(S.groups, null, p.group)}</select>${btn('group', 'btn_set', '', true)}`)}
                ${form('notify', 'h_notify', `<input class="mc-input" id="pn-text" placeholder="${esc(T('ph_message'))}">
                    <select class="mc-select ma-num" id="pn-type">${opts(S.notifyTypes, v => (L['ntype_' + v] || v))}</select>
                    <button class="mc-btn small" data-pnotify="1">${esc(T('btn_send'))}</button>`)}
            </div>`;

        const jobSel = $('#job');
        if (jobSel) {
            const fillGrades = () => {
                const j = S.jobs.find(x => x.name === jobSel.value);
                $('#grade').innerHTML = (j ? j.grades : []).map(g =>
                    `<option value="${Number(g.level)}" ${jobSel.value === p.job && g.level === p.grade ? 'selected' : ''}>${Number(g.level)} ${esc(g.name)}</option>`).join('');
            };
            jobSel.addEventListener('change', fillGrades);
            fillGrades();
        }

        $$('[data-act]', el).forEach(b => b.addEventListener('click', () => {
            if (b.dataset.confirm && !b.classList.contains('confirm')) {
                b.classList.add('confirm');
                b.dataset.label = b.textContent;
                b.textContent = T('btn_sure');
                setTimeout(() => { if (b.isConnected) { b.classList.remove('confirm'); b.textContent = b.dataset.label; } }, S.ui.ConfirmMs);
                return;
            }
            playerAction(b.dataset.act, p);
        }));
        $$('[data-money]', el).forEach(b => b.addEventListener('click', () => playerAction('money', p, { mode: b.dataset.money })));
        $$('[data-item]', el).forEach(b => b.addEventListener('click', () =>
            playerAction('item', p, { mode: b.dataset.item, item: val('item-name').trim(), amount: Number(val('item-amount')) })));
        $$('[data-kit]', el).forEach(b => b.addEventListener('click', () => playerAction('kit', p, { kit: Number(val('kit')) })));
        $$('[data-pnotify]', el).forEach(b => b.addEventListener('click', () =>
            post('action', { action: 'notify', data: { target: p.id, text: val('pn-text'), type: val('pn-type') } })
                .then(res => { if (res && res.ok) $('#pn-text').value = ''; })));
    }

    function val(id) { const e = $('#' + id); return e ? e.value : ''; }

    function playerAction(action, p, extra) {
        const data = Object.assign({ target: p.id }, extra || {});
        if (action === 'kick') data.reason = val('kick-reason');
        if (action === 'warn') data.reason = val('warn-reason');
        if (action === 'ban') { data.reason = val('ban-reason'); data.hours = Number(val('ban-hours')); }
        if (action === 'money') { data.moneyType = val('money-type'); data.amount = Number(val('money-amount')); }
        if (action === 'job') { data.job = val('job'); data.grade = Number(val('grade')); }
        if (action === 'group') data.group = val('group');
        post('action', { action, data }).then(res => {
            if (res && res.ok && !['goto', 'spectate', 'charmenu'].includes(action)) setTimeout(refresh, S.ui.RefreshDelayMs);
        });
    }

    // ---------------------------------------------------------- self tab
    function buildSelfTab() {
        const chips = (list, input) => (list || []).map(m => `<span class="ma-chip" data-fill="${input}" data-model="${esc(m)}">${esc(m)}</span>`).join('');
        $('#horse-presets').innerHTML = chips(S.spawnPresets.horses, 'horse-model');
        $('#wagon-presets').innerHTML = chips(S.spawnPresets.wagons, 'wagon-model');
        $$('.ma-chip').forEach(c => c.addEventListener('click', () => { $('#' + c.dataset.fill).value = c.dataset.model; }));
        $('#weather').innerHTML = opts(S.weatherTypes, null, S.world.weather);
        worldText();
    }

    function worldText() {
        const w = S.world || {};
        $('#cur-weather').textContent = w.weather ? T('now_weather', w.weather) : T('natural');
        $('#cur-time').textContent = w.hour != null
            ? T(w.freeze ? 'set_time_frozen' : 'set_time', `${pad(w.hour)}:${pad(w.minute || 0)}`) : T('natural');
    }

    function setState(st) {
        S.state = st || {};
        $$('.ma-toggle').forEach(t => t.classList.toggle('on', !!S.state[t.dataset.self]));
        $('#nc-speed').textContent = S.state.noclip && S.state.speed ? T('unit_speed', S.state.speed) : '';
    }

    function selfTool(name, data) {
        return post('self', { name, data: data || {} }).then(res => { if (res && res.state) setState(res.state); return res; });
    }

    $$('.ma-toggle').forEach(t => t.addEventListener('click', () => selfTool(t.dataset.self, { on: !S.state[t.dataset.self] })));
    $$('[data-selfbtn]').forEach(b => b.addEventListener('click', () => selfTool(b.dataset.selfbtn)));
    $$('[data-copy]').forEach(b => b.addEventListener('click', () => selfTool('copy', { kind: b.dataset.copy })));
    $$('[data-spawn]').forEach(b => b.addEventListener('click', () =>
        selfTool('spawn', { kind: b.dataset.spawn, model: $('#' + b.dataset.spawn + '-model').value })));

    function worldAction(action, data, after) {
        post('action', { action, data }).then(res => { if (res && res.ok) { after(); worldText(); } });
    }
    $('#set-weather').addEventListener('click', () => { const w = $('#weather').value; worldAction('weather', { weather: w }, () => { S.world.weather = w; }); });
    $('#reset-weather').addEventListener('click', () => worldAction('weather', { weather: 'reset' }, () => { S.world.weather = null; }));
    $('#set-time').addEventListener('click', () => {
        const hour = Number($('#hour').value), minute = Number($('#minute').value), freeze = $('#freeze-time').checked;
        worldAction('time', { hour, minute, freeze }, () => Object.assign(S.world, { hour, minute, freeze }));
    });
    $('#reset-time').addEventListener('click', () => worldAction('time', { reset: true }, () => { S.world.hour = null; S.world.minute = null; S.world.freeze = null; }));

    // ---------------------------------------------------------- server tab
    $('#send-announce').addEventListener('click', () => {
        const text = $('#announce').value.trim();
        if (!text) return;
        post('action', { action: 'announce', data: { text } }).then(res => { if (res && res.ok) $('#announce').value = ''; });
    });

    function fillNotifyTargets() {
        const sel = $('#sn-target');
        const keep = sel.value;
        sel.innerHTML = `<option value="all">${esc(T('opt_everyone'))}</option>` +
            S.players.map(p => `<option value="${Number(p.id)}">${esc(T('opt_player', p.id))} - ${esc(p.charName || p.name)}</option>`).join('');
        if (keep && $$('option', sel).some(o => o.value === keep)) sel.value = keep;
    }
    function buildNotifyForm() {
        $('#sn-type').innerHTML = opts(S.notifyTypes, v => (L['ntype_' + v] || v));
        $('#sn-style').innerHTML = opts(S.notifyStyles, v => (L['nstyle_' + v] || v));
        fillNotifyTargets();
    }
    $('#sn-send').addEventListener('click', () => {
        const text = $('#sn-text').value.trim();
        if (!text) return;
        const t = $('#sn-target').value;
        post('action', { action: 'notify', data: { target: t === 'all' ? 'all' : Number(t), text, type: $('#sn-type').value, style: $('#sn-style').value } })
            .then(res => { if (res && res.ok) $('#sn-text').value = ''; });
    });

    function renderBans(rows) {
        $('#bans').innerHTML = (rows || []).map(b => `
            <tr><td>${Number(b.id)}</td><td>${esc(b.name)}</td><td class="reason" title="${esc(b.reason)}">${esc(b.reason)}</td>
            <td>${esc(b.untilText)}</td><td>${esc(b.bannedby)}</td><td>${esc(b.createdText)}</td>
            <td>${can('unban') ? `<button class="mc-btn small" data-unban="${Number(b.id)}">${esc(T('btn_unban'))}</button>` : ''}</td></tr>`).join('')
            || `<tr><td colspan="7" class="mc-note">${esc(T('no_bans'))}</td></tr>`;
        $$('[data-unban]').forEach(b => b.addEventListener('click', () =>
            post('action', { action: 'unban', data: { id: Number(b.dataset.unban) } }).then(res => { if (res && res.ok) renderBans(res.data); })));
    }
    $('#load-bans').addEventListener('click', () => post('action', { action: 'bans' }).then(res => { if (res && res.ok) renderBans(res.data); }));

    // ---------------------------------------------------------- settings tab
    // Every setting MULTI scripts registered with MULTIcore; the server checks rank and value.
    S.settings = [];
    function loadSettings() {
        return post('action', { action: 'settings' }).then(res => {
            if (res && res.ok && Array.isArray(res.data)) S.settings = res.data;
            renderSettings();
        });
    }

    function shownValue(r, v) {
        if (r.type === 'bool') return T(v ? 'set_on' : 'set_off');
        if (r.type === 'choice') {
            const c = (r.choices || []).find(x => String(x.value) === String(v));
            return c ? c.label : String(v);
        }
        if (v == null || v === '') return '-';
        return String(v) + (r.unit ? ' ' + r.unit : '');
    }
    function when(at) {
        if (!at) return '';
        const d = new Date(Number(at) * 1000);
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
    }
    const ctlId = key => 'set-' + String(key).replace(/[^\w-]/g, '_');

    function control(r) {
        const id = ctlId(r.key);
        if (r.type === 'bool') {
            return `<select class="mc-select" id="${id}"><option value="true" ${r.value ? 'selected' : ''}>${esc(T('set_on'))}</option><option value="false" ${!r.value ? 'selected' : ''}>${esc(T('set_off'))}</option></select>`;
        }
        if (r.type === 'choice') {
            return `<select class="mc-select" id="${id}">${(r.choices || []).map(c =>
                `<option value="${esc(c.value)}" ${String(c.value) === String(r.value) ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select>`;
        }
        if (r.type === 'number') {
            const attr = (r.min != null ? ` min="${Number(r.min)}"` : '') + (r.max != null ? ` max="${Number(r.max)}"` : '') +
                ` step="${r.step != null ? Number(r.step) : (r.integer ? 1 : 'any')}"`;
            return `<input class="mc-input ma-num" type="number" id="${id}" value="${esc(r.value)}"${attr}>${r.unit ? `<span class="ma-unit">${esc(r.unit)}</span>` : ''}`;
        }
        return `<input class="mc-input" id="${id}" value="${esc(r.value)}" maxlength="${Number(r.maxLength || 200)}">`;
    }

    function readControl(r) {
        const el = $('#' + ctlId(r.key));
        if (!el) return null;
        if (r.type === 'bool') return el.value === 'true';
        if (r.type === 'number') return el.value === '' ? '' : Number(el.value);
        if (r.type === 'choice') {
            const c = (r.choices || []).find(x => String(x.value) === el.value);
            return c ? c.value : el.value;
        }
        return el.value;
    }

    function confirmFirst(b) {
        if (b.classList.contains('confirm')) return true;
        b.classList.add('confirm');
        b.dataset.label = b.textContent;
        b.textContent = T('btn_sure');
        setTimeout(() => { if (b.isConnected) { b.classList.remove('confirm'); b.textContent = b.dataset.label; } }, S.ui.ConfirmMs);
        return false;
    }

    function renderSettings() {
        const f = $('#set-search').value.trim().toLowerCase();
        const onlyChanged = $('#set-changed').checked;
        const rows = S.settings.filter(r => (!onlyChanged || r.changed) &&
            (!f || [r.label, r.key, r.resource, r.category].some(v => v && String(v).toLowerCase().includes(f))));
        let html = '', res = null, cat = null;
        rows.forEach(r => {
            if (r.resource !== res) { res = r.resource; cat = null; html += `<h2 class="mc-heading ma-set-res">${esc(res)}</h2>`; }
            if (r.category !== cat) { cat = r.category; if (cat) html += `<h3 class="ma-set-cat">${esc(cat)}</h3>`; }
            const range = r.type === 'number' && (r.min != null || r.max != null)
                ? T('set_range', shownValue(r, r.min != null ? r.min : ''), shownValue(r, r.max != null ? r.max : '')) : '';
            html += `
                <div class="ma-set ${r.changed ? 'changed' : ''}">
                    <div class="ma-set-name">
                        <div>${esc(r.label)}${r.client ? ` <span class="ma-tag">${esc(T('set_tag_players'))}</span>` : ''}</div>
                        <div class="mc-sub">${esc(r.key)}${range ? ' &middot; ' + esc(range) : ''}</div>
                        ${r.help ? `<div class="mc-sub">${esc(r.help)}</div>` : ''}
                    </div>
                    <div class="ma-set-edit ma-inline">${control(r)}</div>
                    <div class="ma-set-file"><label>${esc(T('set_file_value'))}</label><span>${esc(shownValue(r, r.default))}</span></div>
                    <div class="ma-set-btns">
                        <button class="mc-btn small primary" data-setsave="${esc(r.key)}">${esc(T('btn_save'))}</button>
                        <button class="mc-btn small" data-setreset="${esc(r.key)}" ${r.changed ? '' : 'disabled'}>${esc(T('btn_reset_file'))}</button>
                    </div>
                    ${r.changed && r.changedBy ? `<div class="mc-sub ma-set-by">${esc(T('set_changed_by', r.changedBy, when(r.changedAt)))}</div>` : ''}
                </div>`;
        });
        $('#set-list').innerHTML = html || `<p class="mc-note ma-empty">${esc(T(S.settings.length ? 'set_none_match' : 'set_none'))}</p>`;
        const after = res => { if (res && res.ok && Array.isArray(res.data)) { S.settings = res.data; renderSettings(); } };
        $$('[data-setsave]').forEach(b => b.addEventListener('click', () => {
            const r = S.settings.find(x => x.key === b.dataset.setsave);
            if (r) post('action', { action: 'settings_set', data: { key: r.key, value: readControl(r) } }).then(after);
        }));
        $$('[data-setreset]').forEach(b => b.addEventListener('click', () => {
            if (confirmFirst(b)) post('action', { action: 'settings_reset', data: { key: b.dataset.setreset } }).then(after);
        }));
    }
    $('#set-search').addEventListener('input', renderSettings);
    $('#set-changed').addEventListener('change', renderSettings);
    $('#set-reload').addEventListener('click', loadSettings);

    // ---------------------------------------------------------- performance tab
    function fillPerfTargets() {
        const sel = $('#perf-target');
        const keep = sel.value;
        sel.innerHTML = `<option value="server">${esc(T('perf_server'))}</option>` +
            S.players.map(p => `<option value="${Number(p.id)}">${esc(T('perf_player', p.id, p.charName || p.name))}</option>`).join('');
        if (keep && $$('option', sel).some(o => o.value === keep)) sel.value = keep;
        perfHelp();
    }
    function perfHelp() {
        $('#perf-help').textContent = T($('#perf-target').value === 'server' ? 'perf_help_server' : 'perf_help_client');
    }
    $('#perf-target').addEventListener('change', perfHelp);

    const level = (v, warn, heavy) => (v >= heavy ? 'heavy' : (v >= warn ? 'warn' : ''));
    const ms = v => Number(v || 0).toFixed(2);

    function renderServerPerf(d) {
        const rows = d.rows || [];
        if (!rows.length) { $('#perf-out').innerHTML = `<p class="mc-note ma-empty">${esc(T('perf_empty'))}</p>`; return; }
        $('#perf-out').innerHTML = `
            <p class="mc-note">${esc(T('perf_server_summary', d.frames, (Number(d.wallMs || 0) / 1000).toFixed(1), rows.length))}</p>
            <div class="ma-legend"><span class="ma-lv warn">${esc(T('perf_warn', ms(d.warnMs)))}</span><span class="ma-lv heavy">${esc(T('perf_heavy', ms(d.heavyMs)))}</span></div>
            <table class="ma-table ma-perf-table">
                <thead><tr><th>#</th><th>${esc(T('col_resource'))}</th><th>${esc(T('col_avg_tick'))}</th><th>${esc(T('col_max_tick'))}</th>
                    <th>${esc(T('col_total'))}</th><th>${esc(T('col_share'))}</th><th>${esc(T('col_ticks'))}</th><th>${esc(T('col_events'))}</th></tr></thead>
                <tbody>${rows.map((r, i) => `
                    <tr class="ma-lv-row ${level(r.avgMs, d.warnMs, d.heavyMs)}">
                        <td>${i + 1}</td><td>${esc(r.name)}</td><td class="num">${ms(r.avgMs)}</td><td class="num">${ms(r.maxMs)}</td>
                        <td class="num">${ms(r.totalMs)}</td><td class="num">${Number(r.share || 0).toFixed(2)}%</td>
                        <td class="num">${Number(r.ticks || 0)}</td><td class="num">${Number(r.events || 0)}</td></tr>`).join('')}
                </tbody>
            </table>`;
    }

    function renderClientPerf(d) {
        const tile = (key, value, cls) => `<div class="ma-tile ${cls || ''}"><label>${esc(T(key))}</label><span>${esc(value)}</span></div>`;
        const lv = level(d.avgMs, d.warnMs, d.heavyMs);
        $('#perf-out').innerHTML = `
            <p class="mc-note">${esc(T('perf_client_summary', d.playerName || d.player, d.frames, Number(d.seconds || 0).toFixed(1)))}</p>
            <div class="ma-tiles">
                ${tile('perf_fps', Number(d.fps || 0).toFixed(1), lv)}
                ${tile('perf_avg_frame', ms(d.avgMs) + ' ms', lv)}
                ${tile('perf_worst_frames', ms(d.worstMs) + ' ms', level(d.worstMs, d.heavyMs, d.heavyMs * 2))}
                ${tile('perf_max_frame', ms(d.maxMs) + ' ms')}
                ${tile('perf_slow_frames', `${Number(d.slowFrames || 0)} / ${Number(d.frames || 0)}`)}
            </div>
            <p class="mc-note">${esc(T('perf_client_note'))}</p>
            <h3 class="ma-set-cat">${esc(T('perf_client_resources', (d.resources || []).length))}</h3>
            <div class="ma-chips">${(d.resources || []).map(n => `<span class="ma-chip">${esc(n)}</span>`).join('')}</div>`;
    }

    $('#perf-run').addEventListener('click', () => {
        const target = $('#perf-target').value;
        const runBtn = $('#perf-run');
        runBtn.disabled = true;
        $('#perf-status').textContent = T(target === 'server' ? 'perf_measuring_server' : 'perf_measuring_client');
        post('action', { action: 'perf', data: { target: target === 'server' ? 'server' : Number(target) } }).then(res => {
            runBtn.disabled = false;
            $('#perf-status').textContent = '';
            if (!res || !res.ok || !res.data) return;
            if (res.data.kind === 'server') renderServerPerf(res.data); else renderClientPerf(res.data);
        });
    });

    // ---------------------------------------------------------- messages from Lua
    window.addEventListener('message', e => {
        const m = e.data || {};
        if (m.action === 'open') open(m.data || {});
        else if (m.action === 'close') close();
        else if (m.action === 'coords' && m.data) {
            $('#cx').textContent = Number(m.data.x).toFixed(2);
            $('#cy').textContent = Number(m.data.y).toFixed(2);
            $('#cz').textContent = Number(m.data.z).toFixed(2);
            $('#cw').textContent = Number(m.data.w).toFixed(2);
        }
    });

    $('#close').addEventListener('click', () => post('close'));
    document.addEventListener('keydown', e => { if (e.key === 'Escape') post('close'); });

    window.__ma = { open, renderBans, renderSettings, renderServerPerf, renderClientPerf, S }; // used by the preview mock
})();
