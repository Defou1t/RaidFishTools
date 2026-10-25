Raid & Fish Tools 1.3.1 - Ako/Defou1t (from Norrina-Hub by Norrina;
Fish Tracker based on Fish Track Reborn v2.2 by Wagasez, inspired by Usb)

ОБНОВЛЕНИЕ - дважды кликните update-addons.cmd в этой папке: скачает последние
версии Raid & Fish Tools и Auction Income (только установленные), сначала
сохранив копию в Addon\_backups\<дата>. whitelist.txt, настройки и записи
не затираются.

КНОПКА "Raid Tool" - окно рекрутинга (Shift + перетаскивание двигает кнопку).

FISH TRACKER - настроек нет, всегда включён. Возьмите рыбу в цель (Marlin,
Tuna, Sailfish, Sturgeon, Sunfish, Carp, Eel, Arowana, ...) - над ней появятся
иконка действия рыбы с таймером и Strength Contest. Рыбы с номером 1-9 (sign)
после смерти получают таймер 150 с по центру экрана.
Баффы видны только у рыбы в цели: игра не отдаёт аддонам баффы рыбы с номером
(sign) и наблюдаемой цели (проверено в игре). Вторую рыбу - взять в цель.

ПЕРЕДАЧА ЛИДЕРА - кодовое слово по умолчанию у всех gmlr (можно поменять в окне).
Игрок из списка lead пишет gmlr в чат рейда/группы и получает лидера.

ВАЙТЛИСТ - файл whitelist.txt в этой папке (RaidFishTools\whitelist.txt).
Создаётся сам при первом запуске; образец - whitelist.example.txt.
Формат (кавычки и запятые обязательны):

{
    lead = {
        "Name1",
        "Name2",
    },
    invite = {
        "Name3",
        "Name4",
    },
}

  lead   - кому можно передать лидера рейда кодовым словом
           (вместе с полем "Give lead whitelist" в окне);
  invite - кого приглашать при "Whitelist Only: ON"
           (вместе с полем "Whitelist" в окне). Ники из lead тоже приглашаются.
Можно добавлять и свои группы, например  Guild = { "Name5", "Name6" },  -
они считаются как invite. Регистр букв не важен.
После правки файла нажмите "Reload file" в окне Raid Tool; рядом видно,
сколько ников загружено: "File: 9, lead 1".

Настройки окна хранятся в Addon\raidfish_data.lua.
