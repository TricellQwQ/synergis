# 07 — Построчный разбор `player_tether.lua` (412 строк)

Файл: `mods/quant.ew/files/system/player_tether/player_tether.lua`
Плюс: `mods/quant.ew/files/system/player_tether/zone_entity.xml` (33 строки)

**Почему именно этот файл.** Из всего EW это самое близкое к твоей зоне: здесь есть
радиус, видимое кольцо из частиц, телепорт при выходе за радиус, защита от параллельных
миров, защита от Holy Mountain, грейс-период после урона и синхронизация радиуса по сети.
Механика тут другая — это **поводок к хосту** (кооп, чтобы игроки не разбегались), —
но машинерия ровно та, которая нужна сужающемуся кругу. Тебе её надо **инвертировать**:
поводок не к хосту, а к центру зоны.

Важно: по умолчанию система **выключена** — `tetherrange` в настройках EW имеет
`value_default = "0"` (`quant.ew/settings.lua:308–314`, «radius in pixels, 0 for disabled»).

---

## 1. Каркас и переменные (строки 1–11)

```lua
local rpc = net.new_rpc_namespace()
local tether = {}
local tether_length        -- настройка: желаемый радиус (из mod settings)
local tether_length_2      -- «базовый» рисуемый радиус (+128 запаса)
local tether_length_3      -- текущий фактический радиус (динамически растёт/сжимается)
local ignore_tower = false
```

**Три переменные радиуса — не случайность.** Разберись в них, это самая содержательная
идея файла (см. §13). Для зоны тебе понадобится похожая тройка: `zone.radius_target`
(по расписанию фаз), `zone.radius_drawn` (с запасом), `zone.radius_current` (плавно
интерполированный).

## 2. `tether.is_in_box` (строки 13–15) — ловушка в порядке аргументов

```lua
function tether.is_in_box(x1, x2, y1, y2, x, y)
    return x1 < x and x < x2 and y1 < y and y < y2
end
```

Порядок **`x1, x2, y1, y2`**, а не привычный `x1, y1, x2, y2`. Все вызовы в файле
следуют этому порядку, и его легко перепутать при копировании — а ошибка даст
«иногда не работает» без всяких сообщений. Если берёшь функцию, переименуй параметры
или поменяй порядок на очевидный.

Обрати внимание: сравнения строгие (`<`), то есть границы не включаются.

## 3. `tether.not_in_normal_area(x, y)` (строки 17–20) — **ключевая функция для круга**

```lua
function tether.not_in_normal_area(x, y)
    return not (-5646 < x and x < 5120 and -1400 < y and y < 14336)
        and not tether.is_in_box(5632, 7168, 14336, 15872, x, y)
end
```

Возвращает `true`, если точка **вне основного мира**: за пределами параллельного мира 0
(`x < -5646` — западные миры, `x > 5120` — восточные), выше неба (`y < -1400`) или ниже ада
(`y > 14336`). Исключение — финальная комната (5632..7168, 14336..15872).

**Это готовый ответ на вопрос «где вообще может жить мой круг».** Точки высадки, центр
и фазы зоны должны лежать внутри этого прямоугольника — иначе круг окажется в
параллельном мире, где игроков нет.

## 4. `tether.position_to_area_number(x, y, is_dead)` (строки 22–84) — «какой это уровень»

Возвращает **номер области** (по сути номер уровня/биома) и, для некоторых областей,
**Y, куда телепортировать** (`given`). Три ветки: игровой режим 2 (`np.GetGameModeNr() == 2`,
это Daily Run), NG+ (`SessionNumbersGetValue("NEW_GAME_PLUS_COUNT") > 0`), и обычный забег.

Для обычного забега пороги по Y: `1199`, `2735`, `4783`, `6319`, `8367`, `10415`, `12975`,
плюс особые случаи:

```lua
elseif tether.is_in_box(3584-512, 3584+1024, 512, 3584, x, y) and is_dead then return 3, 4783
elseif ...
elseif tether.is_in_box(5632, 7168, 14336, 15872, x, y) then return 11        -- финальная комната
elseif not tether.is_in_box(3000, 4200, 12800, 13500, x, y) then return 8
else return 9
```

**Вердикт: БРАТЬ.** Это таблица границ уровней, которую иначе пришлось бы добывать
экспериментально. Для круга она решает задачу «в каком биоме стоит центр и когда зона
наконец переходит на следующий уровень». Замечание: `np.GetGameModeNr()` — это
**NoitaPatcher**, не ваниль.

