/* MULTIwagons dealer and chop shop page. Based on Phil's wagon dealer page.
   GPL v3, part of MULTIcore by RINGO (RINGOscripting). */
(function () {
    'use strict';

    var RESOURCE = typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : 'MULTIwagons';
    var IMAGES = 'nui://' + RESOURCE + '/images/';
    var T = {};

    function $(id) { return document.getElementById(id); }

    // one line of text; %s markers are filled in order
    function t(key) {
        var text = T[key] != null ? String(T[key]) : key;
        for (var i = 1; i < arguments.length; i++) text = text.replace(/%[sd]/, String(arguments[i]));
        return text;
    }

    function applyText(data) {
        if (data && data.text) T = data.text;
        document.querySelectorAll('[data-t]').forEach(function (el) { el.textContent = t(el.getAttribute('data-t')); });
        document.querySelectorAll('[data-ph]').forEach(function (el) { el.placeholder = t(el.getAttribute('data-ph')); });
        document.querySelectorAll('[data-title]').forEach(function (el) { el.title = t(el.getAttribute('data-title')); });
        if (data && data.lang) {
            document.querySelectorAll('.mc-root').forEach(function (el) { el.classList.toggle('mc-cyrillic', data.lang === 'ru'); });
        }
    }

    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text != null) e.textContent = text;
        return e;
    }

    function show(node, on) { node.classList.toggle('mc-hidden', !on); }

    var WagonShop = {
        isOpen: false,
        store: null,
        categories: [],
        wagons: [],
        myWagons: [],
        selectedMyWagon: null,
        playerMoney: { cash: 0, gold: 0 },
        prices: {},
        currency: '$',
        nameMax: 16,
        selectedCustomType: null,
        selectedCustomValue: null,
        pendingNameWagon: null,
        pendingConfirm: null,
        pendingChop: null,

        init: function () {
            this.bindEvents();
            this.listen();
        },

        money: function (n) { return this.currency + (Number(n) || 0); },

        bindEvents: function () {
            var self = this;
            $('close-btn').addEventListener('click', function () { self.close(); });
            $('header-back').addEventListener('click', function () {
                if (!$('view-chop').classList.contains('mc-hidden')) { self.close(); return; }
                var wrapper = $('wagon-grid-wrapper');
                if (!wrapper.classList.contains('mc-hidden')) {
                    self.backToCategories();
                } else {
                    self.setTab('store');
                }
            });

            $('rotate-left').addEventListener('click', function () { self.post('rotateWagon', { direction: 'left' }); });
            $('rotate-right').addEventListener('click', function () { self.post('rotateWagon', { direction: 'right' }); });
            $('btn-back-category').addEventListener('click', function () { self.backToCategories(); });
            $('btn-back-customize').addEventListener('click', function () { self.backFromCustomize(); });
            $('btn-cancel-customize').addEventListener('click', function () { self.backFromCustomize(); });
            $('btn-save-customize').addEventListener('click', function () { self.saveCustomization(); });

            $('name-modal-cancel').addEventListener('click', function () { self.closeNameModal(); });
            $('name-modal-confirm').addEventListener('click', function () { self.confirmName(); });
            $('confirm-modal-cancel').addEventListener('click', function () { self.closeConfirmModal(); });
            $('confirm-modal-confirm').addEventListener('click', function () { self.confirmAction(); });

            $('btn-chop-cancel').addEventListener('click', function () { self.close(); });
            $('btn-chop-confirm').addEventListener('click', function () { self.confirmChop(); });

            document.querySelectorAll('#nav-tabs .mc-tab').forEach(function (btn) {
                btn.addEventListener('click', function () { self.setTab(btn.dataset.view); });
            });

            document.addEventListener('keydown', function (e) {
                if (e.key !== 'Escape') return;
                if (!$('name-modal').classList.contains('mc-hidden')) { self.closeNameModal(); return; }
                if (!$('confirm-modal').classList.contains('mc-hidden')) { self.closeConfirmModal(); return; }
                if (self.isOpen) self.close();
            });

            $('name-input').addEventListener('keydown', function (e) { if (e.key === 'Enter') self.confirmName(); });
        },

        listen: function () {
            var self = this;
            window.addEventListener('message', function (event) {
                var data = event.data;
                if (!data || !data.action) return;
                switch (data.action) {
                    case 'openStore': self.openStore(data); break;
                    case 'openChop': self.openChop(data); break;
                    case 'close': self.hide(); break;
                    case 'showWagons': self.showWagons(data.wagons); break;
                    case 'updateMoney': self.updateMoney(data.cash, data.gold); break;
                    case 'showMyWagons': self.showMyWagons(data.wagons); break;
                    case 'showCustomOptions': self.showCustomOptions(data.type, data.options, data.price, data.multi, data.categories); break;
                    case 'notify': self.showNotification(data.type, data.title, data.message); break;
                }
            });
        },

        post: function (endpoint, data) {
            return fetch('https://' + RESOURCE + '/' + endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data || {})
            }).catch(function () {});
        },

        setTab: function (view) {
            document.querySelectorAll('#nav-tabs .mc-tab').forEach(function (b) { b.classList.toggle('active', b.dataset.view === view); });
            this.switchView(view);
        },

        backToCategories: function () {
            show($('wagon-grid-wrapper'), false);
            show($('category-grid'), true);
            this.updateFooter(t('ui_hint_store'));
        },

        openStore: function (data) {
            applyText(data);
            this.store = data.store;
            this.categories = data.categories || [];
            this.wagons = [];
            this.playerMoney = data.playerMoney || { cash: 0, gold: 0 };
            this.prices = data.prices || {};
            this.currency = data.currency || '$';
            this.nameMax = data.nameMax || 16;
            $('name-input').maxLength = this.nameMax;
            this.isOpen = true;

            $('shop-name').textContent = t('ui_shop_title');
            $('shop-subtitle').textContent = t('ui_shop_sub');
            show($('nav-tabs'), true);
            show($('money-bar'), true);
            show($('rotate-buttons'), true);
            this.updateMoneyDisplay();
            this.renderCategories();
            this.backToCategories();
            this.setTab('store');
            show($('shop-container'), true);
        },

        renderCategories: function () {
            var self = this;
            var grid = $('category-grid');
            grid.innerHTML = '';
            this.categories.forEach(function (cat) {
                var card = el('div', 'category-card');
                var img = el('img');
                img.src = IMAGES + (cat.image || 'wagon.png');
                img.alt = '';
                img.onerror = function () { img.onerror = null; img.src = IMAGES + 'wagon.png'; img.style.filter = 'none'; };
                card.appendChild(img);
                card.appendChild(el('div', 'category-name', cat.label));
                card.addEventListener('click', function () { self.selectCategory(cat); });
                grid.appendChild(card);
            });
        },

        selectCategory: function (cat) {
            this.post('getWagonsByType', { type: cat.type, store: this.store });
            $('category-title').textContent = cat.label;
            show($('category-grid'), false);
            show($('wagon-grid-wrapper'), true);
            this.updateFooter(t('ui_hint_wagons'));
        },

        showWagons: function (wagons) {
            var self = this;
            this.wagons = wagons || [];
            var grid = $('wagon-grid');
            grid.innerHTML = '';
            if (this.wagons.length === 0) {
                show(grid, false);
                show($('no-wagons'), true);
                return;
            }
            show(grid, true);
            show($('no-wagons'), false);

            this.wagons.forEach(function (w, idx) {
                var card = el('div', 'wagon-card' + (idx === 0 ? ' selected' : ''));
                var stats = [];
                if (w.slots) stats.push(t('ui_slots', w.slots));
                if (w.maxWeight) stats.push(t('ui_weight', w.maxWeight));
                if (w.maxAnimals) stats.push(t('ui_animals', w.maxAnimals));

                var img = el('img');
                img.src = IMAGES + 'wagon.png';
                img.alt = '';
                card.appendChild(img);
                card.appendChild(el('div', 'wagon-name', w.name || w.model));
                card.appendChild(el('div', 'mc-money', self.money(w.price)));
                card.appendChild(el('div', 'wagon-stats', stats.join(' | ')));
                var buy = el('button', 'mc-btn small primary', t('ui_buy'));
                buy.type = 'button';
                buy.addEventListener('click', function (e) {
                    e.stopPropagation();
                    self.promptBuyWagon(w);
                });
                card.appendChild(buy);

                card.addEventListener('click', function () {
                    grid.querySelectorAll('.wagon-card').forEach(function (c) { c.classList.remove('selected'); });
                    card.classList.add('selected');
                    self.post('previewWagon', { model: w.model, store: self.store });
                });
                grid.appendChild(card);
            });

            if (this.wagons[0]) this.post('previewWagon', { model: this.wagons[0].model, store: this.store });
        },

        promptBuyWagon: function (w) {
            this.pendingNameWagon = w;
            $('name-input').value = '';
            show($('name-modal'), true);
            setTimeout(function () { $('name-input').focus(); }, 100);
        },

        confirmName: function () {
            var name = $('name-input').value.trim();
            if (!name || name.length > this.nameMax) {
                this.showNotification('error', t('ui_bad_name'), t('ui_bad_name_text', this.nameMax));
                return;
            }
            if (this.pendingNameWagon) {
                this.post('buyWagon', { model: this.pendingNameWagon.model, name: name, store: this.store });
                this.closeNameModal();
            }
        },

        closeNameModal: function () {
            show($('name-modal'), false);
            this.pendingNameWagon = null;
        },

        showConfirm: function (title, message, onConfirm) {
            this.pendingConfirm = onConfirm;
            $('confirm-title').textContent = title;
            $('confirm-message').textContent = message;
            show($('confirm-modal'), true);
        },

        closeConfirmModal: function () {
            show($('confirm-modal'), false);
            this.pendingConfirm = null;
        },

        confirmAction: function () {
            var fn = this.pendingConfirm;
            this.closeConfirmModal();
            if (fn) fn();
        },

        openChop: function (data) {
            applyText(data);
            this.pendingChop = { netId: data.netId, modelName: data.modelName };
            this.isOpen = true;

            $('shop-name').textContent = t('ui_chop_title');
            $('shop-subtitle').textContent = t('ui_chop_sub');
            show($('nav-tabs'), false);
            show($('money-bar'), false);
            show($('rotate-buttons'), false);

            $('chop-wagon-name').textContent = data.displayName || data.modelName || '';
            $('chop-wagon-model').textContent = data.modelName || '';

            var box = $('chop-rewards');
            box.innerHTML = '';
            (data.rewards || []).forEach(function (r) {
                var row = el('div', 'mc-row');
                row.appendChild(el('span', null, r.label || r.item));
                row.appendChild(el('span', 'mc-sub', r.amount));
                box.appendChild(row);
            });
            show($('chop-owned-note'), !!data.isRegistered);

            this.switchView('chop');
            this.updateFooter(t('ui_hint_chop'));
            show($('shop-container'), true);
        },

        confirmChop: function () {
            if (!this.pendingChop) return;
            this.post('confirmChop', this.pendingChop);
            this.pendingChop = null;
            this.hide();
        },

        switchView: function (view) {
            document.querySelectorAll('.view').forEach(function (v) { show(v, false); });
            show($('view-' + view), true);
            if (view === 'mywagons') {
                show($('wagon-detail-panel'), false);
                this.post('getMyWagons');
                this.updateFooter(t('ui_hint_mine'));
            } else if (view === 'store') {
                this.updateFooter(t('ui_hint_store'));
            }
        },

        showMyWagons: function (wagons) {
            var self = this;
            this.myWagons = wagons || [];
            var list = $('mywagons-items');
            list.innerHTML = '';
            if (this.myWagons.length === 0) {
                show(list, false);
                show($('no-mywagons'), true);
                show($('wagon-detail-panel'), false);
                return;
            }
            show(list, true);
            show($('no-mywagons'), false);

            this.myWagons.forEach(function (w, i) {
                var custom = w.custom || {};
                var item = el('div', 'mc-row mywagon-item' + (i === 0 ? ' active' : ''));
                item.appendChild(el('span', null, (custom.name || t('ui_unnamed')) + (w.active ? '  •' : '')));
                item.appendChild(el('span', 'mc-sub', w.label || w.model));
                item.addEventListener('click', function () {
                    list.querySelectorAll('.mywagon-item').forEach(function (c) { c.classList.remove('active'); });
                    item.classList.add('active');
                    self.selectMyWagon(w);
                });
                list.appendChild(item);
            });
            this.selectMyWagon(this.myWagons[0]);
        },

        actionRow: function (label, pill, cls, onClick) {
            var row = el('div', 'mc-row' + (cls ? ' ' + cls : ''));
            row.appendChild(el('span', null, label));
            if (pill) row.appendChild(el('span', 'pill', pill));
            row.addEventListener('click', onClick);
            return row;
        },

        selectMyWagon: function (w) {
            var self = this;
            var custom = w.custom || {};
            this.selectedMyWagon = { id: w.id, model: w.model, custom: custom };
            show($('wagon-detail-panel'), true);
            show($('customize-preview'), false);
            show($('customize-options'), true);

            $('detail-wagon-name').textContent = custom.name || t('ui_unnamed');
            $('detail-wagon-model').textContent = w.label || w.model;

            var actions = $('detail-actions');
            actions.innerHTML = '';
            actions.appendChild(this.actionRow(t('ui_activate'), w.active ? t('ui_selected') : t('ui_activate_pill'), null, function () {
                self.post('activateWagon', { id: w.id });
                self.hide();
            }));

            show($('customize-section'), true);
            var opts = $('customize-options');
            opts.innerHTML = '';
            ['livery', 'tint', 'extra', 'props', 'lantern'].forEach(function (type) {
                opts.appendChild(self.actionRow(t('ui_custom_' + type), self.money(self.prices[type]), null, function () {
                    self.selectedCustomType = type;
                    self.post('getCustomOptions', { type: type, model: w.model, custom: custom });
                }));
            });

            actions.appendChild(this.actionRow(t('ui_sell'), t('ui_sell_pill'), 'sell', function () {
                self.showConfirm(t('ui_sell'), t('ui_sell_text'), function () {
                    self.post('sellWagon', { id: w.id });
                    self.hide();
                });
            }));

            this.post('previewMyWagon', { model: w.model, custom: custom });
        },

        showCustomOptions: function (type, options, price, multi, categories) {
            this.selectedCustomValue = null;
            $('btn-save-customize').disabled = true;
            var box = $('customize-items');
            box.innerHTML = '';
            var fee = this.money(price != null ? price : this.prices[type]);

            if (type === 'extra' && multi) {
                $('customize-preview-title').textContent = t('ui_select_extras', fee);
                this.renderExtraCheckboxes(box, options || []);
            } else if (type === 'props' && categories && categories.length > 0) {
                $('customize-preview-title').textContent = t('ui_select_x', t('ui_custom_props')) + ' (' + fee + ')';
                this.renderPropsetCategories(box, categories, options || [], fee);
            } else {
                $('customize-preview-title').textContent = t('ui_select_x', t('ui_custom_' + type)) + ' (' + fee + ')';
                this.renderSingleSelect(box, type, options || [], fee);
            }
            show($('customize-preview'), true);
            show($('customize-options'), false);
        },

        optionRow: function (label, fee) {
            var row = el('div', 'mc-row');
            row.appendChild(el('span', 'opt-label', label));
            if (fee) row.appendChild(el('span', 'mc-sub', fee));
            return row;
        },

        renderSingleSelect: function (box, type, options, fee) {
            var self = this;
            options.forEach(function (opt) {
                var row = self.optionRow(opt.label, fee);
                row.addEventListener('click', function () {
                    box.querySelectorAll('.mc-row').forEach(function (c) { c.classList.remove('active'); });
                    row.classList.add('active');
                    self.selectedCustomValue = opt.value;
                    $('btn-save-customize').disabled = false;
                    self.post('previewCustom', { type: type, value: opt.value });
                });
                box.appendChild(row);
            });
        },

        renderExtraCheckboxes: function (box, options) {
            var self = this;
            var selected = new Set();
            var initial = new Set();
            options.forEach(function (opt) {
                if (opt.enabled) { selected.add(opt.value); initial.add(opt.value); }
            });
            var saveBtn = $('btn-save-customize');
            var sync = function () {
                var arr = Array.from(selected).sort(function (a, b) { return a - b; });
                self.selectedCustomValue = arr;
                self.post('previewCustom', { type: 'extra', value: arr });
                var dirty = arr.length !== initial.size || arr.some(function (v) { return !initial.has(v); });
                saveBtn.disabled = !dirty;
            };
            options.forEach(function (opt) {
                var row = self.optionRow((opt.enabled ? '☒ ' : '☐ ') + opt.label);
                if (opt.enabled) row.classList.add('active');
                row.addEventListener('click', function () {
                    var on = !selected.has(opt.value);
                    if (on) selected.add(opt.value); else selected.delete(opt.value);
                    row.classList.toggle('active', on);
                    row.querySelector('.opt-label').textContent = (on ? '☒ ' : '☐ ') + opt.label;
                    sync();
                });
                box.appendChild(row);
            });
            this.selectedCustomValue = Array.from(selected).sort(function (a, b) { return a - b; });
        },

        renderPropsetCategories: function (box, categories, removeOptions, fee) {
            var self = this;
            var saveBtn = $('btn-save-customize');
            var selectRow = function (value, row) {
                box.querySelectorAll('.mc-row').forEach(function (c) { c.classList.remove('active'); });
                row.classList.add('active');
                self.selectedCustomValue = value;
                saveBtn.disabled = false;
                self.post('previewCustom', { type: 'props', value: value });
            };
            (removeOptions || []).forEach(function (opt) {
                var row = self.optionRow(opt.label, fee);
                row.addEventListener('click', function () { selectRow(opt.value, row); });
                box.appendChild(row);
            });

            var select = el('select', 'mc-select');
            categories.forEach(function (cat, idx) {
                var o = el('option', null, cat.label + ' (' + cat.options.length + ')');
                o.value = idx;
                select.appendChild(o);
            });
            box.appendChild(select);

            var listWrap = el('div', 'mc-list');
            box.appendChild(listWrap);
            var renderCat = function (idx) {
                listWrap.innerHTML = '';
                (categories[idx].options || []).forEach(function (opt) {
                    var row = self.optionRow(opt.label, fee);
                    row.addEventListener('click', function () { selectRow(opt.value, row); });
                    listWrap.appendChild(row);
                });
            };
            select.addEventListener('change', function () { renderCat(parseInt(select.value, 10)); });
            renderCat(0);
        },

        backFromCustomize: function () {
            this.selectedCustomType = null;
            this.selectedCustomValue = null;
            show($('customize-preview'), false);
            show($('customize-options'), true);
            if (this.selectedMyWagon) {
                this.post('resetPreview', { model: this.selectedMyWagon.model, custom: this.selectedMyWagon.custom });
            }
        },

        saveCustomization: function () {
            if (!this.selectedCustomType || this.selectedCustomValue === null || !this.selectedMyWagon) return;
            var w = this.selectedMyWagon;
            var type = this.selectedCustomType;
            var value = this.selectedCustomValue;
            this.post('saveCustomization', { id: w.id, type: type, value: value, model: w.model, custom: w.custom });
            if (type === 'extra' && Array.isArray(value)) {
                w.custom.extras = value;
                delete w.custom.extra;
            } else if ((type === 'props' || type === 'lantern') && value === -1) {
                w.custom[type] = false;
            } else {
                w.custom[type] = value;
            }
            this.selectedCustomType = null;
            this.selectedCustomValue = null;
            show($('customize-preview'), false);
            show($('customize-options'), true);
        },

        updateMoneyDisplay: function () {
            $('player-cash').textContent = this.currency + (Number(this.playerMoney.cash) || 0).toFixed(2);
            $('player-gold').textContent = String(Number(this.playerMoney.gold) || 0);
        },

        updateMoney: function (cash, gold) {
            this.playerMoney = { cash: cash || 0, gold: gold || 0 };
            this.updateMoneyDisplay();
        },

        updateFooter: function (text) { $('footer-hint').textContent = text || ''; },

        close: function () {
            this.hide();
            this.post('closeShop');
        },

        hide: function () {
            this.isOpen = false;
            this.selectedMyWagon = null;
            this.selectedCustomType = null;
            this.selectedCustomValue = null;
            this.pendingNameWagon = null;
            this.pendingChop = null;
            show($('shop-container'), false);
            show($('name-modal'), false);
            show($('confirm-modal'), false);
            show($('customize-preview'), false);
            show($('customize-options'), true);
        },

        showNotification: function (type, title, message) {
            var stack = $('notification-container');
            var toast = el('div', 'wg-toast' + (type === 'error' ? ' error' : ''));
            toast.appendChild(el('div', 'wg-toast-label', title || ''));
            if (message) toast.appendChild(el('div', 'wg-toast-message', message));
            stack.prepend(toast);
            requestAnimationFrame(function () { toast.classList.add('visible'); });
            setTimeout(function () {
                toast.classList.remove('visible');
                setTimeout(function () { toast.remove(); }, 250);
            }, 4000);
        }
    };

    document.addEventListener('DOMContentLoaded', function () { WagonShop.init(); });
})();
