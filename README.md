# Raid Tools (formerly Raid & Fish Tools)

ArcheAge Classic addon by **Ako/Defou1t**.
The Raid Tool is taken from [Norrina-Hub](https://github.com/r3d3r1c/norrina-craft-tracker) by **Norrina**. All credit for the original code goes to them.

> **1.4.0: the Fish Tracker moved to [Auction Income](https://github.com/Defou1t/AuctionIncome) 1.10.0** (button **Fish: On/Off** in its main window). `update-addons.cmd` installs Auction Income by itself where it is missing. The folder stays `RaidFishTools`, so settings and the whitelist carry over.
>
> **1.4.0: Fish Tracker переехал в [Auction Income](https://github.com/Defou1t/AuctionIncome) 1.10.0** (кнопка **Fish: On/Off** в его главном окне). `update-addons.cmd` сам поставит Auction Income, если его нет. Папка остаётся `RaidFishTools`, настройки и вайтлист сохраняются.

## Установка

1. Скачайте `RaidFishTools-<версия>.zip` со страницы [Releases](../../releases).
2. Распакуйте в папку аддонов так, чтобы получилось `Документы\AAClassic\Addon\RaidFishTools\main.lua` (рядом с `addons.txt`; если «Документы» в OneDrive — `OneDrive\Documents\AAClassic\Addon`).
3. В игре откройте окно **Addons** и включите **Raid Tools** (или допишите строку `RaidFishTools` в `Addon\addons.txt` и перезапустите игру).
4. На экране появится кнопка **Raid Tool** (Shift + перетаскивание — сдвинуть).

**Обновление** — дважды кликните `update-addons.cmd` в папке аддона: он скачает последние версии Raid Tools и Auction Income, сначала сохранив копию в `Addon\_backups\<дата>`. Ваш `whitelist.txt`, настройки (`Addon\raidfish_data.lua`) и записи Auction Income не затираются. Можно и вручную: распакуйте новую версию поверх — результат тот же.

**1.4.0:** вайтлист в окне = файл `whitelist.txt`: поля Whitelist и Give lead whitelist показывают ники из файла, Save записывает их обратно, ники из Блокнота подтягиваются при открытии окна; лимита на число ников нет. Fish Tracker переехал в Auction Income.

**1.3.2:** иконки под рыбой снова двигаются за ней каждый кадр (в 1.3.1 позиция обновлялась 10 раз в секунду и иконки отставали при повороте камеры); баффы и таймеры по-прежнему 10 раз в секунду.

**1.3.1:** Fish Tracker больше не перерисовывает иконки, тексты и позицию каждый кадр (только когда они изменились, 10 раз в секунду). С 22.10 игра часто падала в рендере (`CryRenderD3D10.dll`); старая версия за 30 кадров с одной рыбой 60 раз заново ставила текстуру иконки.

## Raid Tool

- **Recruit phrases** — фразы через запятую (например `x dis, x event`). Кто напишет такую фразу в чат, получит приглашение в рейд (нужно быть лидером рейда). Один игрок — не чаще раза в 30 секунд.
- **Whitelist Only: ON** — приглашать только ники из вайтлиста (`whitelist.txt`).
- **Blacklist** — никогда не приглашать.
- **Your raid role** — Tank / Healer / DPS.
- **Передача лидерства**: участник пишет в чат рейда/группы кодовое слово **`gmlr`** — и получает лидера, если он в списке `lead` (поле «Give lead whitelist») и включено **Lead Protection: ON**. Кодовое слово по умолчанию у всех одинаковое — `gmlr`; его можно поменять в окне.

### Вайтлист — `RaidFishTools\whitelist.txt`

Файл создаётся сам при первом запуске. Заполните его по образцу `whitelist.example.txt` (кавычки и запятые обязательны, регистр букв не важен):

```lua
{
    lead = {
        "Nickname1",
        "Nickname2",
    },
    invite = {
        "Nickname3",
        "Nickname4",
    },
}
```

- `lead` — кому можно передать лидера рейда кодовым словом (их тоже приглашает).
- `invite` — кого приглашать при «Whitelist Only: ON».
- Можно добавлять свои группы, например `Guild = { "Nickname6", },` — они считаются как `invite`.

Окно показывает этот файл и пишет в него: поле **Whitelist** — все ники, кроме `lead`, поле **Give lead whitelist** — ники из `lead`. Правьте где удобнее: в окне (**Save** записывает файл, свои группы сохраняются) или в Блокноте (ники подтянутся при открытии окна или по **Reload file**). Лимита на число ников нет; если игра всё же обрежет длинный список в поле, Save его не тронет — тогда правьте в Блокноте. Рядом с Reload file видно, сколько загружено: `File: 5, lead 2`. Ники, вписанные в окне до 1.4.0, при первом запуске переносятся в файл.

## Fish Tracker

С версии 1.4.0 — в [Auction Income](https://github.com/Defou1t/AuctionIncome) (кнопка **Fish: On/Off**).

---

## English

Raid auto-invite by chat phrases, whitelist (window + `whitelist.txt` with `lead` / `invite` lists), blacklist, raid roles, raid lead handoff by the code word `gmlr` (default for everyone, changeable). Since 1.4.0 the window shows and writes `whitelist.txt` (no limit on names; Notepad edits show up when the window opens), and the fish tracker lives in Auction Income 1.10.0. Unzip into `Documents\AAClassic\Addon\` so that you get `Addon\RaidFishTools\main.lua`, enable it in the in-game Addons window. Fill `RaidFishTools\whitelist.txt` like `whitelist.example.txt` or type the names in the window.

**Update:** double-click `update-addons.cmd` in the addon folder — it backs up to `Addon\_backups\<date>` and installs the latest releases of Raid Tools and Auction Income; `whitelist.txt`, settings and Auction Income records are kept. **1.3.1** stops the Fish Tracker from resetting icon textures, texts and anchors on every frame (the game crashed in its renderer several times a day since 2026-10-22). **1.3.2** moves the icons with the fish every frame again (1.3.1 lagged behind when the camera turned); buffs and timers still refresh 10 times a second. **1.4.0** whitelist in the window = `whitelist.txt`; the Fish Tracker moved to Auction Income.
