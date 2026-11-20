// ==========================================================================
// MULTIinventory NUI. RINGO-written, Iron Brand.
// Message contract:, 'pad', 'ammo').
//
// Lua -> NUI  { action, data }:
//   open    { player, equipment, secondary?, secondaryLabel?, hotbar, currency{cash,gold},
//             weight{current,max}, groups, config{...}, ammo? }
//   delta   { container, kind, slots = [{ slot, item|false }], weight, maxWeight }
//   hotbar  [ { slot, kind, ref, item, label, count } ]
//   close   notify { text, type }
//   setup   { categories, locale, saddleButton, mounted, dropMode, confirmDelete, ... }  (client/nui.lua)
//   pad     { button = up|down|left|right|accept|cancel|x|y|lb|rb }                     (client/nui.lua)
//   ammo    [ { type, label, count, max } ]  (same shape as open.gunbelt; optional push)
// Part extras read from `open`: gunbelt (weapons), clothing { slots, conflicts, requires } (clothing),
//   secondaryInfo { kind, shared, acceptWeapons, viewers, countLimit } (secondary), config.saddleButton (compat)
// NUI -> Lua  POST https://<resource>/<action>  -> { ok, err?, data? }
//   core: move split sort use give nearby drop hotbar      clothing: equip unequip outfitList outfitSave
//   outfitWear outfitDelete outfitPack      weapons: weaponEquip weaponUnequip weaponDraw weaponClean
//   weaponUnload weaponRename weaponInspect ammoBelt      local: ready close saddlebag      CR: contextAction
// ==========================================================================
(function () {
  'use strict';

  var IN_GAME = typeof GetParentResourceName === 'function';
  var RES = IN_GAME ? GetParentResourceName() : 'MULTIinventory';

  // ---------------------------------------------------------------- strings
  var UI = {
    kicker: 'SATCHEL', title: 'Inventory', carry: 'Carry weight', overweight: 'Over-burdened: you cannot pick anything up.',
    saddle: 'Saddlebags', sortBy: 'Sort...', sortName: 'By name', sortType: 'By type', sortWeight: 'By weight',
    dragHelp: 'Shift = all · Alt = half · Ctrl = amount', worn: 'WORN', equipment: 'Equipment', give: 'Give', drop: 'Drop', destroy: 'Destroy',
    all: 'All', clothing: 'Clothing', search: 'Search ( / )',
    use: 'Use', wear: 'Wear', remove: 'Take off', equip: 'Equip', equipDraw: 'Equip & draw', draw: 'Draw', holster: 'Unequip',
    holsterFirst: 'unequip first', split: 'Split', examine: 'Examine',
    sidearms: 'Sidearms', hipRight: 'Right hip', hipLeft: 'Left hip (off-hand)', equipRight: 'Equip on right hip', equipLeft: 'Equip on left hip (off-hand)',
    hipExtra: 'Extra holster (3rd)', equipExtra: 'Equip in the extra holster', drawExtra: 'Draw (swaps with the right hip)',
    drawBoth: 'Draw (both)',
    outfits: 'Outfits', outfitSave: 'Save current outfit', outfitName: 'Outfit name', outfitWear: 'Wear', outfitUndress: 'Wear (undress rest)',
    outfitDelete: 'Delete', outfitNone: 'No saved outfits yet.', outfitPieces: '{n} pieces', packOutfit: 'Pack into outfit bundle',
    packTitle: 'Pack outfit bundle', packNote: 'Tick the clothing pieces from your bags to bundle into one item.', missing: 'missing',
    shared: 'Shared', viewers: '{n} viewing', countLimit: 'Max {n} items', page: 'Page', weaponsNo: 'No weapons',
    rename: 'Rename', clean: 'Clean', unload: 'Unload ammo', take: 'Take', moveTo: 'Move to', hotbar: 'Hotbar', clearHotbar: 'Clear hotbar slot',
    cancel: 'Cancel', confirm: 'Confirm', close: 'Close', amount: 'Amount', half: 'Half', one: 'One', allBtn: 'All',
    dropTitle: 'Drop on the ground', dropNote: 'Anyone passing by can pick it up. It stays for a while.',
    destroyTitle: 'Destroy item', destroyNote: 'This cannot be undone.',
    giveTitle: 'Give to', giveNone: 'Nobody close enough.', giveLoading: 'Looking around...', giveNote: 'Stand close to the person you give to.',
    splitTitle: 'Split stack', moveTitle: 'Move how many?', renameTitle: 'Rename weapon',
    storage: 'Storage', saddlebags: 'Saddlebags', trunk: 'Wagon trunk', business: 'Business storage', searching: 'Searching', ground: 'On the ground',
    empty: 'Empty', emptySlotHint: 'Drag a matching piece here to wear it.',
    weight: 'Weight', stack: 'Stack', quality: 'Quality', durability: 'Durability', spoils: 'Spoils in', spoiled: 'Spoiled',
    serial: 'Serial', ammoLoaded: 'Ammo loaded', components: 'Components', condition: 'Condition', category: 'Category', cut: 'Cut',
    tints: 'Colours', madeBy: 'Made by', batch: 'Batch', equipped: 'Equipped', worn2: 'Worn', ctxHint: 'Right-click for options',
    secSlots: 'Slots', unlimited: 'no weight limit',
    cash: 'Cash', cashTitle: 'Hand over cash', cashMenu: 'Cash amount...', cashNote: 'Give it to someone close by, drop it, or put it away. Cash on the ground or in storage is not in your pocket.',
    wallet: 'In your pocket', store: 'Put away', value: 'Value', dollarsLbl: 'Dollars', centsLbl: 'Cents',
    craft: 'Craft', craftKicker: 'HAND CRAFT', craftMoveCancel: 'Move to stop.', craftBtn: 'Craft', craftNeeds: 'Needs', craftTools: 'Tools (kept)',
    craftMakes: 'Makes', craftReady: 'Ready', craftNearly: 'Missing 1', craftMissing: 'Missing {n}', craftFull: 'No room', craftWait: 'Wait {s}s',
    craftRequires: 'Needs {item} in your bags', craftTime: '{s}s each', craftQty: 'How many', craftHint: 'Made by hand, no bench needed',
    craftLoading: 'Looking through your bags...', craftEmpty: 'Nothing you can make by hand.', craftOr: 'or', craftCanMake: 'You can make {n}'
  };
  var ERR = {
    weight: 'Too heavy.', limit: 'You cannot carry more of that.', slots: 'No free slot.', not_enough: 'Not enough.',
    no_item: 'That item is gone.', unknown_action: 'Not available yet.', no_access: 'You cannot reach that.', too_far: 'Too far away.',
    cannot_drop: 'That cannot be dropped.', cannot_give: 'That cannot be given.', expired: 'That has spoiled.', broken: 'That is broken.',
    not_usable: 'That cannot be used.', cooldown: 'Not so fast.', rate_limited: 'Not so fast.', locked: 'Someone else is using this.',
    denied: 'Not allowed.', timeout: 'No answer from the server.', not_stackable: 'Those do not stack.', equip_slot: 'That does not go there.',
    bad_count: 'Bad amount.', slot_taken: 'That slot is taken.', no_weapons: 'Weapons cannot go in there.', target_not_loaded: 'They are not ready.',
    bad_target: 'Pick someone.', not_hotbar: 'That cannot go on the hotbar.', no_mount: 'You are not on a horse.', not_ready: 'Still loading.',
    nui_error: 'Something went wrong.', no_secondary: 'Nothing is open.', unknown_container: 'That storage is gone.', is_weapon: 'Not for weapons.',
    wrong_gender: 'That piece is not cut for you.', no_room: 'No room in your bags.',
    clothing_gender: 'That piece does not fit you.', clothing_conflict: 'Take off the piece that is in the way first.',
    clothing_requires: 'You need to wear a gunbelt for that.', clothing_required_by: 'Take off what hangs on it first.',
    clothing_contract: 'That item cannot be worn.', clothing_only: 'Only clothing goes in a wardrobe.', not_clothing: 'That is not clothing.',
    weapon_equipped: 'Unequip that weapon first.', weapon_limit: 'You cannot carry more weapons.', no_weapon: 'No such weapon.',
    offhand_holster: 'You need an off-hand holster for a second sidearm.', not_sidearm: 'Only revolvers, pistols and the sawed-off go on the hip.',
    no_cleaning_item: 'You have nothing to clean it with.', ammo_full: 'Your gunbelt is full.',
    no_permission: 'You may not do that here.', blacklisted: 'That does not go in there.', not_allowed: 'Not allowed in there.',
    bad_name: 'Give it a name.', outfit_limit: 'Too many saved outfits.', nothing_worn: 'You are not wearing anything.',
    no_outfit: 'That outfit is gone.', no_pieces: 'Pick some pieces first.', search_none: 'Nobody close enough.', no_horse: 'No horse nearby.',
    money_disabled: 'Cash cannot be moved right now.', player_offline: 'They are not here.', no_character: 'Your character is still loading.',
    bad_op: 'Not available.',
    missing: 'You are missing something for that.', busy: 'You are already making something.', cannot_now: 'Not right now.',
    unknown_recipe: 'That cannot be made.', recipe_unknown: 'You do not know how to make that.', skill_low: 'You are not skilled enough.',
    disabled: 'Hand crafting is off.', moved: 'You moved away.', too_fast: 'Too quick.', bad_token: 'That craft is gone.', not_busy: 'Nothing in hand.'
  };
  // codes the server (or the owning part) already reports with its own notify: never toast twice
  var SELF_NOTIFY = {
    '*': { weight: 1, limit: 1, slots: 1, locked: 1, weapon_equipped: 1 },
    equip: { clothing_gender: 1, clothing_conflict: 1, clothing_requires: 1, clothing_required_by: 1, clothing_contract: 1, clothing_only: 1, not_clothing: 1 },
    unequip: { clothing_gender: 1, clothing_conflict: 1, clothing_requires: 1, clothing_required_by: 1, clothing_contract: 1, clothing_only: 1, not_clothing: 1 },
    weaponClean: { no_cleaning_item: 1, no_weapon: 1 },
    weaponEquip: { offhand_holster: 1 },
    saddlebag: { no_mount: 1 }
  };
  function selfNotified(action, e) { return !!(SELF_NOTIFY['*'][e] || (SELF_NOTIFY[action] && SELF_NOTIFY[action][e])); }
  var RARITY = { 1: 'Common', 2: 'Uncommon', 3: 'Rare', 4: 'Epic', 5: 'Legendary' };
  var QUALITY = { poor: 1, standard: 2, fine: 3, masterwork: 4 };
  var PANELS = [['head', 'Head'], ['torso', 'Torso'], ['hands', 'Hands'], ['waist', 'Waist'], ['legs', 'Legs'], ['feet', 'Feet'], ['other', 'Other']];
  var DEFAULT_CATS = [
    [1, 'Hat', 'clothing_hat', 'head', 'Hat'], [2, 'EyeWear', 'clothing_eyewear', 'head', 'Eyewear'], [3, 'Mask', 'clothing_mask', 'head', 'Mask'],
    [4, 'NeckWear', 'clothing_neckwear', 'head', 'Neckwear'], [5, 'NeckTies', 'clothing_necktie', 'head', 'Necktie'], [6, 'Bow', 'clothing_hair_accessory', 'head', 'Hair accessory'],
    [7, 'Shirt', 'clothing_shirt', 'torso', 'Shirt'], [8, 'Vest', 'clothing_vest', 'torso', 'Vest'], [9, 'Coat', 'clothing_coat', 'torso', 'Coat (open)'],
    [10, 'CoatClosed', 'clothing_coat_closed', 'torso', 'Coat (closed)'], [11, 'Poncho', 'clothing_poncho', 'torso', 'Poncho'], [12, 'Cloak', 'clothing_cloak', 'torso', 'Cloak'],
    [13, 'Suspender', 'clothing_suspenders', 'torso', 'Suspenders'], [14, 'Dress', 'clothing_dress', 'torso', 'Dress'], [15, 'Armor', 'clothing_armor', 'torso', 'Armour'],
    [16, 'Badge', 'clothing_badge', 'torso', 'Badge'], [17, 'Glove', 'clothing_gloves', 'hands', 'Gloves'], [18, 'Gauntlets', 'clothing_gauntlets', 'hands', 'Gauntlets'],
    [19, 'RingRh', 'clothing_ring_right', 'hands', 'Ring (right)'], [20, 'RingLh', 'clothing_ring_left', 'hands', 'Ring (left)'], [21, 'Bracelet', 'clothing_bracelet', 'hands', 'Bracelet'],
    [22, 'Gunbelt', 'clothing_gunbelt', 'waist', 'Gunbelt'], [23, 'Holster', 'clothing_holster', 'waist', 'Holster'], [24, 'GunbeltAccs', 'clothing_gunbelt_accessory', 'waist', 'Gunbelt accessory'],
    [25, 'Belt', 'clothing_belt', 'waist', 'Belt'], [26, 'Buckle', 'clothing_buckle', 'waist', 'Buckle'], [27, 'Satchels', 'clothing_satchel', 'waist', 'Satchel'],
    [28, 'Loadouts', 'clothing_loadout', 'waist', 'Loadout (bandolier)'], [29, 'Pant', 'clothing_pants', 'legs', 'Trousers'], [30, 'Skirt', 'clothing_skirt', 'legs', 'Skirt'],
    [31, 'Chap', 'clothing_chaps', 'legs', 'Chaps'], [32, 'Boots', 'clothing_boots', 'feet', 'Boots'], [33, 'Spats', 'clothing_spats', 'feet', 'Spats'],
    [34, 'Spurs', 'clothing_spurs', 'feet', 'Spurs'], [35, 'Accessories', 'clothing_accessory', 'other', 'Accessory']
  ].map(function (c) { return { order: c[0], key: c[1], item: c[2], panel: c[3], label: c[4] }; });

  // ---------------------------------------------------------------- state
  var S = {
    open: false,
    setup: { categories: DEFAULT_CATS, saddleButton: false, mounted: false, dropMode: 'world', confirmDelete: true, hotbarSlots: 5, locale: {} },
    config: { slots: 40, hotbarSlots: 5, dropMode: 'world', confirmDelete: true, imagePath: 'nui://MULTIimages/images/%s.png', imageFallback: 'nui://MULTIinventory/html/img/ui/missing.png', showCurrency: { cash: true, gold: true }, money: null },
    groups: [], groupsById: {}, groupsByKey: {},
    cats: [], catsByItem: {}, catsByKey: {}, catsBySlot: {},
    views: { player: null, equip: null, secondary: null },
    secondaryLabel: null,
    idToRef: {},
    hotbar: [], currency: { cash: 0, gold: 0 }, weight: { current: 0, max: 0 }, ammo: null,
    tab: 'all', search: '',
    tiles: { player: {}, secondary: {}, equip: {}, hotbar: {} },
    focus: null, kbMode: false, hover: null,
    carry: null, ctx: null, modal: null, drag: null,
    failedImg: {}, equipCollapsed: false, scale: 1,
    conflicts: {}, requires: {}, secInfo: null, secPage: 0, secId: null,
    craft: { list: null, sel: null, qty: 1, loading: false, timer: null, seq: 0 }
  };
  var SEC_PAGE = 50; // secondary grid page size (housing stashes can have 1000 slots)

  // ---------------------------------------------------------------- helpers
  var $ = function (id) { return document.getElementById(id); };
  // event target as an Element (text nodes / document never reach .closest)
  var NOEL = { closest: function () { return null; } };
  function tgtEl(e) { var t = e && e.target; if (t && t.nodeType === 3) t = t.parentElement; return t && typeof t.closest === 'function' ? t : NOEL; }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function T(key, vars) {
    var loc = S.setup.locale || {};
    var s = loc['ui_' + key] || UI[key] || key;
    if (vars) s = s.replace(/\{(\w+)\}/g, function (m, k) { return vars[k] != null ? vars[k] : m; });
    return s;
  }
  function errText(e) { var loc = S.setup.locale || {}; return loc['ui_err_' + e] || ERR[e] || (e ? String(e).replace(/_/g, ' ') : ERR.nui_error); }
  function num(n, d) { n = Number(n) || 0; return n.toFixed(d == null ? 2 : d); }
  function kg(n) { n = Number(n) || 0; var r = Math.round(n * 100) / 100; return (r % 1 === 0 ? r.toFixed(0) : String(r)) + ' kg'; }
  function titleCase(s) { return String(s || '').replace(/_/g, ' ').replace(/\b\w/g, function (c) { return c.toUpperCase(); }); }
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function fmtDate(sec) { var d = new Date(Number(sec) * 1000); if (isNaN(d.getTime())) return ''; return d.getDate() + ' ' + MONTHS[d.getMonth()] + ' ' + d.getFullYear(); }
  function fmtLeft(sec) {
    sec = Math.max(0, Math.floor(sec));
    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
    if (d > 0) return d + 'd ' + h + 'h'; if (h > 0) return h + 'h ' + m + 'm'; if (m > 0) return m + 'm'; return sec + 's';
  }
  function meta(it) { return (it && it.metadata && typeof it.metadata === 'object' && !Array.isArray(it.metadata)) ? it.metadata : {}; }
  function label(it) { var m = meta(it); return m.label || it.label || it.name; }
  function isWeapon(it) { return it && it.kind === 'weapon'; }
  function weaponEquipped(it) { var m = meta(it); return !!(it.equipped || it.used || m.equipped || m.used); }
  // sidearms: revolvers + pistols + the sawed-off go on the hips (1 = right hip, 2 = left hip / off-hand)
  // [inv_sawnoff] the server sends metadata.sidearm; the group check is the fallback for old payloads
  function isSidearm(it) {
    if (!isWeapon(it)) return false;
    var m = meta(it);
    if (typeof m.sidearm === 'boolean') return m.sidearm;
    var g = String(m.weaponGroup || it.weaponGroup || '').toLowerCase();
    return g === 'revolver' || g === 'pistol' || String(it.item || it.name || '').toUpperCase().indexOf('SAWEDOFF') !== -1;
  }
  function weaponHip(it) { var m = meta(it), e = m.equipped || it.equipped; return e === 'left' || e === 'right' || e === 'extra' ? e : null; }
  function hipLabel(hip) { return hip === 'left' ? T('hipLeft') : hip === 'extra' ? T('hipExtra') : T('hipRight'); }
  // holster tiles: 1 = right hip, 2 = left hip (off-hand), 3 = extra holster (third sidearm, not on the ped)
  function hipKeyOf(n) { n = Number(n); return n === 2 ? 'left' : n === 3 ? 'extra' : 'right'; }
  function holsterItem(n) {
    var v = S.views.player, want = hipKeyOf(n);
    if (!v) return null;
    for (var k in v.items) { var x = v.items[k]; if (isWeapon(x) && weaponHip(x) === want) return x; }
    return null;
  }
  function catForItem(it) {
    if (!it) return null;
    var c = S.catsByItem[it.name];
    if (c) return c;
    var m = meta(it);
    if (m.cv && m.category && S.catsByKey[m.category]) return S.catsByKey[m.category];
    return null;
  }
  function itemCount(it) { return Math.max(1, Number(it.count || it.amount || 1)); }
  // money as items (Config.Money): the wallet is what the player grid holds
  function moneyCfg() { var m = S.config.money; return m && m.enabled ? m : null; }
  function moneyUnit(it) { var m = moneyCfg(); if (!m || !it || isWeapon(it)) return 0; return it.name === m.dollarItem ? 100 : it.name === m.centItem ? 1 : 0; }
  function isMoneyItem(it) { return moneyUnit(it) > 0; }
  function walletCents() {
    var v = S.views.player, n = 0; if (!moneyCfg() || !v) return 0;
    Object.keys(v.items).forEach(function (k) { var x = v.items[k]; n += moneyUnit(x) * (x ? itemCount(x) : 0); });
    return n;
  }
  function fmtCents(c) { c = Math.max(0, Math.floor(Number(c) || 0)); return Math.floor(c / 100) + '.' + ('0' + (c % 100)).slice(-2); }

  // ---------------------------------------------------------------- transport
  function post(action, data) {
    if (!IN_GAME) {
      if (window.InvMock && typeof window.InvMock.handle === 'function') return Promise.resolve(window.InvMock.handle(action, data || {}));
      return Promise.resolve({ ok: false, err: 'not_ready' });
    }
    return fetch('https://' + RES + '/' + action, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {})
    }).then(function (r) { return r.json(); }).then(function (r) { return r || { ok: false, err: 'nui_error' }; })
      .catch(function () { return { ok: false, err: 'nui_error' }; });
  }
  function act(action, data) {
    return post(action, data).then(function (r) {
      if (!r || !r.ok) { var e = r && r.err; if (!selfNotified(action, e)) toast(errText(e), 'bad'); }
      return r || { ok: false };
    });
  }

  // ---------------------------------------------------------------- images
  function imgBase(it) {
    var img = meta(it).image || it.image || (it.name + '.png');
    return String(img);
  }
  function imgSrc(it) {
    var img = imgBase(it);
    if (/^(data:|https?:|nui:)/.test(img) || img.indexOf('/') !== -1) {
      // live picture URL (Registry.setImage / RINGOjobtools) that failed once: try this resource's own file
      if (!S.failedImg[img.replace(/\.(png|webp|jpe?g|gif)$/i, '')] || !it.name) return img;
      img = it.name + '.png';
    }
    var base = img.replace(/\.(png|webp|jpe?g|gif)$/i, '');
    if (S.failedImg[base]) return S.config.imageFallback || 'img/ui/missing.png';
    var p = S.config.imagePath || 'img/items/%s.png';
    return p.indexOf('%s') !== -1 ? p.replace('%s', base) : p + img;
  }
  function imgTag(it) {
    var base = imgBase(it).replace(/\.(png|webp|jpe?g|gif)$/i, '');
    return '<img loading="lazy" draggable="false" alt="" data-base="' + esc(base) + '" src="' + esc(imgSrc(it)) + '">';
  }
  document.addEventListener('error', function (e) {
    var img = e.target;
    if (!img || img.tagName !== 'IMG') return;
    var stage = img.dataset.fb || '0';
    if (stage === '0') {
      if (img.dataset.base) S.failedImg[img.dataset.base] = true;
      img.dataset.fb = '1';
      var fb = S.config.imageFallback || 'img/ui/missing.png';
      if (img.getAttribute('src') !== fb) { img.src = fb; return; }
    }
    if (stage !== '2') { img.dataset.fb = '2'; img.src = 'img/ui/missing.png'; return; }
    img.style.visibility = 'hidden';
  }, true);

  // ---------------------------------------------------------------- scale
  function rescale() {
    var s = Math.min(window.innerWidth / 1600, window.innerHeight / 900);
    // --ui-zoom from html/fonts.css (customer setting, 1 = normal) scales the whole window
    var z = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--ui-zoom'));
    if (!(z > 0)) z = 1;
    S.scale = Math.max(0.4, s) * z;
    document.documentElement.style.setProperty('--s', S.scale);
  }
  window.addEventListener('resize', rescale);
  rescale();

  // ---------------------------------------------------------------- data intake
  function toView(v) {
    if (!v) return null;
    var items = {};
    (v.items || []).forEach(function (it) { if (it && it.slot != null) items[it.slot] = it; });
    return { id: v.id, kind: v.kind, label: v.label, slots: Number(v.slots) || 0, weight: v.weight, maxWeight: v.maxWeight, items: items };
  }
  function setGroups(list) {
    S.groups = Array.isArray(list) ? list : [];
    S.groupsById = {}; S.groupsByKey = {};
    S.groups.forEach(function (g) { S.groupsById[g.id] = g; S.groupsByKey[g.key] = g; });
  }
  function setCats(list) {
    S.cats = (Array.isArray(list) && list.length ? list : DEFAULT_CATS).slice().sort(function (a, b) { return a.order - b.order; });
    S.catsByItem = {}; S.catsByKey = {}; S.catsBySlot = {};
    S.cats.forEach(function (c) { S.catsByItem[c.item] = c; S.catsByKey[c.key] = c; S.catsBySlot[c.order] = c; });
  }
  setCats(DEFAULT_CATS);
  function catSig(list) {
    if (!Array.isArray(list) || !list.length) list = DEFAULT_CATS;
    return list.map(function (c) { return [Number(c.order), c.key, c.item, c.panel, c.label].join('\u0001'); }).sort().join('\u0002');
  }

  function onOpen(d) {
    d = d || {};
    if (d.config) Object.keys(d.config).forEach(function (k) { if (d.config[k] != null) S.config[k] = d.config[k]; });
    setGroups(d.groups);
    S.views.player = toView(d.player);
    S.views.equip = toView(d.equipment);
    S.views.secondary = toView(d.secondary);
    S.secondaryLabel = d.secondaryLabel || null;
    S.idToRef = {};
    ['player', 'equip', 'secondary'].forEach(function (r) { if (S.views[r]) S.idToRef[S.views[r].id] = r; });
    S.hotbar = Array.isArray(d.hotbar) ? d.hotbar : [];
    S.currency = d.currency || { cash: 0, gold: 0 };
    S.weight = d.weight || { current: S.views.player ? S.views.player.weight : 0, max: S.views.player ? S.views.player.maxWeight : 0 };
    S.ammo = d.gunbelt || d.ammo || null;
    // clothing part: slot list (labels, panels) + rules for pre-colouring drops
    if (d.clothing && Array.isArray(d.clothing.slots) && d.clothing.slots.length) {
      setCats(d.clothing.slots.map(function (s) { return { order: Number(s.slot), key: s.key, item: s.item, label: s.label, panel: s.panel }; }));
    }
    S.conflicts = (d.clothing && d.clothing.conflicts) || {};
    S.requires = (d.clothing && d.clothing.requires) || {};
    // secondary part: { id, kind, perCharacter, shared, acceptWeapons, viewers, countLimit }
    S.secInfo = d.secondaryInfo || null;
    if (!S.views.secondary || S.secId !== S.views.secondary.id) S.secPage = 0;
    S.secId = S.views.secondary ? S.views.secondary.id : null;
    if (S.tab !== 'all' && !S.groupsByKey[S.tab] && S.tab !== '_clothing' && !(S.tab === '_craft' && craftOn())) S.tab = 'all';
    S.carry = null; S.focus = null;
    S.craft.list = null;
    renderAll();
    applyCraftMode();
    showApp();
  }

  function onDelta(d) {
    if (!d) return;
    var ref = S.idToRef[d.container];
    if (!ref) return;
    var v = S.views[ref];
    (d.slots || []).forEach(function (s) {
      if (s.item) { s.item.slot = s.slot; v.items[s.slot] = s.item; } else delete v.items[s.slot];
      paintSlot(ref, s.slot, true);
    });
    if (d.weight != null) v.weight = d.weight;
    if (d.maxWeight !== undefined) v.maxWeight = d.maxWeight;
    if (ref === 'player') {
      S.weight = { current: Number(d.weight) || 0, max: d.maxWeight != null ? d.maxWeight : S.weight.max };
      renderHeader(); renderHotbar(); paintAll('player'); paintAll('holster');
      if (S.tab === '_craft') scheduleCraftLoad();
    }
    if (ref === 'secondary') renderSecMeta();
    if (ref === 'equip') renderEquipStrip();
    renderTabs();
    renderCounts();
    if (S.focus) applyFocus();
  }

  // ---------------------------------------------------------------- render: shell
  function showApp() {
    rescale();
    S.open = true;
    document.body.classList.add('open');
    var app = $('app');
    app.classList.remove('hidden');
    var f = $('frame'); f.classList.remove('stamp'); void f.offsetWidth; f.classList.add('stamp');
  }
  function hideApp() {
    S.open = false;
    document.body.classList.remove('open', 'dragging');
    $('app').classList.add('hidden');
    hideTip(); closeCtx(); closeModal(null); cancelDrag();
    S.carry = null; S.focus = null; S.kbMode = false;
    var si = $('search'); if (si) si.blur();
  }
  function requestClose() { hideApp(); post('close', {}); }

  function applyStrings() {
    document.querySelectorAll('[data-t]').forEach(function (el) { el.textContent = T(el.dataset.t); });
    $('search').placeholder = T('search');
  }

  function renderAll() {
    applyStrings();
    renderHeader();
    renderSecondary();
    buildGrid('player', $('gridPlayer'), 1, S.views.player ? S.views.player.slots || S.config.slots : S.config.slots);
    renderEquip();
    renderHotbar();
    renderTabs();
    renderCounts();
    renderAmmo();
    $('zoneDropLabel').textContent = (S.config.dropMode || S.setup.dropMode) === 'delete' ? T('destroy') : T('drop');
  }

  function renderHeader() {
    var sc = S.config.showCurrency || {};
    $('cashBox').classList.toggle('hidden', sc.cash === false);
    $('goldBox').classList.toggle('hidden', sc.gold === false);
    var mc = moneyCfg();
    $('cash').textContent = '$ ' + (mc ? fmtCents(walletCents()) : num(S.currency.cash));
    $('cashBox').style.cursor = mc ? 'pointer' : '';
    $('cashBox').title = mc ? T('cashMenu') : 'Cash';
    $('gold').textContent = num(S.currency.gold);
    var cur = Number(S.weight.current) || 0, max = Number(S.weight.max) || 0;
    var pct = max > 0 ? cur / max * 100 : 0;
    var bar = $('weightBar');
    bar.style.width = Math.min(100, pct) + '%';
    bar.className = pct >= 95 ? 'bad' : pct >= 75 ? 'warn' : '';
    $('weightText').textContent = num(cur, 1) + ' / ' + (max > 0 ? num(max, 1) : '-') + ' kg';
    $('overWarn').classList.toggle('hidden', !(max > 0 && cur > max));
    // shown whenever enabled; client/secondary.lua finds the (last) mount and reports "no horse"
    $('saddleBtn').classList.toggle('hidden', !(S.config.saddleButton || S.setup.saddleButton));
  }

  function secKindLabel(v) {
    var k = String(v.kind || '').toLowerCase(), id = String(v.id || '');
    if (k === 'saddlebag' || k === 'horse' || /saddle|bag/i.test(k)) return T('saddlebags');
    if (k === 'trunk' || k === 'wagon') return T('trunk');
    if (k === 'business') return T('business');
    if (k === 'player' || /^player:/.test(id)) return T('searching');
    if (k === 'drop' || /^drop:/.test(id)) return T('ground');
    return T('storage');
  }
  function renderSecondary() {
    var v = S.views.secondary;
    $('paneSec').classList.toggle('hidden', !v);
    if (!v) { S.tiles.secondary = {}; $('gridSec').innerHTML = ''; return; }
    $('secKind').textContent = secKindLabel(v).toUpperCase();
    $('secLabel').textContent = S.secondaryLabel || v.label || v.id;
    renderSecPage();
  }
  function secPages() { var v = S.views.secondary; return v ? Math.max(1, Math.ceil((v.slots || 1) / SEC_PAGE)) : 1; }
  function renderSecPage() {
    var v = S.views.secondary; if (!v) return;
    S.secPage = Math.max(0, Math.min(secPages() - 1, S.secPage || 0));
    var from = S.secPage * SEC_PAGE + 1, to = Math.min(v.slots || 20, from + SEC_PAGE - 1);
    buildGrid('secondary', $('gridSec'), from, to);
    $('gridSec').scrollTop = 0;
    renderSecMeta();
    if (S.focus && S.focus.pane === 'secondary') applyFocus();
  }
  function setSecPage(p) {
    if (!S.views.secondary) return;
    var np = Math.max(0, Math.min(secPages() - 1, p));
    if (np === S.secPage) return;
    S.secPage = np; hideTip(); renderSecPage();
  }
  function renderPager() {
    var host = $('secPager'), n = secPages(), v = S.views.secondary;
    if (!v || n <= 1) { host.classList.add('hidden'); host.innerHTML = ''; return; }
    host.classList.remove('hidden');
    var filled = {}, match = {};
    Object.keys(v.items).forEach(function (k) {
      var p = Math.floor((Number(k) - 1) / SEC_PAGE); filled[p] = true;
      if ((S.search || S.tab !== 'all') && visible(v.items[k])) match[p] = true;
    });
    var cur = S.secPage, want = {};
    // first/last page, a window around the current page, and up to 4 pages with filter/search matches
    // (1000 slots = 20 pages; only the current page has DOM tiles)
    var lo = Math.max(0, Math.min(cur - 2, n - 5)), hi = Math.min(n - 1, lo + 4);
    want[0] = true; want[n - 1] = true;
    for (var i = lo; i <= hi; i++) want[i] = true;
    Object.keys(match).map(Number).sort(function (a, b) { return a - b; }).slice(0, 4).forEach(function (p) { want[p] = true; });
    var pagesList = Object.keys(want).map(Number).sort(function (a, b) { return a - b; });
    var h = '<button class="pg" data-page="' + (cur - 1) + '"' + (cur === 0 ? ' disabled' : '') + '>&lsaquo;</button>';
    var prev = -1;
    pagesList.forEach(function (p) {
      if (prev >= 0 && p > prev + 1) h += '<span class="gap">…</span>';
      h += '<button class="pg' + (p === cur ? ' on' : '') + (filled[p] ? ' filled' : '') + (match[p] ? ' match' : '') + '" data-page="' + p + '">' + (p + 1) + '</button>';
      prev = p;
    });
    h += '<button class="pg" data-page="' + (cur + 1) + '"' + (cur >= n - 1 ? ' disabled' : '') + '>&rsaquo;</button>';
    host.innerHTML = h;
  }
  $('secPager').addEventListener('click', function (e) {
    var b = tgtEl(e).closest('button[data-page]'); if (!b || b.disabled) return;
    setSecPage(Number(b.dataset.page));
  });
  function renderSecMeta() {
    var v = S.views.secondary; if (!v) return;
    var used = Object.keys(v.items).length;
    var info = S.secInfo, bits = [];
    if (info && info.shared) bits.push(T('shared'));
    if (info && Number(info.viewers) > 1) bits.push(T('viewers', { n: info.viewers }));
    if (info && info.countLimit) bits.push(T('countLimit', { n: info.countLimit }));
    if (info && info.acceptWeapons === false) bits.push(T('weaponsNo'));
    $('secInfo').textContent = bits.join(' · ');
    $('secInfo').classList.toggle('hidden', !bits.length);
    renderPager();
    $('secSlots').textContent = T('secSlots') + ' ' + used + ' / ' + v.slots;
    var hasMax = v.maxWeight != null && Number(v.maxWeight) > 0;
    $('secWeightText').textContent = hasMax ? num(v.weight, 1) + ' / ' + num(v.maxWeight, 1) + ' kg' : num(v.weight || 0, 1) + ' kg · ' + T('unlimited');
    var pct = hasMax ? (Number(v.weight) || 0) / Number(v.maxWeight) * 100 : used / Math.max(1, v.slots) * 100;
    var bar = $('secWeightBar');
    bar.style.width = Math.min(100, pct) + '%';
    bar.className = pct >= 95 ? 'bad' : pct >= 75 ? 'warn' : '';
  }
  function renderCounts() {
    var v = S.views.player;
    if (v) $('playerSlots').textContent = T('secSlots') + ' ' + Object.keys(v.items).length + ' / ' + v.slots;
  }

  // ---------------------------------------------------------------- tabs / filter
  function inTab(it, tab) {
    if (tab === 'all') return true;
    if (tab === '_clothing') return !!catForItem(it);
    var g = S.groupsByKey[tab];
    if (!g) return true;
    if (g.key === 'weapons' && isWeapon(it)) return true;
    if (it.group === g.id || it.groupName === g.key) return true;
    var ig = S.groupsById[it.group] || S.groupsByKey[it.groupName];
    return !!(ig && ig.parent === g.key);
  }
  function inSearch(it) {
    var q = S.search;
    if (!q) return true;
    var m = meta(it);
    var hay = (label(it) + ' ' + it.name + ' ' + (m.description || it.description || it.desc || '') + ' ' + (m.maker || '')).toLowerCase();
    return hay.indexOf(q) !== -1;
  }
  function visible(it) { return inTab(it, S.tab) && inSearch(it); }

  function renderTabs() {
    var all = [];
    ['player', 'secondary'].forEach(function (r) { var v = S.views[r]; if (v) Object.keys(v.items).forEach(function (k) { all.push(v.items[k]); }); });
    var tabs = [{ key: 'all', label: T('all'), n: all.length }];
    if (craftOn()) tabs.push({ key: '_craft', label: T('craft'), n: S.craft.list ? craftReadyCount() : '', cls: 'craft-tab' });
    S.groups.forEach(function (g) {
      if (g.hidden) return;
      var n = all.filter(function (it) { return inTab(it, g.key); }).length;
      if (n > 0 || S.tab === g.key) tabs.push({ key: g.key, label: g.label || titleCase(g.key), n: n });
    });
    var nc = all.filter(function (it) { return !!catForItem(it); }).length;
    if (nc > 0 || S.tab === '_clothing') tabs.push({ key: '_clothing', label: T('clothing'), n: nc });
    var html = tabs.map(function (t) {
      return '<button class="tab' + (t.cls ? ' ' + t.cls : '') + (t.key === S.tab ? ' active' : '') + '" data-tab="' + esc(t.key) + '">' + esc(t.label) + '<i>' + esc(t.n) + '</i></button>';
    }).join('');
    var nav = $('tabs');
    if (nav.innerHTML !== html) nav.innerHTML = html;
  }
  $('tabs').addEventListener('click', function (e) {
    var b = tgtEl(e).closest('.tab'); if (!b) return;
    S.tab = b.dataset.tab; renderTabs(); paintAll('player'); paintAll('secondary'); renderPager();
    applyCraftMode();
  });
  $('tabs').addEventListener('wheel', function (e) { if (e.deltaY) { this.scrollLeft += e.deltaY; e.preventDefault(); } }, { passive: false });
  $('search').addEventListener('input', function () { S.search = this.value.trim().toLowerCase(); paintAll('player'); paintAll('secondary'); renderPager(); if (S.tab === '_craft') renderCraft(); });

  // ---------------------------------------------------------------- tiles
  function hotkeyOf(it) {
    if (!it) return null;
    for (var i = 0; i < S.hotbar.length; i++) {
      var h = S.hotbar[i];
      if (isWeapon(it)) { if (h.kind === 'weapon' && Number(h.ref) === Number(it.weaponId || it.id)) return h.slot; }
      else if (h.kind !== 'weapon' && Number(h.ref) === Number(it.id)) return h.slot;
    }
    return null;
  }
  function durOf(it) {
    var m = meta(it);
    if (typeof m.durability === 'number') return m.durability;
    if (typeof it.percentage === 'number') return it.percentage;
    return null;
  }
  function tileInner(it, opts) {
    opts = opts || {};
    if (!it) return '<div class="in">' + (opts.emptyLabel ? '<span class="elbl">' + esc(opts.emptyLabel) + '</span>' : '') + '</div>';
    var m = meta(it), h = '<div class="in"><div class="rar"></div>' + imgTag(it);
    var q = QUALITY[String(m.quality || '').toLowerCase()];
    if (q) { h += '<span class="q ' + esc(String(m.quality).toLowerCase()) + '">'; for (var i = 0; i < q; i++) h += '<b></b>'; h += '</span>'; }
    if (opts.hk) h += '<span class="hk">' + opts.hk + '</span>';
    if (isWeapon(it) && weaponEquipped(it)) h += '<svg class="lock"><use href="#icon-lock"></use></svg>';
    var hip = isWeapon(it) && !opts.noHip ? weaponHip(it) : null;
    if (hip) h += '<span class="hip" title="' + esc(hipLabel(hip)) + '">' + (hip === 'left' ? 'L' : hip === 'extra' ? '3' : 'R') + '</span>';
    if (!opts.noName) h += '<span class="nm">' + esc(label(it)) + '</span>';
    var c = opts.count != null ? opts.count : itemCount(it);
    if (!isWeapon(it) && c > 1) h += '<span class="cnt">' + c + '</span>';
    // [thrown] a throwable stack shows how many are left to throw
    else if (isWeapon(it) && m.stack != null && Number(m.stack) > 0) h += '<span class="cnt">' + esc(m.stack) + '</span>';
    var d = durOf(it);
    if (d != null) h += '<span class="dur"><i class="' + (d > 50 ? '' : d > 20 ? 'warn' : 'bad') + '" style="width:' + Math.max(0, Math.min(100, d)) + '%"></i></span>';
    return h + '</div>';
  }
  function makeTile(ref, slot, extraCls) {
    var el = document.createElement('div');
    el.className = 'tile' + (extraCls ? ' ' + extraCls : '');
    el.dataset.ref = ref; el.dataset.slot = slot;
    return el;
  }
  function buildGrid(ref, host, from, to) {
    host.innerHTML = '';
    S.tiles[ref] = {};
    var frag = document.createDocumentFragment();
    for (var s = from; s <= to; s++) { var el = makeTile(ref, s); S.tiles[ref][s] = el; frag.appendChild(el); }
    host.appendChild(frag);
    paintAll(ref);
  }
  function paintAll(ref) { var t = S.tiles[ref]; if (!t) return; Object.keys(t).forEach(function (s) { paintSlot(ref, Number(s)); }); }
  function paintSlot(ref, slot, flash) {
    var el = S.tiles[ref] && S.tiles[ref][slot];
    if (!el) return;
    var v = S.views[ref], it = v && v.items[slot], html;
    if (ref === 'holster') {
      it = holsterItem(slot);
      html = tileInner(it, { emptyLabel: hipLabel(hipKeyOf(slot)), noName: true, noHip: true });
    } else if (ref === 'equip') {
      var cat = S.catsBySlot[slot];
      html = tileInner(it, { emptyLabel: cat ? cat.label : '', noName: true });
    } else {
      html = tileInner(it, { hk: ref === 'player' ? hotkeyOf(it) : null });
    }
    // unchanged slot: keep its DOM (no new <img>, no re-decode, no repaint)
    if (el._html !== html) { el.innerHTML = html; el._html = html; }
    el.classList.toggle('has', !!it);
    el.classList.toggle('expired', !!(it && it.expired));
    if (it) el.dataset.rar = it.rarity || 1; else delete el.dataset.rar;
    el.classList.toggle('dim', !!(it && ref !== 'equip' && ref !== 'holster' && !visible(it)));
    if (flash && it) { el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash'); }
  }

  // ---------------------------------------------------------------- equipment
  function renderEquip() {
    var host = $('equipGroups');
    host.innerHTML = '';
    S.tiles.equip = {};
    // sidearm holsters: right hip + left hip (off-hand, dual wield). Tiles show the equipped weapon of
    // the player grid; drag a revolver/pistol here to equip it on that hip, drag it out to unequip.
    S.tiles.holster = {};
    var hg = document.createElement('div'); hg.className = 'egroup egroup-holsters';
    hg.innerHTML = '<span class="kicker">' + esc(T('sidearms')) + '</span><div class="eslots"></div>';
    [1, 2, 3].forEach(function (n) {
      if (n === 2 && !S.setup.dualWield && !holsterItem(2)) return;
      if (n === 3 && !S.setup.extraSidearm && !holsterItem(3)) return;
      var el = makeTile('holster', n, 'eslot hslot-hip'); el.dataset.key = hipKeyOf(n);
      S.tiles.holster[n] = el; hg.querySelector('.eslots').appendChild(el);
    });
    host.appendChild(hg);
    paintAll('holster');
    PANELS.forEach(function (p) {
      var cats = S.cats.filter(function (c) { return (c.panel || 'other') === p[0]; });
      if (!cats.length) return;
      var g = document.createElement('div'); g.className = 'egroup';
      g.innerHTML = '<span class="kicker">' + esc(p[1]) + '</span><div class="eslots"></div>';
      var row = g.querySelector('.eslots');
      cats.forEach(function (c) {
        var el = makeTile('equip', c.order, 'eslot'); el.dataset.key = c.key;
        S.tiles.equip[c.order] = el; row.appendChild(el);
      });
      host.appendChild(g);
    });
    // categories the panel list does not know
    var known = {}; PANELS.forEach(function (p) { known[p[0]] = 1; });
    var odd = S.cats.filter(function (c) { return !known[c.panel || 'other']; });
    if (odd.length) {
      var g2 = document.createElement('div'); g2.className = 'egroup';
      g2.innerHTML = '<span class="kicker">More</span><div class="eslots"></div>';
      odd.forEach(function (c) { var el = makeTile('equip', c.order, 'eslot'); el.dataset.key = c.key; S.tiles.equip[c.order] = el; g2.querySelector('.eslots').appendChild(el); });
      host.appendChild(g2);
    }
    paintAll('equip');
    $('paneEquip').classList.toggle('collapsed', S.equipCollapsed);
    renderEquipStrip();
  }
  function renderEquipStrip() {
    var v = S.views.equip, n = v ? Object.keys(v.items).length : 0;
    $('equipStrip').innerHTML = '<b>' + n + '</b><span>' + esc(T('worn2')) + '</span>';
  }
  $('equipToggle').addEventListener('click', function () {
    S.equipCollapsed = !S.equipCollapsed;
    $('paneEquip').classList.toggle('collapsed', S.equipCollapsed);
    try { localStorage.setItem('multiinv_equip_collapsed', S.equipCollapsed ? '1' : '0'); } catch (e) { /* storage blocked */ }
  });
  try { S.equipCollapsed = localStorage.getItem('multiinv_equip_collapsed') === '1'; } catch (e) { /* storage blocked */ }

  // ---------------------------------------------------------------- hotbar / ammo
  function hotbarItem(n) {
    var h = null;
    for (var i = 0; i < S.hotbar.length; i++) if (Number(S.hotbar[i].slot) === n) h = S.hotbar[i];
    if (!h) return { h: null, it: null };
    var v = S.views.player, it = null, k;
    if (v) {
      for (k in v.items) {
        var x = v.items[k];
        if (h.kind === 'weapon' ? (isWeapon(x) && Number(x.weaponId || x.id) === Number(h.ref)) : (!isWeapon(x) && Number(x.id) === Number(h.ref))) { it = x; break; }
      }
      if (!it && h.kind !== 'weapon' && h.item) for (k in v.items) if (v.items[k].name === h.item && !isWeapon(v.items[k])) { it = v.items[k]; break; }
    }
    return { h: h, it: it };
  }
  function hotbarCount(h) {
    if (!h) return 0;
    if (h.kind === 'weapon') return hotbarItem(Number(h.slot)).it ? 1 : 0;
    var v = S.views.player, n = 0;
    if (v) Object.keys(v.items).forEach(function (k) { var x = v.items[k]; if (!isWeapon(x) && x.name === h.item) n += itemCount(x); });
    return n;
  }
  function renderHotbar() {
    var host = $('hotbar');
    var n = Number(S.config.hotbarSlots || S.setup.hotbarSlots || 5);
    host.innerHTML = '';
    S.tiles.hotbar = {};
    for (var i = 1; i <= n; i++) {
      var r = hotbarItem(i);
      var el = makeTile('hotbar', i, 'hslot');
      var it = r.it || (r.h ? { name: r.h.item, label: r.h.label, kind: r.h.kind, count: 0 } : null);
      if (it) {
        var c = hotbarCount(r.h);
        el.innerHTML = tileInner(it, { count: c });
        el.classList.add('has');
        el.dataset.rar = it.rarity || 1;
        if (!r.it) el.classList.add('ghosted');
      } else {
        el.innerHTML = '<div class="in"></div>';
        el.classList.add('empty');
      }
      var key = document.createElement('span'); key.className = 'key'; key.textContent = i; el.appendChild(key);
      S.tiles.hotbar[i] = el; host.appendChild(el);
    }
  }
  function renderAmmo() {
    var host = $('ammo'), a = S.ammo, list = [];
    if (Array.isArray(a)) list = a;
    else if (a && typeof a === 'object') list = Object.keys(a).map(function (k) { return { type: k, count: a[k] }; });
    list = list.filter(function (x) { return Number(x.count) > 0; });
    host.innerHTML = list.map(function (x) {
      var l = x.label || titleCase(String(x.type).replace(/^ammo_/i, ''));
      var full = x.max && Number(x.count) >= Number(x.max);
      return '<span class="rpill' + (full ? ' ok' : '') + '" title="' + esc(x.type) + '">' + esc(l) + '<b>' + Number(x.count) + (x.max ? '/' + Number(x.max) : '') + '</b></span>';
    }).join('');
  }

  // ---------------------------------------------------------------- tooltip
  function rows(list) {
    return list.filter(Boolean).map(function (r) { return '<div class="t-row"><span>' + esc(r[0]) + '</span><b class="' + (r[2] || '') + '">' + r[1] + '</b></div>'; }).join('');
  }
  function tipHTML(it, ref, opts) {
    opts = opts || {};
    var m = meta(it), r = Number(it.rarity) || 1;
    var g = S.groupsById[it.group] || S.groupsByKey[it.groupName];
    var cat = catForItem(it);
    var kick = cat ? T('clothing') : isWeapon(it) ? 'Weapon' : (g ? (g.label || titleCase(g.key)) : '');
    var h = '<div class="t-kick"><span class="kicker t-rar r' + r + '">' + esc(RARITY[r] || 'Common') + '</span><span class="kicker">' + esc(kick) + '</span></div>';
    h += '<h3>' + esc(label(it)) + '</h3>';
    var desc = m.description || it.description || it.desc;
    if (desc) h += '<p class="t-desc">' + esc(desc) + '</p>';
    var list = [];
    var unit = Number(it.weight) || 0, c = itemCount(it);
    if (ref === 'equip' && !S.config.wornCountsWeight) list.push([T('weight'), kg(unit) + ' (' + T('worn2').toLowerCase() + ', not carried)']);
    else list.push([T('weight'), c > 1 ? kg(unit) + ' × ' + c + ' = ' + kg(unit * c) : kg(unit)]);
    if (isMoneyItem(it)) list.push([T('value'), '$ ' + fmtCents(moneyUnit(it) * c), 'ok t-price']);
    if (m.quality || m.quality_label) list.push([T('quality'), esc(m.quality_label || titleCase(m.quality)), m.quality === 'masterwork' ? 'ok' : m.quality === 'poor' ? 'bad' : '']);
    var d = durOf(it);
    if (typeof m.durability === 'number') list.push([T('durability'), Math.round(m.durability) + '%', m.durability > 50 ? 'ok' : m.durability > 20 ? 'warn' : 'bad']);
    if (it.expired) list.push([T('spoiled'), '&#10007;', 'bad']);
    else if (it.decayAt) {
      var left = Number(it.decayAt) - Date.now() / 1000;
      list.push([T('spoils'), esc(fmtLeft(left)) + (typeof it.percentage === 'number' ? ' (' + Math.round(it.percentage) + '%)' : ''), d != null && d < 25 ? 'warn' : '']);
    }
    if (isWeapon(it)) {
      var serial = m.serial || m.serial_number || it.serial_number || it.serial;
      if (serial) list.push([T('serial'), esc(serial)]);
      var ammo = m.ammo != null ? m.ammo : it.ammo;
      if (ammo != null && typeof ammo !== 'object') list.push([T('ammoLoaded'), esc(ammo)]);
      else if (ammo && typeof ammo === 'object') Object.keys(ammo).forEach(function (k) { list.push([titleCase(k.replace(/^ammo_/i, '')), esc(ammo[k])]); });
      var comps = m.components || it.components;
      if (comps && typeof comps === 'object') {
        var names = Array.isArray(comps) ? comps : Object.keys(comps).map(function (k) { return typeof comps[k] === 'string' ? comps[k] : k; });
        if (names.length) list.push([T('components'), esc(names.slice(0, 4).map(titleCase).join(', ')) + (names.length > 4 ? ' +' + (names.length - 4) : '')]);
      }
      var cond = m.condition != null ? m.condition : m.degradation;
      if (cond != null && typeof cond !== 'object') list.push([T('condition'), esc(Math.round(Number(cond) * (Number(cond) <= 1 ? 100 : 1)) + '%')]);
      if (weaponEquipped(it)) list.push([T('equipped'), weaponHip(it) ? esc(hipLabel(weaponHip(it))) : '&#10003;', 'ok']);
    }
    if (cat) {
      list.push([T('category'), esc(cat.label)]);
      if (m.gender) list.push([T('cut'), esc(titleCase(m.gender))]);
      if (m.tint0 != null || m.tint1 != null || m.tint2 != null) {
        var sw = [m.tint0, m.tint1, m.tint2].map(function (t) {
          if (t == null) return '';
          var v = Math.max(0, Math.min(254, Number(t) || 0)), l = 22 + Math.round(v / 254 * 60);
          return '<span class="sw" style="background:hsl(0,0%,' + l + '%)">' + v + '</span>';
        }).join('');
        list.push([T('tints'), sw]);
      }
    }
    h += '<div class="t-rows">' + rows(list) + '</div>';
    if (m.maker || m.made_by) {
      var parts = [];
      if (m.maker) parts.push(esc(m.maker));
      if (m.made_by_label || m.business_label || m.made_by) parts.push(esc(m.made_by_label || m.business_label || titleCase(String(m.made_by).replace(/^[a-z]+_/, ''))));
      if (m.made_at) parts.push(esc(fmtDate(m.made_at)));
      h += '<div class="t-maker">' + esc(T('madeBy')) + ' ' + parts.join(', ') + (m.batch ? ' · ' + esc(T('batch')) + ' ' + esc(m.batch) : '') + '</div>';
    }
    var lines = m.tooltip;
    if (typeof lines === 'string') lines = lines.split('\n');
    if (Array.isArray(lines) && lines.length) h += '<ul class="t-lines">' + lines.map(function (l) { return '<li>' + esc(l) + '</li>'; }).join('') + '</ul>';
    if (!opts.noHint) h += '<div class="t-hint">' + esc(T('ctxHint')) + '</div>';
    return '<div class="plate-frame"><div class="plate"><div class="plate-body">' + h + '</div></div></div>';
  }
  function emptyEquipTipHTML(cat) {
    return '<div class="plate-frame"><div class="plate"><div class="plate-body"><div class="t-kick"><span class="kicker">' + esc(T('equipment')) + '</span></div><h3>' + esc(cat.label) + '</h3><p class="t-desc">' + esc(T('empty')) + '. ' + esc(T('emptySlotHint')) + '</p></div></div></div>';
  }
  function place(el, x, y, w, h) {
    var s = S.scale;
    var W = w * s, H = h * s;
    var nx = x + 18, ny = y + 14;
    if (nx + W > window.innerWidth - 8) nx = x - W - 14;
    if (ny + H > window.innerHeight - 8) ny = window.innerHeight - H - 8;
    nx = Math.max(8, nx); ny = Math.max(8, ny);
    el.style.transform = 'translate(' + Math.round(nx) + 'px,' + Math.round(ny) + 'px) scale(' + s + ')';
  }
  var tipTimer = null;
  function showTipFor(tile, x, y) {
    var ref = tile.dataset.ref, slot = Number(tile.dataset.slot);
    var it = itemAt(ref, slot), tip = $('tip'), html;
    if (it) html = tipHTML(it, ref);
    else if (ref === 'equip' && S.catsBySlot[slot]) html = emptyEquipTipHTML(S.catsBySlot[slot]);
    else { hideTip(); return; }
    tip.innerHTML = html;
    tip.classList.remove('hidden');
    if (x == null) { var r = tile.getBoundingClientRect(); x = r.right - 10; y = r.top; }
    place(tip, x, y, tip.offsetWidth, tip.offsetHeight);
  }
  function hideTip() { clearTimeout(tipTimer); $('tip').classList.add('hidden'); }

  // ---------------------------------------------------------------- lookup
  function itemAt(ref, slot) {
    if (ref === 'hotbar') return hotbarItem(Number(slot)).it;
    if (ref === 'holster') return holsterItem(slot);
    var v = S.views[ref];
    return v ? v.items[slot] || null : null;
  }
  function freeSlot(ref) {
    var v = S.views[ref]; if (!v) return null;
    for (var s = 1; s <= v.slots; s++) if (!v.items[s]) return s;
    return null;
  }
  function secAcceptsWeapons() { return !(S.secInfo && S.secInfo.acceptWeapons === false); }
  function secItemTotal() {
    var v = S.views.secondary, n = 0;
    if (v) Object.keys(v.items).forEach(function (k) { n += itemCount(v.items[k]); });
    return n;
  }
  function wouldOverweight(it, count) {
    var max = Number(S.weight.max) || 0;
    if (max <= 0) return false;
    return (Number(S.weight.current) || 0) + (Number(it.weight) || 0) * count > max + 1e-6;
  }

  // ---------------------------------------------------------------- actions
  function moveItem(fromRef, slot, toRef, toSlot, count) {
    var it = itemAt(fromRef, slot);
    var d = { from: { container: fromRef, slot: slot }, to: { container: toRef } };
    if (toSlot != null) d.to.slot = toSlot;
    if (it && count != null && count < itemCount(it)) d.count = count;
    return act('move', d);
  }
  function equipFrom(fromRef, slot, cat) {
    var it = itemAt(fromRef, slot);
    cat = cat || catForItem(it);
    if (!cat) { toast(errText('equip_slot'), 'bad'); return Promise.resolve({ ok: false }); }
    return post('equip', { container: fromRef, slot: slot, key: cat.key, toSlot: cat.order }).then(function (r) {
      if (r && !r.ok && r.err === 'unknown_action') return act('move', { from: { container: fromRef, slot: slot }, to: { container: 'equip', slot: cat.order } });
      if (!r || !r.ok) { var e = r && r.err; if (!selfNotified('equip', e)) toast(errText(e), 'bad'); }
      return r;
    });
  }
  function unequip(slot, toRef, toSlot) {
    var cat = S.catsBySlot[slot];
    toRef = toRef || 'player';
    if (toRef !== 'player') {
      // the clothing part's unequip always returns the piece to the player grid; anything else is a plain move
      var mv = { from: { container: 'equip', slot: slot }, to: { container: toRef } };
      if (toSlot != null) mv.to.slot = toSlot;
      return act('move', mv);
    }
    var d = { slot: slot, key: cat ? cat.key : null };
    if (toSlot != null) d.toSlot = toSlot;
    return post('unequip', d).then(function (r) {
      if (r && !r.ok && r.err === 'unknown_action') {
        var m = { from: { container: 'equip', slot: slot }, to: { container: toRef } };
        if (toSlot != null) m.to.slot = toSlot;
        return act('move', m);
      }
      if (!r || !r.ok) { var e = r && r.err; if (!selfNotified('unequip', e)) toast(errText(e), 'bad'); }
      return r;
    });
  }
  function weaponAct(name, it, extra) {
    var d = { slot: it.slot, weaponId: it.weaponId || it.id };
    if (extra) Object.keys(extra).forEach(function (k) { d[k] = extra[k]; });
    return act(name, d).then(function (r) {
      // gunbelt changes after unload / equip: refresh the ammo strip
      if (r && r.ok && (name === 'weaponUnload' || name === 'weaponEquip' || name === 'weaponUnequip')) refreshAmmo();
      return r;
    });
  }
  function refreshAmmo() {
    post('ammoBelt', {}).then(function (r) { if (r && r.ok && r.data) { S.ammo = r.data; renderAmmo(); } });
  }
  function inspectWeapon(it) {
    post('weaponInspect', { slot: it.slot, weaponId: it.weaponId || it.id }).then(function (r) {
      var merged = it;
      if (r && r.ok && r.data && typeof r.data === 'object') {
        merged = Object.assign({}, it);
        var w = r.data, m = Object.assign({}, meta(it));
        if (w.serial_number && !m.serial) m.serial = w.serial_number;
        if (w.custom_label && !m.label) m.label = w.custom_label;
        if (w.custom_desc && !m.description) m.description = w.custom_desc;
        if (w.components && !m.components) m.components = w.components;
        merged.metadata = m;
      }
      openExamine('player', merged);
    });
  }
  function useItem(ref, slot) {
    var it = itemAt(ref, slot);
    if (!it) return;
    if (ref === 'holster') return weaponAct('weaponUnequip', it);
    if (ref === 'equip') return unequip(slot);
    if (ref !== 'player') return quickMove(ref, slot);
    if (catForItem(it)) return equipFrom('player', slot);
    if (isWeapon(it)) return weaponAct(weaponEquipped(it) ? 'weaponUnequip' : 'weaponEquip', it);
    if (it.canUse === false) { toast(errText('not_usable'), 'bad'); return; }
    return act('use', { slot: slot });
  }
  function quickMove(ref, slot) {
    var it = itemAt(ref, slot); if (!it) return;
    if (ref === 'equip') return unequip(slot);
    if (ref === 'player' && S.views.secondary) return moveItem('player', slot, 'secondary', null);
    if (ref === 'secondary') {
      if (wouldOverweight(it, itemCount(it))) { toast(errText('weight'), 'bad'); return; }
      return moveItem('secondary', slot, 'player', null);
    }
    if (ref === 'player' && catForItem(it)) return equipFrom('player', slot);
  }
  function assignHotbar(n, slot) { return act('hotbar', { op: 'assign', n: n, slot: slot }); }
  function clearHotbar(n) { return act('hotbar', { op: 'clear', n: n }); }
  function sortRef(ref, mode) { if (mode) act('sort', { container: ref, mode: mode }); }

  $('sortMode').addEventListener('change', function () { sortRef('player', this.value); this.value = ''; this.blur(); });
  $('secSort').addEventListener('click', function () { sortRef('secondary', 'name'); });
  $('closeBtn').addEventListener('click', requestClose);
  $('saddleBtn').addEventListener('click', function () { act('saddlebag', {}); });

  // ---------------------------------------------------------------- modals
  function closeModal(val) {
    var m = S.modal; if (!m) return;
    S.modal = null;
    $('modalRoot').innerHTML = '';
    m.resolve(val);
  }
  function modal(o) {
    closeModal(null);
    return new Promise(function (resolve) {
      var root = $('modalRoot');
      root.innerHTML = '<div class="rmodal-backdrop"><div class="rmodal"><div class="plate-frame cut-modal"><div class="plate"><div class="plate-body">' +
        (o.kicker ? '<span class="kicker">' + esc(o.kicker) + '</span>' : '') + '<h2 class="multi-title">' + esc(o.title || '') + '</h2>' +
        '<div class="m-body"></div><div class="actions"></div></div></div></div></div></div>';
      var body = root.querySelector('.m-body'), acts = root.querySelector('.actions');
      if (typeof o.body === 'string') body.innerHTML = o.body; else if (o.body) body.appendChild(o.body);
      (o.buttons || []).forEach(function (b) {
        var el = document.createElement('button');
        el.className = 'rbtn ' + (b.cls || '');
        el.textContent = b.label;
        el.addEventListener('click', function () { var v = typeof b.value === 'function' ? b.value() : b.value; if (v === undefined) return; closeModal(v); });
        b.el = el; acts.appendChild(el);
      });
      root.querySelector('.rmodal-backdrop').addEventListener('mousedown', function (e) { if (e.target === e.currentTarget) closeModal(null); });
      S.modal = { resolve: resolve, o: o, root: root };
      hideTip(); closeCtx();
      if (o.onMount) o.onMount(root);
      var f = root.querySelector('[data-autofocus]'); if (f) { f.focus(); if (f.select) f.select(); }
    });
  }
  function itemHeader(it) {
    return '<div class="m-item"><div class="tile has" data-rar="' + (it.rarity || 1) + '">' + tileInner(it, { noName: true }) + '</div><div><b>' + esc(label(it)) + '</b><small>' + (isWeapon(it) ? '' : '× ' + itemCount(it) + ' · ') + kg((Number(it.weight) || 0) * itemCount(it)) + '</small></div></div>';
  }
  function amountBlock(max, init) {
    return '<label class="rlabel">' + esc(T('amount')) + '</label><div class="amount">' +
      '<button class="rbtn" type="button" data-step="-1">−</button><input class="rinput" type="number" min="1" max="' + max + '" value="' + init + '" data-amt data-autofocus>' +
      '<button class="rbtn" type="button" data-step="1">+</button></div>' +
      '<input class="amount-range" type="range" min="1" max="' + max + '" value="' + init + '" data-range>' +
      '<div class="quick"><button class="rbtn muted" type="button" data-q="1">' + esc(T('one')) + '</button><button class="rbtn muted" type="button" data-q="half">' + esc(T('half')) + '</button><button class="rbtn muted" type="button" data-q="all">' + esc(T('allBtn')) + '</button></div>';
  }
  function wireAmount(root, max) {
    var input = root.querySelector('[data-amt]'), range = root.querySelector('[data-range]');
    if (!input) return function () { return 1; };
    function set(v) { v = Math.max(1, Math.min(max, Math.floor(Number(v) || 1))); input.value = v; range.value = v; }
    input.addEventListener('input', function () { range.value = input.value; });
    input.addEventListener('change', function () { set(input.value); });
    range.addEventListener('input', function () { input.value = range.value; });
    root.querySelectorAll('[data-step]').forEach(function (b) { b.addEventListener('click', function () { set(Number(input.value) + Number(b.dataset.step)); }); });
    root.querySelectorAll('[data-q]').forEach(function (b) { b.addEventListener('click', function () { set(b.dataset.q === 'all' ? max : b.dataset.q === 'half' ? Math.max(1, Math.floor(max / 2)) : 1); }); });
    S.modal.step = function (d) { set(Number(input.value) + d); };
    return function () { set(input.value); return Number(input.value); };
  }
  function askAmount(it, o) {
    var max = o.max || itemCount(it);
    var init = Math.max(1, Math.min(max, o.init || Math.max(1, Math.floor(max / 2))));
    var get;
    return modal({
      kicker: o.kicker, title: o.title,
      body: itemHeader(it) + amountBlock(max, init) + (o.note ? '<p class="m-note">' + esc(o.note) + '</p>' : ''),
      buttons: [{ label: T('cancel'), cls: 'muted', value: null }, { label: o.confirm || T('confirm'), cls: o.danger ? 'danger' : 'primary', primary: true, value: function () { return get(); } }],
      onMount: function (root) { get = wireAmount(root, max); }
    });
  }
  function openSplit(ref, slot) {
    var it = itemAt(ref, slot); if (!it || itemCount(it) < 2) return;
    askAmount(it, { title: T('splitTitle'), max: itemCount(it) - 1, init: Math.floor(itemCount(it) / 2) }).then(function (n) {
      if (n) act('split', { container: ref, slot: slot, count: n });
    });
  }
  function openDrop(slot, preset) {
    var it = itemAt('player', slot); if (!it) return;
    var del = (S.config.dropMode || S.setup.dropMode) === 'delete';
    var c = itemCount(it);
    var send = function (n) { if (n) act('drop', isWeapon(it) || n >= c ? { slot: slot } : { slot: slot, count: n }); };
    if (it.canRemove === false) { toast(errText('cannot_drop'), 'bad'); return; }
    if (del && S.config.confirmDelete === false && c === 1) { send(1); return; }
    if (c > 1) {
      askAmount(it, { kicker: del ? T('destroy') : T('drop'), title: del ? T('destroyTitle') : T('dropTitle'), init: preset || c,
        note: del ? T('destroyNote') : T('dropNote'), confirm: del ? T('destroy') : T('drop'), danger: del }).then(send);
    } else {
      modal({ kicker: del ? T('destroy') : T('drop'), title: del ? T('destroyTitle') : T('dropTitle'),
        body: itemHeader(it) + '<p class="m-note' + (del ? ' m-warn' : '') + '">' + esc(del ? T('destroyNote') : T('dropNote')) + '</p>',
        buttons: [{ label: T('cancel'), cls: 'muted', value: null }, { label: del ? T('destroy') : T('drop'), cls: del ? 'danger' : 'primary', primary: true, value: 1 }] }).then(send);
    }
  }
  function openGive(slot, preset) {
    var it = itemAt('player', slot); if (!it) return;
    if (it.canRemove === false) { toast(errText('cannot_give'), 'bad'); return; }
    var c = isWeapon(it) ? 1 : itemCount(it), target = null, get = function () { return 1; };
    var confirmBtn = { label: T('give'), cls: 'primary', primary: true, value: function () { if (target == null) { toast(errText('bad_target'), 'bad'); return undefined; } return { target: target, count: get() }; } };
    modal({
      kicker: T('give'), title: T('giveTitle'),
      body: itemHeader(it) + '<div class="players" data-players><div class="m-empty">' + esc(T('giveLoading')) + '</div></div>' + (c > 1 ? amountBlock(c, preset || c) : '') + '<p class="m-note">' + esc(T('giveNote')) + '</p>',
      buttons: [{ label: T('cancel'), cls: 'muted', value: null }, confirmBtn],
      onMount: function (root) {
        if (c > 1) get = wireAmount(root, c);
        var host = root.querySelector('[data-players]');
        post('nearby', {}).then(function (r) {
          if (!S.modal || S.modal.root !== root) return;
          var list = (r && r.ok && Array.isArray(r.data)) ? r.data : [];
          if (!list.length) { host.innerHTML = '<div class="m-empty">' + esc(T('giveNone')) + '</div>'; return; }
          host.innerHTML = list.map(function (p, i) {
            return '<div class="rrow" data-pid="' + esc(p.id) + '" data-i="' + i + '"><span class="rtile">' + esc(String(p.id)) + '</span><span>' + esc(p.name || ('#' + p.id)) + '</span><span class="dist">' + num(p.distance, 1) + ' m</span></div>';
          }).join('');
          var pick = function (row) {
            host.querySelectorAll('.rrow').forEach(function (x) { x.classList.toggle('active', x === row); });
            target = Number(row.dataset.pid);
          };
          host.querySelectorAll('.rrow').forEach(function (row) { row.addEventListener('click', function () { pick(row); }); });
          pick(host.querySelector('.rrow'));
          S.modal.cycle = function (d) {
            var rowsEl = Array.prototype.slice.call(host.querySelectorAll('.rrow'));
            var i = rowsEl.findIndex(function (x) { return x.classList.contains('active'); });
            pick(rowsEl[(i + d + rowsEl.length) % rowsEl.length]);
          };
        });
      }
    }).then(function (v) {
      if (!v) return;
      var d = { slot: slot, target: v.target };
      if (!isWeapon(it) && v.count < c) d.count = v.count;
      act('give', d);
    });
  }
  // ---- cash (Config.Money): an exact amount (dollars + cents) given, dropped or put away.
  // The server makes change (breaks a dollar into cents) and moves the right bills and coins.
  function openCash() {
    var m = moneyCfg(); if (!m) return;
    var have = walletCents();
    if (have < 1) { toast(errText('not_enough'), 'bad'); return; }
    var del = (S.config.dropMode || S.setup.dropMode) === 'delete';
    var target = null;
    var body = '<div class="m-item"><div><b>' + esc(T('wallet')) + ': $ ' + fmtCents(have) + '</b></div></div>' +
      '<label class="rlabel">' + esc(T('amount')) + '</label><div class="amount">' +
      '<span>$</span><input class="rinput" type="number" min="0" max="' + Math.floor(have / 100) + '" value="' + Math.floor(have / 100) + '" title="' + esc(T('dollarsLbl')) + '" data-dollars data-autofocus>' +
      '<span>.</span><input class="rinput" type="number" min="0" max="99" value="' + ('0' + (have % 100)).slice(-2) + '" title="' + esc(T('centsLbl')) + '" data-cents></div>' +
      '<div class="quick"><button class="rbtn muted" type="button" data-cq="half">' + esc(T('half')) + '</button><button class="rbtn muted" type="button" data-cq="all">' + esc(T('allBtn')) + '</button></div>' +
      '<div class="players" data-players><div class="m-empty">' + esc(T('giveLoading')) + '</div></div>' +
      '<p class="m-note">' + esc(T('cashNote')) + '</p>';
    var read = function () {
      var root = S.modal && S.modal.root; if (!root) return null;
      var dv = String(root.querySelector('[data-dollars]').value || '0'), cv = String(root.querySelector('[data-cents]').value || '0');
      if (!/^\d+$/.test(dv) || !/^\d{1,2}$/.test(cv)) return null;
      var d = Number(dv), c = Number(cv), t = d * 100 + c;
      if (t < 1 || t > have) return null;
      return { dollars: d, cents: c };
    };
    var pick = function (op) {
      return function () {
        var r = read();
        if (!r) { toast(errText('bad_count'), 'bad'); return undefined; }
        if (op === 'give' && target == null) { toast(errText('bad_target'), 'bad'); return undefined; }
        r.op = op; if (op === 'give') r.target = target;
        return r;
      };
    };
    var buttons = [{ label: T('cancel'), cls: 'muted', value: null }];
    if (!del && m.allowOnGround !== false) buttons.push({ label: T('drop'), cls: 'danger', value: pick('drop') });
    if (S.views.secondary && m.allowInStashes !== false) buttons.push({ label: T('store'), cls: '', value: pick('store') });
    buttons.push({ label: T('give'), cls: 'primary', primary: true, value: pick('give') });
    modal({
      kicker: T('cash'), title: T('cashTitle'), body: body, buttons: buttons,
      onMount: function (root) {
        var dIn = root.querySelector('[data-dollars]'), cIn = root.querySelector('[data-cents]');
        var setC = function (t) { t = Math.max(0, Math.min(have, Math.floor(t))); dIn.value = Math.floor(t / 100); cIn.value = ('0' + (t % 100)).slice(-2); };
        root.querySelectorAll('[data-cq]').forEach(function (b) { b.addEventListener('click', function () { setC(b.dataset.cq === 'all' ? have : have / 2); }); });
        var host = root.querySelector('[data-players]');
        post('nearby', {}).then(function (r) {
          if (!S.modal || S.modal.root !== root) return;
          var list = (r && r.ok && Array.isArray(r.data)) ? r.data : [];
          if (!list.length) { host.innerHTML = '<div class="m-empty">' + esc(T('giveNone')) + '</div>'; return; }
          host.innerHTML = list.map(function (p, i) {
            return '<div class="rrow" data-pid="' + esc(p.id) + '" data-i="' + i + '"><span class="rtile">' + esc(String(p.id)) + '</span><span>' + esc(p.name || ('#' + p.id)) + '</span><span class="dist">' + num(p.distance, 1) + ' m</span></div>';
          }).join('');
          var choose = function (row) {
            host.querySelectorAll('.rrow').forEach(function (x) { x.classList.toggle('active', x === row); });
            target = Number(row.dataset.pid);
          };
          host.querySelectorAll('.rrow').forEach(function (row) { row.addEventListener('click', function () { choose(row); }); });
          choose(host.querySelector('.rrow'));
          S.modal.cycle = function (dd) {
            var rowsEl = Array.prototype.slice.call(host.querySelectorAll('.rrow'));
            var i = rowsEl.findIndex(function (x) { return x.classList.contains('active'); });
            choose(rowsEl[(i + dd + rowsEl.length) % rowsEl.length]);
          };
        });
      }
    }).then(function (v) { if (v) act('cash', v); });
  }
  $('cashBox').addEventListener('click', function () { if (S.open && moneyCfg()) openCash(); });

  function openRename(it) {
    modal({
      kicker: 'Weapon', title: T('renameTitle'),
      body: itemHeader(it) + '<label class="rlabel">Name</label><input class="rinput" maxlength="40" data-name data-autofocus value="' + esc(label(it)) + '">',
      buttons: [{ label: T('cancel'), cls: 'muted', value: null }, { label: T('confirm'), cls: 'primary', primary: true, value: function () { return S.modal.root.querySelector('[data-name]').value.trim() || undefined; } }]
    }).then(function (name) { if (name) weaponAct('renameWeapon', it, { label: name }); });
  }
  // ---- outfits
  function openOutfits() {
    var render = function (root, list) {
      var host = root.querySelector('[data-outfits]');
      if (!list.length) { host.innerHTML = '<div class="m-empty">' + esc(T('outfitNone')) + '</div>'; return; }
      host.innerHTML = list.map(function (o) {
        var n = Array.isArray(o.pieces) ? o.pieces.length : 0;
        return '<div class="rrow outfit" data-id="' + esc(o.id) + '"><span class="rtile">' + n + '</span><span class="o-name">' + esc(o.name) +
          '<small>' + esc(T('outfitPieces', { n: n })) + '</small></span><span class="o-acts">' +
          '<button class="rbtn small primary" data-wear="' + esc(o.id) + '">' + esc(T('outfitWear')) + '</button>' +
          '<button class="rbtn small" data-undress="' + esc(o.id) + '" title="' + esc(T('outfitUndress')) + '">+</button>' +
          '<button class="rbtn small danger" data-del="' + esc(o.id) + '">&times;</button></span></div>';
      }).join('');
    };
    var load = function (root) {
      post('outfitList', {}).then(function (r) {
        if (!S.modal || S.modal.root !== root) return;
        render(root, r && r.ok && Array.isArray(r.data) ? r.data : []);
      });
    };
    var wear = function (id, undress) {
      post('outfitWear', { id: Number(id), undress: !!undress }).then(function (r) {
        if (!r || !r.ok) { toast(errText(r && r.err), 'bad'); return; }
        var res = r.data || {}, miss = Array.isArray(res.missing) ? res.missing : [];
        var failed = res.failed && typeof res.failed === 'object' ? Object.keys(res.failed) : [];
        if (miss.length || failed.length) toast(miss.concat(failed).map(function (k) { return (S.catsByKey[k] || { label: k }).label; }).join(', ') + ' — ' + T('missing'), 'bad');
        else toast(T('outfitWear') + ' ✓', 'ok');
      });
    };
    modal({
      kicker: T('equipment'), title: T('outfits'),
      body: '<div class="players outfits" data-outfits><div class="m-empty">' + esc(T('giveLoading')) + '</div></div>' +
        '<label class="rlabel">' + esc(T('outfitName')) + '</label><div class="amount"><input class="rinput" maxlength="64" data-oname>' +
        '<button class="rbtn primary" type="button" data-save>' + esc(T('outfitSave')) + '</button></div>',
      buttons: [{ label: T('close'), cls: 'muted', value: null, primary: true }],
      onMount: function (root) {
        load(root);
        root.querySelector('[data-save]').addEventListener('click', function () {
          var name = root.querySelector('[data-oname]').value.trim();
          act('outfitSave', { name: name }).then(function (r) { if (r.ok) { root.querySelector('[data-oname]').value = ''; load(root); } });
        });
        root.querySelector('[data-outfits]').addEventListener('click', function (e) {
          var b = tgtEl(e).closest('button'); if (!b) return;
          if (b.dataset.wear) wear(b.dataset.wear, false);
          else if (b.dataset.undress) wear(b.dataset.undress, true);
          else if (b.dataset.del) act('outfitDelete', { id: Number(b.dataset.del) }).then(function (r) { if (r.ok) load(root); });
        });
      }
    });
  }
  function openPackOutfit(firstSlot) {
    var v = S.views.player; if (!v) return;
    var pieces = Object.keys(v.items).map(function (k) { return v.items[k]; }).filter(function (x) { return catForItem(x); })
      .sort(function (a, b) { return a.slot - b.slot; });
    modal({
      kicker: T('outfits'), title: T('packTitle'),
      body: '<div class="players" data-pack>' + pieces.map(function (x) {
        return '<label class="rrow' + (x.slot === firstSlot ? ' active' : '') + '"><input type="checkbox" value="' + x.slot + '"' + (x.slot === firstSlot ? ' checked' : '') + '>' +
          '<span>' + esc(label(x)) + '</span><span class="dist">' + esc(catForItem(x).label) + '</span></label>';
      }).join('') + '</div><label class="rlabel">' + esc(T('outfitName')) + '</label><input class="rinput" maxlength="64" data-plabel value="Outfit">' +
        '<p class="m-note">' + esc(T('packNote')) + '</p>',
      buttons: [{ label: T('cancel'), cls: 'muted', value: null }, { label: T('confirm'), cls: 'primary', primary: true, value: function () {
        var root = S.modal.root, slots = [];
        root.querySelectorAll('[data-pack] input:checked').forEach(function (c) { slots.push(Number(c.value)); });
        if (!slots.length) { toast(errText('no_pieces'), 'bad'); return undefined; }
        return { slots: slots, label: root.querySelector('[data-plabel]').value.trim() || 'Outfit' };
      } }],
      onMount: function (root) {
        root.querySelectorAll('[data-pack] input').forEach(function (c) { c.addEventListener('change', function () { c.parentNode.classList.toggle('active', c.checked); }); });
      }
    }).then(function (v2) { if (v2) act('outfitPack', v2); });
  }
  $('outfitBtn').addEventListener('click', openOutfits);

  function openExamine(ref, it) {
    modal({ kicker: T('examine'), title: label(it), body: '<div class="tip examine" style="position:static;width:auto;transform:none;filter:none">' + tipHTML(it, ref, { noHint: true }) + '</div>',
      buttons: [{ label: T('close'), cls: 'primary', primary: true, value: 0 }] });
  }
  function modalKey(e) {
    var m = S.modal, k = e.key;
    if (k === 'Escape' || k === 'Backspace' && !/INPUT|TEXTAREA/.test((document.activeElement || {}).tagName)) { e.preventDefault(); closeModal(null); return; }
    if (k === 'Enter') { e.preventDefault(); var b = (m.o.buttons || []).filter(function (x) { return x.primary; })[0]; if (b && b.el) b.el.click(); return; }
    if ((k === 'ArrowUp' || k === 'ArrowDown') && m.cycle) { e.preventDefault(); m.cycle(k === 'ArrowUp' ? -1 : 1); return; }
    if ((k === 'ArrowLeft' || k === 'ArrowRight') && m.step && (document.activeElement || {}).type !== 'text') { e.preventDefault(); m.step(k === 'ArrowLeft' ? -1 : 1); }
  }

  // ---------------------------------------------------------------- context menu
  function closeCtx() { if (S.ctx) { S.ctx = null; $('ctx').classList.add('hidden'); $('ctx').innerHTML = ''; } }
  function openCtx(ref, slot, x, y) {
    hideTip();
    if (ref === 'holster') {
      // a hip tile is a view of the player-grid weapon: same menu
      var hw = holsterItem(slot);
      if (!hw || hw.slot == null) return;
      ref = 'player'; slot = Number(hw.slot);
    }
    var it = itemAt(ref, slot);
    if (ref === 'hotbar') {
      var hb = hotbarItem(slot);
      if (!hb.h) return;
      return showCtx(hb.h.label || hb.h.item, [
        hb.it ? { label: T('use'), key: slot, fn: function () { act('hotbar', { op: 'use', n: slot }); } } : null,
        { label: T('clearHotbar'), fn: function () { clearHotbar(slot); } }
      ], x, y);
    }
    if (!it) return;
    var o = [], isP = ref === 'player', isS = ref === 'secondary', isE = ref === 'equip';
    var cat = catForItem(it), c = itemCount(it);
    var del = (S.config.dropMode || S.setup.dropMode) === 'delete';
    if (isE) o.push({ label: T('remove'), fn: function () { unequip(slot); } });
    if (isP && cat) o.push({ label: T('wear'), key: 'Y', fn: function () { equipFrom('player', slot, cat); } });
    var wEq = isWeapon(it) && weaponEquipped(it);
    if (isP && isWeapon(it)) {
      if (wEq) {
        var pair = isSidearm(it) && holsterItem(1) && holsterItem(2) && weaponHip(it) && weaponHip(it) !== 'extra';
        o.push({ label: weaponHip(it) === 'extra' ? T('drawExtra') : pair ? T('drawBoth') : T('draw'), fn: function () { weaponAct('weaponDraw', it); } });
        o.push({ label: T('holster'), key: 'Y', fn: function () { weaponAct('weaponUnequip', it); } });
      } else {
        o.push({ label: T('equip'), key: 'Y', fn: function () { weaponAct('weaponEquip', it); } });
        o.push({ label: T('equipDraw'), fn: function () { weaponAct('weaponEquip', it, { draw: true }); } });
        if (isSidearm(it) && S.setup.dualWield) {
          o.push({ label: T('equipRight'), fn: function () { weaponAct('weaponEquip', it, { hand: 'right' }); } });
          o.push({ label: T('equipLeft'), fn: function () { weaponAct('weaponEquip', it, { hand: 'left' }); } });
        }
        if (isSidearm(it) && S.setup.extraSidearm) {
          o.push({ label: T('equipExtra'), fn: function () { weaponAct('weaponEquip', it, { hand: 'extra' }); } });
        }
      }
    }
    if (isP && !cat && !isWeapon(it) && it.canUse !== false) o.push({ label: T('use'), key: 'Y', fn: function () { act('use', { slot: slot }); } });
    if (isP && S.views.secondary) o.push({ label: T('moveTo') + ' ' + (S.secondaryLabel || S.views.secondary.label || ''), disabled: wEq || (isWeapon(it) && !secAcceptsWeapons()), fn: function () { quickMove('player', slot); } });
    if (isS) o.push({ label: T('take'), fn: function () { quickMove('secondary', slot); } });
    if (!isE && !isWeapon(it) && c > 1) o.push({ label: T('split'), fn: function () { openSplit(ref, slot); } });
    if (isP && isMoneyItem(it)) o.push({ label: T('cashMenu'), fn: function () { openCash(); } });
    if (isP) o.push({ label: T('give') + (wEq ? ' (' + T('holsterFirst') + ')' : ''), disabled: it.canRemove === false || wEq, fn: function () { openGive(slot); } });
    if (isP && isWeapon(it)) {
      o.push('-');
      if (S.setup.allowRename) o.push({ label: T('rename'), fn: function () { openRename(it); } });
      o.push({ label: T('clean'), fn: function () { weaponAct('weaponClean', it); } });
      o.push({ label: T('unload'), fn: function () { weaponAct('weaponUnload', it); } });
    }
    if (isP && cat && S.views.player) o.push({ label: T('packOutfit'), fn: function () { openPackOutfit(slot); } });
    var extra = meta(it).context;
    if (Array.isArray(extra) && extra.length) {
      o.push('-');
      extra.forEach(function (b, i) {
        if (!b) return;
        o.push({ label: String(b.label || b.text || ('Action ' + (i + 1))), fn: function () { act('contextAction', { container: ref, slot: slot, index: i + 1, id: b.id || b.action || b.event || null }); } });
      });
    }
    o.push('-');
    o.push({ label: T('examine'), fn: function () { if (isP && isWeapon(it)) inspectWeapon(it); else openExamine(ref, it); } });
    if (isP) o.push({ label: (del ? T('destroy') : T('drop')) + (wEq ? ' (' + T('holsterFirst') + ')' : ''), danger: true, disabled: it.canRemove === false || wEq, fn: function () { openDrop(slot); } });
    var hk = isP ? { current: hotkeyOf(it), slot: slot } : null;
    showCtx(label(it), o, x, y, hk);
  }
  function showCtx(title, opts, x, y, hk) {
    var ctx = $('ctx');
    var html = '<div class="plate-frame"><div class="plate"><div class="plate-body"><div class="ctx-title">' + esc(title) + '</div>';
    var btns = [];
    opts.forEach(function (o) {
      if (!o) return;
      if (o === '-') { html += '<div class="sep"></div>'; return; }
      btns.push(o);
      html += '<button data-i="' + (btns.length - 1) + '" class="' + (o.danger ? 'danger' : '') + '"' + (o.disabled ? ' disabled' : '') + '>' + esc(o.label) + (o.key ? '<small>' + esc(o.key) + '</small>' : '') + '</button>';
    });
    if (hk) {
      html += '<div class="sep"></div><div class="hk-label">' + esc(T('hotbar')) + '</div><div class="hk-row">';
      var n = Number(S.config.hotbarSlots || 5);
      for (var i = 1; i <= n; i++) html += '<button data-hk="' + i + '" class="' + (hk.current === i ? 'on' : '') + '">' + i + '</button>';
      html += '</div>';
    }
    html += '</div></div></div>';
    ctx.innerHTML = html;
    ctx.classList.remove('hidden');
    S.ctx = { btns: btns, sel: -1, hk: hk };
    ctx.querySelectorAll('button[data-i]').forEach(function (b) {
      b.addEventListener('click', function () { var o = btns[Number(b.dataset.i)]; closeCtx(); if (o && !o.disabled) o.fn(); });
    });
    ctx.querySelectorAll('button[data-hk]').forEach(function (b) {
      b.addEventListener('click', function () { var n2 = Number(b.dataset.hk); closeCtx(); if (hk.current === n2) clearHotbar(n2); else assignHotbar(n2, hk.slot); });
    });
    place(ctx, x - 18, y - 14, ctx.offsetWidth, ctx.offsetHeight);
  }
  function ctxKey(e) {
    var c = S.ctx, k = e.key, els = $('ctx').querySelectorAll('button[data-i]:not([disabled])');
    if (k === 'Escape' || k === 'Backspace') { e.preventDefault(); closeCtx(); return; }
    if (k === 'ArrowDown' || k === 'ArrowUp') {
      e.preventDefault();
      if (!els.length) return;
      var list = Array.prototype.slice.call(els), i = list.findIndex(function (b) { return b.classList.contains('sel'); });
      i = (i + (k === 'ArrowDown' ? 1 : -1) + list.length) % list.length;
      list.forEach(function (b, j) { b.classList.toggle('sel', j === i); });
      return;
    }
    if (k === 'Enter' || k === ' ') { e.preventDefault(); var s = $('ctx').querySelector('button.sel'); if (s) s.click(); return; }
    if (/^[1-9]$/.test(k) && c.hk) { e.preventDefault(); var hb = $('ctx').querySelector('button[data-hk="' + k + '"]'); if (hb) hb.click(); }
  }
  document.addEventListener('mousedown', function (e) {
    if (S.ctx && !tgtEl(e).closest('#ctx')) closeCtx();
  });

  // ---------------------------------------------------------------- drag & drop
  var press = null, pageHover = null, pageTimer = null;
  function startDrag(p) {
    p.dragging = true;
    S.drag = p;
    hideTip(); closeCtx();
    document.body.classList.add('dragging');
    p.el.classList.add('ghosted');
    var g = $('ghost');
    var it = p.item;
    g.innerHTML = '<div class="tile has" data-rar="' + (it.rarity || 1) + '">' + tileInner(it, p.ref === 'hotbar' ? { count: hotbarCount(hotbarItem(p.slot).h) } : {}) + '</div><span class="amt hidden"></span>';
    g.classList.remove('hidden');
    if (p.ref === 'player' || p.ref === 'secondary') {
      var cat = catForItem(it);
      if (cat && S.tiles.equip[cat.order]) S.tiles.equip[cat.order].classList.add('target-hint');
      if (p.ref === 'player' && isSidearm(it) && !weaponEquipped(it) && S.tiles.holster) {
        Object.keys(S.tiles.holster).forEach(function (k) { if (!holsterItem(k)) S.tiles.holster[k].classList.add('target-hint'); });
      }
    }
  }
  function moveGhost(x, y, e) {
    var g = $('ghost'), s = S.scale;
    g.style.transform = 'translate(' + Math.round(x - 37 * s) + 'px,' + Math.round(y - 37 * s) + 'px) scale(' + s + ')';
    var amt = g.querySelector('.amt'), it = S.drag && S.drag.item;
    if (amt && it && !isWeapon(it) && itemCount(it) > 1 && S.drag.ref !== 'hotbar') {
      var t = e.ctrlKey ? T('amount') + '…' : e.altKey ? '× ' + Math.max(1, Math.floor(itemCount(it) / 2)) : '× ' + itemCount(it);
      amt.textContent = t; amt.classList.remove('hidden');
    } else if (amt) amt.classList.add('hidden');
  }
  var lastTargetEl = null;
  function targetAt(x, y) {
    var el = document.elementFromPoint(x, y);
    if (!el) return null;
    var tile = el.closest('.tile[data-ref]');
    if (tile && tile.closest('#stage')) {
      var ref = tile.dataset.ref;
      return { type: ref === 'equip' ? 'equip' : ref === 'hotbar' ? 'hotbar' : ref === 'holster' ? 'holster' : 'slot', ref: ref, slot: Number(tile.dataset.slot), el: tile };
    }
    var pg = el.closest('#secPager button[data-page]');
    if (pg) return { type: 'page', page: Number(pg.dataset.page), el: pg };
    var zone = el.closest('.zone');
    if (zone) return { type: zone.dataset.zone, el: zone };
    if (el.closest('.inv')) return null;
    if (el.closest('#app')) return { type: 'outside', el: null };
    return null;
  }
  function validity(src, tgt) {
    if (!tgt) return null;
    var it = src.item;
    if (src.ref === 'hotbar') return tgt.type === 'hotbar' ? (tgt.slot === src.slot ? null : 'ok') : null;
    // hip tile -> player grid / anywhere in the bag = unequip; hip -> other hip = not supported
    if (src.ref === 'holster') return (tgt.type === 'slot' && tgt.ref === 'player') ? 'ok' : (tgt.type === 'holster' && tgt.slot !== src.slot ? 'bad' : null);
    switch (tgt.type) {
      case 'holster':
        if (src.ref !== 'player' || !isSidearm(it) || weaponEquipped(it)) return 'bad';
        return 'ok';
      case 'slot':
        if (tgt.ref === src.ref && tgt.slot === src.slot) return null;
        if (src.ref === 'equip') {
          var occ = itemAt(tgt.ref, tgt.slot);
          if (occ) return 'bad';
          if (tgt.ref === 'player' && !S.config.wornCountsWeight && wouldOverweight(it, 1)) return 'bad';
          return 'ok';
        }
        if (tgt.ref === 'player' && src.ref !== 'player' && wouldOverweight(it, itemCount(it))) return 'bad';
        if (tgt.ref !== src.ref && isWeapon(it) && weaponEquipped(it)) return 'bad';
        if (tgt.ref === 'secondary' && isWeapon(it) && !secAcceptsWeapons()) return 'bad';
        if (tgt.ref === 'secondary' && src.ref !== 'secondary' && S.secInfo && S.secInfo.countLimit && secItemTotal() + itemCount(it) > Number(S.secInfo.countLimit)) return 'bad';
        return 'ok';
      case 'equip':
        if (src.ref === 'equip') return tgt.slot === src.slot ? null : 'bad';
        var cat = S.catsBySlot[tgt.slot];
        if (!cat || catForItem(it) !== cat) return 'bad';
        var need = S.requires[cat.key];
        if (need && S.catsByKey[need] && !itemAt('equip', S.catsByKey[need].order)) return 'bad';
        return 'ok';
      case 'hotbar': return src.ref === 'player' ? 'ok' : 'bad';
      case 'give': case 'drop':
        return src.ref === 'player' && it.canRemove !== false && !(isWeapon(it) && weaponEquipped(it)) ? 'ok' : 'bad';
      case 'outside': return src.ref === 'player' && it.canRemove !== false && !(isWeapon(it) && weaponEquipped(it)) ? 'ok' : null;
      case 'page': return null;
    }
    return null;
  }
  function markTarget(tgt, v) {
    if (lastTargetEl) lastTargetEl.classList.remove('drop-ok', 'drop-bad');
    lastTargetEl = null;
    if (tgt && tgt.el && v) { tgt.el.classList.add(v === 'ok' ? 'drop-ok' : 'drop-bad'); lastTargetEl = tgt.el; }
  }
  function cancelDrag() {
    if (lastTargetEl) lastTargetEl.classList.remove('drop-ok', 'drop-bad');
    lastTargetEl = null;
    document.querySelectorAll('.target-hint').forEach(function (x) { x.classList.remove('target-hint'); });
    if (S.drag && S.drag.el) S.drag.el.classList.remove('ghosted');
    S.drag = null; press = null;
    document.body.classList.remove('dragging');
    $('ghost').classList.add('hidden');
  }
  function pickCount(it, mods) {
    if (isWeapon(it)) return Promise.resolve(1);
    var c = itemCount(it);
    if (c <= 1 || mods.shiftKey) return Promise.resolve(c);
    if (mods.altKey) return Promise.resolve(Math.max(1, Math.floor(c / 2)));
    if (mods.ctrlKey) return askAmount(it, { title: T('moveTitle'), init: c });
    return Promise.resolve(c);
  }
  function dispatchDrop(src, tgt, mods) {
    var v = validity(src, tgt);
    if (src.ref === 'hotbar') {
      if (v === 'ok') { var hs = hotbarItem(src.slot).it; if (hs) assignHotbar(tgt.slot, hs.slot); }
      else if (!tgt || tgt.type === 'outside' || (tgt.type !== 'hotbar')) { if (!tgt || tgt.type !== 'hotbar') clearHotbar(src.slot); }
      return;
    }
    if (src.ref === 'holster') {
      if (v === 'ok') weaponAct('weaponUnequip', src.item);
      else if (v === 'bad') toast(errText('weapon_equipped'), 'bad');
      return;
    }
    if (tgt && tgt.type === 'holster') {
      if (v === 'ok') weaponAct('weaponEquip', src.item, { hand: hipKeyOf(tgt.slot) });
      else if (v === 'bad') toast(errText(isSidearm(src.item) ? 'weapon_equipped' : 'not_sidearm'), 'bad');
      return;
    }
    if (v !== 'ok') {
      if (v === 'bad') {
        var bi = src.item;
        if (isWeapon(bi) && weaponEquipped(bi) && tgt.type !== 'equip' && tgt.type !== 'hotbar') toast(errText('weapon_equipped'), 'bad');
        else if (tgt.type === 'slot' && tgt.ref === 'player' && wouldOverweight(bi, itemCount(bi))) toast(errText('weight'), 'bad');
        else if (tgt.type === 'slot' && tgt.ref === 'secondary' && isWeapon(bi) && !secAcceptsWeapons()) toast(errText('no_weapons'), 'bad');
        else if (tgt.type === 'equip') {
          var c2 = S.catsBySlot[tgt.slot];
          toast(errText(c2 && catForItem(bi) === c2 && S.requires[c2.key] ? 'clothing_requires' : 'equip_slot'), 'bad');
        }
        else if (tgt.type === 'slot' && tgt.ref === 'secondary') toast(errText('limit'), 'bad');
      }
      return;
    }
    var it = src.item;
    switch (tgt.type) {
      case 'slot':
        if (src.ref === 'equip') { unequip(src.slot, tgt.ref, tgt.slot); return; }
        pickCount(it, mods).then(function (n) { if (n) moveItem(src.ref, src.slot, tgt.ref, tgt.slot, n); });
        return;
      case 'equip': equipFrom(src.ref, src.slot, S.catsBySlot[tgt.slot]); return;
      case 'hotbar': assignHotbar(tgt.slot, src.slot); return;
      case 'give':
        pickCount(it, { shiftKey: mods.shiftKey, altKey: mods.altKey }).then(function (n) { openGive(src.slot, n); });
        return;
      case 'drop': case 'outside':
        pickCount(it, { shiftKey: mods.shiftKey, altKey: mods.altKey }).then(function (n) { openDrop(src.slot, n); });
        return;
    }
  }

  document.addEventListener('pointerdown', function (e) {
    if (!S.open || e.button !== 0 || S.modal) return;
    var tile = tgtEl(e).closest('#stage .tile[data-ref]');
    if (!tile) return;
    var ref = tile.dataset.ref, slot = Number(tile.dataset.slot), it = itemAt(ref, slot);
    if (!it) return;
    S.kbMode = false;
    press = { ref: ref, slot: slot, item: it, x: e.clientX, y: e.clientY, el: tile, dragging: false };
    e.preventDefault();
  });
  document.addEventListener('pointermove', function (e) {
    if (S.kbMode && (Math.abs(e.movementX) + Math.abs(e.movementY) > 2)) { S.kbMode = false; }
    if (!press) return;
    if (!press.dragging) {
      if (Math.abs(e.clientX - press.x) + Math.abs(e.clientY - press.y) < 6) return;
      startDrag(press);
    }
    moveGhost(e.clientX, e.clientY, e);
    var tgt = targetAt(e.clientX, e.clientY);
    markTarget(tgt, validity(press, tgt));
    // hovering a page button while dragging flips the secondary page
    if (tgt && tgt.type === 'page' && !tgt.el.disabled) {
      if (pageHover !== tgt.page) {
        pageHover = tgt.page; clearTimeout(pageTimer);
        pageTimer = setTimeout(function () { if (S.drag) setSecPage(pageHover); pageHover = null; }, 450);
      }
    } else if (pageHover !== null) { pageHover = null; clearTimeout(pageTimer); }
  });
  document.addEventListener('pointerup', function (e) {
    if (!press) return;
    var p = press;
    if (p.dragging) {
      var tgt = targetAt(e.clientX, e.clientY);
      var mods = { shiftKey: e.shiftKey, altKey: e.altKey, ctrlKey: e.ctrlKey };
      cancelDrag();
      dispatchDrop(p, tgt, mods);
    } else {
      press = null;
      if (e.shiftKey && p.ref !== 'hotbar' && p.ref !== 'holster') quickMove(p.ref, p.slot);
      else if (p.ref === 'hotbar') act('hotbar', { op: 'use', n: p.slot });
    }
  });
  window.addEventListener('blur', cancelDrag);
  document.addEventListener('dblclick', function (e) {
    var tile = tgtEl(e).closest('#stage .tile[data-ref]');
    if (!tile || !S.open || tile.dataset.ref === 'hotbar') return;
    useItem(tile.dataset.ref, Number(tile.dataset.slot));
  });
  document.addEventListener('contextmenu', function (e) {
    e.preventDefault();
    if (!S.open || S.modal) return;
    var tile = tgtEl(e).closest('#stage .tile[data-ref]');
    if (!tile) { closeCtx(); return; }
    openCtx(tile.dataset.ref, Number(tile.dataset.slot), e.clientX, e.clientY);
  });
  document.addEventListener('mouseover', function (e) {
    var tile = tgtEl(e).closest('#stage .tile[data-ref]');
    S.hover = tile ? { ref: tile.dataset.ref, slot: Number(tile.dataset.slot) } : null;
    if (S.drag || S.ctx || S.modal || S.kbMode) return;
    clearTimeout(tipTimer);
    if (!tile) { hideTip(); return; }
    var x = e.clientX, y = e.clientY;
    tipTimer = setTimeout(function () { if (!S.drag && !S.ctx && !S.modal) showTipFor(tile, x, y); }, 220);
  });
  document.addEventListener('mousemove', function (e) {
    var tip = $('tip');
    if (tip.classList.contains('hidden') || S.kbMode) return;
    place(tip, e.clientX, e.clientY, tip.offsetWidth, tip.offsetHeight);
  });

  // ---------------------------------------------------------------- keyboard / controller
  function panes() {
    var out = [];
    if (S.views.secondary) out.push('secondary');
    out.push('player');
    if (!S.equipCollapsed) out.push('equip');
    out.push('hotbar');
    return out;
  }
  function paneTiles(p) {
    var t = S.tiles[p] || {};
    if (p === 'equip') return S.cats.map(function (c) { return t[c.order]; }).filter(Boolean);
    return Object.keys(t).map(Number).sort(function (a, b) { return a - b; }).map(function (k) { return t[k]; });
  }
  var COLS = { secondary: 5, player: 8, equip: 7, hotbar: 5 };
  function applyFocus() {
    document.querySelectorAll('#stage .tile.focus').forEach(function (x) { x.classList.remove('focus'); });
    if (!S.focus) return;
    var list = paneTiles(S.focus.pane);
    if (!list.length) return;
    S.focus.idx = Math.max(0, Math.min(list.length - 1, S.focus.idx));
    var el = list[S.focus.idx];
    el.classList.add('focus');
    if (el.scrollIntoView && S.focus.pane === 'secondary') el.scrollIntoView({ block: 'nearest' });
    if (S.kbMode) showTipFor(el);
  }
  function focusedTile() { if (!S.focus) return null; return paneTiles(S.focus.pane)[S.focus.idx] || null; }
  function nav(dir) {
    S.kbMode = true;
    if (!S.focus) { S.focus = { pane: 'player', idx: 0 }; applyFocus(); return; }
    var cols = COLS[S.focus.pane] || 5, n = paneTiles(S.focus.pane).length, i = S.focus.idx;
    if (dir === 'left') i = i % cols === 0 ? i : i - 1;
    if (dir === 'right') i = (i % cols === cols - 1 || i + 1 >= n) ? i : i + 1;
    if (dir === 'up') i = i - cols >= 0 ? i - cols : i;
    if (dir === 'down') i = i + cols < n ? i + cols : i;
    // crossing a column edge moves to the neighbouring panel on that side (never wraps)
    var row = Math.floor(S.focus.idx / cols);
    var side = { secondary: [null, 'player'], player: [S.views.secondary ? 'secondary' : null, S.equipCollapsed ? null : 'equip'], equip: ['player', null], hotbar: [null, null] }[S.focus.pane] || [null, null];
    if (dir === 'left' && i === S.focus.idx && i % cols === 0) {
      if (!side[0]) return;
      var lt = paneTiles(side[0]), lc = COLS[side[0]];
      S.focus = { pane: side[0], idx: Math.min(lt.length - 1, row * lc + lc - 1) }; applyFocus(); return;
    }
    if (dir === 'right' && i === S.focus.idx && (i % cols === cols - 1 || i + 1 >= n)) {
      if (!side[1]) return;
      var rc = COLS[side[1]];
      S.focus = { pane: side[1], idx: Math.min(paneTiles(side[1]).length - 1, row * rc) }; applyFocus(); return;
    }
    if (dir === 'down' && i === S.focus.idx && S.focus.pane !== 'hotbar') { S.focus = { pane: 'hotbar', idx: Math.min(4, i % cols) }; applyFocus(); return; }
    if (dir === 'up' && i === S.focus.idx && S.focus.pane === 'hotbar') { S.focus = { pane: 'player', idx: 32 + Math.min(i, 7) }; applyFocus(); return; }
    S.focus.idx = i; applyFocus();
  }
  function switchPane(d) {
    S.kbMode = true;
    var ps = panes(), cur = S.focus ? ps.indexOf(S.focus.pane) : ps.indexOf('player');
    if (cur < 0) cur = ps.indexOf('player');
    var next = ps[(cur + d + ps.length) % ps.length];
    S.focus = { pane: next, idx: 0 };
    applyFocus();
  }
  function pickPlace(mods) {
    S.kbMode = true;
    var el = focusedTile(); if (!el) { nav('none'); return; }
    var ref = el.dataset.ref, slot = Number(el.dataset.slot);
    if (!S.carry) {
      var it = itemAt(ref, slot); if (!it) return;
      S.carry = { ref: ref, slot: slot, item: it, el: el };
      el.classList.add('carry');
      return;
    }
    var src = S.carry;
    src.el.classList.remove('carry');
    S.carry = null;
    if (src.ref === ref && src.slot === slot) return;
    var tgt = { type: ref === 'equip' ? 'equip' : ref === 'hotbar' ? 'hotbar' : 'slot', ref: ref, slot: slot, el: el };
    dispatchDrop(src, tgt, mods || {});
  }
  function cancelCarry() { if (S.carry) { S.carry.el.classList.remove('carry'); S.carry = null; return true; } return false; }
  function ctxAtFocus() {
    var el = focusedTile() || (S.hover && S.tiles[S.hover.ref] && S.tiles[S.hover.ref][S.hover.slot]);
    if (!el) return;
    var r = el.getBoundingClientRect();
    openCtx(el.dataset.ref, Number(el.dataset.slot), r.right, r.top + 10);
    var first = $('ctx').querySelector('button[data-i]:not([disabled])'); if (first) first.classList.add('sel');
  }
  function useAtFocus() {
    var el = focusedTile() || (S.hover && S.tiles[S.hover.ref] && S.tiles[S.hover.ref][S.hover.slot]);
    if (!el) return;
    if (el.dataset.ref === 'hotbar') act('hotbar', { op: 'use', n: Number(el.dataset.slot) });
    else useItem(el.dataset.ref, Number(el.dataset.slot));
  }

  document.addEventListener('keydown', function (e) {
    if (!S.open) return;
    if (e.key === 'Alt') e.preventDefault();
    if (S.modal) { modalKey(e); return; }
    if (S.ctx) { ctxKey(e); return; }
    var ae = document.activeElement, typing = ae && /INPUT|SELECT|TEXTAREA/.test(ae.tagName);
    if (typing) {
      if (e.key === 'Escape' || e.key === 'Enter' || (e.key === 'ArrowDown' && ae.tagName === 'INPUT')) { e.preventDefault(); ae.blur(); if (e.key !== 'Escape') nav('none'); }
      return;
    }
    if (S.tab === '_craft' && craftKey(e)) return;
    var k = e.key;
    switch (k) {
      case 'Escape': case 'Backspace': e.preventDefault(); if (!cancelCarry()) requestClose(); return;
      case 'ArrowUp': e.preventDefault(); nav('up'); return;
      case 'ArrowDown': e.preventDefault(); nav('down'); return;
      case 'ArrowLeft': e.preventDefault(); nav('left'); return;
      case 'ArrowRight': e.preventDefault(); nav('right'); return;
      case 'Enter': case ' ': e.preventDefault(); pickPlace({ shiftKey: e.shiftKey, altKey: e.altKey, ctrlKey: e.ctrlKey }); return;
      case 'x': case 'X': case 'ContextMenu': e.preventDefault(); ctxAtFocus(); return;
      case 'y': case 'Y': e.preventDefault(); useAtFocus(); return;
      case 'q': case 'Q': case 'PageUp': e.preventDefault(); switchPane(-1); return;
      case 'e': case 'E': case 'PageDown': e.preventDefault(); switchPane(1); return;
      case '/': e.preventDefault(); $('search').focus(); return;
      case 'Tab': e.preventDefault(); switchPane(e.shiftKey ? -1 : 1); return;
      case '[': e.preventDefault(); setSecPage(S.secPage - 1); return;
      case ']': e.preventDefault(); setSecPage(S.secPage + 1); return;
    }
    if (/^[1-9]$/.test(k)) {
      var n = Number(k);
      if (n > Number(S.config.hotbarSlots || 5)) return;
      var el = (S.hover && S.hover.ref === 'player') ? S.tiles.player[S.hover.slot] : focusedTile();
      if (el && el.dataset.ref === 'player' && itemAt('player', Number(el.dataset.slot))) {
        e.preventDefault();
        var it = itemAt('player', Number(el.dataset.slot));
        if (hotkeyOf(it) === n) clearHotbar(n); else assignHotbar(n, Number(el.dataset.slot));
      }
    }
  });
  function onPad(d) {
    if (!S.open || !d) return;
    var b = d.button;
    var key = { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight', accept: 'Enter', cancel: 'Escape', x: 'x', y: 'y', lb: 'q', rb: 'e' }[b];
    if (!key) return;
    if (S.modal && (b === 'left' || b === 'right') && !S.modal.step) return;
    var ev = new KeyboardEvent('keydown', { key: key, bubbles: true, cancelable: true });
    if (document.activeElement && /INPUT|SELECT/.test(document.activeElement.tagName) && !S.modal) document.activeElement.blur();
    if (S.modal && (b === 'left' || b === 'right')) { S.modal.step(b === 'left' ? -1 : 1); return; }
    document.dispatchEvent(ev);
  }

  // ---------------------------------------------------------------- hand crafting (Craft tab)
  // Server actions: handcraftList -> { recipes, busy }; local: handcraftStart { id, qty } (client/handcraft.lua
  // closes the inventory and runs the progress). Lua -> NUI: craftProgress { label, duration, qty } | { state }.
  function craftOn() { var h = S.config.handcraft; return !!(h && h.enabled); }
  function craftReadyCount() {
    return (S.craft.list || []).filter(function (r) { return r.status === 'ready' && !(r.cooldown > 0); }).length;
  }
  function applyCraftMode() {
    var on = S.tab === '_craft' && craftOn();
    var pane = document.querySelector('.pane-main');
    if (pane) pane.classList.toggle('crafting', on);
    $('gridPlayer').classList.toggle('hidden', on);
    $('craftPanel').classList.toggle('hidden', !on);
    $('sortMode').classList.toggle('hidden', on);
    if (!on) return;
    renderCraft();
    if (!S.craft.list) loadCraft();
  }
  function scheduleCraftLoad() { clearTimeout(S.craft.timer); S.craft.timer = setTimeout(loadCraft, 250); }
  function loadCraft() {
    var seq = ++S.craft.seq;
    S.craft.loading = true;
    return post('handcraftList', {}).then(function (r) {
      if (seq !== S.craft.seq) return;
      S.craft.loading = false;
      if (!r || !r.ok) { S.craft.list = []; S.craft.err = (r && r.err) || 'nui_error'; }
      else { S.craft.list = (r.data && Array.isArray(r.data.recipes)) ? r.data.recipes : []; S.craft.err = null; }
      renderTabs();
      if (S.tab === '_craft') renderCraft();
    });
  }
  function craftVisible() {
    var q = S.search;
    return (S.craft.list || []).filter(function (r) {
      if (!q) return true;
      var hay = [r.label, r.description, r.category].concat((r.outputs || []).map(function (o) { return o.label; }))
        .concat((r.ingredients || []).map(function (g) { return g.label; })).join(' ').toLowerCase();
      return hay.indexOf(q) !== -1;
    });
  }
  function craftSel(vis) {
    vis = vis || craftVisible();
    for (var i = 0; i < vis.length; i++) if (vis[i].id === S.craft.sel) return vis[i];
    return vis[0] || null;
  }
  function craftPill(r) {
    if (r.cooldown > 0) return ['warn', T('craftWait', { s: Math.ceil(r.cooldown) })];
    if (r.status === 'ready') return ['ok', T('craftReady') + ' ×' + r.maxCraft];
    if (r.status === 'full') return ['warn', T('craftFull')];
    if (r.status === 'nearly') return ['warn', T('craftNearly')];
    return ['bad', T('craftMissing', { n: r.missing })];
  }
  function craftIcon(it, count, cls) {
    var x = { name: it.name, image: it.image, label: it.label, metadata: it.metadata || {}, count: count || 1 };
    return '<div class="tile has ' + (cls || '') + '" data-rar="1">' + tileInner(x, { noName: true, count: count || 1 }) + '</div>';
  }
  function renderCraft() {
    var list = $('craftList'), det = $('craftDetail');
    if (!S.craft.list) { list.innerHTML = '<div class="craft-empty">' + esc(T('craftLoading')) + '</div>'; det.innerHTML = ''; return; }
    var vis = craftVisible();
    if (!vis.length) {
      list.innerHTML = '<div class="craft-empty">' + esc(S.craft.err ? errText(S.craft.err) : T('craftEmpty')) + '</div>';
      det.innerHTML = '<div class="craft-empty">' + esc(T('craftHint')) + '</div>';
      return;
    }
    var sel = craftSel(vis);
    if (S.craft.sel !== sel.id) S.craft.qty = 1;
    S.craft.sel = sel.id;
    list.innerHTML = vis.map(function (r) {
      var p = craftPill(r), o = r.outputs[0];
      return '<div class="crow ' + esc(r.status) + (r.cooldown > 0 ? ' cooling' : '') + (r.id === sel.id ? ' active' : '') + '" data-id="' + esc(r.id) + '">' +
        craftIcon(o, o.count, 'crow-ico') +
        '<div class="crow-txt"><b>' + esc(r.label) + '</b><small>' + esc(r.category) + '</small></div>' +
        '<span class="rpill ' + p[0] + '">' + esc(p[1]) + '</span></div>';
    }).join('');
    var act = list.querySelector('.crow.active');
    if (act && act.scrollIntoView) act.scrollIntoView({ block: 'nearest' });
    renderCraftDetail(sel);
  }
  function craftQty(r) {
    var max = Math.max(0, Math.floor(Number(r.maxCraft) || 0));
    var q = Math.floor(Number(S.craft.qty) || 1);
    return Math.max(1, Math.min(Math.max(1, max), q));
  }
  function ingRow(g, mult) {
    var need = g.need * mult, ok = g.have >= need;
    var alts = (g.alts && g.alts.length > 1) ? '<small>' + g.alts.map(esc).join(' ' + esc(T('craftOr')) + ' ') + '</small>' : '';
    return '<div class="cing ' + (ok ? 'ok' : 'bad') + '">' + craftIcon(g, 1, 'cing-ico') +
      '<span class="cing-lbl">' + esc(g.label) + alts + '</span><b>' + esc(g.have) + ' / ' + esc(need) + '</b></div>';
  }
  function renderCraftDetail(r) {
    var det = $('craftDetail');
    if (!r) { det.innerHTML = ''; return; }
    var qty = craftQty(r); S.craft.qty = qty;
    var max = Math.max(0, Math.floor(Number(r.maxCraft) || 0));
    var can = max >= 1 && !(r.cooldown > 0) && r.status === 'ready';
    var o = r.outputs[0];
    var secs = (Number(r.time) || 0) / 1000;
    var h = '<div class="cd-head">' + craftIcon(o, o.count, 'cd-ico') +
      '<div class="cd-title"><span class="kicker">' + esc(r.category) + '</span><h3 class="stencil">' + esc(r.label) + '</h3>' +
      '<small>' + esc(T('craftTime', { s: secs % 1 === 0 ? secs : secs.toFixed(1) })) + ' · ' + esc(T('craftHint')) + '</small></div></div>';
    if (r.description) h += '<p class="cd-desc">' + esc(r.description) + '</p>';
    h += '<div class="cd-sec"><span class="rlabel">' + esc(T('craftNeeds')) + '</span>' + r.ingredients.map(function (g) { return ingRow(g, qty); }).join('') + '</div>';
    if (r.tools && r.tools.length) h += '<div class="cd-sec"><span class="rlabel">' + esc(T('craftTools')) + '</span>' + r.tools.map(function (g) { return ingRow(g, 1); }).join('') + '</div>';
    h += '<div class="cd-sec"><span class="rlabel">' + esc(T('craftMakes')) + '</span><div class="cd-makes">' + r.outputs.map(function (x) {
      return '<span class="cd-out">' + craftIcon(x, x.count * qty, 'cing-ico') + '<span>' + esc(x.label) + ' ×' + esc(x.count * qty) + '</span></span>';
    }).join('') + '</div></div>';
    if (r.knownItem) h += '<p class="m-note">' + esc(T('craftRequires', { item: r.knownItem })) + '</p>';
    h += '<div class="cd-foot"><span class="rlabel">' + esc(T('craftQty')) + '</span><div class="amount">' +
      '<button class="rbtn" type="button" data-cstep="-1"' + (can ? '' : ' disabled') + '>−</button>' +
      '<input class="rinput" type="number" min="1" max="' + Math.max(1, max) + '" value="' + qty + '" data-cqty' + (can ? '' : ' disabled') + '>' +
      '<button class="rbtn" type="button" data-cstep="1"' + (can ? '' : ' disabled') + '>+</button>' +
      '<button class="rbtn muted" type="button" data-cmax' + (can ? '' : ' disabled') + '>' + esc(T('allBtn')) + '</button></div>' +
      '<button class="rbtn primary craft-go" type="button" data-craft' + (can ? '' : ' disabled') + '>' + esc(T('craftBtn')) + (qty > 1 ? ' ×' + qty : '') + '</button></div>';
    det.innerHTML = h;
  }
  function setCraftQty(v) {
    var r = craftSel(); if (!r) return;
    S.craft.qty = v; S.craft.qty = craftQty(r);
    renderCraftDetail(r);
  }
  function stepCraftSel(d) {
    var vis = craftVisible(); if (!vis.length) return;
    var cur = craftSel(vis), i = vis.indexOf(cur);
    i = Math.max(0, Math.min(vis.length - 1, i + d));
    if (vis[i] !== cur) { S.craft.sel = vis[i].id; S.craft.qty = 1; renderCraft(); }
  }
  function startCraft() {
    var r = craftSel();
    if (!r || S.craft.starting) return;
    if (!(r.status === 'ready' && r.maxCraft >= 1 && !(r.cooldown > 0))) { toast(errText('missing'), 'bad'); return; }
    S.craft.starting = true;
    post('handcraftStart', { id: r.id, qty: craftQty(r) }).then(function (res) {
      S.craft.starting = false;
      if (!res || !res.ok) { toast(errText(res && res.err), 'bad'); scheduleCraftLoad(); }
    });
  }
  $('craftList').addEventListener('click', function (e) {
    var row = tgtEl(e).closest('.crow'); if (!row) return;
    if (row.dataset.id !== S.craft.sel) { S.craft.sel = row.dataset.id; S.craft.qty = 1; renderCraft(); }
  });
  $('craftList').addEventListener('dblclick', function (e) { if (tgtEl(e).closest('.crow')) startCraft(); });
  $('craftDetail').addEventListener('click', function (e) {
    var t = tgtEl(e), b;
    if ((b = t.closest('[data-cstep]')) && !b.disabled) { setCraftQty(S.craft.qty + Number(b.dataset.cstep)); return; }
    if ((b = t.closest('[data-cmax]')) && !b.disabled) { var r = craftSel(); if (r) setCraftQty(r.maxCraft); return; }
    if ((b = t.closest('[data-craft]')) && !b.disabled) startCraft();
  });
  $('craftDetail').addEventListener('change', function (e) {
    var t = tgtEl(e).closest('[data-cqty]'); if (t) setCraftQty(Number(t.value));
  });
  function craftKey(e) {
    switch (e.key) {
      case 'ArrowUp': e.preventDefault(); stepCraftSel(-1); return true;
      case 'ArrowDown': e.preventDefault(); stepCraftSel(1); return true;
      case 'ArrowLeft': e.preventDefault(); setCraftQty(S.craft.qty - 1); return true;
      case 'ArrowRight': e.preventDefault(); setCraftQty(S.craft.qty + 1); return true;
      case 'Enter': case ' ': case 'y': case 'Y': e.preventDefault(); startCraft(); return true;
    }
    return false;
  }
  var craftHideTimer = null;
  function onCraftProgress(d) {
    var el = $('craftProgress'), bar = $('cpBar');
    clearTimeout(craftHideTimer);
    if (!d || d.state) {
      var cancel = d && d.state === 'cancel';
      el.classList.toggle('cancel', cancel);
      if (!cancel) { bar.style.transition = 'none'; bar.style.width = '100%'; }
      craftHideTimer = setTimeout(function () { el.classList.add('hidden'); el.classList.remove('cancel'); }, cancel ? 700 : 300);
      return;
    }
    el.querySelectorAll('[data-t]').forEach(function (x) { x.textContent = T(x.dataset.t); });
    $('cpLabel').textContent = String(d.label || '') + (Number(d.qty) > 1 ? ' ×' + Number(d.qty) : '');
    el.classList.remove('cancel');
    bar.style.transition = 'none'; bar.style.width = '0%';
    el.classList.remove('hidden');
    void bar.offsetWidth;
    var ms = Math.max(0, Math.min(600000, Number(d.duration) || 0));
    bar.style.transition = 'width ' + ms + 'ms linear';
    bar.style.width = '100%';
  }

  // ---------------------------------------------------------------- toasts
  function toast(text, type) {
    if (!text) return;
    var cls = type === 'success' || type === 'ok' ? 'ok' : type === 'error' || type === 'bad' ? 'bad' : '';
    var host = $('toasts');
    var el = document.createElement('div');
    el.className = 'rtoast ' + cls;
    el.innerHTML = '<div class="plate-frame cut-toast"><div class="plate"><div class="plate-body"></div></div></div>';
    el.querySelector('.plate-body').textContent = String(text);
    host.appendChild(el);
    while (host.children.length > 4) host.removeChild(host.firstChild);
    setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 3800);
  }

  // ---------------------------------------------------------------- setup / messages
  function onSetup(d) {
    if (!d) return;
    Object.keys(d).forEach(function (k) { S.setup[k] = d[k]; });
    // sent right after every open: rebuild the equipment pane only when the slot list really changed
    if (d.categories && catSig(d.categories) !== catSig(S.cats)) { setCats(d.categories); if (S.open) renderEquip(); }
    if (S.open) { applyStrings(); renderHeader(); }
  }
  var HANDLERS = {
    open: onOpen,
    delta: onDelta,
    hotbar: function (d) { S.hotbar = Array.isArray(d) ? d : []; if (S.open) { renderHotbar(); paintAll('player'); } },
    close: hideApp,
    notify: function (d) { if (d) toast(d.text, d.type); },
    setup: onSetup,
    pad: onPad,
    ammo: function (d) { S.ammo = d; renderAmmo(); },
    craftProgress: onCraftProgress
  };
  window.addEventListener('message', function (e) {
    var m = e.data;
    if (!m || typeof m !== 'object' || !m.action) return;
    var h = HANDLERS[m.action];
    if (h) { try { h(m.data); } catch (err) { console.error('[MULTIinventory] ' + m.action + ': ' + (err && err.stack || err)); } }
  });

  // first contact: ask Lua for the setup data
  post('ready', {}).then(function (r) { if (r && r.ok && r.data) onSetup(r.data); });

  // test hook (browser harness only reads state; game code never uses it)
  window.InvUI = { state: S, toast: toast, version: '1.0.0' };
})();
