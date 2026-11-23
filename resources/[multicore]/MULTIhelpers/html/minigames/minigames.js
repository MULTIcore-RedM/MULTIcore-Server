/* MULTIhelpers NUI: bcc-minigames stand-in. Six small skill checks in the MULTI look,
   started by client/bcc_minigames.lua. Own code, GPL v3. */
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
    function mk(tag, cls, parent) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (parent) parent.appendChild(e);
        return e;
    }
    function num(v, d) { v = Number(v); return isFinite(v) ? v : d; }
    function rnd(a, b) { return a + Math.random() * (b - a); }
    function rndInt(a, b) { return Math.floor(rnd(a, b + 1)); }

    // language lines (locales/*.lua through MULTIhelpers' ready call); English when missing
    var TEXT = {};
    var EN = { mg_rock: 'Rock', mg_paper: 'Paper', mg_scissors: 'Scissors', mg_win: 'You win', mg_lose: 'You lose', mg_tie: 'Tie' };
    function T(k) { return TEXT[k] !== undefined ? TEXT[k] : (EN[k] || k); }
    window.addEventListener('load', function () {
        fetch('https://' + RES + '/ready', { method: 'POST', body: '{}' })
            .then(function (r) { return r.json(); })
            .then(function (s) { if (s && s.text) TEXT = s.text; })
            .catch(function () {});
    });

    // ------------------------------------------------------------ shell
    var G = null;          // running game: { token, game, cfg, end(), key(ev), ... }
    var wrap = null, panel = null, stage = null, foot = null;
    var raf = 0, timers = [];

    function later(fn, ms) { var t = setTimeout(fn, ms); timers.push(t); return t; }
    function clearAll() {
        cancelAnimationFrame(raf); raf = 0;
        timers.forEach(clearTimeout); timers = [];
    }

    function shell(kind) {
        if (!wrap) {
            wrap = mk('div', 'mg-wrap mc-hidden', document.body);
            panel = mk('div', 'mc-root mc-panel mg-panel', wrap);
            stage = mk('div', 'mg-stage', panel);
            foot = mk('div', 'mg-foot mc-prompts', panel);
        }
        wrap.className = 'mg-wrap mg-' + kind;
        panel.className = 'mc-root mc-panel mg-panel mg-panel-' + kind;
        stage.innerHTML = '';
        foot.innerHTML = '';
    }

    function keyCap(parent, label, extra) {
        var s = mk('span', 'mg-prompt', parent);
        var k = mk('span', 'mc-key', s);
        k.textContent = label;
        if (extra) { var t = mk('span', '', s); t.textContent = extra; }
        return s;
    }

    function pips(parent, total) {
        var box = mk('div', 'mg-pips', parent);
        var list = [];
        for (var i = 0; i < total; i++) list.push(mk('span', 'mg-pip on', box));
        return {
            set: function (left) { list.forEach(function (p, i) { p.classList.toggle('on', i < left); }); },
            box: box
        };
    }

    function flash(cls) {
        panel.classList.remove('mg-good', 'mg-bad');
        void panel.offsetWidth;
        panel.classList.add(cls);
    }

    function finish(result) {
        if (!G) return;
        var token = G.token;
        clearAll();
        G = null;
        if (wrap) wrap.classList.add('mc-hidden');
        post('mgResult', { token: token, result: result });
    }

    function stopGame() {
        clearAll();
        G = null;
        if (wrap) wrap.classList.add('mc-hidden');
    }

    function loop(fn) {
        var last = performance.now();
        function tick(now) {
            if (!G) return;
            var dt = Math.min(100, now - last); last = now;
            fn(dt, now);
            raf = requestAnimationFrame(tick);
        }
        raf = requestAnimationFrame(tick);
    }

    // ================================================================ skillcheck
    var RANDOM_KEYS = 'QERFGZXCVB';
    function skillcheck(cfg) {
        var circle = String(cfg.type || 'bar').toLowerCase() === 'trailing';
        shell('skillcheck');
        var key = String(cfg.keytopress || 'E').toUpperCase();
        var code = cfg.keycode !== undefined ? num(cfg.keycode, 0) : 0;
        if (cfg.userandomkey) { key = RANDOM_KEYS.charAt(rndInt(0, RANDOM_KEYS.length - 1)); code = 0; }
        var attempts = Math.max(1, Math.floor(num(cfg.maxattempts, 3)));
        var speed = Math.max(0.2, Math.min(10, num(cfg.speed, 1)));
        var period = 2000 / speed;             // ms for one full sweep
        var zoneSize = cfg.strict ? 0.09 : 0.13;
        var pos = 0, dir = 1, zone = 0;
        var cap = mk('div', 'mg-bigkey', stage); mk('span', 'mc-key', cap).textContent = key;

        var track, needle, zoneEl, ring, marker;
        if (circle) {
            ring = mk('div', 'mg-ring', stage);
            zoneEl = mk('div', 'mg-ring-zone', ring);
            mk('div', 'mg-ring-hole', ring);
            marker = mk('div', 'mg-ring-marker', ring);
        } else {
            track = mk('div', 'mg-track', stage);
            zoneEl = mk('div', 'mg-zone', track);
            needle = mk('div', 'mg-needle', track);
        }
        var life = pips(foot, attempts);

        function newZone() {
            zone = rnd(0.25, 0.9 - zoneSize);
            if (circle) {
                zoneEl.style.background = 'conic-gradient(from ' + (zone * 360) + 'deg, var(--mg-zone) 0deg ' + (zoneSize * 360) + 'deg, transparent ' + (zoneSize * 360) + 'deg)';
            } else {
                zoneEl.style.left = (zone * 100) + '%';
                zoneEl.style.width = (zoneSize * 100) + '%';
            }
        }
        newZone();
        wrap.classList.remove('mc-hidden');

        loop(function (dt) {
            if (circle) {
                pos = (pos + dt / period) % 1;
                marker.style.transform = 'rotate(' + (pos * 360) + 'deg)';
            } else {
                pos += dir * dt / period;
                if (pos >= 1) { pos = 1; dir = -1; }
                if (pos <= 0) { pos = 0; dir = 1; }
                needle.style.left = (pos * 100) + '%';
            }
        });

        G.key = function (ev) {
            if (ev.repeat) return;
            var k = String(ev.key || '').toUpperCase();
            var right = k === key || (code && (ev.keyCode === code || ev.which === code));
            if (!right) {
                if (cfg.strict && /^[A-Z0-9 ]$/.test(k)) miss();
                return;
            }
            if (pos >= zone && pos <= zone + zoneSize) {
                flash('mg-good');
                finish({ passed: true });
            } else {
                miss();
            }
        };
        function miss() {
            attempts--;
            life.set(attempts);
            flash('mg-bad');
            if (attempts <= 0) { later(function () { finish({ passed: false }); }, 250); return; }
            newZone();
        }
        G.cancel = function () { finish({ passed: false }); };
    }

    // ================================================================ lockpick
    function lockpick(cfg) {
        shell('lockpick');
        var stages = Array.isArray(cfg.stages) && cfg.stages.length ? cfg.stages : [{ deg: rndInt(0, 359) }];
        var threshold = Math.max(1, num(cfg.threshold, 10));
        var hintDelay = Math.max(0, num(cfg.hintdelay, 500));
        var attempts = Math.max(1, Math.floor(num(cfg.maxattempts, 3)));
        var at = 0, angle = 0, nearSince = 0;

        var lock = mk('div', 'mg-lock', stage);
        var glow = mk('div', 'mg-lock-glow', lock);
        mk('div', 'mg-lock-core', lock);
        var pick = mk('div', 'mg-pick', lock);
        var steps = mk('div', 'mg-pips mg-steps', stage);
        var stepEls = stages.map(function () { return mk('span', 'mg-pip', steps); });
        var life = pips(foot, attempts);
        keyCap(foot, 'A / D');
        keyCap(foot, 'E');
        wrap.classList.remove('mc-hidden');

        function target() { return ((num(stages[at].deg, 0) % 360) + 360) % 360; }
        function diff() { var d = Math.abs(angle - target()) % 360; return d > 180 ? 360 - d : d; }
        function draw() { pick.style.transform = 'rotate(' + angle + 'deg)'; }
        function setAngle(a) { angle = ((a % 360) + 360) % 360; draw(); }

        var spin = 0;
        loop(function (dt, now) {
            if (spin) setAngle(angle + spin * dt * 0.12);
            // hint: the lock glows as the pick nears the pin, once it has been close for hintdelay
            var d = diff();
            if (d <= threshold * 3) { if (!nearSince) nearSince = now; } else nearSince = 0;
            var show = nearSince && now - nearSince >= hintDelay;
            glow.style.opacity = show ? String(Math.max(0, 1 - d / (threshold * 3))) : '0';
        });

        lock.addEventListener('mousemove', function (ev) {
            var r = lock.getBoundingClientRect();
            var x = ev.clientX - (r.left + r.width / 2), y = ev.clientY - (r.top + r.height / 2);
            setAngle(Math.atan2(x, -y) * 180 / Math.PI);
        });
        lock.addEventListener('click', tryPin);

        function tryPin() {
            if (!G) return;
            if (diff() <= threshold) {
                stepEls[at].classList.add('on');
                flash('mg-good');
                at++;
                nearSince = 0;
                if (at >= stages.length) { later(function () { finish({ unlocked: true }); }, 300); }
                return;
            }
            attempts--;
            life.set(attempts);
            flash('mg-bad');
            if (attempts <= 0) later(function () { finish({ unlocked: false }); }, 300);
        }

        G.key = function (ev) {
            var k = ev.key;
            if (k === 'a' || k === 'A' || k === 'ArrowLeft') { spin = -1; return; }
            if (k === 'd' || k === 'D' || k === 'ArrowRight') { spin = 1; return; }
            if (!ev.repeat && (k === 'e' || k === 'E' || k === ' ' || k === 'Enter')) tryPin();
        };
        G.keyup = function (ev) {
            var k = ev.key;
            if (k === 'a' || k === 'A' || k === 'ArrowLeft' || k === 'd' || k === 'D' || k === 'ArrowRight') spin = 0;
        };
        G.cancel = function () { finish({ unlocked: false }); };
        draw();
    }

    // ================================================================ rock paper scissors
    var RPS = ['rock', 'paper', 'scissors'];
    // ︎ asks for the plain (one-colour) form of the hand signs
    var RPS_ICON = { rock: '✊︎', paper: '✋︎', scissors: '✌︎' };
    function rps(cfg) {
        shell('rps');
        var board = mk('div', 'mg-rps-board', stage);
        var you = mk('div', 'mg-rps-hand', board);
        mk('div', 'mg-rps-vs', board).textContent = '—';
        var them = mk('div', 'mg-rps-hand', board);
        var verdict = mk('div', 'mc-subtitle mg-rps-verdict', stage);
        var row = mk('div', 'mc-btn-row mg-rps-row', stage);
        var locked = false;

        function reset() {
            locked = false;
            you.textContent = '?'; them.textContent = '?';
            verdict.textContent = '';
            row.classList.remove('mg-off');
        }
        RPS.forEach(function (c, i) {
            var b = mk('button', 'mc-btn mg-rps-btn', row);
            b.type = 'button';
            mk('span', 'mg-rps-icon', b).textContent = RPS_ICON[c];
            mk('span', '', b).textContent = T('mg_' + c);
            b.addEventListener('click', function () { pick(i); });
        });
        keyCap(foot, '1 2 3');

        function pick(i) {
            if (locked || !G) return;
            locked = true;
            row.classList.add('mg-off');
            var j = rndInt(0, 2);
            you.textContent = RPS_ICON[RPS[i]];
            them.textContent = RPS_ICON[RPS[j]];
            var res = i === j ? 'tie' : ((i - j + 3) % 3 === 1 ? 'win' : 'lose');
            verdict.textContent = T('mg_' + res);
            flash(res === 'win' ? 'mg-good' : (res === 'lose' ? 'mg-bad' : 'mg-tie'));
            if (res === 'tie' && cfg.allowretry) { later(reset, 1300); return; }
            later(function () { finish({ result: res }); }, 1500);
        }
        G.key = function (ev) {
            if (ev.repeat) return;
            var n = { '1': 0, '2': 1, '3': 2, r: 0, p: 1, s: 2 }[String(ev.key).toLowerCase()];
            if (n !== undefined) pick(n);
        };
        G.cancel = function () { finish({ result: 'lose' }); };
        reset();
        wrap.classList.remove('mc-hidden');
    }

    // ================================================================ hammertime
    var WOOD = { 'light-wood': 'light', 'medium-wood': 'medium', 'dark-wood': 'dark' };
    function hammertime(cfg) {
        shell('hammertime');
        var count = Math.max(1, Math.min(8, Math.floor(num(cfg.nails, 3))));
        var HITS = 2, MISSES = 3;
        var plank = mk('div', 'mg-plank mg-wood-' + (WOOD[cfg.type] || 'medium'), stage);
        var nails = [];
        for (var i = 0; i < count; i++) {
            var n = mk('div', 'mg-nail', plank);
            mk('div', 'mg-nail-head', n);
            mk('div', 'mg-nail-shaft', n);
            nails.push({ el: n, left: HITS });
        }
        var meter = mk('div', 'mg-meter', stage);
        var sweet = mk('div', 'mg-meter-sweet', meter);
        var bar = mk('div', 'mg-meter-fill', meter);
        var life = pips(foot, MISSES);
        keyCap(foot, 'SPACE');
        var cur = 0, misses = 0, p = 0, dir = 1, lo = 0;
        function newSweet() { lo = rnd(0.55, 0.78); sweet.style.bottom = (lo * 100) + '%'; sweet.style.height = '16%'; }
        function mark() { nails.forEach(function (n, i) { n.el.classList.toggle('mg-current', i === cur); }); }
        newSweet(); mark();
        loop(function (dt) {
            p += dir * dt / 700;
            if (p >= 1) { p = 1; dir = -1; }
            if (p <= 0) { p = 0; dir = 1; }
            bar.style.height = (p * 100) + '%';
        });
        function strike() {
            if (!G || cur >= nails.length) return;
            var n = nails[cur];
            if (p >= lo && p <= lo + 0.16) {
                n.left--;
                n.el.style.setProperty('--sink', String((HITS - n.left) / HITS));
                flash('mg-good');
                if (n.left <= 0) {
                    n.el.classList.add('mg-done');
                    cur++;
                    mark();
                    if (cur >= nails.length) { later(function () { finish({ result: true }); }, 400); return; }
                }
                newSweet();
            } else {
                misses++;
                life.set(MISSES - misses);
                n.el.classList.add('mg-bent');
                later(function () { n.el.classList.remove('mg-bent'); }, 250);
                flash('mg-bad');
                if (misses >= MISSES) later(function () { finish({ result: false }); }, 400);
            }
        }
        plank.addEventListener('click', strike);
        G.key = function (ev) { if (!ev.repeat && (ev.key === ' ' || ev.key === 'Enter' || ev.key === 'e' || ev.key === 'E')) { ev.preventDefault(); strike(); } };
        G.cancel = function () { finish({ result: false }); };
        wrap.classList.remove('mc-hidden');
    }

    // ================================================================ cowmilker
    function cowmilker(cfg) {
        shell('cowmilker');
        var secs = Math.max(1, num(cfg.timer, 10));
        var lo = Math.max(0, num(cfg.minMilkPerSqueez, 1));
        var hi = Math.max(lo, num(cfg.maxMilkPerSqueez, lo + 1));
        var cap = secs * 5 * hi || 1;            // a brisk pace fills the pail
        var collected = 0, last = '', left = secs * 1000;

        var row = mk('div', 'mg-milk', stage);
        var lk = mk('div', 'mg-teat', row); mk('span', 'mc-key', lk).textContent = 'A';
        var pail = mk('div', 'mg-pail', row);
        var milk = mk('div', 'mg-pail-milk', pail);
        var amount = mk('div', 'mg-pail-amount', pail);
        var rk = mk('div', 'mg-teat', row); mk('span', 'mc-key', rk).textContent = 'D';
        var timeTrack = mk('div', 'mg-track mg-time', stage);
        var timeFill = mk('div', 'mg-time-fill', timeTrack);

        function show() {
            milk.style.height = Math.min(100, collected / cap * 100) + '%';
            amount.textContent = (Math.round(collected * 10) / 10).toString();
        }
        function squeeze(side) {
            if (!G || side === last) return;
            last = side;
            (side === 'l' ? lk : rk).classList.add('mg-press');
            later(function () { (side === 'l' ? lk : rk).classList.remove('mg-press'); }, 120);
            collected += rnd(lo, hi);
            show();
        }
        loop(function (dt) {
            left -= dt;
            timeFill.style.width = Math.max(0, left / (secs * 1000) * 100) + '%';
            if (left <= 0) finish({ collected: Math.round(collected * 100) / 100 });
        });
        wrap.addEventListener('mousedown', function (ev) { if (G && G.game === 'cowmilker') squeeze(ev.button === 2 ? 'r' : 'l'); });
        G.key = function (ev) {
            if (ev.repeat) return;
            var k = String(ev.key).toLowerCase();
            if (k === 'a' || k === 'arrowleft') squeeze('l');
            else if (k === 'd' || k === 'arrowright') squeeze('r');
        };
        G.cancel = function () { finish({ collected: Math.round(collected * 100) / 100 }); };
        show();
        wrap.classList.remove('mc-hidden');
    }

    // ================================================================ diceroller
    // notation: '4d20', '2d6+1', { '2d10', '2d6' }, { qty, sides }, or a list of those
    function parseOne(n) {
        if (n && typeof n === 'object' && !Array.isArray(n)) {
            return [{ qty: Math.max(1, Math.floor(num(n.qty, 1))), sides: Math.max(2, Math.floor(num(n.sides, 6))), modifier: num(n.modifier, 0) }];
        }
        var out = [];
        String(n || '').split(/[\s,]+/).forEach(function (part) {
            var m = /^(\d*)d(\d+)([+-]\d+)?$/i.exec(part.trim());
            if (m) out.push({ qty: Math.max(1, Math.min(50, Number(m[1] || 1))), sides: Math.max(2, Number(m[2])), modifier: Number(m[3] || 0) });
        });
        return out;
    }
    function parseNotation(n) {
        if (Array.isArray(n)) {
            var all = [];
            n.forEach(function (x) { all = all.concat(parseOne(x)); });
            return all;
        }
        return parseOne(n);
    }

    var dice = null;   // { groups: [{ id, qty, sides, modifier, rolls: [{ groupId, rollId, sides, value, el }] }], tray }
    function diceroller(cfg) {
        shell('diceroller');
        dice = { groups: [], tray: mk('div', 'mg-tray', stage), total: mk('div', 'mc-title mg-dice-total', stage), seq: 0 };
        wrap.classList.remove('mc-hidden');
        G.cancel = function () {
            var token = G.token;
            stopGame();
            post('mgClosed', { token: token });
        };
        G.key = function () {};
        diceCommand(cfg);
    }

    function emit(type, data) {
        if (!G) return;
        post('mgEvent', { token: G.token, result: { type: type, data: data } });
    }
    function rollView(r) { return { groupId: r.groupId, rollId: r.rollId, sides: r.sides, value: r.value }; }
    function groupView(g) {
        var sum = 0;
        g.rolls.forEach(function (r) { sum += r.value || 0; });
        return { id: g.id, qty: g.rolls.length, sides: g.sides, modifier: g.modifier, value: sum + g.modifier, rolls: g.rolls.map(rollView) };
    }
    function showTotal() {
        var t = 0, any = false;
        dice.groups.forEach(function (g) { var v = groupView(g); t += v.value; if (g.rolls.length) any = true; });
        dice.total.textContent = any ? String(t) : '';
    }

    function rollDice(list) {
        // list: rolls to (re)roll; they tumble, then settle one by one
        if (!list.length) return;
        list.forEach(function (r) { r.value = 0; r.el.classList.add('mg-rolling'); });
        dice.total.textContent = '';
        var spin = setInterval(function () {
            list.forEach(function (r) { if (!r.value) r.el.textContent = String(rndInt(1, r.sides)); });
        }, 70);
        timers.push(spin);
        list.forEach(function (r, i) {
            later(function () {
                r.value = rndInt(1, r.sides);
                r.el.textContent = String(r.value);
                r.el.classList.remove('mg-rolling');
                emit('dieComplete', rollView(r));
                if (i === list.length - 1) {
                    clearInterval(spin);
                    showTotal();
                    emit('rollComplete', dice.groups.map(groupView));
                    autoClear();
                }
            }, 700 + i * 180);
        });
    }

    function addGroups(parsed) {
        var added = [];
        parsed.forEach(function (p) {
            var g = { id: dice.groups.length, qty: p.qty, sides: p.sides, modifier: p.modifier || 0, rolls: [] };
            for (var i = 0; i < p.qty; i++) {
                var el = mk('div', 'mg-die' + (p.sides === 6 ? ' mg-d6' : ''), dice.tray);
                el.setAttribute('data-sides', 'd' + p.sides);
                var r = { groupId: g.id, rollId: i, sides: p.sides, value: 0, el: el };
                g.rolls.push(r); added.push(r);
            }
            dice.groups.push(g);
        });
        return added;
    }

    var clearTimer = 0;
    var clearCfg = null;
    function autoClear() {
        clearTimeout(clearTimer);
        if (!clearCfg || !clearCfg.active) return;
        clearTimer = later(function () { clearDice(); }, Math.max(500, num(clearCfg.time, 3000)));
    }
    function clearDice() {
        if (!dice) return;
        dice.groups = [];
        dice.tray.innerHTML = '';
        dice.total.textContent = '';
    }

    function diceCommand(cfg) {
        if (!dice || !G) return;
        var type = String(cfg.type || 'roll').toLowerCase();
        var opts = cfg.options || {};
        if (opts.autoClear) clearCfg = opts.autoClear;
        var parsed = parseNotation(opts.notation !== undefined ? opts.notation : opts);
        if (type === 'roll') {
            clearDice();
            emit('beforeRoll', parsed);
            rollDice(addGroups(parsed));
        } else if (type === 'add') {
            emit('beforeRoll', parsed);
            rollDice(addGroups(parsed));
        } else if (type === 'reroll') {
            var all = [];
            dice.groups.forEach(function (g) { g.rolls.forEach(function (r) { all.push(r); }); });
            emit('beforeRoll', dice.groups.map(groupView));
            rollDice(all);
        } else if (type === 'remove') {
            // take away dice matching the notation (or the last die)
            var removed = [];
            var want = parsed.length ? parsed : [{ qty: 1, sides: 0 }];
            want.forEach(function (w) {
                for (var n = 0; n < w.qty; n++) {
                    for (var gi = dice.groups.length - 1; gi >= 0; gi--) {
                        var g = dice.groups[gi];
                        if ((!w.sides || g.sides === w.sides) && g.rolls.length) {
                            var r = g.rolls.pop(); r.el.remove(); removed.push(rollView(r)); break;
                        }
                    }
                }
            });
            dice.groups = dice.groups.filter(function (g) { return g.rolls.length; });
            showTotal();
            emit('removeComplete', removed);
        } else if (type === 'clear') {
            clearDice();
        }
    }

    // ------------------------------------------------------------ start / messages
    var GAMES = { skillcheck: skillcheck, lockpick: lockpick, rps: rps, hammertime: hammertime, cowmilker: cowmilker, diceroller: diceroller };

    function start(d) {
        clearAll();
        clearCfg = null;
        var fn = GAMES[d.game];
        if (!fn) return;
        G = { token: d.token, game: d.game, cfg: d.cfg || {} };
        fn(G.cfg);
    }

    window.addEventListener('keydown', function (ev) {
        if (!G) return;
        if (ev.key === 'Escape') { if (!ev.repeat && G.cancel) G.cancel(); return; }
        if (G.key) G.key(ev);
    });
    window.addEventListener('keyup', function (ev) { if (G && G.keyup) G.keyup(ev); });

    window.addEventListener('message', function (ev) {
        var m = ev.data || {};
        switch (m.action) {
            case 'mgStart': start(m.data || {}); break;
            case 'mgStop': stopGame(); break;
            case 'mgTrigger':
                if (G && m.data && m.data.token === G.token && G.game === 'diceroller') diceCommand(m.data.cfg || {});
                break;
        }
    });

    // for the render preview
    window.MG = { start: start, stop: stopGame };
})();
