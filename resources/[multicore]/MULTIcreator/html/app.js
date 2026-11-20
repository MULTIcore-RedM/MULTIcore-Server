/* ============================================================
   MULTIcreator page
   The client sends 'open' with the data (grouped pieces), the config and
   the language table. Every change rebuilds the look and posts it back
   (debounced) so the ped follows the sliders.
   ============================================================ */
(function () {
    'use strict';

    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'MULTIcreator';
    const $ = (id) => document.getElementById(id);

    // hair / beard colour names in the game data -> swatch colour shown in the menu (display only)
    const HAIR_SWATCH = {
        BLONDE: '#c9a564', BROWN: '#5a3b24', DARK_BLONDE: '#9c7a45', DARKEST_BROWN: '#2b1c12',
        DARK_GINGER: '#7a3a1c', DARK_GREY: '#55524d', GINGER: '#a5512a', GREY: '#8c8984',
        JET_BLACK: '#121110', LIGHT_BLONDE: '#e0c890', LIGHT_BROWN: '#7d5a3a', LIGHT_GINGER: '#c47a4a',
        LIGHT_GREY: '#b8b5ae', MEDIUM_BROWN: '#6a4529', SALT_PEPPER: '#6f6c66', STRAWBERRY_BLONDE: '#c98c5e',
        UNCLE_GREY: '#a29f98',
    };
    const FEATURE_GROUPS = [
        ['head', /^head/], ['eyes', /^(eyes|eyelid)/], ['brows', /^eyebrow/], ['ears', /^(ears|earlobe)/],
        ['cheeks', /^cheekbones/], ['jaw', /^(jaw|chin)/], ['nose', /^(nose|nostrils)/], ['mouth', /^(mouth|upper lip|lower lip)/],
    ];
    const MAX_TINT = 254;

    let L = {};
    let D = null;        // data from the client
    let C = {};          // config from the client
    let mode = 'create';
    let look = null;     // { skin, comps }
    let info = {};
    let ui = {};         // menu positions that are not stored in the look (tone, shape, style ...)
    let tab = null;
    let ovSel = null;
    let applyTimer = null, applyKind = null;
    let cancelArmed = false;
    let busy = false;

    const t = (key, ...args) => {
        let s = (L && L[key] !== undefined) ? L[key] : key;
        args.forEach((a) => { s = s.replace(/%[sd]/, String(a)); });
        return s;
    };

    function post(name, body) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => null);
    }

    const clone = (o) => JSON.parse(JSON.stringify(o));
    const sexData = () => D[look.skin.sex] || D.male;
    const rnd = (n) => Math.floor(Math.random() * n);

    // ---------------------------------------------------------------
    // look <-> menu positions
    // ---------------------------------------------------------------

    // skin tone: menu position 1..n <-> tone number in the piece name (_V_00n), light to dark (D.toneOrder)
    const toneV = (pos) => (D.toneOrder && D.toneOrder[pos - 1]) || pos;
    const tonePos = (v) => { const k = (D.toneOrder || []).indexOf(v); return k >= 0 ? k + 1 : v; };
    // eyes / teeth: menu position 1..n <-> index of a named piece
    const posOf = (list, index) => Math.max(1, list.indexOf(index) + 1);

    // heads / bodies: groups of tones (named pieces only)
    function toneGroups(g) {
        const out = g.groups.slice();
        (g.extras || []).forEach((i) => out.push({ name: 'x' + i, tones: Array(Math.max(1, g.tones)).fill(i) }));
        return out;
    }
    function pick(groups, shape, tone) {
        const g = groups[Math.min(Math.max(shape, 1), groups.length) - 1];
        if (!g) return 1;
        return g.tones[tone - 1] || g.tones.find((x) => x > 0) || 1;
    }
    function locate(groups, index) {
        for (let s = 0; s < groups.length; s++) {
            const k = groups[s].tones.indexOf(index);
            if (k >= 0) return { shape: s + 1, tone: k + 1 };
        }
        return { shape: 1, tone: 1 };
    }
    function locateStyle(groups, index) {
        for (let s = 0; s < groups.length; s++) {
            const k = groups[s].items.findIndex((it) => it.i === index);
            if (k >= 0) return { style: s + 1, colour: k + 1 };
        }
        return { style: 0, colour: 1 };
    }

    function readUi() {
        const sd = sexData(), s = look.skin;
        const h = locate(toneGroups(sd.heads), s.head);
        const u = locate(toneGroups(sd.bodiesUpper), s.bodyUpper);
        const l = locate(toneGroups(sd.bodiesLower), s.bodyLower);
        const hair = s.hair > 0 ? locateStyle(sd.hair, s.hair) : { style: 0, colour: 1 };
        const beard = s.beard > 0 ? locateStyle(sd.beards, s.beard) : { style: 0, colour: 1 };
        ui = { tone: tonePos(h.tone), shape: h.shape, upper: u.shape, lower: l.shape,
            eye: posOf(sd.eyes, s.eyes), tooth: posOf(sd.teeth, s.teeth),
            hairStyle: hair.style, hairColour: hair.colour, beardStyle: beard.style, beardColour: beard.colour };
    }

    function writeSkin() {
        const sd = sexData(), s = look.skin;
        const tone = toneV(ui.tone);
        s.head = pick(toneGroups(sd.heads), ui.shape, tone);
        s.bodyUpper = pick(toneGroups(sd.bodiesUpper), ui.upper, tone);
        s.bodyLower = pick(toneGroups(sd.bodiesLower), ui.lower, tone);
        s.eyes = sd.eyes[ui.eye - 1] || sd.eyes[0] || 1;
        s.teeth = sd.teeth[ui.tooth - 1] || sd.teeth[0] || 1;
        const hg = sd.hair[ui.hairStyle - 1];
        s.hair = hg ? (hg.items[Math.min(ui.hairColour, hg.items.length) - 1] || hg.items[0]).i : 0;
        const bg = sd.beards[ui.beardStyle - 1];
        s.beard = bg ? (bg.items[Math.min(ui.beardColour, bg.items.length) - 1] || bg.items[0]).i : 0;
    }

    function newOverlay() { return { tx: 1, var: 0, opacity: 1.0, palette: 1, c1: 0, c2: 0, c3: 0 }; }

    function defaultLook(sex) {
        const sd = D[sex];
        const skin = { sex: sex, head: 1, bodyUpper: 1, bodyLower: 1, eyes: 1, teeth: 1, hair: 0, beard: 0,
            bodyType: 0, waist: 0, height: 1.0, features: {}, body: {}, overlays: { eyebrows: newOverlay() } };
        const comps = {};
        const start = (C.startingClothes || {})[sex] || {};
        sd.clothes.forEach((c) => { if (start[c.key] && start[c.key] <= c.count) comps[c.key] = { index: start[c.key] }; });
        look = { skin: skin, comps: comps };
        ui = { tone: 1, shape: 1, upper: 1, lower: 1, eye: 1, tooth: 1, hairStyle: sd.hair.length ? 1 : 0, hairColour: 1, beardStyle: 0, beardColour: 1 };
        writeSkin();
    }

    // ---------------------------------------------------------------
    // applying (debounced)
    // ---------------------------------------------------------------

    function queue(kind) {
        applyKind = (applyKind && applyKind !== kind) ? 'all' : kind;
        clearTimeout(applyTimer);
        applyTimer = setTimeout(() => {
            const k = applyKind; applyKind = null;
            post('apply', { kind: k, look: look });
        }, C.applyDelay || 0);
    }

    // ---------------------------------------------------------------
    // controls
    // ---------------------------------------------------------------

    function el(tag, cls, text) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    }
    function heading(text) { return el('div', 'mc-heading', text); }

    // < value n / max >
    function stepper(label, value, min, max, onChange, fmt) {
        const wrap = el('div', 'block');
        if (label) wrap.appendChild(el('div', 'step-label', label));
        const s = el('div', 'mc-stepper');
        const prev = el('button', '', '‹'), next = el('button', '', '›');
        const txt = el('div', 'mc-stepper-text');
        const draw = () => {
            txt.textContent = fmt ? fmt(value) : (value === 0 && min === 0 ? t('none') : String(value));
            const sm = el('small', '', `${value} / ${max}`);
            txt.appendChild(sm);
        };
        const set = (v) => {
            if (max < min) return;
            if (v > max) v = min; if (v < min) v = max;
            value = v; draw(); onChange(v);
        };
        prev.onclick = () => set(value - 1);
        next.onclick = () => set(value + 1);
        s.append(prev, txt, next); wrap.appendChild(s); draw();
        return wrap;
    }

    function slider(label, value, min, max, step, onChange, fmt) {
        const w = el('div', 'mc-slider');
        const lab = el('span', 'mc-slider-label', label);
        const val = el('span', 'mc-slider-value');
        const r = el('input'); r.type = 'range'; r.min = min; r.max = max; r.step = step; r.value = value;
        const show = () => { val.textContent = fmt ? fmt(+r.value) : (+r.value).toFixed(2); };
        r.oninput = () => { show(); onChange(+r.value); };
        w.append(lab, val, r); show();
        return w;
    }

    function toggle(label, on, onChange) {
        const w = el('label', 'toggle');
        const c = el('input'); c.type = 'checkbox'; c.checked = !!on;
        c.onchange = () => onChange(c.checked);
        w.append(c, document.createTextNode(label));
        return w;
    }

    function field(label, input) {
        const f = el('div', 'mc-field');
        f.append(el('label', '', label), input);
        return f;
    }
    function textInput(value, max, onInput, type) {
        const i = el('input', 'mc-input'); i.type = type || 'text'; i.value = value || '';
        if (max) i.maxLength = max;
        i.oninput = () => onInput(i.value);
        return i;
    }

    // ---------------------------------------------------------------
    // tabs
    // ---------------------------------------------------------------

    const TABS = {
        identity: { cam: 'body', draw: drawIdentity },
        body: { cam: 'body', draw: drawBody },
        face: { cam: 'face', draw: drawFace },
        features: { cam: 'face', draw: drawFeatures },
        hair: { cam: 'face', draw: drawHair },
        overlays: { cam: 'face', draw: drawOverlays },
        clothes: { cam: 'body', draw: drawClothes },
    };
    const tabsFor = () => mode === 'barber' ? ['hair', 'overlays'] : ['identity', 'body', 'face', 'features', 'hair', 'overlays', 'clothes'];

    function drawTabs() {
        const nav = $('tabs'); nav.innerHTML = '';
        tabsFor().forEach((k) => {
            const b = el('button', 'mc-tab' + (k === tab ? ' active' : ''), t('tab_' + k));
            b.onclick = () => openTab(k);
            nav.appendChild(b);
        });
    }
    function openTab(k) {
        // the camera stays where the player put it (FACE / BODY / LEGS buttons, mouse wheel); tabs don't move it
        tab = k; drawTabs(); draw();
        drawCams();
    }
    function draw() {
        const c = $('content'); c.innerHTML = '';
        TABS[tab].draw(c);
    }

    function sexChoice(c) {
        const w = el('div', 'mc-choice');
        ['male', 'female'].forEach((sx) => {
            const b = el('button', 'mc-btn' + (look.skin.sex === sx ? ' active' : ''), t('sex_' + sx));
            b.onclick = () => switchSex(sx);
            w.appendChild(b);
        });
        c.appendChild(field(t('sex'), w));
    }

    function switchSex(sx) {
        if (busy || look.skin.sex === sx) return;
        busy = true;
        defaultLook(sx);
        info.gender = sx;
        post('sex', { sex: sx, look: look }).then(() => { busy = false; draw(); });
        draw();
    }

    function drawIdentity(c) {
        const id = C.identity || {};
        sexChoice(c);
        const grid = el('div', 'field-grid');
        grid.append(
            field(t('firstname'), textInput(info.firstname, 30, (v) => { info.firstname = v; })),
            field(t('lastname'), textInput(info.lastname, 30, (v) => { info.lastname = v; })),
        );
        c.appendChild(grid);
        c.appendChild(field(t('nickname'), textInput(info.nickname, id.nicknameMax, (v) => { info.nickname = v; })));
        const g2 = el('div', 'field-grid');
        const age = textInput(info.age, 3, (v) => { info.age = v; }, 'number');
        age.min = id.minAge; age.max = id.maxAge;
        const birth = textInput(info.birthdate, 10, (v) => {
            info.birthdate = v;
            const m = /^(\d{4})-\d{2}-\d{2}$/.exec(v);
            if (m && id.gameYear) { info.age = id.gameYear - (+m[1]); age.value = info.age; }
        }, 'date');
        g2.append(field(t('birthdate'), birth), field(t('age'), age));
        c.appendChild(g2);
        const sel = el('select', 'mc-select');
        (id.nationalities || []).forEach((n) => {
            const o = el('option', '', t('nation_' + n)); o.value = n;
            if (info.nationalityKey === n) o.selected = true;
            sel.appendChild(o);
        });
        if (!info.nationalityKey && id.nationalities) info.nationalityKey = id.nationalities[0];
        sel.onchange = () => { info.nationalityKey = sel.value; };
        c.appendChild(field(t('nationality'), sel));
        const ta = el('textarea', 'mc-textarea'); ta.maxLength = id.descriptionMax || 500; ta.value = info.description || '';
        ta.placeholder = t('description_hint');
        ta.oninput = () => { info.description = ta.value; };
        c.appendChild(field(t('description'), ta));
    }

    function drawBody(c) {
        const sd = sexData(), s = look.skin;
        sexChoice(c);
        const tones = Math.max(1, sd.heads.tones);
        c.appendChild(stepper(t('skin_tone'), ui.tone, 1, tones, (v) => { ui.tone = v; writeSkin(); queue('all'); }));
        c.appendChild(heading(t('body_shape')));
        c.appendChild(stepper(t('body_type'), Math.min(s.bodyType, D.bodySizes), 0, D.bodySizes || 0, (v) => { s.bodyType = v; queue('all'); }, (v) => v === 0 ? t('default') : t('build_' + v)));
        c.appendChild(stepper(t('waist'), s.waist, 0, D.waists || 0, (v) => { s.waist = v; queue('all'); }, (v) => v === 0 ? t('default') : String(v)));
        c.appendChild(stepper(t('torso'), ui.upper, 1, toneGroups(sd.bodiesUpper).length, (v) => { ui.upper = v; writeSkin(); queue('all'); }));
        c.appendChild(stepper(t('legs'), ui.lower, 1, toneGroups(sd.bodiesLower).length, (v) => { ui.lower = v; writeSkin(); queue('all'); }));
        const h = C.height || { min: 0.95, max: 1.05, step: 0.01 };
        c.appendChild(slider(t('height'), s.height, h.min, h.max, h.step, (v) => { s.height = v; queue('features'); }, (v) => Math.round(v * 100) + '%'));
        if (C.bodySliders !== false) drawBodySliders(c);
    }

    // body proportions (MetaPedExpression sliders, -1..1); female-only ones hidden on male
    function bodyList() { return (D.body || []).filter((f) => !f.female || look.skin.sex === 'female'); }
    function drawBodySliders(c) {
        const s = look.skin;
        s.body = s.body || {};
        c.appendChild(heading(t('body_sliders')));
        bodyList().forEach((f) => {
            c.appendChild(slider(t('body_' + f.name), s.body[f.key] || 0, -1, 1, 0.05, (v) => {
                s.body[f.key] = v; queue('features');
            }));
        });
        const reset = el('button', 'mc-btn small', t('reset_body'));
        reset.onclick = () => { s.body = {}; queue('features'); draw(); };
        c.appendChild(reset);
    }

    function drawFace(c) {
        const sd = sexData(), s = look.skin;
        c.appendChild(stepper(t('head'), ui.shape, 1, toneGroups(sd.heads).length, (v) => { ui.shape = v; writeSkin(); queue('all'); }));
        c.appendChild(stepper(t('skin_tone'), ui.tone, 1, Math.max(1, sd.heads.tones), (v) => { ui.tone = v; writeSkin(); queue('all'); }));
        c.appendChild(stepper(t('eye_colour'), ui.eye, 1, sd.eyes.length, (v) => { ui.eye = v; writeSkin(); queue('all'); }));
        c.appendChild(stepper(t('teeth'), ui.tooth, 1, sd.teeth.length, (v) => { ui.tooth = v; writeSkin(); queue('all'); }));
    }

    function featureLabel(name) { return t('feat_' + name.replace(/ /g, '_')); }

    function drawFeatures(c) {
        const s = look.skin;
        FEATURE_GROUPS.forEach(([g, re]) => {
            const list = D.features.filter((f) => re.test(f.name));
            if (!list.length) return;
            c.appendChild(heading(t('group_' + g)));
            list.forEach((f) => {
                c.appendChild(slider(featureLabel(f.name), s.features[f.key] || 0, -1, 1, 0.05, (v) => {
                    s.features[f.key] = v; queue('features');
                }));
            });
        });
        const reset = el('button', 'mc-btn small', t('reset_features'));
        reset.onclick = () => { s.features = {}; queue('features'); draw(); };
        c.appendChild(reset);
    }

    function colourSwatches(groups, styleIdx, colour, onPick) {
        const g = groups[styleIdx - 1];
        const w = el('div', 'mc-swatches');
        if (!g) return w;
        g.items.forEach((it, k) => {
            const sw = el('div', 'mc-swatch' + (k + 1 === colour ? ' active' : ''));
            sw.style.background = HAIR_SWATCH[it.c] || 'var(--mc-paper-3)';
            sw.title = it.c ? t('colour_' + it.c.toLowerCase()) : String(k + 1);
            sw.onclick = () => onPick(k + 1);
            w.appendChild(sw);
        });
        return w;
    }

    function drawHair(c) {
        const sd = sexData();
        c.appendChild(heading(t('hair')));
        c.appendChild(stepper(t('style'), ui.hairStyle, 0, sd.hair.length, (v) => { ui.hairStyle = v; writeSkin(); queue('all'); draw(); }));
        if (ui.hairStyle > 0) {
            c.appendChild(el('div', 'step-label', t('colour')));
            c.appendChild(colourSwatches(sd.hair, ui.hairStyle, ui.hairColour, (k) => { ui.hairColour = k; writeSkin(); queue('all'); draw(); }));
        }
        if (sd.beards.length) {
            c.appendChild(heading(t('beard')));
            c.appendChild(stepper(t('style'), ui.beardStyle, 0, sd.beards.length, (v) => { ui.beardStyle = v; writeSkin(); queue('all'); draw(); }));
            if (ui.beardStyle > 0) {
                c.appendChild(el('div', 'step-label', t('colour')));
                c.appendChild(colourSwatches(sd.beards, ui.beardStyle, ui.beardColour, (k) => { ui.beardColour = k; writeSkin(); queue('all'); draw(); }));
            }
        }
    }

    function overlayList() {
        if (mode !== 'barber') return D.overlays;
        const allow = C.barberOverlays || [];
        return D.overlays.filter((o) => allow.indexOf(o.name) >= 0);
    }

    function drawOverlays(c) {
        const s = look.skin, list = overlayList();
        if (!ovSel || !list.find((o) => o.name === ovSel)) ovSel = list.length ? list[0].name : null;
        const box = el('div', 'mc-list ov-list');
        list.forEach((o) => {
            const on = !!s.overlays[o.name];
            const row = el('div', 'mc-row' + (o.name === ovSel ? ' active' : ''));
            row.append(el('span', '', t('overlay_' + o.name)), el('span', 'ov-state' + (on ? ' on' : ''), on ? t('on') : t('off')));
            row.onclick = () => { ovSel = o.name; draw(); };
            box.appendChild(row);
        });
        c.appendChild(box);
        const o = list.find((x) => x.name === ovSel);
        if (!o) return;
        const ed = el('div', 'ov-editor');
        const cur = s.overlays[o.name];
        ed.appendChild(toggle(t('overlay_' + o.name), !!cur, (v) => {
            if (v) s.overlays[o.name] = newOverlay(); else delete s.overlays[o.name];
            queue('overlays'); draw();
        }));
        if (cur) {
            ed.appendChild(stepper(t('texture'), cur.tx, 1, o.count, (v) => { cur.tx = v; queue('overlays'); }));
            if (o.variants > 1) ed.appendChild(stepper(t('variant'), cur.var + 1, 1, o.variants, (v) => { cur.var = v - 1; queue('overlays'); }));
            ed.appendChild(slider(t('opacity'), cur.opacity, 0, 1, 0.05, (v) => { cur.opacity = v; queue('overlays'); }, (v) => Math.round(v * 100) + '%'));
            ed.appendChild(stepper(t('palette'), cur.palette, 1, D.palettes, (v) => { cur.palette = v; queue('overlays'); }));
            ['c1', 'c2', 'c3'].forEach((k, i) => {
                ed.appendChild(slider(t('tint_n', i + 1), cur[k], 0, MAX_TINT, 1, (v) => { cur[k] = v; queue('overlays'); }, (v) => String(v)));
            });
        }
        c.appendChild(ed);
    }

    function drawClothes(c) {
        const sd = sexData();
        sd.clothes.forEach((cat) => {
            const w = el('div', 'cloth');
            const piece = look.comps[cat.key];
            w.appendChild(stepper(t('cloth_' + cat.key), piece ? piece.index : 0, 0, cat.count, (v) => {
                if (v === 0) delete look.comps[cat.key];
                else look.comps[cat.key] = Object.assign(look.comps[cat.key] || {}, { index: v });
                queue('comps');
                if (cat.tint && (v === 0) !== !piece) draw();
            }));
            if (cat.tint && piece) {
                const tw = el('div', 'tints');
                tw.appendChild(toggle(t('custom_colour'), piece.palette !== undefined, (v) => {
                    if (v) Object.assign(piece, { palette: 1, tint0: 0, tint1: 0, tint2: 0 });
                    else { delete piece.palette; delete piece.tint0; delete piece.tint1; delete piece.tint2; }
                    queue('comps'); draw();
                }));
                if (piece.palette !== undefined) {
                    tw.appendChild(stepper(t('palette'), piece.palette, 1, D.palettes, (v) => { piece.palette = v; queue('comps'); }));
                    ['tint0', 'tint1', 'tint2'].forEach((k, i) => {
                        tw.appendChild(slider(t('tint_n', i + 1), piece[k] || 0, 0, MAX_TINT, 1, (v) => { piece[k] = v; queue('comps'); }, (v) => String(v)));
                    });
                }
                w.appendChild(tw);
            }
            c.appendChild(w);
        });
    }

    // ---------------------------------------------------------------
    // randomise
    // ---------------------------------------------------------------

    function randomise() {
        const sd = sexData(), s = look.skin, r = C.random || {};
        const span = r.featureRange || 0.5;
        if (mode !== 'barber') {
            ui.tone = 1 + rnd(Math.max(1, sd.heads.tones));
            ui.shape = 1 + rnd(sd.heads.groups.length || 1);
            ui.eye = 1 + rnd(Math.max(1, sd.eyes.length));
            ui.tooth = 1 + rnd(Math.max(1, sd.teeth.length));
            s.bodyType = rnd((D.bodySizes || 0) + 1);
            s.waist = rnd((D.waists || 0) + 1);
            s.features = {};
            D.features.forEach((f) => { s.features[f.key] = Math.round((Math.random() * 2 - 1) * span * 100) / 100; });
            const bspan = r.bodyRange || 0.3;
            s.body = {};
            bodyList().forEach((f) => { s.body[f.key] = Math.round((Math.random() * 2 - 1) * bspan * 100) / 100; });
        }
        ui.hairStyle = sd.hair.length ? 1 + rnd(sd.hair.length) : 0;
        ui.hairColour = 1 + rnd(sd.hair[ui.hairStyle - 1] ? sd.hair[ui.hairStyle - 1].items.length : 1);
        if (sd.beards.length && Math.random() < (r.beardChance || 0.5)) {
            ui.beardStyle = 1 + rnd(sd.beards.length);
            ui.beardColour = ui.hairColour;
        } else ui.beardStyle = 0;
        const eb = D.overlays.find((o) => o.name === 'eyebrows');
        if (eb) s.overlays.eyebrows = Object.assign(newOverlay(), { tx: 1 + rnd(eb.count) });
        writeSkin();
        queue('all');
        draw();
    }

    // ---------------------------------------------------------------
    // finish / cancel
    // ---------------------------------------------------------------

    function validate() {
        const id = C.identity || {};
        const nameOk = (n) => typeof n === 'string' && n.trim().length >= 1 && n.trim().length <= 30;
        if (!nameOk(info.firstname) || !nameOk(info.lastname)) return t('err_name');
        if (!/^\d{4}-\d{2}-\d{2}$/.test(info.birthdate || '')) return t('err_birthdate');
        const age = +info.age;
        if (!(age >= id.minAge && age <= id.maxAge)) return t('err_age', id.minAge, id.maxAge);
        return null;
    }

    function finish() {
        if (busy) return;
        if (mode === 'barber') {
            busy = true; $('btn-finish').disabled = true;
            post('barberSave', { look: look });
            return;
        }
        const err = validate();
        if (err) { $('error').textContent = err; openTab('identity'); return; }
        busy = true;
        post('finish', {
            look: look,
            info: {
                firstname: info.firstname.trim(), lastname: info.lastname.trim(), gender: look.skin.sex,
                birthdate: info.birthdate, nationality: t('nation_' + info.nationalityKey), age: +info.age,
                nickname: (info.nickname || '').trim(), description: (info.description || '').trim(),
            },
        });
    }

    function cancel() {
        if (busy) return;
        if (!cancelArmed) {
            cancelArmed = true; $('btn-cancel').textContent = t('cancel_sure');
            setTimeout(() => { cancelArmed = false; $('btn-cancel').textContent = t('cancel'); }, C.cancelConfirmMs || 3000);
            return;
        }
        post('cancel');
    }

    // ---------------------------------------------------------------
    // camera, rotate, zoom
    // ---------------------------------------------------------------

    let camZone = 'body';
    function drawCams() {
        const w = $('cams'); w.innerHTML = '';
        camZone = TABS[tab].cam;
        ['face', 'body', 'legs'].forEach((z) => {
            const b = el('button', 'mc-btn small' + (z === camZone ? ' active' : ''), t('cam_' + z));
            b.onclick = () => { camZone = z; post('camera', { zone: z }); w.querySelectorAll('.mc-btn').forEach((x) => x.classList.toggle('active', x === b)); };
            w.appendChild(b);
        });
        $('hints').innerHTML = '';
        [['A / D', t('hint_rotate')], ['⇔', t('hint_drag')], ['↕', t('hint_zoom')]].forEach(([k, txt]) => {
            const s = el('span'); s.append(el('span', 'mc-key', k), document.createTextNode(txt + '  '));
            $('hints').appendChild(s);
        });
    }

    let drag = null, dragAcc = 0, dragRaf = 0;
    $('stage').addEventListener('mousedown', (e) => { drag = e.clientX; $('stage').classList.add('dragging'); });
    window.addEventListener('mouseup', () => { drag = null; $('stage').classList.remove('dragging'); });
    window.addEventListener('mousemove', (e) => {
        if (drag === null) return;
        dragAcc += (e.clientX - drag) * (C.mouseRotate || 0.5);
        drag = e.clientX;
        if (!dragRaf) dragRaf = requestAnimationFrame(() => { dragRaf = 0; if (dragAcc) post('rotate', { deg: dragAcc }); dragAcc = 0; });
    });
    $('stage').addEventListener('wheel', (e) => { post('zoom', { delta: e.deltaY > 0 ? 1 : -1 }); });
    window.addEventListener('keydown', (e) => {
        const tag = (document.activeElement && document.activeElement.tagName) || '';
        if (tag === 'INPUT' && document.activeElement.type !== 'range' && document.activeElement.type !== 'checkbox') return;
        if (tag === 'TEXTAREA' || tag === 'SELECT') return;
        const k = e.key.toLowerCase();
        if (k === 'a' || k === 'q') post('rotate', { deg: -(C.rotateStep || 6) });
        if (k === 'd' || k === 'e') post('rotate', { deg: (C.rotateStep || 6) });
    });

    // ---------------------------------------------------------------
    // open / close
    // ---------------------------------------------------------------

    function labels() {
        $('title').textContent = mode === 'barber' ? t('title_barber') : t('title_create');
        $('subtitle').textContent = mode === 'barber' ? t('subtitle_barber') : t('subtitle_create');
        $('btn-random').textContent = t('randomise');
        $('btn-cancel').textContent = t('cancel');
        $('btn-finish').textContent = mode === 'barber'
            ? (C.price > 0 ? t('pay_save', C.price) : t('save'))
            : t('finish');
    }

    function open(msg) {
        L = msg.locale || {};
        D = msg.data; C = msg.config || {}; mode = msg.mode === 'barber' ? 'barber' : 'create';
        document.getElementById('app').classList.toggle('mc-cyrillic', msg.lang === 'ru');
        busy = false; cancelArmed = false; ovSel = null; $('error').textContent = '';
        $('btn-finish').disabled = false;
        if (msg.look && msg.look.skin) {
            look = clone(msg.look);
            look.skin.features = look.skin.features || {};
            look.skin.body = look.skin.body || {};
            look.skin.overlays = look.skin.overlays || {};
            look.comps = look.comps || {};
            readUi();
        } else {
            defaultLook(msg.sex === 'female' ? 'female' : 'male');
            post('apply', { kind: 'all', look: look });
        }
        info = { gender: look.skin.sex, age: '', birthdate: '' };
        labels();
        tab = tabsFor()[0];
        drawTabs(); draw(); drawCams();
        $('app').classList.remove('mc-hidden');
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'open') open(m);
        else if (m.action === 'close') $('app').classList.add('mc-hidden');
        else if (m.action === 'busy') { busy = !!m.busy; $('btn-finish').disabled = busy; }
    });

    $('btn-random').onclick = randomise;
    $('btn-finish').onclick = finish;
    $('btn-cancel').onclick = cancel;
})();
