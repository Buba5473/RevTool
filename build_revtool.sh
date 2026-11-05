#!/usr/bin/env bash
# build_revtool.sh — статическая сборка RevTool (+ Capstone) в один бинарник
# Windows 10+ amd64. Запуск из терминала MSYS2 UCRT64.
# Переменные окружения: REVTOOL_REF/REVTOOL_COMMIT, CAPSTONE_REF/CAPSTONE_COMMIT,
# REVTOOL_MARCH, REVTOOL_CAPSTONE_ARCHS, REVTOOL_CFLAGS_EXTRA, REVTOOL_LDFLAGS_EXTRA,
# Если REVTOOL_REF не задан, default-ветка репозитория определяется автоматически (master/main/др.).
set -euo pipefail

die(){ echo "[!] $*" >&2; exit 1; }
msg(){ echo "[*] $*"; }

# --- Конфигурация ---
R_REPO=https://github.com/MorenoLopez/RevTool.git
C_REPO=https://github.com/capstone-engine/capstone.git
R_REF=${REVTOOL_REF:-}; R_COMMIT=${REVTOOL_COMMIT:-}
C_REF=${CAPSTONE_REF:-5.0.9}; C_COMMIT=${CAPSTONE_COMMIT:-}
MARCH=${REVTOOL_MARCH:-x86-64-v3}
CAP_ARCHS=${REVTOOL_CAPSTONE_ARCHS:-}
STRIP_FLAGS=${REVTOOL_STRIP_FLAGS:---strip-all}
DO_STRIP=$([[ ${REVTOOL_NO_STRIP:-0} == 1 ]] && echo 0 || echo 1)
CF_X=${REVTOOL_CFLAGS_EXTRA:-}; LD_X=${REVTOOL_LDFLAGS_EXTRA:-}
TARGET=${REVTOOL_TARGET:-capstone}
SKIP_SMOKE=${REVTOOL_SKIP_SMOKE:-0}

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_revtool
R_SRC=$ROOT/RevTool; C_SRC=$ROOT/capstone; C_PFX=$ROOT/capstone-install

msg "Корень: $ROOT"
msg "RevTool: ${R_REF:-<auto>}${R_COMMIT:+ @ $R_COMMIT}; Capstone: ${C_REF:-<auto>}${C_COMMIT:+ @ $C_COMMIT}"
msg "-march=$MARCH; стриппинг: $DO_STRIP (${STRIP_FLAGS})"

# --- Проверки ---
[[ -n $ROOT && $ROOT != "/" ]] || die "Подозрительный ROOT='$ROOT'"
[[ ${MSYSTEM:-} == UCRT64 ]] || die "Требуется окружение MSYS2 UCRT64 (MSYSTEM=${MSYSTEM:-не задан}). Откройте терминал 'MSYS2 UCRT64'."
for t in git gcc make cmake ar strip objdump; do
    command -v "$t" &>/dev/null || die "Не найден '$t'. Установите: pacman -S --needed git mingw-w64-ucrt-x86_64-{gcc,make,cmake,binutils}"
done

# --- Очистка и клонирование ---
rm -rf "$ROOT" && mkdir -p "$ROOT"

default_branch(){
    git ls-remote --symref "$1" HEAD 2>/dev/null \
        | sed -nE 's#^ref:[[:space:]]+refs/heads/([^[:space:]]+)[[:space:]]+HEAD$#\1#p' \
        | head -1
}

clone(){ # clone <url> <ref> <commit> <dest>
    if [[ -n $3 ]]; then
        mkdir -p "$4"
        git -C "$4" init -q
        git -C "$4" remote add origin "$1"
        if ! git -C "$4" fetch --depth 1 origin "$3" 2>/dev/null; then
            # fallback: SHA недостижим по прямой ссылке — тянем всю историю
            git -C "$4" fetch origin
        fi
        # 5.0.9 — аннотированный тег; --detach с тегом пишет warning
        # "не является коммитом", после чего git сам переключается
        # на коммит, на который указывает тег. Подавляем шум.
        git -C "$4" checkout --detach --quiet "$3"
    else
        local url=$1 ref=$2 dest=$4
        if [[ -z $ref ]]; then
            ref=$(default_branch "$url")
            [[ -n $ref ]] || die "Не удалось определить default-ветку в $url"
            msg "Ветка не задана — использую default-ветку '$ref'"
        elif ! git ls-remote --exit-code --heads "$url" "$ref" &>/dev/null \
             && ! git ls-remote --exit-code --tags "$url" "$ref" &>/dev/null; then
            local detected
            detected=$(default_branch "$url")
            [[ -n $detected ]] || die "Ссылка '$ref' отсутствует в $url, и не удалось определить default-ветку"
            if [[ "$ref" != "$detected" ]]; then
                msg "Ссылка '$ref' отсутствует в $url — использую default-ветку '$detected'"
                ref=$detected
            fi
        fi
        git clone --depth 1 --branch "$ref" "$url" "$dest"
    fi
    msg "$(basename "$4"): $(git -C "$4" rev-parse HEAD)"
}