## 5. `new_pos(given)` (строки 86–92) — запасная точка

```lua
local function new_pos(given)
    if given ~= nil then return -678, given + 149
    else return 1914, 13119 end
end
```

Фолбэк-позиция для телепорта, если основную взять нельзя. `-678` — это X внутри
Holy Mountain, `given + 149` — чуть ниже его Y. Пригодится как «безопасная точка сброса»
для игроков вне зоны.

## 6. `in_normal_hm` и `not_in_hm` (строки 94–145) — **энциклопедия мировой геометрии**

```lua
local function in_normal_hm(list, x, y)
    local x1, x2, dy = -1024, 512, 338
    for _, y1 in ipairs(list) do
        if tether.is_in_box(x1, x2, y1, y1 + dy, x, y) then return true end
    end
    return false
end
```

Holy Mountain — это бокс `x ∈ (−1024, 512)`, `y ∈ (y1, y1+338)`, где `y1` берётся из
списка, зависящего от режима:

- обычный забег: `{ 1198, 2734, 4782, 6318, 8366, 10414 }`
- NG+: `{ 1198, 2734, 6318, 10414 }`
- Daily Run (`GetGameModeNr() == 2`): `{ 1198, 3758, 6318, 10414 }`

А `not_in_hm(x, y)` возвращает **два** булева значения и содержит жёстко прописанные
координаты особых зон:

```lua
or tether.is_in_box(1536, 2726, 12798, 13312, x, y)   -- последний HM
or tether.is_in_box(-4634, -4054, 2006, 2580, x, y)   -- комната медитации
or tether.is_in_box(-4060, -3656, 5078, 5660, x, y)   -- глазная комната
or tether.is_in_box(3578, 4080, 4048, 4640, x, y)     -- снежная комната
or tether.is_in_box(8700, 11300, 3550, 10240, x, y)   -- башня
or tether.is_in_box(5632, 7168, 14336, 15872, x, y)   -- финальная комната
```

**Вердикт: ЗАБРАТЬ КАК СПРАВОЧНИК.** Это карта «где в мире есть особые места, которые
ломают обычные правила». Для БР это готовый список исключений: в этих зонах зона/урон
должны вести себя иначе (или быть запрещены).

## 7. `is_suitable_target` (строки 149–151) — полиформинг

```lua
local function is_suitable_target(entity)
    return EntityGetIsAlive(entity) and not EntityHasTag(entity, "polymorphed")
end
```

**Для БР это важное решение, а не деталь.** Полиморфнутый (превращённый в животное)
игрок в EW не считается «подходящей целью» — его не телепортируют и не тянут. В БР
полиморф — легальная тактика убежать из зоны. Решай явно: либо мьютить зону для
полиморфнутых, либо считать их обычными, либо вообще банить полиморф.

## 8. `set_tether_length` (строки 153–163) — **как из числа получается видимое кольцо**

```lua
local function set_tether_length(length, entity)
    for _, child in ipairs(EntityGetAllChildren(entity) or {}) do
        if EntityGetName(child) == "ew_tether" then
            local emmiter = EntityGetFirstComponentIncludingDisabled(child, "ParticleEmitterComponent")
            ComponentSetValue2(emmiter, "area_circle_radius", length, length + 2)
            ComponentSetValue2(emmiter, "count_min", length * 256 / (2048 + 128))
            ComponentSetValue2(emmiter, "count_max", length * 512 / (2048 + 128))
            break
        end
    end
end
```

Три вещи, которые надо забрать целиком:

1. **радиус кольца = поле `area_circle_radius`** эмиттера, задаётся парой (min, max);
2. **количество частиц масштабируется радиусом** — формула `length * 256 / 2176`
   (эмпирика автора, чтобы плотность кольца не менялась при росте радиуса);
3. `ComponentSetValue2` для `Vector2`-поля принимает **два числа**, а не таблицу —
   частая ошибка.

## 9. `tether_enable` (строки 165–186) — создание/включение кольца

```lua
local function tether_enable(to_enable, entity)
    if entity ~= nil and EntityGetIsAlive(entity) then
        local found = false
        for _, child in ipairs(EntityGetAllChildren(entity) or {}) do
            if EntityGetName(child) == "ew_tether" then
                local emmiter = EntityGetFirstComponentIncludingDisabled(child, "ParticleEmitterComponent")
                EntitySetComponentIsEnabled(child, emmiter, to_enable)
                found = true
                break
            end
        end
        if not found then
            local child = EntityLoad("mods/quant.ew/files/system/player_tether/zone_entity.xml")
            EntityAddChild(entity, child)
            ...
```

