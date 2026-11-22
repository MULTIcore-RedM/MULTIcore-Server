// ============================================================================
// MULTIvendor NUI
// ============================================================================

let isClosing = false;
let closedByLua = false;

let state = {
    items: [],
    selectedItem: null,
    category: 'All',
    hasCategories: false,
};

const PLACEHOLDER_IMG = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="50" height="50"><rect x="2" y="2" width="46" height="46" fill="none" stroke="#ffffff" stroke-width="2"/><text x="25" y="34" font-size="26" text-anchor="middle" fill="#ffffff" font-family="serif">?</text></svg>');

const LANG = {};

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
function nuiFetch(endpoint, data) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then(r => r.json()).catch(e => console.error(e));
}

// Simple Lua-style string.format supporting sequential %s placeholders.
function fmt(str, ...args) {
    if (typeof str !== 'string') return '';
    let i = 0;
    return str.replace(/%s/g, () => (args[i] !== undefined ? String(args[i++]) : '%s'));
}

function money(value) {
    return state.currency + value.toFixed(2);
}

function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
}

// ----------------------------------------------------------------------------
// Open / close
// ----------------------------------------------------------------------------
function openSell(data) {
    state.currency = data.currency || '$';
    state.quickAmounts = data.quickAmounts || [1, 5, 10, 25, 50];
    state.showSellEverything = data.showSellEverything !== false;
    state.items = data.items || [];
    state.selectedItem = null;
    state.category = 'All';
    state.images = (data.images && data.images.length) ? data.images : ['nui://MULTIimages/images/'];
    closedByLua = false;

    document.body.classList.toggle('mc-cyrillic', !!data.cyrillic);
    Object.assign(LANG, data.lang || {});
    setText('vendorTitle', data.vendorName || 'Vendor');
    setText('closeBtn', LANG.close || 'Close');
    setText('availableHeading', LANG.select_item || 'Available Items');
    setText('sellHeading', LANG.sell || 'Sell');

    const totalValue = data.totalValue || 0;
    setText('sellEverythingBtn', (LANG.sell_everything || 'Sell Everything') + ' (' + money(totalValue) + ')');
    document.getElementById('sellEverythingBtn').classList.toggle('hidden', !state.showSellEverything);

    buildCategories();
    renderGrid();
    renderDetails();

    document.getElementById('vendorMenu').classList.add('active');
    isClosing = false;
}

function hideSell() {
    if (isClosing) return;
    isClosing = true;
    document.getElementById('vendorMenu').classList.remove('active');
    setTimeout(() => { isClosing = false; }, 300);
}

function closeSell() {
    hideSell();
    if (!closedByLua) {
        nuiFetch('close').catch(() => {});
    }
    closedByLua = false;
}

// ----------------------------------------------------------------------------
// Category tabs
// ----------------------------------------------------------------------------
function buildCategories() {
    const cats = [];
    state.items.forEach(i => {
        if (i.category && !cats.includes(i.category)) cats.push(i.category);
    });
    state.hasCategories = cats.length > 0;

    const container = document.getElementById('categoryTabs');
    container.innerHTML = '';
    if (!state.hasCategories) {
        container.classList.add('hidden');
        return;
    }
    container.classList.remove('hidden');

    const all = document.createElement('button');
    all.className = 'mc-tab active';
    all.textContent = LANG.all || 'All';
    all.onclick = () => selectCategory('All', all);
    container.appendChild(all);

    cats.sort().forEach(c => {
        const btn = document.createElement('button');
        btn.className = 'mc-tab';
        btn.textContent = c;
        btn.onclick = () => selectCategory(c, btn);
        container.appendChild(btn);
    });
}

function selectCategory(cat, btn) {
    state.category = cat;
    document.querySelectorAll('#categoryTabs .mc-tab').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');
    renderGrid();
}

// ----------------------------------------------------------------------------
// Item grid
// ----------------------------------------------------------------------------
function renderGrid() {
    const grid = document.getElementById('itemGrid');
    const filtered = state.hasCategories
        ? state.items.filter(i => state.category === 'All' || i.category === state.category)
        : state.items;

    if (filtered.length === 0) {
        grid.innerHTML = `<p class="empty-state">${LANG.no_items || 'No items to sell'}</p>`;
        return;
    }

    let html = '';
    filtered.forEach(it => {
        const sel = state.selectedItem && state.selectedItem.item === it.item ? ' selected' : '';
        html += `
        <div class="item-card${sel}" data-item="${it.item.replace(/"/g, '&quot;')}">
            <img class="item-image" src="${itemImgSrc(it)}" data-image="${escapeHtml(it.image || "")}" onerror="imageFallback(this)">
            <div class="item-name">${escapeHtml(it.label || it.item)}</div>
            <div class="item-price">${money(it.price)}</div>
            <div class="item-stock">${fmt(LANG.owned || 'x%s', it.count)}</div>
        </div>`;
    });
    grid.innerHTML = html;

    grid.querySelectorAll('.item-card').forEach(card => {
        card.onclick = () => {
            const itemName = card.getAttribute('data-item');
            const item = state.items.find(i => i.item === itemName);
            if (item) selectItem(item);
        };
    });
}

