# 00 — Ориентирование: как устроена модовая разработка в Noita

Это карта местности. Здесь нет «как сделать мод», здесь — **где лежит правда** и какие
грабли разложены на пути. Всё ниже проверено на твоей локальной установке.

Версия игры: `_version_hash.txt` = `9dbd52ced019a643169a2db02f46c77f8766c6e5`, ветка `master`.
Modding API версия: **12**.

---

## 1. Где лежит правда (локальные источники, в порядке полезности)

| Путь | Что это |
| --- | --- |
| `tools_modding/lua_api_documentation.txt` | **Главный документ.** ~360 функций API v12. `lua_api_documentation.html` — то же с поиском. |
| `tools_modding/component_documentation.txt` | Список компонентов (ECS) и их полей — нужен, когда лезешь в `ComponentGetValue2`. |
| `tools_modding/luacheck_config.lua` | Готовый конфиг линтера со списком **всех** глобальных API-функций. Идеально для IDE/CI: не даст опечататься и перепутать контексты. |
| `tools_modding/lua_debugging.txt` | Как отлаживать: Decoda IDE + `noita_dev.exe -debug_lua`, точки останова, `_G` в Watch. |
| `mods/example/` | Минимальный пример: mod.xml, init.lua со всеми хуками, файлы, настройки. |
| `mods/nightmare/` | **Эталон кастомной генерации**: `files/biome_map.lua` переписывает карту биомов, `init.lua` правит параметры биомов. |
| `mods/daily_practice/` | Пер-слот варианты `magic_numbers` + `biome_map_0N.lua`, чтение ванильной карты по пикселям. |
| `mods/starting_loadouts/` | Как выдавать игроку стартовые жесты/спеллы (пригодится для M4). |
| `mods/quant.ew/` | Установленный Entangled Worlds — твой сетевой слой. |
| `mods/noita_entangled_worlds-master/` | Исходники EW: Lua + Rust (прокси) + `docs/` + `ew_api_example/`. |
| `noita_dev.exe` | Dev-сборка: включает `EntitySave` и прочие dev-плюшки. Играть/тестировать лучше через неё. |
| `logger.txt` в корне Noita | Лог **движка** (запуск, ошибки загрузки, Steam). Вывод Lua сюда не попадает — см. §6. |
| `ew_log.txt` в корне Noita | Лог EW. |

## 2. Ванильные исходники: где их читать

Игра поставляет весь ванильный контент упакованным в `data/data.wak` (42 МБ). Пока он
упакован, ты не можешь прочитать ванильные `data/biome/*.xml`, `data/scripts/**/*.lua`,
`data/entities/**`. А это 90% ответов на вопрос «а как это сделано в оригинале».

**Ванильные исходники распакованы в профиле игры.** Туда их положила распаковка `data.wak`
(см. ниже) — полное дерево ванильных `data/`:

```
%USERPROFILE%\AppData\LocalLow\Nolla_Games_Noita\data\
```

На момент проверки там **14 745 файлов: 1077 `.lua` и 4325 `.xml`** — включая всё, что нужно:
`scripts\lib\utilities.lua`, `scripts\items\generate_shop_item.lua`,
`scripts\perks\perk_list.lua` (124 КБ), `biome\coalmine.xml`,
`entities\items\pickup\chest_random.xml`, `magic_numbers.xml`.

Это тот же ванильный код **от твоей версии игры**, поэтому вопрос «а как это сделано
в оригинале» решается грепом **здесь**, а не в зеркалах. Оговорка: после обновления игры
каталог может обновляться не сразу.

