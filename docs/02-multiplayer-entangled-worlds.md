# 02 — Мультиплеер: Quant's Entangled Worlds

## 0. Короткий вывод

**Свою сетевую часть писать не надо и практически невозможно.** В ванильном Lua-API нет ни
сокетов, ни сети. Единственный работающий путь в Noita — Entangled Worlds, и он даёт:
сетевой транспорт, RPC, синхронизацию игроков/предметов/врагов/пикселей мира и **уже готовый
позиционный голосовой чат** (см. `docs/03`).

Твоя задача — не «сделать мультиплеер», а **встроиться в EW** и написать поверх него логику БР.

Цена вопроса: ты навсегда зависишь от чужого мода, который ломается при обновлениях игры,
и чьи внутренности не обещают стабильности. Ниже — как минимизировать этот риск.

---

## 1. Архитектура EW из трёх частей

```
┌─────────────────────────────┐
│ noita_proxy.exe  (Rust)     │  отдельное приложение-лончер:
│  - GUI-настройки            │  хостит/подключается (Steam lobby или IP:port),
│  - Steam networking / UDP   │  ставит мод, ЗАПУСКАЕТ игру, синхронизирует мир,
│  - мир, карта, аудио        │  позиционный голосовой чат
└──────────┬──────────────────┘
           │ TCP/sockets (локально)
┌──────────┴──────────────────┐
│ noita.exe + ewext.dll       │  ewext.dll — Lua C-модуль (Rust),
│  ← грузится через           │  вставляет в Lua функции ewext.*
│    NoitaPatcher             │
└──────────┬──────────────────┘
           │ require("ewext")
┌──────────┴──────────────────┐
│ mods/quant.ew  (Lua)        │  init.lua + files/core + files/system + files/api
│  - ctx, net, RPC, системы   │  логика синхронизации
└─────────────────────────────┘
```

Как EW грузит нативный код (`mods/quant.ew/init.lua`, строки 1–13) — это **важно**, потому что
ровно так же ты сможешь подгрузить свой нативный модуль, если когда-нибудь понадобится:

```lua
dofile_once("mods/quant.ew/NoitaPatcher/load.lua")   -- подменяет do_mod_appends, чтобы
np = require("noitapatcher")                          -- прописать package.cpath/package.path
package.cpath = package.cpath .. ";./mods/quant.ew/?.dll"
package.path  = package.path  .. ";./mods/quant.ew/?.lua"
ewext = require("ewext")                              -- ← вот загрузка C-модуля
```

То есть: `noitapatcher.dll` → `noitapatcher` (API NoitaPatcher) → `ewext.dll` (API EW).
`NoitaPatcher` даёт в том числе `np.CrossCallAdd(name, fn)` — мост между Lua-контекстами.

## 2. Транспорт: что уходит в сеть

`mods/quant.ew/files/core/net.lua` — весь низкий уровень. Сообщение = строка, первый байт —
тип:

| Байт | Тип | Содержимое |
| --- | --- | --- |
| `1` | `mod` (RPC) | 8 байт peer_id (hex) + `bitser`-сериализованный `{key=..., value=...}` |
| `2` | `proxy` (строка) | `"<key> <value> [value2]"` — опции от прокси: `seed`, `peer_id`, `host_id`, `proxy_opt*`, `dc`, `leave` |
| `3` | `proxy` (бинарь) | `[key_byte] <binary>` — например, чанки мира (`proxy_bin_send`) |

Публичный API `net`:

```lua
net.new_rpc_namespace()              -- namespace с автоиндексом (для внутренних систем EW)
net.new_rpc_namespace_with_id(id)    -- ← используй ЭТО: префиксует индексы твоим id
net.send(key, value, reliable)
net.send_to_host(key, value, reliable)  -- ВНИМАНИЕ: реализовано как net.send, т.е. broadcast
                                        -- (в исходнике стоит "TODO actually only send to host")
net.proxy_send(key, value)              -- строковое сообщение в прокси
net.proxy_bin_send(key_byte, value)     -- бинарное сообщение в прокси
net.estimate_rpc_size(message)          -- прикинуть размер до отправки
```

