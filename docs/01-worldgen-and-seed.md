# 01 — Процедурная генерация и сид

## 1. Главное, что нужно понять сразу

**В Noita нельзя написать свой генератор мира «с нуля».** Рельеф, ванг-тайлы, топология,
пещеры — это C++ движка. Мод влияет на генерацию через **данные и параметры**:

```
magic_numbers.xml (BIOME_MAP → lua)      ← точка входа №1: своя карта биомов
        ↓
biome map (пиксели: какой биом где)      ← BiomeMapSetPixel / BiomeMapLoadImage
        ↓
data/biome/<biome>.xml                   ← параметры биома: материалы, топология, спавны
        ↓
wang-тайлы + pixel scenes (префабы)      ← LoadPixelScene / RegisterSpawnFunction
        ↓
сущности (враги, лут, жезлы, сундуки)    ← EntityLoad / SpawnStash / ProceduralRandom
```

То есть «кастомная процедурная генерация, привязанная к сиду» на практике означает:
**свой `biome_map.lua`, который детерминированно от сида рисует карту биомов, плюс правка
параметров биомов в `OnWorldInitialized`.** Ровно это делает официальный мод `nightmare`,
и это твой учебник.

## 2. Точка входа: BIOME_MAP

В `magic_numbers.xml` есть ключ `BIOME_MAP`, который может указывать на **lua-файл**.
Если он указывает на lua, то в контексте этого файла становятся доступны функции
(из `lua_api_documentation.txt` строки 224–231):

```
BiomeMapSetSize(width, height)
BiomeMapGetSize() -> width, height
BiomeMapSetPixel(x, y, color_int)
BiomeMapGetPixel(x, y) -> color
BiomeMapConvertPixelFromUintToInt(color) -> int      -- свап красного и синего каналов
BiomeMapLoadImage(x, y, image_filename)
BiomeMapLoadImageCropped(x, y, image, ix, iy, iw, ih)
BiomeMapGetVerticalPositionInsideBiome(x, y)
BiomeMapGetName(x, y)
```

Цвет пикселя = биом. Формат цвета — **ARGB** (например `0xFFD57917` = Coal Mines).

Подключение через `ModMagicNumbersFileAdd(...)` — см. `nightmare/init.lua` строка 143.

### Как это выглядит на практике

`mods/nightmare/files/biome_map.lua` (227 строк) — минимально достаточный пример:

```lua
BiomeMapSetSize(64, 48)
BiomeMapLoadImage(0, 0, "mods/nightmare/files/biome_map.png")
SetRandomSeed(4573, 4621)          -- ← вот он, сид

-- своп биомов с вероятностями
if Random(0, 100) < 35 then
    biome_fungicave, biome_excavationsite = biome_excavationsite, biome_fungicave
end

-- «рисование» карты своими функциями
paint_biome_area(32, 14, 3, 2, biome_coalmines, 0)
paint_cave(27, 15, -1, biome_fungicave, Random(4, 50))

-- отдельные важные пиксели: орбы, босс-арена, финальная комната
BiomeMapSetPixel(51, 11, 0xFFC88F5F)
```

`mods/daily_practice/files/magic_numbers/biome_map_general.lua` показывает второй приём:
**читать ванильную карту по пикселям и править её точечно** (`BiomeMapGetPixel` в цикле +
`BiomeMapSetPixel`), а не рисовать с нуля. Для БР это, скорее всего, то, что тебе нужно:
взять ванильный мир и «вырезать» из него арену.

## 3. Параметры биомов: BiomeSetValue и родня

```
BiomeSetValue(filename, field, value)
BiomeGetValue(filename, field) -> value
BiomeObjectSetValue(filename, meta_object_name, field, value)
BiomeVegetationSetValue(filename, material_name, field, value)
BiomeMaterialSetValue(filename, material_name, field, value)
BiomeMaterialGetValue(filename, material_name, field) -> value
```

Пример из `nightmare/init.lua`:

```lua
function set_biome_to_nightmare(biome_name, hp_scale, attack_speed)
    local biome_filename = "data/biome/" .. biome_name .. ".xml"
    BiomeSetValue(biome_filename, "game_enemy_hp_scale", hp_scale)
    BiomeSetValue(biome_filename, "game_enemy_attack_speed", attack_speed)
end

function OnWorldInitialized()
    set_biome_to_nightmare("coalmine", 3, 0.5)
    ...
end
```

**Критично:** комментарий в том же файле — *«biome data is not saved, so we do these every
time»*. Данные биомов не сериализуются в сейв, поэтому править их надо **каждый раз**
в `OnWorldInitialized`, а не однократно.

## 4. Сид: откуда его брать и куда не лезть

API: `SetWorldSeed(new_seed:int)`, `SetRandomSeed(x, y)`, `GetDailyPracticeRunSeed()`.

**В мультиплеере сид задаёт EW, а не ты.** Прокси рассылает его, а EW применяет
(`mods/quant.ew/files/core/net_handling.lua`, `net_handling.proxy.seed`):

```lua
function net_handling.proxy.seed(_, value)
    local seed = tonumber(value)
    if seed == 0 then seed = 1 end
    if seed ~= nil then
        SetWorldSeed(seed)
        SetRandomSeed(seed, 141)
    end
end
```

Вывод: **не изобретай свой сид и не вызывай `SetWorldSeed` сам** — иначе рассинхрон мира
между игроками. Читай текущий сид из того же источника, что и игра/EW, и строй генерацию
на `SetRandomSeed` + `Random` внутри своего `biome_map.lua` (он исполняется в момент
создания мира, когда сид уже выставлен прокси).

