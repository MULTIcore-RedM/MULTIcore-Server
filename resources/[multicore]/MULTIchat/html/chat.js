// MULTIchat page. Messages from client/main.lua:
//   { action: 'init', text, lang, scale, max, maxLength, fade, styles }
//   { action: 'message', message: { mc, ok, args, color, template, templateId } }
//   { action: 'suggestions', list: [ { name, help, params } ] }   { action: 'removeSuggestion', name }
//   { action: 'template', id, html }   { action: 'clear' }   { action: 'open' }   { action: 'close' }
//   { action: 'hidden', on }
(function () {
    'use strict';
    var root = document.getElementById('chat');
    var feed = document.getElementById('feed');
    var lines = document.getElementById('lines');
    var box = document.getElementById('box');
    var input = document.getElementById('input');
    var suggestBox = document.getElementById('suggest');

    var text = {};
    var max = 100, fadeMs = 12000;
    var templates = {};
    var suggestions = {};      // name -> { name, help, params }
    var shown = [];            // suggestions on screen
    var pick = 0;
    var history = [], histPos = -1;
    var isOpen = false, fadeTimer = null;

    function post(name, body) {
        if (typeof GetParentResourceName !== 'function') return;
        fetch('https://' + GetParentResourceName() + '/' + name, { method: 'POST', body: JSON.stringify(body || {}) }).catch(function () {});
    }

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }
    function strip(s) { return String(s == null ? '' : s).replace(/\^[0-9*_~=r]/g, ''); }
    // escaped text with ^0 - ^9 colour codes turned into spans
    function colour(s) {
        var open = 0;
        var out = esc(s).replace(/\^([0-9*_~=r])/g, function (_, c) {
            if (!/[0-9]/.test(c)) return '';
            var close = open ? '</span>' : '';
            open = 1;
            return close + '<span class="mch-c' + c + '">';
        });
        return out + (open ? '</span>' : '');
    }
    function rgb(c) {
        if (!Array.isArray(c) || c.length < 3) return null;
        var n = c.slice(0, 3).map(function (x) { return Math.max(0, Math.min(255, Number(x) || 0)); });
        if (n[0] === 255 && n[1] === 255 && n[2] === 255) return null;
        return 'rgb(' + n.join(',') + ')';
    }

    // ---------- lines ----------
    function build(m) {
        var args = Array.isArray(m.args) ? m.args : (m.args && typeof m.args === 'object' ? Object.keys(m.args).map(function (k) { return m.args[k]; }) : []);
        var line = document.createElement('div');
        var kind = { me: 1, 'do': 1, 'try': 1, say: 1, system: 1 }[m.mc] ? m.mc : 'system';
        line.className = 'mch-line mch-' + kind;

        if (m.mc === 'me' || m.mc === 'do') {
            line.textContent = strip(args[0]);
        } else if (m.mc === 'try') {
            line.textContent = strip(args[0]) + ' ';
            var r = document.createElement('span');
            r.className = m.ok ? 'mch-good' : 'mch-bad';
            r.textContent = strip(args[1]);
            line.appendChild(r);
        } else if (m.mc === 'say') {
            var b = document.createElement('b');
            b.textContent = strip(args[0]) + ':';
            line.appendChild(b);
            line.appendChild(document.createTextNode(strip(args[1])));
        } else if (m.mc === 'system') {
            line.innerHTML = colour(args.join(' '));
        } else {
            // a standard chat message from another script
            var tpl = (m.templateId && templates[m.templateId]) || m.template || (args.length > 1 ? '<b>{0}</b>: {1}' : '{0}');
            line.innerHTML = String(tpl).replace(/\{(\d+)\}/g, function (_, i) { return colour(args[Number(i)]); });
            var col = rgb(m.color);
            if (col) line.style.color = col;
        }
        return line;
    }

    function addLine(m) {
        if (!m || typeof m !== 'object') return;
        var atBottom = feed.scrollTop + feed.clientHeight >= feed.scrollHeight - 4;
        lines.appendChild(build(m));
        while (lines.children.length > max) lines.removeChild(lines.firstChild);
        if (atBottom || !isOpen) feed.scrollTop = feed.scrollHeight;
        wake();
    }

    function wake() {
        feed.classList.remove('mch-faded');
        clearTimeout(fadeTimer);
        if (!isOpen) fadeTimer = setTimeout(function () { if (!isOpen) feed.classList.add('mch-faded'); }, fadeMs);
    }

    // ---------- suggestions ----------
    function renderSuggest() {
        var v = input.value;
        shown = [];
        if (v.charAt(0) === '/') {
            var word = v.split(' ')[0].toLowerCase();
            var typedArgs = v.split(' ').length - 1;
            Object.keys(suggestions).sort().forEach(function (k) {
                var s = suggestions[k];
                var n = s.name.toLowerCase();
                if (typedArgs ? n === word : n.indexOf(word) === 0) shown.push(s);
            });
            shown = shown.slice(0, 6);
            suggestBox.innerHTML = '';
            shown.forEach(function (s, i) {
                var row = document.createElement('div');
                row.className = 'mch-sug' + (i === pick ? ' on' : '');
                var nm = document.createElement('span');
                nm.className = 'mch-name';
                nm.textContent = s.name;
                row.appendChild(nm);
                (Array.isArray(s.params) ? s.params : []).forEach(function (p, pi) {
                    var ps = document.createElement('span');
                    ps.className = 'mch-param' + (typedArgs === pi + 1 ? ' on' : '');
                    ps.textContent = '[' + strip(p && p.name || '') + ']';
                    row.appendChild(ps);
                });
                if (s.help) {
                    var h = document.createElement('span');
                    h.className = 'mch-help';
                    h.textContent = strip(s.help);
                    row.appendChild(h);
                }
                row.addEventListener('mousedown', function (e) { e.preventDefault(); complete(s); });
                suggestBox.appendChild(row);
            });
        }
        suggestBox.classList.toggle('mc-hidden', shown.length === 0);
    }

    function complete(s) {
        input.value = s.name + ' ';
        pick = 0;
        renderSuggest();
        input.focus();
    }

    // ---------- open / close ----------
    function openBox() {
        isOpen = true;
        root.classList.add('mch-open');
        box.classList.remove('mc-hidden');
        feed.classList.remove('mch-faded');
        clearTimeout(fadeTimer);
        input.value = '';
        histPos = -1;
        pick = 0;
        renderSuggest();
        setTimeout(function () { input.focus(); }, 0);
        feed.scrollTop = feed.scrollHeight;
    }

    function closeBox() {
        isOpen = false;
        root.classList.remove('mch-open');
        box.classList.add('mc-hidden');
        suggestBox.classList.add('mc-hidden');
        input.blur();
        feed.scrollTop = feed.scrollHeight;
        wake();
    }

    function send(canceled) {
        var v = input.value;
        if (!canceled && v.trim() !== '') {
            history.unshift(v);
            if (history.length > 50) history.pop();
        }
        post('chatResult', { message: canceled ? '' : v, canceled: !!canceled });
        closeBox();
    }

    input.addEventListener('input', function () { pick = 0; renderSuggest(); });
    input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); send(false); }
        else if (e.key === 'Escape') { e.preventDefault(); send(true); }
        else if (e.key === 'Tab') {
            e.preventDefault();
            if (shown[pick]) complete(shown[pick]);
        } else if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
            e.preventDefault();
            var up = e.key === 'ArrowUp';
            if (shown.length > 1 && input.value.indexOf(' ') < 0) {
                pick = (pick + (up ? shown.length - 1 : 1)) % shown.length;
                renderSuggest();
            } else if (history.length) {
                histPos = Math.max(-1, Math.min(history.length - 1, histPos + (up ? 1 : -1)));
                input.value = histPos < 0 ? '' : history[histPos];
                renderSuggest();
            }
        }
    });

    // ---------- messages from the game ----------
    window.addEventListener('message', function (e) {
        var m = e.data || {};
        switch (m.action) {
            case 'init':
                text = m.text || {};
                max = Number(m.max) || 100;
                fadeMs = (Number(m.fade) || 12) * 1000;
                input.maxLength = Number(m.maxLength) || 256;
                input.placeholder = text.placeholder || '';
                root.style.setProperty('--mch-scale', Number(m.scale) || 1);
                root.classList.toggle('mc-cyrillic', /^(ru|uk|bg|el|zh|ja|ko|ar|th|vi)$/.test(m.lang));
                Object.keys(m.styles || {}).forEach(function (k) {
                    var s = m.styles[k] || {};
                    ['text', 'bg', 'good', 'bad'].forEach(function (f) {
                        if (typeof s[f] === 'string' && /^[#a-z0-9(),.\s%-]+$/i.test(s[f])) {
                            root.style.setProperty('--mch-' + k + '-' + f, s[f]);
                        }
                    });
                });
                break;
            case 'message': addLine(m.message); break;
            case 'suggestions':
                (m.list || []).forEach(function (s) {
                    if (!s || !s.name) return;
                    var old = suggestions[s.name];
                    // a later list without help text never wipes help a script already gave
                    suggestions[s.name] = { name: s.name, help: s.help || (old && old.help) || '', params: s.params || (old && old.params) || [] };
                });
                if (isOpen) renderSuggest();
                break;
            case 'removeSuggestion': delete suggestions[m.name]; break;
            case 'template': templates[m.id] = m.html; break;
            case 'clear': lines.innerHTML = ''; break;
            case 'open': openBox(); break;
            case 'close': if (isOpen) closeBox(); break;
            case 'hidden': root.classList.toggle('mch-off', !!m.on); break;
        }
    });

    post('loaded');
})();