msg "Клонирование RevTool и Capstone..."
clone "$R_REPO" "$R_REF" "$R_COMMIT" "$R_SRC"
clone "$C_REPO" "$C_REF" "$C_COMMIT" "$C_SRC"

# --- Контракт с Makefile RevTool (до долгой сборки Capstone) ---
MAKE=$R_SRC/Makefile
[[ -f $MAKE ]] || die "Не найден $MAKE"
if ! grep -qE "^${TARGET}[[:space:]]*:" "$MAKE"; then
    echo "[!] В Makefile RevTool нет цели '${TARGET}' (REVTOOL_TARGET). Найденные цели:" >&2
    grep -E '^[a-zA-Z_][a-zA-Z0-9_-]*[[:space:]]*:' "$MAKE" | sed -E 's/[[:space:]]*:.*//;s/^/    /' >&2
    exit 1
fi
# $(LDLIBS) должно использоваться в рецептах (строки с отступом),
# а не просто быть объявлено.
if grep -qE '^[[:space:]]+.*\$\{?LDLIBS\}?' "$MAKE"; then
    LDLIBS_USED=1
else
    LDLIBS_USED=0
fi

# --- Capstone (static, Release, LTO) ---
msg "Сборка Capstone..."
CAP_ARGS=()
[[ -n $CAP_ARCHS ]] && CAP_ARGS=(-DCAPSTONE_ARCHS="$CAP_ARCHS")
cmake -S "$C_SRC" -B "$C_SRC/build" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$C_PFX" \
    -DBUILD_SHARED_LIBS=OFF -DCAPSTONE_BUILD_TESTS=OFF \
    -DCMAKE_C_FLAGS="-O3 -march=$MARCH -flto -DNDEBUG -ffunction-sections -fdata-sections" \
    -DCMAKE_EXE_LINKER_FLAGS="-flto -static" \
    "${CAP_ARGS[@]}"
cmake --build "$C_SRC/build" --config Release --parallel
cmake --install "$C_SRC/build"
[[ -f $C_PFX/lib/libcapstone.a ]] || die "libcapstone.a не найден после установки Capstone"

# --- RevTool ---
# --- Windows POSIX shim: sys/mman.h ---
# RevTool включает <sys/mman.h> и использует mmap/munmap — этих
# функций нет в MinGW-w64/UCRT64 (POSIX vs Windows). Генерируем
# минимальную обёртку над WinAPI (CreateFileMapping/VirtualAlloc).
mkdir -p "$ROOT/compat"
cat > "$ROOT/compat/auto_vt100.h" <<'VT100_H_EOF'
#ifndef REVTOOL_AUTO_VT100_H
#define REVTOOL_AUTO_VT100_H

#ifdef _WIN32
#include <windows.h>

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

/*
 * Подключается через `-include auto_vt100.h` ко всем TU RevTool.
 * __attribute__((constructor)) кладёт функцию в .CRT$XCU — CRT вызывает
 * её до main(). Если stdout/stderr — реальная консоль, включаем VT100
 * локально для процесса (аналог VirtualTerminalLevel в реестре, но без
 * постоянных изменений в системе). На редиректе / pre-Win10 — no-op.
 *
 * static — чтобы при -include в N TU линковщик не ругался на дубли.
 * Многократный вызов SetConsoleMode идемпотентен.
 */
__attribute__((constructor))
static void revtool_enable_console_vt100(void)
{
    DWORD mode = 0;

    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hOut != INVALID_HANDLE_VALUE && GetConsoleMode(hOut, &mode))
        SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

    HANDLE hErr = GetStdHandle(STD_ERROR_HANDLE);
    if (hErr != INVALID_HANDLE_VALUE && GetConsoleMode(hErr, &mode))
        SetConsoleMode(hErr, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
}
#endif /* _WIN32 */

