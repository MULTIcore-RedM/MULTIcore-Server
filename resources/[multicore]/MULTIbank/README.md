# MULTIbank

Banks for MULTIcore servers: deposit, withdraw, transfer between characters (online or offline), a gold exchange and a passbook history. RSG v2 and VORP scripts keep working, because every balance lives in MULTIcore's normal `players.money` (`cash`, `bank`, `gold`).

GPL v3, like MULTIcore.

## What it does

- **Five banks**: Valentine, Rhodes, Saint Denis, Blackwater, Armadillo (list in `config.lua`, add or remove freely).
- **Teller**: MULTItarget on the counter and the clerk ("Open bank", Left Alt), or a hold-key prompt when MULTItarget is not running (`Config.Interact`). Clerk NPC, map blips, bank doors set to open / locked. `/mcinteract` (MULTIcore) prints what was placed to the server console.
- **Bank doors and MULTIdoors**: when MULTIdoors runs (`Config.Doors.DoorScript`), the bank leaves its doors alone and MULTIdoors locks them (keys, law access, lockpicking). Without MULTIdoors the bank sets the door states in `Config.Doors.List`.
- **Opening hours** on the in-game clock (off by default).
- **Passbook page** (NUI, MULTIcore theme): cash, bank and gold balances; deposit; withdraw; transfer; gold buy / sell; ledger of the last entries.
- **Transfers** by character number (`players.id`, shown as "Account #12") or citizen id. The recipient may be offline (`Config.Transfer.AllowOffline`). The payee's name can be looked up before sending.
- **Gold exchange** at fixed prices (`Config.Gold`), paid in cash or from the account.
- **History** in table `multicore_bank_log` (created on start), old rows pruned after `Config.History.KeepDays`.
- **Safe-deposit boxes** (needs MULTIinventory): the **Safe-deposit box** button on the passbook opens a menu to rent a box (three sizes, `Config.SafeDeposit.Tiers`), open it, pay the rent or give it up. The box opens next to the satchel as a MULTIinventory storage `custom:safedeposit:<citizenid>:<bank id>`, or one box per character usable at every bank (`...:all`, `PerBank = false`). Rent is a fee every `PeriodDays` real days (`Billing = 'monthly'`, the first period is paid when renting) or one price for good (`'once'`); a box with rent due stays shut until it is paid; up to `MaxPrepaid` periods can be paid ahead. Paid from the account of the bank (or cash, `PayWith`). Only an empty box can be given up. Rentals live in `multicore_bank_boxes`; the items in MULTIinventory's `inventories` table. A client can never open a box by id (MULTIinventory's `Config.ServerOpenOnly`), only through the counter, and items can only be moved while standing within `MaxUseDistance` of the counter.
- **Money clips** (needs MULTIinventory): the **Clip** tab folds cash (or the account, `Config.MoneyClip.From`) into a `money_clip` item holding `info.money`; using the clip anywhere gives the cash back. Clips can be stored, traded and handed over like any item.

## Safety

- Every money change runs on the server through MULTIcore's `Player.Functions.AddMoney / RemoveMoney`; the page only asks.
- Amounts: numbers only, cents kept, no negatives, NaN, infinity or values over the limits (`Config.MaxDeposit`, `MaxWithdraw`, `MaxTransfer`, `Gold.MaxPerTrade`, `HardCap`).
- The player must stand at a bank counter for every action (`Config.MaxUseDistance`, needs OneSync).
- Spam guard per player (`Config.RateLimit`) and one action at a time.
- If the second half of a move fails (e.g. the credit), the first half is refunded.
- **Offline transfers** write one atomic SQL statement that only changes the one key inside `players.money` (JSON_SET), and only when the character is not loaded. If the character logs in at the exact same moment, a warning is printed in the server console.

## Setup

1. Put `MULTIbank` in `resources/[multicore]/`.
2. `server.cfg`, after MULTIcore and before RSG / VORP scripts:
   ```
   ensure MULTIbank
   ```
3. Remove `rsg-banking` from the server: MULTIbank stands in for it (`provide 'rsg-banking'`).
4. Needs `oxmysql`, `ox_lib`, `MULTIcore`; `MULTItarget` recommended (used automatically when it runs); `MULTIinventory` (started before MULTIbank) for safe-deposit boxes and money clips. Tables are created on first start.

## Config (`config.lua`)

Every option has a comment. The main ones:

