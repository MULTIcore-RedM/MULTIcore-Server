/* MULTIhelpers NUI: feather-menu (v1) stand-in. Draws the menus and toasts sent by
   client/feather_menu.lua in the MULTI look. Own code, GPL v3. */
(function () {
    'use strict';

    var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'MULTIhelpers';
    function post(name, data) {
        return fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }

    // ------------------------------------------------------------ safe HTML (scripts send small bits of markup)
    var BAD_TAGS = { SCRIPT: 1, IFRAME: 1, OBJECT: 1, EMBED: 1, LINK: 1, META: 1, BASE: 1, FORM: 1 };
    function clean(node) {
        Array.prototype.slice.call(node.childNodes).forEach(function (k) {
            if (k.nodeType !== 1) return;
            if (BAD_TAGS[k.tagName]) { k.remove(); return; }
            Array.prototype.slice.call(k.attributes).forEach(function (a) {
                var n = a.name.toLowerCase(), v = String(a.value).toLowerCase().replace(/\s+/g, '');
                if (n.indexOf('on') === 0 || v.indexOf('javascript:') >= 0) k.removeAttribute(a.name);
            });
            clean(k);
        });
    }
    function setHtml(el, html) {
        if (html === undefined || html === null) html = '';
        var t = document.createElement('template');
        t.innerHTML = String(html);
        clean(t.content);
        el.innerHTML = '';
        el.appendChild(t.content);
    }
    function text(v) { return v === undefined || v === null ? '' : String(v); }
    function num(v, d) { v = Number(v); return isFinite(v) ? v : d; }
    function mk(tag, cls, parent) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (parent) parent.appendChild(e);
        return e;
    }

    // ------------------------------------------------------------ script styles
    // Scripts pass CSS tables. Size and layout are kept; colours, backgrounds, borders and fonts
    // are left to the MULTI theme so every menu follows the server's look.
    var STYLE_OK = /^(width|height|min-width|max-width|min-height|max-height|margin(-.+)?|padding(-.+)?|text-align|gap|row-gap|column-gap|display|flex(-.+)?|justify-.+|align-.+|order|overflow(-.+)?|white-space|word-break|font-size|font-weight|font-style|text-transform|letter-spacing|line-height|text-decoration|opacity|z-index|top|left|right|bottom|position|transform|grid(-.+)?|object-fit|cursor|vertical-align|float|clear)$/;
    function applyStyle(el, style) {
        if (!style || typeof style !== 'object') return;
        Object.keys(style).forEach(function (k) {
            var prop = String(k).trim().toLowerCase();
            if (!STYLE_OK.test(prop)) return;
            var v = style[k];
            if (v === null || v === undefined || typeof v === 'object') return;
            try { el.style.setProperty(prop, String(v)); } catch (e) { /* bad value: skip */ }
        });
    }

    // ------------------------------------------------------------ state
    var F = null;          // { menu, page }
    var root = null;       // menu box
    var slots = {};        // header / content / footer
    var nodes = {};        // element id -> node
    var data = {};         // element id -> element record

    function ensureRoot() {
        if (root) return;
        root = mk('div', 'mc-root mc-panel fm-menu mc-hidden', document.body);
        root.id = 'feather-menu';
        var close = mk('button', 'fm-close', root);
        close.type = 'button';
        close.innerHTML = '&#215;';
        close.addEventListener('click', function () { if (F) post('featherClose', { menuID: F.menu.id }); });
        slots.header = mk('div', 'fm-slot fm-header', root);
        slots.content = mk('div', 'fm-slot fm-content mc-scroll', root);
        slots.footer = mk('div', 'fm-slot fm-footer', root);
        dragSetup();
    }

    // ------------------------------------------------------------ drag (config.draggable)
    var drag = null;
    function dragSetup() {
        slots.header.addEventListener('mousedown', function (ev) {
            if (!F || !F.menu.draggable || ev.button !== 0) return;
            if (ev.target.closest('input, textarea, select, button, .fm-click')) return;
            var r = root.getBoundingClientRect();
            drag = { dx: ev.clientX - r.left, dy: ev.clientY - r.top };
            ev.preventDefault();
        });
        window.addEventListener('mousemove', function (ev) {
            if (!drag) return;
            root.style.left = Math.max(0, ev.clientX - drag.dx) + 'px';
            root.style.top = Math.max(0, ev.clientY - drag.dy) + 'px';
            root.dataset.dragged = '1';
        });
        window.addEventListener('mouseup', function () { drag = null; });
    }

    // ------------------------------------------------------------ sending values
    var timers = {};
    function send(el, extra, delay) {
        var d = { menuID: F.menu.id, pageID: F.page.id, id: el.id };
        Object.keys(extra || {}).forEach(function (k) { d[k] = extra[k]; });
        clearTimeout(timers[el.id]);
        if (delay) timers[el.id] = setTimeout(function () { post('featherEvent', d); }, delay);
        else post('featherEvent', d);
    }

    function optionText(o) {
        if (o && typeof o === 'object') return text(o.display !== undefined ? o.display : (o.text !== undefined ? o.text : o.label));
        return text(o);
    }

    function hoverFrame(node) {
        node.addEventListener('mouseenter', function () { node.classList.add('active'); });
        node.addEventListener('mouseleave', function () { node.classList.remove('active'); });
    }

    function labelEl(parent, d) {
        var l = mk('span', 'fm-label', parent);
        setHtml(l, d.label);
        return l;
    }

    // ------------------------------------------------------------ elements
    var gridHeld = null;   // the grid slider being dragged
    window.addEventListener('mousemove', function (ev) { if (gridHeld) gridHeld(ev); });
    window.addEventListener('mouseup', function () { gridHeld = null; });

    var BUILD = {
        header: function (el, d) {
            var n = mk('h1', 'mc-title fm-h');
            setHtml(n, d.value);
            return n;
        },
        subheader: function (el, d) {
            var n = mk('div', 'mc-subtitle fm-sub');
            setHtml(n, d.value);
            return n;
        },
        line: function () { return mk('hr', 'mc-rule fm-line'); },
        bottomline: function () { return mk('hr', 'mc-rule fm-line'); },
        textdisplay: function (el, d) {
            var n = mk('div', 'fm-text');
            setHtml(n, d.value);
            return n;
        },
        html: function (el, d) {
            var n = mk('div', 'fm-html');
            setHtml(n, d.value);
            return n;
        },
        button: function (el, d) {
            var n = mk('div', 'mc-row fm-button fm-click');
            var l = mk('span', 'fm-label', n);
            setHtml(l, d.html !== undefined && d.html !== null ? d.html : d.label);
            hoverFrame(n);
            n.addEventListener('click', function () { send(el, {}); });
            return n;
        },
        input: function (el, d) {
            var n = mk('label', 'mc-field fm-field');
            var l = mk('span', 'fm-flabel', n); setHtml(l, d.label);
            if (!d.label) l.classList.add('mc-hidden');
            var i = mk('input', 'mc-input', n);
            i.type = d.inputType === 'number' || d.type === 'number' ? 'number' : 'text';
            i.placeholder = text(d.placeholder);
            i.value = text(d.value);
            i.addEventListener('input', function () { send(el, { value: i.value }, 120); });
            i.addEventListener('change', function () { send(el, { value: i.value }); });
            return n;
        },
        textarea: function (el, d) {
            var n = mk('label', 'mc-field fm-field');
            var l = mk('span', 'fm-flabel', n); setHtml(l, d.label);
            if (!d.label) l.classList.add('mc-hidden');
            var t = mk('textarea', 'mc-textarea', n);
            t.placeholder = text(d.placeholder);
            t.value = text(d.value);
            if (d.rows) t.rows = num(d.rows, 3);
            if (d.cols) t.cols = num(d.cols, 20);
            t.style.resize = d.resize === false || d.resize === 'none' ? 'none' : 'vertical';
            t.addEventListener('input', function () { send(el, { value: t.value }, 120); });
            t.addEventListener('change', function () { send(el, { value: t.value }); });
            return n;
        },
        slider: function (el, d) {
            var n = mk('div', 'mc-slider fm-slider');
            var l = mk('span', 'mc-slider-label', n); setHtml(l, d.label);
            var v = mk('span', 'mc-slider-value', n);
            var r = mk('input', '', n);
            r.type = 'range';
            r.min = num(d.min, 0); r.max = num(d.max, 100); r.step = num(d.steps, 1) || 1;
            r.value = num(d.value, num(d.start, r.min));
            v.textContent = r.value;
            r.addEventListener('input', function () { v.textContent = r.value; send(el, { value: Number(r.value) }, 60); });
            return n;
        },
        arrows: function (el, d) {
            var opts = Array.isArray(d.options) ? d.options : [];
            var idx = Math.max(1, Math.min(opts.length || 1, num(d.persistindex, num(d.start, 1))));
            var n = mk('div', 'mc-row fm-arrows');
            labelEl(n, d);
            var right = mk('span', 'fm-right', n);
            var a = mk('span', 'fm-arrow fm-click', right); a.innerHTML = '&#8249;';
            var val = mk('span', 'fm-val', right);
            var b = mk('span', 'fm-arrow fm-click', right); b.innerHTML = '&#8250;';
            function show() { setHtml(val, optionText(opts[idx - 1])); }
            function go(dir) {
                if (!opts.length) return;
                idx += dir;
                if (idx < 1) idx = opts.length;
                if (idx > opts.length) idx = 1;
                show();
                send(el, { index: idx });
            }
            a.addEventListener('click', function () { go(-1); });
            b.addEventListener('click', function () { go(1); });
            hoverFrame(n);
            show();
            return n;
        },
        toggle: function (el, d) {
            var on = d.value === true;
            var n = mk('div', 'mc-row fm-toggle fm-click');
            labelEl(n, d);
            var sw = mk('span', 'fm-switch' + (on ? ' on' : ''), n);
            mk('span', 'fm-knob', sw);
            hoverFrame(n);
            n.addEventListener('click', function () {
                on = !on; sw.classList.toggle('on', on);
                send(el, { value: on });
            });
            return n;
        },
        checkbox: function (el, d) {
            var on = d.value === true;
            var n = mk('div', 'mc-row fm-checkbox fm-click');
            labelEl(n, d);
            var t = mk('span', 'fm-tick' + (on ? ' on' : ''), n);
            hoverFrame(n);
            n.addEventListener('click', function () {
                on = !on; t.classList.toggle('on', on);
                send(el, { value: on });
            });
            return n;
        },
        dropdown: function (el, d) {
            var opts = Array.isArray(d.options) ? d.options : [];
            var n = mk('label', 'mc-field fm-field');
            var l = mk('span', 'fm-flabel', n); setHtml(l, d.label);
            if (!d.label) l.classList.add('mc-hidden');
            var s = mk('select', 'mc-select', n);
            var ph = mk('option', '', s);
            ph.value = '0'; ph.textContent = text(d.placeholder); ph.disabled = true;
            var chosen = d.value !== undefined && d.value !== null ? d.value : d.selectedValue;
            var picked = false;
            opts.forEach(function (o, i) {
                var op = mk('option', '', s);
                op.value = String(i + 1);
                op.textContent = optionText(o);
                var ov = (o && typeof o === 'object') ? (o.value !== undefined ? o.value : o.text) : o;
                if (!picked && chosen !== undefined && chosen !== null && String(ov) === String(chosen)) { op.selected = true; picked = true; }
            });
            if (!picked) { ph.selected = true; if (!d.placeholder) ph.hidden = true; }
            s.addEventListener('change', function () { send(el, { index: Number(s.value) }); });
            return n;
        },
        gridslider: function (el, d) {
            var mx = Math.abs(num(d.maxx, 1)) || 1, my = Math.abs(num(d.maxy, 1)) || 1;
            var prec = Math.max(0, Math.min(6, num(d.precision, 2)));
            var val = (d.value && typeof d.value === 'object') ? { x: num(d.value.x, 0), y: num(d.value.y, 0) } : { x: 0, y: 0 };
            var n = mk('div', 'fm-grid');
            var top = mk('div', 'fm-grid-lab fm-grid-top', n); setHtml(top, d.toplabel);
            var mid = mk('div', 'fm-grid-mid', n);
            var left = mk('div', 'fm-grid-lab', mid); setHtml(left, d.leftlabel);
            var pad = mk('div', 'fm-grid-pad fm-click', mid);
            mk('div', 'fm-grid-h', pad); mk('div', 'fm-grid-v', pad);
            var dot = mk('div', 'fm-grid-dot', pad);
            var right = mk('div', 'fm-grid-lab', mid); setHtml(right, d.rightlabel);
            var bottom = mk('div', 'fm-grid-lab fm-grid-bottom', n); setHtml(bottom, d.bottomlabel);
            function place() {
                dot.style.left = ((val.x / mx + 1) * 50) + '%';
                dot.style.top = ((1 - val.y / my) * 50) + '%';
            }
            function fromMouse(ev) {
                var r = pad.getBoundingClientRect();
                var fx = Math.max(0, Math.min(1, (ev.clientX - r.left) / r.width));
                var fy = Math.max(0, Math.min(1, (ev.clientY - r.top) / r.height));
                val.x = Number(((fx * 2 - 1) * mx).toFixed(prec));
                val.y = Number(((1 - fy * 2) * my).toFixed(prec));
                place();
                send(el, { value: { x: val.x, y: val.y } }, 60);
            }
            pad.addEventListener('mousedown', function (ev) { gridHeld = fromMouse; fromMouse(ev); });
            pad.tabIndex = 0;
            pad.addEventListener('keydown', function (ev) {
                var st = num(d.arrowsteps, 0.1) || 0.1, moved = true;
                if (ev.key === 'ArrowLeft') val.x = Math.max(-mx, val.x - st);
                else if (ev.key === 'ArrowRight') val.x = Math.min(mx, val.x + st);
                else if (ev.key === 'ArrowUp') val.y = Math.min(my, val.y + st);
                else if (ev.key === 'ArrowDown') val.y = Math.max(-my, val.y - st);
                else moved = false;
                if (!moved) return;
                ev.preventDefault();
                val.x = Number(val.x.toFixed(prec)); val.y = Number(val.y.toFixed(prec));
                place();
                send(el, { value: { x: val.x, y: val.y } }, 60);
            });
            place();
            return n;
        },
        imagebox: function (el, d) {
            return imageBox(d, function () { send(el, {}); });
        },
        imageboxcontainer: function (el, d) {
            var n = mk('div', 'fm-images');
            (Array.isArray(d.items) ? d.items : []).forEach(function (it, i) {
                n.appendChild(imageBox(it || {}, function () { send(el, { index: i + 1 }); }));
            });
            return n;
        },
        pagearrows: function (el, d) {
            var n = mk('div', 'fm-pagearrows');
            var a = mk('span', 'fm-arrow fm-click', n); a.innerHTML = '&#8249;';
            var t = mk('span', 'fm-val', n);
            t.textContent = text(d.current) + ' / ' + text(d.total);
            var b = mk('span', 'fm-arrow fm-click', n); b.innerHTML = '&#8250;';
            a.addEventListener('click', function () { send(el, { value: 'back' }); });
            b.addEventListener('click', function () { send(el, { value: 'forward' }); });
            return n;
        }
    };

    function imageBox(d, onClick) {
        var n = mk('div', 'fm-imagebox fm-click');
        var tip = d.tooltip !== undefined && d.tooltip !== null ? d.tooltip : d.label;
        if (tip) n.title = text(tip).replace(/<[^>]*>/g, '');
        if (d.img) { var im = mk('img', '', n); im.src = String(d.img); im.alt = ''; }
        if (d.label) { var l = mk('div', 'fm-imagelabel', n); setHtml(l, d.label); }
        applyStyle(n, d.style);
        hoverFrame(n);
        n.addEventListener('click', onClick);
        return n;
    }

    function build(el) {
        var d = el.data || {};
        var fn = BUILD[el.type] || BUILD.textdisplay;
        var n = fn(el, d);
        n.classList.add('fm-el', 'fm-type-' + el.type);
        n.setAttribute('data-id', el.id);
        if (el.type !== 'imagebox') applyStyle(n, d.style);
        return n;
    }

    // ------------------------------------------------------------ show / update / hide
    function slotOf(el) {
        var s = String(el.slot || 'content').toLowerCase();
        return slots[s] ? s : 'content';
    }

    function show(msg) {
        ensureRoot();
        var menu = msg.menu || {}, page = msg.page || {};
        var samePage = F && F.menu.id === menu.id && F.page.id === page.id;
        var scrollTop = samePage ? slots.content.scrollTop : 0;
        var moved = F && F.menu.id === menu.id && root.dataset.dragged === '1';
        var keepTop = root.style.top, keepLeft = root.style.left;
        F = { menu: menu, page: page };
        nodes = {}; data = {};

        root.removeAttribute('style');
        applyStyle(root, menu.style);
        if (moved) {
            root.style.top = keepTop;
            root.style.left = keepLeft;
        } else {
            delete root.dataset.dragged;
            if (menu.top) root.style.top = String(menu.top);
            if (menu.left) root.style.left = String(menu.left);
        }
        ['header', 'content', 'footer'].forEach(function (s) {
            slots[s].removeAttribute('style');
            slots[s].innerHTML = '';
            var cfg = menu[s + 'slot'];
            if (cfg && cfg.style) applyStyle(slots[s], cfg.style);
        });
        root.classList.toggle('fm-draggable', !!menu.draggable);
        root.classList.toggle('fm-canclose', menu.canclose !== false);

        (page.elements || []).forEach(function (el) {
            var n = build(el);
            nodes[el.id] = n; data[el.id] = el;
            slots[slotOf(el)].appendChild(n);
        });
        ['header', 'footer'].forEach(function (s) { slots[s].classList.toggle('fm-empty', !slots[s].firstChild); });
        root.classList.remove('mc-hidden');
        slots.content.scrollTop = scrollTop;
    }

    function update(el) {
        if (!F || !el || !nodes[el.id]) return;
        var old = nodes[el.id];
        var n = build(el);
        var target = slots[slotOf(el)];
        if (old.parentNode === target) target.replaceChild(n, old);
        else { old.remove(); target.appendChild(n); }
        nodes[el.id] = n; data[el.id] = el;
    }

    function hide() {
        F = null;
        if (root) root.classList.add('mc-hidden');
    }

    // ------------------------------------------------------------ toasts
    var toastBoxes = {};
    function toastBox(pos) {
        pos = /^(top|bottom)-(left|right|center)$/.test(pos) ? pos : 'top-right';
        if (!toastBoxes[pos]) toastBoxes[pos] = mk('div', 'fm-toasts fm-' + pos, document.body);
        return toastBoxes[pos];
    }
    function notify(t) {
        var box = toastBox(t.position);
        var n = mk('div', 'mc-root mc-panel fm-toast fm-' + (String(t.type || 'default').replace(/[^a-z]/gi, '') || 'default'), box);
        var msg = mk('div', 'fm-toast-text', n);
        setHtml(msg, t.message);
        var bar = null;
        var ms = t.autoClose === false ? 0 : num(t.autoClose, 5000);
        if (ms > 0 && !t.hideProgressBar) {
            bar = mk('div', 'fm-toast-bar', n);
            bar.style.animationDuration = ms + 'ms';
        }
        var gone = false;
        function close() {
            if (gone) return;
            gone = true;
            n.remove();
            post('featherToast', { id: t.id, type: 'closed' });
        }
        n.addEventListener('click', close);
        if (ms > 0) setTimeout(close, ms);
        post('featherToast', { id: t.id, type: 'opened' });
    }

    // ------------------------------------------------------------ keys
    window.addEventListener('keydown', function (ev) {
        if (!F) return;
        var typing = ev.target && /^(INPUT|TEXTAREA|SELECT)$/.test(ev.target.tagName);
        if (ev.key === 'Escape') {
            if (typing) { ev.target.blur(); return; }
            if (F.menu.canclose !== false && !ev.repeat) post('featherClose', { menuID: F.menu.id });
            return;
        }
        if (typing || ev.repeat) return;
        var keys = F.menu.keys || [];
        var hit = null;
        if (keys.indexOf(ev.key) >= 0) hit = ev.key;
        else if (keys.indexOf(ev.code) >= 0) hit = ev.code;
        else if (ev.key && keys.indexOf(ev.key.toUpperCase()) >= 0) hit = ev.key.toUpperCase();
        else if (ev.key && keys.indexOf(ev.key.toLowerCase()) >= 0) hit = ev.key.toLowerCase();
        if (hit) post('featherKey', { key: hit });
    });

    window.addEventListener('message', function (ev) {
        var m = ev.data || {};
        switch (m.action) {
            case 'featherShow': show(m.data || {}); break;
            case 'featherUpdate': update((m.data || {}).element); break;
            case 'featherHide': hide(); break;
            case 'featherNotify': notify(m.data || {}); break;
        }
    });

    // for the render preview
    window.FM = { show: show, update: update, hide: hide, notify: notify };
})();
