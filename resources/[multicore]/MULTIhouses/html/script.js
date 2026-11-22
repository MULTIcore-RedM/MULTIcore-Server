// MULTIhouses house page, drawn in MULTIcore's look. Every text comes from locales/<lang>.lua (setLocale).
const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'MULTIhouses';

let Locale = {};
let menuHistory = [];
let currentHouseId = null;
let currentHouseName = '';
let currentDialogCallback = null;

// one line in the chosen language; %s / %d are filled in order
function t(key, ...args) {
    let text = (Locale && Locale[key]) || key;
    let i = 0;
    return String(text).replace(/%[sd]/g, function (m) { return i < args.length ? String(args[i++]) : m; });
}

function applyStaticLocale() {
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
        const key = el.getAttribute('data-i18n');
        if (Locale[key]) el.textContent = Locale[key];
    });
    document.querySelectorAll('[data-i18n-aria]').forEach(function (el) {
        const key = el.getAttribute('data-i18n-aria');
        if (Locale[key]) el.setAttribute('aria-label', Locale[key]);
    });
}

function escapeHtml(text) {
    if (text === null || text === undefined) return '';
    return String(text)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function formatNumber(num) {
    if (num === null || num === undefined) return '0';
    return String(num).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function money(num) { return '$' + formatNumber(num); }

function postNUI(endpoint, data) {
    return fetch('https://' + RESOURCE + '/' + endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

function el(id) { return document.getElementById(id); }

document.addEventListener('DOMContentLoaded', function () {
    el('close-btn').addEventListener('click', closeUI);
    el('back-btn').addEventListener('click', goBack);
    el('dialog-cancel').addEventListener('click', closeDialog);
    el('dialog-confirm').addEventListener('click', confirmDialog);

    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape') return;
        if (!el('input-dialog').classList.contains('hidden')) closeDialog();
        else if (!el('housing-ui').classList.contains('hidden')) closeUI();
    });
});

window.addEventListener('message', function (event) {
    const data = event.data || {};
    switch (data.action) {
        case 'setLocale':
            Locale = data.locale || {};
            document.body.classList.toggle('mc-cyrillic', data.lang === 'ru');
            applyStaticLocale();
            break;
        case 'openMenu': openMenu(data.menu, data.data); break;
        case 'closeMenu': hideUI(); break;
        case 'showNotification': showNotification(data.title, data.message, data.type); break;
        case 'updateGuests': renderRemoveGuestMenu(data.guests, data.houseId); break;
        case 'updateCredit': renderCreditMenu(data.houseId, data.houseName, data.credit); break;
        case 'updateBalance': renderBalanceMenu(data.houseId, data.houseName, data.balance); break;
        case 'showSellConfirm': confirmSellHouse(data.houseId, data.houseName, data.sellprice, data.balance, data.payout); break;
    }
});

// ------------------------------------------------------------ building blocks
function rowHtml(id, icon, title, desc, extraClass) {
    return '<div class="menu-item ' + (extraClass || '') + '" id="' + id + '">' +
        '<div class="item-header">' +
            '<div class="item-icon"><i class="fas ' + icon + '"></i></div>' +
            '<span class="item-title">' + escapeHtml(title) + '</span>' +
        '</div>' +
        (desc ? '<div class="item-description">' + escapeHtml(desc) + '</div>' : '') +
        '<span class="item-arrow"><i class="fas fa-chevron-right"></i></span>' +
    '</div>';
}

function cardHtml(name, details) {
    let html = '<div class="property-card"><div class="property-name"><i class="fas fa-house"></i>' + escapeHtml(name) + '</div><div class="property-details">';
    details.forEach(function (d) {
        html += '<div class="property-detail">' + escapeHtml(d[0]) + ' <span>' + escapeHtml(d[1]) + '</span></div>';
    });
    return html + '</div></div>';
}

function loadingHtml(text) {
    return '<div class="loading"><div class="loading-spinner"></div><div class="loading-text">' + escapeHtml(text) + '</div></div>';
}

function onClick(id, fn) {
    const node = el(id);
    if (node) node.addEventListener('click', fn);
}

function setTitle(key, showBack) {
    el('menu-title').textContent = t(key);
    el('back-btn').classList.toggle('hidden', !showBack);
}

function showDialog(titleKey, html, callback) {
    el('dialog-title').textContent = t(titleKey);
    el('dialog-content').innerHTML = html;
    el('input-dialog').classList.remove('hidden');
    currentDialogCallback = callback;
}

// ------------------------------------------------------------ open / close
function hideUI() {
    el('housing-ui').classList.add('hidden');
    el('input-dialog').classList.add('hidden');
    currentDialogCallback = null;
    menuHistory = [];
    currentHouseId = null;
    currentHouseName = '';
}

function openMenu(menuType, data) {
    data = data || {};
    el('housing-ui').classList.remove('hidden');
    menuHistory = [];
    currentHouseId = data.houseId || null;
    currentHouseName = data.houseName || currentHouseId || '';
    if (menuType === 'buyAtHouse') renderBuyAtHouse(data);
    else if (menuType === 'houseMenu') renderHouseMenu(data);
}

function closeUI() {
    hideUI();
    postNUI('closeUI', {});
}

function goBack() {
    const prev = menuHistory.pop();
    if (!prev) { closeUI(); return; }
    if (prev.menu === 'houseMenu') renderHouseMenu(prev.data);
    else if (prev.menu === 'guestMenu') renderGuestMenu(prev.data.houseId);
    else closeUI();
}

function pushHistory(menu, data) { menuHistory.push({ menu: menu, data: data }); }

// ------------------------------------------------------------ buying
function renderBuyAtHouse(d) {
    setTitle('nui_title_buy', false);
    const details = [[t('nui_price'), money(d.price)]];
    if (d.balance > 0) {
        details.push([t('nui_deposit'), money(d.deposit)]);
        details.push([t('nui_balance'), money(d.balance)]);
    }
    details.push([t('nui_sell_back'), money(d.sellprice)]);
    if (d.tax > 0) details.push([t('nui_tax'), t('nui_tax_per_cycle', formatNumber(d.tax))]);
    el('menu-content').innerHTML = cardHtml(d.houseName, details) +
        rowHtml('btn-confirm-buy', 'fa-check', t('nui_buy_for', money(d.balance > 0 ? d.deposit : d.price)), t('nui_buy_desc'));
    onClick('btn-confirm-buy', function () { confirmBuyHouse(d); });
}

function confirmBuyHouse(d) {
    const details = [[t('nui_price'), money(d.price)]];
    if (d.balance > 0) {
        details.push([t('nui_deposit_now'), money(d.deposit)]);
        details.push([t('nui_balance_owed'), money(d.balance)]);
    }
    showDialog('nui_confirm_buy', cardHtml(d.houseName, details) + '<p class="dialog-text">' + escapeHtml(t('nui_confirm_buy_text')) + '</p>', function () {
        postNUI('buyHouse', { house: d.houseId });
    });
}

// ------------------------------------------------------------ selling / releasing
function confirmSellHouse(houseId, houseName, sellprice, balance, payout) {
    const details = [[t('nui_sale_price'), money(sellprice)]];
    if (balance > 0) {
        details.push([t('nui_balance_owed'), money(balance)]);
        details.push([t('nui_you_get'), money(payout)]);
    }
    showDialog('nui_confirm_sale', cardHtml(houseName, details) + '<p class="dialog-text warn">' + escapeHtml(t('nui_cannot_undo')) + '</p>', function () {
        postNUI('sellHouse', { house: houseId });
    });
}

function confirmReleaseHouse(houseId) {
    showDialog('nui_release_title', cardHtml(currentHouseName || houseId, [[t('nui_payment'), t('nui_none')]]) +
        '<p class="dialog-text warn">' + escapeHtml(t('nui_release_text')) + '</p>', function () {
        postNUI('releaseHouse', { houseid: houseId });
    });
}

// ------------------------------------------------------------ house menu
function renderHouseMenu(d) {
    currentHouseId = d.houseId;
    currentHouseName = d.houseName || d.houseId;
    const houseId = d.houseId;
    setTitle(d.isGuest ? 'nui_title_guest' : 'nui_title_house', false);
    const content = el('menu-content');

    if (d.isGuest) {
        content.innerHTML = cardHtml(currentHouseName, [[t('nui_status'), t('nui_status_guest')]]) +
            rowHtml('btn-storage', 'fa-box', t('nui_storage'), t('nui_storage_desc')) +
            rowHtml('btn-outfits', 'fa-hat-cowboy-side', t('nui_outfits'), t('nui_outfits_desc'));
        onClick('btn-storage', function () { postNUI('openStorage', { house: houseId }); });
        onClick('btn-outfits', function () { postNUI('openOutfits', { house: houseId }); });
        return;
    }

    if (d.hasBalance) {
        content.innerHTML = cardHtml(currentHouseName, [[t('nui_status'), t('nui_status_owner_balance')]]) +
            rowHtml('btn-balance', 'fa-hand-holding-dollar', t('nui_pay_balance'), t('nui_pay_balance_desc')) +
            rowHtml('btn-sell', 'fa-sign-hanging', t('nui_sell'), t('nui_sell_desc')) +
            rowHtml('btn-release', 'fa-trash-can', t('nui_release'), t('nui_release_desc'), 'danger-item');
    } else {
        content.innerHTML = cardHtml(currentHouseName, [[t('nui_status'), t('nui_status_owner')]]) +
            rowHtml('btn-guests', 'fa-users', t('nui_guests'), t('nui_guests_desc')) +
            rowHtml('btn-credit', 'fa-dollar-sign', t('nui_tax_menu'), t('nui_tax_menu_desc')) +
            rowHtml('btn-storage', 'fa-box', t('nui_storage'), t('nui_storage_desc')) +
            rowHtml('btn-outfits', 'fa-hat-cowboy-side', t('nui_outfits'), t('nui_outfits_desc')) +
            rowHtml('btn-mail', 'fa-envelope', t('nui_mail'), t('nui_mail_desc')) +
            rowHtml('btn-sell', 'fa-sign-hanging', t('nui_sell'), t('nui_sell_desc')) +
            rowHtml('btn-release', 'fa-trash-can', t('nui_release'), t('nui_release_desc'), 'danger-item');
    }

    const self = { houseId: houseId, houseName: currentHouseName, isGuest: false, hasBalance: d.hasBalance };
    onClick('btn-balance', function () { pushHistory('houseMenu', self); openBalance(houseId); });
    onClick('btn-guests', function () { pushHistory('houseMenu', self); renderGuestMenu(houseId); });
    onClick('btn-credit', function () { pushHistory('houseMenu', self); openCredit(houseId); });
    onClick('btn-storage', function () { postNUI('openStorage', { house: houseId }); });
    onClick('btn-outfits', function () { postNUI('openOutfits', { house: houseId }); });
    onClick('btn-mail', function () { postNUI('openMail', {}); });
    onClick('btn-sell', function () { postNUI('getSellInfo', { house: houseId }); });
    onClick('btn-release', function () { confirmReleaseHouse(houseId); });
}

// ------------------------------------------------------------ guests
function renderGuestMenu(houseId) {
    currentHouseId = houseId;
    setTitle('nui_title_guests', true);
    el('menu-content').innerHTML =
        rowHtml('btn-add-guest', 'fa-user-plus', t('nui_add_guest'), t('nui_add_guest_desc')) +
        rowHtml('btn-remove-guest', 'fa-user-minus', t('nui_remove_guest'), t('nui_remove_guest_desc'));
    onClick('btn-add-guest', function () { showAddGuestDialog(houseId); });
    onClick('btn-remove-guest', function () {
        pushHistory('guestMenu', { houseId: houseId });
        setTitle('nui_remove_guest', true);
        el('menu-content').innerHTML = loadingHtml(t('nui_loading'));
        postNUI('getGuests', { houseid: houseId });
    });
}

function showAddGuestDialog(houseId) {
    showDialog('nui_add_guest', '<div class="input-group">' +
        '<label for="guest-cid">' + escapeHtml(t('nui_citizen_id')) + '</label>' +
        '<input type="text" id="guest-cid" style="text-transform: uppercase;">' +
        '<p class="input-description">' + escapeHtml(t('nui_citizen_id_desc')) + '</p>' +
    '</div>', function () {
        const input = el('guest-cid');
        const cid = input ? input.value.toUpperCase().trim() : '';
        if (cid) postNUI('addGuest', { citizenid: cid, houseid: houseId });
        else showNotification(t('nui_error'), t('nui_enter_citizen_id'), 'error');
    });
    setTimeout(function () { const i = el('guest-cid'); if (i) i.focus(); }, 100);
}

function renderRemoveGuestMenu(guests, houseId) {
    setTitle('nui_remove_guest', true);
    const content = el('menu-content');
    if (!guests || guests.length === 0) {
        content.innerHTML = '<div class="no-items"><i class="fas fa-users"></i><p>' + escapeHtml(t('nui_no_guests')) + '</p></div>';
        return;
    }
    let html = '';
    guests.forEach(function (g, i) { html += rowHtml('guest-' + i, 'fa-user', g.citizenid, t('nui_click_remove')); });
    content.innerHTML = html;
    guests.forEach(function (g, i) {
        onClick('guest-' + i, function () {
            showDialog('nui_remove_guest',
                '<p class="dialog-text">' + escapeHtml(t('nui_remove_access_for')) + '</p>' +
                '<p class="dialog-text big">' + escapeHtml(g.citizenid) + '</p>' +
                '<p class="dialog-text">' + escapeHtml(t('nui_remove_access_text')) + '</p>', function () {
                postNUI('removeGuest', { citizenid: g.citizenid, houseid: houseId });
            });
        });
    });
}

// ------------------------------------------------------------ property tax credit
function openCredit(houseId) {
    setTitle('nui_tax_menu', true);
    el('menu-content').innerHTML = loadingHtml(t('nui_loading'));
    postNUI('getCredit', { houseid: houseId });
}

function renderCreditMenu(houseId, houseName, credit) {
    const creditNum = parseInt(credit) || 0;
    setTitle('nui_tax_menu', true);
    el('menu-content').innerHTML =
        '<div class="credit-display"><div class="credit-amount">' + money(creditNum) + '</div>' +
        '<div class="credit-label">' + escapeHtml(t('nui_current_credit')) + '</div></div>' +
        rowHtml('btn-add-credit', 'fa-plus', t('nui_add_credit'), t('nui_add_credit_desc')) +
        rowHtml('btn-remove-credit', 'fa-minus', t('nui_withdraw_credit'), t('nui_withdraw_credit_desc'));
    onClick('btn-add-credit', function () { showAmountDialog('add', houseId, creditNum); });
    onClick('btn-remove-credit', function () { showAmountDialog('remove', houseId, creditNum); });
}

function showAmountDialog(kind, houseId, current) {
    const isAdd = kind === 'add';
    const isPay = kind === 'pay';
    const titleKey = isPay ? 'nui_pay_balance' : (isAdd ? 'nui_add_credit' : 'nui_withdraw_credit');
    const desc = isPay ? t('nui_pay_amount_desc', formatNumber(current))
        : (isAdd ? t('nui_add_amount_desc') : t('nui_withdraw_amount_desc', formatNumber(current)));
    const start = isPay ? current : 50;
    showDialog(titleKey, '<div class="input-group">' +
        '<label for="amount-input">' + escapeHtml(t('nui_amount')) + '</label>' +
        '<input type="number" id="amount-input" value="' + start + '" min="1">' +
        '<p class="input-description">' + escapeHtml(desc) + '</p>' +
    '</div>', function () {
        const input = el('amount-input');
        const amount = input ? parseInt(input.value) : 0;
        if (!amount || amount <= 0) { showNotification(t('nui_error'), t('nui_bad_amount'), 'error'); return; }
        if (!isAdd && amount > current) {
            showNotification(t('nui_error'), isPay ? t('nui_amount_over_balance') : t('nui_amount_over_credit'), 'error');
            return;
        }
        postNUI(isPay ? 'payBalance' : (isAdd ? 'addCredit' : 'removeCredit'), { houseid: houseId, amount: amount });
    });
    setTimeout(function () { const i = el('amount-input'); if (i) { i.focus(); i.select(); } }, 100);
}

// ------------------------------------------------------------ balance
function openBalance(houseId) {
    setTitle('nui_pay_balance', true);
    el('menu-content').innerHTML = loadingHtml(t('nui_loading'));
    postNUI('getBalance', { houseid: houseId });
}

function renderBalanceMenu(houseId, houseName, balance) {
    const balanceNum = parseInt(balance) || 0;
    setTitle('nui_pay_balance', true);
    const content = el('menu-content');
    if (balanceNum <= 0) {
        content.innerHTML = '<div class="no-items"><i class="fas fa-check"></i><p>' + escapeHtml(t('nui_no_balance')) + '</p></div>';
        return;
    }
    content.innerHTML =
        '<div class="credit-display"><div class="credit-amount">' + money(balanceNum) + '</div>' +
        '<div class="credit-label">' + escapeHtml(t('nui_outstanding')) + '</div></div>' +
        rowHtml('btn-pay-balance', 'fa-hand-holding-dollar', t('nui_pay_balance'), t('nui_pay_balance_desc'));
    onClick('btn-pay-balance', function () { showAmountDialog('pay', houseId, balanceNum); });
}

// ------------------------------------------------------------ dialog and page notices
function closeDialog() {
    el('input-dialog').classList.add('hidden');
    currentDialogCallback = null;
}

function confirmDialog() {
    const fn = currentDialogCallback;
    closeDialog();
    if (fn) fn();
}

function showNotification(title, message, type) {
    const box = document.createElement('div');
    box.className = 'notification ' + (type || 'info');
    box.innerHTML = '<div class="notification-content">' +
        '<div class="notification-title">' + escapeHtml(title) + '</div>' +
        '<div class="notification-message">' + escapeHtml(message) + '</div></div>';
    el('notification-container').appendChild(box);
    setTimeout(function () {
        box.classList.add('hide');
        setTimeout(function () { if (box.parentNode) box.parentNode.removeChild(box); }, 300);
    }, 4000);
}
