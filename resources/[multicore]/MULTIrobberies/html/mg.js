// MULTIrobberies minigames (NUI)
//   lock: a pin tumbler lock seen from the side. The mouse moves the pick along the pins (left / right)
//         and lifts the pin above it (up / down). Pins bind one at a time in a hidden order; the binding
//         pin feels stiff and sets with a click when held at the shear line. Pushing it far past the
//         line strains the pick until it snaps.
//   safe: a combination dial 0-99. Turn LEFT to the first number, RIGHT to the second, LEFT to the
//         third... Every number gives a light tick; the right number gives a heavy click. Turning back
//         on the right number sets it; turning back anywhere else lets the tumblers fall.
// Lua sends { action: 'open', game: 'lock' | 'safe', opts, text }; the page answers POST done { ok }.
// GPL v3, part of MULTIcore by RINGO (RINGOscripting).
(function () {
    'use strict';
    var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'MULTIrobberies';
    var $ = function (id) { return document.getElementById(id); };
    var ui = $('ui'), cv = $('mg-canvas'), ctx = cv.getContext('2d');
    var W = cv.width, H = cv.height;

    var game = null;            // the running game
    var T = {};                 // text from Lua
    var colors = {};
    var mouse = { x: W / 2, y: H / 2, down: false, inside: false };
    var keys = {};

    function readColors() {
        var s = getComputedStyle(document.documentElement);
        function v(n, d) { var x = s.getPropertyValue(n).trim(); return x || d; }
        colors.ink = v('--mc-ink', '#fff');
        colors.dim = v('--mc-ink-dim', 'rgba(255,255,255,.72)');
        colors.faint = v('--mc-ink-faint', 'rgba(255,255,255,.42)');
        colors.line = v('--mc-line', 'rgba(255,255,255,.18)');
        colors.strong = v('--mc-line-strong', 'rgba(255,255,255,.55)');
        colors.field = v('--mc-field-bg', 'rgba(0,0,0,.6)');
        colors.gold = v('--mc-gold', '#d6b25e');
        colors.good = v('--mc-good', '#8fbf6a');
        colors.bad = v('--mc-bad', '#d04a3c');
        colors.red = v('--mc-red', '#c0281e');
    }
    window.addEventListener('mcpreset', function () { setTimeout(readColors, 0); });

    function t(k, a) {
        var s = T[k] || k;
        if (a !== undefined) s = s.replace('%s', a).replace('%d', a);
        return s;
    }

    function post(name, data) {
        try {
            fetch('https://' + RES + '/' + name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) });
        } catch (e) { }
    }

    // ------------------------------------------------------------------ sound (made here, no files)
    var AC = null;
    function audio() {
        if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { AC = null; } }
        if (AC && AC.state === 'suspended') AC.resume();
        return AC;
    }
    // a short burst of filtered noise: metal ticks and clicks
    function noise(freq, q, ms, vol, decay) {
        var ac = audio(); if (!ac) return;
        var len = Math.floor(ac.sampleRate * ms / 1000);
        var buf = ac.createBuffer(1, len, ac.sampleRate), d = buf.getChannelData(0);
        for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay || 4);
        var src = ac.createBufferSource(); src.buffer = buf;
        var f = ac.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = q;
        var g = ac.createGain(); g.gain.value = vol;
        src.connect(f); f.connect(g); g.connect(ac.destination);
        src.start();
    }
    function tone(freq, ms, vol) {
        var ac = audio(); if (!ac) return;
        var o = ac.createOscillator(), g = ac.createGain();
        o.type = 'triangle'; o.frequency.value = freq;
        g.gain.setValueAtTime(vol, ac.currentTime);
        g.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + ms / 1000);
        o.connect(g); g.connect(ac.destination);
        o.start(); o.stop(ac.currentTime + ms / 1000);
    }
    var SND = {
        tick: function () { noise(5200, 9, 14, 0.18, 6); },                         // dial passes a number
        heavy: function () { noise(1900, 4, 45, 0.9, 3); tone(240, 60, 0.12); },     // the right number
        set: function () { noise(2600, 5, 35, 0.7, 3); tone(520, 40, 0.06); },       // a pin / wheel sets
        spring: function () { noise(7000, 12, 10, 0.08, 6); },                       // a loose pin
        fall: function () { for (var i = 0; i < 4; i++) setTimeout(function () { noise(3500, 6, 18, 0.25, 5); }, i * 45); },
        snap: function () { noise(4200, 2, 90, 1.0, 2); },
        open: function () { noise(700, 2, 220, 0.9, 2); tone(110, 260, 0.2); },
    };

    function flash() {
        var f = $('mg-flash'); f.classList.add('on');
        setTimeout(function () { f.classList.remove('on'); }, 40);
    }
    function shake() {
        cv.classList.remove('shake'); void cv.offsetWidth; cv.classList.add('shake');
    }
    function setState(text, kind) {
        var s = $('mg-state'); s.textContent = text || ''; s.className = kind || '';
    }
    function setPips(n, on) {
        var p = $('mg-pips'), h = '';
        for (var i = 0; i < n; i++) h += '<span class="' + (i < on ? 'on' : '') + '"></span>';
        p.innerHTML = h;
    }

    // ------------------------------------------------------------------ the lock
    var PLUG_TOP = 150, PLUG_BOT = 272, REST = 236, CH_TOP = 34;
    function newLock(o) {
        var n = Math.max(2, Math.min(7, o.pins || 4));
        var g = { kind: 'lock', pins: [], order: [], bind: 0, tol: o.tolerance || 5, strain: 0, holdMs: o.holdMs || 220 };
        var x0 = 150, gap = Math.min(64, 330 / Math.max(1, n - 1));
        for (var i = 0; i < n; i++) {
            var key = 30 + Math.floor(Math.random() * 36);   // key pin length
            g.pins.push({ x: x0 + i * gap, key: key, need: (REST - key) - PLUG_TOP, lift: 0, set: false, hold: 0, jit: 0 });
            g.order.push(i);
        }
        for (var j = g.order.length - 1; j > 0; j--) { var r = Math.floor(Math.random() * (j + 1)); var tmp = g.order[j]; g.order[j] = g.order[r]; g.order[r] = tmp; }
        g.pickX = 60; g.tipY = REST + 8;
        return g;
    }

    function lockStep(g, dt) {
        // the pick follows the mouse: x along the keyway, y = how high the tip pushes
        var tx = Math.max(40, Math.min(W - 40, mouse.x));
        g.pickX += (tx - g.pickX) * Math.min(1, dt * 14);
        var ty = Math.max(PLUG_TOP - 70, Math.min(REST + 8, mouse.y));
        g.tipY += (ty - g.tipY) * Math.min(1, dt * 16);
        var tipLift = Math.max(0, REST - g.tipY);
        var binding = g.order[g.bind];
        var touching = -1;
        for (var i = 0; i < g.pins.length; i++) {
            var p = g.pins[i];
            if (p.set) continue;
            var under = Math.abs(g.pickX - p.x) < 13;
            if (under) touching = i;
            var want = under ? tipLift : 0;
            if (i === binding) {
                // the binding pin is stiff: it follows slowly and trembles
                p.lift += (want - p.lift) * Math.min(1, dt * 5);
                p.jit = under && want > 4 ? (Math.random() - 0.5) * 1.6 : 0;
                var d = p.lift - p.need;
                if (Math.abs(d) <= g.tol) {
                    p.hold += dt * 1000;
                    if (p.hold >= g.holdMs) {
                        p.set = true; p.lift = p.need; p.jit = 0;
                        g.bind++;
                        SND.set(); flash();
                        setPips(g.pins.length, g.bind);
                        if (g.bind >= g.pins.length) return finish(true);
                    }
                } else {
                    p.hold = Math.max(0, p.hold - dt * 2000);
                }
                // forced far past the shear line: the pick bends
                if (d > g.tol + 6 && under) g.strain += dt * (0.3 + (d - g.tol) / 90);
            } else {
                // loose pins spring up and down freely
                var before = p.lift;
                p.lift += (want - p.lift) * Math.min(1, dt * 22);
                if (under && Math.abs(p.lift - before) > 2.5 && Math.random() < 0.25) SND.spring();
                p.jit = 0;
            }
        }
        g.strain = Math.max(0, g.strain - dt * 0.25);
        if (g.strain >= 1) { SND.snap(); shake(); return finish(false, t('lock_snapped')); }
        g.touching = touching;
    }

    // ---- materials: the lock and the safe are drawn as real metal, finished to match the UI preset
    //   classic   the base game: blackened steel, black door, white figures
    //   parchment old-west catalogue: polished brass, green painted safe, gold pin-striping, ivory figures
    //   modern    brushed nickel and chrome, graphite door, crisp white figures
    var LOOKS = {
        classic: {
            mat: {
                brass:  ['#2e2618', '#5f5131', '#b6a578', '#7a6a43', '#2f2717'],
                steel:  ['#1b1c1e', '#3d4043', '#9ba0a5', '#55595d', '#1e1f21'],
                chrome: ['#2a2c2f', '#7d8288', '#e9ecef', '#6e7378', '#25272a'],
            },
            door: ['#202020', '#111111', '#060606'], stripe: 'rgba(255,255,255,0.42)', stripe2: 'rgba(255,255,255,0.16)',
            enamel: ['#303030', '#101010', '#000000'], fig: '#ffffff', figMid: '#d8d8d8', figDim: '#7a7a7a',
            index: 'chrome', keyway: ['#000000', '#0b0b0b', '#1c1c1c'], plugEdge: 'rgba(0,0,0,0.8)', glint: 'rgba(255,255,255,0.9)',
            handle: ['#1d1d1d', '#3a3a3a', '#0c0c0c'],
        },
        parchment: {
            mat: {
                brass:  ['#5e4413', '#a57c2c', '#f1d58a', '#c79a3f', '#6b4c15'],
                steel:  ['#3a3d42', '#7d838b', '#e2e6ea', '#9aa1a8', '#45484d'],
                chrome: ['#5a5f66', '#c9ced4', '#ffffff', '#a8aeb5', '#4d5157'],
            },
            door: ['#2d3a31', '#1d2721', '#121914'], stripe: 'rgba(214,178,94,0.55)', stripe2: 'rgba(214,178,94,0.3)',
            enamel: ['#3a3a3a', '#151515', '#050505'], fig: '#efe6cf', figMid: '#d9d0b8', figDim: '#8f8a7c',
            index: 'brass', keyway: ['#050505', '#15120c', '#2b2215'], plugEdge: 'rgba(40,25,0,0.7)', glint: 'rgba(255,240,190,0.9)',
            handle: ['#6b4424', '#a0693a', '#3d2512'],
        },
        modern: {
            mat: {
                brass:  ['#5d5a52', '#a9a597', '#efece3', '#bdb8aa', '#5f5b51'],   // nickel-plated pins and plug
                steel:  ['#3f454c', '#8c959f', '#eef2f6', '#a7b0b9', '#4a5058'],
                chrome: ['#4f565e', '#c5ccd3', '#ffffff', '#aeb6be', '#475057'],
            },
            door: ['#3b4148', '#2a2f35', '#1a1e22'], stripe: 'rgba(200,214,230,0.45)', stripe2: 'rgba(200,214,230,0.18)',
            enamel: ['#3d434b', '#1c2025', '#0d0f12'], fig: '#f2f6fa', figMid: '#cfd6de', figDim: '#76808a',
            index: 'red', keyway: ['#07080a', '#14171b', '#262b31'], plugEdge: 'rgba(0,0,0,0.6)', glint: 'rgba(255,255,255,0.95)',
            handle: ['#2b3036', '#59616a', '#171a1e'],
        },
    };
    LOOKS.classic.mat.red = LOOKS.parchment.mat.red = LOOKS.modern.mat.red = ['#5a0f0a', '#9a1c14', '#e0574a', '#b4261c', '#5a0f0a'];
    function look() {
        var p = document.documentElement.getAttribute('data-mc-preset') || '';
        if (!LOOKS[p]) {
            var cl = document.documentElement.classList;
            p = cl.contains('mc-preset-parchment') ? 'parchment' : cl.contains('mc-preset-modern') ? 'modern' : 'classic';
        }
        return LOOKS[p];
    }
    function grad3(x0, y0, x1, y1, c) {
        var gr = ctx.createLinearGradient(x0, y0, x1, y1);
        gr.addColorStop(0, c[0]); gr.addColorStop(0.5, c[1]); gr.addColorStop(1, c[2]);
        return gr;
    }
    function metal(x0, y0, x1, y1, m) {
        var gr = ctx.createLinearGradient(x0, y0, x1, y1), s = look().mat[m];
        gr.addColorStop(0, s[0]); gr.addColorStop(0.22, s[1]); gr.addColorStop(0.45, s[2]);
        gr.addColorStop(0.7, s[3]); gr.addColorStop(1, s[4]);
        return gr;
    }
    function roundRect(x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r);
        ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
        ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r);
        ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
    }
    // diagonal hatching: how a drawing shows metal that was cut through
    function hatch(x, y, w, h, color) {
        ctx.save(); ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip();
        ctx.strokeStyle = color; ctx.lineWidth = 1;
        for (var d = -h; d < w; d += 9) { ctx.beginPath(); ctx.moveTo(x + d, y + h); ctx.lineTo(x + d + h, y); ctx.stroke(); }
        ctx.restore();
    }
    function shadowOn(blur, oy) { ctx.shadowColor = 'rgba(0,0,0,0.55)'; ctx.shadowBlur = blur; ctx.shadowOffsetY = oy || 0; }
    function shadowOff() { ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0; }

    var KEYWAY_TOP = REST + 2, KEYWAY_BOT = REST + 24;

    function lockDraw(g) {
        ctx.clearRect(0, 0, W, H);
        var LK = look();
        var hx = 92, hw = W - 184;                     // the housing (bible) above the plug
        // housing: cut-away steel
        shadowOn(18, 6);
        roundRect(hx, CH_TOP - 14, hw, PLUG_TOP - CH_TOP + 14, 10);
        ctx.fillStyle = metal(0, CH_TOP - 14, 0, PLUG_TOP, 'steel'); ctx.fill();
        shadowOff();
        hatch(hx, CH_TOP - 14, hw, PLUG_TOP - CH_TOP + 14, 'rgba(0,0,0,0.18)');
        ctx.strokeStyle = 'rgba(0,0,0,0.6)'; ctx.lineWidth = 1.5; roundRect(hx, CH_TOP - 14, hw, PLUG_TOP - CH_TOP + 14, 10); ctx.stroke();
        // shell around the plug
        shadowOn(18, 6);
        roundRect(20, PLUG_TOP - 6, W - 40, PLUG_BOT - PLUG_TOP + 18, 16);
        ctx.fillStyle = metal(0, PLUG_TOP - 6, 0, PLUG_BOT + 12, 'steel'); ctx.fill();
        shadowOff();
        hatch(20, PLUG_TOP - 6, W - 40, PLUG_BOT - PLUG_TOP + 18, 'rgba(0,0,0,0.16)');
        // the brass plug, turned as a cylinder
        roundRect(32, PLUG_TOP, W - 64, PLUG_BOT - PLUG_TOP, 10);
        ctx.fillStyle = metal(0, PLUG_TOP, 0, PLUG_BOT, 'brass'); ctx.fill();
        ctx.strokeStyle = LK.plugEdge; ctx.lineWidth = 1.5; ctx.stroke();
        // front face of the plug (where the key goes in)
        ctx.fillStyle = metal(32, 0, 52, 0, 'brass'); ctx.fillRect(32, PLUG_TOP + 4, 14, PLUG_BOT - PLUG_TOP - 8);
        // the keyway: a dark slot along the bottom of the plug
        var kg = ctx.createLinearGradient(0, KEYWAY_TOP, 0, KEYWAY_BOT);
        kg.addColorStop(0, LK.keyway[0]); kg.addColorStop(0.6, LK.keyway[1]); kg.addColorStop(1, LK.keyway[2]);
        ctx.fillStyle = kg; roundRect(32, KEYWAY_TOP, W - 80, KEYWAY_BOT - KEYWAY_TOP, 5); ctx.fill();
        // shear line: the hair gap between plug and housing
        ctx.strokeStyle = 'rgba(0,0,0,0.85)'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(32, PLUG_TOP); ctx.lineTo(W - 32, PLUG_TOP); ctx.stroke();

        for (var i = 0; i < g.pins.length; i++) {
            var p = g.pins[i], x = p.x + p.jit;
            // the drilled chamber through housing and plug
            var cg = ctx.createLinearGradient(p.x - 13, 0, p.x + 13, 0);
            cg.addColorStop(0, '#0b0b0c'); cg.addColorStop(0.5, '#26282b'); cg.addColorStop(1, '#0b0b0c');
            ctx.fillStyle = cg; ctx.fillRect(p.x - 13, CH_TOP, 26, KEYWAY_TOP - CH_TOP);
            var keyTop = REST - p.key - p.lift;
            var drvBot = p.set ? PLUG_TOP - 1 : keyTop - 1;
            var drvTop = drvBot - 44;
            // spring: a steel coil seen from the side
            var coils = 8, top = CH_TOP + 2, len = Math.max(8, drvTop - top);
            ctx.lineWidth = 2.2;
            for (var c = 0; c < coils; c++) {
                var y0 = top + len * c / coils, y1 = top + len * (c + 0.5) / coils, y2 = top + len * (c + 1) / coils;
                ctx.strokeStyle = '#6e737a';
                ctx.beginPath(); ctx.moveTo(x - 8, y0); ctx.lineTo(x + 8, y1); ctx.stroke();
                ctx.strokeStyle = '#d5d9de';
                ctx.beginPath(); ctx.moveTo(x + 8, y1); ctx.lineTo(x - 8, y2); ctx.stroke();
            }
            // driver pin: plain steel cylinder
            roundRect(x - 10, drvTop, 20, drvBot - drvTop, 3);
            ctx.fillStyle = metal(x - 10, 0, x + 10, 0, 'steel'); ctx.fill();
            ctx.strokeStyle = 'rgba(0,0,0,0.55)'; ctx.lineWidth = 1; ctx.stroke();
            // key pin: brass with a rounded point
            var kb = REST - p.lift;
            ctx.beginPath();
            ctx.moveTo(x - 10, keyTop + 2); ctx.quadraticCurveTo(x - 10, keyTop, x - 8, keyTop);
            ctx.lineTo(x + 8, keyTop); ctx.quadraticCurveTo(x + 10, keyTop, x + 10, keyTop + 2);
            ctx.lineTo(x + 10, kb - 9); ctx.quadraticCurveTo(x + 6, kb - 1, x, kb); ctx.quadraticCurveTo(x - 6, kb - 1, x - 10, kb - 9);
            ctx.closePath();
            ctx.fillStyle = metal(x - 10, 0, x + 10, 0, 'brass'); ctx.fill();
            ctx.strokeStyle = LK.plugEdge; ctx.lineWidth = 1; ctx.stroke();
            // a set pin sits with its top exactly on the shear line: a thin glint marks it
            if (p.set) {
                ctx.strokeStyle = LK.glint; ctx.lineWidth = 1.5;
                ctx.beginPath(); ctx.moveTo(x - 10, PLUG_TOP + 1); ctx.lineTo(x + 10, PLUG_TOP + 1); ctx.stroke();
            }
        }

        // tension wrench: an L of spring steel in the bottom of the keyway, turned against the plug
        ctx.lineCap = 'round';
        ctx.strokeStyle = '#1a1b1d'; ctx.lineWidth = 7;
        ctx.beginPath(); ctx.moveTo(0, H - 34); ctx.lineTo(26, H - 34); ctx.lineTo(26, KEYWAY_BOT - 4); ctx.lineTo(60, KEYWAY_BOT - 4); ctx.stroke();
        ctx.strokeStyle = metal(0, H - 40, 0, H - 28, 'steel'); ctx.lineWidth = 4;
        ctx.beginPath(); ctx.moveTo(0, H - 34); ctx.lineTo(26, H - 34); ctx.lineTo(26, KEYWAY_BOT - 4); ctx.lineTo(60, KEYWAY_BOT - 4); ctx.stroke();

        // the pick: a wooden handle outside the lock, a steel shaft along the keyway, a hook up to the pins
        var bend = g.strain * 14;
        var shaftY = KEYWAY_BOT - 8 + bend * 0.35;
        var path = function () {
            ctx.beginPath();
            ctx.moveTo(0, shaftY + bend);
            ctx.lineTo(g.pickX - 22, shaftY + bend * 0.4);
            ctx.quadraticCurveTo(g.pickX - 6, shaftY, g.pickX - 2, g.tipY + 6);
            ctx.quadraticCurveTo(g.pickX, g.tipY + 1, g.pickX + 4, g.tipY + 2);
        };
        ctx.strokeStyle = '#0d0d0e'; ctx.lineWidth = 6.5; path(); ctx.stroke();
        ctx.strokeStyle = '#9ba2aa'; ctx.lineWidth = 4; path(); ctx.stroke();
        ctx.strokeStyle = 'rgba(255,255,255,0.75)'; ctx.lineWidth = 1.2;
        ctx.save(); ctx.translate(0, -1); path(); ctx.stroke(); ctx.restore();
        ctx.lineCap = 'butt';
        // handle (only its end shows at the left edge)
        var hg = ctx.createLinearGradient(0, shaftY - 9, 0, shaftY + 9);
        hg.addColorStop(0, LK.handle[0]); hg.addColorStop(0.45, LK.handle[1]); hg.addColorStop(1, LK.handle[2]);
        ctx.fillStyle = hg; roundRect(-20, shaftY + bend - 9, 34, 18, 5); ctx.fill();
    }

    // ------------------------------------------------------------------ the safe dial
    function newSafe(o) {
        var n = Math.max(2, Math.min(5, o.numbers || 3));
        var g = { kind: 'safe', combo: [], step: 0, tol: o.tolerance === undefined ? 1 : o.tolerance, angle: 0, num: 0,
                  dir: 0, moved: 0, contact: false, wobble: 0, spin: 0 };
        var last = -99;
        for (var i = 0; i < n; i++) {
            var v;
            do { v = Math.floor(Math.random() * 100); } while (Math.abs(v - last) < 15 || v === 0);
            g.combo.push(v); last = v;
        }
        g.angle = Math.floor(Math.random() * 100) * 3.6;
        g.num = numAt(g.angle);
        return g;
    }
    function numAt(a) { return ((Math.round(a / 3.6) % 100) + 100) % 100; }
    function needDir(g) { return g.step % 2 === 0 ? 1 : -1; }    // 1 = left (numbers go up), -1 = right
    function near(a, b, tol) { var d = Math.abs(a - b); d = Math.min(d, 100 - d); return d <= tol; }

    function safeTurn(g, deg) {
        if (!deg) return;
        g.angle += deg;
        var n = numAt(g.angle);
        if (n === g.num) return;
        // walk every number passed, so a fast spin still ticks and clicks on the way
        var stepDir = deg > 0 ? 1 : -1;
        var guard = 0;
        while (g.num !== n && guard++ < 100 && game === g) {
            g.num = (g.num + stepDir + 100) % 100;
            safeNumber(g, stepDir);
        }
    }

    function safeNumber(g, dir) {
        if (dir !== g.dir) {
            // turned back: on the right number in the right direction the wheel sets
            if (g.dir !== 0 && g.moved >= 1) {
                if (g.contact) {
                    g.step++;
                    SND.set(); flash();
                    setPips(g.combo.length, g.step);
                    if (g.step >= g.combo.length) { SND.open(); return finish(true); }
                } else if (g.step > 0) {
                    g.step = 0;
                    SND.fall(); shake();
                    setPips(g.combo.length, 0);
                    setState(t('safe_reset'), 'bad');
                    setTimeout(function () { if (game === g) safeHint(g); }, 1200);
                }
            }
            g.dir = dir; g.moved = 0; g.contact = false;
        }
        g.moved++;
        var target = g.combo[g.step];
        var right = dir === needDir(g) && near(g.num, target, g.tol);
        if (right && !g.contact) { SND.heavy(); g.wobble = 1; }
        else SND.tick();
        g.contact = right;
        if (g.step < g.combo.length && g.moved === 1 && g.dir === needDir(g)) safeHint(g);
    }

    function safeHint(g) {
        setState(needDir(g) === 1 ? t('safe_left') : t('safe_right'), '');
    }

    function safeStep(g, dt) {
        // keys: A / left = turn left, D / right = turn right, Shift = slow
        var k = 0;
        if (keys.a || keys.arrowleft) k += 1;
        if (keys.d || keys.arrowright) k -= 1;
        if (k) {
            g.spin += dt * (keys.shift ? 8 : 26);
            while (g.spin >= 1) { g.spin -= 1; safeTurn(g, 3.6 * k); if (!game) return; }
        } else g.spin = 0;
        g.wobble = Math.max(0, g.wobble - dt * 6);
    }

    function safeDraw(g) {
        ctx.clearRect(0, 0, W, H);
        var LK = look();
        var cx = W / 2, cy = H / 2 + 4, R = 132;
        var wob = g.wobble ? (Math.random() - 0.5) * 2.4 * g.wobble : 0;
        // the safe door: painted steel with a faint sheen, rivets round the edge
        var dg = ctx.createLinearGradient(0, 0, W, H);
        dg.addColorStop(0, LK.door[0]); dg.addColorStop(0.45, LK.door[1]); dg.addColorStop(1, LK.door[2]);
        shadowOn(20, 6);
        roundRect(8, 4, W - 16, H - 8, 14); ctx.fillStyle = dg; ctx.fill();
        shadowOff();
        ctx.strokeStyle = 'rgba(0,0,0,0.7)'; ctx.lineWidth = 2; ctx.stroke();
        // gold pin-striping, as old safes had
        ctx.strokeStyle = LK.stripe; ctx.lineWidth = 1.5; roundRect(22, 18, W - 44, H - 36, 10); ctx.stroke();
        ctx.strokeStyle = LK.stripe2; ctx.lineWidth = 1; roundRect(28, 24, W - 56, H - 48, 8); ctx.stroke();
        var rivets = [[40, 40], [W - 40, 40], [40, H - 40], [W - 40, H - 40], [W / 2, 34], [W / 2, H - 34]];
        for (var r = 0; r < rivets.length; r++) {
            var rx = rivets[r][0], ry = rivets[r][1];
            var rg = ctx.createRadialGradient(rx - 2, ry - 2, 1, rx, ry, 6);
            rg.addColorStop(0, '#c8ccd0'); rg.addColorStop(0.5, '#5d6268'); rg.addColorStop(1, '#202224');
            ctx.fillStyle = rg; ctx.beginPath(); ctx.arc(rx, ry, 6, 0, Math.PI * 2); ctx.fill();
        }
        // chrome bezel ring
        shadowOn(16, 4);
        ctx.beginPath(); ctx.arc(cx, cy, R + 18, 0, Math.PI * 2);
        ctx.fillStyle = metal(cx - R, cy - R, cx + R, cy + R, 'chrome'); ctx.fill();
        shadowOff();
        ctx.beginPath(); ctx.arc(cx, cy, R + 4, 0, Math.PI * 2); ctx.fillStyle = '#0a0a0a'; ctx.fill();
        // brass index mark on the bezel
        ctx.beginPath(); ctx.moveTo(cx - 8, cy - R - 17); ctx.lineTo(cx + 8, cy - R - 17); ctx.lineTo(cx, cy - R - 3); ctx.closePath();
        ctx.fillStyle = metal(cx - 8, 0, cx + 8, 0, LK.index); ctx.fill();
        ctx.strokeStyle = LK.plugEdge; ctx.lineWidth = 1; ctx.stroke();

        // the dial itself: black enamel, turning
        ctx.save();
        ctx.translate(cx + wob, cy);
        ctx.rotate(-g.angle * Math.PI / 180);
        var eg = ctx.createRadialGradient(-R * 0.35, -R * 0.45, 10, 0, 0, R);
        eg.addColorStop(0, LK.enamel[0]); eg.addColorStop(0.35, LK.enamel[1]); eg.addColorStop(1, LK.enamel[2]);
        ctx.beginPath(); ctx.arc(0, 0, R, 0, Math.PI * 2); ctx.fillStyle = eg; ctx.fill();
        // graduations and numbers in worn ivory paint
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.font = '700 15px Georgia, "Times New Roman", serif';
        for (var i = 0; i < 100; i++) {
            var a = i * 3.6 * Math.PI / 180, long = i % 5 === 0, ten = i % 10 === 0;
            ctx.strokeStyle = ten ? LK.fig : (long ? LK.figMid : LK.figDim);
            ctx.lineWidth = ten ? 2.2 : (long ? 1.6 : 1);
            var r0 = R - 5, r1 = R - (ten ? 20 : long ? 15 : 10);
            ctx.beginPath(); ctx.moveTo(Math.sin(a) * r0, -Math.cos(a) * r0); ctx.lineTo(Math.sin(a) * r1, -Math.cos(a) * r1); ctx.stroke();
            if (ten) {
                ctx.save(); ctx.translate(Math.sin(a) * (R - 34), -Math.cos(a) * (R - 34)); ctx.rotate(a);
                ctx.fillStyle = LK.fig; ctx.fillText(String(i), 0, 0); ctx.restore();
            }
        }
        // a fine chrome ring inside the numbers
        ctx.beginPath(); ctx.arc(0, 0, R - 48, 0, Math.PI * 2);
        ctx.strokeStyle = metal(-R, -R, R, R, 'chrome'); ctx.lineWidth = 3; ctx.stroke();
        // the knob: knurled steel with a polished cap
        var KR = 44;
        ctx.save(); shadowOn(10, 3);
        ctx.beginPath(); ctx.arc(0, 0, KR, 0, Math.PI * 2); ctx.fillStyle = metal(-KR, -KR, KR, KR, 'steel'); ctx.fill();
        ctx.restore();
        for (var k = 0; k < 60; k++) {
            var b = k * Math.PI / 30;
            ctx.strokeStyle = k % 2 ? 'rgba(0,0,0,0.45)' : 'rgba(255,255,255,0.35)'; ctx.lineWidth = 1.4;
            ctx.beginPath(); ctx.moveTo(Math.sin(b) * (KR - 9), -Math.cos(b) * (KR - 9)); ctx.lineTo(Math.sin(b) * KR, -Math.cos(b) * KR); ctx.stroke();
        }
        ctx.beginPath(); ctx.arc(0, 0, KR - 10, 0, Math.PI * 2);
        ctx.fillStyle = metal(-KR, -KR, KR, KR, 'chrome'); ctx.fill();
        ctx.strokeStyle = 'rgba(0,0,0,0.5)'; ctx.lineWidth = 1; ctx.stroke();
        // the grip bar across the knob
        roundRect(-KR + 14, -6, (KR - 14) * 2, 12, 5);
        ctx.fillStyle = metal(0, -6, 0, 6, 'steel'); ctx.fill(); ctx.strokeStyle = 'rgba(0,0,0,0.5)'; ctx.stroke();
        ctx.restore();
        // glare on the enamel (does not turn with the dial)
        var gl = ctx.createLinearGradient(cx - R, cy - R, cx, cy);
        gl.addColorStop(0, 'rgba(255,255,255,0.10)'); gl.addColorStop(1, 'rgba(255,255,255,0)');
        ctx.beginPath(); ctx.arc(cx, cy, R, Math.PI * 1.05, Math.PI * 1.75); ctx.arc(cx, cy, R - 46, Math.PI * 1.75, Math.PI * 1.05, true); ctx.closePath();
        ctx.fillStyle = gl; ctx.fill();
    }

    // ------------------------------------------------------------------ running a game
    var last = 0, endAt = 0, total = 0, raf = null;

    function loop(now) {
        if (!game) return;
        var dt = Math.min(0.05, (now - last) / 1000); last = now;
        var left = endAt - Date.now();
        var bar = $('mg-time');
        bar.style.width = Math.max(0, left / total * 100) + '%';
        bar.classList.toggle('low', left < total * 0.25);
        if (left <= 0) { finish(false, t('timeout')); return; }
        if (game.kind === 'lock') { lockStep(game, dt); if (game) lockDraw(game); }
        else { safeStep(game, dt); if (game) safeDraw(game); }
        raf = requestAnimationFrame(loop);
    }

    function open(d) {
        T = d.text || {};
        readColors();
        var o = d.opts || {};
        game = d.game === 'safe' ? newSafe(o) : newLock(o);
        $('mg-title').textContent = d.game === 'safe' ? t('safe_title') : t('lock_title');
        $('mg-sub').textContent = d.label || '';
        $('mg-help').textContent = d.game === 'safe' ? t('safe_help') : t('lock_help');
        setPips(game.kind === 'safe' ? game.combo.length : game.pins.length, 0);
        if (game.kind === 'safe') safeHint(game); else setState(t('lock_state'), '');
        total = Math.max(5, o.seconds || 45) * 1000;
        endAt = Date.now() + total;
        ui.classList.remove('mc-hidden');
        audio();
        last = performance.now();
        cancelAnimationFrame(raf);
        raf = requestAnimationFrame(loop);
    }

    function finish(ok, why) {
        if (!game) return;
        var g = game; game = null;
        cancelAnimationFrame(raf);
        if (ok) { setState(g.kind === 'safe' ? t('safe_open') : t('lock_open'), 'good'); if (g.kind === 'lock') SND.open(); }
        else setState(why || t('gave_up'), 'bad');
        setTimeout(function () {
            ui.classList.add('mc-hidden');
            post('done', { ok: ok === true });
        }, ok ? 700 : 900);
    }

    // ------------------------------------------------------------------ input
    var stage = cv.parentNode;
    stage.addEventListener('mousemove', function (e) {
        var r = cv.getBoundingClientRect();
        var nx = (e.clientX - r.left) * (W / r.width), ny = (e.clientY - r.top) * (H / r.height);
        if (game && game.kind === 'safe' && mouse.down) {
            // dragging the dial: moving the mouse left turns it left
            safeTurn(game, (mouse.x - nx) * 0.9);
        }
        mouse.x = nx; mouse.y = ny;
    });
    stage.addEventListener('mousedown', function (e) {
        var r = cv.getBoundingClientRect();
        mouse.x = (e.clientX - r.left) * (W / r.width); mouse.y = (e.clientY - r.top) * (H / r.height);
        mouse.down = true; audio();
    });
    window.addEventListener('mouseup', function () { mouse.down = false; });
    stage.addEventListener('wheel', function (e) {
        if (game && game.kind === 'safe') { safeTurn(game, e.deltaY < 0 ? 3.6 : -3.6); e.preventDefault(); }
    }, { passive: false });
    window.addEventListener('keydown', function (e) {
        var k = (e.key || '').toLowerCase();
        if (k === 'escape' || k === 'backspace') { if (game) finish(false, t('gave_up')); return; }
        keys[k] = true;
        if (e.shiftKey) keys.shift = true;
    });
    window.addEventListener('keyup', function (e) {
        var k = (e.key || '').toLowerCase();
        keys[k] = false;
        if (!e.shiftKey) keys.shift = false;
    });

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.action === 'open') open(d);
        else if (d.action === 'close' && game) finish(false);
    });

    window.MGTest = { open: open, game: function () { return game; }, colors: colors, mouse: mouse,
        tick: function (dt) { if (game && game.kind === 'lock') lockStep(game, dt); } };
})();