Идиома «найти ребёнка по имени, если нет — создать из XML и прицепить» — так делается
почти всё визуальное в Noita. `EntityLoad` + `EntityAddChild` = сущность, которая едет
за родителем.

Важно: кольцо вешается на **сущность хоста** (`host_playerdata.entity`), а не на каждого
игрока (см. §13). Для круга ты сделаешь наоборот: одна независимая сущность-маркер
в центре зоны, которая **не** привязана ни к кому.

## 10. `zone_entity.xml` (33 строки) — **готовый шаблон кольца зоны**

```xml
<Entity name="ew_tether">
    <InheritTransformComponent only_position="1">
        <Transform position.x="0" position.y="-8" />
    </InheritTransformComponent>
    <ParticleEmitterComponent
        emitted_material_name="spark_yellow"
        gravity.y="0.0"
        lifetime_min="0.1" lifetime_max="0.5"
        count_min="200" count_max="300"
        render_on_grid="0" render_ultrabright="1"
        fade_based_on_lifetime="1"
        area_circle_radius.min="100" area_circle_radius.max="100"
        cosmetic_force_create="0"
        airflow_force="0.3" airflow_time="0.01" airflow_scale="0.05"
        emission_interval_min_frames="0" emission_interval_max_frames="0"
        emit_cosmetic_particles="1" is_emitting="1" />
</Entity>
```

Для своей зоны достаточно скопировать и поменять:

- `emitted_material_name` — `spark_yellow` на что-то зловещее (например `spark_red`,
  `acid_gas` или свой материал из `materials.xml`);
- `lifetime_min/max` — на бóльшие значения, чтобы кольцо не мерцало;
- `is_emitting="1"` — кольцо видно всегда; для фаз можно включать/выключать;
- `InheritTransformComponent` — убрать, если сущность стоит в мире сама по себе.

## 11. `rpc.teleport_to_tower` (строки 193–207) — образец «телепорт с проверкой»

```lua
function rpc.teleport_to_tower()
    if ignore_tower then return end
    local x2, y2 = EntityGetTransform(ctx.my_player.entity)
    if tether.is_in_box(9200, 11000, 8300, 9800, x2, y2) then return end
    async(function()
        EntitySetTransform(ctx.my_player.entity, 9740, 9100)
        wait(30)
        EntitySetTransform(ctx.my_player.entity, 9740, 9100)
        float()
    end)
end
```

Тот же приём, что в `pvp.lua`, но с `wait(30)` вместо `wait(4)` — чем дальше телепорт,
тем дольше надо повторять. И проверка «я уже там» перед телепортом.

## 12. `rpc.give_new_length` (строки 213–233) — синхронизация радиуса по сети

```lua
function rpc.give_new_length(new_range)
    if new_range ~= nil then
        tether_length = new_range
        if new_range > 512 then
            tether_length_2 = new_range + 128
            tether_length_3 = math.max(tether_length_3 or 0, tether_length_2)
        else
            tether_length_2 = new_range
            tether_length_3 = new_range
        end
        local host_playerdata = player_fns.peer_get_player_data(ctx.host_id, true)
        if host_playerdata ~= nil and host_playerdata.entity ~= nil then
            if new_range == 0 then tether_enable(false, host_playerdata.entity)
            else
                tether_enable(true, host_playerdata.entity)
                set_tether_length(tether_length_3, host_playerdata.entity)
            end
        end
    end
end
```

**Смысл трёх радиусов:**

| Переменная | Что значит |
| --- | --- |
| `tether_length` | желаемый радиус (настройка) |
| `tether_length_2` | базовый рисуемый: `length + 128` запаса при `length > 512`, иначе сам `length` |
| `tether_length_3` | фактический текущий: `max(предыдущий, length_2)` — **монотонно растёт**, пока игрок далеко |

Это защита от «пинг-понга»: если игрок чуть за границей, каждый кадр его телепортирует,
он снова оказывается снаружи, и так по кругу. Запас +128 и «монотонный максимум» гасят
такое дрожание.

**Для сужающегося круга логика обратная:** зона должна сжиматься **монотонно вниз**,
и телепорт/урон должен срабатывать по `radius_target`, а не по текущему сглаженному
радиусу. Иначе игроки будут «выжиматься» наружу во время анимации сужения. Это,
пожалуй, главная ошибка, которую тут легко унаследовать.

