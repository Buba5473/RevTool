# 📦 RevTool Static Builder

[🇷🇺 Русский](#-русский) | [🇬🇧 English](#-english)

## Содержание / Table of Contents

### 🇷🇺 Русский

- [Возможности](#-возможности)
- [Требования](#-требования)
- [Использование](#-использование)
- [Пиннинг версий и переменные окружения](#-пиннинг-версий-и-переменные-окружения)
- [Структура рабочей папки](#-структура-рабочей-папки)
- [Как это работает](#-как-это-работает)
- [Ключевые флаги оптимизации](#-ключевые-флаги-оптимизации)
- [Проверка результата](#-проверка-результата)
- [Возможные проблемы](#-возможные-проблемы)
- [Лицензия](#-лицензия)
- [Благодарности](#-благодарности)

### 🇬🇧 English

- [Features](#-features)
- [Requirements](#-requirements)
- [Usage](#-usage)
- [Version pinning and environment variables](#-version-pinning-and-environment-variables)
- [Working directory structure](#-working-directory-structure)
- [How it works](#-how-it-works)
- [Optimization flags](#-optimization-flags)
- [Verifying the result](#-verifying-the-result)
- [Troubleshooting](#-troubleshooting)
- [License](#-license)
- [Credits](#-credits)

---

## 🇷🇺 Русский

Скрипт автоматической сборки [RevTool](https://github.com/MorenoLopez/RevTool) в **один статический исполняемый файл** для Windows 10+ (amd64) с поддержкой дизассемблера **Capstone**.

Сборка выполняется в среде **MSYS2 UCRT64**, использует глубокую оптимизацию компилятора и включает весь рантайм MinGW-w64 в итоговый бинарник — никаких внешних DLL не требуется.

---

## ✨ Возможности

- 🔒 **Полностью статическая сборка** — один `.exe` без зависимостей от `libcapstone.dll`, `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`.
- ⚡ **Глубокая оптимизация** под amd64 (`-O3`, `-march=x86-64-v3`, `-flto`, `-DNDEBUG`, `-ffunction-sections`, `-fdata-sections`, `-Wl,--gc-sections`).
- 🧩 **Capstone собирается из исходников** как статическая библиотека (`libcapstone.a`) — в MSYS2 UCRT64 поставляется только динамическая версия.
- 🧼 **Изолированная сборка** — все действия выполняются в подпапке `build_revtool/`, которая полностью очищается перед началом работы.
- 🌿 **Пиннинг версий и автоопределение ветки** — RevTool по умолчанию берётся из **default-ветки** репозитория (автоопределение: `master`, `main` и т. п.), Capstone — из стабильного тега `5.0.9`. Обе зависимости клонируются с `--depth 1`; при указании `*_COMMIT` выполняется частичный клон по SHA.
- 🐧 **Совместимость с Windows 10+** — целевая микроархитектура `x86-64-v3` (AVX2), поддерживаемая всеми актуальными amd64-процессорами.
- 🧩 **Автоматический VT100** — `compat/auto_vt100.h` включает обработку ANSI-цветов
  через `SetConsoleMode(ENABLE_VIRTUAL_TERMINAL_PROCESSING)` — цветной вывод корректно
  отображается в cmd.exe без правки реестра.
- 🧬 **Авто-восстановление `-DUSE_CAPSTONE=1`** — `CFLAGS` из командной строки скрывает
  Makefile-овский `CFLAGS += -DUSE_CAPSTONE`; скрипт извлекает макрос из Makefile
  (или инжектит дефолт) — компилируется настоящий код Capstone, а не hex-dump fallback.
- 🧩 **POSIX shim для Windows** — RevTool использует `<sys/mman.h>` и `mmap`/`munmap`; build-скрипт генерирует локальный shim
  (`build_revtool/compat/{sys/mman.h,libmman.a}`), реализующий их через `CreateFileMapping`/`MapViewOfFile`/`VirtualAlloc`.

---

## 📋 Требования

| Компонент | Назначение |
| :--- | :--- |
| **Windows 10** или новее (x64) | Целевая ОС |
| **MSYS2** с окружением **UCRT64** | Среда сборки |
| `git` | Клонирование репозиториев |
| `mingw-w64-ucrt-x86_64-gcc` | Компилятор C/C++ |
| `mingw-w64-ucrt-x86_64-cmake` | Сборка Capstone |
| `mingw-w64-ucrt-x86_64-make` | Сборка RevTool |
| `mingw-w64-ucrt-x86_64-binutils` | `as`, `ld`, `strip`, **`objdump`** (используется для валидации DLL-зависимостей) |

### Установка зависимостей в MSYS2 UCRT64

Откройте терминал **MSYS2 UCRT64** (не MINGW64 и не CLANG64) и выполните:

```bash
pacman -S --needed git \
    mingw-w64-ucrt-x86_64-gcc \
    mingw-w64-ucrt-x86_64-cmake \
    mingw-w64-ucrt-x86_64-make \
    mingw-w64-ucrt-x86_64-binutils
```

> ⚠️ **Важно**: скрипт рассчитан именно на окружение **UCRT64**. Сборка в MINGW64 или CLANG64 не гарантирует корректный результат.

---

## 🚀 Использование

1. Скопируйте `build_revtool.sh` в удобный каталог, например в `C:\projects\revtool-build\`.
2. Откройте терминал **MSYS2 UCRT64** и перейдите в этот каталог:
   ```bash
   cd /c/projects/revtool-build
   ```
3. Сделайте скрипт исполняемым и запустите:
   ```bash
   chmod +x build_revtool.sh
   ./build_revtool.sh
   ```
4. Дождитесь завершения. Готовый бинарник появится по пути:
   ```
   build_revtool/RevTool/revtool.exe
   ```

### ⏱️ Время сборки

| Этап | Примерное время |
| :--- | :--- |
| Клонирование репозиториев | 10–30 с |
| Сборка Capstone (LTO) | 2–4 мин |
| Сборка RevTool (LTO) | 10–20 с |
| **Итого** | **~3–5 мин** |

---

## 🔒 Пиннинг версий и переменные окружения

По умолчанию RevTool клонируется из `master`, а Capstone — из тега **`5.0.9`**
(стабильный релиз). Скрипт печатает итоговые SHA-1 обоих репозиториев перед сборкой.

| Переменная | По умолчанию | Назначение |
| :--- | :--- | :--- |
| `REVTOOL_REF` / `REVTOOL_COMMIT` | *(default-ветка)* / — | Ветка/тег или точный SHA RevTool; если не задано — определяется default-ветка репозитория |
| `CAPSTONE_REF` / `CAPSTONE_COMMIT` | `5.0.9` / — | Ветка/тег или точный SHA Capstone |
| `REVTOOL_MARCH` | `x86-64-v3` | Целевая микроархитектура (для старых CPU — `x86-64-v2`) |
| `REVTOOL_CAPSTONE_ARCHS` | *(все)* | Напр. `X86` — резко сокращает время сборки Capstone |
| `REVTOOL_NO_STRIP` | `0` | `1` — отключить стриппинг |
| `REVTOOL_STRIP_FLAGS` | `--strip-all` | Флаги `strip` |
| `REVTOOL_CFLAGS_EXTRA` / `REVTOOL_LDFLAGS_EXTRA` | — | Дополнительные флаги поверх встроенных |
| `REVTOOL_TARGET` | `capstone` | Имя цели `make` в Makefile RevTool |
| `REVTOOL_SKIP_SMOKE` | `0` | `1` — отключить обязательный smoke-тест `revtool.exe --version` |

Пример воспроизводимой сборки:
```bash
# ветку/тег можно не указывать — скрипт определит default автоматически;
# для полного пиннинга укажите REVTOOL_REF=<branch-or-tag>
REVTOOL_COMMIT=$(git ls-remote https://github.com/MorenoLopez/RevTool.git HEAD | cut -f1) \
CAPSTONE_COMMIT=$(git ls-remote https://github.com/capstone-engine/capstone.git refs/tags/5.0.9 | cut -f1) \
./build_revtool.sh
```

---

## 📂 Структура рабочей папки

После успешной сборки структура каталога выглядит так:

```
<каталог_скрипта>/
├── build_revtool.sh                 # Этот скрипт
├── readme.md
└── build_revtool/                   # Рабочая папка (пересоздаётся при каждом запуске)
    ├── RevTool/                     # Исходники RevTool (default-ветка, у MorenoLopez — Master)
    │   └── revtool.exe              # ✅ Итоговый статический бинарник
    ├── capstone/                    # Исходники Capstone (тег 5.0.9)
    │   └── build/                   # Артефакты сборки Capstone
    └── capstone-install/            # Локальный префикс установки Capstone
        ├── include/capstone/        # Заголовочные файлы
        └── lib/libcapstone.a        # Статическая библиотека
```

> 🧹 При каждом повторном запуске папка `build_revtool/` **полностью удаляется** и создаётся заново — это гарантирует чистоту сборки и отсутствие «залипших» артефактов.

---

## 🔧 Как это работает

> ⚙️ Полный pipeline: clone → генерация shim'ов (`compat/*.h`, `libmman.a`) →
> сборка Capstone → извлечение `-DUSE_CAPSTONE` → сборка RevTool → strip →
> проверка DLL по whitelist → smoke-тест.

Скрипт выполняет следующие шаги:

### 1. Очистка рабочей папки
```bash
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
```

### 2. Клонирование исходников
```bash
# ref (master/main/...) определяется автоматически, если REVTOOL_REF не задан
git clone --depth 1 --branch <detected-ref> https://github.com/MorenoLopez/RevTool.git
git clone --depth 1 --branch 5.0.9 https://github.com/capstone-engine/capstone.git
```

### 3. Сборка Capstone как статической библиотеки

Ключевые флаги CMake:
- `-DBUILD_SHARED_LIBS=OFF` — только статическая библиотека
- `-DCAPSTONE_BUILD_TESTS=OFF` — без тестов
- `-DCMAKE_BUILD_TYPE=Release`
- `-DCMAKE_INSTALL_PREFIX=${CAPSTONE_PREFIX}` — локальный префикс, без вмешательства в MSYS2
- *(опционально)* `-DCAPSTONE_ARCHS=<список>` — ограничить набор поддерживаемых архитектур

### 4. Сборка RevTool с линковкой Capstone

Скрипт:
1. **До начала долгой сборки Capstone** проверяет, что в `Makefile` RevTool
   присутствует цель `capstone` (переопределяется через `REVTOOL_TARGET`),
   иначе падает с диагностикой доступных целей.
2. Определяет, используется ли `$(LDLIBS)` **в рецептах** `Makefile` (а не просто
   объявлено). Если да — `-lcapstone` передаётся через неё (**после** объектных
   файлов — важно для статической линковки). Если нет — выводит предупреждение
   и кладёт `-lcapstone` в `LDFLAGS`.
3. Сохраняет базовые `CFLAGS`/`LDFLAGS` из `Makefile` (учитываются `=` и `+=`;
   `?=` намеренно игнорируется — при передаче переменной через командную строку
   `make` его значение всё равно не используется) и объединяет их с
   оптимизационными флагами — это предотвращает потерю обязательных флагов.
4. Добавляет `REVTOOL_CFLAGS_EXTRA` / `REVTOOL_LDFLAGS_EXTRA`.

### 5. Проверка результата

Скрипт проверяет наличие `${REVTOOL_SRC}/revtool.exe`, выводит его тип (`file`) и размер.

---

## 🎛️ Ключевые флаги оптимизации

| Флаг | Назначение |
| :--- | :--- |
| `-O3` | Максимальная агрессивная оптимизация |
| `-march=x86-64-v3` | Микроархитектура с AVX2 (совместима с Windows 10+ amd64) |
| `-flto` | Link-Time Optimization — межмодульная оптимизация |
| `-DNDEBUG` | Отключение `assert()` и отладочных проверок |
| `-ffunction-sections` `-fdata-sections` | Гранулярное размещение функций/данных в секциях |
| `-Wl,--gc-sections` | Удаление неиспользуемых секций при линковке (существенно с LTO) |
| `-static` | Полностью статический рантайм (libgcc, libstdc++, libwinpthread включаются в PE без внешних DLL) |

---

## ✅ Проверка результата

После сборки убедитесь, что бинарник не зависит от внешних DLL:

```bash
# В MSYS2 UCRT64
objdump -p build_revtool/RevTool/revtool.exe | grep "DLL Name"
```

В списке должны присутствовать **только системные библиотеки Windows** (`KERNEL32.dll`, `msvcrt.dll`, `api-ms-win-crt-*` и т. п.). Не должно быть `libcapstone.dll`, `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`.

Скрипт проверяет DLL автоматически по **белому списку системных DLL Windows**
и **завершается с ошибкой** при обнаружении любой несистемной DLL (включая
`libcapstone.dll`, `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`
и любые другие). Дополнительно выполняется **обязательный** smoke-тест
`revtool.exe --version` (отключается через `REVTOOL_SKIP_SMOKE=1`).

Быстрая проверка работоспособности:

```bash
./build_revtool/RevTool/revtool.exe --version
./build_revtool/RevTool/revtool.exe info /c/Windows/System32/notepad.exe
./build_revtool/RevTool/revtool.exe disasm -a x64 -o 0x400 -s 256 /c/Windows/System32/notepad.exe
```

---

## 🩺 Возможные проблемы

### `[Capstone not available - showing hex dump]`

Макрос `-DUSE_CAPSTONE=1` не дошёл до компилятора (`CFLAGS` из командной
строки скрывает Makefile-овский `CFLAGS += -DUSE_CAPSTONE`). Скрипт пытается
извлечь макрос из Makefile автоматически; если не вышло — задайте вручную:

```bash
REVTOOL_CFLAGS_EXTRA="-DUSE_CAPSTONE=1" ./build_revtool.sh
```

### `\x1b[36m` / `\x1b[1m` — «кракозябры» вместо цветов

ANSI-escape рендерятся в терминале без VT100. Скрипт встраивает конструктор,
включающий `SetConsoleMode(ENABLE_VIRTUAL_TERMINAL_PROCESSING)` до `main()`.
Если коды всё равно видны — запускайте в **Windows Terminal** или **mintty**.
Для логов в файл (`revtool.exe ... > out.txt`) чистите так:

```bash
sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' out.txt
```

### `sys/mman.h: No such file or directory`

mman-shim не сгенерирован. Проверьте, что существует
`build_revtool/compat/sys/mman.h` — его создаёт `build_revtool.sh`
перед сборкой RevTool.

### `cmake: command not found`
Не установлен CMake. Установите:
```bash
pacman -S mingw-w64-ucrt-x86_64-cmake
```

### `gcc: command not found`
Вы находитесь в неправильном окружении. Проверьте, что терминал называется **MSYS2 UCRT64**, а не MINGW64/CLANG64:
```bash
echo $MSYSTEM   # должно вывести UCRT64
```

### Ошибка линковки `undefined reference to ...capstone...`
Capstone не собрался или не установился в `${CAPSTONE_PREFIX}`. Проверьте наличие файла `build_revtool/capstone-install/lib/libcapstone.a`.

### `undefined reference to cs_disasm` / `cs_open` / прочие `cs_*`

Makefile RevTool не использует `LDLIBS`, и `-lcapstone` попадает в `LDFLAGS`,
которые в этом Makefile раскрываются **до** объектных файлов. Для статической
линковки порядок критичен. Решение — добавить в `Makefile` RevTool переменную
`LDLIBS` и использовать её в правиле линковки после `$^`:

```makefile
LDLIBS =
...
$(TARGET): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)
```

Скрипт автоматически проверит использование `$(LDLIBS)` в рецептах `Makefile`
и переключится на корректный режим линковки.

### `[!] Требуется окружение MSYS2 UCRT64`

Скрипт теперь **жёстко требует** `MSYSTEM=UCRT64` и завершается с ошибкой в
MINGW64/CLANG64. Это осознанное решение: результаты в других окружениях
не гарантированы.

### Сборка на старом CPU

По умолчанию — `-march=x86-64-v3` (AVX2). Для процессоров без AVX2:
```bash
REVTOOL_MARCH=x86-64-v2 ./build_revtool.sh
```

### `-march=x86-64-v3` не поддерживается компилятором
Обновите GCC:
```bash
pacman -Syu
pacman -S mingw-w64-ucrt-x86_64-gcc
```

### Бинарник не запускается на целевой машине
Убедитесь, что целевой процессор поддерживает **AVX2** (обязательно для `x86-64-v3`). Для более старых процессоров замените `-march=x86-64-v3` на `-march=x86-64-v2` в скрипте.

---

## 📜 Лицензия

Скрипт распространяется под лицензией **MIT**.

RevTool распространяется под лицензией **MIT** ([оригинальный репозиторий](https://github.com/MorenoLopez/RevTool)).
Capstone распространяется под лицензией **BSD-3-Clause** ([оригинальный репозиторий](https://github.com/capstone-engine/capstone)).

Итоговый бинарник содержит код обеих библиотек — при распространении учитывайте условия соответствующих лицензий.

---

## 🙏 Благодарности

- [MorenoLopez/RevTool](https://github.com/MorenoLopez/RevTool) — за сам инструмент.
- [capstone-engine/capstone](https://github.com/capstone-engine/capstone) — за движок дизассемблирования.
- Сообществу **MSYS2** — за превосходный toolchain для Windows.

---

## 🇬🇧 English

Build script that compiles [RevTool](https://github.com/MorenoLopez/RevTool) into a **single static executable** for Windows 10+ (amd64) with disassembler support via **Capstone**.

The build runs in **MSYS2 UCRT64**, uses aggressive compiler optimization, and embeds the entire MinGW-w64 runtime — no external DLLs required.

---

## ✨ Features

- 🔒 **Fully static build** — one `.exe` with no dependencies on `libcapstone.dll`, `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, or `libwinpthread-1.dll`.
- ⚡ **Deep optimization** for amd64 (`-O3`, `-march=x86-64-v3`, `-flto`, `-DNDEBUG`, `-ffunction-sections`, `-fdata-sections`, `-Wl,--gc-sections`).
- 🧩 **Capstone built from source** as a static library (`libcapstone.a`) — MSYS2 UCRT64 ships only the dynamic version.
- 🧼 **Isolated build** — everything happens in `build_revtool/`, fully wiped on each run.
- 🌿 **Version pinning & auto-detection** — RevTool comes from the repository's **default branch** (auto-detected: `master`, `main`, etc.), Capstone — from the stable tag `5.0.9`. Both are cloned with `--depth 1`; when a `*_COMMIT` is given, a partial SHA clone is used.
- 🐧 **Windows 10+ compatibility** — target micro-architecture `x86-64-v3` (AVX2), supported by all modern amd64 CPUs.
- 🧩 **POSIX shim for Windows** — RevTool uses `<sys/mman.h>` and `mmap`/`munmap`; the build script generates a local shim (`build_revtool/compat/{sys/mman.h,libmman.a}`) implementing them via `CreateFileMapping`/`MapViewOfFile`/`VirtualAlloc`.
- 🎨 **Automatic VT100** — `compat/auto_vt100.h` enables ANSI color processing via `SetConsoleMode(ENABLE_VIRTUAL_TERMINAL_PROCESSING)`, so colored output renders correctly in cmd.exe without touching the registry.
- 🧬 **Auto-restored `-DUSE_CAPSTONE=1`** — the `CFLAGS` override on the command line hides the Makefile's `CFLAGS += -DUSE_CAPSTONE`; the script extracts the macro from the Makefile (or injects the default) so the real Capstone code path is compiled instead of the hex-dump fallback.

---

## 📋 Requirements

| Component | Purpose |
| :--- | :--- |
| **Windows 10** or newer (x64) | Target OS |
| **MSYS2** with **UCRT64** environment | Build environment |
| `git` | Clone repositories |
| `mingw-w64-ucrt-x86_64-gcc` | C/C++ compiler |
| `mingw-w64-ucrt-x86_64-cmake` | Build Capstone |
| `mingw-w64-ucrt-x86_64-make` | Build RevTool |
| `mingw-w64-ucrt-x86_64-binutils` | `as`, `ld`, `ar`, `strip`, **`objdump`** (for DLL validation) |

### Installing dependencies in MSYS2 UCRT64

```bash
pacman -S --needed git \
    mingw-w64-ucrt-x86_64-gcc \
    mingw-w64-ucrt-x86_64-cmake \
    mingw-w64-ucrt-x86_64-make \
    mingw-w64-ucrt-x86_64-binutils
```

> ⚠️ **Important**: the script targets UCRT64 only. Building in MINGW64 or CLANG64 is not guaranteed to work.

---

## 🚀 Usage

1. Copy `build_revtool.sh` to a convenient directory, e.g. `C:\projects\revtool-build\`.
2. Open a **MSYS2 UCRT64** terminal and `cd` there.
3. Make the script executable and run it:

   ```bash
   chmod +x build_revtool.sh
   ./build_revtool.sh
   ```

4. The resulting binary is placed at `build_revtool/RevTool/revtool.exe`.

### ⏱️ Build time

| Stage | Approx. time |
| :--- | :--- |
| Cloning repositories | 10–30 s |
| Capstone build (LTO) | 2–4 min |
| RevTool build (LTO) | 10–20 s |
| **Total** | **~3–5 min** |

---

## 🔒 Version pinning and environment variables

By default RevTool is cloned from the repository's default branch (auto-detected: `master`, `main`, etc.), Capstone — from tag `5.0.9` (stable release). The script prints the resolved SHA-1 for both repos before building.

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `REVTOOL_REF` / `REVTOOL_COMMIT` | *(default branch)* / — | Branch/tag or exact SHA of RevTool; if unset, the repository's default branch is used |
| `CAPSTONE_REF` / `CAPSTONE_COMMIT` | `5.0.9` / — | Branch/tag or exact SHA of Capstone |
| `REVTOOL_MARCH` | `x86-64-v3` | Target micro-architecture (`x86-64-v2` for older CPUs) |
| `REVTOOL_CAPSTONE_ARCHS` | *(all)* | e.g. `X86` — dramatically cuts Capstone build time |
| `REVTOOL_NO_STRIP` | `0` | `1` — disable stripping |
| `REVTOOL_STRIP_FLAGS` | `--strip-all` | Flags for `strip` |
| `REVTOOL_CFLAGS_EXTRA` / `REVTOOL_LDFLAGS_EXTRA` | — | Extra flags on top of the built-in ones |
| `REVTOOL_TARGET` | `capstone` | Name of the `make` target in RevTool's Makefile |
| `REVTOOL_SKIP_SMOKE` | `0` | `1` — skip the mandatory `revtool.exe --version` smoke test |

Reproducible build example:

```bash
REVTOOL_COMMIT=$(git ls-remote https://github.com/MorenoLopez/RevTool.git HEAD | cut -f1) \
CAPSTONE_COMMIT=$(git ls-remote https://github.com/capstone-engine/capstone.git refs/tags/5.0.9 | cut -f1) \
./build_revtool.sh
```

---

## 📂 Working directory structure

```text
<script_dir>/
├── build_revtool.sh                 # This script
├── readme.md
└── build_revtool/                   # Working dir (recreated each run)
    ├── RevTool/                     # RevTool sources (default branch)
    │   └── revtool.exe              # ✅ Final static binary
    ├── capstone/                    # Capstone sources (tag 5.0.9)
    │   └── build/                   # Capstone build artifacts
    ├── capstone-install/            # Local Capstone install prefix
    │   ├── include/capstone/        # Header files
    │   └── lib/libcapstone.a        # Static library
    ├── compat/                      # Windows compatibility shims
    │   ├── sys/mman.h               # mmap/munmap declarations
    │   ├── mman_win32.c             # WinAPI implementation
    │   ├── libmman.a                # Static shim library
    │   └── auto_vt100.h             # VT100 auto-enable (via -include)
    └── revtool_make.log             # Full make output (created on every build)
```

> 🧹 On each run, `build_revtool/` is fully removed and recreated — clean builds, no stale artifacts.

---

## 🔧 How it works

> ⚙️ Full pipeline: clone → shim generation (`compat/*.h`, `libmman.a`) → Capstone build → `-DUSE_CAPSTONE` extraction → RevTool build → strip → whitelist DLL check → smoke test.

1. **Cleaning the working directory**

   ```bash
   rm -rf "${BUILD_ROOT}"
   mkdir -p "${BUILD_ROOT}"
   ```

2. **Cloning sources**

   If `*_COMMIT` is given, `git init` + `git fetch --depth 1 origin <sha>` is used (with a full-fetch fallback). Otherwise `git clone --depth 1 --branch <ref>` with the ref auto-detected from the remote when not specified.

3. **Building Capstone as a static library**

   Key CMake flags:

   - `-DBUILD_SHARED_LIBS=OFF` — static only
   - `-DCAPSTONE_BUILD_TESTS=OFF`
   - `-DCMAKE_BUILD_TYPE=Release`
   - `-DCMAKE_INSTALL_PREFIX=${CAPSTONE_PREFIX}` — local prefix
   - *(optional)* `-DCAPSTONE_ARCHS=<list>` — restrict architectures

4. **Generating the Windows POSIX shim**

   `compat/sys/mman.h` + `compat/mman_win32.c` → `compat/libmman.a`. Implements `mmap`, `munmap`, `mprotect`, `msync` via `CreateFileMapping` / `MapViewOfFile` / `VirtualAlloc`.

5. **Generating the VT100 helper**

   `compat/auto_vt100.h` is injected into every translation unit via `-include auto_vt100.h`. A `__attribute__((constructor))` enables `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on stdout/stderr before `main()` — no registry edits.

6. **Restoring `-DUSE_CAPSTONE=1`**

   Since `CFLAGS=` on the command line overrides the Makefile's `CFLAGS += -DUSE_CAPSTONE`, the script extracts the macro (or falls back to `-DUSE_CAPSTONE=1`) and appends it to `CFLAGS`.

7. **Building RevTool with static Capstone**

   The script:

   1. Verifies the target (`REVTOOL_TARGET`, default `capstone`) exists in the Makefile — fails early with a diagnostics dump of available targets otherwise.
   2. Detects whether `$(LDLIBS)` is used in recipes (not just declared). If yes — `-lcapstone -lmman` go through it (after object files, essential for static linking). If no — a warning is printed and the libs go into `LDFLAGS`.
   3. Preserves base `CFLAGS`/`LDFLAGS` from the Makefile (both `=` and `+=` are honoured; `?=` is intentionally skipped).
   4. Adds `REVTOOL_CFLAGS_EXTRA` / `REVTOOL_LDFLAGS_EXTRA`.

8. **Verifying the result**

   The binary is stripped (`strip --strip-all`, `REVTOOL_NO_STRIP=1` disables).

   DLL dependencies are checked against a whitelist of Windows system DLLs — any non-system DLL aborts the build.

   A mandatory smoke test (`revtool.exe --version`) runs unless `REVTOOL_SKIP_SMOKE=1`.

---

## 🎛️ Optimization flags

| Flag | Purpose |
| :--- | :--- |
| `-O3` | Maximum aggressive optimization |
| `-march=x86-64-v3` | Micro-architecture with AVX2 (Windows 10+ amd64 compatible) |
| `-flto` | Link-Time Optimization |
| `-DNDEBUG` | Disable `assert()` and debug checks |
| `-ffunction-sections` `-fdata-sections` | Granular section placement |
| `-Wl,--gc-sections` | Drop unused sections at link (very effective with LTO) |
| `-static` | Fully static runtime (`libgcc`, `libstdc++`, `libwinpthread` bundled into the PE) |

---

## ✅ Verifying the result

```bash
objdump -p build_revtool/RevTool/revtool.exe | grep "DLL Name"
```

Expected: only Windows system libraries (`KERNEL32.dll`, `api-ms-win-crt-*`). No `libcapstone.dll`, `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, or `libwinpthread-1.dll`.

Quick sanity checks:

```bash
./build_revtool/RevTool/revtool.exe --version
./build_revtool/RevTool/revtool.exe info /c/Windows/System32/notepad.exe
./build_revtool/RevTool/revtool.exe disasm -a x64 -o 0x400 -s 256 /c/Windows/System32/notepad.exe
```

---

## 🩺 Troubleshooting

### `cmake: command not found` / `gcc: command not found`

Missing toolchain — install via `pacman -S mingw-w64-ucrt-x86_64-{gcc,cmake,make,binutils}`. Verify `echo $MSYSTEM` prints `UCRT64`.

### `[Capstone not available - showing hex dump]`

`-DUSE_CAPSTONE=1` did not reach the compiler (the `CFLAGS` override hid the Makefile's `+=` line). The script extracts the macro from the Makefile automatically; if that fails, pass it explicitly:

```bash
REVTOOL_CFLAGS_EXTRA="-DUSE_CAPSTONE=1" ./build_revtool.sh
```

### `\x1b[36m` / `\x1b[1m` garbage in output

ANSI escapes rendered in a terminal without VT100. The build script now embeds a constructor that calls `SetConsoleMode(ENABLE_VIRTUAL_TERMINAL_PROCESSING)` before `main()`. If you still see raw codes, run inside Windows Terminal or mintty. For files (`revtool.exe ... > out.txt`), strip with:

```bash
sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' out.txt
```

### `sys/mman.h: No such file or directory`

The mman shim was not generated. Verify `build_revtool/compat/sys/mman.h` exists — it is created by `build_revtool.sh` before the RevTool build.

### `undefined reference to cs_*`

Capstone was not built or not linked. Check `build_revtool/capstone-install/lib/libcapstone.a`. If the Makefile's `LDFLAGS` appear before objects, switch to `LDLIBS`:

```makefile
LDLIBS =
$(TARGET): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)
```

The script auto-detects `$(LDLIBS)` in recipes and switches to the correct link order.

### `[!] Требуется окружение MSYS2 UCRT64`

The script requires `MSYSTEM=UCRT64`. Other environments (MINGW64/CLANG64) are not supported.

### Older CPU

By default `-march=x86-64-v3` (AVX2). For CPUs without AVX2:

```bash
REVTOOL_MARCH=x86-64-v2 ./build_revtool.sh
```

---

## 📜 License

Build script: **MIT**

RevTool: **MIT** ([original repo](https://github.com/MorenoLopez/RevTool))

Capstone: **BSD-3-Clause** ([original repo](https://github.com/capstone-engine/capstone))

The resulting binary contains code from both projects — comply with both licenses when distributing.

---

## 🙏 Credits

- [MorenoLopez/RevTool](https://github.com/MorenoLopez/RevTool) — the tool itself.
- [capstone-engine/capstone](https://github.com/capstone-engine/capstone) — the disassembly engine.
- The **MSYS2** community for an excellent Windows toolchain.