// MULTIhotel: the desk, room, guest, invite, credit and eviction pages.
// Same page style and theme as the other MULTI scripts. Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
(function () {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const root = $('hotel');
    const menuPanel = $('hotel-menu');
    const inputPanel = $('input-dialog');
    const confirmPanel = $('confirm-dialog');

    // English fallback. client.lua sends the full table through _LT() when available.
    const FALLBACK = {
        ui_subtitle: 'Guest Services',
        ui_back: 'Back',
        ui_close: 'Close',
        ui_cancel: 'Cancel',
        ui_confirm: 'Confirm',
        ui_amount: 'Amount',
        ui_max: 'Max',
        ui_valid_amount: 'Please enter a valid amount',
        ui_success: 'Success',
        ui_error: 'Error',
        ui_info: 'Info',
        ui_notice: 'Notice'
    };

    let L = Object.assign({}, FALLBACK);
    let currentMenuId = null;
    let currentMenu = null;
    let history = [];            // menu ids stacked for the Back arrow
    let ignoreHistoryOnce = false;
    let inputCtx = null;
    let confirmCtx = null;

    // locale line: %s / %d markers are filled in order, %% is a literal %
    function t(key, ...args) {
        let i = 0;
        const s = L[key] != null ? String(L[key]) : (FALLBACK[key] != null ? FALLBACK[key] : key);
        return s.replace(/%%|%[sd]/g, (m) => (m === '%%' ? '%' : (args[i++] ?? '')));
    }
    function applyLocale() {
        document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
        document.querySelectorAll('[data-lp]').forEach((el) => { el.placeholder = t(el.dataset.lp); });
    }
    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, (ch) =>
            ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    }
    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIhotel';
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then((r) => r.json()).catch(() => ({}));
    }
    function say(id, text, ok) {
        const m = $(id);
        m.textContent = text || '';
        m.className = 'msg ' + (text ? (ok ? 'ok' : 'bad') : '');
    }
    function show(panel) {
        menuPanel.classList.add('mc-hidden');
        inputPanel.classList.add('mc-hidden');
        confirmPanel.classList.add('mc-hidden');
        panel.classList.remove('mc-hidden');
    }
    function hidePanels() {
        menuPanel.classList.add('mc-hidden');
        inputPanel.classList.add('mc-hidden');
        confirmPanel.classList.add('mc-hidden');
    }

    // ------------------------------------------------------------------ menu
    function renderOptions(options) {
        $('listHead').textContent = '';
        $('options').innerHTML = (options || []).map((o, i) => {
            if (o.separator) {
                return `<div class="mc-row sep"><div class="main"><h3 class="mc-heading">${esc(o.label || '')}</h3></div></div>`;
            }
            const main = `<b>${esc(o.title || '')}</b>` +
                (o.description ? `<span class="mc-sub">${esc(o.description)}</span>` : '');
            const side = (o.badge ? `<span class="pill">${esc(o.badge)}</span>` : '') +
                (o.arrow ? '<span class="arrow">&#8250;</span>' : '');
            return `<div class="mc-row${o.disabled ? ' disabled' : ''}" data-idx="${i}">` +
                `<div class="main">${main}</div><div class="side">${side}</div></div>`;
        }).join('');
    }

    function openMenu(data) {
        if (data.L) L = Object.assign({}, FALLBACK, data.L);
        applyLocale();
        root.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(data.lang || ''));

        // top-level menus start a fresh trail; submenus remember where they came from
        if (!data.showBack) {
            history = [];
        } else if (!ignoreHistoryOnce && currentMenuId && currentMenuId !== data.menuId) {
            history.push(currentMenuId);
        }
        ignoreHistoryOnce = false;

        currentMenu = data;
        currentMenuId = data.menuId || null;

        $('title').textContent = data.title || t('ui_info');
        $('subtitle').textContent = data.subtitle || t('ui_subtitle');

        const badge = $('badge');
        if (data.badge) {
            badge.textContent = data.badge;
            badge.classList.remove('mc-hidden');
        } else {
            badge.classList.add('mc-hidden');
        }

        $('backBtn').classList.toggle('mc-hidden', !(data.showBack && history.length > 0));
        renderOptions(data.options);
        say('menuMsg', '', false);
        show(menuPanel);
    }

    function optionAt(idx) {
        return currentMenu && currentMenu.options ? currentMenu.options[Number(idx)] : null;
    }
    function choose(idx) {
        const o = optionAt(idx);
        if (!o || o.disabled || o.separator) return;
        post('menuOptionSelected', {
            menuId: currentMenuId,
            optionId: o.id,
            action: o.action,
            args: o.args
        });
    }
    function goBack() {
        if (!history.length) return;
        const previousMenu = history.pop();
        ignoreHistoryOnce = true;
        post('goBack', { previousMenu: previousMenu });
    }
    function closeFromUser() {
        hidePanels();
        history = [];
        post('closeMenu', {});
    }
    function closeFromLua() {
        hidePanels();
        // keep the trail: Lua closes and reopens the panel when moving between menus
    }

    // ------------------------------------------------------------------ input
    function quickValues(data) {
        const max = Number(data.max) || 999999;
        const vals = [25, 50, 100].filter((v) => v <= max);
        if (max > 0 && vals.indexOf(max) === -1) vals.push(max);
        return vals;
    }
    function openInput(data) {
        inputCtx = data || {};
        $('inputTitle').textContent = inputCtx.title || t('ui_amount');
        $('inputLabel').textContent = inputCtx.label || t('ui_amount');
        const input = $('inputField');
        input.value = '';
        input.min = inputCtx.min != null ? inputCtx.min : 1;
        input.max = inputCtx.max != null ? inputCtx.max : 999999;
        input.placeholder = inputCtx.placeholder || '0';
        const max = Number(inputCtx.max) || 999999;
        $('quick').innerHTML = quickValues(inputCtx).map((v) =>
            `<button type="button" class="mc-btn small" data-quick="${v}">${v === max ? esc(t('ui_max')) : v}</button>`
        ).join('');
        say('inputMsg', '', false);
        show(inputPanel);
        setTimeout(() => { input.focus(); input.select(); }, 50);
    }
    function submitInput() {
        const input = $('inputField');
        const value = parseInt(input.value, 10);
        if (isNaN(value) || value < 1) {
            say('inputMsg', t('ui_valid_amount'), false);
            return;
        }
        hidePanels();
        post('inputSubmitted', { value: value });
    }
    function cancelInput() {
        hidePanels();
        post('inputCancelled', {});
    }

    // ------------------------------------------------------------------ confirm
    function openConfirm(data) {
        confirmCtx = data || {};
        $('confirmTitle').textContent = confirmCtx.title || t('ui_confirm');
        $('confirmMessage').textContent = confirmCtx.message || '';
        say('confirmMsg', '', false);
        show(confirmPanel);
    }
    function acceptConfirm() {
        hidePanels();
        post('confirmAccepted', {});
    }
    function cancelConfirm() {
        hidePanels();
        post('confirmCancelled', {});
    }

    // ------------------------------------------------------------------ toasts
    function showToast(message, type) {
        type = ['success', 'error', 'info'].indexOf(type) === -1 ? 'info' : type;
        const el = document.createElement('div');
        el.className = 'toast ' + type;
        el.innerHTML = `<div class="toast-label">${esc(t('ui_' + type))}</div>` +
            `<div class="toast-msg">${esc(message)}</div>`;
        $('toasts').appendChild(el);
        setTimeout(() => {
            el.classList.add('hiding');
            setTimeout(() => el.remove(), 200);
        }, 3200);
    }

    // ------------------------------------------------------------------ events
    document.addEventListener('click', (e) => {
        const row = e.target.closest('[data-idx]');
        if (row) { choose(row.dataset.idx); return; }

        const quick = e.target.closest('[data-quick]');
        if (quick) { $('inputField').value = quick.dataset.quick; return; }

        const id = e.target.id;
        if (id === 'backBtn') { goBack(); return; }
        if (id === 'closeBtn') { closeFromUser(); return; }
        if (id === 'inputSubmit') { submitInput(); return; }
        if (id === 'inputCancel') { cancelInput(); return; }
        if (id === 'confirmAccept') { acceptConfirm(); return; }
        if (id === 'confirmCancel') { cancelConfirm(); return; }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!confirmPanel.classList.contains('mc-hidden')) cancelConfirm();
            else if (!inputPanel.classList.contains('mc-hidden')) cancelInput();
            else if (!menuPanel.classList.contains('mc-hidden')) closeFromUser();
        } else if (e.key === 'Enter' && !inputPanel.classList.contains('mc-hidden')) {
            submitInput();
        }
    });

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        switch (m.action) {
            case 'openMenu': openMenu(m); break;
            case 'closeMenu': closeFromLua(); break;
            case 'openInputDialog': openInput(m); break;
            case 'openConfirmDialog': openConfirm(m); break;
            case 'showNotification': showToast(m.message, m.type || 'info'); break;
        }
    });

    applyLocale();
})();