`rpc.request_tether()` (строки 235–237) — обратная сторона: клиент, который только
подключился, **просит** у хоста текущий радиус. **Обязательный паттерн для БР:**
опоздавший игрок должен узнать фазу зоны, а не гадать.

## 13. `tether.on_world_update` (строки 241–410) — главный цикл

Весь цикл — под `if GameGetFrameNum() % 10 == 7` (раз в 10 кадров). Для зоны это
разумный базовый темп.

### 13a. Настройка с дебаунсом (242–264)

```lua
if ctx.is_host then
    local new_range = tonumber(ModSettingGet("quant.ew.tetherrange") or 0) or 0
    if tether_length ~= new_range and new_range ~= nil then
        if wait_on_send == nil then wait_on_send = GameGetFrameNum() + 60
        elseif wait_on_send < GameGetFrameNum() then
            wait_on_send = nil
            ...
            rpc.give_new_length(new_range)
        end
    end
end
```

**Приём:** хост замечает изменение настройки, но ждёт стабилизации 60 кадров, прежде чем
рассылать. Это защита от рассылки на каждый чих ползунка. Забрать для настроек БР.

### 13b. Bootstrap клиента (265–270)

```lua
if tether_length == 0 then return end
if tether_length == nil then rpc.request_tether(); return end
```

Клиент не знает радиус → просит у хоста. Ровно то же нужно для фазы зоны.

### 13c. Условия «не трогать игрока» (272–285)

```lua
if GameHasFlagRun("ending_game_completed") then ... return end
if (ctx.proxy_opt.perma_death or ctx.proxy_opt.no_notplayer)
   and (not ctx.my_player.status.is_alive or not host_playerdata.is_alive) then return end
```

Плюс `is_suitable_target` (полиморф) ниже. **Собери все эти гварды в один список
«когда зона не действует»** — в БР это: мёртв, спектатор, полиморф, идёт заставка/финал,
фаза подготовки.

### 13d. Особые зоны: башня и «убежал за пределы мира» (286–315)

```lua
local x2, y2 = EntityGetTransform(ctx.my_player.entity)
if tether.is_in_box(9200, 11000, 4000, 8300, x2, y2) then ignore_tower = true end
```

и

```lua
for _, player in pairs(ctx.players) do
    local x, y = EntityGetTransform(player.entity)
    if not tether.is_in_box(9200, 11000, 4000, 9800, x, y) then any_not = true end
    if tether.is_in_box(0, 1000, -2000, 0, x, y) then
        async(function()
            EntitySetTransform(ctx.my_player.entity, 770, 900)
            wait(30)
            EntitySetTransform(ctx.my_player.entity, 770, 900)
            float()
        end)
        return
    end
end
```

Кусок `is_in_box(0, 1000, -2000, 0, ...)` → телепорт в `(770, 900)` — это античит
против ухода в небо над горой. Обрати внимание: проверяется **все игроки**, и если
**кто угодно** там, телепортируется **локальный** игрок. Для БР: арсенал приёмов
против «улетел за карту» начинается отсюда.

### 13e. Параллельные миры (345–349) — **критично для дизайна B**

```lua
local host_pw = check_parallel_pos(x1)
local my_pw = check_parallel_pos(x2)
if host_pw ~= my_pw then return end
```

`check_parallel_pos` — **ванильная** функция из `data/scripts/lib/utilities.lua`
(подтверждено по исходнику зеркала `noitadata`):

```lua
function check_parallel_pos( x )
    local pw = GetParallelWorldPosition( x, 0 )
    local mapwidth = BiomeMapGetSize() * 512
    local half = mapwidth * 0.5
    local mx = ( ( x + half ) % mapwidth ) - half
    return pw, mx
end
```

Возвращает **номер параллельного мира** и **X, приведённый к канонической карте**
(свёрнутый в `[−mapwidth/2, +mapwidth/2)`).

Заметь: тут используется **только первый** возвращаемый результат — сравнивается
номер мира, без учёта `mx`. Это правильно для вопроса «мы в одном мире?», но
недостаточно для «мы в одном и том же месте мира».

**Для сужающегося круга это ключевая функция:**

- проверить, что центр зоны в мире 0;
- привести позиции игроков из параллельных миров к канонической X
  (для HUD, карты, «кто ближе к центру»);
- отсечь игроков, которые ушли в параллельный мир, — считать их вне зоны.

### 13f. Грейс-период после урона (363–367) — **забрать обязательно**

```lua
if host_playerdata.last_hit + 10 < GameGetFrameNum()
   and ctx.my_player.last_hit + 10 < GameGetFrameNum() then
```

