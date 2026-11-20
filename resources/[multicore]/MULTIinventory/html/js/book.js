// ==========================================================================
// MULTIinventory NUI - Crafting Journal (book UI). RINGO-written.
// Self-contained (app.js is a separate IIFE). No globals.
//
// Lua -> NUI  { action, data }:
//   bookOpen  BookData  { title, chapter|null, chapters[{key,label,blurb}], station{key,label}|null,
//                         maxQuantity, recipes[Recipe], locale? (optional { key = text } overrides) }
//   bookData  { recipes, station }   refresh in place (stays on the same page)
//   bookClose                        hide
// NUI -> Lua  POST https://<resource>/<action>  -> { ok, err?, data? }
//   bookList {}                       -> { recipes, station }
//   handcraftStart { id, qty, book }  -> { duration } (Lua then closes the book) | err
//   bookClose {}
// ==========================================================================
(function () {
  'use strict';

  var IN_GAME = typeof GetParentResourceName === 'function';
  var RES = IN_GAME ? GetParentResourceName() : 'MULTIinventory';
  var PAGE_W = 690;       // one page on the design canvas (css/book.css)
  var TURN_MS = 270;      // page-turn animation

  // ---------------------------------------------------------------- strings (data.locale overrides)
  var STR = {
    coverKick: "The Outfitter's Journal", coverSub: 'Receipts, remedies and handiwork, set down by hand.', open: 'Open',
    contents: 'Contents', introSub: 'Every receipt you have learned, by chapter. Turn the pages, pick a quantity and set to work.',
    recipes: '{n} receipts', recipe1: '1 receipt', ready: '{n} ready', hereTag: 'here', youAreAt: 'You are at the {s}.',
    other: 'Other', needs: 'Needs', tools: 'Tools (kept)', makes: 'Makes', each: '{s} s each', madeAt: 'Made at the {s}',
    byHand: 'Made by hand', needStation: 'You need to be at a {s}.', or: 'or', qty: 'How many', max: 'Max', craft: 'Craft',
    stReady: 'Ready ×{n}', stFull: 'No room', stNearly: 'Missing 1', stMissing: 'Missing {n}', stStation: 'Needs the {s}',
    stLocked: 'Not learned', stWait: 'Wait {s}', learn: 'Read {s} to learn this.', learnNone: 'You have not learned this yet.',
    whyLocked: 'You have not learned this yet.', whyStation: 'You need to be at a {s}.', whyWait: 'Ready again in {s}.',
    whyFull: 'No room in your bags.', whyMissing: 'You are missing ingredients.', requires: 'You must carry {s}.',
    copyTitle: 'Write a copy', copyBtn: 'Write copy', copyHint: 'A copy anyone can read and learn. {s} s.', copyMissing: 'You need paper and ink to write a copy.',
    learned: 'Learned', recipePage: 'a recipe page', pageHint: 'Recipe pages are found, looted or written by others.',
    canMake: 'You can make {n}', starting: 'Starting...', station: 'station', noRecipes: 'Nothing written in this journal yet.',
    endChapter: '', no: 'No. {n}',
    kTurn: 'turn', kChapter: 'chapter', kContents: 'contents', kAmount: 'amount', kPage: 'page', kCraft: 'craft', kClose: 'close'
  };
  var ERR = {
    missing: 'You are missing ingredients.', no_room: 'No room in your bags.', limit: 'You cannot carry more of that.',
    busy: 'You are busy.', cooldown: 'Not yet. Wait a little.', rate_limited: 'Not so fast.',
    station_far: 'You need to be at the right station.', locked: 'You have not learned this yet.',
    unknown_recipe: 'That receipt is not known.', disabled: 'Crafting is turned off.', cannot_now: 'You cannot do that right now.',
    not_ready: 'Still loading.', timeout: 'No answer from the server.', nui_error: 'Something went wrong.'
  };
  var DEFAULT_ERR = 'That did not work.';

  // ---------------------------------------------------------------- state
  var S = {
    visible: false, closed: true, single: false,
    data: null, station: null, chapters: [], byId: {}, pages: [], view: 0,
    focus: 0, qty: {}, err: null, busy: false,
    anim: null, wheelAt: 0, tick: null, refreshT: null, toastT: null
  };

  // ---------------------------------------------------------------- helpers
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function T(key, vars) {
    var loc = (S.data && S.data.locale) || {};
    var s = loc[key] != null ? String(loc[key]) : (STR[key] != null ? STR[key] : key);
    if (vars) s = s.replace(/\{(\w+)\}/g, function (m, k) { return vars[k] != null ? vars[k] : m; });
    return s;
  }
  function errText(code) {
    var loc = (S.data && S.data.locale) || {};
    if (code && loc['err_' + code]) return String(loc['err_' + code]);
    return (code && ERR[code]) || DEFAULT_ERR;
  }
  function num(n) { n = Number(n); return isFinite(n) ? n : 0; }
  function fmtWait(sec) {
    sec = Math.max(0, Math.ceil(num(sec)));
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    if (h > 0) return h + 'h ' + m + 'm';
    if (m > 0) return m + 'm ' + (s < 10 ? '0' : '') + s + 's';
    return s + 's';
  }
  function fmtSecs(ms) { var s = num(ms) / 1000; return s % 1 === 0 ? String(s) : s.toFixed(1); }
  var root = null;
  function $(sel) { return root ? root.querySelector(sel) : null; }

  function post(action, data) {
    if (!IN_GAME) {
      if (window.BookMock && typeof window.BookMock.handle === 'function') {
        try { return Promise.resolve(window.BookMock.handle(action, data || {})); } catch (e) { return Promise.resolve({ ok: false, err: 'nui_error' }); }
      }
      return Promise.resolve({ ok: false, err: 'not_ready' });
    }
    return fetch('https://' + RES + '/' + action, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {})
    }).then(function (r) { return r.json(); }).then(function (r) { return r || { ok: false, err: 'nui_error' }; })
      .catch(function () { return { ok: false, err: 'nui_error' }; });
  }

  // ---------------------------------------------------------------- images (same rules as app.js)
  function imgSrc(it) {
    var img = String((it && (it.image || (it.name ? it.name + '.png' : ''))) || '');
    if (/^(data:|https?:|nui:)/.test(img) || img.indexOf('/') !== -1) return img;
    var base = img.replace(/\.(png|webp|jpe?g|gif)$/i, '');
    return 'img/items/' + base + '.png';
  }
  function imgTag(it) {
    var base = String((it && (it.image || it.name)) || '').replace(/\.(png|webp|jpe?g|gif)$/i, '');
    return '<img draggable="false" alt="" data-base="' + esc(base) + '" data-name="' + esc(it && it.name || '') + '" src="' + esc(imgSrc(it)) + '">';
  }
  // fallback for book pictures; app.js's own document handler runs first and, when present, takes over
  document.addEventListener('error', function (e) {
    var img = e.target;
    if (!img || img.tagName !== 'IMG' || !root || !root.contains(img)) return;
    if (img.dataset.fb) return; // app.js handled it
    var st = img.dataset.bfb || '0';
    if (st === '0') {
      img.dataset.bfb = '1';
      var own = img.dataset.name ? 'img/items/' + img.dataset.name + '.png' : '';
      if (own && img.getAttribute('src') !== own) { img.src = own; return; }
    }
    if (st !== '2') { img.dataset.bfb = '2'; img.src = 'img/ui/missing.png'; return; }
    img.style.visibility = 'hidden';
  }, true);
  function icon(it, count, cls) {
    return '<span class="bk-ico ' + (cls || '') + '">' + imgTag(it) + (count > 1 ? '<span class="n">' + esc(count) + '</span>' : '') + '</span>';
  }

  // ---------------------------------------------------------------- recipe rules
  function stationFar(r) { return !!(r.station && !r.atStation) || r.status === 'station'; }
  function canCraft(r) {
    return !r.locked && r.status !== 'locked' && !stationFar(r) && !(num(r.cooldown) > 0) && r.status === 'ready' && num(r.maxCraft) >= 1;
  }
  function stamp(r) {
    if (r.locked || r.status === 'locked') return ['lock', T('stLocked')];
    if (stationFar(r)) return ['bad', T('stStation', { s: r.stationLabel || T('station') })];
    if (num(r.cooldown) > 0) return ['warn', T('stWait', { s: fmtWait(r.cooldown) })];
    if (r.status === 'ready') return ['ok', T('stReady', { n: num(r.maxCraft) })];
    if (r.status === 'full') return ['warn', T('stFull')];
    if (r.status === 'nearly') return ['warn', T('stNearly')];
    return ['bad', T('stMissing', { n: Math.max(1, num(r.missing)) })];
  }
  function whyNot(r) {
    if (r.locked || r.status === 'locked') return T('whyLocked');
    if (stationFar(r)) return T('whyStation', { s: r.stationLabel || T('station') });
    if (num(r.cooldown) > 0) return T('whyWait', { s: fmtWait(r.cooldown) });
    if (r.status === 'full') return T('whyFull');
    if (r.knownItem && r.status !== 'ready') return T('requires', { s: r.knownItem });
    if (r.status !== 'ready' || num(r.maxCraft) < 1) return T('whyMissing');
    return '';
  }
  function canCopy(r) {
    var c = r && r.copy;
    return !!c && !r.locked && c.status === 'ready' && num(c.maxCraft) >= 1 && !(num(c.cooldown) > 0);
  }
  function whyNotCopy(r) {
    var c = r && r.copy; if (!c) return '';
    if (r.locked || c.status === 'locked') return T('whyLocked');
    if (c.status === 'station') return T('whyStation', { s: r.stationLabel || T('station') });
    if (num(c.cooldown) > 0) return T('whyWait', { s: fmtWait(c.cooldown) });
    if (c.status === 'full') return T('whyFull');
    if (c.status !== 'ready' || num(c.maxCraft) < 1) return T('copyMissing');
    return '';
  }
  function copyHtml(r) {
    var c = r.copy, can = canCopy(r), isErr = S.err && S.err.id === c.id;
    var rows = (c.ingredients || []).concat(c.tools || []).map(function (g) {
      var need = num(g.need), have = num(g.have), ok = have >= need;
      return '<span class="bk-chip ' + (ok ? 'ok' : 'bad') + '">' + icon(g, 0, 'xs') + '<span>' + esc(g.label) + '</span><b>' + esc(have) + '/' + esc(need) + '</b></span>';
    }).join('');
    var why = isErr ? S.err.text : (can ? T('copyHint', { s: fmtSecs(c.time) }) : whyNotCopy(r));
    return '<div class="bk-copy ' + (can ? 'ok' : 'bad') + '" data-copybox>' +
      '<svg class="bk-quill" viewBox="0 0 32 32"><path d="M27 4 C17 6 10 13 7 24 L9 25 C11 19 14 15 18 12 C15 16 13 20 12 25 C20 22 25 15 27 4 Z M5 28 L9 25" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></svg>' +
      '<div class="bk-copy-in"><div class="bk-copy-t">' + esc(c.label || T('copyTitle')) + '<span class="bk-copy-cost">' + rows + '</span></div>' +
      '<div class="bk-copy-why' + (isErr || !can ? '' : ' soft') + '">' + esc(why) + '</div></div>' +
      '<button class="bk-btn bk-copy-btn" type="button" data-copy' + (can && !S.busy ? '' : ' disabled') + '>' + esc(T('copyBtn')) + '</button></div>';
  }
  function maxQty(r) {
    var cap = num(S.data && S.data.maxQuantity) || 20;
    return Math.max(1, Math.min(cap, Math.floor(num(r.maxCraft))));
  }
  function qtyOf(r) {
    var q = Math.floor(num(S.qty[r.id]) || 1);
    q = Math.max(1, Math.min(maxQty(r), q));
    S.qty[r.id] = q;
    return q;
  }

  // ---------------------------------------------------------------- page model
  function build() {
    var d = S.data || {}, list = Array.isArray(d.recipes) ? d.recipes : [];
    var chaps = [], byKey = {};
    (Array.isArray(d.chapters) ? d.chapters : []).forEach(function (c) {
      if (!c || c.key == null || byKey[c.key]) return;
      var ch = { key: String(c.key), label: c.label || String(c.key), blurb: c.blurb || null, recipes: [], start: -1 };
      byKey[ch.key] = ch; chaps.push(ch);
    });
    var other = null;
    S.byId = {};
    list.forEach(function (r) {
      if (!r || r.id == null) return;
      S.byId[r.id] = r;
      var ch = byKey[r.chapter];
      if (!ch) {
        if (!other) other = { key: '_other', label: T('other'), blurb: null, recipes: [], start: -1 };
        ch = other;
      }
      ch.recipes.push(r);
    });
    if (other) chaps.push(other);
    var pages = [{ t: 'intro' }, { t: 'toc' }];
    chaps.forEach(function (ch) {
      if (!ch.recipes.length) return;
      if (!S.single && pages.length % 2 === 1) pages.push({ t: 'blank' });
      ch.start = pages.length;
      ch.recipes.forEach(function (r, i) { pages.push({ t: 'recipe', id: r.id, ch: ch, n: i + 1 }); });
    });
    if (!S.single && pages.length % 2 === 1) pages.push({ t: 'blank' });
    S.chapters = chaps; S.pages = pages;
  }
  function per() { return S.single ? 1 : 2; }
  function views() { return Math.max(1, Math.ceil(S.pages.length / per())); }
  function pageAt(side) { return S.pages[S.view * per() + side] || null; }
  function recipeAt(side) { var p = pageAt(side); return p && p.t === 'recipe' ? S.byId[p.id] || null : null; }
  function anchor() {
    var p = pageAt(S.focus) || pageAt(0);
    if (p && p.t === 'recipe') return { id: p.id };
    return { t: p ? p.t : 'toc' };
  }
  function findAnchor(a) {
    for (var i = 0; i < S.pages.length; i++) {
      var p = S.pages[i];
      if (a.id != null ? (p.t === 'recipe' && p.id === a.id) : p.t === a.t) return i;
    }
    return -1;
  }
  function viewOfPage(i) { return Math.floor(Math.max(0, i) / per()); }
  function sideOfPage(i) { return S.single ? 0 : i % 2; }
  function chapterOfView(v) {
    var p = S.pages[v * per()], q = S.pages[v * per() + 1];
    var c = (p && p.ch) || (q && q.ch) || null;
    return c;
  }
  function fixFocus() {
    if (S.single) { S.focus = 0; return; }
    if (!recipeAt(S.focus)) S.focus = recipeAt(0) ? 0 : (recipeAt(1) ? 1 : 0);
  }

  // ---------------------------------------------------------------- rendering
  var ORN = '<svg class="bk-orn" viewBox="0 0 220 22"><path d="M4 11 H86 M134 11 H216" stroke="currentColor" stroke-width="1"/>' +
    '<path d="M110 3 C100 3 96 11 88 11 C96 11 100 19 110 19 C120 19 124 11 132 11 C124 11 120 3 110 3 Z" fill="none" stroke="currentColor" stroke-width="1.2"/>' +
    '<circle cx="110" cy="11" r="2.4" fill="currentColor"/></svg>';

  function folio(i, side) {
    var n = '<span>' + esc(i + 1) + '</span>';
    if (side === 0 && S.pages[i] && S.pages[i].t !== 'toc' && S.pages[i].t !== 'intro') n = '<a data-go="contents">' + esc(T('contents')) + '</a>' + n;
    return '<div class="bk-folio">' + n + '</div>';
  }
  function curls(side) {
    if (S.single) return '<div class="bk-curl back" data-turn="-1"></div><div class="bk-curl" data-turn="1"></div>';
    return '<div class="bk-curl" data-turn="' + (side === 0 ? -1 : 1) + '"></div>';
  }
  function introHtml() {
    var d = S.data || {}, h = '<div class="bk-pg intro">';
    h += '<div class="bk-head" style="align-self:stretch"><span class="bk-run">' + esc(d.title || 'Crafting Journal') + '</span><span></span></div>';
    h += '<div class="bk-intro-in">';
    h += ORN + '<h2 class="bk-title">' + esc(T('contents')) + '</h2>' + ORN;
    h += '<p class="bk-sub">' + esc(T('introSub')) + '</p>';
    if (S.station && S.station.label) h += '<div class="bk-here">' + esc(T('youAreAt', { s: S.station.label })) + '</div>';
    h += '<div class="bk-legend">' + keyLegend() + '</div>';
    h += '</div>' + folio(0, 0) + '</div>';
    return h;
  }
  function keyLegend() {
    return '<kbd>←</kbd> <kbd>→</kbd> ' + esc(T('kTurn')) + ' &nbsp; <kbd>PgUp</kbd> <kbd>PgDn</kbd> ' + esc(T('kChapter')) +
      ' &nbsp; <kbd>Home</kbd> ' + esc(T('kContents')) + '<br><kbd>↑</kbd> <kbd>↓</kbd> ' + esc(T('kAmount')) +
      ' &nbsp; <kbd>Tab</kbd> ' + esc(T('kPage')) + ' &nbsp; <kbd>Enter</kbd> ' + esc(T('kCraft')) + ' &nbsp; <kbd>Esc</kbd> ' + esc(T('kClose'));
  }
  function chapterHere(ch) {
    if (!S.station || S.station.key == null) return false;
    for (var i = 0; i < ch.recipes.length; i++) if (ch.recipes[i].station === S.station.key) return true;
    return false;
  }
  function tocHtml(i) {
    var d = S.data || {}, h = '<div class="bk-pg toc">';
    h += '<div class="bk-head"><span class="bk-run">' + esc(d.title || 'Crafting Journal') + '</span><span>' + esc(T('contents')) + '</span></div>';
    h += '<div class="bk-toc">';
    if (!S.chapters.length) h += '<p class="bk-learn">' + esc(T('noRecipes')) + '</p>';
    S.chapters.forEach(function (ch) {
      var n = ch.recipes.length, ready = ch.recipes.filter(canCraft).length, here = chapterHere(ch);
      h += '<div class="bk-toc-row' + (n ? '' : ' empty') + (here ? ' here' : '') + '"' + (n ? ' data-chap="' + esc(ch.key) + '"' : '') + '>' +
        '<span class="txt"><span class="nm">' + esc(ch.label) + (here ? '<span class="tag">' + esc(T('hereTag')) + '</span>' : '') +
        (ch.blurb ? '<small>' + esc(ch.blurb) + '</small>' : '') + '</span></span>' +
        '<span class="dots"></span><span class="ct">' + esc(n === 1 ? T('recipe1') : T('recipes', { n: n })) +
        (ready ? ' · <b>' + esc(T('ready', { n: ready })) + '</b>' : '') + '</span>' +
        '<span class="pg">' + (n ? esc(ch.start + 1) : '') + '</span></div>';
    });
    h += '</div>' + folio(i, sideOfPage(i)) + '</div>';
    return h;
  }
  function ingRow(g, qty, locked) {
    var need = g.kept ? num(g.need) : num(g.need) * qty, have = num(g.have), ok = have >= need;
    var alts = [];
    if (Array.isArray(g.alts) && g.alts.length > 1) g.alts.forEach(function (a) { if (a !== g.label) alts.push(a); });
    var altHtml = alts.length ? '<small>' + esc(T('or')) + ' ' + alts.map(esc).join(' ' + esc(T('or')) + ' ') + '</small>' : '';
    if (locked) return '<div class="bk-ing">' + icon(g, 0, 'sm') + '<span class="lbl">' + esc(g.label) + altHtml + '</span><span class="dots"></span></div>';
    return '<div class="bk-ing ' + (ok ? 'ok' : 'bad') + '">' + icon(g, 0, 'sm') + '<span class="lbl">' + esc(g.label) + altHtml + '</span>' +
      '<span class="dots"></span><b>' + esc(have) + ' / ' + esc(need) + '</b><span class="mk">' + (ok ? '✓' : '✗') + '</span></div>';
  }
  function recipeHtml(p, i, side) {
    var r = S.byId[p.id];
    if (!r) return blankHtml(i, side);
    var locked = !!(r.locked || r.status === 'locked');
    var qty = locked ? 1 : qtyOf(r), can = canCraft(r), st = stamp(r);
    var outs = Array.isArray(r.outputs) ? r.outputs : [], o = outs[0] || { name: '', label: r.label, count: 1 };
    var h = '<div class="bk-pg recipe' + (locked ? ' locked' : '') + '" data-id="' + esc(r.id) + '">';
    h += '<div class="bk-head"><span class="bk-run">' + esc(p.ch.label) + '</span><span>' + esc(T('no', { n: p.n })) + '</span></div>';
    if (p.n === 1 && p.ch.blurb) h += '<p class="bk-blurb">' + esc(p.ch.blurb) + '</p>';
    h += '<div class="bk-stamp ' + st[0] + '" data-stamp>' + esc(st[1]) + '</div>';
    var meta = [];
    if (!locked) meta.push(esc(T('each', { s: fmtSecs(r.time) })));
    meta.push(esc(r.station ? T('madeAt', { s: r.stationLabel || T('station') }) : T('byHand')));
    if (r.learned && !locked) meta.push('<span class="bk-learned">' + esc(T('learned')) + '</span>');
    h += '<div class="bk-titlerow">' + icon(o, num(o.count), '') + '<div><h2 class="bk-title">' + esc(r.label) + '</h2>' +
      '<div class="bk-meta">' + meta.join('<span class="sep">·</span>') + '</div></div></div>';
    if (r.description) h += '<p class="bk-desc">' + esc(r.description) + '</p>';
    if (!locked && stationFar(r)) h += '<div class="bk-warn">' + esc(T('needStation', { s: r.stationLabel || T('station') })) + '</div>';
    h += '<div class="bk-body">';
    if (locked) {
      h += '<div class="bk-learn">' + esc(r.unlockLabel ? T('learn', { s: r.unlockLabel }) : T('learnNone')) +
        ((r.unlockLabel === 'a recipe page' || r.unlockLabel === T('recipePage')) ? '<small class="bk-learn-hint">' + esc(T('pageHint')) + '</small>' : '') + '</div>';
      h += '<h4 class="bk-sec">' + esc(T('makes')) + '</h4><div class="bk-makes">' + outs.map(function (x) {
        return '<span class="bk-out">' + icon(x, num(x.count), 'sm') + '<span>' + esc(x.label) + '</span></span>';
      }).join('') + '</div>';
      if (r.ingredients && r.ingredients.length) {
        h += '<h4 class="bk-sec blur">' + esc(T('needs')) + '</h4>' + r.ingredients.map(function (g) { return ingRow(g, 1, true); }).join('');
      }
    } else {
      h += '<h4 class="bk-sec">' + esc(T('needs')) + '</h4>' + (r.ingredients || []).map(function (g) { return ingRow(g, qty, false); }).join('');
      if (r.tools && r.tools.length) h += '<h4 class="bk-sec">' + esc(T('tools')) + '</h4>' + r.tools.map(function (g) { return ingRow(g, 1, false); }).join('');
      h += '<h4 class="bk-sec">' + esc(T('makes')) + '</h4><div class="bk-makes">' + outs.map(function (x) {
        var c = num(x.count) * qty;
        return '<span class="bk-out">' + icon(x, c, 'sm') + '<span>' + esc(x.label) + ' ×' + esc(c) + '</span></span>';
      }).join('') + '</div>';
      if (r.knownItem) h += '<p class="bk-known">' + esc(T('requires', { s: r.knownItem })) + '</p>';
    }
    h += '</div>';
    if (!locked && r.copy) h += copyHtml(r);
    if (!locked) {
      var max = maxQty(r), dis = can ? '' : ' disabled';
      var why = (S.err && S.err.id === r.id) ? S.err.text : whyNot(r);
      var whyCls = (S.err && S.err.id === r.id) ? '' : (can ? ' soft' : '');
      if (can && !why) why = T('canMake', { n: num(r.maxCraft) });
      h += '<div class="bk-foot"><div class="bk-qty"><span class="bk-qty-l">' + esc(T('qty')) + '</span>' +
        '<button class="bk-btn" type="button" data-step="-1"' + (can && qty > 1 ? '' : ' disabled') + '>−</button>' +
        '<input type="number" min="1" max="' + max + '" value="' + qty + '" data-qty' + dis + '>' +
        '<button class="bk-btn" type="button" data-step="1"' + (can && qty < max ? '' : ' disabled') + '>+</button>' +
        '<button class="bk-btn" type="button" data-max' + (can && qty < max ? '' : ' disabled') + '>' + esc(T('max')) + '</button></div>' +
        '<button class="bk-btn bk-craft' + (S.busy ? ' busy' : '') + '" type="button" data-craft' + (can && !S.busy ? '' : ' disabled') + '>' +
        esc(S.busy ? T('starting') : T('craft') + (qty > 1 ? ' ×' + qty : '')) + '</button>' +
        '<div class="bk-why' + whyCls + '" data-why>' + esc(why) + '</div></div>';
    }
    h += folio(i, side) + '</div>';
    return h;
  }
  function blankHtml(i, side) {
    return '<div class="bk-pg blank">' + ORN + (T('endChapter') ? '<p class="bk-blurb">' + esc(T('endChapter')) + '</p>' : '') + '</div>';
  }
  function pageHtml(side) {
    var i = S.view * per() + side, p = S.pages[i];
    var h;
    if (!p) h = '<div class="bk-pg blank"></div>';
    else if (p.t === 'intro') h = introHtml();
    else if (p.t === 'toc') h = tocHtml(i);
    else if (p.t === 'recipe') h = recipeHtml(p, i, side);
    else h = blankHtml(i, side);
    return h + curls(side);
  }
  function pageEl(side) { return $(side === 0 ? '.bk-page.left' : '.bk-page.right'); }
  function renderPage(side) {
    var el = pageEl(side); if (!el) return;
    el.innerHTML = pageHtml(side);
    el.classList.toggle('focus', !S.single && S.focus === side && !!recipeAt(side));
  }
  function renderTabs() {
    var host = $('.bk-tabs'); if (!host) return;
    if (S.noTabs !== false) { host.innerHTML = ''; return; }   // chapters are picked from the Contents page
    var cur = chapterOfView(S.view), COLORS = ['#7a2a1c', '#2f4a5a', '#4d5a2a', '#6b4a1e', '#4a2e52', '#5a2a3a', '#2e5248', '#6a5a2a'];
    var k = 0;
    host.innerHTML = S.chapters.map(function (ch) {
      if (!ch.recipes.length) return '';
      var c = COLORS[k++ % COLORS.length];
      return '<div class="bk-tab' + (cur === ch ? ' active' : '') + (chapterHere(ch) ? ' here' : '') + '" style="--tab:' + c + '" data-chap="' + esc(ch.key) + '" title="' + esc(ch.label) + '">' + esc(ch.label) + '</div>';
    }).join('');
  }
  function renderNav() {
    var prev = $('.bk-arrow.prev'), next = $('.bk-arrow.next');
    if (prev) prev.disabled = false; // at the start, "back" closes to the cover
    if (next) next.disabled = !S.closed && S.view >= views() - 1;
  }
  function render() {
    if (!root) return;
    fixFocus();
    renderPage(0);
    if (!S.single) renderPage(1);
    renderTabs(); renderNav();
    $('.bk-book').classList.toggle('closed', S.closed);
  }

  // ---------------------------------------------------------------- page turning
  function finishAnim() {
    if (!S.anim) return;
    clearTimeout(S.anim.t);
    S.anim.els.forEach(function (x) { if (x.parentNode) x.parentNode.removeChild(x); });
    S.anim = null;
  }
  function stripClone(el) {
    var c = el.cloneNode(true);
    c.classList.remove('slide-in-l', 'slide-in-r');
    var inp = c.querySelectorAll('input, button'); for (var i = 0; i < inp.length; i++) inp[i].tabIndex = -1;
    return c;
  }
  function goView(v, dirHint, focusSide) {
    v = Math.max(0, Math.min(views() - 1, v));
    finishAnim();
    var fs = focusSide || 0;
    if (v === S.view && !S.closed) { if (S.focus !== fs) { S.focus = fs; render(); } return; }
    var dir = dirHint || (v > S.view ? 1 : -1);
    var wasClosed = S.closed;
    S.err = null;
    if (wasClosed) { S.closed = false; S.view = v; S.focus = fs; render(); return; }
    if (S.single) {
      S.view = v; S.focus = fs; render();
      var el = pageEl(0);
      el.classList.remove('slide-in-l', 'slide-in-r'); void el.offsetWidth;
      el.classList.add(dir > 0 ? 'slide-in-r' : 'slide-in-l');
      S.anim = { els: [], t: setTimeout(function () { el.classList.remove('slide-in-l', 'slide-in-r'); S.anim = null; }, 240) };
      return;
    }
    var L = pageEl(0), R = pageEl(1), oldL = stripClone(L), oldR = stripClone(R);
    S.view = v; S.focus = fs; render();
    var newL = stripClone(L), newR = stripClone(R);
    var spread = $('.bk-spread');
    var leaf = document.createElement('div'), under = document.createElement('div');
    leaf.className = 'bk-leaf ' + (dir > 0 ? 'fwd' : 'back');
    under.className = 'bk-under';
    var a = dir > 0 ? oldR : oldL, b = dir > 0 ? newL : newR;
    a.classList.add('face-a'); b.classList.add('face-b');
    leaf.appendChild(a); leaf.appendChild(b);
    under.style.left = (dir > 0 ? 0 : PAGE_W) + 'px';
    under.appendChild(dir > 0 ? oldL : oldR);
    spread.appendChild(under); spread.appendChild(leaf);
    void leaf.offsetWidth;
    leaf.classList.add('go');
    S.anim = { els: [leaf, under], t: setTimeout(finishAnim, TURN_MS + 20) };
  }
  function turn(d) {
    if (S.closed) { if (d > 0) openCover(); return; }
    if (d < 0 && S.view === 0) { closeCover(); return; }
    goView(S.view + d, d);
  }
  function openCover() {
    if (!S.closed) return;
    S.closed = false; S.view = S.single ? viewOfPage(1) : 0; S.focus = 0;
    render();
  }
  function closeCover() { finishAnim(); S.closed = true; render(); }
  function gotoContents() { if (S.closed) { openCover(); return; } goView(S.single ? viewOfPage(1) : 0, -1); }
  function gotoChapter(key) {
    for (var i = 0; i < S.chapters.length; i++) {
      var ch = S.chapters[i];
      if (ch.key === key && ch.start >= 0) { goView(viewOfPage(ch.start), 0, sideOfPage(ch.start)); return; }
    }
  }
  function stepChapter(d) {
    var cur = S.closed ? null : chapterOfView(S.view), list = S.chapters.filter(function (c) { return c.start >= 0; });
    if (!list.length) return;
    var idx = cur ? list.indexOf(cur) : -1, n;
    if (d > 0) n = idx + 1; else n = (cur && viewOfPage(cur.start) !== S.view) ? idx : idx - 1;
    if (n < 0) { gotoContents(); return; }
    if (n >= list.length) return;
    gotoChapter(list[n].key);
  }

  // ---------------------------------------------------------------- quantity + craft
  function focusedRecipe() { fixFocus(); return recipeAt(S.focus); }
  function setQty(r, q) {
    if (!r || r.locked) return;
    S.qty[r.id] = q; qtyOf(r);
    if (S.err && S.err.id === r.id) S.err = null;
    for (var s = 0; s < per(); s++) if (recipeAt(s) === r) renderPage(s);
  }
  function setFocus(side) {
    if (S.single || S.closed || !recipeAt(side) || S.focus === side) return;
    S.focus = side; renderPage(0); renderPage(1);
  }
  function craft(r) {
    r = r || focusedRecipe();
    if (!r || S.busy) return;
    if (!canCraft(r)) { toast(whyNot(r) || DEFAULT_ERR, 'bad'); return; }
    startCraft(r.id, qtyOf(r));
  }
  // "Write a copy" of a learned recipe: same callback and error handling as Craft, always qty 1
  function writeCopy(r) {
    r = r || focusedRecipe();
    if (!r || !r.copy || S.busy) return;
    if (!canCopy(r)) { toast(whyNotCopy(r) || DEFAULT_ERR, 'bad'); return; }
    startCraft(r.copy.id, 1);
  }
  function startCraft(id, qty) {
    S.busy = true; S.err = null; render();
    post('handcraftStart', { id: id, qty: qty, book: true }).then(function (res) {
      S.busy = false;
      if (res && res.ok) { render(); return; } // Lua closes the book and shows the progress bar
      var text = errText(res && res.err);
      S.err = { id: id, text: text };
      if (S.visible) { render(); toast(text, 'bad'); }
      refresh();
    });
  }
  function refresh() {
    clearTimeout(S.refreshT);
    S.refreshT = setTimeout(function () {
      if (!S.visible) return;
      post('bookList', {}).then(function (res) {
        if (res && res.ok && res.data && S.visible) applyData(res.data);
      });
    }, 60);
  }

  // ---------------------------------------------------------------- toast
  function toast(text, type) {
    var el = $('.bk-toast'); if (!el || !text) return;
    el.textContent = String(text);
    el.className = 'bk-toast show' + (type === 'bad' ? ' bad' : '');
    clearTimeout(S.toastT);
    S.toastT = setTimeout(function () { el.classList.remove('show'); }, 3200);
  }

  // ---------------------------------------------------------------- scale / mode
  function rescale() {
    if (!root) return;
    var W = window.innerWidth || 1366, H = window.innerHeight || 768;
    var single = W < 1100 || W / H < 1.25;
    if (single !== S.single) {
      var a = S.data ? anchor() : null;
      S.single = single; root.classList.toggle('single', single);
      if (S.data) { finishAnim(); build(); var i = findAnchor(a); S.view = viewOfPage(i < 0 ? 0 : i); S.focus = i < 0 ? 0 : sideOfPage(i); if (S.visible) render(); }
    }
    var cw = single ? 880 : 1560;
    var s = Math.min(W / cw, H / 910) * 0.95;   // keep a margin so the key bar never runs off the screen
    $('.bk-canvas').style.transform = 'scale(' + Math.max(0.3, s) + ')';
  }

  // ---------------------------------------------------------------- open / data / close
  function onOpen(d) {
    if (!d || typeof d !== 'object') return;
    ensureDom();
    finishAnim();
    S.data = d; S.station = d.station || null; S.qty = {}; S.err = null; S.busy = false;
    S.visible = true; root.classList.remove('hidden');
    rescale();
    build();
    var start = -1;
    if (d.chapter != null) for (var i = 0; i < S.chapters.length; i++) if (S.chapters[i].key === d.chapter && S.chapters[i].start >= 0) start = S.chapters[i].start;
    if (start >= 0) { S.closed = false; S.view = viewOfPage(start); S.focus = sideOfPage(start); }
    else { S.closed = true; S.view = 0; S.focus = 0; }
    paintCover();
    render();
    startTick();
  }
  function applyData(d) {
    if (!d || !S.data) return;
    var a = anchor();
    if (Array.isArray(d.recipes)) S.data.recipes = d.recipes;
    if (d.station !== undefined) { S.station = d.station || null; S.data.station = S.station; }
    finishAnim();
    build();
    var i = findAnchor(a);
    if (i >= 0) { S.view = viewOfPage(i); if (a.id != null) S.focus = sideOfPage(i); }
    else S.view = Math.min(S.view, views() - 1);
    if (S.visible) render();
  }
  function hide() {
    finishAnim();
    S.visible = false; S.busy = false;
    clearInterval(S.tick); S.tick = null;
    if (root) root.classList.add('hidden');
  }
  function closeBook() { if (!S.visible) return; hide(); post('bookClose', {}); }

  function startTick() {
    clearInterval(S.tick);
    S.tick = setInterval(function () {
      if (!S.visible || !S.data) return;
      var hit = false, ended = false;
      (S.data.recipes || []).forEach(function (r) {
        if (num(r.cooldown) > 0) { r.cooldown = Math.max(0, num(r.cooldown) - 1); hit = true; if (r.cooldown === 0) ended = true; }
      });
      if (!hit || S.closed) return;
      for (var s = 0; s < per(); s++) {
        var r = recipeAt(s);
        if (!r) continue;
        var el = pageEl(s), st = stamp(r);
        var stEl = el.querySelector('[data-stamp]'); if (stEl) { stEl.textContent = st[1]; stEl.className = 'bk-stamp ' + st[0]; }
        var why = el.querySelector('[data-why]'); if (why && !(S.err && S.err.id === r.id) && num(r.cooldown) > 0) why.textContent = whyNot(r);
      }
      if (ended) refresh();
    }, 1000);
  }

  // ---------------------------------------------------------------- DOM
  function paintCover() {
    var d = S.data || {};
    var t = $('.bk-cover-title'); if (t) t.textContent = d.title || 'Crafting Journal';
    var k = $('.bk-cover-kick'); if (k) k.textContent = T('coverKick');
    var s = $('.bk-cover-sub'); if (s) s.textContent = T('coverSub');
    var o = $('.bk-cover-open'); if (o) o.textContent = T('open');
    var keys = $('.bk-keys');
    if (keys) keys.innerHTML = '<span><kbd>←</kbd><kbd>→</kbd> ' + esc(T('kTurn')) + '</span><span><kbd>PgUp</kbd><kbd>PgDn</kbd> ' + esc(T('kChapter')) +
      '</span><span><kbd>Home</kbd> ' + esc(T('kContents')) + '</span><span><kbd>↑</kbd><kbd>↓</kbd> ' + esc(T('kAmount')) +
      '</span><span><kbd>Tab</kbd> ' + esc(T('kPage')) + '</span><span><kbd>Enter</kbd> ' + esc(T('kCraft')) + '</span><span><kbd>Esc</kbd> ' + esc(T('kClose')) + '</span>';
  }
  function ensureDom() {
    if (root && root.querySelector('.bk-canvas')) return;
    root = document.getElementById('book');
    if (!root) { root = document.createElement('div'); root.id = 'book'; root.className = 'hidden'; document.body.appendChild(root); }
    var fits = '<i class="bk-corner-fit tl"></i><i class="bk-corner-fit tr"></i><i class="bk-corner-fit bl"></i><i class="bk-corner-fit br"></i>';
    root.innerHTML =
      '<div class="bk-fit"><div class="bk-canvas">' +
        '<div class="bk-book closed">' +
          '<div class="bk-boards"></div>' + fits +
          '<div class="bk-tabs"></div>' +
          '<div class="bk-spread"><div class="bk-page left"></div><div class="bk-page right"></div></div>' +
          '<div class="bk-cover" data-act="open"><div class="bk-cover-face">' + fits +
            '<div class="bk-medal"><svg><use href="#icon-multi-r"></use></svg></div>' +
            '<div class="bk-cover-kick"></div><h1 class="bk-cover-title"></h1><div class="bk-cover-sub"></div>' +
            '<div class="bk-cover-open"></div>' +
          '</div></div>' +
        '</div>' +
        '<button class="bk-arrow prev" type="button" data-turn="-1">‹</button>' +
        '<button class="bk-arrow next" type="button" data-turn="1">›</button>' +
        '<button class="bk-close" type="button" data-close title="Esc"><svg><use href="#icon-close"></use></svg></button>' +
        '<div class="bk-keys"></div><div class="bk-toast"></div>' +
      '</div></div>';
    bind();
  }
  function closest(e, sel) {
    var t = e.target; if (t && t.nodeType === 3) t = t.parentElement;
    return t && t.closest ? t.closest(sel) : null;
  }
  function bind() {
    root.addEventListener('click', function (e) {
      if (!S.visible) return;
      var t = e.target, b;
      if (t === root || (t.classList && (t.classList.contains('bk-fit') || t.classList.contains('bk-canvas')))) { closeBook(); return; }
      if (closest(e, '[data-close]')) { closeBook(); return; }
      if (closest(e, '[data-act="open"]')) { openCover(); return; }
      if ((b = closest(e, '[data-turn]'))) { if (!b.disabled) turn(Number(b.getAttribute('data-turn'))); return; }
      if ((b = closest(e, '[data-chap]'))) { gotoChapter(b.getAttribute('data-chap')); return; }
      if (closest(e, '[data-go="contents"]')) { gotoContents(); return; }
      var pg = closest(e, '.bk-page');
      var side = pg ? (pg.classList.contains('right') ? 1 : 0) : -1;
      if (side >= 0) setFocus(side);
      var r = side >= 0 ? recipeAt(side) : null;
      if (!r) return;
      if ((b = closest(e, '[data-step]'))) { if (!b.disabled) setQty(r, qtyOf(r) + Number(b.getAttribute('data-step'))); return; }
      if ((b = closest(e, '[data-max]'))) { if (!b.disabled) setQty(r, maxQty(r)); return; }
      if ((b = closest(e, '[data-craft]'))) { if (!b.disabled) craft(r); return; }
      if ((b = closest(e, '[data-copy]'))) { if (!b.disabled) writeCopy(r); return; }
    });
    root.addEventListener('change', function (e) {
      var inp = closest(e, '[data-qty]'); if (!inp) return;
      var pg = closest(e, '.bk-page'), side = pg && pg.classList.contains('right') ? 1 : 0;
      setQty(recipeAt(side), Number(inp.value));
    });
    root.addEventListener('wheel', function (e) {
      if (!S.visible || !e.deltaY) return;
      var sc = closest(e, '.bk-body, .bk-toc');
      if (sc && sc.scrollHeight > sc.clientHeight + 1) {
        var canDown = sc.scrollTop + sc.clientHeight < sc.scrollHeight - 1, canUp = sc.scrollTop > 0;
        if ((e.deltaY > 0 && canDown) || (e.deltaY < 0 && canUp)) return;
      }
      e.preventDefault();
      var now = Date.now();
      if (now - S.wheelAt < 280) return;
      S.wheelAt = now;
      turn(e.deltaY > 0 ? 1 : -1);
    }, { passive: false });
  }

  // keyboard: window capture runs before app.js's document listener; swallow keys while the book is up
  window.addEventListener('keydown', function (e) {
    if (!S.visible) return;
    e.stopPropagation();
    var k = e.key, inInput = e.target && e.target.matches && e.target.matches('input[data-qty]');
    if (inInput) {
      if (k === 'Enter') { e.preventDefault(); var pg = e.target.closest('.bk-page'), side = pg && pg.classList.contains('right') ? 1 : 0, r0 = recipeAt(side); setQty(r0, Number(e.target.value)); craft(r0); return; }
      if (k === 'Escape') { e.preventDefault(); e.target.blur(); return; }
      if (k !== 'ArrowUp' && k !== 'ArrowDown' && k !== 'Tab') return; // typing digits / editing
      e.target.blur();
    }
    if (e.repeat && (k === 'Enter' || k === 'Escape' || k === 'Backspace')) { e.preventDefault(); return; }
    var r;
    switch (k) {
      case 'Escape': case 'Backspace': e.preventDefault(); closeBook(); return;
      case 'ArrowRight': case 'd': case 'D': e.preventDefault(); turn(1); return;
      case 'ArrowLeft': case 'a': case 'A': e.preventDefault(); turn(-1); return;
      case 'Home': e.preventDefault(); gotoContents(); return;
      case 'PageDown': e.preventDefault(); stepChapter(1); return;
      case 'PageUp': e.preventDefault(); stepChapter(-1); return;
      case 'ArrowUp': case '+': case '=': e.preventDefault(); r = focusedRecipe(); if (r && canCraft(r)) setQty(r, qtyOf(r) + 1); return;
      case 'ArrowDown': case '-': case '_': e.preventDefault(); r = focusedRecipe(); if (r && canCraft(r)) setQty(r, qtyOf(r) - 1); return;
      case 'm': case 'M': e.preventDefault(); r = focusedRecipe(); if (r && canCraft(r)) setQty(r, maxQty(r)); return;
      case 'c': case 'C': e.preventDefault(); r = focusedRecipe(); if (r && r.copy) writeCopy(r); return;
      case 'Tab': e.preventDefault(); if (!S.single) setFocus(S.focus === 0 ? 1 : 0); return;
      case '1': e.preventDefault(); setFocus(0); return;
      case '2': e.preventDefault(); setFocus(1); return;
      case 'Enter': case ' ':
        e.preventDefault();
        if (S.closed) { openCover(); return; }
        if (pageAt(S.focus) && pageAt(S.focus).t === 'toc') return;
        craft(); return;
    }
  }, true);
  window.addEventListener('resize', function () { if (root) rescale(); });
  document.addEventListener('visibilitychange', function () { if (!document.hidden && S.visible) refresh(); });

  // ---------------------------------------------------------------- messages
  var HANDLERS = {
    bookOpen: onOpen,
    bookData: function (d) { if (S.visible) applyData(d); else if (S.data && d) { if (Array.isArray(d.recipes)) S.data.recipes = d.recipes; if (d.station !== undefined) S.data.station = S.station = d.station || null; } },
    bookClose: hide
  };
  window.addEventListener('message', function (e) {
    var m = e.data;
    if (!m || typeof m !== 'object' || !m.action || !HANDLERS[m.action]) return;
    try { HANDLERS[m.action](m.data); } catch (err) { console.error('[MULTIinventory book] ' + m.action + ': ' + (err && err.stack || err)); }
  });

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ensureDom); else ensureDom();
})();
