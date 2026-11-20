// MULTIbank passbook. Shows what the server sends; every action goes back to the server.
(function () {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const root = $('bank');
    let state = null;
    let sending = false;
    let L = {};
    let quick = [];
    let built = false;

    // locale line; %s markers are filled in order, %% is a literal %
    function t(key, ...args) {
        let i = 0;
        const s = L[key] != null ? String(L[key]) : key;
        return s.replace(/%%|%[sd]/g, (m) => (m === "%%" ? "%" : (args[i++] ?? "")));
    }
    function applyLocale() {
        document.querySelectorAll("[data-l]").forEach((el) => { el.textContent = t(el.dataset.l); });
        document.querySelectorAll("[data-lp]").forEach((el) => { el.placeholder = t(el.dataset.lp); });
    }

    const KIND_CLASS = { deposit: "in", withdraw: "out", transfer_out: "out", transfer_in: "in", gold_buy: "gold", gold_sell: "gold", credit: "in", debit: "out", box_rent: "out", box_fee: "out", money_clip: "out" };

    function post(name, data) {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'MULTIbank';
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false }));
    }

    function group(d) { return d.replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
    // $1,234<sup>56</sup> for balances; plain = $1,234.56 for ledger lines
    function money(n, plain) {
        n = Number(n) || 0;
        const neg = n < 0;
        const [d, c] = Math.abs(n).toFixed(2).split('.');
        if (plain) return `${neg ? '-' : ''}$${group(d)}.${c}`;
        return `${neg ? '-' : ''}$${group(d)}<span class="mc-cents">${c}</span>`;
    }
    function goldAmt(n) { return (Number(n) || 0).toFixed(2); }
    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    }
    function date(ts) {
        if (!ts) return '';
        const d = new Date(ts * 1000);
        const hh = String(d.getHours()).padStart(2, '0');
        const mm = String(d.getMinutes()).padStart(2, '0');
        return `${t("ui_months").split(",")[d.getMonth()] || ""} ${d.getDate()}, ${hh}:${mm}`;
    }
    function readAmount(id) {
        const v = $(id).value.trim().replace(',', '.');
        if (!/^\d{1,9}(\.\d{1,2})?$/.test(v)) return null;
        const n = Number(v);
        return n > 0 ? n : null;
    }
    function say(text, ok) {
        const m = $('msg');
        m.textContent = text || '';
        m.className = 'msg ' + (text ? (ok ? 'ok' : 'bad') : '');
    }

    function renderLedger(rows) {
        const box = $('ledger');
        if (!rows || !rows.length) { box.innerHTML = `<div class="empty">${esc(t("ui_empty"))}</div>`; return; }
        box.innerHTML = rows.map((r) => {
            const k = [L["k_" + r.kind] != null ? t("k_" + r.kind) : r.kind, KIND_CLASS[r.kind] || ""];
            const isGold = k[1] === 'gold';
            const sign = k[1] === 'out' ? '-' : (k[1] === 'in' ? '+' : '');
            const amt = isGold ? `${goldAmt(r.amount)} g` : sign + money(r.amount, true);
            const bal = r.balance_after == null ? '' : (isGold ? `${goldAmt(r.balance_after)} g` : money(r.balance_after, true));
            return `<div class="entry"><span class="date">${date(r.t)}</span>` +
                `<span class="what">${esc(k[0])}${r.other ? `<small>${esc(r.other)}</small>` : ''}</span>` +
                `<span class="num ${k[1]}">${amt}</span><span class="num">${bal}</span></div>`;
        }).join('');
    }

    function render(s) {
        state = s;
        $("bankName").textContent = s.bank || t("title");
        $('holder').textContent = s.holder || '';
        $('charId').textContent = s.charId != null ? '#' + s.charId : '';
        $('citizenid').textContent = s.citizenid || '';
        $('cash').innerHTML = money(s.cash);
        $('balance').innerHTML = money(s.balance);
        $('gold').innerHTML = goldAmt(s.gold);
        $('accountLabel').textContent = t(s.account === "bank" ? "ui_in_bank" : "ui_in_this_bank");
        $('goldBuy').innerHTML = money(s.goldBuy);
        $('goldSell').innerHTML = money(s.goldSell);
        $('tabTransfer').classList.toggle('mc-hidden', !s.transferEnabled);
        $('tabGold').classList.toggle('mc-hidden', !s.goldEnabled);
        $('tabClip').classList.toggle('mc-hidden', !s.moneyClip);
        $('sdBtn').classList.toggle('mc-hidden', !s.safeDeposit);
        $("clipNote").textContent = t("ui_clip_hint", group(String(s.clipMax || 0)), t(s.clipFrom === "bank" ? "ui_pay_bank" : "ui_pay_cash"));
        $("depNote").textContent = t("ui_limit", group(String(s.maxDeposit)));
        $("wdNote").textContent = t("ui_limit", group(String(s.maxWithdraw))) + (s.withdrawFee > 0 ? " " + t("ui_fee", s.withdrawFee) : "");
        $("trNote").textContent = t("ui_limit", group(String(s.maxTransfer))) + (s.transferFee > 0 ? " " + t("ui_fee", s.transferFee) : "");
        updateGoldNote();
        renderLedger(s.history);
    }

    function updateGoldNote() {
        if (!state) return;
        const g = readAmount('goldAmount');
        const pay = esc(t(state.goldPayWith === "bank" ? "ui_pay_bank" : "ui_pay_cash"));
        $("goldNote").innerHTML = g
            ? esc(t("ui_gold_preview", "{1}", "{2}", "{3}")).replace("{1}", money(g * state.goldBuy, true)).replace("{2}", money(g * state.goldSell, true)).replace("{3}", pay)
            : esc(t("ui_gold_hint", "{1}", state.goldMax)).replace("{1}", pay);
    }

    function quickButtons() {
        document.querySelectorAll('.quick').forEach((row) => {
            const input = row.dataset.for;
            (quick.length ? quick : []).forEach((v) => {
                const b = document.createElement('button');
                b.className = 'mc-btn small';
                b.textContent = '$' + v;
                b.onclick = () => { $(input).value = v; };
                row.appendChild(b);
            });
            const all = document.createElement('button');
            all.className = 'mc-btn small';
            all.textContent = t("ui_all");
            all.onclick = () => { if (state) $(input).value = Math.max(0, Number(state[row.dataset.max]) || 0).toFixed(2); };
            row.appendChild(all);
        });
    }

    function showTab(name) {
        document.querySelectorAll('.mc-tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
        document.querySelectorAll('.pane').forEach((p) => p.classList.toggle('mc-hidden', p.dataset.pane !== name));
        say('');
    }

    async function act(action, data) {
        if (sending) return;
        sending = true;
        const res = await post('action', { action, data });
        sending = false;
        if (res && res.state) render(res.state);
        say(res && res.msg, res && res.ok);
        return res;
    }

    // ---------- wiring ----------
    document.querySelectorAll('.mc-tab').forEach((t) => { t.onclick = () => showTab(t.dataset.tab); });
    document.querySelectorAll('[data-act]').forEach((b) => {
        b.onclick = async () => {
            const amount = readAmount(b.dataset.input);
            if (amount == null) { say(t("ui_err_amount"), false); return; }
            const data = { amount };
            if (b.dataset.act === 'transfer') {
                data.target = $('trTarget').value.trim();
                if (!data.target) { say(t("ui_err_target"), false); return; }
            }
            const res = await act(b.dataset.act, data);
            if (res && res.ok) $(b.dataset.input).value = '';
        };
    });
    $('trFind').onclick = async () => {
        const target = $('trTarget').value.trim();
        $('trPayee').textContent = '';
        if (!target) return;
        const res = await act('lookup', { target });
        if (res && res.ok && res.extra) $("trPayee").textContent = t("ui_payee", res.extra.name, res.extra.id);
    };
    $('trTarget').oninput = () => { $('trPayee').textContent = ''; };
    $('goldAmount').oninput = updateGoldNote;
    $('close').onclick = () => post('close');
    $('sdBtn').onclick = () => post('safedeposit');

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !root.classList.contains('mc-hidden')) post('close');
    });

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === "open") {
            L = d.L || {};
            root.classList.toggle("mc-cyrillic", d.lang === "ru");
            if (!built) { built = true; quick = Array.isArray(d.quick) ? d.quick.filter((v) => Number(v) > 0) : []; quickButtons(); }
            applyLocale();
            render(d.state || {});
            showTab('deposit');
            root.classList.remove('mc-hidden');
        } else if (d.action === 'close') {
            root.classList.add('mc-hidden');
            state = null;
        }
    });
})();
