# Raid & Fish Tools

ArcheAge Classic addon by **Ako/Defou1t**.
Raid Tool and Fish Tracker are taken from [Norrina-Hub](https://github.com/r3d3r1c/norrina-craft-tracker) by **Norrina**; the Fish Tracker there is based on Fish Track Reborn v2.2 by **Wagasez**, inspired by Usb. All credit for the original code goes to them.

## Установка

1. Скачайте `RaidFishTools-<версия>.zip` со страницы [Releases](../../releases).
2. Распакуйте в папку аддонов так, чтобы получилось `Документы\AAClassic\Addon\RaidFishTools\main.lua` (рядом с `addons.txt`; если «Документы» в OneDrive — `OneDrive\Documents\AAClassic\Addon`).
3. В игре откройте окно **Addons** и включите **Raid & Fish Tools** (или допишите строку `RaidFishTools` в `Addon\addons.txt` и перезапустите игру).
4. На экране появится кнопка **Raid Tool** (Shift + перетаскивание — сдвинуть).

**Обновление** — дважды кликните `update-addons.cmd` в папке аддона: он скачает последние версии Raid & Fish Tools и Auction Income (только те, что у вас уже стоят), сначала сохранив копию в `Addon\_backups\<дата>`. Ваш `whitelist.txt`, настройки (`Addon\raidfish_data.lua`) и записи Auction Income не затираются. Можно и вручную: распакуйте новую версию поверх — результат тот же.

**1.3.1:** Fish Tracker больше не перерисовывает иконки, тексты и позицию каждый кадр (только когда они изменились, 10 раз в секунду). С 22.10 игра часто падала в рендере (`CryRenderD3D10.dll`); старая версия за 30 кадров с одной рыбой 60 раз заново ставила текстуру иконки.

## Raid Tool

- **Recruit phrases** — фразы через запятую (например `x dis, x event`). Кто напишет такую фразу в чат, получит приглашение в рейд (нужно быть лидером рейда). Один игрок — не чаще раза в 30 секунд.
- **Whitelist Only: ON** — приглашать только ники из вайтлиста (поле в окне + файл).
- **Blacklist** — никогда не приглашать.
- **Your raid role** — Tank / Healer / DPS.
- **Передача лидерства**: участник пишет в чат рейда/группы кодовое слово **`gmlr`** — и получает лидера, если он в списке `lead` (или в поле «Give lead whitelist») и включено **Lead Protection: ON**. Кодовое слово по умолчанию у всех одинаковое — `gmlr`; его можно поменять в окне.

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

После правки нажмите **Reload file** в окне Raid Tool — рядом видно, сколько загружено: `File: 5, lead 2`.

## Fish Tracker

Всегда включён, настроек нет. Возьмите рыбу в цель (Marlin, Tuna, Sailfish, Sturgeon, Sunfish, Carp, Eel, Arowana, …) — над ней появятся иконка её действия с таймером и Strength Contest. Рыбы с номером 1–9 (sign) после смерти получают таймер 150 с по центру экрана.

Ограничение игры: аддонам доступны баффы только рыбы **в цели** — ни по номеру (sign), ни через наблюдаемую цель (watch target) игра их не отдаёт (проверено в игре).

---

## English

Raid auto-invite by chat phrases, whitelist (window + `whitelist.txt` with `lead` / `invite` lists), blacklist, raid roles, raid lead handoff by the code word `gmlr` (default for everyone, changeable), and a fish buff tracker (always on, for the targeted fish). Unzip into `Documents\AAClassic\Addon\` so that you get `Addon\RaidFishTools\main.lua`, enable it in the in-game Addons window. Fill `RaidFishTools\whitelist.txt` like `whitelist.example.txt`, then press **Reload file**.

**Update:** double-click `update-addons.cmd` in the addon folder — it backs up to `Addon\_backups\<date>` and installs the latest releases of the addons you have; `whitelist.txt`, settings and Auction Income records are kept. **1.3.1** stops the Fish Tracker from resetting icon textures, texts and anchors on every frame (the game crashed in its renderer several times a day since 2026-10-22).
