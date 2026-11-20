// ============================================================
// MULTIcore notifications (NUI)
// Messages from client/multi/notify.lua:
//   { action: 'notify', layout: {...}, n: { id, style, type, title, text, icon, img, color, duration } }
//   { action: 'clear', id }      { action: 'clearAll' }
// No words live here: every text comes from Lua (config / locales).
// duration -1 = stays until cleared. A message with an id that is
// already shown counts up (x2, x3) and restarts its timer.
// ============================================================
(function () {
    'use strict';

    var root = document.getElementById('mn-root');
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

    function applyLayout(l) {
        if (!l) return;
        var t = l.toast || {}, s = stacks.toast.style;
        var pos = String(t.position || 'top-right');
        var right = pos.indexOf('left') < 0;
        s.left = s.right = s.top = s.bottom = s.transform = '';
        s.width = (t.width || 340) + 'px';
        if (right) s.right = (t.x || 0) + 'px'; else s.left = (t.x || 0) + 'px';
        if (pos.indexOf('bottom') === 0) s.bottom = (t.y || 0) + 'px';
        else if (pos.indexOf('middle') === 0) { s.top = '50%'; s.transform = 'translateY(-50%)'; }
        else s.top = (t.y || 0) + 'px';
        stacks.toast.classList.toggle('mn-left', !right);
        stacks.tip.style.bottom = ((l.tip && l.tip.y) || 0) + 'px';
        stacks.objective.style.top = ((l.objective && l.objective.y) || 0) + 'px';
        stacks.banner.style.top = ((l.banner && l.banner.top) || 30) + '%';
        ['toast', 'tip', 'objective', 'banner'].forEach(function (k) {
            if (l[k] && l[k].max > 0) max[k] = l[k].max;
        });
        root.classList.toggle('mc-cyrillic', !!l.cyrillic);
    }

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
        requestAnimationFrame(function () { requestAnimationFrame(function () { b.el.classList.add('mn-in'); }); });
    }

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.action === 'notify') { applyLayout(d.layout); show(d.n); }
        else if (d.action === 'clear') remove(String(d.id));
        else if (d.action === 'clearAll') Object.keys(items).forEach(remove);
    });
})();