#endif /* REVTOOL_AUTO_VT100_H */
VT100_H_EOF
msg "Создание Windows-shim для <sys/mman.h>..."
mkdir -p "$ROOT/compat/sys"
cat > "$ROOT/compat/sys/mman.h" <<'MMAN_H_EOF'
#ifndef REVTOOL_MMAN_WIN32_H
#define REVTOOL_MMAN_WIN32_H
#include <stddef.h>
#include <sys/types.h>

#ifndef PROT_READ
#define PROT_READ  0x1
#endif
#ifndef PROT_WRITE
#define PROT_WRITE 0x2
#endif
#ifndef PROT_EXEC
#define PROT_EXEC  0x4
#endif

#ifndef MAP_SHARED
#define MAP_SHARED    0x01
#endif
#ifndef MAP_PRIVATE
#define MAP_PRIVATE   0x02
#endif
#ifndef MAP_FIXED
#define MAP_FIXED     0x10
#endif
#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS 0x20
#endif
#ifndef MAP_ANON
#define MAP_ANON      MAP_ANONYMOUS
#endif

#define MAP_FAILED ((void *)-1)

#ifndef MS_ASYNC
#define MS_ASYNC 1
#endif
#ifndef MS_SYNC
#define MS_SYNC  4
#endif

#ifdef __cplusplus
extern "C" {
#endif
void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
int   munmap(void *addr, size_t length);
int   mprotect(void *addr, size_t len, int prot);
int   msync(void *addr, size_t length, int flags);
#ifdef __cplusplus
}
#endif

#endif
MMAN_H_EOF

cat > "$ROOT/compat/mman_win32.c" <<'MMAN_C_EOF'
#include <windows.h>
#include <sys/mman.h>
#include <io.h>
#include <errno.h>

static DWORD pick_page_prot(int prot) {
    if (prot & PROT_EXEC) return PAGE_EXECUTE_READWRITE;
    if (prot & PROT_WRITE) return PAGE_READWRITE;
    return PAGE_READONLY;
}

void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset) {
    (void)addr;
    HANDLE hMap;
    void  *p;
    DWORD  flProtect = pick_page_prot(prot);
    DWORD  dwAccess;
    ULARGE_INTEGER off;

    if (fd >= 0 && !(flags & MAP_ANONYMOUS)) {
        intptr_t osf = _get_osfhandle(fd);
        if (osf == -1) { errno = EBADF; return MAP_FAILED; }

        if ((prot & PROT_READ) && (prot & PROT_WRITE)) {
            if (flags & MAP_SHARED) { flProtect = PAGE_READWRITE; dwAccess = FILE_MAP_ALL_ACCESS; }
            else                    { flProtect = PAGE_WRITECOPY; dwAccess = FILE_MAP_COPY; }
        } else if (prot & PROT_WRITE) {
            flProtect = PAGE_READWRITE; dwAccess = FILE_MAP_ALL_ACCESS;
        } else if (prot & PROT_EXEC) {
            flProtect = PAGE_EXECUTE_READ; dwAccess = FILE_MAP_EXECUTE | FILE_MAP_READ;
        } else {
            flProtect = PAGE_READONLY; dwAccess = FILE_MAP_READ;
        }

        hMap = CreateFileMappingA((HANDLE)osf, NULL, flProtect, 0, 0, NULL);
        if (!hMap) { errno = EINVAL; return MAP_FAILED; }

        off.QuadPart = (ULONGLONG)offset;
        p = MapViewOfFile(hMap, dwAccess,
                          (DWORD)(off.QuadPart >> 32),
                          (DWORD)(off.QuadPart & 0xFFFFFFFF),
                          length);
        CloseHandle(hMap);
        if (!p) { errno = ENOMEM; return MAP_FAILED; }
        return p;
    }

    p = VirtualAlloc(NULL, length, MEM_RESERVE | MEM_COMMIT, flProtect);
    if (!p) { errno = ENOMEM; return MAP_FAILED; }
    return p;
}

int munmap(void *addr, size_t length) {
    (void)length;
    if (!addr || addr == MAP_FAILED) { errno = EINVAL; return -1; }
    if (UnmapViewOfFile(addr)) return 0;
    if (VirtualFree(addr, 0, MEM_RELEASE)) return 0;
    errno = EINVAL;
    return -1;
}