**Ключевое ограничение: транспорт широковещательный.** Отдельного «клиент → только хост»
канала нет. Значит host-authoritative логику строишь так: рассылаешь всем, а выполняешь
только под `if ctx.is_host then ... end`.

## 3. Как встроиться: официальный стабильный API

`mods/quant.ew/files/api/ew_api.lua` — 13 строк, и это **единственное, что автор EW обещает
не менять** («Parts of EW api that are guaranteed to be stable»):

```lua
ew_api.new_rpc_namespace(id)   -- создать RPC-пространство имён
ew_api.rpc_player_data()       -- внутри rpc: данные игрока, который его вызвал
```

Подключение (это то, что ты напишешь в своём `init.lua`, на этапе загрузки мода):

```lua
if ModIsEnabled("quant.ew") then
    ModLuaFileAppend("mods/quant.ew/files/api/extra_modules.lua",
                     "mods/synergis/files/net/module.lua")
end
```

`extra_modules.lua` — это список файлов, которые EW исполняет **в своём контексте**.
Твой модуль должен вернуть таблицу; всё, что начинается с `on_`, EW вызовет как хук.
Полный список хуков — `mods/noita_entangled_worlds-master/docs/hooks.md`:

```
ctx.hook.on_world_initialized()
ctx.hook.on_new_entity(ents)
ctx.hook.on_world_update()               -- OnWorldPreUpdate
ctx.hook.on_world_update_post()
ctx.hook.on_world_update_client()        -- только клиенты
ctx.hook.on_world_update_host()          -- только хост
ctx.hook.on_new_player_seen(new_playerdata, player_count)
ctx.hook.on_local_player_spawn(my_player)
ctx.hook.on_client_spawned(peer_id, new_playerdata)
ctx.hook.on_should_send_updates()
ctx.hook.on_draw_debug_window(imgui)
ctx.hook.on_local_player_polymorphed(currently_polymorphed)
ctx.hook.on_client_polymorphed(peer_id, player_data)
ctx.hook.on_late_init()
```

То есть `on_world_update_host` уже даёт тебе готовое разделение «хост/клиент» — на нём и
строится БР-loop.

## 4. RPC: синтаксис и правила

Из `net.lua` (строки 57–94) и `ew_api_example/module.lua`:

```lua
local rpc = ew_api.new_rpc_namespace("synergis")   -- уникальный короткий id

rpc.opts_reliable()     -- доставить гарантированно и по порядку
rpc.opts_everywhere()   -- вызвать и у отправителя тоже
function rpc.spawn_zone(cx, cy, radius)            -- ← сразу после opts
    -- ctx.rpc_peer_id  = кто вызвал
    -- ctx.rpc_player_data = { name = ..., ... }
end
```

Правила, которые легко нарушить:

1. **`opts_*()` действуют на СЛЕДУЮЩЕЕ объявление функции** и потом сбрасываются.
2. `ctx.rpc_peer_id` / `ctx.rpc_player_data` не nil **только внутри вызова rpc**. Вне вызова —
   используй `ctx.players[peer_id]`.
3. `rpc.create_var(name, cb)` создаёт синхронизируемую переменную: `var.set(v)`, `var.values[peer_id]`,
   `var.prev_values[peer_id]`. Удобно для «состояния матча» и настроек хоста.
4. **Не занимай строковые ключи в `net_handling.mod`** — это общее пространство имён с внутренними
   системами EW (`inventory`, `perks`, `fire`, `welcome`, `join_notify`). Используй
   `new_rpc_namespace_with_id`, он нумерует ключи с префиксом твоего id.
5. Для «дешёвых» вещей (позиция, таймер) не ставь `opts_reliable()` — надёжная доставка дороже.
   И наоборот: спавн, смерть, конец матча — только reliable.

## 5. Что тебе даёт `ctx` (состояние сессии)

