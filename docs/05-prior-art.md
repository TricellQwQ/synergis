# 05 — Что уже сделано до тебя (prior art)

Читать чужие проекты — самый быстрый способ научиться. Здесь только то, что напрямую
относится к твоей идее.

## 1. Noita Arena — ближайший родственник. Читать первым

- Код: <https://github.com/EvaisaDev/noita-arena>
- Автор: EvaisaDev. Использует его же фреймворк Noita Online.
- **EW прямо благодарит его: «@EvaisaDev for allowing to use code from Noita Arena mod»** —
  то есть в `pvp.lua` из EW лежит код, выросший из Арены.

Из README (по состоянию на момент проверки):

> - Rounds style online PvP.
> - Completely configurable lobbies, with settings for basically everything imaginable.
> - **A death zone to keep people from flying off into space. (Can be made to move over time for that fortnite experience)**
> - A card system ... players get to pick a card whenever the round ends.
> - Different types of shops ...
> - Lobby presets, configurable blacklists, in-game scoreboard, ready indicator
> - **Custom map support**, skin editor, cosmetics

**Что это значит для тебя.** Практически всё, кроме «большого мира с высадкой и лутом
по всей карте», уже сделано кем-то, и сделано в жанре «PvP-арена с раундами и сужающейся
зоной». Твоя реальная новизна:

- БР-петля **на всём мире Noita** (высадка в разные биомы, лут по всей карте), а не на арене;
- прогрессия/эскалация через глубину биомов;
- голосовой чат (в Арене его не было; в EW есть).

То есть ты не изобретаешь жанр с нуля — ты переносишь его на другой масштаб мира.
Это хорошая новость: есть у кого подсмотреть решения (особенно зону и лобби).

## 2. Noita Entangled Worlds — твоя база

- Код: <https://github.com/IntQuant/noita_entangled_worlds> (у тебя локально: `mods/noita_entangled_worlds-master`)
- Discord: <https://discord.gg/uAK7utvVWN> — там живут разработчики, туда идти с вопросами про API.
- Таблица совместимости модов (публичная, можно дописывать):
  <https://docs.google.com/spreadsheets/d/1nMdqzrLCav_diXbNPB9RgxPcCQzDPgXdEv-klKWJyS0>
- Уже синхронизирует: игроков, позиции, HP, перки, инвентари, использование жезлов и предметов,
  предметы в мире, врагов и атаки, **пиксели мира**, грибные сдвиги, полиморф.
- Содержит **позиционный голосовой чат** (см. `docs/03`).
- Имеет **PvP-режим** с раундами по биомам и таблицей побед — ближайший к БР код внутри EW.

## 3. Noita Together — архитектурно близко к тому, о чём ты спрашивал

- Код: <https://github.com/Noita-Together/noita-together>
- Это кооп-мод, работающий через **внешний сервер/приложение**, а не через прокси-хуки движка.
- Полезно как второй пример того, как вообще можно вынести сеть за пределы игры
  (мод + внешний процесс), и какие ограничения это накладывает.

## 4. evaisa.mp — фреймворк мультиплеера для Noita

- Код: <https://github.com/EvaisaDev/evaisa.mp>
- «A multiplayer gamemode framework for Noita using SteamAPI».
- Смысл: ещё один взгляд на то, как делать мультиплеер поверх Steam. Если ты когда-нибудь
  захочешь уйти от EW — это направление, куда смотреть.

## 5. NoitaMP (Ismoh) — поучительно читать issue

- Код: <https://github.com/Ismoh/NoitaMP>
- Интересен не столько кодом, сколько обсуждениями: <https://github.com/Ismoh/NoitaMP/issues/27>
  («Developer want to rework NetworkComponents»).
- Полезно, чтобы понять, **почему это так сложно**: сериализация компонентов, сущностей,
  мира. Это объясняет, почему в итоге победил подход EW через прокси и нативный модуль.

## 6. Прочее, что пригодится

- Официальные примеры модов, которые уже лежат рядом: `mods/nightmare` (кастомная карта биомов),
  `mods/daily_practice` (пер-слот генерация, чтение ванильной карты по пикселям),
  `mods/starting_loadouts` (выдача жезлов и стартового снаряжения), `mods/example`.
- `tools_modding/lua_api_documentation.txt` — не ссылка, а рабочая необходимость: держать открытым.
- Видео по EW (из README): <https://www.youtube.com/watch?v=mMP-93-RTs0> — посмотреть,
  как это выглядит живьём.

## 7. Вывод

Ландшафт такой:

| Хочу | Уже есть | Делать самому |
| --- | --- | --- |
| Мультиплеер-транспорт | EW (прокси + ewext + Lua) | ничего |
| Позиционный голос | EW (Opus + затухание по расстоянию) | только доработки |
| PvP-раунды, зона, лобби, магазины | Noita Arena + EW `pvp.lua` | переписать под БР-правила |
| Высадка в разные биомы мира | таблица `chunks_by_floor` в EW | логика выбора и prep-фаза |
| Лут по всей карте | `ProceduralRandom`, `item_sync`, `gen_sync` | правила и тиры |
| БР на всём мире Noita | нигде | **это и есть твой проект** |
| Кастомный компактный мир-арена | `nightmare`-подход к `biome_map.lua` | своя карта биомов |

Строка «БР на всём мире Noita» — единственная, где ты реально первый. Всё остальное —
интеграция уже существующих кусков. Это **хорошая** новость: проект становится обозримым.