int mprotect(void *addr, size_t len, int prot) {
    DWORD oldProt;
    if (!VirtualProtect(addr, len, pick_page_prot(prot), &oldProt)) {
        errno = EINVAL;
        return -1;
    }
    return 0;
}

int msync(void *addr, size_t length, int flags) {
    (void)addr; (void)length; (void)flags;
    return 0;
}
MMAN_C_EOF

if ! gcc -I"$ROOT/compat" -O2 -c -o "$ROOT/compat/mman_win32.o" "$ROOT/compat/mman_win32.c"; then
    die "Не удалось скомпилировать compat/mman_win32.c"
fi
ar rcs "$ROOT/compat/libmman.a" "$ROOT/compat/mman_win32.o" \
    || die "Не удалось создать libmman.a (нет ar?)"
[[ -f $ROOT/compat/libmman.a ]] || die "libmman.a не создан"
msg "Shim готов: $ROOT/compat/libmman.a"

# --- Конец Windows POSIX shim ---

msg "Сборка RevTool (static, LTO, $MARCH)..."
msg "LTO-компиляция медленнее обычной — это нормально, пожалуйста, подождите"

# Если в Makefile CFLAGS/LDFLAGS заданы через '=' (не '?='), при передаче в командной
# строке они бы потерялись — вытаскиваем и сохраняем.
# Извлекает объединённые значения CFLAGS/LDFLAGS из Makefile.
# Учитываются "=" и "+="; "?=" игнорируется — при передаче переменной
# через командную строку make значение ?= всё равно не используется.
# Извлекает объединённые значения CFLAGS/LDFLAGS из Makefile.
# Учитываются "=" и "+="; "?=" игнорируется — при передаче переменной
# через командную строку make значение ?= всё равно не используется.
# Реализация через grep|sed — проще и без awk-конкатенации regex-строк.
base_flag(){
    local name=$1
    # pipefail + set -e: если grep ничего не нашёл (нет CFLAGS в Makefile),
    # труба вернёт 1 и base_flag убьёт скрипт. || true внутри группы — фикс.
    { grep -E "^${name}[[:space:]]*([+]?=)" "$MAKE" 2>/dev/null || true; } \
        | sed -E "s/^${name}[[:space:]]*[+]?=[[:space:]]*//" \
        | tr '\n' ' ' \
        | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}
BASE_C=$(base_flag CFLAGS || true); BASE_L=$(base_flag LDFLAGS || true)
[[ -n $BASE_C ]] && msg "Базовые CFLAGS из Makefile: $BASE_C"
[[ -n $BASE_L ]] && msg "Базовые LDFLAGS из Makefile: $BASE_L"

FC="${BASE_C:+$BASE_C }-I$ROOT/compat -include auto_vt100.h -I$C_PFX/include -O3 -march=$MARCH -flto -DNDEBUG -ffunction-sections -fdata-sections ${CF_X:+$CF_X }"

# Makefile RevTool оборачивает код Capstone в #ifdef USE_CAPSTONE
# (или похожий макрос). Так как мы передаём CFLAGS из командной
# строки, Makefile-овское `CFLAGS += -DUSE_CAPSTONE` теряется —
# без макроса компилируется hex-dump fallback. Восстанавливаем:
#  1. Пытаемся извлечь точное имя макроса из Makefile
#  2. Если не нашли — используем -DUSE_CAPSTONE=1 по умолчанию
CAPSTONE_MACRO=""
if grep -q "USE_CAPSTONE" "$MAKE"; then
    CAPSTONE_MACRO=$(grep -E "^[^#].*(CFLAGS|CPPFLAGS|DEFINES)" "$MAKE" \
        | grep -oE -- '-D[^ ]*CAPSTONE[^ ]*' \
        | sort -u | head -1)
    [[ -z $CAPSTONE_MACRO ]] && CAPSTONE_MACRO="-DUSE_CAPSTONE=1"
    msg "Capstone macro: $CAPSTONE_MACRO"
    FC="$FC $CAPSTONE_MACRO"
fi
FL="${BASE_L:+$BASE_L }-L$ROOT/compat -flto -static -Wl,--gc-sections ${LD_X:+$LD_X }"