**Альтернатива — зеркало на GitHub**, если нужен поиск по коду в вебе или каталога нет:
[NathanSnail/noitadata](https://github.com/NathanSnail/noitadata). Может быть на другой
версии игры.

**Как получить это дерево.** По `tools_modding/READ_ME_FIRST.txt`: скопировать файлы из
`tools_modding/` в корень Noita и запустить `data_wak_unpack.bat`
(это `noita.exe -wizard_unpak`). По факту дерево оказалось именно в профиле игры, а не
в корне Noita — путь см. выше.

Дополнительно стоит положить в `tools_modding/` бинарник `luacheck.exe`
(ссылка в `lua_debugging.txt`) — тогда `luacheck_all.bat` начнёт проверять твой мод.

## 3. Анатомия мода

```
mods/synergis/
  mod.xml            манифест: имя, описание, флаги доступа к API
  init.lua           код в СОБСТВЕННОМ Lua-контексте мода
  settings.lua       настройки (УРЕЗАННЫЙ контекст: без io/os/dofile)
  files/             файлы мода, адресуются как mods/synergis/files/...
  data/              файлы с путями игры: ПЕРЕОПРЕДЕЛЯЮТ ванильные data/...
  data/generated/    автогенерируемое (sprite_uv_maps), руками не трогать
  compatibility.xml  version_built_with (необязательно)
  workshop.xml       для выгрузки в Workshop
  workshop_preview_image.png  16:9, для Workshop
```

Важные атрибуты `mod.xml` (полный список — на
[вики](https://noita.wiki.gg/wiki/Modding:_mod.xml)):

- `request_no_api_restrictions="1"` — даёт `os.*` и `io.*`.
  Цитата из официального шаблона: *«If a mod requires access to the full lua api e.g. os.* io.*
  it has to request access via 'request_no_api_restrictions="1"'. It is recommended that other
  options are explored first, as we may completely disable those APIs in the future.»*

  **Уточнение с вики, которое легко упустить:** флаг действует **только на контекст
  `init.lua`**. `LuaComponent` и прочие контексты остаются урезанными — то есть `io.*`
  в скрипте сущности не появится, сколько бы флагов ты ни ставил.

  Следствие: **такие моды не работают через Steam Workshop.**
- `is_game_mode="1"` — мод появляется в меню **New Game** как отдельный игровой режим
  и активируется, когда игрок его выбирает. Сопутствующие:
  `game_mode_supports_save_slots="1"` (несколько слотов сохранения),
  `ui_newgame_name`, `ui_newgame_description`,
  `ui_newgame_gfx_banner_bg` / `ui_newgame_gfx_banner_fg` (баннеры 64×36, путь обязательно
  полный, вида `mods/synergis/files/...`).

  **Для Synergis это рабочий вариант** — проверено, что он совместим с прокси EW.
  Что он даёт, чего стоит и какие таблицы в EW после этого сломаются —
  см. [`docs/08-game-mode.md`](08-game-mode.md).

## 4. Контексты Lua — главная ловушка для новичка

Noita исполняет Lua в **нескольких независимых Lua-стейтах**. Это не один общий `_G`.

1. **Контекст мода.** `init.lua` и `settings.lua` каждого мода. У каждого мода свой.
   Здесь доступны все игровые API-функции, но *твои собственные* функции не видны никому
   снаружи. `dofile_once` кэширует файл **внутри этого контекста**.
2. **Контекст игры.** `data/scripts/**/*.lua` и скрипты сущностей (`LuaComponent`,
   `script_item_picked_up` и т.п.). Тоже свой стейт. Функции из `data/scripts/lib/utilities.lua`
   живут здесь.
3. **Контекст EW** (см. `docs/02`) — отдельный стейт внутри мода `quant.ew`. Туда можно
   «дописать» свой модуль через `ModLuaFileAppend`.

Следствие: **`init.lua` не может просто так вызвать функцию из скрипта сущности и наоборот.**
Мосты между контекстами:

| Мост | Направление | Комментарий |
| --- | --- | --- |
| `ModLuaFileAppend(game_file, your_file)` | твой код → в контекст игры | Твой файл дописывается в конец ванильного. Классический приём: переопределить функцию, сохранив оригинал (`ew_orig_... = generate_shop_item`). |
| `ModTextFileSetContent(path, content)` | подменить файл игры целиком | Мощно и опасно. EW так вырезает часть сущностей. |
| `ModMagicNumbersFileAdd(path)` | подмешать magic_numbers | Так подключается своя `BIOME_MAP` и другие константы генерации. |
| `GlobalsSetValue/GlobalsGetValue` | общая шина, **сохраняется в сейв** | Так pvp.lua в EW передаёт `ew_floor`, `ew_player_count`. |
| `SessionNumbersSet/GetValue` | на текущую сессию | Не переживает сейв. |
| `GameAddFlagRun/GameHasFlagRun` | флаги забега | EW использует для идемпотентности спавна (`spwn_<fn>_<x>_<y>`). |
| `ModSettingGet("synergis.<id>")` | настройки | Самый простой способ донести конфиг до любого контекста. |
| `np.CrossCallAdd(name, fn)` / `CrossCall(name, ...)` | между контекстами | Это **NoitaPatcher**, не ваниль. Работает только если мод грузит `noitapatcher.dll` (так делает EW). Именно так EW зовёт свой сетевой код из скриптов сущностей. |

## 5. Практические правила гигиены

- **Никогда не полагайся на порядок загрузки модов.** Проверяй `ModIsEnabled("quant.ew")`,
  `ModDoesFileExist(...)`.
- **Защищайся от nil.** `ComponentGetValue2` возвращает nil при неверном имени поля, и падение
  скрипта не всегда видно: в `logger.txt` попадает только движковое, а вывод Lua надо
  организовать самому (§6).
- **Линтер.** Гоняй `luacheck` с `luacheck_config.lua`: он знает список API и ловит
  `undefined variable`, что в Lua без компилятора — половина всех ошибок.
- **Отладка.** Decoda + `noita_dev.exe -debug_lua` (`lua_debugging.txt`). `_G` в Watch-окне
  показывает весь стейт контекста. Помни, что контекстов несколько — смотри нужный.
- **Хот-релоада Lua в Noita нет.** Правка скриптов = перезапуск игры (или, для скриптов
  сущностей, иногда достаточно перезайти в забег). Планируй итерации соответственно:
  сначала алгоритм проверяй на «сухих» данных, потом в игре.
- **Не пиши в `data/generated/`** — это автогенерация.

## 6. Куда попадает вывод: `print`, `GamePrint`, логи

Самая частая потеря времени на старте — писать `print` и не находить его нигде.

| Способ | Куда идёт | Когда работает |
| --- | --- | --- |
| `print(...)` | в **стандартный вывод процесса**. При обычном запуске консоли нет, поэтому вывод **теряется** | в любом контексте, в любой момент |
| `GamePrint(...)` | в **ленту сообщений на экране** | только когда есть запущенный мир |
| `GamePrintImportant(...)` | заметное сообщение вместо строчки в ленте | когда есть мир |
| свой файл через `io.open(path, "a")` | в **файл, который ты сам выбрал** | нужен `request_no_api_restrictions="1"` |

**`logger.txt` в корне Noita — это лог движка, а не Lua.** Туда попадают запуск, ошибки
загрузки файлов, проблемы Steam и статистики. Ни `print`, ни `GamePrint` там не появляются:
проверено поиском по всем `.txt` в корне игры и в `mods` — строк мода на диске нет вообще.

**Что делать.** Для «сработал ли хук» достаточно `GamePrint` — видно прямо в игре. Как только
понадобится история, которую можно грепать, заводи свой лог-файл:

```lua
-- нужен request_no_api_restrictions="1" в mod.xml
local function log(msg)
    local f = io.open("mods/synergis/debug.log", "a")
    if f ~= nil then
        f:write(tostring(msg) .. "\n")
        f:close()
    end
end
```

Флаг `request_no_api_restrictions` действует **только на контекст `init.lua`** (см. §3),
и закрывает дорогу в Steam Workshop — для этого проекта неважно, EW всё равно требует
unsafe mods.

Ещё есть `F9 — Toggle Log levels` и `SHIFT+F9 — Clears the debug log` из
`data/debug_keys.txt`: у движка есть уровни логирования. Влияет ли это на Lua-`print`,
не проверено.

## 7. Куда идти дальше

- `docs/01-worldgen-and-seed.md` — процедурная генерация и сид.
- `docs/02-multiplayer-entangled-worlds.md` — вся сетевая часть (и почему писать своё не надо).
- `docs/03-voice-chat.md` — **хорошая новость**: голосовой чат в EW уже есть.
- `docs/04-battle-royale-plan.md` — дизайн БР и план по этапам.
- `docs/05-prior-art.md` — что уже сделали до тебя (и что из этого можно читать как учебник).