| Option | Default | What |
|---|---|---|
| `Locale` | `''` | language for this script; empty = `setr multicore_locale`, else English |
| `Interact` | `'auto'` | `'auto'` (MULTItarget when it runs, else prompts), `'target'` or `'prompt'` |
| `PromptKey` | `'J'` | key name from MULTIcore's keybinds |
| `PromptDistance` | `2.0` | metres from the counter at which the prompt shows (prompt mode) |
| `Hours.Enabled` | `false` | opening hours on the game clock |
| `SeparateTownAccounts` | `false` | `true` = each bank has its own account (RSG v2 `valbank`, `rhobank`, ...) |
| `MaxDeposit / MaxWithdraw / MaxTransfer` | 100000 / 100000 / 50000 | per action |
| `WithdrawFeePercent / TransferFeePercent` | 0 | fees |
| `Transfer.AllowOffline` | `true` | send to offline characters |
| `Gold.BuyPrice / SellPrice / PayWith` | 25 / 20 / `'cash'` | gold exchange |
| `GiveCash.Max / MaxDistance` | 5000 / 5.0 | rsg-banking's hand-cash event |
| `History.Rows / KeepDays` | 40 / 90 | passbook lines, pruning |
| `RateLimit` | 6 per 3 s | spam guard |
| `Npc`, `Blips`, `Doors` | on | clerk, map blips, door states (skipped while `Doors.DoorScript`, default MULTIdoors, runs) |
| `SafeDeposit.Enabled / PerBank / Billing` | `true` / `true` / `'monthly'` | boxes on, one per bank, fee per period (`'once'` = one price) |
| `SafeDeposit.PeriodDays / MaxPrepaid / PayWith` | 30 / 3 / `'bank'` | real days per fee, periods payable ahead, `'bank'` or `'cash'` |
| `SafeDeposit.Tiers` | small 10 slots 10 kg $5.00 or $0.50 a period; medium 20 / 25 kg $10.00 or $1.00; large 40 / 60 kg $20.00 or $2.00 | sizes and prices |
| `MoneyClip.Enabled / Item / From / Max` | `true` / `'money_clip'` / `'cash'` / 1000 | money clips |
| `Banks` | 5 banks | id, rsg-banking town name, locale key of the name, moneytype, counter coords, clerk spot |

Texts are in `locales/*.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr; English is the master). Bank names are locale keys (`bank_valentine`, ...). Restyle the page in `html/custom.css`.

## Exports (server)

```lua
exports.MULTIbank:GetBalance(src [, account])     -- number, 'bank' unless an allowed town account is named
exports.MULTIbank:AddBank(src, amount, reason)    -- true / false, logged in the passbook
exports.MULTIbank:RemoveBank(src, amount, reason) -- true / false (false if the account holds too little)

-- job / society accounts (table multicore_bank_accounts)
exports.MULTIbank:GetAccountBalance(name)               -- number, 0 if the account does not exist
exports.MULTIbank:AddAccountMoney(name, amount, reason) -- true / false
exports.MULTIbank:RemoveAccountMoney(name, amount, reason) -- true / false
```

## rsg-banking compatibility

MULTIbank answers to the name `rsg-banking`, so RSG v2 scripts that call the bank keep working:

| rsg-banking name | Kind | What MULTIbank does |
|---|---|---|
| `exports['rsg-banking']:GetAccountBalance(name)` | export | society balance (number, 0 = no such account). rsg-core's paycheck code uses it when `PayCheckSociety` is on. |
| `exports['rsg-banking']:RemoveMoney(name, amount, reason)` | export | takes money from the society account, false if too little |
| `exports['rsg-banking']:AddMoney(name, amount, reason)` | export | adds money to the society account |
| `rsg-banking:server:transact (type, amount, moneytype)` | server event | 1 = withdraw, 2 = deposit, run with the same checks as the passbook at the bank the player stands at; 3 = money clip (`amount` folded into a `money_clip` item with `info.money`, taken from `Config.MoneyClip.From`; rsg-banking took it from the account) |
| `rsg-banking:server:givemoney (targetServerId, amount)` | server event | hands cash to a player within `GiveCash.MaxDistance`, limit `GiveCash.Max` |
| `rsg-banking:server:opensafedeposit (town)` | server event | opens the player's box at the bank they stand at (`town` = `Valentine`, `Rhodes`, `SaintDenis`, `Blackwater`, `Armadillo`, as rsg-banking sends); with no box yet or rent due, opens the rent / pay menu instead |
| `money_clip` item (usable) | item | using it gives `info.money` back as cash, as with rsg-banking |
| `rsg-banking:getBankingInformation (moneytype)` | RSGCore callback | `{ bank = balance, cash = cash }` |
| `rsg-banking:client:OpenBanking` | client event | opens the passbook of the bank the player stands at |
| `rsg-banking:client:UpdateBanking (balance, moneytype)` | client event | sent after every change, for HUDs that listen |

The names and argument shapes were taken from rsg-banking (RSG v2 framework, GPL v3); the code is MULTIbank's own.

## Credits

- Bank counter coordinates, clerk spots, door hashes and the blip style come from the `rsg-banking` config of the RSG v2 framework (GPL v3), by the RSG team.
- Built for MULTIcore, which is built on rsg-core 2.4.1 (GPL v3).