function itemImgSrc(it) {
    if (it.image) {
        return imageUrl(0, it.image);
    }
    return PLACEHOLDER_IMG;
}

function imageFile(image) {
    return /\.(png|jpe?g|webp|gif)$/i.test(image) ? image : image + '.png';
}

function imageUrl(index, image) {
    let folder = state.images[index] || '';
    if (folder && !folder.endsWith('/')) folder += '/';
    return folder + imageFile(image);
}

// Try the next picture folder, then the placeholder.
function imageFallback(img) {
    const image = img.getAttribute('data-image');
    const next = parseInt(img.getAttribute('data-try') || '0', 10) + 1;
    if (image && next < state.images.length) {
        img.setAttribute('data-try', String(next));
        img.src = imageUrl(next, image);
        return;
    }
    img.onerror = null;
    img.src = PLACEHOLDER_IMG;
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function selectItem(item) {
    state.selectedItem = item;
    document.querySelectorAll('#itemGrid .item-card').forEach(c => {
        c.classList.toggle('selected', c.getAttribute('data-item') === item.item);
    });
    renderDetails();
}

// ----------------------------------------------------------------------------
// Details pane (sell controls)
// ----------------------------------------------------------------------------
function renderDetails() {
    const details = document.getElementById('sellDetails');
    if (!state.selectedItem) {
        details.innerHTML = `<p class="empty-state">${LANG.select_item || 'Select an item to sell'}</p>`;
        return;
    }

    const it = state.selectedItem;
    details.innerHTML = `
        <div class="info-card">
            <div class="info-row">${escapeHtml(it.label || it.item)}</div>
            <div class="info-row meta">${fmt(LANG.owned || 'x%s', it.count)} &middot; ${fmt(LANG.price_each, money(it.price))}</div>
        </div>

        <button class="mc-btn primary full-width" onclick="sellAmount('${it.item.replace(/'/g, '')}', ${it.count})">${LANG.sell_all || 'Sell All'} (${it.count}) &mdash; ${money(it.price * it.count)}</button>

        <div class="quick-grid">
            ${state.quickAmounts.map(a => a < it.count
                ? `<button class="mc-btn small" onclick="sellAmount('${it.item.replace(/'/g, '')}', ${a})">${a}x &mdash; ${money(it.price * a)}</button>`
                : '').join('')}
        </div>

        <hr class="divider">
        <h3 class="mc-heading sub-heading">${LANG.custom_amount || 'Custom Amount'}</h3>
        <input type="number" id="customAmount" class="mc-input amount-input" min="1" max="${it.count}" placeholder="${LANG.amount || 'Amount'} (1-${it.count})">
        <button class="mc-btn primary full-width" onclick="sellCustomAmount('${it.item.replace(/'/g, '')}', ${it.count})">${LANG.sell || 'Sell'}</button>
    `;
}

function sellAmount(item, amount) {
    nuiFetch('sellItem', { item: item, amount: amount }).catch(() => {});
    hideSell();
}

function sellCustomAmount(item, maxCount) {
    const input = document.getElementById('customAmount');
    let amount = parseInt(input.value, 10);
    if (isNaN(amount) || amount < 1) return;
    amount = Math.min(amount, maxCount);
    sellAmount(item, amount);
}

function confirmSellEverything() {
    const totalValue = state.items.reduce((sum, it) => sum + it.value, 0);
    const details = document.getElementById('sellDetails');
    details.innerHTML = `
        <p class="confirm-text">${fmt(LANG.confirm_sell_everything || 'Sell everything for %s?', money(totalValue))}</p>
        <button class="mc-btn primary full-width" onclick="doSellEverything()">${LANG.confirm || 'Confirm'}</button>
        <button class="mc-btn danger full-width" onclick="cancelSellEverything()">${LANG.cancel || 'Cancel'}</button>
    `;
}

function doSellEverything() {
    nuiFetch('sellAll', {}).catch(() => {});
    hideSell();
}

function cancelSellEverything() {
    renderDetails();
}

// ----------------------------------------------------------------------------
// Events
// ----------------------------------------------------------------------------
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    if (data.action === 'openSell') openSell(data);
    else if (data.action === 'forceCloseSell') { closedByLua = true; hideSell(); }
});

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('closeBtn').addEventListener('click', closeSell);
    document.getElementById('sellEverythingBtn').addEventListener('click', confirmSellEverything);
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeSell();
    });
});