msg "CFLAGS=$FC"
msg "LDFLAGS=$FL"
msg "TARGET=$TARGET, LDLIBS_USED=$LDLIBS_USED, CAPSTONE_MACRO=${CAPSTONE_MACRO:-<none>}"
if [[ $LDLIBS_USED == 1 ]]; then
    MAKE_LOG=$ROOT/revtool_make.log
    msg "Лог make: $MAKE_LOG (можно мониторить: tail -f \"$MAKE_LOG\")"
    if ! make -C "$R_SRC" "$TARGET" CC=gcc CFLAGS="$FC" LDFLAGS="$FL" LDLIBS="-L$C_PFX/lib -lcapstone -lmman" 2>&1 | tee "$MAKE_LOG"; then
        echo "[!] make завершился с ошибкой. Хвост лога $MAKE_LOG:" >&2
        tail -80 "$MAKE_LOG" >&2
        exit 1
    fi
else
    echo "[!] Makefile не использует LDLIBS: -lcapstone добавлен в LDFLAGS." >&2
    echo "    При 'undefined reference to cs_*' — LDFLAGS в Makefile стоит до объектов, исправьте Makefile." >&2
    MAKE_LOG=$ROOT/revtool_make.log
    msg "Лог make: $MAKE_LOG (можно мониторить: tail -f \"$MAKE_LOG\")"
    if ! make -C "$R_SRC" "$TARGET" CC=gcc CFLAGS="$FC" LDFLAGS="$FL -L$C_PFX/lib -lcapstone -lmman" 2>&1 | tee "$MAKE_LOG"; then
        echo "[!] make завершился с ошибкой. Хвост лога $MAKE_LOG:" >&2
        tail -80 "$MAKE_LOG" >&2
        exit 1
    fi
fi

# --- Бинарник и стриппинг ---
BIN=$R_SRC/revtool.exe
if [[ ! -f $BIN ]]; then
    BIN=$(find "$R_SRC" -maxdepth 1 -type f -iname '*.exe' -print -quit) || true
    [[ -n $BIN ]] || die "Исполняемый файл не найден в $R_SRC"
fi

SIZE_BEFORE=$(wc -c < "$BIN" | tr -d '[:space:]')
if [[ $DO_STRIP == 1 ]]; then
    if strip $STRIP_FLAGS "$BIN"; then # $STRIP_FLAGS намеренно разбивается на слова
        SIZE_AFTER=$(wc -c < "$BIN" | tr -d '[:space:]')
        msg "Размер: $SIZE_BEFORE -> $SIZE_AFTER B (сэкономлено $((SIZE_BEFORE - SIZE_AFTER)) B)"
    else
        echo "[!] strip завершился с ошибкой; бинарник оставлен как есть." >&2
    fi
fi

# --- Проверка результата ---
msg "Готово: $BIN"
file "$BIN" 2>/dev/null || true

DLLS=$(objdump -p "$BIN" 2>/dev/null | sed -nE 's/.*DLL Name:[[:space:]]*//p' || true)
if [[ -n $DLLS ]]; then
    echo "$DLLS" | sed 's/^/    /'
    # Whitelist: разрешены только системные DLL Windows. Любая другая — ошибка.
    UNEXPECTED=$(echo "$DLLS" | grep -viE '^(api-ms-win-[a-z0-9-]+|ucrtbase|msvcrt|ntdll|kernel32|kernelbase|user32|advapi32|shell32|shlwapi|gdi32|rpcrt4|ole32|oleaut32|ws2_32|bcrypt|crypt32|psapi|dbghelp|version|setupapi|cfgmgr32|powrprof|userenv|secur32|winmm|imm32|comctl32|comdlg32|mpr|netapi32)\.dll$' || true)
    if [[ -n $UNEXPECTED ]]; then
        echo "[!] Обнаружены несистемные DLL-зависимости:" >&2
        echo "$UNEXPECTED" | sed 's/^/    /' >&2
        die "Бинарник не полностью статический"
    fi
    msg "Все DLL — системные Windows; MinGW-зависимостей нет"
else
    msg "objdump не обнаружил DLL-импортов (полностью статический PE)"
fi

if [[ $SKIP_SMOKE == 1 ]]; then
    msg "Smoke-тест пропущен (REVTOOL_SKIP_SMOKE=1)"
elif V=$("$BIN" --version 2>&1); then
    echo "$V" | sed 's/^/    /'
else
    die "Smoke-тест провален: $BIN --version завершился с ошибкой"
fi

msg "Сборка завершена успешно."
