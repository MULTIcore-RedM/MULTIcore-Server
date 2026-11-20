// MULTIcore menus and dialogs. Messages from client/multi/ui.lua:
//   ui:context { title, back, canClose, rows, words }   ui:contextHide
//   ui:input { heading, rows, allowCancel, words }       ui:alert { header, content, cancel, confirm, cancelLabel, words }
//   ui:dialogHide   ui:progress { label, duration, canCancel, words }   ui:progressHide
//   ui:text { text, icon }   ui:textHide
// Every word shown comes from Lua (words = the locale lines); player text is set with textContent only.
(function () {
    'use strict';
    var root = document.createElement('div');
    root.className = 'mc-root mu-root';
    document.body.appendChild(root);

    var words = {};
    var ctx = null;          // { el, rows, sel, back, canClose }
    var dlg = null;          // { el, kind, rows, allowCancel, cancel }
    var prog = null, text = null;

    function post(name, body) {
        if (typeof GetParentResourceName !== 'function') return;
        fetch('https://' + GetParentResourceName() + '/' + name, { method: 'POST', body: JSON.stringify(body || {}) }).catch(function () {});
    }
    function el(tag, cls, txt) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (txt != null) e.textContent = txt;
        return e;
    }
    function icon(i) {
        i = String(i || '').trim();
        if (!i || !/^[a-z0-9 -]+$/i.test(i)) return null;
        if (!/\bfa-(solid|regular|brands)\b|\bfa[srb]\b/.test(i)) i = 'fa-solid ' + (i.indexOf('fa-') === 0 ? i : 'fa-' + i);
        return el('i', i + ' mu-icon');
    }
    function W(k, fallback) { return words[k] || fallback; }

    // ---------- context menu ----------
    function closeCtx() { if (ctx) { ctx.el.remove(); ctx = null; } }

    function showMeta(r) {
        var old = ctx.el.querySelector('.mu-meta');
        if (old) old.remove();
        if (!r || !r.metadata || !r.metadata.length) return;
        var box = el('div', 'mc-panel mu-meta');
        r.metadata.forEach(function (m) {
            var line = el('div', 'mu-m' + (m.progress != null ? ' mu-mprog' : ''));
            line.appendChild(el('span', null, m.label));
            if (m.value != null) line.appendChild(el('span', null, m.value));
            if (m.progress != null) {
                var bar = el('div', 'mu-bar'), f = el('span');
                f.style.width = Math.max(0, Math.min(100, m.progress)) + '%';
                bar.appendChild(f); line.appendChild(bar);
            }
            box.appendChild(line);
        });
        ctx.el.appendChild(box);
    }

    function select(n) {
        if (!ctx) return;
        var rows = ctx.list.children;
        if (!rows.length) return;
        ctx.sel = (n + rows.length) % rows.length;
        for (var i = 0; i < rows.length; i++) rows[i].classList.toggle('active', i === ctx.sel);
        rows[ctx.sel].scrollIntoView({ block: 'nearest' });
        showMeta(ctx.back ? (ctx.sel === 0 ? null : ctx.rows[ctx.sel - 1]) : ctx.rows[ctx.sel]);
    }

    function pickRow(i) {
        if (ctx.back && i === 0) return post('ui:contextBack');
        var r = ctx.rows[ctx.back ? i - 1 : i];
        if (!r || r.readOnly || r.disabled) return;
        post('ui:contextPick', { index: (ctx.back ? i : i + 1) });
    }

    function openCtx(m) {
        closeCtx();
        var panel = el('section', 'mc-panel mu-ctx mc-fade');
        panel.appendChild(el('h1', 'mc-title', m.title || ''));
        panel.appendChild(el('hr', 'mc-rule'));
        var list = el('div', 'mu-rows mc-scroll');
        panel.appendChild(list);
        ctx = { el: panel, list: list, rows: m.rows || [], sel: 0, back: !!m.back, canClose: m.canClose !== false };

        if (ctx.back) {
            var b = el('div', 'mc-row mu-row mu-back');
            b.appendChild(el('i', 'fa-solid fa-chevron-left mu-icon'));
            b.appendChild(el('span', 'mu-t', W('ui_back', 'Back')));
            list.appendChild(b);
        }
        ctx.rows.forEach(function (r) {
            var row = el('div', 'mc-row mu-row' + (r.readOnly ? ' mu-read' : '') + (r.disabled ? ' disabled' : ''));
            var ic = icon(r.icon);
            if (ic) row.appendChild(ic); else row.classList.add('mu-noicon');
            var t = el('span', 'mu-t', r.title || '');
            if (r.description) t.appendChild(el('span', 'mu-d', r.description));
            row.appendChild(t);
            row.appendChild(r.arrow ? el('i', 'fa-solid fa-chevron-right mu-more') : el('span'));
            if (r.progress != null) {
                var bar = el('div', 'mu-bar'), f = el('span');
                f.style.width = Math.max(0, Math.min(100, r.progress)) + '%';
                bar.appendChild(f); row.appendChild(bar);
            }
            if (r.image && /^(https?|nui):\/\//.test(r.image)) { var im = el('img', 'mu-img'); im.src = r.image; row.appendChild(im); }
            list.appendChild(row);
        });
        Array.prototype.forEach.call(list.children, function (row, i) {
            row.addEventListener('mouseenter', function () { select(i); });
            row.addEventListener('click', function () { select(i); pickRow(i); });
        });
        root.appendChild(panel);
        // start on the first row that can be used
        var start = 0;
        for (var i = 0; i < list.children.length; i++) {
            var rr = ctx.back ? (i === 0 ? null : ctx.rows[i - 1]) : ctx.rows[i];
            if (rr && !rr.readOnly && !rr.disabled) { start = i; break; }
        }
        select(start);
    }

    // ---------- dialogs ----------
    function closeDlg() { if (dlg) { dlg.el.remove(); dlg = null; } }

    function field(r, i) {
        var wrap;
        var label = (r.label || '') ;
        if (r.type === 'checkbox') {
            wrap = el('label', 'mu-check');
            var cb = el('input'); cb.type = 'checkbox'; cb.checked = !!r.checked; cb.disabled = !!r.disabled;
            wrap.appendChild(cb); wrap.appendChild(el('span', null, label));
            return { el: wrap, get: function () { return cb.checked; } };
        }
        wrap = el('div', 'mc-field');
        var lab = el('label', null, label);
        if (r.required) lab.appendChild(el('span', 'mu-req', '*'));
        wrap.appendChild(lab);
        if (r.description) wrap.appendChild(el('div', 'mu-desc', r.description));
        var inp, get;
        if (r.type === 'select') {
            inp = el('select', 'mc-select');
            if (!r.required) inp.appendChild(el('option', null, ''));
            (r.options || []).forEach(function (o, j) {
                var op = el('option', null, o.label); op.value = String(j);
                if (r.default != null && String(o.value) === String(r.default)) op.selected = true;
                inp.appendChild(op);
            });
            get = function () { var j = inp.value; return j === '' ? null : r.options[Number(j)].value; };
        } else if (r.type === 'multi-select') {
            inp = el('div', 'mu-multi');
            var boxes = [];
            var def = Array.isArray(r.default) ? r.default.map(String) : [];
            (r.options || []).forEach(function (o) {
                var l = el('label', 'mu-check'), c = el('input'); c.type = 'checkbox'; c.checked = def.indexOf(String(o.value)) >= 0;
                l.appendChild(c); l.appendChild(el('span', null, o.label)); inp.appendChild(l); boxes.push(c);
            });
            get = function () { var v = []; boxes.forEach(function (c, j) { if (c.checked) v.push(r.options[j].value); }); return v.length ? v : null; };
        } else if (r.type === 'textarea') {
            inp = el('textarea', 'mc-textarea');
            if (r.default != null) inp.value = String(r.default);
            if (r.max) inp.maxLength = r.max;
            get = function () { return inp.value === '' ? null : inp.value; };
        } else if (r.type === 'slider') {
            wrap = el('div', 'mc-slider');
            var val = el('span', 'mc-slider-value');
            wrap.appendChild(el('span', 'mc-slider-label', label)); wrap.appendChild(val);
            inp = el('input'); inp.type = 'range';
            inp.min = r.min != null ? r.min : 0; inp.max = r.max != null ? r.max : 100; inp.step = r.step || 1;
            inp.value = r.default != null ? r.default : inp.min;
            val.textContent = inp.value;
            inp.addEventListener('input', function () { val.textContent = inp.value; });
            wrap.appendChild(inp);
            return { el: wrap, get: function () { return Number(inp.value); }, input: inp };
        } else {
            inp = el('input', 'mc-input');
            inp.type = r.type === 'number' ? 'number' : r.type === 'color' ? 'color' : r.type === 'date' ? 'date' : r.type === 'time' ? 'time' : (r.password ? 'password' : 'text');
            if (r.placeholder) inp.placeholder = r.placeholder;
            if (r.default != null) inp.value = String(r.default);
            if (r.type === 'number') {
                if (r.min != null) inp.min = r.min; if (r.max != null) inp.max = r.max; if (r.step) inp.step = r.step;
                get = function () {
                    if (inp.value === '') return null;
                    var n = Number(inp.value);
                    if (isNaN(n)) return null;
                    if (r.min != null) n = Math.max(r.min, n);
                    if (r.max != null) n = Math.min(r.max, n);
                    return n;
                };
            } else {
                if (r.max) inp.maxLength = r.max;
                get = function () { return inp.value === '' ? null : inp.value; };
            }
        }
        inp.disabled = !!r.disabled;
        wrap.appendChild(inp);
        return { el: wrap, get: get, input: inp };
    }

    function finishInput(cancel) {
        if (!dlg) return;
        if (cancel) {
            if (!dlg.allowCancel) return;
            closeDlg(); return post('ui:inputDone', { cancel: true });
        }
        var values = {}, missing = false;
        dlg.fields.forEach(function (f, i) {
            var v = f.get();
            var r = dlg.rows[i];
            if (r.required && (v == null || (r.type === 'input' && r.min && String(v).length < r.min))) missing = true;
            values[i] = v;
        });
        if (missing) { dlg.err.textContent = W('ui_required', ''); return; }
        closeDlg();
        post('ui:inputDone', { values: values });
    }

    function openInput(m) {
        closeDlg();
        var p = el('section', 'mc-panel mu-dlg mc-fade');
        p.appendChild(el('h1', 'mc-title', m.heading || ''));
        p.appendChild(el('hr', 'mc-rule'));
        var box = el('div', 'mu-fields mc-scroll');
        var fields = (m.rows || []).map(function (r, i) { var f = field(r, i); box.appendChild(f.el); return f; });
        p.appendChild(box);
        var err = el('div', 'mu-err');
        p.appendChild(err);
        var btns = el('div', 'mc-btn-row mu-btns');
        if (m.allowCancel !== false) {
            var c = el('button', 'mc-btn', W('ui_cancel', 'Cancel'));
            c.addEventListener('click', function () { finishInput(true); });
            btns.appendChild(c);
        }
        var ok = el('button', 'mc-btn primary', W('ui_confirm', 'Confirm'));
        ok.addEventListener('click', function () { finishInput(false); });
        btns.appendChild(ok);
        p.appendChild(btns);
        root.appendChild(p);
        dlg = { el: p, kind: 'input', rows: m.rows || [], fields: fields, err: err, allowCancel: m.allowCancel !== false };
        var first = fields.filter(function (f) { return f.input && !f.input.disabled; })[0];
        if (first) setTimeout(function () { first.input.focus(); }, 0);
    }

    function finishAlert(confirm) {
        if (!dlg) return;
        if (!confirm && !dlg.cancel) confirm = false;
        closeDlg();
        post('ui:alertDone', { confirm: !!confirm });
    }

    function openAlert(m) {
        closeDlg();
        var p = el('section', 'mc-panel mu-dlg mc-fade');
        p.appendChild(el('h1', 'mc-title', m.header || ''));
        p.appendChild(el('hr', 'mc-rule'));
        // ox_lib content is markdown; **bold** and line breaks are kept, the rest shows as text
        var content = el('div', 'mu-content');
        String(m.content || '').split(/(\*\*[^*]+\*\*)/).forEach(function (part) {
            if (/^\*\*[^*]+\*\*$/.test(part)) content.appendChild(el('b', null, part.slice(2, -2)));
            else content.appendChild(document.createTextNode(part.replace(/[#_`>]/g, '')));
        });
        p.appendChild(content);
        var btns = el('div', 'mc-btn-row mu-btns');
        if (m.cancel) {
            var c = el('button', 'mc-btn', m.cancelLabel || W('ui_cancel', 'Cancel'));
            c.addEventListener('click', function () { finishAlert(false); });
            btns.appendChild(c);
        }
        var ok = el('button', 'mc-btn primary', m.confirm || W('ui_confirm', 'Confirm'));
        ok.addEventListener('click', function () { finishAlert(true); });
        btns.appendChild(ok);
        p.appendChild(btns);
        root.appendChild(p);
        dlg = { el: p, kind: 'alert', cancel: !!m.cancel };
        setTimeout(function () { ok.focus(); }, 0);
    }

    // ---------- progress and text prompt ----------
    function hideProg() { if (prog) { prog.remove(); prog = null; } }
    function openProg(m) {
        hideProg();
        prog = el('div', 'mc-root mu-prog');
        if (m.label) prog.appendChild(el('div', 'mu-pl', m.label));
        var track = el('div', 'mu-track'), fill = el('div', 'mu-fill');
        track.appendChild(fill); prog.appendChild(track);
        if (m.canCancel) {
            var pr = el('div', 'mc-prompts'), s = el('span');
            s.appendChild(el('span', 'mc-key', 'X')); s.appendChild(el('span', null, W('ui_cancel', 'Cancel')));
            pr.appendChild(s); prog.appendChild(pr);
        }
        root.appendChild(prog);
        var ms = Math.max(0, Number(m.duration) || 0);
        requestAnimationFrame(function () {
            fill.style.transition = 'width ' + ms + 'ms linear';
            requestAnimationFrame(function () { fill.style.width = '100%'; });
        });
    }

    function hideText() { if (text) { text.remove(); text = null; } }
    function openText(m) {
        hideText();
        text = el('div', 'mu-text');
        var ic = icon(m.icon);
        if (ic) text.appendChild(ic);
        // "[E] - Open" or "[E] Open": the key goes in a key box
        String(m.text || '').split(/(\[[^\]]{1,12}\])/).forEach(function (part) {
            if (/^\[[^\]]{1,12}\]$/.test(part)) text.appendChild(el('span', 'mc-key', part.slice(1, -1)));
            else text.appendChild(document.createTextNode(part.replace(/^\s*-\s*/, '')));
        });
        root.appendChild(text);
    }

    // ---------- keys ----------
    window.addEventListener('keydown', function (e) {
        if (dlg) {
            if (e.key === 'Escape') { e.preventDefault(); dlg.kind === 'input' ? finishInput(true) : (dlg.cancel && finishAlert(false)); }
            else if (e.key === 'Enter' && document.activeElement.tagName !== 'TEXTAREA') { e.preventDefault(); dlg.kind === 'input' ? finishInput(false) : finishAlert(true); }
            return;
        }
        if (!ctx) return;
        if (e.key === 'ArrowDown') { e.preventDefault(); select(ctx.sel + 1); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); select(ctx.sel - 1); }
        else if (e.key === 'Enter') { e.preventDefault(); pickRow(ctx.sel); }
        else if (e.key === 'Backspace' && ctx.back) { e.preventDefault(); post('ui:contextBack'); }
        else if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); if (ctx.canClose) post('ui:contextClose'); }
    });

    window.addEventListener('message', function (e) {
        var m = e.data || {};
        if (typeof m.action !== 'string' || m.action.indexOf('ui:') !== 0) return;
        if (m.words) words = m.words;
        switch (m.action) {
            case 'ui:context': openCtx(m); break;
            case 'ui:contextHide': closeCtx(); break;
            case 'ui:input': openInput(m); break;
            case 'ui:alert': openAlert(m); break;
            case 'ui:dialogHide': closeDlg(); break;
            case 'ui:progress': openProg(m); break;
            case 'ui:progressHide': hideProg(); break;
            case 'ui:text': openText(m); break;
            case 'ui:textHide': hideText(); break;
        }
    });
})();
