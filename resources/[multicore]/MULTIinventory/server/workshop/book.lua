-- ============================================================
-- MULTIinventory :: server/workshop/book.lua
--
-- The Crafting Journal (Config.CraftBook, config_workshop.lua): the hand-craft
-- recipes read and made from a book. Crafting itself stays in
-- server/handcraft/handcraft.lua (same validation, busy lock, anti-dupe, log).
--
--   use crafting_journal          -> MULTIinventory:cl:bookOpen (BookData)
--   bookOpen { chapter }          -> BookData            (client re-opens the book after a craft)
--   bookList {}                   -> { recipes, station }
--   use <recipe book item>        -> learns every recipe with unlock = that item
--   use <recipe page item>        -> learns ONE recipe: metadata.recipe, or a random unknown one from the
--                                    item's pool (Config.CraftBook.recipePapers) - loot-table friendly
--   copy:<recipe id>              -> hidden hand recipe "write a copy" (paper + ink -> recipe page with
--                                    metadata.recipe); only for recipes the writer has learned
--   starter journal               -> every character gets one journal, once (Config.CraftBook.starterJournal)
--
-- Learned keys (multiinv_recipes_known.book): '<book item>' | 'recipe:<recipe id>' | '@starter_journal'
-- BookData = { title, chapter, chapters = { { key, label, blurb } }, station, maxQuantity, recipes }
-- Exports: LearnRecipeBook(src, item)  KnowsRecipeBook(src, item)  LearnRecipe(src, recipeId)
--          KnowsRecipe(src, recipeId)  GiveRecipePage(src, recipeId|nil, item|nil) -> ok
-- ============================================================

CraftBook = CraftBook or {}

local CB = Config.CraftBook or { mode = 'tab' }
local HC = Config.HandCraft or {}
local RP = CB.recipePapers or {}
local L = WorkshopLogic

local learned = {}   -- [charId] = { [key] = true }
local STARTER = '@starter_journal'

local function bookMode() return CB.mode == 'book' end

local function charOf(src)
    local st = State.get(src)
    return st and st.charId or nil
end

-- recipe page items (loot pools + the written copy item)
local PAPER = {}
for name in pairs(RP.pools or {}) do PAPER[name] = true end
if RP.writtenItem then PAPER[RP.writtenItem] = true end
CraftBook.isPaper = function(item) return PAPER[item] == true end

-- ------------------------------------------------------------
-- what a character has learned
-- ------------------------------------------------------------
function CraftBook.loadLearned(charId)
    charId = math.tointeger(tonumber(charId))
    if not charId then return {} end
    local t = {}
    for _, r in ipairs(InvDB.query('SELECT `book` FROM `multiinv_recipes_known` WHERE `charid` = ?', { charId })) do
        if type(r.book) == 'string' then t[r.book] = true end
    end
    learned[charId] = t
    return t
end

local function learnedOf(charId)
    if not charId then return {} end
    return learned[charId] or CraftBook.loadLearned(charId)
end

local function record(charId, key)
    InvDB.update('INSERT IGNORE INTO `multiinv_recipes_known` (`charid`, `book`, `learned_at`) VALUES (?, ?, ?)',
                 { charId, key:sub(1, 64), Util.now() })
    learnedOf(charId)[key] = true
end

function CraftBook.knows(src, key)
    return learnedOf(charOf(src))[key] == true
end

local function recipeKey(id) return 'recipe:' .. tostring(id) end

function CraftBook.knowsRecipe(src, r)
    if not r.unlock then return true end
    local known = learnedOf(charOf(src))
    if known[recipeKey(r.id)] then return true end
    return not PAPER[r.unlock] and known[r.unlock] == true   -- a page item never teaches a whole group
end

HandCraft.isLearned = function(src, r) return CraftBook.knowsRecipe(src, r) end

HandCraft.hasBook = function(src, counts)
    if not bookMode() or CB.requireBook == false then return true end
    return (counts[CB.item] or 0) > 0
end

