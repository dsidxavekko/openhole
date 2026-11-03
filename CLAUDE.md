# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

OpenHole — гра з відкритим кодом (MIT) у дусі hole.io: ти дірка, що ковтає процедурно згенероване місто. Godot 4.7, GDScript, основна платформа — Android (портрет 720×1280), також PC і Web.

## Правила проєкту
- Коміти, коментарі в коді, ідентифікатори й UI-рядки — **англійською**. Спілкування з власником — **українською**.
- Кожен закінчений крок — окремий коміт. Push — тільки за командою власника.
- Збірка APK (`make apk`/`make run`) — **лише за явною командою власника**. `make test` можна запускати завжди.
- Увесь текст в UI проходить через `tr()`. Ключі лежать в `i18n/strings.csv` (колонки `keys,en,uk`). Після зміни CSV треба запустити `make import`. Файли `*.translation` генеруються автоматично й ігноруються git, руками їх не редагувати.
- Після зміни команд або модулів онови цей файл і `README.md`.
- Сусідні проєкти в `~/Projects` (Gallium Wallet, Mastell, Seal) не чіпати.

## Команди
```sh
make test                 # headless-тести (tests/run_tests.gd), спершу make import
make smoke MODE=classic   # повний матч, яким керує бот, без графіки: classic|solo|battle|daily
make run-pc               # грати на PC (WASD/стрілки, перетягування мишею = джойстик)
make import               # переімпорт ресурсів і перегенерація .translation
make web                  # Web-білд для itch.io в out/web (без потоків)
make serve-web            # http://127.0.0.1:8000 — wasm не працює з file://
make apk / make install   # Android-збірка і встановлення через adb (лише за командою)
godot --path . --rendering-driver opengl3 -- --screenshot=menu.png   # скріншот
```
- На macOS Godot стоїть через Homebrew (`/opt/homebrew/bin/godot`). Makefile сам бере `~/.local/opt/godot/godot`, а якщо його немає — `godot` з PATH. Шлях можна перевизначити: `make GODOT=...`.
- Окремий тест запустити не можна: усі перевірки — це послідовні виклики `_check(cond, "what")` у `_init()` файлу `tests/run_tests.gd`. Під нову фічу додавай новий блок `print("Name")` + `_check(...)`. Тест пройшов, якщо в кінці виведено `ALL PASSED`.
- `make smoke` друкує рядок `MATCH_END mode=... points=... eaten=... frame_ms=...`. Порівнюй його до і після змін. Попередження `ObjectDB instances were leaked` було й раніше.

## Архітектура
- **Сцени мінімальні, усе будується з коду.** `scenes/main_menu.tscn` і `scenes/game.tscn` містять лише кореневий вузол зі скриптом.
- **Autoload**: `Save` (налаштування й рекорди), `GameState` (режим, опції, seed, daily, прапорець `autoplay` з `-- --autoplay`), `Sfx` (усі звуки синтезуються кодом під час старту, аудіофайлів немає; новий звук = новий `_streams[...]` у `sfx.gd`).
- **`scripts/game.gd`** — контролер матчу. Тут зосереджена майже вся логіка: місто, просторова сітка (`grid`, `CELL`), ковтання (`_swallow_step` → `_start_fall` → `_falling_step` → `_eat`), трафік, пауерапи, дірка-проти-дірки (`_holes_step`/`_eat_hole`), зона Battle, запити для ботів (`find_threat`/`find_prey`/`find_food`), оновлення HUD і фіналу. З `attract = true` той самий скрипт малює фон головного меню (маленьке місто, один бот, без HUD) — **у attract нічого не міняти**.
- **`scripts/core/`** — чисті правила без сцен (`HoleRules`, `DebrisRules`, `Skins`). Сюди виносимо формули, щоб їх можна було тестувати headless.
- **`Hole`** (`scripts/hole/hole.gd`) — стан дірки: очки/рівень/радіус (плавно тягнеться до `target_radius` через `_wanted_radius()`), `effects` (Powerup.Kind → секунди), комбо, кільце ефекту. Кермується через `move_dir`: гравця веде `_player_input()`, ботів — `controller` (`BotAI`, стан-машина WANDER/FOOD/CHASE/FLEE).
- **Як працює ковтання**: земля — один суцільний колайдер, а дірки вирізаються в шейдері землі (`ground.gdshader`, параметри `holes`/`hole_colors` з `_update_ground`). Предмет, що влазить і перекриває дірку, скидає шар землі з `collision_mask`, падає й зараховується, коли опускається під поверхню.
- **Руйнування**: `Fracture` (`scripts/world/fracture.gd`) ріже моделі на шматки площинами в `WorkerThreadPool`. `Demolition` підміняє будівлю шматками (`kind == "debris"`) і стежить, хто кого підпирає (`DebrisRules`).
- **UI**: `Hud` (CanvasLayer, увесь UI з коду, стилі в `UiTheme`) спілкується з `Game` сигналами (`play_again`, `to_menu`, `resume`). `FloatingJoystick` ігнорує тачі по контролах зі списку `joystick.blockers` — сюди треба додавати кожну нову кнопку HUD.
- **Пауерапи** (`scripts/world/powerup.gd`): `Kind`, `DURATIONS`, `COLORS`, `NAMES` (ключі i18n) і `WEIGHTS` (ймовірність спавну; у Solo SHIELD не спавниться).

## Платформи
- Рендер `mobile`, фізика Jolt, 60 тіків. `export_presets.cfg` містить пресети Android (arm64-v8a, пакет `org.openhole.game`) і Web.
- Web: рендер `gl_compatibility` вмикається тільки для Web через `renderer/rendering_method.web` у `project.godot`, глобально лишається `mobile`. Білд однопотоковий (`variant/thread_support=false`), бо itch.io не віддає COOP/COEP. Jolt у Web працює. Для itch.io треба запакувати в zip вміст `out/web` (~42 МБ).
- Метадані F-Droid лежать у `fastlane/metadata/android/{en-US,uk}/`, там же changelog `changelogs/<versionCode>.txt`. Версія задана у двох місцях: `project.godot` (`config/version`) і `export_presets.cfg` (`version/code`, `version/name`).