```lua
ctx.my_id        -- твой peer_id (строка-hex)
ctx.host_id      -- peer_id хоста
ctx.is_host      -- ctx.my_id == ctx.host_id
ctx.players      -- { [peer_id] = player_data }
ctx.my_player    -- твой player_data
ctx.run_ended
ctx.proxy_opt    -- настройки, присланные ПРОКСИ (см. ниже!)
```

`player_data` (по использованию в `pvp.lua`, `player_tether.lua`, `net.lua`):

```lua
p.entity, p.name, p.pos_x, p.pos_y, p.mouse_x, p.mouse_y,
p.is_alive, p.status.is_alive, p.last_hit, p.dc (disconnected)
```

## 6. Настройки: proxy_opt ≠ mod setting

Это неочевидно и важно. Часть конфигурации приходит **от прокси**, а не из `settings.lua` мода.
Прокси отправляет их сообщениями `proxy_opt`, `proxy_opt_num`, `proxy_opt_bool`
(`noita-proxy/src/net/proxy_opt.rs`) и их принимает `net_handling.proxy.proxy_opt*`.

Что EW так получает (по использованиям в Lua): `pvp`, `pvp_kill_steal`, `chest_on_win`,
`timed`, `time_in`, `time_out`, `wait_on_players`, `wait_for_time`, `perma_death`,
`no_notplayer`, `dont_steal`, `debug`, `log_performance`.

**Плохая новость:** игровой режим в прокси — это **захардкоженный Rust-enum**
(`noita-proxy/src/lib.rs`, строка 72):

```rust
pub enum GameMode { SharedHealth, LocalHealth(LocalHealthMode) }
enum LocalHealthMode { Normal, Alternate, PermaDeath, PvP }
```

Он выбирается в GUI прокси и уезжает в Steam-lobby data. **Свой режим туда не добавить без
форка прокси.**

**Практический вывод для БР:**

- Все свои настройки держи в `settings.lua` мода и читай через `ModSettingGet("synergis.*")` —
  это работает без единой правки прокси.
- Режим бери из существующих: `LocalPermadeath` (идеально для БР: умер = выбыл) или `PvP`.
- Форк прокси нужен только если захочешь: свой пункт режима в лобби, свой сетевой канал,
  или глубокую интеграцию с голосом. Это отдельный проект на Rust, не начинай с него.

**Не путай это с игровым режимом Noita.** Здесь речь про модель здоровья в прокси.
Отдельный пункт в меню New Game со своими сейвами и своими `magic_numbers` — это
**другая, независимая вещь** (`is_game_mode="1"` в `mod.xml`), и она совместима с EW.
См. [`docs/08-game-mode.md`](08-game-mode.md).

## 7. Что EW уже синхронизирует (не переписывай!)

Из README EW: позиции игроков, здоровье, перки, инвентари, использование жезлов, использование
предметов, предметы в мире (один бросил — другой поднял), враги и их атаки, **пиксели мира**,
грибные сдвиги, полиморф.

Плюс в `files/system/` лежит много готового, что для БР переиспользуется почти как есть:

| Система | Что там полезного для БР |
| --- | --- |
| `pvp/pvp.lua` | **Главный источник вдохновения.** `chunks_by_floor` (координаты всех биомов), `teleport_into_biome()` (высадка в случайный чанк + безопасность + приземление), таймеры раундов (`timed`, `time_in`, `time_out`), учёт `player_died` по раундам, `rpc.win()`, кража золота у убитого, таблица побед в Holy Mountain. |
| `player_tether/` | Механика «удержания игрока в радиусе» через `ParticleEmitterComponent` + телепорт. Готовый каркас **границы зоны**. Ставь `tetherrange = 0`, чтобы выключить. |
| `local_health/` | Локальное здоровье, perma-death, `notplayer`, эффекты респауна/смерти. |
| `spectate/` | Наблюдение за другими после смерти — в БР обязательно. |
| `item_sync.lua` | `ctx.cap.item_sync.globalize(eid, instantly, give_authority_to)` — **как правильно спавнить предмет, чтобы его увидели все.** |
| `gen_sync/` | Образец host-authoritative генерации: спавн-функции выполняются на хосте, а клиенты просят хоста через `rpc.remote_run_spawn_fn`. |
| `damage/` | Как наносить урон через сеть (сравни с `local_health`, выбери одну capability). |
| `nickname.lua`, `player_arrows/`, `map/`, `player_ping/`, `text.lua` | UI: подписи над игроками, стрелки, карта, пинг. Для HUD БР — бери готовое. |
| `flag_sync/` | Синхронизация `GameHasFlagRun` — чтобы флаги забега совпадали у всех. |
| `wang_hooks/` | Перехват вановой генерации мира; нужен при кастомной генерации. |
| `world_sync/`, `streaming_sync/` | Синхронизация мира и стриминга. Не трогай, просто знай что есть. |

