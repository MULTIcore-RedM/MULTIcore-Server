// MULTImedic death screen. Shows what the client sends; the keys are read by the game (Lua).
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('death');
    let L = {};
    let st = { remaining: 0, medics: 0, cooldown: 0, call: true, showMedics: true, fee: 0, callState: '' };

    // locale line; %s / %d markers are filled in order, %% is a literal %
    function t(key, ...args) {
        let i = 0;
        const s = L[key] != null ? String(L[key]) : key;
        return s.replace(/%%|%[sd]/g, (m) => (m === '%%' ? '%' : (args[i++] ?? '')));
    }
    function applyLocale() {
        document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
    }
    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTImedic';
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false }));
    }
    function clock(sec) {
        sec = Math.max(0, Math.floor(sec));
        const m = Math.floor(sec / 60), s = sec % 60;
        return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    }

    const CALL_TEXT = { sending: 'ui_call_sending', sent: 'ui_call_sent', none: 'ui_call_none', cooldown: 'ui_call_wait', no_pos: 'ui_call_failed' };

    function render() {
        const done = st.remaining <= 0;
        $('timerBox').classList.toggle('mc-hidden', done);
        $('respawnBox').classList.toggle('mc-hidden', !done);
        $('clock').textContent = clock(st.remaining);
        $('sub').textContent = done ? t('ui_sub_ready') : t('ui_sub');
        $('feeLine').textContent = st.fee > 0 ? t('ui_fee', st.fee) : '';

        $('callBox').classList.toggle('mc-hidden', !st.call);
        $('callBtn').disabled = st.cooldown > 0;
        let status = st.callState && CALL_TEXT[st.callState] ? t(CALL_TEXT[st.callState]) : '';
        if (st.cooldown > 0) status = (status ? status + ' · ' : '') + t('ui_call_again', st.cooldown);
        $('callStatus').textContent = status;
        $('callStatus').classList.toggle('bad', st.callState === 'none' || st.callState === 'no_pos');
        $('medics').textContent = st.showMedics ? (st.medics > 0 ? t('ui_medics', st.medics) : t('ui_no_medics')) : '';
    }

    $('callBtn').addEventListener('click', () => { if (!$('callBtn').disabled) post('callDoctor'); });

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        switch (d.action) {
            case 'open':
                L = d.L || {};
                root.classList.toggle('mc-cyrillic', d.lang === 'ru');
                root.classList.toggle('cursor', !!d.cursor);
                st = {
                    remaining: d.remaining || 0, medics: d.medics || 0, cooldown: 0,
                    call: d.call !== false, showMedics: d.showMedics !== false, fee: d.fee || 0, callState: '',
                };
                if (d.keys) { $('keyRespawn').textContent = d.keys.respawn || 'E'; $('keyCall').textContent = d.keys.call || 'G'; }
                $('holdFill').style.width = '0%';
                applyLocale();
                render();
                root.classList.remove('mc-hidden');
                break;
            case 'tick':
                st.remaining = d.remaining ?? st.remaining;
                st.medics = d.medics ?? st.medics;
                st.cooldown = d.cooldown ?? 0;
                if (st.cooldown <= 0 && st.callState === 'cooldown') st.callState = '';
                render();
                break;
            case 'hold':
                $('holdFill').style.width = `${Math.round((d.progress || 0) * 100)}%`;
                break;
            case 'call':
                st.callState = d.state || '';
                if (d.cooldown != null) st.cooldown = d.cooldown;
                render();
                break;
            case 'close':
                root.classList.add('mc-hidden');
                break;
        }
    });
})();