Телепорт не срабатывает, если хост или игрок получали урон за последние 10 кадров.
Причина очевидна: не выдёргивать игрока из боя. **В БР это ещё важнее** — иначе зона
будет телепортировать человека ровно в момент перестрелки. `last_hit` — поле
`player_data`, синхронизируемое EW.

### 13g. Перемещение при выходе за радиус (378–401)

```lua
if dist_sq > tether_length_3 * tether_length_3 then
    local x, y = x1, y1
    local my_pos, given = tether.position_to_area_number(x2, y2)
    if not tether.not_in_normal_area(x, y) and not tether.not_in_normal_area(x2, y2)
       and tether.position_to_area_number(x, y) > my_pos then
        x, y = new_pos(given)
    end
    EntitySetTransform(ctx.my_player.entity, x, y)
    async(function()
        if tether_length_3 > 1024 then
            wait(40)
            EntitySetTransform(ctx.my_player.entity, x, y)
            float()
        end
    end)
elseif tether_length_3 > tether_length_2 then
    ...
```

Две ветки: если далеко — телепорт (к хосту или в HM, если хост на уровень выше);
если близко — потихоньку сжать динамический радиус обратно. Мягкое «отпускание поводка».

### 13h. Условие применения поводка и «курсор хоста» (353–362)

```lua
local host_mx, host_my = host_playerdata.mouse_x, host_playerdata.mouse_y
local dxm, dym = host_mx - x2, host_my - y2
if ... and (tether_length < 512 or dxm*dxm + dym*dym > tether_length*tether_length/2) then
```

Если радиус мал (`< 512`) — проверка пропускается. Если велик — требуется, чтобы
**курсор хоста был достаточно далеко** от игрока. Похоже на эвристику «не дёргать
игрока, если хост на него смотрит / взаимодействует». Точный замысел в коде
не документирован — **не копируй вслепую**; для зоны это правило бессмысленно
(у зоны нет курсора).

---

## Сводка: что брать, что инвертировать, что выбросить

| Строки | Блок | Вердикт для сужающегося круга |
| --- | --- | --- |
| 13–15 | `is_in_box` | Брать, **переписав порядок аргументов** |
| 17–20 | `not_in_normal_area` | **Брать** — границы обитаемого мира |
| 22–84 | `position_to_area_number` | **Брать** — границы уровней |
| 86–92 | `new_pos` | Брать — безопасная точка сброса |
| 94–145 | `not_in_hm`, `in_normal_hm` | **Брать как справочник** особых зон |
| 149–151 | `is_suitable_target` | Решить явно: что с полиморфом |
| 153–163 | `set_tether_length` | **Брать как есть** — как число превращается в кольцо |
| 165–186 | `tether_enable` | **Инвертировать**: маркер в центре зоны, не на хосте |
| 188–191 | `float` | Брать |
| 193–207 | `teleport_to_tower` | Брать как образец телепорта с проверкой |
| 213–233 | `give_new_length` | **Инвертировать**: сжатие должно быть монотонным вниз |
| 235–237 | `request_tether` | **Брать обязательно** — синк для опоздавших |
| 242–264 | дебаунс настроек | **Брать** — приём |
| 265–270 | bootstrap клиента | Брать |
| 272–285 | гварды «не трогать» | Собрать в один список условий |
| 286–315 | башня, античит неба | Брать (античит против ухода за карту) |
| 345–349 | `check_parallel_pos` | **Критично** — см. §13e |
| 353–362 | условие с курсором | **Выбросить** — у зоны нет курсора |
| 363–367 | грейс `last_hit` | **Брать обязательно** |
| 378–401 | телепорт при выходе | Брать, заменив «к хосту» на «к центру» |

## Чего здесь нет и что придётся написать

1. **Круга как независимого объекта** — тут кольцо привязано к сущности хоста
   через `InheritTransformComponent`. Тебе нужна отдельная сущность в центре зоны
   и ручное обновление её позиции.
2. **Расписания фаз** — тут радиус один и меняется настройкой. У тебя — последовательность
   фаз с временами и целевыми радиусами.
3. **Урона** — тут только телепорт. Урон вне зоны: `ctx.cap.health.inflict_damage(dmg)`.
4. **Интерполяции радиуса на клиентах** — тут `rpc.give_new_length` рассылает значение
   на каждое изменение. Для плавного сужения лучше рассылать «фаза + время начала +
   от/до радиуса», а интерполяцию делать локально.