## 8. Ловушки, на которые ты обязательно наткнёшься

1. **Локальный спавн предмета не синхронизируется.** Если ты сделал `EntityLoad("...wand...")`,
   его увидишь только ты. Варианты: (а) `ctx.cap.item_sync.globalize(eid, instantly, peer_id)`;
   (б) генерировать лут на **всех** клиентах через `ProceduralRandom(x, y)` — тогда спавнить
   вообще не надо синхронизировать.
2. **`SetRandomSeed`/`Random` глобальны для контекста.** Рандом «в цикле по игрокам» даст
   разное на разных машинах. Сидируй детерминированно или считай только на хосте.
3. **Внутренности EW не стабильны.** Стабилен только `ew_api.lua`. Значит: пинить версию EW,
   писать защитно (`if ctx.players[id] == nil then return end`), не полагаться на поля
   `player_data`, которых нет в `ew_api`.
4. **Нет античита и нет авторитетности.** Клиент сам сообщает свои попадания. Для игры
   с друзьями — нормально; для публичного лобби — нет.
5. **Все игроки должны иметь одинаковый набор модов и версий.** Один лишний мод = рассинхрон.
   Прокси это проверяет и ругается.
6. **`request_no_api_restrictions="1"` не совместим с Steam Workshop.** Если мод нужен
   в Workshop — придётся отказаться от `io`.
7. **EW ломается при обновлениях Noita.** У него своя версия совместимости (`compatibility.xml`,
   `NP_SKIP_MOD_CHECK`). После патча игры жди обновления EW, а не правь его сам.
8. **Unsafe mods обязательны.** В меню модов надо включить «unsafe mods», иначе EW не загрузится.
9. **Порядок загрузки.** Не полагайся на то, что EW уже инициализирован в момент твоего
   `init.lua`. Всё, что требует EW, делай в хуках, а не на этапе загрузки файла.

## 9. Как тестировать мультиплеер в одиночку

Практические находки из репозитория EW:

- Прокси сам умеет запускать игру, и ему можно указать команду запуска:
  `noita_proxy --launch-cmd "noita.exe -gamemode 0"` (см. `Justfile`, цель `run2`).
- Переменные окружения: `NP_NOITA_ADDR` (адрес, куда прокси подключается к игре),
  `NP_APPID` (подменить app id, чтобы не мешать Steam), `NP_SKIP_MOD_CHECK=1`.
- Хостинг/подключение из CLI: `noita_proxy --host 5123` (или `--host steam`),
  `noita_proxy --lobby <code/ip:port>`.
- Для двух клиентов на одной машине нужно два экземпляра игры + два прокси с разными портами.
  Это неудобно, но выполнимо; альтернатива — вторая машина или виртуалка.

## 10. Рекомендованный порядок освоения

1. Запустить EW в кооперативе с одним другом. Убедиться, что вообще работает, посмотреть
   `ew_log.txt` и `logger.txt`.
2. Добавить в свой модуль один `print` в `on_world_update` и один RPC — убедиться, что
   видишь **peer_id, host_id и ники** с обеих сторон.
3. Только после этого начинать логику БР.

Если шаг 1 не работает — дальше идти бессмысленно, и проблема почти всегда в версии
игры/EW или в наборе модов.
