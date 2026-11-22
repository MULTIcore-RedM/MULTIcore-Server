// ============================================================
// MULTIcore notifications (NUI)
// Messages from client/multi/notify.lua:
//   { action: 'notify', layout: {...}, n: { id, style, type, title, text, icon, img, color, duration } }
//   { action: 'clear', id }      { action: 'clearAll' }
//   { action: 'editor', layout, server, words }   the /notifylayout editor
// No words live here: every text comes from Lua (config / locales).
// duration -1 = stays until cleared. A message with an id that is
// already shown counts up (x2, x3) and restarts its timer.
// layout: per style { position, x, y, width, scale, align, max, topPct? } and look { ... }.
// ============================================================
(function () {
    'use strict';

    var root = document.getElementById('mn-root');
    var STYLES = ['toast', 'tip', 'objective', 'banner'];
    var stacks = {
        toast: document.getElementById('mn-toast'),
        tip: document.getElementById('mn-tip'),
        objective: document.getElementById('mn-objective'),
        banner: document.getElementById('mn-banner')
    };
    var items = {};          // id -> { el, style, timer, count, sticky }
    var order = [];          // ids, oldest first
    var max = { toast: 5, tip: 1, objective: 1, banner: 1 };
    var FADE_MS = 300;
    var places = {};         // style -> the place it was last put at
    var editor = null;       // while /notifylayout is open

    // ---------------- place and size ----------------
    function split(pos) {
        if (pos === 'center') return { v: 'middle', h: 'center' };
        var p = String(pos || 'top-left').split('-');
        return { v: p[0] || 'top', h: p[1] || 'left' };
    }

    function place(style, p) {
        var st = stacks[style], s = st.style;
        if (!st || !p) return;
        places[style] = p;
        var a = split(p.position);
        var x = Number(p.x) || 0, y = Number(p.y) || 0, sc = Number(p.scale) || 1;
        var tx = '0', ty = '0';
        s.left = s.right = s.top = s.bottom = '';
        if (a.h === 'left') s.left = x + 'px';
        else if (a.h === 'right') s.right = x + 'px';
        else { s.left = 'calc(50% + ' + x + 'px)'; tx = '-50%'; }
        if (a.v === 'top') s.top = (p.topPct != null ? 'calc(' + p.topPct + '% + ' + y + 'px)' : y + 'px');
        else if (a.v === 'bottom') s.bottom = y + 'px';
        else { s.top = 'calc(50% + ' + y + 'px)'; ty = '-50%'; }
        s.transformOrigin = (a.h === 'center' ? 'center' : a.h) + ' ' + (a.v === 'middle' ? 'center' : a.v);
        s.transform = 'translate(' + tx + ', ' + ty + ') scale(' + sc + ')';
        s.width = p.width > 0 ? 'min(' + p.width + 'px, ' + Math.round(96 / sc) + 'vw)' : '';
        st.classList.remove('mn-side-left', 'mn-side-right', 'mn-side-center');
        st.classList.add('mn-side-' + a.h);
        var align = p.align && p.align !== 'auto' ? p.align : a.h;
        st.classList.remove('mn-align-left', 'mn-align-right', 'mn-align-center');
        st.classList.add('mn-align-' + align);
        if (p.max > 0) max[style] = p.max;
    }

    // ---------------- look ----------------
    var lookKey = '';
    function px(v) { return v == null ? '' : v + 'px'; }
    function setVar(name, v) { if (v == null || v === '') root.style.removeProperty(name); else root.style.setProperty(name, v); }

    function applyLook(L) {
        if (!L) return;
        var key = JSON.stringify(L);
        if (key === lookKey) return;
        lookKey = key;
        setVar('--mn-bg', L.Background);
        setVar('--mn-border', L.Border);
        setVar('--mn-radius', px(L.Radius));
        setVar('--mn-pad', L.Padding);
        setVar('--mn-edge', px(L.AccentEdge));
        setVar('--mn-ink', L.TextColor);
        setVar('--mn-title-ink', L.TitleColor);
        setVar('--mn-dim', L.DimColor);
        setVar('--mn-shadow', L.TextShadow);
        setVar('--mn-title-case', L.TitleUppercase === false ? 'none' : 'uppercase');
        setVar('--mc-font-ui', L.TitleFont ? '"' + L.TitleFont + '", ' + 'var(--mc-font-body)' : null);
        setVar('--mc-font-title', L.TitleFont ? '"' + L.TitleFont + '", sans-serif' : null);
        setVar('--mc-font-body', L.BodyFont ? '"' + L.BodyFont + '", serif' : null);
        setVar('--mn-text-size', L.TextSize ? 'calc(' + L.TextSize + 'px * var(--mc-scale))' : null);
        setVar('--mn-title-size', L.TitleSize ? 'calc(' + L.TitleSize + 'px * var(--mc-scale))' : null);
        setVar('--mn-icon-size', px(L.IconSize));
        setVar('--mn-gap', px(L.Gap));
        FADE_MS = L.FadeMs != null ? Math.max(0, L.FadeMs) : 300;
        setVar('--mn-fade', (L.Animation === 'none' ? 0 : FADE_MS) + 'ms');
        root.classList.toggle('mn-solid', L.FadeEdges === false);
        root.classList.toggle('mn-noicons', L.ShowIcons === false);
        ['slide', 'fade', 'none'].forEach(function (a) { root.classList.toggle('mn-anim-' + a, L.Animation === a); });
        ['screen', 'left', 'right', 'top', 'bottom'].forEach(function (s) { root.classList.toggle('mn-edge-' + s, L.AccentSide === s); });
    }

    function applyLayout(l) {
        if (!l) return;
        applyLook(l.look);
        STYLES.forEach(function (k) { if (l[k] && !editor) place(k, l[k]); });
        root.classList.toggle('mc-cyrillic', !!l.cyrillic);
    }

    // ---------------- building one notification ----------------
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text != null) e.textContent = text;
        return e;
    }

    function iconEl(n) {
        var box = el('div', 'mn-icon');
        box.textContent = n.icon || '';
        if (n.img) {
            // game texture (only when NotifyConfig.GameIcons is on); fall back to the type's sign
            var img = new Image();
            img.onload = function () { box.textContent = ''; box.appendChild(img); };
            img.src = n.img;
        }
        return box;
    }

    function build(n) {
        var item = el('div', 'mn-item mn-' + n.style + ' mn-type-' + n.type);
        if (n.color) item.style.setProperty('--mn-accent', n.color);
        var count = el('span', 'mn-count');
        var title = n.title ? el('div', 'mn-title', n.title) : null;
        var text = n.text ? el('div', 'mn-text', n.text) : null;
        (title || text).appendChild(count);

        if (n.style === 'toast' || n.style === 'tip') {
            item.appendChild(iconEl(n));
            var body = el('div', 'mn-body');
            if (title) body.appendChild(title);
            if (text) body.appendChild(text);
            item.appendChild(body);
        } else if (n.style === 'objective') {
            if (title) item.appendChild(title);
            if (text) item.appendChild(text);
            item.appendChild(el('div', 'mn-rule'));
        } else { // banner
            item.appendChild(el('div', 'mn-rule'));
            if (title) item.appendChild(title);
            if (text) item.appendChild(text);
            item.appendChild(el('div', 'mn-rule'));
        }
        return { el: item, count: count };
    }

    function remove(id) {
        var it = items[id];
        if (!it) return;
        delete items[id];
        order = order.filter(function (x) { return x !== id; });
        clearTimeout(it.timer);
        it.el.classList.remove('mn-in');
        it.el.classList.add('mn-out');
        setTimeout(function () { if (it.el.parentNode) it.el.parentNode.removeChild(it.el); }, FADE_MS);
    }

    function arm(id, duration) {
        var it = items[id];
        clearTimeout(it.timer);
        it.sticky = duration < 0;
        if (!it.sticky) it.timer = setTimeout(function () { remove(id); }, duration);
    }

    // too many of one style on screen: drop the oldest that may go, else the oldest
    function trim(style) {
        var mine = order.filter(function (id) { return items[id].style === style; });
        while (mine.length > max[style]) {
            var victim = mine.filter(function (id) { return !items[id].sticky; })[0] || mine[0];
            remove(victim);
            mine = mine.filter(function (id) { return id !== victim; });
        }
    }

    function fadeIn(e) {
        requestAnimationFrame(function () { requestAnimationFrame(function () { e.classList.add('mn-in'); }); });
    }

    function show(n) {
        if (!n || !stacks[n.style]) return;
        var id = String(n.id);
        var it = items[id];
        if (it) {
            it.n += 1;
            it.countEl.textContent = '×' + it.n;
            it.countEl.classList.remove('mn-bump');
            void it.countEl.offsetWidth; // restart the one-time bump
            it.countEl.classList.add('mn-bump');
            arm(id, n.duration);
            return;
        }
        var b = build(n);
        items[id] = { el: b.el, countEl: b.count, style: n.style, n: 1 };
        order.push(id);
        stacks[n.style].appendChild(b.el);
        arm(id, n.duration);
        trim(n.style);
        fadeIn(b.el);
    }

    // ---------------- layout editor (/notifylayout) ----------------
    function post(name, data) {
        var res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIcore';
        fetch('https://' + res + '/' + name, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }

    function copy(p) {
        return { position: p.position, x: p.x, y: p.y, width: p.width, scale: p.scale, align: p.align, max: p.max, topPct: p.topPct };
    }

    function startEditor(d) {
        if (editor) return;
        var w = d.words || {};
        if (d.layout) applyLook(d.layout.look);
        editor = { cur: {}, server: d.server || {}, samples: [], words: w };
        STYLES.forEach(function (k) {
            var p = (d.layout && d.layout[k]) || places[k] || { position: 'center', x: 0, y: 0, width: 0, scale: 1 };
            editor.cur[k] = copy(p);
            place(k, editor.cur[k]);
            var sample = {
                toast: { style: 'toast', type: 'info', icon: 'i', title: w.sample_title, text: w.sample_text },
                tip: { style: 'tip', type: 'info', icon: 'i', text: w.sample_tip },
                objective: { style: 'objective', type: 'info', text: w.sample_objective },
                banner: { style: 'banner', type: 'info', title: w.sample_banner, text: w.sample_banner_text }
            }[k];
            var b = build(sample);
            b.el.classList.add('mn-sample');
            var tag = el('div', 'mn-edit-tag', w[k] || k);
            stacks[k].appendChild(tag);
            stacks[k].appendChild(b.el);
            editor.samples.push(tag, b.el);
            fadeIn(b.el);
            stacks[k].addEventListener('mousedown', onDown);
            stacks[k].addEventListener('wheel', onWheel, { passive: false });
        });
        var bar = el('div', 'mn-edit-bar');
        bar.appendChild(el('div', 'mn-edit-help', w.help));
        var btns = el('div', 'mn-edit-btns');
        [['save', save], ['reset', resetToServer], ['cancel', cancel]].forEach(function (b) {
            var btn = el('button', 'mn-edit-btn mn-edit-' + b[0], w[b[0]] || b[0]);
            btn.addEventListener('click', b[1]);
            btns.appendChild(btn);
        });
        bar.appendChild(btns);
        root.appendChild(bar);
        editor.bar = bar;
        root.classList.add('mn-editing');
        document.addEventListener('keydown', onKey);
    }

    function endEditor() {
        if (!editor) return;
        STYLES.forEach(function (k) {
            stacks[k].removeEventListener('mousedown', onDown);
            stacks[k].removeEventListener('wheel', onWheel);
        });
        editor.samples.forEach(function (e) { if (e.parentNode) e.parentNode.removeChild(e); });
        if (editor.bar.parentNode) editor.bar.parentNode.removeChild(editor.bar);
        document.removeEventListener('keydown', onKey);
        root.classList.remove('mn-editing');
        editor = null;
    }

    function styleOf(stack) {
        for (var i = 0; i < STYLES.length; i++) if (stacks[STYLES[i]] === stack) return STYLES[i];
        return null;
    }

    // where a stack now sits on screen -> the nearest of the 9 positions and the px offsets from it
    function measure(style) {
        var r = stacks[style].getBoundingClientRect();
        var W = window.innerWidth, H = window.innerHeight;
        var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
        var h = cx < W / 3 ? 'left' : (cx > W * 2 / 3 ? 'right' : 'center');
        var v = cy < H / 3 ? 'top' : (cy > H * 2 / 3 ? 'bottom' : 'middle');
        var p = editor.cur[style];
        p.position = (v === 'middle' && h === 'center') ? 'center' : v + '-' + h;
        // an edge position never pushes the box off the screen
        p.x = Math.round(h === 'left' ? Math.max(0, r.left) : h === 'right' ? Math.max(0, W - r.right) : cx - W / 2);
        p.y = Math.round(v === 'top' ? Math.max(0, r.top) : v === 'bottom' ? Math.max(0, H - r.bottom) : cy - H / 2);
        p.topPct = null;
        place(style, p);
    }

    var drag = null;
    function onDown(e) {
        if (e.button !== 0) return;
        var style = styleOf(e.currentTarget);
        if (!style) return;
        e.preventDefault();
        var r = stacks[style].getBoundingClientRect();
        drag = { style: style, dx: e.clientX - r.left, dy: e.clientY - r.top };
        var s = stacks[style].style;
        s.right = s.bottom = '';
        s.left = r.left + 'px'; s.top = r.top + 'px';
        s.transformOrigin = 'left top';
        s.transform = 'scale(' + (editor.cur[style].scale || 1) + ')';
        stacks[style].classList.add('mn-dragging');
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
    }
    function onMove(e) {
        if (!drag) return;
        var s = stacks[drag.style].style;
        s.left = (e.clientX - drag.dx) + 'px';
        s.top = (e.clientY - drag.dy) + 'px';
    }
    function onUp() {
        if (!drag) return;
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        stacks[drag.style].classList.remove('mn-dragging');
        measure(drag.style);
        drag = null;
    }

    function onWheel(e) {
        var style = styleOf(e.currentTarget);
        if (!style || drag) return;
        e.preventDefault();
        var p = editor.cur[style], up = e.deltaY < 0;
        if (e.shiftKey) {
            var now = p.width > 0 ? p.width : Math.round(stacks[style].getBoundingClientRect().width / (p.scale || 1));
            p.width = Math.max(120, Math.min(2400, now + (up ? 20 : -20)));
        } else {
            p.scale = Math.round(Math.max(0.3, Math.min(3, (p.scale || 1) + (up ? 0.05 : -0.05))) * 100) / 100;
        }
        place(style, p);
    }

    function onKey(e) { if (e.key === 'Escape') cancel(); }

    function save() {
        var out = {};
        STYLES.forEach(function (k) {
            var p = editor.cur[k];
            out[k] = { position: p.position, x: p.x, y: p.y, width: p.width, scale: p.scale };
        });
        endEditor();
        post('notifyEditor:save', out);
    }

    function cancel() {
        var keep = editor && editor.before;
        endEditor();
        post('notifyEditor:cancel', {});
        if (keep) STYLES.forEach(function (k) { place(k, keep[k]); });
    }

    function resetToServer() {
        STYLES.forEach(function (k) {
            var s = editor.server[k];
            if (s) { editor.cur[k] = copy(s); place(k, editor.cur[k]); }
        });
    }

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.action === 'notify') { applyLayout(d.layout); show(d.n); }
        else if (d.action === 'clear') remove(String(d.id));
        else if (d.action === 'clearAll') Object.keys(items).forEach(remove);
        else if (d.action === 'editor') {
            var before = {};
            STYLES.forEach(function (k) { if (places[k]) before[k] = copy(places[k]); });
            startEditor(d);
            if (editor) editor.before = before;
        }
    });
})();
