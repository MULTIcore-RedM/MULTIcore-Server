// MULTIjobs pages: job centre, my jobs, boss menu, gang menu.
// Shows what the server sends; every button goes back to the server, which checks everything.
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('app');
    let L = {};
    let screen = null;   // 'centre' | 'myjobs' | 'boss' | 'gang'
    let state = null;
    let tab = null;
    let sel = null;      // selected row key
    let nearby = null;   // hire / recruit list
    let busy = false;
    let armed = null;    // button waiting for a second click (confirm)

    // locale line; %s / %d markers are filled in order, %% is a literal %
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
    function group(d) { return d.replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
    function money(n, cents) {
        n = Number(n) || 0;
        const [d, c] = Math.abs(n).toFixed(2).split('.');
        if (cents) return `${n < 0 ? '-' : ''}$${group(d)}<span class="mc-cents">${c}</span>`;
        return `${n < 0 ? '-' : ''}$${group(d)}${c !== '00' ? '.' + c : ''}`;
    }
    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIjobs';
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
    function act(action, data) {
        if (busy) return;
        busy = true;
        post('action', { action, data: data || {} }).then((res) => {
            busy = false;
            if (!res) return;
            if (res.msg) say(res.msg, res.ok);
            if (res.list) nearby = res.list;
            if (res.state) state = res.state;
            if (res.ok && (action === 'hire')) nearby = null;
            render();
            if (tab === 'hire' && nearby === null) loadNearby();
        });
    }
    function loadNearby() {
        nearby = [];
        post('action', { action: 'nearby' }).then((res) => {
            nearby = (res && res.list) || [];
            render();
        });
    }
    function close() {
        root.classList.add('mc-hidden');
        screen = null;
        post('close');
    }

    // ---------- building blocks ----------
    function row(key, main, sub, side, active) {
        return `<div class="mc-row${active ? ' active' : ''}" data-sel="${esc(key)}">` +
            `<div class="main"><b>${main}</b>${sub ? `<span class="mc-sub">${sub}</span>` : ''}</div>` +
            `<div class="side">${side || ''}</div></div>`;
    }
    function btn(label, attrs, cls) {
        return `<button class="mc-btn ${cls || ''}" ${attrs || ''}>${esc(label)}</button>`;
    }
    function payText(p) { return Number(p) > 0 ? t('ui_per_pay', money(p)) : t('ui_no_wage'); }
    function grades(list, mine) {
        return `<div class="grades">${list.map((g) => `<div class="g${mine === g.level ? ' me' : ''}"><span>${esc(g.name)}${g.isboss ? ` <span class="pill">${esc(t('ui_boss'))}</span>` : ''}</span>` +
            `<span class="mc-money">${Number(g.payment) > 0 ? money(g.payment) : '<span class="faint">-</span>'}</span></div>`).join('')}</div>`;
    }
    function setHead(title, subtitle) {
        $('title').textContent = title || '';
        $('subtitle').textContent = subtitle || '';
    }
    function setTabs(list) {
        const nav = $('tabs');
        if (!list) { nav.classList.add('mc-hidden'); nav.innerHTML = ''; return; }
        nav.classList.remove('mc-hidden');
        const word = (k) => (k === 'staff' && state && state.kind === 'gang' ? 'ui_tab_members' : 'ui_tab_' + k);
        nav.innerHTML = list.map((k) => `<button class="mc-tab${k === tab ? ' active' : ''}" data-tab="${k}">${esc(t(word(k)))}</button>`).join('');
    }
    function pick(list, keyOf) {
        if (!list.length) { sel = null; return null; }
        let it = list.find((x) => keyOf(x) === sel);
        if (!it) { it = list[0]; sel = keyOf(it); }
        return it;
    }

    // ---------- job centre ----------
    function renderCentre() {
        const s = state;
        setHead(s.centre, `${t('ui_jobs_held', s.count, s.max)}  ·  ${t('ui_current', s.currentLabel || '')}`);
        setTabs(null);
        $('listHead').textContent = t('ui_open_positions');
        const cur = pick(s.jobs, (j) => j.job);
        $('list').innerHTML = s.jobs.length ? s.jobs.map((j) => row(j.job, esc(j.label), payText(j.pay),
            j.active ? `<span class="pill solid">${esc(t('ui_active'))}</span>` : (j.held ? `<span class="pill">${esc(t('ui_held'))}</span>` : ''),
            j.job === sel)).join('') : `<div class="empty">${esc(t('ui_no_positions'))}</div>`;
        let html = '';
        if (cur) {
            const full = s.count >= s.max;
            html += `<h2>${esc(cur.label)}</h2><p class="lead">${esc(cur.desc)}</p>`;
            html += `<div class="facts"><span>${esc(t('ui_start_pay'))}</span><b>${payText(cur.pay)}</b></div>`;
            html += `<h3 class="mc-heading">${esc(t('ui_ranks'))}</h3>${grades(cur.grades)}`;
            html += `<div class="actions">${btn(t('ui_take_job'), `data-do="take" data-job="${esc(cur.job)}"${cur.held || full ? ' disabled' : ''}`, 'primary')}</div>`;
            if (cur.held) html += `<p class="mc-note">${esc(t('ui_you_hold'))}</p>`;
            else if (full) html += `<p class="mc-note">${esc(t('ui_max_reached', s.max))}</p>`;
        }
        $('detail').innerHTML = html;
        $('footLeft').innerHTML = s.current && s.current !== 'unemployed'
            ? btn(t('ui_become_unemployed'), 'data-do="quit" data-confirm="1"', 'danger small') : '';
    }

    // ---------- my jobs ----------
    function renderMyJobs() {
        const s = state;
        setHead(t('ui_myjobs'), t('ui_jobs_held', s.count, s.max));
        setTabs(null);
        $('listHead').textContent = t('ui_your_jobs');
        const list = s.jobs.slice();
        list.push({ job: 'unemployed', label: t('ui_civilian'), civ: true, active: s.current === 'unemployed' });
        const cur = pick(list, (j) => j.job);
        $('list').innerHTML = list.map((j) => row(j.job, esc(j.label),
            j.civ ? esc(t('ui_civilian_sub')) : `${esc(j.gradeName)}  ·  ${payText(j.pay)}`,
            j.active ? `<span class="pill solid">${esc(t('ui_active'))}</span>` : '', j.job === sel)).join('');
        let html = '';
        if (cur && cur.civ) {
            html += `<h2>${esc(t('ui_civilian'))}</h2><p class="lead">${esc(t('ui_civilian_help'))}</p>`;
            if (!cur.active) html += `<div class="actions">${btn(t('ui_go_civilian'), 'data-do="switch" data-job="unemployed"', 'primary')}</div>`;
        } else if (cur) {
            html += `<h2>${esc(cur.label)}</h2>`;
            html += `<div class="facts"><span>${esc(t('ui_rank'))}</span><b>${esc(cur.gradeName)}${cur.isboss ? ` <span class="pill">${esc(t('ui_boss'))}</span>` : ''}</b>` +
                `<span>${esc(t('ui_pay'))}</span><b>${payText(cur.pay)}</b>` +
                `<span>${esc(t('ui_status'))}</span><b>${esc(cur.active ? t('ui_active_now') : t('ui_held_only'))}</b></div>`;
            html += '<div class="actions">';
            if (!cur.active) html += btn(t('ui_make_active'), `data-do="switch" data-job="${esc(cur.job)}"`, 'primary');
            html += btn(t('ui_quit_job'), `data-do="quit" data-job="${esc(cur.job)}" data-confirm="1"`, 'danger');
            html += '</div>';
            if (cur.active && s.dutyJob) {
                html += `<div class="block"><h3>${esc(t('ui_duty'))}</h3><p class="lead"><span class="dot ${s.onduty ? 'on' : ''}"></span>${esc(s.onduty ? t('ui_on_duty') : t('ui_off_duty'))}</p>` +
                    `<div class="actions">${btn(s.onduty ? t('ui_clock_out') : t('ui_clock_in'), 'data-do="duty"')}</div></div>`;
            }
        }
        html += `<div class="block"><h3>${esc(t('ui_your_gang'))}</h3>`;
        if (s.gang) {
            html += `<div class="facts"><span>${esc(t('ui_gang'))}</span><b>${esc(s.gang.label)}</b><span>${esc(t('ui_rank'))}</span><b>${esc(s.gang.gradeName)}</b></div>`;
            if (s.canLeaveGang) html += `<div class="actions">${btn(t('ui_leave_gang'), 'data-do="leavegang" data-confirm="1"', 'danger small')}</div>`;
        } else {
            html += `<p class="mc-note">${esc(t('ui_no_gang'))}</p>`;
        }
        html += '</div>';
        $('detail').innerHTML = html;
        $('footLeft').innerHTML = '';
    }

    // ---------- boss and gang menus ----------
    function bossTabs() {
        if (state.readOnly) return ['staff'];
        return state.kind === 'job' ? ['staff', 'hire', 'ranks', 'money', 'roster'] : ['staff', 'hire', 'money'];
    }
    function staffRows(list) {
        return list.map((m) => row(m.cid, esc(m.name), esc(m.gradeName) + (state.kind === 'job' && !m.active ? `  ·  ${esc(t('ui_side_job'))}` : ''),
            `<span class="dot ${m.online ? 'on' : ''}"></span><span class="mc-sub">${esc(m.online ? t('ui_online') : t('ui_offline'))}</span>` +
            (m.onduty ? ` <span class="pill">${esc(t('ui_duty_short'))}</span>` : ''), m.cid === sel)).join('');
    }
    function renderBoss() {
        const s = state;
        const tabs = bossTabs();
        if (!tabs.includes(tab)) tab = tabs[0];
        setHead(s.label, t('ui_your_rank', s.gradeName));
        setTabs(tabs.length > 1 ? tabs : null);
        $('footLeft').innerHTML = s.stash && !s.readOnly ? btn(t('ui_stash'), 'data-do="stash"', 'small') : '';
        let list = '';
        let html = '';
        if (tab === 'staff') {
            $('listHead').textContent = t(s.kind === 'job' ? 'ui_staff_count' : 'ui_members_count', s.staff.length);
            const cur = pick(s.staff, (m) => m.cid);
            list = s.staff.length ? staffRows(s.staff) : `<div class="empty">${esc(t('ui_nobody'))}</div>`;
            if (cur) {
                html += `<h2>${esc(cur.name)}</h2>`;
                html += `<div class="facts"><span>${esc(t('ui_rank'))}</span><b>${esc(cur.gradeName)}</b>` +
                    `<span>${esc(t('ui_status'))}</span><b><span class="dot ${cur.online ? 'on' : ''}"></span>${esc(cur.online ? t('ui_online') : t('ui_offline'))}</b>`;
                if (s.kind === 'job') {
                    html += `<span>${esc(t('ui_this_job'))}</span><b>${esc(cur.active ? t('ui_active_now') : t('ui_side_job'))}</b>` +
                        `<span>${esc(t('ui_duty'))}</span><b>${esc(cur.onduty ? t('ui_on_duty') : t('ui_off_duty'))}</b>`;
                }
                html += '</div>';
                if (s.readOnly) {
                    // members only look
                } else if (cur.cid === s.cid) {
                    html += `<p class="mc-note">${esc(t('ui_this_is_you'))}</p>`;
                } else if (cur.grade > s.manageUpTo) {
                    html += `<p class="mc-note">${esc(t('ui_outranks_you'))}</p>`;
                } else {
                    const opts = s.grades.filter((g) => g.level <= s.manageUpTo)
                        .map((g) => `<option value="${g.level}"${g.level === cur.grade ? ' selected' : ''}>${esc(g.name)}</option>`).join('');
                    html += `<h3 class="mc-heading">${esc(t('ui_change_rank'))}</h3><div class="actions"><select class="mc-select" id="gradeSel">${opts}</select>` +
                        btn(t('ui_set_rank'), `data-do="setgrade" data-cid="${esc(cur.cid)}"`, 'primary') + '</div>';
                    html += `<div class="actions">${btn(t(s.kind === 'job' ? 'ui_fire' : 'ui_kick'), `data-do="fire" data-cid="${esc(cur.cid)}" data-confirm="1"`, 'danger')}</div>`;
                }
            }
        } else if (tab === 'hire') {
            $('listHead').textContent = t('ui_people_near');
            if (nearby === null) loadNearby();
            const near = nearby || [];
            list = near.length ? near.map((p) => row('p' + p.id, esc(p.name), '', btn(t(s.kind === 'job' ? 'ui_hire' : 'ui_recruit'), `data-do="hire" data-target="${p.id}"`, 'small primary'), false)).join('')
                : `<div class="empty">${esc(t('ui_nobody_near'))}</div>`;
            html += `<h2>${esc(t(s.kind === 'job' ? 'ui_hire_title' : 'ui_recruit_title'))}</h2><p class="lead">${esc(t(s.kind === 'job' ? 'ui_hire_help' : 'ui_recruit_help'))}</p>` +
                `<div class="actions">${btn(t('ui_refresh'), 'data-do="refreshNearby"')}</div>`;
        } else if (tab === 'ranks') {
            $('listHead').textContent = t('ui_ranks');
            const cur = pick(s.grades, (g) => 'g' + g.level);
            list = s.grades.map((g) => row('g' + g.level, esc(g.name) + (g.isboss ? ` <span class="pill">${esc(t('ui_boss'))}</span>` : ''), payText(g.payment), '', 'g' + g.level === sel)).join('');
            if (cur) {
                html += `<h2>${esc(cur.name)}</h2><div class="facts"><span>${esc(t('ui_pay'))}</span><b>${payText(cur.payment)}</b></div>`;
                if (cur.level < s.grade) {
                    html += `<div class="money-inputs"><div class="mc-field"><label for="payIn">${esc(t('ui_new_pay'))}</label>` +
                        `<input class="mc-input" id="payIn" inputmode="decimal" maxlength="8" value="${esc(cur.payment)}"></div>` +
                        btn(t('ui_save'), `data-do="setpay" data-grade="${cur.level}"`, 'primary') + '</div>' +
                        `<p class="mc-note">${esc(t('ui_pay_limits', money(s.payMin), money(s.payMax)))}</p>`;
                } else {
                    html += `<p class="mc-note">${esc(t('ui_cant_set_own'))}</p>`;
                }
            }
        } else if (tab === 'money') {
            $('listHead').textContent = '';
            list = `<div class="block center"><h3>${esc(t(s.kind === 'job' ? 'ui_society_funds' : 'ui_gang_funds'))}</h3>` +
                `<div class="mc-money big">${s.bankOk ? money(s.balance, true) : '-'}</div>` +
                `<p class="mc-note">${esc(t('ui_your_cash'))} ${money(s.cash)}</p></div>`;
            if (!s.bankOk) html += `<p class="mc-note">${esc(t('no_bank'))}</p>`;
            else html += `<h2>${esc(t('ui_tab_money'))}</h2><p class="lead">${esc(t('ui_money_help'))}</p>` +
                `<div class="money-inputs"><div class="mc-field"><label for="amt">${esc(t('ui_amount'))}</label><input class="mc-input" id="amt" inputmode="decimal" placeholder="0.00" maxlength="10"></div></div>` +
                `<div class="actions">${btn(t('ui_deposit'), 'data-do="deposit"', 'primary')}${btn(t('ui_withdraw'), 'data-do="withdraw"')}</div>`;
        } else if (tab === 'roster') {
            const online = s.staff.filter((m) => m.online);
            online.sort((a, b) => (b.onduty ? 1 : 0) - (a.onduty ? 1 : 0));
            $('listHead').textContent = t('ui_online_staff', online.length);
            list = online.length ? online.map((m) => row(m.cid, esc(m.name), esc(m.gradeName),
                `<span class="dot ${m.onduty ? 'on' : ''}"></span><span class="mc-sub">${esc(m.onduty ? t('ui_on_duty') : (m.active ? t('ui_off_duty') : t('ui_side_job')))}</span>`, false)).join('')
                : `<div class="empty">${esc(t('ui_nobody_online'))}</div>`;
            html += `<div class="center"><div class="mc-money big">${s.onduty}</div><p class="lead">${esc(t('ui_on_duty_now'))}</p></div>`;
            html += `<p class="mc-note center">${esc(t('ui_roster_help'))}</p>`;
        }
        $('list').innerHTML = list;
        $('detail').innerHTML = html;
    }

    function render() {
        if (!state) return;
        armed = null;
        if (screen === 'centre') renderCentre();
        else if (screen === 'myjobs') renderMyJobs();
        else renderBoss();
    }

    // ---------- clicks ----------
    function readAmount(id) {
        const el = $(id);
        if (!el) return null;
        const v = el.value.trim().replace(',', '.');
        if (!/^\d{1,9}(\.\d{1,2})?$/.test(v)) return null;
        return Number(v);
    }
    document.addEventListener('click', (e) => {
        const tabBtn = e.target.closest('[data-tab]');
        if (tabBtn) {
            tab = tabBtn.dataset.tab;
            sel = null;
            say('');
            if (tab === 'hire') nearby = null;
            render();
            return;
        }
        const b = e.target.closest('[data-do]');
        if (b) {
            if (b.disabled) return;
            if (b.dataset.confirm && armed !== b) {
                armed = b;
                b.dataset.text = b.textContent;
                b.textContent = t('ui_confirm');
                setTimeout(() => { if (armed === b) { b.textContent = b.dataset.text; armed = null; } }, 3000);
                return;
            }
            armed = null;
            const d = b.dataset;
            switch (d.do) {
                case 'take': act('take', { job: d.job }); break;
                case 'quit': act('quit', { job: d.job }); break;
                case 'switch': act('switch', { job: d.job }); break;
                case 'duty': act('duty'); break;
                case 'leavegang': act('leavegang'); break;
                case 'stash': act('stash'); break;
                case 'refreshNearby': loadNearby(); break;
                case 'hire': act('hire', { target: Number(d.target) }); break;
                case 'fire': act('fire', { cid: d.cid }); break;
                case 'setgrade': act('setgrade', { cid: d.cid, grade: Number($('gradeSel').value) }); break;
                case 'setpay': {
                    const v = readAmount('payIn');
                    if (v === null) { say(t('bad_amount'), false); return; }
                    act('setpay', { grade: Number(d.grade), amount: v });
                    break;
                }
                case 'deposit':
                case 'withdraw': {
                    const v = readAmount('amt');
                    if (!v) { say(t('bad_amount'), false); return; }
                    act(d.do, { amount: v });
                    break;
                }
            }
            return;
        }
        const r = e.target.closest('[data-sel]');
        if (r) {
            sel = r.dataset.sel;
            render();
        }
    });
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && screen) close();
    });

    // ---------- messages from the game ----------
    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'open') {
            L = m.L || {};
            screen = m.screen;
            state = m.state;
            tab = m.tab || null;
            sel = null;
            nearby = null;
            root.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(m.lang));
            applyLocale();
            say('');
            root.classList.remove('mc-hidden');
            render();
        } else if (m.action === 'state') {
            state = m.state;
            render();
        } else if (m.action === 'close') {
            root.classList.add('mc-hidden');
            screen = null;
        }
    });
})();