---Recipes a book teaches: { { id, label }, ... }
function CraftBook.recipesOf(bookItem)
    local out = {}
    for id, r in pairs(HandCraft.all()) do
        if r.unlock == bookItem and r.enabled and not r.hidden then out[#out + 1] = { id = id, label = r.label } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function takeOne(src, c, stackId, item)
    local ctx = { src = src, reason = 'learn', from = c.id }
    local ok = false
    if stackId then ok = Inv.removeStack(c, stackId, 1, ctx) end
    if not ok then ok = Inv.remove(c, item, 1, nil, ctx) end
    return ok and true or false
end

local function logLearn(src, charId, c, item, recipes)
    if InvLog then
        InvLog.write('learn', { actorSrc = src, targetCharId = charId, from = c and c.id or nil, item = item, count = 1,
                                data = { recipes = recipes } })
    end
end

---A recipe book: every recipe with unlock = bookItem. free = true: without taking the book (exports / admin)
function CraftBook.learn(src, bookItem, stackId, free)
    local charId = charOf(src)
    if not charId then return false, 'player_not_loaded' end
    local teaches = CraftBook.recipesOf(bookItem)
    if #teaches == 0 then return false, 'nothing_to_learn' end
    local known = learnedOf(charId)
    if known[bookItem] then return false, 'already_known' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    if (CB.recipeBooks or {}).consumeOnRead ~= false and not free then
        if not takeOne(src, c, stackId, bookItem) then return false, 'missing' end
    end
    record(charId, bookItem)
    logLearn(src, charId, c, bookItem, teaches)
    return true, teaches
end

---One recipe (a recipe page, or an export).
function CraftBook.learnRecipe(src, recipeId, stackId, item, free)
    local charId = charOf(src)
    if not charId then return false, 'player_not_loaded' end
    local r = HandCraft.get(recipeId)
    if not r or not r.enabled or r.hidden then return false, 'nothing_to_learn' end
    if CraftBook.knowsRecipe(src, r) then return false, 'already_known' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    if not free then
        if not takeOne(src, c, stackId, item) then return false, 'missing' end
    end
    record(charId, recipeKey(r.id))
    logLearn(src, charId, c, item or 'export', { { id = r.id, label = r.label } })
    return true, { { id = r.id, label = r.label } }
end

---Random recipe from a page item's pool that the reader does not know yet (weighted). nil when none.
function CraftBook.pickFromPool(src, item, rand)
    local pool = (RP.pools or {})[item]
    if type(pool) ~= 'table' then return nil end
    local cands, total = {}, 0
    for _, e in ipairs(pool) do
        local r = type(e) == 'table' and HandCraft.get(e.recipe) or nil
        local w = type(e) == 'table' and L.num(e.weight) or nil
        if r and r.enabled and not r.hidden and w and w > 0 and not CraftBook.knowsRecipe(src, r) then
            cands[#cands + 1] = { id = r.id, w = w }
            total = total + w
        end
    end
    if #cands == 0 then return nil end
    local roll = (rand or math.random)() * total
    for _, x in ipairs(cands) do
        roll = roll - x.w
        if roll <= 0 then return x.id end
    end
    return cands[#cands].id
end

---Read a recipe page item (the used stack).
function CraftBook.readPage(src, itemTable)
    local item = itemTable.name or itemTable.item
    local meta = itemTable.metadata or {}
    local id = type(meta.recipe) == 'string' and meta.recipe or nil
    if not id then
        id = CraftBook.pickFromPool(src, item)
        if not id then return false, 'pool_known' end
    end
    return CraftBook.learnRecipe(src, id, itemTable.id, item, false)
end

-- ------------------------------------------------------------
-- "write a copy": hidden hand recipes copy:<id> (paper + ink -> a page with metadata.recipe)
-- ------------------------------------------------------------
function CraftBook.pageMeta(r)
    return { recipe = r.id, label = 'Recipe: ' .. r.label,
             description = ('A handwritten recipe for %s. Read it to learn it.'):format(r.label) }
end

function CraftBook.registerCopies()
    local cp = RP.copy or {}
    if cp.enabled == false or not RP.writtenItem then return 0 end
    local n = 0
    for id, r in pairs(HandCraft.all()) do
        if r.unlock and r.copyable ~= false and not r.copyOf and not r.hidden then
            local ok = HandCraft.register('copy:' .. id, {
                label = 'Write a copy: ' .. r.label, category = r.category, hidden = true, copyOf = id,
                ingredients = cp.ingredients, tools = cp.tools,
                outputs = { { item = RP.writtenItem, count = 1, metadata = CraftBook.pageMeta(r) } },
                time = cp.time or 8000, maxQuantity = 5,
            }, 'workshop')
            if ok then n = n + 1 end
        end
    end
    return n
end

-- ------------------------------------------------------------
-- book data
-- ------------------------------------------------------------
local stationLabel = function(key)
    local t = Stations and Stations.typeOf and Stations.typeOf(key)
    return t and t.label or key
end

function HandCraft.chapterOf(r) return L.chapterOf(r.category, CB.chapters) end

HandCraft.decorateView = function(v, r, src, counts, locked)
    v.chapter = L.chapterOf(r.category, CB.chapters)
    if r.station then v.stationLabel = stationLabel(r.station) end
    if r.unlock then
        if PAPER[r.unlock] then
            v.unlockLabel = 'a recipe page'
        else
            local b = ((CB.recipeBooks or {}).items or {})[r.unlock]
            local d = Registry.get(r.unlock)
            v.unlockLabel = (d and d.label) or (b and b.label) or r.unlock
        end
        if not locked then
            v.learned = true
            local cr = src and HandCraft.get('copy:' .. r.id)
            local cv = cr and HandCraft.view(src, cr, counts or {})
            if cv then
                v.copy = { id = cv.id, label = 'Write a copy', status = cv.status, maxCraft = cv.maxCraft, time = cv.time,
                           ingredients = cv.ingredients, tools = cv.tools, outputs = cv.outputs }
            end
        end
    end
end

---Chapters in book order. With `recipes`, only chapters that hold at least one of them
---(job chapters stay out of other players' books).
function CraftBook.chapters(recipes)
    local used
    if recipes then
        used = {}
        for _, v in ipairs(recipes) do if v.chapter then used[v.chapter] = true end end
    end
    local out = {}
    for _, ch in ipairs(CB.chapters or {}) do
        if not used or used[ch.key] then out[#out + 1] = { key = ch.key, label = ch.label, blurb = ch.blurb } end
    end
    return out
end

function CraftBook.data(src, chapter)
    local recipes, err = HandCraft.list(src, { book = true })
    if not recipes then return nil, err end
    return {
        title = CB.title or 'Crafting Journal',
        chapter = type(chapter) == 'string' and chapter:sub(1, 32) or nil,
        chapters = CraftBook.chapters(recipes),
        station = Stations and Stations.current and Stations.current(src) or nil,
        maxQuantity = HC.maxQuantity or 20,
        recipes = recipes,
    }
end

function CraftBook.open(src, chapter)
    if not HC.enabled then return false, 'disabled' end
    local data, err = CraftBook.data(src, chapter)
    if not data then return false, err end
    TriggerClientEvent('MULTIinventory:cl:bookOpen', src, data)
    return true
end

-- ------------------------------------------------------------
-- starter journal (once per character; existing characters get it on their next login)
-- ------------------------------------------------------------
function CraftBook.giveStarter(src, charId)
    if not (HC.enabled and bookMode() and CB.starterJournal ~= false and CB.item) then return false, 'off' end
    charId = math.tointeger(tonumber(charId)) or charOf(src)
    if not charId then return false, 'player_not_loaded' end
    if learnedOf(charId)[STARTER] then return false, 'already_given' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    if Inv.count(c, CB.item) == 0 then
        local ok, why = Inv.add(c, CB.item, 1, nil, { src = src, reason = 'starter', to = c.id })
        if not ok then return false, why end   -- no room: try again next login
        Sync.notify(src, 'You have a Crafting Journal - use it to see what you can make.', 'inform')
    end
    record(charId, STARTER)
    return true
end

-- ------------------------------------------------------------
-- actions + usables
-- ------------------------------------------------------------
Actions.register('bookList', function(src)
    if not HC.enabled then return false, 'disabled' end
    local recipes, err = HandCraft.list(src, { book = true })
    if not recipes then return false, err end
    return true, { recipes = recipes, station = Stations and Stations.current and Stations.current(src) or nil }
end)

Actions.register('bookOpen', function(src, d)
    if not HC.enabled then return false, 'disabled' end
    local data, err = CraftBook.data(src, d.chapter)
    if not data then return false, err end
    return true, data
end)

local LEARN_MSG = {
    already_known = 'You already know what is written here.',
    nothing_to_learn = 'There is nothing in here you can use.',
    pool_known = 'Nothing on this page is new to you - someone else might want it.',
    missing = 'You no longer have it.',
}

local RES = GetCurrentResourceName()

local function learned_dialog(src, title, list)
    local labels = {}
    for _, x in ipairs(list) do labels[#labels + 1] = x.label end
    TriggerClientEvent('MULTIinventory:cl:recipesLearned', src, { book = title, recipes = labels })
end

if HC.enabled and bookMode() and CB.item then
    Usables.register(CB.item, function(data)
        local ok, err = CraftBook.open(data.source)
        if not ok and err then Sync.notify(data.source, HandCraft.REASON[err] or 'You cannot read that now.', 'error') end
    end, RES)
end

do
    local books = {}
    for name in pairs(((CB.recipeBooks or {}).items) or {}) do books[name] = true end
    for _, r in pairs(HC.recipes or {}) do if type(r) == 'table' and type(r.unlock) == 'string' then books[r.unlock] = true end end
    for name in pairs(books) do
        if not PAPER[name] then
            Usables.register(name, function(data)
                local src = data.source
                local ok, res = CraftBook.learn(src, name, data.item and data.item.id)
                if not ok then Sync.notify(src, LEARN_MSG[res] or 'You cannot read that now.', 'error') return end
                local d = Registry.get(name)
                learned_dialog(src, d and d.label or name, res)
            end, RES)
        end
    end
    for name in pairs(PAPER) do
        Usables.register(name, function(data)
            local src = data.source
            local ok, res = CraftBook.readPage(src, data.item or {})
            if not ok then Sync.notify(src, LEARN_MSG[res] or 'You cannot read that now.', 'error') return end
            local d = Registry.get(name)
            learned_dialog(src, (data.item and data.item.label) or (d and d.label) or 'the page', res)
        end, RES)
    end
end

CraftBook.registerCopies()

Config.Log = Config.Log or {}
Config.Log.actions = Config.Log.actions or {}
if Config.Log.actions.learn == nil then Config.Log.actions.learn = true end

InvHooks.register('characterLoaded', function(src, charId)
    CreateThread(function()
        CraftBook.loadLearned(charId)
        Wait(5000)   -- let the character finish loading before handing anything over
        if State.get(src) and State.get(src).charId == charId then CraftBook.giveStarter(src, charId) end
    end)
end)
InvHooks.register('characterUnloaded', function(src, charId)
    learned[math.tointeger(tonumber(charId)) or -1] = nil
end)

exports('LearnRecipeBook', function(src, item) return CraftBook.learn(tonumber(src), item, nil, true) == true end)
exports('KnowsRecipeBook', function(src, item) return CraftBook.knows(tonumber(src), item) end)
exports('LearnRecipe', function(src, recipeId) return CraftBook.learnRecipe(tonumber(src), recipeId, nil, nil, true) == true end)
exports('KnowsRecipe', function(src, recipeId)
    local r = HandCraft.get(recipeId)
    return r ~= nil and CraftBook.knowsRecipe(tonumber(src), r)
end)
---Give a recipe page: recipeId = that recipe (a "written" page), nil = a random page of `item`'s pool.
exports('GiveRecipePage', function(src, recipeId, item)
    src = tonumber(src)
    local c = src and Actions.ref(src, 'player')
    if not c then return false end
    if recipeId then
        local r = HandCraft.get(recipeId)
        if not r or not RP.writtenItem then return false end
        return Inv.add(c, RP.writtenItem, 1, CraftBook.pageMeta(r), { src = src, reason = 'api', to = c.id }) == true
    end
    item = item or RP.writtenItem
    if not PAPER[item] then return false end
    return Inv.add(c, item, 1, nil, { src = src, reason = 'api', to = c.id }) == true
end)

CraftBook._learned = learned   -- tests