## 5. Золотой инструмент для БР: ProceduralRandom

```
ProceduralRandom(x, y, [a, b])   -> number|int
ProceduralRandomf(x, y, [a, b])  -> number
ProceduralRandomi(x, y, [a, b])  -> int
```

Это **чистая функция мировых координат и мирового сида**. Одинаковые `(x, y)` → одинаковый
результат на всех машинах с тем же сидом.

Что это даёт: **лут можно генерировать независимо на каждом клиенте вообще без сети.**
В чанке `(cx, cy)` на позиции `(x, y)` каждый игрок сам решит «тут сундук», «тут жезл уровня 3»,
«тут ничего» — и получит то же самое, что остальные. Ноль пакетов, ноль рассинхрона.

Для БР это основной способ наполнять мир лутом. Что всё равно придётся синхронизировать —
так это *изменения* (кто что подобрал, что взорвалось, где чей труп), и этим занимается EW.

Осторожно с `SetRandomSeed` + `Random` в рантайме: он **глобальный и общий** для контекста,
поэтому «просто рандом» в цикле по игрокам даст разные результаты на разных машинах.
В рантайме сидируй детерминированно, как это делает `pvp.lua`:

```lua
SetRandomSeed(tonumber(string.sub(ctx.my_id, 8, 12), 16), tonumber(string.sub(ctx.my_id, 12), 16))
n = Random(1, #chunks)
```

## 6. Чанки и координаты

- **1 чанк = 512 пикселей.** Мир в чанках: `BiomeMapGetSize()`.
- `BiomeMapGetName(x, y)` — имя биома в точке (для правил «тут лут получше»).
- `BiomeMapGetVerticalPositionInsideBiome(x, y)` — «глубина внутри биома», удобно для tier'ов лута.
- `DebugBiomeMapGetFilename(x, y)` — имя файла биома.
- `DoesWorldExistAt(min_x, min_y, max_x, max_y)` — загружен ли уже участок (не спавни в несуществующем!).

В EW уже есть **готовая таблица координат чанков по всем биомам** — `mods/quant.ew/files/system/pvp/pvp.lua`,
переменная `chunks_by_floor` (строки 4–27). Это буквально список «где какие биомы лежат в чанках»,
например:

```lua
{ { -3, 1, 3, 1 }, { 0, 0, 2, 0 } }, -- (Collapsed) Mines
{ { -6, 3, 3, 4 }, { -7, 3, -7, 3 } }, -- Coal Pits
{ { -5, 6, 4, 8 } }, -- Snowy Depths
```

Для механики «игроки высаживаются в различные локации» это готовая основа — не надо
самому исследовать мир.

## 7. Спавн контента в уже сгенерированном мире

Генерация мира и спавн контента — разные вещи. Второе доступно в рантайме:

| Функция | Назначение |
| --- | --- |
| `EntityLoad(xml, x, y)` | поставить сущность (жезл, сундук, алтарь) |
| `SpawnStash(x, y, level, action_count)` | готовый «клад» с спеллами |
| `SpawnActionItem(x, y, level)` | случайный спелл/предмет |
| `CreateItemActionEntity(action_id, x, y)` | конкретный спелл по id |
| `GetRandomAction(x, y, max_level)` / `GetRandomActionWithType(...)` | выбор действия под уровень |
| `LoadPixelScene(materials_png, colors_png, x, y, bg, skip_biome_checks, skip_edge_textures, ...)` | вставить префаб-комнату |
| `LoadBackgroundSprite(...)` | фон |
| `RegisterSpawnFunction(color, fn_name)` | привязать цвет из pixel scene к своей функции спавна |
| `SetPlayerSpawnLocation(x, y)` | точка спавна игрока |
| `GameCutThroughWorldVertical(x, y_min, y_max, radius, edge)` | прорезать шахту (для «десантирования») |
| `ConvertMaterialOnAreaInstantly(...)` | заменить материал в области (арена, обрушение) |
| `LoadGameEffectEntityTo(entity, xml)` | повесить эффект (неуязвимость, телепорт) |

Готовый пример «телепортировать игрока в случайный чанк биома, обезопасить, приземлить»
целиком есть в `pvp.lua` → `pvp.teleport_into_biome()` (строки 503–549). Для высадки в БР
можно брать почти как есть.

## 8. Что реально можно и нельзя

**Можно:**
- своя карта биомов из lua, детерминированная от сида;
- правка параметров биомов при каждом `OnWorldInitialized`;
- точечная правка ванильной карты по пикселям;
- вставка префабов (`LoadPixelScene`) и прорезание проходов;
- детерминированный спавн лута по координатам без сети;
- менять карту на лету (`BiomeMapLoad_KeepPlayer`) — но это тяжёлая и рискованная операция.

**Нельзя (и не надо пытаться):**
- писать свой генератор рельефа/пещер — это движок;
- вызывать `SetWorldSeed` в мультиплеере (это делает EW);
- рассчитывать, что правки биомов сохранятся в сейве — их надо применять каждый раз;
- спавнить в незагруженных чанках (проверяй `DoesWorldExistAt`).

## 9. Практический совет по порядку работ

Не начинай с генерации. Сначала сделай играбельную петлю БР на **ванильном мире** —
это уже 80% ощущения от режима и не требует ни одного нового пикселя. Кастомная генерация
(M8 в `docs/04`) — это отдельный, последний и самый необязательный этап. Ты сам увидишь,
чего не хватает: скорее всего, захочется не «свой мир», а «стартовую арену и равномерный лут»,
а это делается точечно.