5. **HUD и карты** — тут нет ничего; см. `files/system/map/map.lua`.

---

## Бонус: ванильные хелперы, которые тебе понадобятся

Пока искал `check_parallel_pos`, я прочитал `data/scripts/lib/utilities.lua` целиком
(1082 строки) и нашёл там готовое, что сэкономит тебе время. EW грузит этот файл
через `dofile_once("data/scripts/lib/utilities.lua")` у себя в `init.lua`, так что
в контексте EW **все эти функции доступны глобально**.

**Для детерминированного лута (прямо по теме):**

```lua
function random_create( x, y )      -- создать состояние ГПСЧ
    local result = {} result.x = x result.y = y return result
end
function random_next( rnd, min, max )    -- ProceduralRandomf + инкремент rnd.y
    local result = ProceduralRandomf( rnd.x, rnd.y, min, max )
    rnd.y = rnd.y + 1
    return result
end
function random_nexti( rnd, min, max )   -- то же, но целое
function pick_random_from_table_weighted( rnd, t )   -- взвешенная таблица по ГПСЧ
```

Это **готовый механизм «одна и та же последовательность на всех клиентах»**:
создаёшь `rnd = random_create(chunk_x, chunk_y)`, и дальше `random_next`/`random_nexti`
выдают воспроизводимую последовательность. А `pick_random_from_table_weighted`
превращает это в нормальные таблицы лута с вероятностями. Для БР — то, что нужно.

**Геометрия и математика (для круга):**

```
clamp(v, min, max)          lerp(a, b, w)         map(v, omin, omax, nmin, nmax)
sign(v)                     get_distance(x1,y1,x2,y2)   get_distance2(...)  -- без sqrt!
get_magnitude(x, y)         get_direction(x1,y1,x2,y2)  get_direction_difference(d1,d2)
vec_add / vec_sub / vec_mult / vec_div / vec_scale / vec_equals / vec_normalize
vec_lerp / vec_dot / vec_length / vec_rotate
```

Для проверки «внутри круга» используй `get_distance2` (без квадратного корня) —
это заметно дешевле, и в `player_tether.lua` сделано именно так (`dist_sq`).

**Прочее полезное, что там есть:**

| Функция | Зачем |
| --- | --- |
| `is_in_camera_bounds(x, y, padding)` | «видно ли игроку эту точку» — дешёвый способ не спавнить/не рисовать лишнее |
| `get_players()` | `EntityGetWithTag("player_unit")` |
| `get_herd_id(entity)` / `get_herd_id` | herd-id для команд «свой/чужой» (см. `docs/04` §8) |
| `component_readwrite` / `component_read` / `component_write` | аккуратная пакетная работа с компонентами через `ComponentGetValue2`/`SetValue2` |
| `edit_component2` / `edit_all_components2` / `edit_nth_component2` | то же, версия v2 API (быстрее) |
| `debug_print_entity(entity)` | распечатать **все** компоненты сущности со всеми полями — незаменимо при изучении ванильных сущностей |
| `debug_print_table(t)` | печать вложенных таблиц |
| `orb_map_update()` | используется в `nightmare/biome_map.lua` |
| `GUI_OPTION`, `GUI_RECT_ANIMATION_PLAYBACK`, `TEXTURE_*` | константы для GUI/шейдеров |

### Где читать ванильные скрипты, не распаковывая `data.wak`

Есть публичное зеркало ванильных `data/` файлов:
[NathanSnail/noitadata](https://github.com/NathanSnail/noitadata). Именно оттуда я взял
исходник `utilities.lua`. Это удобно для быстрого поиска («а как в оригинале сделано X?»),
но **не гарантирует совпадения с твоей версией игры** — зеркало может быть на другой
версии. Для всего, что критично, сверяйся со своим распакованным `data/`.

## Что читать следующим

1. `mods/quant.ew/files/system/local_health/local_health.lua` (907 строк) — смерть,
   respawn, perma-death, стык с `pvp` (строки 19–32, 373–377).
   Без этого не сделать «умер = выбыл» и урон вне зоны.
2. `mods/quant.ew/files/system/map/map.lua` — как рисовать маркеры на карте
   (в т.ч. `check_parallel_pos` для игроков из других миров); нужно для отображения круга.
3. `mods/quant.ew/files/system/text/text.lua` — **в EW есть текстовый чат с настраиваемым
   радиусом** (`text_range` в `settings.lua`, по умолчанию 0 = выключен).
   Чат по близости — родственная голосу механика, и `ctx.is_texting` уже существует.
