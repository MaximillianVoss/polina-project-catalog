#!/usr/bin/env bash
# Выбрать проект и папку, скачать чистую копию, собрать и запустить.
# Один самостоятельный файл. Bash 3.2+, Git, Python 3.9+; Node.js или Java для проекта.
set -eo pipefail
die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
python_cmd=()
for candidate in python python3; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3,9))' >/dev/null 2>&1; then
    python_cmd=("$candidate"); break
  fi
done
if [[ ${#python_cmd[@]} -eq 0 ]] && command -v py >/dev/null 2>&1 && py -3 -c 'import sys; sys.exit(sys.version_info < (3,9))' >/dev/null 2>&1; then python_cmd=(py -3); fi
[[ ${#python_cmd[@]} -gt 0 ]] || die 'Установите Python 3.9+ (python, python3 или py -3).'
command -v git >/dev/null 2>&1 || die 'Установите Git. На Windows запускайте этот файл через Git Bash.'

requested=""; destination=""; build_args=(); platform=""; build_only=0; list_only=0; offline=0; replace_existing=0
catalog_url='https://raw.githubusercontent.com/MaximillianVoss/polina-project-catalog/main/projects.json'
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|--dest|--expo-platform|--ready-timeout|--catalog-url)
      [[ $# -ge 2 && -n "$2" ]] || die "после $1 нужно значение."
      case "$1" in
        --project) requested="$2" ;;
        --dest) destination="$2" ;;
        --expo-platform) platform="$2"; case "$platform" in android|ios|web) ;; *) die 'Платформа: android, ios или web.' ;; esac ;;
        --ready-timeout) build_args+=("$1" "$2") ;;
        --catalog-url) catalog_url="$2" ;;
      esac
      shift 2 ;;
    --build-only) build_only=1; build_args+=("$1"); shift ;;
    --smoke-test|--no-open|--skip-tests|--strict-checks) build_args+=("$1"); shift ;;
    --list) list_only=1; shift ;;
    --offline) offline=1; shift ;;
    --replace) replace_existing=1; shift ;;
    --help|-h)
      printf '%s\n' 'Запуск: bash download-and-run.sh' 'Выберите номер проекта, затем введите конечную папку.' 'Список автоматически обновляется из каталога GitHub при каждом запуске.' 'Если каталог недоступен, используется последний сохранённый или встроенный список.' 'Скачивание → новая история Git без remote → сборка и тесты → запуск.' 'Занятую папку можно заменить после подтверждения.' 'Для автоматизации: --project ID --dest ПАПКА [--replace] [--smoke-test] [--no-open] [--build-only] [--expo-platform android|ios|web].' 'Каталог: --offline (без обновления списка), --catalog-url HTTPS_RAW_GITHUB_URL.'
      exit 0 ;;
    *) die "Неизвестный параметр: $1" ;;
  esac
done

tool_dir="$(mktemp -d "${TMPDIR:-/tmp}/download-run.XXXXXXXX")"
cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "$tool_dir" && -d "$tool_dir" && ! -L "$tool_dir" && "$(basename -- "$tool_dir")" == download-run.* ]]; then rm -rf -- "$tool_dir"; fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cat > "$tool_dir/catalog-default.json" <<'__CATALOG_DEFAULT_JSON__'
{
  "schema": "polina-project-catalog/v1",
  "projects": [
    {
      "id": "web-profile",
      "title": "React — Profile Card",
      "repo": "https://github.com/MaximillianVoss/polina-profile-card.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:08:47Z"
    },
    {
      "id": "web-counter",
      "title": "React — Counter",
      "repo": "https://github.com/MaximillianVoss/polina-counter.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:11:08Z"
    },
    {
      "id": "web-feedback",
      "title": "React — User Feedback",
      "repo": "https://github.com/MaximillianVoss/polina-user-feedback.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:17:07Z"
    },
    {
      "id": "web-quiz",
      "title": "React — Simple Quiz",
      "repo": "https://github.com/MaximillianVoss/polina-simple-quiz.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:17:12Z"
    },
    {
      "id": "web-budget",
      "title": "React — Budget Tracker",
      "repo": "https://github.com/MaximillianVoss/polina-budget-tracker.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:18:49Z"
    },
    {
      "id": "web-trivia",
      "title": "React — Trivia API",
      "repo": "https://github.com/MaximillianVoss/polina-trivia-api.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:18:54Z"
    },
    {
      "id": "web-github",
      "title": "React — GitHub Explorer",
      "repo": "https://github.com/MaximillianVoss/polina-github-explorer.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:18:57Z"
    },
    {
      "id": "web-trainer",
      "title": "React — Personal Trainer, итоговый проект",
      "repo": "https://github.com/MaximillianVoss/polina-personal-trainer.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T16:20:48Z"
    },
    {
      "id": "mob-calculator",
      "title": "React Native — Calculator, история и страницы",
      "repo": "https://github.com/MaximillianVoss/polina-calculator.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:20:47Z"
    },
    {
      "id": "mob-shopping",
      "title": "React Native — Shopping List, SQLite и Paper",
      "repo": "https://github.com/MaximillianVoss/polina-shopping-list.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:20:48Z"
    },
    {
      "id": "mob-firebase",
      "title": "React Native — Shopping List Firebase",
      "repo": "https://github.com/MaximillianVoss/polina-shopping-list-firebase.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:03Z"
    },
    {
      "id": "mob-guess",
      "title": "React Native — Number Guessing Game",
      "repo": "https://github.com/MaximillianVoss/polina-number-guessing-game.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:05Z"
    },
    {
      "id": "mob-recipe",
      "title": "React Native — Recipe Finder",
      "repo": "https://github.com/MaximillianVoss/polina-recipe-finder.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:04Z"
    },
    {
      "id": "mob-euro",
      "title": "React Native — Euro Converter",
      "repo": "https://github.com/MaximillianVoss/polina-euro-converter.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:20Z"
    },
    {
      "id": "mob-address",
      "title": "React Native — Find Address",
      "repo": "https://github.com/MaximillianVoss/polina-find-address.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:21Z"
    },
    {
      "id": "mob-weather",
      "title": "React Native — Weather Forecast",
      "repo": "https://github.com/MaximillianVoss/polina-weather-forecast.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:21Z"
    },
    {
      "id": "mob-contacts",
      "title": "React Native — Contacts",
      "repo": "https://github.com/MaximillianVoss/polina-contacts.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:37Z"
    },
    {
      "id": "mob-speech",
      "title": "React Native — Text to Speech",
      "repo": "https://github.com/MaximillianVoss/polina-text-to-speech.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:38Z"
    },
    {
      "id": "mob-places",
      "title": "React Native — My Places",
      "repo": "https://github.com/MaximillianVoss/polina-my-places.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:38Z"
    },
    {
      "id": "mob-soundshades",
      "title": "React Native — SoundShades, итоговый проект",
      "repo": "https://github.com/MaximillianVoss/polina-soundshades.git",
      "ref": "main",
      "path": ".",
      "type": "expo",
      "createdAt": "2026-10-14T16:21:55Z"
    },
    {
      "id": "spring-endpoints",
      "title": "Spring Boot — Controller Endpoints",
      "repo": "https://github.com/MaximillianVoss/polina-controller-endpoints.git",
      "ref": "main",
      "path": ".",
      "type": "spring",
      "createdAt": "2026-10-14T16:21:54Z"
    },
    {
      "id": "spring-params",
      "title": "Spring Boot — Request Parameters",
      "repo": "https://github.com/MaximillianVoss/polina-request-parameters.git",
      "ref": "main",
      "path": ".",
      "type": "spring",
      "createdAt": "2026-10-14T16:21:55Z"
    },
    {
      "id": "spring-bookstore",
      "title": "Spring Boot — Bookstore, главы 3–6 и Testing",
      "repo": "https://github.com/MaximillianVoss/polina-bookstore.git",
      "ref": "main",
      "path": ".",
      "type": "spring",
      "createdAt": "2026-10-14T16:22:11Z"
    },
    {
      "id": "spring-whichone",
      "title": "Spring Boot — WhichOne, итоговый проект",
      "repo": "https://github.com/MaximillianVoss/polina-whichone.git",
      "ref": "main",
      "path": ".",
      "type": "spring",
      "createdAt": "2026-10-14T16:22:11Z"
    },
    {
      "id": "web-car-shop",
      "title": "React — Car Shop, управление автомобилями",
      "repo": "https://github.com/MaximillianVoss/polina-car-shop.git",
      "ref": "main",
      "path": ".",
      "type": "vite",
      "createdAt": "2026-10-14T18:28:14Z"
    }
  ]
}
__CATALOG_DEFAULT_JSON__

cat > "$tool_dir/project_catalog.py" <<'__CATALOG_LOADER_PY__'
"""Load a GitHub JSON catalog as data; never evaluate its contents. Python 3.9+."""
import argparse
from datetime import date, datetime
import hashlib
from http.client import HTTPException
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

DEFAULT_URL = "https://raw.githubusercontent.com/MaximillianVoss/polina-project-catalog/main/projects.json"
SCHEMA = "polina-project-catalog/v1"
MAX_BYTES = 256 * 1024
MAX_PROJECTS = 200


def catalog_url(raw):
    if not isinstance(raw, str) or any(ord(char) < 32 or 127 <= ord(char) <= 159 for char in raw):
        raise ValueError("Управляющие символы в URL каталога запрещены.")
    value = urlsplit(raw)
    if (value.scheme != "https" or value.netloc != "raw.githubusercontent.com"
            or value.query or value.fragment or not re.fullmatch(
                r"/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+", value.path)
            or any(part in ("", ".", "..") for part in value.path.split("/")[1:])):
        raise ValueError("Адрес каталога должен быть HTTPS-ссылкой raw.githubusercontent.com на JSON в GitHub.")
    return raw


def validate(data):
    if not isinstance(data, dict) or data.get("schema") != SCHEMA:
        raise ValueError("Неизвестный формат каталога.")
    projects = data.get("projects")
    if not isinstance(projects, list) or not 1 <= len(projects) <= MAX_PROJECTS:
        raise ValueError("Каталог должен содержать от 1 до 200 проектов.")
    ids, sources, result = set(), set(), []
    for row in projects:
        if not isinstance(row, dict):
            raise ValueError("Некорректная карточка проекта.")
        item = {key: row.get(key) for key in ("id", "title", "repo", "ref", "path")}
        if not all(isinstance(value, str) for value in item.values()):
            raise ValueError("Все поля карточки должны быть строками.")
        if any(any(ord(char) < 32 or 127 <= ord(char) <= 159 for char in value) for value in item.values()):
            raise ValueError("Управляющие символы в каталоге запрещены.")
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", item["id"]):
            raise ValueError("Некорректный ID проекта.")
        if not 1 <= len(item["title"].strip()) <= 160:
            raise ValueError("Некорректное название проекта.")
        match = re.fullmatch(r"https://github\.com/([A-Za-z0-9][A-Za-z0-9-]*)/([A-Za-z0-9][A-Za-z0-9_.-]*?)(?:\.git)?", item["repo"])
        if not match or ".." in match[2] or match[2].endswith("."):
            raise ValueError("Нужен публичный HTTPS-адрес репозитория GitHub без пароля или параметров.")
        ref = item["ref"]
        if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]{0,199}", ref)
                or ".." in ref or "//" in ref or ref.endswith(("/", ".", ".lock"))):
            raise ValueError("Некорректная ветка, метка или commit проекта.")
        path = item["path"]
        if path != "." and (not path or path.startswith(("/", "-")) or "\\" in path or ":" in path
                            or len(path) > 300 or any(part in ("", ".", "..") for part in path.split("/"))):
            raise ValueError("Небезопасная папка исходников в каталоге.")
        key = (item["repo"].removesuffix(".git").lower(), ref, path)
        if item["id"] in ids or key in sources:
            raise ValueError("В каталоге повторяется ID или источник проекта.")
        project_type = row.get("type")
        if project_type not in ("vite", "expo", "spring"):
            raise ValueError("Для каждого проекта нужно указать тип: vite, expo или spring.")
        item["type"] = project_type
        created = row.get("createdAt")
        if not isinstance(created, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2}))?", created):
            raise ValueError("Для каждого проекта нужна корректная дата создания репозитория.")
        try:
            if len(created) == 10:
                date.fromisoformat(created)
            else:
                datetime.fromisoformat(created.replace("Z", "+00:00"))
        except ValueError:
            raise ValueError("Некорректная дата создания репозитория.") from None
        item["createdAt"] = created
        ids.add(item["id"])
        sources.add(key)
        result.append(item)
    return {"schema": SCHEMA, "projects": result}


def decode(raw):
    if len(raw) > MAX_BYTES:
        raise ValueError("Каталог слишком большой.")
    return validate(json.loads(raw.decode("utf-8-sig")))


def cache_path(url):
    if os.name == "nt":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData/Local")
    else:
        base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return base / "polina-project-catalog" / (hashlib.sha256(url.encode()).hexdigest()[:20] + ".json")


def save_cache(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix="catalog-", suffix=".tmp", dir=path.parent, delete=False) as output:
            name = Path(output.name)
            json.dump(data, output, ensure_ascii=False)
        os.replace(name, path)
    finally:
        if name is not None and name.exists():
            name.unlink()


def fetch(url):
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "polina-project-downloader/1"})
    with urlopen(request, timeout=6) as response:
        catalog_url(response.geturl())
        return decode(response.read(MAX_BYTES + 1))


def load(url, embedded, *, offline=False, cache=None, log=None):
    catalog_url(url)
    cache = cache if cache is not None else cache_path(url)
    log = log if log is not None else sys.stderr
    if not offline:
        try:
            data = fetch(url)
        except (OSError, ValueError, UnicodeError, HTTPException) as error:
            # The URL is a validated public URL; do not print provider payloads.
            print("Не удалось обновить каталог GitHub (" + type(error).__name__ + "). Использую резервный список.", file=log)
        else:
            try:
                save_cache(cache, data)
            except OSError:
                print("Не удалось сохранить список в кэш; текущий каталог загружен.", file=log)
            print(f"Каталог GitHub: {len(data['projects'])} проектов.", file=log)
            return data, "github"
    else:
        print("Обновление каталога отключено (--offline).", file=log)
    try:
        data = decode(cache.read_bytes())
        source = "cache"
        print(f"Сохранённый каталог: {len(data['projects'])} проектов.", file=log)
    except (OSError, ValueError, UnicodeError):
        data = decode(Path(embedded).read_bytes())
        source = "embedded"
        print(f"Встроенный резервный каталог: {len(data['projects'])} проектов.", file=log)
    return data, source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--embedded", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--menu-json", help="Validated catalog with optional display metadata")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    sys.stderr.reconfigure(encoding="utf-8", newline="\n")
    try:
        data, _ = load(args.url, args.embedded, offline=args.offline)
        lines = ["\t".join(row[key] for key in ("id", "title", "repo", "ref", "path")) for row in data["projects"]]
        with Path(args.output).open("w", encoding="utf-8", newline="\n") as output:
            output.write("\n".join(lines) + "\n")
        if args.menu_json:
            with Path(args.menu_json).open("w", encoding="utf-8", newline="\n") as output:
                json.dump(data, output, ensure_ascii=False)
    except (OSError, ValueError, UnicodeError) as error:
        print("Ошибка каталога: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
__CATALOG_LOADER_PY__

cat > "$tool_dir/terminal_table.py" <<'__CATALOG_TABLE_PY__'
"""Shared, read-only terminal menu renderer. Python 3.9+, standard library only."""
import argparse
from datetime import date, datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET

TYPES = {"vite": "Vite", "expo": "Expo", "spring": "Spring Boot"}


def clean(value):
    return "".join(" " if unicodedata.category(c).startswith("C") and c != "\u200d" else c
                   for c in str(value)).strip()


def cell_width(value):
    width = 0
    joined = False
    regional = False
    for char in value:
        if char == "\u200d":
            joined = True
            continue
        if unicodedata.combining(char) or char in ("\ufe0e", "\ufe0f") or 0x1F3FB <= ord(char) <= 0x1F3FF:
            continue
        is_regional = 0x1F1E6 <= ord(char) <= 0x1F1FF
        size = 2 if unicodedata.east_asian_width(char) in ("W", "F") or 0x1F000 <= ord(char) <= 0x1FAFF else 1
        if not joined and not (is_regional and regional):
            width += size
        joined = False
        regional = is_regional and not regional
    return width


def fit(value, width):
    value = clean(value)
    if cell_width(value) > width:
        prefix = ""
        for char in value:
            if cell_width(prefix + char) > width - 1:
                break
            prefix += char
        value = prefix.rstrip("\u200d") + "…"
    return value + " " * max(0, width - cell_width(value))


def terminal_width():
    raw = os.environ.get("COLUMNS", "")
    return max(32, min(240, int(raw))) if raw.isdigit() else max(32, min(240, shutil.get_terminal_size((120, 24)).columns))


def table(rows, width=None):
    width = width or terminal_width()
    headers = ["№", "Имя", "Папка", "Тип", "Создана"]
    # Five visible fields even in a small terminal; prefer space for names and folders.
    widths = [max(2, len(str(len(rows)))), 4, 5, 3, 10]
    available = max(0, width - 16 - sum(widths))
    for column, target in ((3, 11), (1, 22), (2, 36), (1, 42), (2, 120)):
        extra = min(available, max(0, target - widths[column]))
        widths[column] += extra
        available -= extra
    if width < sum(widths) + 16:
        widths[4] = max(4, width - 16 - sum(widths[:4]))
        for column in (2, 1):
            excess = max(0, sum(widths) + 16 - width)
            widths[column] -= min(excess, widths[column] - 3)
    def border(left, middle, right):
        return left + middle.join("─" * (n + 2) for n in widths) + right
    def row_line(values):
        return "│ " + " │ ".join(fit(value, n) for value, n in zip(values, widths)) + " │"
    lines = [border("┌", "┬", "┐"), row_line(headers), border("├", "┼", "┤")]
    lines.extend(row_line(row) for row in rows)
    lines.append(border("└", "┴", "┘"))
    return "\n".join(lines)


def local_path(raw):
    if os.name == "nt":
        match = re.fullmatch(r"/(?:cygdrive/)?([A-Za-z])(?:/(.*))?", raw)
        if match:
            return Path(match[1] + ":/" + (match[2] or ""))
    return Path(raw)


def creation_date(path):
    try:
        info = path.stat()
        birth = getattr(info, "st_birthtime", None)
        if birth is None and os.name == "nt":
            birth = info.st_ctime
        if birth is not None:
            return datetime.fromtimestamp(birth).strftime("%Y-%m-%d")
    except (OSError, ValueError, OverflowError):
        return "—"
    # Linux ctime is metadata-change time, not creation time. Ask stat for birth time.
    for command in (["stat", "-c", "%w", "--", str(path)],
                    ["stat", "-f", "%SB", "-t", "%Y-%m-%d", str(path)]):
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=2, check=False)
            value = result.stdout.strip()[:10]
            if result.returncode == 0 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
                return date.fromisoformat(value).isoformat()
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    return "—"


def friendly_name(path, marker, label):
    try:
        if marker == "package.json":
            app = path / "app.json"
            if app.is_file():
                data = json.loads(app.read_text(encoding="utf-8-sig"))
                name = data.get("expo", {}).get("name")
                if isinstance(name, str) and name.strip():
                    return clean(name)
            data = json.loads((path / marker).read_text(encoding="utf-8-sig"))
            name = data.get("displayName") or data.get("name")
        else:
            root = ET.parse(path / marker).getroot()
            name = None
            for key in ("name", "artifactId"):
                element = next((item for item in root if item.tag.rsplit("}", 1)[-1] == key), None)
                if element is not None and element.text and element.text.strip():
                    name = element.text.strip()
                    break
        if isinstance(name, str) and name.strip():
            # Remove course scaffolding identifiers, retain the application name.
            name = re.sub(r"^(?:front-end-sof\w+?-\d+-|fullstack-homework-|react-native-homework-|homework-\d+-|assignment\d+-)", "", name)
            name = re.sub(r"-pe\d+$", "", name)
            name = clean(re.sub(r"[-_]+", " ", name))
            return name[:1].upper() + name[1:]
    except (OSError, ValueError, TypeError, AttributeError, ET.ParseError):
        pass
    return clean(Path(label).name or label)


def local_rows(payload):
    values = payload.decode("utf-8", errors="replace").split("\0")
    if values and values[-1] == "":
        values.pop()
    if len(values) % 5:
        raise ValueError("Неполная строка списка проектов.")
    rows = []
    for offset in range(0, len(values), 5):
        number, kind, label, directory, marker = values[offset:offset + 5]
        path = local_path(directory)
        rows.append([number, friendly_name(path, marker, label), label, TYPES.get(kind, kind), creation_date(path)])
    return rows


def catalog_rows(data):
    rows = []
    for number, item in enumerate(data["projects"], 1):
        folder = item["repo"].removesuffix(".git").rsplit("/", 1)[-1]
        kind = item.get("type", "")
        created = item.get("createdAt", "")[:10]
        try:
            created = date.fromisoformat(created).isoformat()
        except (TypeError, ValueError):
            created = "—"
        rows.append([str(number), item["title"], folder, TYPES.get(kind, kind) or "—", created])
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("local", "catalog"))
    parser.add_argument("file", nargs="?")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    if args.mode == "local":
        rows = local_rows(sys.stdin.buffer.read())
    else:
        rows = catalog_rows(json.loads(Path(args.file).read_text(encoding="utf-8-sig")))
    print(table(rows))
    print(f"Всего проектов: {len(rows)}")
    if args.mode == "local":
        print("Создана: локальная папка; — = дата неизвестна.")
        print("… = сокращено; полный путь будет показан после выбора.")
    else:
        print("Создана: репозиторий GitHub; — = дата неизвестна.")
        print("Папка: предлагаемое имя; место сохранения выбирается далее.")


if __name__ == "__main__":
    main()
__CATALOG_TABLE_PY__

catalog_args=(--url "$catalog_url" --embedded "$tool_dir/catalog-default.json" --output "$tool_dir/catalog.tsv" --menu-json "$tool_dir/catalog.json")
if [[ $offline -eq 1 ]]; then catalog_args+=(--offline); fi
"${python_cmd[@]}" "$tool_dir/project_catalog.py" "${catalog_args[@]}"
project_ids=(); project_names=(); project_repos=(); project_refs=(); project_paths=()
while IFS=$'\t' read -r project_id project_name project_repo project_ref project_path; do
  project_ids+=("$project_id"); project_names+=("$project_name"); project_repos+=("$project_repo"); project_refs+=("$project_ref"); project_paths+=("$project_path")
done < "$tool_dir/catalog.tsv"

echo
echo 'Скачать и запустить проект'
echo '========================='
COLUMNS="${COLUMNS:-}" "${python_cmd[@]}" "$tool_dir/terminal_table.py" catalog "$tool_dir/catalog.json"
echo ' 0) Выход'
[[ $list_only -eq 0 ]] || exit 0
selected=-1
while [[ $selected -lt 0 ]]; do
  if [[ -z "$requested" ]]; then printf '\nНомер проекта: '; read -r requested || die 'Ввод завершён.'; requested="${requested%$'\r'}"; fi
  if [[ "$requested" == 0 ]]; then echo 'Отменено.'; exit 0; fi
  if [[ "$requested" =~ ^[0-9]{1,3}$ ]]; then
    number=$((10#$requested))
    if [[ $number -ge 1 && $number -le ${#project_ids[@]} ]]; then selected=$((number-1)); fi
  else
    for ((i=0; i<${#project_ids[@]}; i++)); do if [[ "$requested" == "${project_ids[$i]}" ]]; then selected=$i; break; fi; done
  fi
  if [[ $selected -lt 0 ]]; then echo 'Нет такого проекта. Введите номер из списка или 0.'; requested=""; fi
done
if [[ -z "$destination" ]]; then
  echo
  echo 'Укажите конечную папку для проекта (новую или пустую).'
  echo 'Пример Windows: C:/Projects/My App; macOS/Linux: ~/Projects/My App'
  printf 'Папка: '; read -r destination || die 'Ввод завершён.'
fi
[[ -n "$destination" ]] || die 'Папка не указана.'

cat > "$tool_dir/export_project.py" <<'__EMBED_EXPORT_PROJECT_PY__'
"""Safe standard-library companion for export-project.sh. Python 3.9+."""
import csv
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tarfile
import uuid

GIT_NAMES = {'.git', '.github', '.gitmodules', '.gitconfig', '.git-credentials', '.git-credential-cache'}
GENERATED = {'node_modules', 'target', 'dist', 'build', 'coverage', '.expo', '.gradle', '.venv', 'venv', '__pycache__', '.DS_Store', '.idea', '.vscode', '.next', '.nuxt', '.cache', '.pytest_cache', '.mypy_cache'}
SECRET_NAMES = {'.npmrc', '.pypirc', '.netrc', '_netrc', '.ssh', '.aws', '.azure', '.kube', 'credentials.json', 'secrets.json', 'secrets.yaml', 'secrets.yml', 'id_rsa', 'id_ed25519'}
LOCAL_CONFIG = re.compile(r'^(application|appsettings)[-.](local|private|secrets)(?:\.|-).+', re.I)
DATABASE = re.compile(r'.*\.(?:db|sqlite|sqlite3|mv\.db|h2\.db|trace\.db)(?:-wal|-shm|-journal)?$', re.I)

def fail(message):
    raise ValueError(message)

def source_path(raw):
    if raw == '.':
        return raw
    if not raw or raw.startswith(('/', '-')) or '\\' in raw or ':' in raw or any(c in raw for c in '\n\r\t\x00'):
        fail('Нужен безопасный относительный --path.')
    if any(part in ('', '.', '..') for part in raw.split('/')):
        fail('--path не допускает пустые сегменты, . или ...')
    return raw

def destination(raw, replace_existing=False):
    if not raw or any(c in raw for c in '\n\r\t\x00') or '..' in Path(raw).parts:
        fail('Небезопасный путь назначения.')
    value = Path(os.path.abspath(raw))
    if value.name.lower() in ('', '.', '..', '.git') or value.name.endswith((' ', '.')):
        fail('Нужна отдельная папка назначения.')
    if not value.parent.is_dir():
        fail('Сначала создайте родительскую папку назначения.')
    value = value.parent.resolve() / value.name
    if value == Path.home().resolve() or value == Path.cwd().resolve() or value == Path('/'):
        fail('Домашняя, текущая и корневая папки не подходят для назначения.')
    if value.is_symlink():
        fail('Папка назначения не должна быть символической ссылкой.')
    if value.exists() and (not value.is_dir() or (any(value.iterdir()) and not replace_existing)):
        fail('Папка назначения уже существует и не пуста; ничего не изменено.')
    for ancestor in (value.parent, *value.parent.parents):
        metadata = ancestor / '.git'
        if os.path.lexists(metadata):
            fail('Назначение находится внутри другого Git-репозитория. Выберите независимую папку.')
    return value

def excluded(parts):
    for part in parts:
        lowered = part.lower()
        example = lowered.endswith(('.example', '.sample', '.template'))
        if lowered in GIT_NAMES or part in GENERATED or lowered in SECRET_NAMES or (not example and (DATABASE.fullmatch(part) or LOCAL_CONFIG.fullmatch(part) or lowered.endswith(('.key', '.pem', '.p12', '.pfx', '.jks', '.keystore')) or lowered.startswith('service-account'))):
            return True
        if part == '.env' or (part.startswith('.env.') and not example):
            return True
    return False

def check_credentials(path):
    """Refuse explicit credentials in unexpected JSON; never print their value.

    Application source, schemas and example templates are retained. This is a
    conservative delivery guard, not a general-purpose secret scanner.
    """
    if path.suffix.lower() != '.json' or path.name.lower().endswith(('.example', '.sample', '.template')):
        return
    try:
        value = json.loads(path.read_text(encoding='utf-8-sig'))
    except (UnicodeError, json.JSONDecodeError):
        return
    keys = {'private_key', 'privatekey', 'client_secret', 'access_token', 'refresh_token'}
    placeholders = {'', 'replace-me', 'replace_me', 'changeme', 'your-token', 'your_token', 'placeholder', 'example', 'null'}
    def visit(item):
        if isinstance(item, dict):
            for key, val in item.items():
                if str(key).lower() in keys and isinstance(val, str):
                    if val.lower().strip() not in placeholders and not val.startswith(('${', 'YOUR_', '<')):
                        fail('Обнаружено явное значение credential в JSON; экспорт отменён. Удалите его из исходного репозитория.')
                visit(val)
        elif isinstance(item, list):
            for val in item:
                visit(val)
    visit(value)

def extract(archive_path, target):
    target = Path(target)
    target.mkdir()
    with tarfile.open(archive_path, 'r:') as archive:
        members = archive.getmembers()
        # This marker identifies the optional upstream downloader bundled by
        # this delivery. Application folders with the same name are preserved.
        strip_tooling = any(item.name == 'delivery-tools/.upstream-tools' and item.isfile()
                            and item.size in (len(b'clean-export-tooling/v1\n'), len(b'clean-export-tooling/v1\r\n'))
                            and archive.extractfile(item).read() in (b'clean-export-tooling/v1\n', b'clean-export-tooling/v1\r\n')
                            for item in members)
        retained = []
        for item in members:
            name = PurePosixPath(item.name)
            if name.is_absolute() or '..' in name.parts or '\\' in item.name or ':' in item.name or any(c in item.name for c in '\r\n\t\x00'):
                fail('Архив содержит небезопасный путь.')
            if any(part.endswith((' ', '.')) or re.fullmatch(r'(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?', part, re.I) for part in name.parts):
                fail('Архив содержит непереносимое имя Windows.')
            if excluded(name.parts):
                continue
            if name.parts == ('.delivery-source.json',) or (strip_tooling and name.parts[0] == 'delivery-tools'):
                continue
            if not (item.isfile() or item.isdir() or item.issym()):
                fail('Архив содержит special file/hardlink; экспорт отменён.')
            if item.issym():
                # A portable delivery contains regular files only. No symlink
                # can recreate references to metadata, secrets or outside files.
                continue
            retained.append(item)
        # Do not extract below another archive entry that is a symlink.
        symlinks = {PurePosixPath(item.name) for item in members if item.issym()}
        for item in retained:
            if any(parent in symlinks for parent in PurePosixPath(item.name).parents):
                fail('Путь в архиве проходит через символическую ссылку.')
        for item in retained:
            out = target / item.name
            if item.isdir():
                out.mkdir(parents=True, exist_ok=True)
            else:
                out.parent.mkdir(parents=True, exist_ok=True)
                if item.issym():
                    out.symlink_to(item.linkname)
                else:
                    with archive.extractfile(item) as source, out.open('xb') as dest:
                        import shutil
                        shutil.copyfileobj(source, dest)
                    os.chmod(out, item.mode & 0o777)
                    check_credentials(out)
                    if out.name == 'README.md':
                        try:
                            text = out.read_text(encoding='utf-8')
                            cleaned = re.sub(r'\n?<!-- upstream-tools:start -->.*?<!-- upstream-tools:end -->\n?', '\n', text, flags=re.S)
                            if text != cleaned:
                                out.write_text(cleaned, encoding='utf-8')
                        except UnicodeError:
                            pass
                    if out.name == 'package.json':
                        try:
                            package = json.loads(out.read_text(encoding='utf-8'))
                            if isinstance(package, dict) and any(k in package for k in ('repository', 'homepage', 'bugs', 'funding')):
                                for key in ('repository', 'homepage', 'bugs', 'funding'):
                                    package.pop(key, None)
                                out.write_text(json.dumps(package, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                        except (UnicodeError, json.JSONDecodeError):
                            pass
        if not any(target.iterdir()):
            fail('После исключения metadata проект пуст.')

def publish(payload, raw_destination, init_git, replace_existing=False):
    payload = Path(payload)
    final = destination(raw_destination, replace_existing)  # Recheck immediately before atomic rename.
    for entry in payload.rglob('*'):
        relative = entry.relative_to(payload)
        if entry.name in GIT_NAMES:
            if init_git and relative.parts == ('.git',):
                continue
            if init_git and relative.parts[0] == '.git':
                continue
            fail('В новой копии остались Git metadata.')
    # Move confirmed non-empty contents aside only after the replacement has
    # downloaded, been extracted, and passed credential/Git checks.
    backup = None
    if replace_existing and final.exists() and any(final.iterdir()):
        backup = final.parent / ('.' + final.name + '.replaced-' + uuid.uuid4().hex)
        os.rename(final, backup)
    # POSIX rename replaces an empty directory atomically. Windows requires
    # rmdir first; on failure restore the previous destination.
    removed_empty = False
    if os.name == 'nt' and final.exists():
        final.rmdir()
        removed_empty = True
    try:
        os.rename(payload, final)
    except OSError:
        if backup is not None and not final.exists():
            os.rename(backup, final)
            backup = None
        if removed_empty and not final.exists():
            final.mkdir()
        raise
    if backup is not None:
        import shutil
        try:
            shutil.rmtree(backup)
        except OSError:
            print('Предыдущая папка оставлена рядом для ручного удаления: ' + str(backup), file=sys.stderr)

def catalog(filename, wanted=None):
    records = []
    seen = set()
    with open(filename, encoding='utf-8-sig', newline='') as f:
        for row in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
            if not row or row[0].startswith('#'):
                continue
            if row == ['id', 'repo', 'ref', 'path']:
                continue
            if len(row) != 4 or any(not part or any(c in part for c in '\n\r\x00') for part in row):
                fail('Каталог должен содержать 4 непустые колонки TAB.')
            if row[0] in seen:
                fail('Повторный id в каталоге.')
            seen.add(row[0])
            source_path(row[3])
            records.append(row)
    if wanted is None:
        print('\n'.join(row[0] for row in records))
    else:
        matches = [row for row in records if row[0] == wanted]
        if len(matches) != 1:
            fail('Не найден ровно один проект с таким id.')
        print('\t'.join(matches[0][1:]))

def main():
    mode, *args = sys.argv[1:]
    if mode == 'source-path':
        print(source_path(args[0]))
    elif mode == 'destination':
        # Bash/dirname must receive forward slashes even with native Windows
        # Python under Git Bash, so the temporary dir stays on the same volume.
        print(destination(args[0], len(args) > 1 and args[1] == '1').as_posix())
    elif mode == 'nonempty':
        value = destination(args[0], True)
        print('1' if value.exists() and any(value.iterdir()) else '0')
    elif mode == 'extract':
        extract(*args)
    elif mode == 'publish':
        publish(args[0], args[1], args[2] == '1', len(args) > 3 and args[3] == '1')
    elif mode == 'catalog':
        catalog(*args)
    else:
        fail('Неизвестная операция.')

if __name__ == '__main__':
    # Native Windows Python under Git Bash must emit UTF-8 with LF. CRLF
    # would leave a trailing CR in Bash command substitutions and TSV fields.
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    sys.stderr.reconfigure(encoding='utf-8', newline='\n')
    try:
        main()
    except (ValueError, OSError, tarfile.TarError) as error:
        print(f'Ошибка: {error}', file=sys.stderr)
        sys.exit(1)
__EMBED_EXPORT_PROJECT_PY__

cat > "$tool_dir/export-project.sh" <<'__EMBED_EXPORT_PROJECT_SH__'
#!/usr/bin/env bash
# Экспорт одного проекта без исходной истории и remote. Bash 3.2+.
set -eo pipefail
usage() {
  cat <<'USAGE'
Использование:
  bash export-project.sh --repo URL --ref main --path . --dest "/папка/Мой проект"
  bash export-project.sh --catalog projects.tsv --project web-counter --dest "/папка/Counter"
  bash export-project.sh --catalog projects.tsv --list

  --repo URL       GitHub SSH/HTTPS URL или локальный репозиторий для офлайн-проверки.
  --ref REF        Ветка, тег или commit (по умолчанию HEAD).
  --path ПУТЬ      Каталог внутри репозитория (по умолчанию .).
  --dest ПАПКА     Папка проекта; родитель должен существовать.
  --replace        Явно заменить существующее содержимое папки назначения.
  --catalog TSV    Каталог: id, repo, ref, path (4 колонки TAB; # — комментарий).
  --project ID     Выбрать ровно одну строку из каталога.
  --list           Показать id из каталога, ничего не экспортировать.
  --init-git       Создать новую локальную .git без commit и без remote.

Нужны Git и Python 3.9+. Для закрытого repo понадобится доступ через свой аккаунт.
Открытые GitHub repo скачиваются по HTTPS без входа. Исходный репозиторий не меняется.
Непустую папку можно заменить с флагом --replace; ссылка и папка внутри существующего Git-репозитория отклоняются.
Исключаются только из новой копии: Git metadata, ссылки, зависимости, сборки,
.env, известные файлы ключей/credentials, рабочие БД, локальные конфиги и caches.
.env.example, схемы и лицензии сохраняются. .github и отмеченный набор downloader
удаляются; package.json теряет repository/homepage/bugs/funding. README теряет
только отмеченный блок upstream-tools. Исходная Git-история не копируется.
USAGE
}
die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo=""; ref="HEAD"; project_path="."; destination=""; catalog=""; project_id=""
list_only=0; init_git=0; replace_existing=0; explicit_source=0; work=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|--ref|--path|--dest|--catalog|--project)
      [[ $# -ge 2 && -n "$2" ]] || die "после $1 требуется значение."
      case "$1" in
        --repo) repo="$2"; explicit_source=1 ;;
        --ref) ref="$2"; explicit_source=1 ;;
        --path) project_path="$2"; explicit_source=1 ;;
        --dest) destination="$2" ;;
        --catalog) catalog="$2" ;;
        --project) project_id="$2" ;;
      esac
      shift 2 ;;
    --list) list_only=1; shift ;;
    --init-git) init_git=1; shift ;;
    --replace) replace_existing=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "неизвестный параметр: $1" ;;
  esac
done
command -v git >/dev/null 2>&1 || die "Git не найден."
python_cmd=()
for python_candidate in python python3; do
  if command -v "$python_candidate" >/dev/null 2>&1 && "$python_candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
    python_cmd=("$python_candidate")
    break
  fi
done
if [[ ${#python_cmd[@]} -eq 0 ]] && command -v py >/dev/null 2>&1 && py -3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
  python_cmd=(py -3)
fi
[[ ${#python_cmd[@]} -gt 0 ]] || die "Нужен Python 3.9+: команда python, python3 или py -3."
[[ -f "$script_dir/export_project.py" ]] || die "рядом должен находиться export_project.py."
if [[ -n "$catalog" ]]; then
  [[ $explicit_source -eq 0 ]] || die "не смешивайте --catalog с --repo/--ref/--path."
  [[ -f "$catalog" ]] || die "каталог не найден."
  if [[ $list_only -eq 1 ]]; then
    "${python_cmd[@]}" "$script_dir/export_project.py" catalog "$catalog"
    exit 0
  fi
  [[ -n "$project_id" ]] || die "укажите --project ID."
  resolved="$("${python_cmd[@]}" "$script_dir/export_project.py" catalog "$catalog" "$project_id")"
  IFS=$'\t' read -r repo ref project_path <<< "$resolved"
elif [[ -n "$project_id" || $list_only -eq 1 ]]; then
  die "--project и --list требуют --catalog."
fi
[[ -n "$repo" && -n "$destination" ]] || die "нужны --repo и --dest (см. --help)."
[[ "$repo" != -* && "$ref" != -* ]] || die "URL/ref не могут начинаться с -."
[[ "$ref" != *$'\n'* && "$ref" != *$'\r'* && "$repo" != *$'\n'* ]] || die "URL/ref содержат перевод строки."
[[ "$repo" != http*://*@* ]] || die "не помещайте пароль/token в URL; используйте SSH или credential helper."
project_path="$("${python_cmd[@]}" "$script_dir/export_project.py" source-path "$project_path")"
destination="$("${python_cmd[@]}" "$script_dir/export_project.py" destination "$destination" "$replace_existing")"
parent="$(dirname -- "$destination")"
work="$(mktemp -d "$parent/.project-export.XXXXXX")"
cleanup() {
  local result=$?
  trap - EXIT
  # Только созданная нами временная папка; никогда не папка назначения.
  if [[ -n "$work" && -d "$work" && ! -L "$work" && "$work" == "$parent/.project-export."* ]]; then
    rm -rf -- "$work"
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -c init.templateDir= init --bare --quiet "$work/source.git"
git --git-dir="$work/source.git" -c advice.detachedHead=false -c protocol.ext.allow=never -c protocol.helper.allow=never fetch --quiet --depth=1 -- "$repo" "$ref"
commit="$(git --git-dir="$work/source.git" rev-parse --verify 'FETCH_HEAD^{commit}')"
tree="$commit^{tree}"
if [[ "$project_path" != "." ]]; then tree="$commit:$project_path"; fi
[[ "$(git --git-dir="$work/source.git" cat-file -t "$tree")" == tree ]] || die "--path должен обозначать каталог репозитория."
git --git-dir="$work/source.git" ls-tree -r "$tree" > "$work/tree.txt"
if grep -q '^160000 ' "$work/tree.txt"; then
  die "в проекте есть submodule: подготовьте самостоятельный пакет с его исходниками."
fi
git --git-dir="$work/source.git" archive --format=tar "$tree" > "$work/source.tar"
"${python_cmd[@]}" "$script_dir/export_project.py" extract "$work/source.tar" "$work/payload"
if [[ $init_git -eq 1 ]]; then
  git -c init.templateDir= init --quiet --template= "$work/payload"
  [[ -z "$(git -C "$work/payload" remote)" ]] || die "новый Git неожиданно содержит remote."
fi
"${python_cmd[@]}" "$script_dir/export_project.py" publish "$work/payload" "$destination" "$init_git" "$replace_existing"
printf 'Готово: %s\n' "$destination"
if [[ $init_git -eq 1 ]]; then
  echo 'Создан новый локальный Git без remote и без исходной истории.'
else
  echo 'Git metadata отсутствует. Для своего репозитория выполните git init в новой папке.'
fi
__EMBED_EXPORT_PROJECT_SH__

cat > "$tool_dir/build-and-run.sh" <<'__EMBED_BUILD_AND_RUN_SH__'
#!/usr/bin/env bash


# Находит вложенные Vite, Expo и Spring Boot проекты, проверяет и собирает
# их, а затем запускает выбранные приложения на свободных портах.
# Совместим со стандартным Bash 3.2 в macOS.

set -eo pipefail

launcher_version="2026-10-16.1"

print_usage() {
  cat <<'USAGE'
Использование:
  bash build-and-run.sh
  bash build-and-run.sh --list
  bash build-and-run.sh --all [--build-only] [--no-open]
  bash build-and-run.sh --select "1,5 9" [--build-only] [--no-open]
  bash build-and-run.sh --project "путь/к/проекту" [--project "ещё/один"]

Параметры:
  --list             Только показать найденные проекты.
  --all              Выбрать все найденные проекты.
  --select СПИСОК    Выбрать номера через пробел и/или запятую.
  --project ПУТЬ     Выбрать проект по пути; параметр можно повторять.
  --build-only       Проверить и собрать, но не запускать серверы.
  --no-open          Не открывать браузер/эмулятор (только сервер).
  --expo-platform P  Режим Expo: ios, android или web; иначе спросить.
  --install-web-deps Разрешить установку недостающих web-зависимостей Expo.
  --smoke-test       Проверить HTTP-готовность и сразу остановить серверы.
  --ready-timeout N  Предел ожидания HTTP-готовности (секунды; по умолчанию 90).
  --spring-ready-path ПУТЬ  Явный публичный endpoint Spring (например /login).
  --skip-tests       Не запускать автоматические тесты.
  --strict-checks    Останавливать запуск при замечаниях Expo Doctor (для сдачи).
  --root ПАПКА       Искать проекты в другой корневой папке.
  --dry-run          Показать план команд без их выполнения.
  --platform-menu    Показать общее меню платформ и выйти.
  -h, --help         Показать эту справку.

Без --all, --select и --project скрипт предложит интерактивный выбор.
Вложенные папки и проекты без номера в названии поддерживаются.
Один каталог приложения показывается один раз. Этапы выбирайте через --project stages/ИМЯ.
Для остановки всех запущенных им серверов нажмите Control + C.
USAGE
}

die() {
  echo "Ошибка: $*" >&2
  exit 1
}

warn() {
  echo "Предупреждение: $*" >&2
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$script_dir"
list_only=0
select_all=0
selection_spec=""
build_only=0
no_open=0
skip_tests=0
strict_checks=0
dry_run=0
smoke_test=0
ready_timeout=90
spring_ready_path=""
project_requests=()
expo_platform=""
install_web_deps=0
project_expo_platforms=()
platform_menu_only=0

print_expo_menu() {
  echo "Где запустить мобильный проект?"
  echo "1) iOS Simulator (Mac + Xcode)"
  echo "2) Android Emulator (Android Studio / SDK)"
  echo "3) Web (браузер, НЕ эмулятор телефона)"
  echo "0) Отмена"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict-checks) strict_checks=1; shift ;;
    --platform-menu) platform_menu_only=1; shift ;;
    --smoke-test) smoke_test=1; shift ;;
    --ready-timeout)
      [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ && ${#2} -le 4 ]] || die "--ready-timeout: целое число 1–9999."
      ready_timeout="$2"; shift 2 ;;
    --spring-ready-path)
      [[ $# -ge 2 && "$2" == /* && "$2" != //* && "$2" != *$'\n'* ]] || die "публичный endpoint должен начинаться с /."
      spring_ready_path="$2"; shift 2 ;;
    --expo-platform)
      [[ $# -ge 2 ]] || die "после --expo-platform нужно ios, android или web."
      case "$2" in ios|android|web) expo_platform="$2" ;; *) die "режим Expo: ios, android или web." ;; esac
      shift 2
      ;;
    --install-web-deps)
      install_web_deps=1
      shift
      ;;
    --list)
      list_only=1
      shift
      ;;
    --all)
      select_all=1
      shift
      ;;
    --select)
      [[ $# -ge 2 ]] || die "после --select нужен список номеров."
      selection_spec="$2"
      shift 2
      ;;
    --project)
      [[ $# -ge 2 ]] || die "после --project нужен путь."
      project_requests+=("$2")
      shift 2
      ;;
    --build-only)
      build_only=1
      shift
      ;;
    --no-open)
      no_open=1
      shift
      ;;
    --skip-tests)
      skip_tests=1
      shift
      ;;
    --root)
      [[ $# -ge 2 ]] || die "после --root нужен путь к папке."
      root_dir="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      die "неизвестный параметр '$1'. Запустите с --help."
      ;;
  esac
done

if [[ $platform_menu_only -eq 1 ]]; then print_expo_menu; exit 0; fi

selection_modes=0
[[ $select_all -eq 1 ]] && selection_modes=$((selection_modes + 1))
[[ -n "$selection_spec" ]] && selection_modes=$((selection_modes + 1))
[[ ${#project_requests[@]} -gt 0 ]] && selection_modes=$((selection_modes + 1))
[[ $selection_modes -le 1 ]] || die "используйте только один способ выбора: --all, --select или --project."

[[ -d "$root_dir" ]] || die "корневая папка не существует: $root_dir"
root_dir="$(cd -- "$root_dir" && pwd)"

package_type() {
  local package_file="$1"

  # Vite имеет приоритет: в учебный web-репозиторий может случайно попасть
  # зависимость expo, хотя его scripts dev/build/preview остаются Vite-командами.
  if grep -Eq '"vite"[[:space:]]*:' "$package_file"; then
    echo "vite"
  elif grep -Eq '"expo"[[:space:]]*:' "$package_file"; then
    echo "expo"
  else
    echo "npm"
  fi
}

human_type() {
  case "$1" in
    expo) echo "Expo" ;;
    vite) echo "Vite" ;;
    spring) echo "Spring Boot" ;;
    npm) echo "npm (неизвестный тип)" ;;
    maven) echo "Maven (не Spring Boot)" ;;
    *) echo "$1" ;;
  esac
}

project_dirs=()
project_types=()
project_labels=()
project_markers=()
project_task_numbers=()

task_number_for_project() {
  local label="$1"
  local type="$2"
  local number

  local task_pattern="/0*([0-9]+)[[:space:]_-]"
  if [[ "/$label" =~ $task_pattern ]]; then
    number=$((10#${BASH_REMATCH[1]}))
    echo "$number"
  elif [[ "$type" == "spring" && "$label" == "projects/spring-boot/bookstore" ]]; then
    # В комплекте общий Spring-проект хранится как projects/spring-boot/bookstore.
    echo "3"
  else
    echo "0"
  fi
}

is_supported_type() {
  case "$1" in
    vite|expo|spring) return 0 ;;
    *) return 1 ;;
  esac
}

has_supported_ancestor() {
  local project_dir="$1"
  local ancestor
  local ancestor_type

  ancestor="$(dirname -- "$project_dir")"
  while [[ "$ancestor" == "$root_dir" || "$ancestor" == "$root_dir/"* ]]; do
    ancestor_type=""
    if [[ -f "$ancestor/package.json" ]]; then
      ancestor_type="$(package_type "$ancestor/package.json")"
    elif [[ -f "$ancestor/pom.xml" ]] && grep -Eq 'spring-boot' "$ancestor/pom.xml"; then
      ancestor_type="spring"
    fi

    if [[ -n "$ancestor_type" ]] && is_supported_type "$ancestor_type"; then
      return 0
    fi

    [[ "$ancestor" != "$root_dir" ]] || break
    ancestor="$(dirname -- "$ancestor")"
  done
  return 1
}

while IFS= read -r marker; do
  [[ -n "$marker" ]] || continue

  project_dir="$(dirname -- "$marker")"
  relative_path="${project_dir#"$root_dir"/}"
  if [[ "$relative_path" == "$project_dir" ]]; then
    relative_path="$(basename -- "$project_dir")"
  fi

  if [[ "$(basename -- "$marker")" == "package.json" ]]; then
    detected_type="$(package_type "$marker")"
  elif grep -Eq 'spring-boot' "$marker"; then
    detected_type="spring"
  else
    detected_type="maven"
  fi

  # Не показываем неподдерживаемый npm/Maven-проект как запускаемое приложение.
  is_supported_type "$detected_type" || continue

  # Если проект уже имеет запускаемый корень, вложенные package.json/pom.xml
  # считаются его внутренними частями, а не отдельными приложениями.
  has_supported_ancestor "$project_dir" && continue

  task_number="$(task_number_for_project "$relative_path" "$detected_type")"

  project_dirs+=("$project_dir")
  project_types+=("$detected_type")
  project_labels+=("$relative_path")
  project_markers+=("$marker")
  project_task_numbers+=("$task_number")
done < <(
  find "$root_dir" \
    \( -type d \( \
      -name .git -o \
      -name node_modules -o \
      -name .expo -o \
      -name dist -o \
      -name build -o \
      -name target -o \
      -name coverage \
    \) -prune \) -o \
    \( -type f \( -name package.json -o -name pom.xml \) -print \) \
    | LC_ALL=C sort
)

[[ ${#project_dirs[@]} -gt 0 ]] || die "в '$root_dir' не найдено ни одного package.json или pom.xml."

# Один физический каталог — одно приложение: этапы не дублируются.

project_sort_key() {
  local task_number="$1"
  local label="$2"
  if ((task_number <= 0)); then
    task_number=99999999
  fi
  printf '%08d|%s' "$task_number" "$label"
}

# Сортируем по логическому номеру работы: 01-09.
for ((left = 0; left < ${#project_dirs[@]}; left++)); do
  for ((right = left + 1; right < ${#project_dirs[@]}; right++)); do
    left_key="$(project_sort_key "${project_task_numbers[$left]}" "${project_labels[$left]}")"
    right_key="$(project_sort_key "${project_task_numbers[$right]}" "${project_labels[$right]}")"
    if [[ "$left_key" > "$right_key" ]]; then
      temporary="${project_dirs[$left]}"
      project_dirs[$left]="${project_dirs[$right]}"
      project_dirs[$right]="$temporary"

      temporary="${project_types[$left]}"
      project_types[$left]="${project_types[$right]}"
      project_types[$right]="$temporary"

      temporary="${project_labels[$left]}"
      project_labels[$left]="${project_labels[$right]}"
      project_labels[$right]="$temporary"

      temporary="${project_markers[$left]}"
      project_markers[$left]="${project_markers[$right]}"
      project_markers[$right]="$temporary"

      temporary="${project_task_numbers[$left]}"
      project_task_numbers[$left]="${project_task_numbers[$right]}"
      project_task_numbers[$right]="$temporary"
    fi
  done
done

terminal_table_source() {
  cat <<'__TERMINAL_TABLE_PY__'
"""Shared, read-only terminal menu renderer. Python 3.9+, standard library only."""
import argparse
from datetime import date, datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET

TYPES = {"vite": "Vite", "expo": "Expo", "spring": "Spring Boot"}


def clean(value):
    return "".join(" " if unicodedata.category(c).startswith("C") and c != "\u200d" else c
                   for c in str(value)).strip()


def cell_width(value):
    width = 0
    joined = False
    regional = False
    for char in value:
        if char == "\u200d":
            joined = True
            continue
        if unicodedata.combining(char) or char in ("\ufe0e", "\ufe0f") or 0x1F3FB <= ord(char) <= 0x1F3FF:
            continue
        is_regional = 0x1F1E6 <= ord(char) <= 0x1F1FF
        size = 2 if unicodedata.east_asian_width(char) in ("W", "F") or 0x1F000 <= ord(char) <= 0x1FAFF else 1
        if not joined and not (is_regional and regional):
            width += size
        joined = False
        regional = is_regional and not regional
    return width


def fit(value, width):
    value = clean(value)
    if cell_width(value) > width:
        prefix = ""
        for char in value:
            if cell_width(prefix + char) > width - 1:
                break
            prefix += char
        value = prefix.rstrip("\u200d") + "…"
    return value + " " * max(0, width - cell_width(value))


def terminal_width():
    raw = os.environ.get("COLUMNS", "")
    return max(32, min(240, int(raw))) if raw.isdigit() else max(32, min(240, shutil.get_terminal_size((120, 24)).columns))


def table(rows, width=None):
    width = width or terminal_width()
    headers = ["№", "Имя", "Папка", "Тип", "Создана"]
    # Five visible fields even in a small terminal; prefer space for names and folders.
    widths = [max(2, len(str(len(rows)))), 4, 5, 3, 10]
    available = max(0, width - 16 - sum(widths))
    for column, target in ((3, 11), (1, 22), (2, 36), (1, 42), (2, 120)):
        extra = min(available, max(0, target - widths[column]))
        widths[column] += extra
        available -= extra
    if width < sum(widths) + 16:
        widths[4] = max(4, width - 16 - sum(widths[:4]))
        for column in (2, 1):
            excess = max(0, sum(widths) + 16 - width)
            widths[column] -= min(excess, widths[column] - 3)
    def border(left, middle, right):
        return left + middle.join("─" * (n + 2) for n in widths) + right
    def row_line(values):
        return "│ " + " │ ".join(fit(value, n) for value, n in zip(values, widths)) + " │"
    lines = [border("┌", "┬", "┐"), row_line(headers), border("├", "┼", "┤")]
    lines.extend(row_line(row) for row in rows)
    lines.append(border("└", "┴", "┘"))
    return "\n".join(lines)


def local_path(raw):
    if os.name == "nt":
        match = re.fullmatch(r"/(?:cygdrive/)?([A-Za-z])(?:/(.*))?", raw)
        if match:
            return Path(match[1] + ":/" + (match[2] or ""))
    return Path(raw)


def creation_date(path):
    try:
        info = path.stat()
        birth = getattr(info, "st_birthtime", None)
        if birth is None and os.name == "nt":
            birth = info.st_ctime
        if birth is not None:
            return datetime.fromtimestamp(birth).strftime("%Y-%m-%d")
    except (OSError, ValueError, OverflowError):
        return "—"
    # Linux ctime is metadata-change time, not creation time. Ask stat for birth time.
    for command in (["stat", "-c", "%w", "--", str(path)],
                    ["stat", "-f", "%SB", "-t", "%Y-%m-%d", str(path)]):
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=2, check=False)
            value = result.stdout.strip()[:10]
            if result.returncode == 0 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
                return date.fromisoformat(value).isoformat()
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    return "—"


def friendly_name(path, marker, label):
    try:
        if marker == "package.json":
            app = path / "app.json"
            if app.is_file():
                data = json.loads(app.read_text(encoding="utf-8-sig"))
                name = data.get("expo", {}).get("name")
                if isinstance(name, str) and name.strip():
                    return clean(name)
            data = json.loads((path / marker).read_text(encoding="utf-8-sig"))
            name = data.get("displayName") or data.get("name")
        else:
            root = ET.parse(path / marker).getroot()
            name = None
            for key in ("name", "artifactId"):
                element = next((item for item in root if item.tag.rsplit("}", 1)[-1] == key), None)
                if element is not None and element.text and element.text.strip():
                    name = element.text.strip()
                    break
        if isinstance(name, str) and name.strip():
            # Remove course scaffolding identifiers, retain the application name.
            name = re.sub(r"^(?:front-end-sof\w+?-\d+-|fullstack-homework-|react-native-homework-|homework-\d+-|assignment\d+-)", "", name)
            name = re.sub(r"-pe\d+$", "", name)
            name = clean(re.sub(r"[-_]+", " ", name))
            return name[:1].upper() + name[1:]
    except (OSError, ValueError, TypeError, AttributeError, ET.ParseError):
        pass
    return clean(Path(label).name or label)


def local_rows(payload):
    values = payload.decode("utf-8", errors="replace").split("\0")
    if values and values[-1] == "":
        values.pop()
    if len(values) % 5:
        raise ValueError("Неполная строка списка проектов.")
    rows = []
    for offset in range(0, len(values), 5):
        number, kind, label, directory, marker = values[offset:offset + 5]
        path = local_path(directory)
        rows.append([number, friendly_name(path, marker, label), label, TYPES.get(kind, kind), creation_date(path)])
    return rows


def catalog_rows(data):
    rows = []
    for number, item in enumerate(data["projects"], 1):
        folder = item["repo"].removesuffix(".git").rsplit("/", 1)[-1]
        kind = item.get("type", "")
        created = item.get("createdAt", "")[:10]
        try:
            created = date.fromisoformat(created).isoformat()
        except (TypeError, ValueError):
            created = "—"
        rows.append([str(number), item["title"], folder, TYPES.get(kind, kind) or "—", created])
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("local", "catalog"))
    parser.add_argument("file", nargs="?")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    if args.mode == "local":
        rows = local_rows(sys.stdin.buffer.read())
    else:
        rows = catalog_rows(json.loads(Path(args.file).read_text(encoding="utf-8-sig")))
    print(table(rows))
    print(f"Всего проектов: {len(rows)}")
    if args.mode == "local":
        print("Создана: локальная папка; — = дата неизвестна.")
        print("… = сокращено; полный путь будет показан после выбора.")
    else:
        print("Создана: репозиторий GitHub; — = дата неизвестна.")
        print("Папка: предлагаемое имя; место сохранения выбирается далее.")


if __name__ == "__main__":
    main()
__TERMINAL_TABLE_PY__
}

table_fallback_cell() {
  local value="$1" width="$2" count control_code control_char
  value="${value//[[:cntrl:]]/ }"
  # Exact UTF-8 byte pairs also work when the shell locale is C, not UTF-8.
  for ((control_code=128; control_code<=159; control_code++)); do
    printf -v control_char '\\302\\%03o' "$control_code"
    printf -v control_char '%b' "$control_char"
    value="${value//"$control_char"/ }"
  done
  if [[ ${#value} -gt $width ]]; then value="${value:0:$((width - 1))}…"; fi
  printf '%s' "$value"
  for ((count=${#value}; count<width; count++)); do printf ' '; done
}

print_projects_fallback() {
  local index cols="${COLUMNS:-100}" name_width folder_width type_width=11 raw_date created label
  [[ "$cols" =~ ^[0-9]{1,3}$ ]] || cols=100
  [[ $cols -ge 40 ]] || cols=40
  [[ $cols -le 180 ]] || cols=180
  [[ $cols -ge 48 ]] || type_width=3
  name_width=$(((cols - 28 - type_width) / 3))
  folder_width=$((cols - 28 - type_width - name_width))
  for ((index=-1; index<${#project_dirs[@]}; index++)); do
    if [[ $index -lt 0 ]]; then
      set -- '№' 'Имя' 'Папка' 'Тип' 'Создана'
    else
      label="${project_labels[$index]}"
      created='—'
      raw_date="$(stat -c '%w' -- "${project_dirs[$index]}" 2>/dev/null || stat -f '%SB' -t '%Y-%m-%d' "${project_dirs[$index]}" 2>/dev/null || true)"
      if [[ "$raw_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then created="${raw_date:0:10}"; fi
      set -- "$((index + 1))" "${label##*/}" "$label" "$(human_type "${project_types[$index]}")" "$created"
    fi
    printf '| '; table_fallback_cell "$1" 2
    printf ' | '; table_fallback_cell "$2" "$name_width"
    printf ' | '; table_fallback_cell "$3" "$folder_width"
    printf ' | '; table_fallback_cell "$4" "$type_width"
    printf ' | '; table_fallback_cell "$5" 10; printf ' |\n'
  done
  printf 'Всего проектов: %s\n' "${#project_dirs[@]}"
  echo 'Создана: локальная папка; — = дата неизвестна.'
  echo '… = сокращено; полный путь будет показан после выбора.'
}

print_projects() {
  local index candidate directory
  local menu_python=()
  echo "Найденные проекты:"
  echo
  # Formatting is optional: a Java/Node project must not require Python to start.
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3,9))' >/dev/null 2>&1; then
      menu_python=("$candidate"); break
    fi
  done
  if [[ ${#menu_python[@]} -eq 0 ]] && command -v py >/dev/null 2>&1 && py -3 -c 'import sys; sys.exit(sys.version_info < (3,9))' >/dev/null 2>&1; then menu_python=(py -3); fi
  if [[ ${#menu_python[@]} -gt 0 ]]; then
    if {
      for ((index=0; index<${#project_dirs[@]}; index++)); do
        directory="${project_dirs[$index]}"
        if command -v cygpath >/dev/null 2>&1; then directory="$(cygpath -am -- "$directory")"; fi
        printf '%s\0%s\0%s\0%s\0%s\0' "$((index + 1))" "${project_types[$index]}" "${project_labels[$index]}" "$directory" "${project_markers[$index]##*/}"
      done
    } | COLUMNS="${COLUMNS:-}" "${menu_python[@]}" -c "$(terminal_table_source)" local; then return 0; fi
  fi
  print_projects_fallback
}

if [[ $list_only -eq 1 ]]; then
  print_projects
  exit 0
fi

selected_indices=()

add_selected_index() {
  local candidate="$1"
  local existing

  for existing in "${selected_indices[@]}"; do
    [[ "$existing" != "$candidate" ]] || return 0
  done
  selected_indices+=("$candidate")
}

select_from_numbers() {
  local input="${1//,/ }"
  local token
  local number

  for token in $input; do
    if [[ "$token" == "all" || "$token" == "все" ]]; then
      for ((number = 0; number < ${#project_dirs[@]}; number++)); do
        add_selected_index "$number"
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      number=$((10#$token))
      if ((number < 1 || number > ${#project_dirs[@]})); then
        die "номера проекта $token нет; допустимы номера от 1 до ${#project_dirs[@]}."
      fi
      add_selected_index "$((number - 1))"
    else
      die "'$token' не является номером проекта."
    fi
  done
}

select_from_path() {
  local requested="$1"
  local requested_dir
  local index
  local match=-1
  local match_count=0
  local explicit_marker
  local explicit_type

  if [[ -d "$requested" ]]; then
    requested_dir="$(cd -- "$requested" && pwd)"
  elif [[ -d "$root_dir/$requested" ]]; then
    requested_dir="$(cd -- "$root_dir/$requested" && pwd)"
  else
    die "папка проекта не существует: $requested"
  fi

  for ((index = 0; index < ${#project_dirs[@]}; index++)); do
    if [[ "${project_dirs[$index]}" == "$requested_dir" || "${project_dirs[$index]}" == "$requested_dir/"* ]]; then
      match="$index"
      match_count=$((match_count + 1))
    fi
  done

  # Явно выбранный вложенный stage разрешён, даже если primary уже найден.
  if [[ $match_count -eq 0 && ( "$requested_dir" == "$root_dir" || "$requested_dir" == "$root_dir/"* ) ]]; then
    explicit_marker=""
    explicit_type=""
    if [[ -f "$requested_dir/package.json" ]]; then
      explicit_marker="$requested_dir/package.json"
      explicit_type="$(package_type "$explicit_marker")"
    elif [[ -f "$requested_dir/pom.xml" ]] && grep -Eq 'spring-boot' "$requested_dir/pom.xml"; then
      explicit_marker="$requested_dir/pom.xml"
      explicit_type="spring"
    fi
    if is_supported_type "$explicit_type"; then
      match="${#project_dirs[@]}"
      project_dirs+=("$requested_dir")
      project_types+=("$explicit_type")
      project_labels+=("${requested_dir#"$root_dir"/}")
      project_markers+=("$explicit_marker")
      project_task_numbers+=("0")
      match_count=1
    fi
  fi

  if [[ $match_count -eq 0 ]]; then
    die "в '$requested' нет поддерживаемого файла проекта."
  elif [[ $match_count -gt 1 ]]; then
    die "в '$requested' найдено несколько проектов; укажите точнее или выберите их по номерам."
  fi

  add_selected_index "$match"
}

if [[ $select_all -eq 1 ]]; then
  for ((index = 0; index < ${#project_dirs[@]}; index++)); do
    add_selected_index "$index"
  done
elif [[ -n "$selection_spec" ]]; then
  select_from_numbers "$selection_spec"
elif [[ ${#project_requests[@]} -gt 0 ]]; then
  for requested_project in "${project_requests[@]}"; do
    select_from_path "$requested_project"
  done
else
  [[ -t 0 ]] || die "нет интерактивного ввода; используйте --all, --select или --project."
  print_projects
  echo
  echo "Введите номера через пробел/запятую, 'all' для всех или 0 для отмены."
  read -r -p "Ваш выбор: " selection_spec
  if [[ "$selection_spec" == "0" ]]; then
    echo "Запуск отменён."
    exit 0
  fi
  select_from_numbers "$selection_spec"
fi

[[ ${#selected_indices[@]} -gt 0 ]] || die "не выбран ни один проект."

echo "Выбрано работ: ${#selected_indices[@]}"
echo "Версия запуска: $launcher_version; автоматическое восстановление зависимостей включено."
for selected_index in "${selected_indices[@]}"; do
  echo "  - ${project_labels[$selected_index]} ($(human_type "${project_types[$selected_index]}"))"
done

# Для каждого Expo-проекта выбираем платформу ДО сборки и запуска.
for selected_index in "${selected_indices[@]}"; do
  [[ "${project_types[$selected_index]}" == "expo" ]] || continue
  selected_platform="$expo_platform"
  if [[ -z "$selected_platform" ]]; then
    if [[ $dry_run -eq 1 ]]; then
      selected_platform="<ios|android|web>"
    elif [[ $build_only -eq 1 ]]; then
      selected_platform="android"
    elif [[ -t 0 ]]; then
      echo
      print_expo_menu
      while true; do
        read -r -p "Режим: " platform_choice || die "ввод прерван."
        case "$platform_choice" in
          1|ios) selected_platform=ios; break ;;
          2|android) selected_platform=android; break ;;
          3|web) selected_platform=web; break ;;
          0) echo "Запуск отменён."; exit 0 ;;
          *) echo "Введите 1, 2, 3 или 0." ;;
        esac
      done
    else
      die "для Expo укажите --expo-platform ios, android или web."
    fi
  fi
  project_expo_platforms[$selected_index]="$selected_platform"
done

print_dry_run_plan() {
  local index="$1"
  local type="${project_types[$index]}"

  echo
  echo "План: ${project_labels[$index]}"
  case "$type" in
    vite)
      echo "  зависимости: npm ci --engine-strict (или npm install --engine-strict без lock)"
      echo "  проверка:     typecheck при наличии; test:run или CI=1 npm test"
      echo "  сборка:       npm run build"
      echo "  запуск:       npm exec -- vite preview --host 127.0.0.1 --port <свободный> --strictPort"
      ;;
    expo)
      echo "  зависимости: npm ci --engine-strict (или npm install --engine-strict без lock)"
      echo "  проверка:     typecheck при наличии; test:run или CI=1 npm test; Expo Doctor"
      echo "  сборка:       expo export --platform ${project_expo_platforms[$index]} --output-dir dist"
      echo "  запуск:       expo start --${project_expo_platforms[$index]} --localhost --port <свободный>"
      echo "  используется локальный Expo CLI; --no-open отключает открытие среды."
      ;;
    spring)
      echo "  сборка:       bash ./mvnw clean verify"
      echo "  запуск:       java -jar target/<приложение>.jar --server.port=<свободный>"
      ;;
    *)
      echo "  ошибка: тип проекта не поддерживается"
      ;;
  esac
}

if [[ $dry_run -eq 1 ]]; then
  for selected_index in "${selected_indices[@]}"; do
    print_dry_run_plan "$selected_index"
  done
  if [[ $build_only -eq 1 ]]; then
    echo
    echo "Режим --build-only: команды запуска были бы пропущены."
  fi
  exit 0
fi

need_node=0
need_java=0
for selected_index in "${selected_indices[@]}"; do
  case "${project_types[$selected_index]}" in
    vite|expo|npm) need_node=1 ;;
    spring|maven) need_java=1 ;;
  esac
done

if [[ $need_node -eq 1 ]] && { ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; }; then
  export NVM_DIR="${NVM_DIR:-${HOME:-}/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  fi
fi

# Не включаем `set -u`: стандартный macOS Bash 3.2 считает пустые массивы
# (например, список уже занятых нами портов до первого запуска) необъявленными.

if [[ $need_node -eq 1 ]]; then
  command -v node >/dev/null 2>&1 || die "Node.js не найден. Установите актуальную LTS-версию Node.js."
  command -v npm >/dev/null 2>&1 || die "npm не найден. Переустановите Node.js вместе с npm."

  if ! node -e '
const [major, minor, patch] = process.versions.node.split(".").map(Number);
const supported =
  major > 22 ||
  (major === 22 && minor >= 12) ||
  (major === 20 && (minor > 19 || (minor === 19 && patch >= 4)));
if (!supported) {
  console.error(`Требуется Node.js 20.19.4+ или 22.12+; установлена ${process.versions.node}.`);
  process.exit(1);
}
'; then
    echo "Если используется NVM: nvm install 22 && nvm use 22" >&2
    exit 1
  fi
fi

if [[ $need_java -eq 1 ]]; then
  command -v java >/dev/null 2>&1 || die "Java не найдена; для Spring Boot установите JDK 17 или новее."
  java_major="$(java -XshowSettings:properties -version 2>&1 | awk '/java.version =/ { split($3, parts, "."); if (parts[1] == 1) print parts[2]; else print parts[1]; exit }')"
  [[ "$java_major" =~ ^[0-9]+$ ]] || die "не удалось определить версию Java."
  ((java_major >= 17)) || die "для Spring Boot требуется JDK 17 или новее; найдена Java $java_major."
fi

validate_package_json() {
  local package_file="$1"
  node -e '
const fs = require("fs");
const file = process.argv[1];
const value = JSON.parse(fs.readFileSync(file, "utf8"));
if (!value || typeof value !== "object" || Array.isArray(value)) {
  throw new Error("корень package.json должен быть объектом");
}
' "$package_file" >/dev/null
}

has_npm_script() {
  local package_file="$1"
  local script_name="$2"
  node -e '
const value = require(process.argv[1]);
process.exit(value.scripts && typeof value.scripts[process.argv[2]] === "string" ? 0 : 1);
' "$package_file" "$script_name"
}

validate_selected_projects() {
  local index
  local type
  local marker
  local dir

  for index in "${selected_indices[@]}"; do
    type="${project_types[$index]}"
    marker="${project_markers[$index]}"
    dir="${project_dirs[$index]}"

    [[ -f "$marker" ]] || die "файл проекта исчез: $marker"

    case "$type" in
      vite|expo|npm)
        if ! validate_package_json "$marker"; then
          die "некорректный JSON в $marker"
        fi
        if [[ "$type" == "vite" ]] && ! has_npm_script "$marker" "build"; then
          die "в $marker отсутствует script 'build'."
        fi
        # Expo вызывается напрямую: scripts start/web не обязательны.
        if [[ "$type" == "npm" ]]; then
          die "не удалось определить Vite или Expo в $dir; этот npm-проект не запускается автоматически."
        fi
        ;;
      spring)
        if [[ ! -f "$dir/mvnw" ]] && ! command -v mvn >/dev/null 2>&1; then
          die "для $dir не найден Maven Wrapper (mvnw) и команда mvn."
        fi
        ;;
      maven)
        die "$dir является Maven-проектом, но не распознан как Spring Boot."
        ;;
    esac
  done
}

validate_selected_projects
if [[ $build_only -eq 0 ]]; then
  command -v curl >/dev/null 2>&1 || die "curl нужен для проверки HTTP-готовности серверов."
fi

expo_cli_for() {
  node -e '
const path = require("path");
const p = require.resolve("expo/package.json", {paths:[process.argv[1]]});
const pkg = require(p);
const bin = typeof pkg.bin === "string" ? pkg.bin : pkg.bin.expo;
process.stdout.write(path.resolve(path.dirname(p), bin));
' "$1"
}

validate_expo_device() {
  local platform="$1"
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  local devices
  local avds
  [[ $build_only -eq 0 && $no_open -eq 0 ]] || return 0
  case "$platform" in
    ios)
      [[ "$(uname -s)" == "Darwin" ]] || die "iOS Simulator доступен только в macOS. Выберите android или web."
      command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1 || die "нужен полный Xcode (не только Command Line Tools). Откройте Xcode и завершите первичную настройку."
      if ! devices="$(xcrun simctl list devices available --json)"; then
        die "не удалось получить симуляторы Xcode; проверьте выбранный Xcode и установленную платформу iOS."
      fi
      if ! printf '%s' "$devices" | node -e '
let s=""; process.stdin.on("data",c=>s+=c); process.stdin.on("end",()=>{
const d=JSON.parse(s).devices || {};
process.exit(Object.keys(d).some(k=>k.includes(".iOS-") && d[k].some(v=>v.isAvailable!==false))?0:1);
});'; then
        die "нет доступного iOS Simulator. Xcode → Settings → Components/Platforms → установите iOS и создайте симулятор."
      fi
      ;;
    android)
      if [[ -z "$sdk" ]]; then
        if [[ -d "${HOME:-}/Library/Android/sdk" ]]; then sdk="${HOME:-}/Library/Android/sdk"
        elif [[ -d "${HOME:-}/Android/Sdk" ]]; then sdk="${HOME:-}/Android/Sdk"
        elif [[ -n "${LOCALAPPDATA:-}" && -d "${LOCALAPPDATA//\\//}/Android/Sdk" ]]; then sdk="${LOCALAPPDATA//\\//}/Android/Sdk"; fi
      fi
      if [[ -n "$sdk" && -d "$sdk" ]]; then
        export ANDROID_HOME="$sdk"
        export PATH="$sdk/platform-tools:$sdk/emulator:$PATH"
      fi
      command -v adb >/dev/null 2>&1 || die "Android SDK: adb не найден. Для Android установите Android Studio + SDK Platform-Tools. На Mac для iOS повторите запуск и выберите 1; Android всегда пункт 2."
      devices="$(adb devices)" || die "Android: adb не отвечает."
      if ! printf '%s\n' "$devices" | grep -Eq '^emulator-[0-9]+[[:space:]]+device'; then
        command -v emulator >/dev/null 2>&1 || die "Android Emulator не найден. Установите его через SDK Manager."
        avds="$(emulator -list-avds)" || die "не удалось прочитать Android AVD."
        [[ -n "$avds" ]] || die "нет Android AVD. Android Studio → Device Manager → Create Virtual Device."
      fi
      echo "Expo откроет доступное Android-устройство/AVD. Если подключён телефон, отключите его для запуска именно эмулятора."
      ;;
  esac
}

# Проверяем среду раньше длительной сборки. Ничего не устанавливаем глобально.
for selected_index in "${selected_indices[@]}"; do
  [[ "${project_types[$selected_index]}" == "expo" ]] || continue
  validate_expo_device "${project_expo_platforms[$selected_index]}"
done

prepare_expo_platform() {
  local dir="$1"
  local platform="$2"
  local cli
  local missing
  local answer
  local config
  cli="$(expo_cli_for "$dir")" || die "локальный Expo CLI не найден в $dir."
  if [[ "$platform" == "web" ]]; then
    missing="$(node -e '
const p=require(process.argv[1]); const d={...p.dependencies,...p.devDependencies};
console.log(["react-dom","react-native-web","@expo/metro-runtime"].filter(n=>!d[n]).join(" "));
' "$dir/package.json")"
    if [[ -n "$missing" ]]; then
      echo "Для Web отсутствуют зависимости: $missing"
      if [[ $install_web_deps -ne 1 ]]; then
        if [[ -t 0 ]]; then
          read -r -p "Установить совместимые с Expo версии в этот проект? [y/N]: " answer || die "ввод прерван."
          case "$answer" in y|Y|yes|да|Да) ;; *) die "выберите native-режим или установите зависимости: npx expo install $missing" ;; esac
        else
          die "повторите с --install-web-deps либо выполните в проекте: npx expo install $missing"
        fi
      fi
      # Список фиксированный, пользовательский ввод в shell-команду не подставляется.
      node "$cli" install react-dom react-native-web @expo/metro-runtime
    fi
  fi
  config="$(node "$cli" config --type public --json)" || die "не удалось прочитать конфигурацию Expo: $dir"
  if ! printf '%s' "$config" | node -e '
let s=""; process.stdin.on("data",c=>s+=c); process.stdin.on("end",()=>{
const c=JSON.parse(s); const p=c.platforms || (c.expo && c.expo.platforms);
process.exit(!Array.isArray(p) || p.includes(process.argv[1]) ? 0 : 1);
});' "$platform"; then
    die "платформа $platform исключена настройкой platforms в app.json/app.config.*. Добавьте её в список platforms или выберите другой режим. Конфигурация не изменена."
  fi
}

install_node_dependencies() {
  local dir="$1" recovery

  cd "$dir"
  if [[ ! -f package-lock.json ]]; then
    echo "package-lock.json отсутствует — выполняю npm install."
    npm install --engine-strict --no-audit --no-fund
  elif [[ "${force_clean_install:-0}" == 1 ]] || ! install_fingerprint "$dir" check; then
    echo "Устанавливаю точные версии зависимостей командой npm ci."
    if ! npm ci --engine-strict --no-audit --no-fund; then
      recovery="${dependency_reports:-$(mktemp -d "${TMPDIR:-/tmp}/homework-deps.XXXXXXXX")}/ci-recovery"
      mkdir -p "$recovery/before" "$recovery/fresh"
      cp -- package.json package-lock.json "$recovery/before/"
      cp -- package.json "$recovery/fresh/"
      echo "Восстанавливаю lock из текущих настроек проекта и повторяю чистую установку..."
      if (cd "$recovery/fresh" && npm install --package-lock-only --ignore-scripts --no-force --engine-strict --no-fund --no-audit --fetch-retries=0 --fetch-timeout=20000) > "$recovery/repair.log" 2>&1 && dependency_json guard "$recovery/before" "$recovery/fresh" && cp -- "$recovery/fresh/package-lock.json" "$dir/package-lock.json" && npm ci --engine-strict --no-audit --no-fund; then
        echo "Зависимости автоматически восстановлены."
      else
        cp -- "$recovery/before/package.json" "$recovery/before/package-lock.json" "$dir/"
        cat "$recovery/repair.log" >&2
        die "установка не восстановилась; настройки сохранены. Отчёт: $recovery"
      fi
    fi
  else
    echo "Зависимости уже установлены и актуальны."
  fi
  install_fingerprint "$dir" write
}

# Lock-only npm operations can rewrite timestamps without installing packages.
# Use content and runtime fingerprints, never mtimes, to trust node_modules.
install_fingerprint() {
  node - "$1" "$2" <<'INSTALL_FINGERPRINT'
const fs=require('fs'), path=require('path'), crypto=require('crypto');
const [dir,mode]=process.argv.slice(2), file=path.join(dir,'node_modules','.homework-install.json');
const hash=n=>fs.existsSync(path.join(dir,n))?crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,n))).digest('hex'):null;
const value={package:hash('package.json'),lock:hash('package-lock.json'),installedLock:hash('node_modules/.package-lock.json'),node:process.versions.node,platform:process.platform,arch:process.arch};
if(mode==='write') fs.writeFileSync(file,JSON.stringify(value)+'\n');
else { try { if(JSON.stringify(JSON.parse(fs.readFileSync(file,'utf8')))!==JSON.stringify(value)) process.exit(1); } catch { process.exit(1); } }
INSTALL_FINGERPRINT
}

# Keep audit reports/backups outside the project; never force a new Expo SDK.
dependency_json() {
  node - "$@" <<'DEPENDENCY_JSON'
const fs = require('fs'), path = require('path');
const [mode, ...args] = process.argv.slice(2);
const read = p => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
// Frozen delivery SDK profiles; only these known coursework apps are restored.
const knownExpoBaselines = {"homework-08-find-address":{"dependencies":{"expo":"~57.0.24","react":"19.2.3","react-native":"0.86.3","react-native-safe-area-context":"~5.7.0","expo-location":"~57.0.19","react-native-maps":"1.27.2"},"devDependencies":{"@types/react":"~19.2.2","typescript":"~6.0.3"}},"fullstack-homework-calculator-pages":{"dependencies":{"expo":"~54.0.36","expo-status-bar":"~3.0.9","react":"19.1.0","react-native":"0.81.5","react-dom":"19.1.0","react-native-web":"^0.21.0","@react-navigation/native":"^7.1.22","@react-navigation/native-stack":"^7.8.2","react-native-safe-area-context":"~5.6.2","react-native-screens":"~4.16.0"},"devDependencies":{"@testing-library/react-native":"13.3.3","jest":"29.7.0","jest-expo":"~54.0.18","react-test-renderer":"19.1.0","@types/jest":"^29.5.14","@types/react":"~19.1.0","typescript":"~5.9.2"}},"assignment13-contacts":{"dependencies":{"@expo/metro-runtime":"~57.0.16","expo":"~57.0.24","expo-contacts":"~57.0.5","react":"19.2.3","react-dom":"19.2.3","react-native":"0.86.3","react-native-safe-area-context":"~5.7.0","react-native-web":"~0.21.0"},"devDependencies":{"@types/node":"~24.0.0","@types/react":"~19.2.2","typescript":"~6.0.3"}},"fullstack-homework-euro-converter":{"dependencies":{"expo":"~54.0.36","expo-status-bar":"~3.0.9","react":"19.1.0","react-native":"0.81.5","@react-native-picker/picker":"2.11.1","react-dom":"19.1.0","react-native-web":"^0.21.0"},"devDependencies":{"@testing-library/react-native":"13.3.3","jest":"29.7.0","jest-expo":"~54.0.18","react-test-renderer":"19.1.0","@types/jest":"29.5.14","@types/node":"22.15.3","@types/react":"~19.1.10","typescript":"~5.9.2"}},"homework-12-firebase-shopping":{"dependencies":{"expo":"~57.0.24","react":"19.2.3","react-native":"0.86.3","react-native-safe-area-context":"~5.7.0","firebase":"12.19.0","@react-native-async-storage/async-storage":"2.2.0"},"devDependencies":{"@types/react":"~19.2.2","typescript":"~6.0.3"}},"react-native-homework-number-guessing-game":{"dependencies":{"expo":"~54.0.36","expo-status-bar":"~3.0.9","react":"19.1.0","react-native":"0.81.5"},"devDependencies":{"@testing-library/react-native":"13.3.3","jest":"29.7.0","jest-expo":"~54.0.18","react-test-renderer":"19.1.0"}},"my-places":{"dependencies":{"expo":"~54.0.37","react":"19.1.0","react-native":"0.81.5","react-dom":"19.1.0","react-native-web":"~0.21.0","expo-sqlite":"~16.0.10","react-native-maps":"1.20.1","react-native-paper":"5.15.3","react-native-safe-area-context":"~5.6.0","react-native-screens":"~4.16.0","@react-navigation/native":"^7.1.9","@react-navigation/native-stack":"^7.3.0","@expo/vector-icons":"^15.0.3"},"devDependencies":{"typescript":"~5.9.2","@types/react":"~19.1.10","@types/node":"^24.0.0"}},"fullstack-homework-recipe-finder":{"dependencies":{"expo":"~54.0.36","expo-status-bar":"~3.0.9","react":"19.1.0","react-native":"0.81.5","react-dom":"19.1.0","react-native-web":"^0.21.0"},"devDependencies":{"@testing-library/react-native":"13.3.3","jest":"29.7.0","jest-expo":"~54.0.18","react-test-renderer":"19.1.0","@types/jest":"^29.5.14","@types/react":"~19.1.0","typescript":"~5.9.2"}},"shopping-list-paper":{"dependencies":{"expo":"~54.0.37","expo-sqlite":"~16.0.10","react":"19.1.0","react-dom":"19.1.0","react-native":"0.81.5","react-native-paper":"5.15.3","react-native-safe-area-context":"~5.6.0","react-native-web":"~0.21.0"},"devDependencies":{"@types/react":"~19.1.10","typescript":"~5.9.2"}},"soundshades":{"dependencies":{"@expo/metro-runtime":"~57.0.16","@react-native-async-storage/async-storage":"2.2.0","@react-navigation/native":"^7.1.0","@react-navigation/native-stack":"^7.3.0","expo":"~57.0.24","expo-asset":"~57.0.18","expo-audio":"~57.0.5","expo-crypto":"~57.0.3","firebase":"^12.0.0","react":"19.2.3","react-dom":"19.2.3","react-native":"0.86.3","react-native-safe-area-context":"~5.7.0","react-native-screens":"~4.26.0","react-native-web":"~0.21.0"},"devDependencies":{"@firebase/rules-unit-testing":"^5.0.0","@types/node":"~24.0.0","@types/react":"~19.2.2","typescript":"~6.0.3"}},"assignment-14-text-to-speech":{"dependencies":{"@expo/metro-runtime":"~57.0.16","@react-native-segmented-control/segmented-control":"2.5.7","expo":"~57.0.24","expo-speech":"~57.0.3","react":"19.2.3","react-dom":"19.2.3","react-native":"0.86.3","react-native-safe-area-context":"~5.7.0","react-native-web":"~0.21.0"},"devDependencies":{"@types/node":"~24.0.0","@types/react":"~19.2.2","typescript":"~6.0.3"}},"homework-09-weather-forecast":{"dependencies":{"expo":"~57.0.24","react":"19.2.3","react-native":"0.86.3","react-native-safe-area-context":"~5.7.0","expo-location":"~57.0.19"},"devDependencies":{"@types/react":"~19.2.2","typescript":"~6.0.3"}}};
if (mode === 'restore-baseline') {
  const [dir, reports] = args, filename = path.join(dir,'package.json'), pkg = read(filename), baseline = knownExpoBaselines[pkg.name];
  if (!baseline) { console.log('unchanged'); process.exit(0); }
  const lockFile = path.join(dir,'package-lock.json'), lock = fs.existsSync(lockFile) ? read(lockFile) : null;
  const core = ['expo','react','react-native'];
  let broken = core.some(n => pkg.dependencies?.[n] !== baseline.dependencies[n]);
  if (lock) for (const n of core) {
    const installed = lock.packages?.['node_modules/'+n]?.version || lock.dependencies?.[n]?.version;
    const expected = baseline.dependencies[n].match(/\d+\.\d+/)?.[0];
    if (installed && !installed.startsWith(expected+'.')) broken = true;
  }
  if (!broken) { console.log('unchanged'); process.exit(0); }
  const backup = path.join(reports,'before-sdk-restore'); fs.mkdirSync(backup);
  fs.copyFileSync(filename,path.join(backup,'package.json'));
  if (lock) fs.copyFileSync(lockFile,path.join(backup,'package-lock.json'));
  pkg.dependencies ||= {};
  for (const [n,v] of Object.entries(baseline.dependencies)) {
    if (n === 'expo' || n.startsWith('expo-') || ['react','react-dom','react-native','react-native-web','react-native-safe-area-context','react-native-screens','@expo/metro-runtime'].includes(n)) pkg.dependencies[n]=v;
  }
  for (const n of ['@types/react','typescript']) if (baseline.devDependencies[n]) { pkg.devDependencies ||= {}; pkg.devDependencies[n]=baseline.devDependencies[n]; }
  fs.writeFileSync(filename,JSON.stringify(pkg,null,2)+'\n');
  console.log('restored');
} else if (mode === 'clean-rn-types') {
  const [dir,reports]=args, filename=path.join(dir,'package.json'), pkg=read(filename);
  const sections=['dependencies','devDependencies','optionalDependencies','peerDependencies'];
  if(!sections.some(s=>Object.hasOwn(pkg[s]||{},'@types/react-native'))) { console.log('unchanged'); process.exit(0); }
  let ownsTypes=!!knownExpoBaselines[pkg.name];
  const native=path.join(dir,'node_modules/react-native'), nativeFile=path.join(native,'package.json');
  if(!ownsTypes && fs.existsSync(nativeFile)) {
    const info=read(nativeFile), types=info.types||info.typings;
    if(typeof types==='string') {
      const target=path.resolve(native,types);
      ownsTypes=target.startsWith(native+path.sep)&&fs.existsSync(target);
    }
  }
  if(!ownsTypes) { console.log('unchanged'); process.exit(0); }
  const backup=path.join(reports,'before-rn-types-cleanup'); fs.mkdirSync(backup);
  fs.copyFileSync(filename,path.join(backup,'package.json'));
  const lock=path.join(dir,'package-lock.json'); if(fs.existsSync(lock)) fs.copyFileSync(lock,path.join(backup,'package-lock.json'));
  for(const section of sections) if(pkg[section]) delete pkg[section]['@types/react-native'];
  if(pkg.peerDependenciesMeta) delete pkg.peerDependenciesMeta['@types/react-native'];
  fs.writeFileSync(filename,JSON.stringify(pkg,null,2)+'\n'); console.log('removed');
} else if (mode === 'audit-count') {
  const r = read(args[0]);
  if (r.error || !r.metadata || !r.metadata.vulnerabilities || !Number.isInteger(r.metadata.vulnerabilities.total)) process.exit(2);
  console.log(r.metadata.vulnerabilities.total);
} else if (mode === 'fix-result') {
  if (read(args[0]).error) process.exit(1);
} else if (mode === 'guard') {
  const before = read(path.join(args[0], 'package-lock.json'));
  const after = read(path.join(args[1], 'package-lock.json'));
  const pkg = read(path.join(args[0], 'package.json'));
  const names = Object.keys({...pkg.dependencies, ...pkg.devDependencies, ...pkg.optionalDependencies});
  const version = (lock, n) => lock.packages?.['node_modules/' + n]?.version || lock.dependencies?.[n]?.version;
  for (const n of names) {
    const a = version(before,n), b = version(after,n);
    if (!a && !b) continue;
    const av = String(a).match(/^(\d+)\.(\d+)\./), bv = String(b).match(/^(\d+)\.(\d+)\./);
    if (!av || !bv || av[1] !== bv[1] || (av[1] === '0' && av[2] !== bv[2])) {
      console.error('Отклонена смена несовместимой ветки зависимости: ' + n); process.exit(1);
    }
  }
} else if (mode === 'pending-actions') {
  const [reportFile, dir] = args, report = read(reportFile), pkg = read(path.join(dir,'package.json'));
  const lock = read(path.join(dir,'package-lock.json'));
  if (!Array.isArray(report.allowScripts)) process.exit(1);
  const policy = pkg.allowScripts || {};
  for (const item of report.allowScripts) {
    const name = item.name;
    if (!['fsevents','esbuild'].includes(name)) continue;
    if (Object.keys(policy).some(k => k === name || k.startsWith(name+'@'))) continue;
    const folder = path.join(dir,'node_modules',name), infoFile = path.join(folder,'package.json');
    if (!fs.existsSync(infoFile)) continue;
    const info = read(infoFile), entry = lock.packages?.['node_modules/'+name];
    if (!entry || entry.version !== info.version || !String(entry.resolved).startsWith('https://registry.npmjs.org/'+name+'/') || !String(entry.integrity).startsWith('sha512-')) continue;
    if (name === 'fsevents' && info.version === '2.3.3' && fs.existsSync(path.join(folder,'fsevents.node')) && !info.scripts?.install && !fs.existsSync(path.join(folder,'binding.gyp'))) {
      if (process.platform === 'darwin') require(folder);
      console.log('deny\tfsevents');
    } else if (name === 'esbuild' && info.scripts?.postinstall === 'node install.js') {
      console.log('approve\tesbuild@'+info.version);
    }
  }
}
DEPENDENCY_JSON
}

repair_dependency_lock() {
  local dir="$1" before after code=0 restored cleaned backup
  dependency_reports="$(mktemp -d "${TMPDIR:-/tmp}/homework-deps.XXXXXXXX")"
  force_clean_install=0
  restored="$(dependency_json restore-baseline "$dir" "$dependency_reports")" || die "не удалось проверить SDK-профиль приложения."
  cleaned="$(dependency_json clean-rn-types "$dir" "$dependency_reports")" || die "не удалось проверить встроенные типы React Native."
  if [[ "$restored" == restored ]]; then
    echo "Восстанавливаю согласованные версии Expo/React/React Native из учебного комплекта. Резервная копия: $dependency_reports/before-sdk-restore"
  fi
  if [[ "$cleaned" == removed ]]; then
    echo "Убираю лишний @types/react-native: React Native содержит собственные типы. Резервная копия: $dependency_reports/before-rn-types-cleanup"
  fi
  if [[ "$restored" == restored || "$cleaned" == removed ]]; then
    force_clean_install=1
    if [[ "$restored" == restored ]]; then backup="$dependency_reports/before-sdk-restore"; else backup="$dependency_reports/before-rn-types-cleanup"; fi
    mkdir "$dependency_reports/fresh-lock"
    cp -- "$dir/package.json" "$dependency_reports/fresh-lock/"
    if (cd "$dependency_reports/fresh-lock" && npm install --package-lock-only --ignore-scripts --no-force --engine-strict --no-fund --no-audit --fetch-retries=0 --fetch-timeout=20000) > "$dependency_reports/sdk-restore.log" 2>&1; then
      cp -- "$dependency_reports/fresh-lock/package-lock.json" "$dir/package-lock.json"
    else
      cp -- "$backup/package.json" "$dir/package.json"
      cat "$dependency_reports/sdk-restore.log" >&2
      die "не удалось получить согласованный lock; исходный package.json восстановлен."
    fi
  fi
  [[ -f "$dir/package-lock.json" ]] || return 0
  echo "Проверяю уязвимости зависимостей; отчёты: $dependency_reports"
  (cd "$dir" && npm audit --json --fetch-retries=0 --fetch-timeout=20000) > "$dependency_reports/audit-before.json" 2> "$dependency_reports/audit-before.log" || true
  if ! before="$(dependency_json audit-count "$dependency_reports/audit-before.json")"; then
    warn "npm audit не получил достоверный отчёт. Проверка уязвимостей не завершена; журнал: $dependency_reports"
    return 0
  fi
  if [[ "$before" == 0 ]]; then echo "npm audit: известных уязвимостей не найдено."; return 0; fi
  mkdir "$dependency_reports/before"
  cp -- "$dir/package.json" "$dir/package-lock.json" "$dependency_reports/before/"
  echo "Найдено: $before. Применяю исправления в пределах совместимых веток зависимостей..."
  (cd "$dir" && npm audit fix --package-lock-only --ignore-scripts --no-force --engine-strict --no-fund --json --fetch-retries=0 --fetch-timeout=20000) > "$dependency_reports/audit-fix.json" 2> "$dependency_reports/audit-fix.log" || code=$?
  if [[ $code -gt 1 ]] || ! dependency_json fix-result "$dependency_reports/audit-fix.json" || ! dependency_json guard "$dependency_reports/before" "$dir"; then
    cp -- "$dependency_reports/before/package.json" "$dependency_reports/before/package-lock.json" "$dir/"
    warn "Исправление audit отклонено; исходные package.json и lock восстановлены. Журнал: $dependency_reports"
  fi
  if ! cmp -s "$dependency_reports/before/package-lock.json" "$dir/package-lock.json"; then force_clean_install=1; fi
  (cd "$dir" && npm audit --json --fetch-retries=0 --fetch-timeout=20000) > "$dependency_reports/audit-after.json" 2> "$dependency_reports/audit-after.log" || true
  if after="$(dependency_json audit-count "$dependency_reports/audit-after.json")"; then
    echo "npm audit: до исправления $before, после $after."
    if [[ "$after" != 0 ]]; then warn "Осталось $after уязвимостей. Обновление SDK/несовместимых зависимостей автоматически не применяется. Подробности: $dependency_reports/audit-after.json"; fi
  else
    warn "Повторный npm audit недоступен; итоговый статус уязвимостей неизвестен. Журнал: $dependency_reports"
  fi
}

resolve_install_scripts() {
  local dir="$1" action spec remaining
  [[ -f "$dir/package-lock.json" ]] || return 0
  if (cd "$dir" && npm approve-scripts --allow-scripts-pending --json) > "$dependency_reports/pending.json" 2> "$dependency_reports/pending.log"; then
    if ! dependency_json pending-actions "$dependency_reports/pending.json" "$dir" > "$dependency_reports/actions.tsv"; then
      warn "Не удалось разобрать install scripts; автоматические разрешения не выданы. Журнал: $dependency_reports"
      return 0
    fi
    while IFS=$'\t' read -r action spec; do
      [[ -n "$action" ]] || continue
      if [[ "$action" == deny && "$spec" == fsevents ]]; then
        echo "fsevents 2.3.3: готовый native-модуль проверен; ненужная повторная компиляция отключена."
        (cd "$dir" && npm deny-scripts fsevents) || die "не удалось сохранить политику fsevents."
      elif [[ "$action" == approve && "$spec" == esbuild@* ]]; then
        echo "Разрешаю только установленную версию $spec из npm registry."
        (cd "$dir" && npm approve-scripts "$spec" && npm rebuild "$spec" --no-audit) || die "не удалось подготовить $spec."
      fi
    done < "$dependency_reports/actions.tsv"
    (cd "$dir" && npm approve-scripts --allow-scripts-pending --json) > "$dependency_reports/pending-after.json" 2>/dev/null || return 0
    remaining="$(node -e 'const p=require(process.argv[1]); console.log((p.allowScripts||[]).map(x=>x.name).join(", "))' "$dependency_reports/pending-after.json")"
    if [[ -n "$remaining" ]]; then warn "Install scripts требуют отдельного решения: $remaining. Отчёт: $dependency_reports/pending-after.json"; fi
  fi
}

check_expo_dependencies() {
  local dir="$1" cli backup
  cli="$(expo_cli_for "$dir")" || return 1
  echo "Проверяю версии пакетов для установленного Expo SDK..."
  if (cd "$dir" && CI=1 node "$cli" install --check) > "$dependency_reports/expo-versions.log" 2>&1; then
    cat "$dependency_reports/expo-versions.log"; return 0
  fi
  cat "$dependency_reports/expo-versions.log"
  if ! grep -Eq 'should be updated|expected version|Expected package' "$dependency_reports/expo-versions.log"; then
    die "Проверка версий Expo не завершилась. Подробности: $dependency_reports/expo-versions.log"
  fi
  backup="$dependency_reports/before-expo-fix"
  mkdir "$backup"; cp -- "$dir/package.json" "$dir/package-lock.json" "$backup/"
  echo "Исправляю версии пакетов под текущий Expo SDK..."
  if (cd "$dir" && CI=1 npm_config_audit=false npm_config_fund=false node "$cli" install --fix --npm) && dependency_json guard "$backup" "$dir" && cli="$(expo_cli_for "$dir")" && (cd "$dir" && CI=1 node "$cli" install --check); then
    return 0
  else
    cp -- "$backup/package.json" "$backup/package-lock.json" "$dir/"
    (cd "$dir" && npm ci --engine-strict --no-audit) || true
    die "Исправление Expo не подтверждено; исходные manifests восстановлены. Журнал: $dependency_reports"
  fi
}

run_expo_doctor() {
  local dir="$1"
  echo "Проверяю совместимость Expo..."
  if (cd "$dir" && npm_config_fetch_retries=0 npm_config_fetch_timeout=20000 npx --yes expo-doctor@latest) > "$dependency_reports/expo-doctor.log" 2>&1; then
    cat "$dependency_reports/expo-doctor.log"; return 0
  fi
  cat "$dependency_reports/expo-doctor.log"
  if grep -Fq 'Directory check failed with unexpected server response' "$dependency_reports/expo-doctor.log"; then
    warn "Внешний React Native Directory не ответил. Повторяю остальные проверки; проверка совместимости SDK сохраняется."
    if (cd "$dir" && EXPO_DOCTOR_ENABLE_DIRECTORY_CHECK=0 npm_config_fetch_retries=0 npm_config_fetch_timeout=20000 npx --yes expo-doctor@latest) > "$dependency_reports/expo-doctor-retry.log" 2>&1; then
      cat "$dependency_reports/expo-doctor-retry.log"
      echo "Проверки Expo пройдены; внешний Directory недоступен и не подтверждён."
      return 0
    fi
    cat "$dependency_reports/expo-doctor-retry.log"
  fi
  if [[ "${strict_checks:-0}" == 1 ]]; then
    die "Expo Doctor обнаружил нерешённую проблему. Журнал: $dependency_reports"
  fi
  warn "Замечания Expo Doctor сохранены: $dependency_reports. Продолжаю сборку и проверку запуска. Для строгой проверки используйте --strict-checks."
  return 0
}

ensure_expo_go_compatible() {
  local dir="$1" platform="$2"
  [[ $build_only -eq 0 && $no_open -eq 0 && "$platform" == ios ]] || return 0
  echo "Проверяю Expo Go в iOS Simulator для SDK проекта..."
  # Use the project's own Expo CLI to select the same simulator and download
  # its SDK-specific Expo Go. Install in place; never uninstall/erase app data.
  node - "$dir" <<'EXPO_GO_COMPATIBILITY'
const fs=require('fs'), path=require('path'), {spawnSync}=require('child_process');
(async()=>{
  const dir=process.argv[2];
  const expoFile=require.resolve('expo/package.json',{paths:[dir]});
  const sdk=JSON.parse(fs.readFileSync(expoFile,'utf8')).version.split('.')[0]+'.0.0';
  const cli=path.dirname(require.resolve('@expo/cli/package.json',{paths:[path.dirname(expoFile)]}));
  const load=p=>require(path.join(cli,'build/src',p));
  const {getVersionsAsync}=load('api/getVersions.js');
  const versions=await getVersionsAsync();
  const expected=versions.sdkVersions?.[sdk]?.iosClientVersion;
  if(!expected) throw new Error('Expo API не вернул версию Expo Go для SDK '+sdk+'. Выберите эту версию на https://expo.dev/go и установите в Simulator.');
  const {AppleDeviceManager}=load('start/platforms/ios/AppleDeviceManager.js');
  const device=await AppleDeviceManager.resolveAsync({shouldPrompt:false});
  const appId='host.exp.Exponent';
  const container=await device.isAppInstalledAndIfSoReturnContainerPathForIOSAsync(appId);
  let installed=container?await device.getAppVersionAsync(appId,{containerPath:typeof container==='string'?container:undefined}):null;
  if(installed===expected) { console.log('Expo Go '+expected+' соответствует SDK '+sdk+'.'); return; }
  console.log('SDK '+sdk+': установлен Expo Go '+(installed||'не установлен')+', нужен '+expected+'. Устанавливаю совместимую версию в '+device.name+'...');
  const {downloadExpoGoAsync}=load('utils/downloadExpoGoAsync.js');
  const binary=await downloadExpoGoAsync('ios',{sdkVersion:sdk});
  // Stop the old running binary without uninstalling its data container.
  spawnSync('xcrun',['simctl','terminate',device.identifier,appId],{stdio:'ignore'});
  await device.installAppAsync(binary);
  const newContainer=await device.isAppInstalledAndIfSoReturnContainerPathForIOSAsync(appId);
  installed=await device.getAppVersionAsync(appId,{containerPath:typeof newContainer==='string'?newContainer:undefined});
  if(installed!==expected) throw new Error('После установки версия Expo Go '+installed+' не совпала с '+expected+'. Запуск остановлен.');
  console.log('Expo Go '+expected+' установлен и проверен для SDK '+sdk+'.');
})().catch(error=>{console.error('Ошибка совместимости Expo Go: '+error.message); process.exitCode=1;});
EXPO_GO_COMPATIBILITY
}

has_typescript_sources() {
  local dir="$1"
  local source_file

  source_file="$(
    find "$dir" \
      \( -type d \( -name node_modules -o -name .expo -o -name dist -o -name coverage \) -prune \) -o \
      \( -type f \( -name '*.ts' -o -name '*.tsx' \) -print \) \
      | sed -n '1p'
  )"
  [[ -n "$source_file" ]]
}

run_node_checks() {
  local dir="$1"
  local type="$2"
  local package_file="$dir/package.json"

  cd "$dir"
  if has_npm_script "$package_file" "typecheck"; then
    echo "Проверяю TypeScript..."
    npm run typecheck
  elif [[ -f tsconfig.json && -x node_modules/.bin/tsc ]]; then
    echo "Проверяю TypeScript..."
    npm exec -- tsc --noEmit
  elif has_typescript_sources "$dir"; then
    warn "в ${project_labels[$3]} есть TypeScript, но не настроена команда typecheck."
  fi

  if [[ $skip_tests -eq 1 ]]; then
    echo "Тесты пропущены по параметру --skip-tests."
  elif has_npm_script "$package_file" "test:run"; then
    echo "Запускаю тесты..."
    npm run test:run
  elif has_npm_script "$package_file" "test"; then
    echo "Запускаю тесты..."
    # Honor the configured runner. Jest flags break Node --test, while
    # --run is not a universal option. CI also disables default watch mode.
    CI=1 npm test
  else
    warn "для ${project_labels[$3]} не настроены автоматические тесты."
  fi
}

build_node_project() {
  local index="$1"
  local dir="${project_dirs[$index]}"
  local type="${project_types[$index]}"

  echo
  echo "============================================================"
  echo "Проверяю и собираю: ${project_labels[$index]}"
  echo "============================================================"

  repair_dependency_lock "$dir"
  install_node_dependencies "$dir"
  if [[ "$type" == "expo" ]]; then
    prepare_expo_platform "$dir" "${project_expo_platforms[$index]}"
    check_expo_dependencies "$dir"
  fi
  resolve_install_scripts "$dir"
  install_fingerprint "$dir" write
  run_node_checks "$dir" "$type" "$index"

  cd "$dir"
  if [[ "$type" == "vite" ]]; then
    echo "Собираю Vite production-версию..."
    npm run build
    [[ -s dist/index.html ]] || die "Vite не создал $dir/dist/index.html"
  else
    run_expo_doctor "$dir"
    echo "Собираю Expo bundle: ${project_expo_platforms[$index]}..."
    node "$(expo_cli_for "$dir")" export --platform "${project_expo_platforms[$index]}" --output-dir dist
    [[ -n "$(find dist -type f -print | sed -n '1p')" ]] || die "Expo не создал файлы в $dir/dist"
    ensure_expo_go_compatible "$dir" "${project_expo_platforms[$index]}" || die "не удалось установить Expo Go под SDK проекта."
  fi
}

validate_mysql_profile() {
  local dir="$1"
  local profile="$dir/src/main/resources/application-mysql.properties"

  [[ -f "$profile" ]] || die "для работы 09 отсутствует $profile"
  grep -F '${BOOKSTORE_MYSQL_URL}' "$profile" >/dev/null || die "MySQL URL должен приходить из BOOKSTORE_MYSQL_URL."
  grep -F '${BOOKSTORE_MYSQL_USERNAME}' "$profile" >/dev/null || die "MySQL username должен приходить из BOOKSTORE_MYSQL_USERNAME."
  grep -F '${BOOKSTORE_DB_PASSWORD}' "$profile" >/dev/null || die "MySQL password должен приходить из BOOKSTORE_DB_PASSWORD."
}

run_maven() {
  local dir="$1"
  shift

  cd "$dir"
  if [[ -f mvnw ]]; then
    bash ./mvnw "$@"
  else
    mvn "$@"
  fi
}

build_spring_project() {
  local index="$1"
  local dir="${project_dirs[$index]}"

  echo
  echo "============================================================"
  echo "Проверяю и собираю: ${project_labels[$index]}"
  echo "============================================================"

  if [[ $skip_tests -eq 1 ]]; then
    run_maven "$dir" -DskipTests clean verify
  else
    run_maven "$dir" clean verify
  fi
}

processed_build_dirs=()

build_dir_was_processed() {
  local candidate="$1"
  local existing
  for existing in "${processed_build_dirs[@]}"; do
    [[ "$existing" != "$candidate" ]] || return 0
  done
  return 1
}

for selected_index in "${selected_indices[@]}"; do
  if [[ "${project_labels[$selected_index]}" == *"[MySQL Optional]" ]]; then
    validate_mysql_profile "${project_dirs[$selected_index]}"
  fi

  if build_dir_was_processed "${project_dirs[$selected_index]}"; then
    echo "Пропускаю повторную сборку общего каталога: ${project_labels[$selected_index]}"
    continue
  fi
  processed_build_dirs+=("${project_dirs[$selected_index]}")

  case "${project_types[$selected_index]}" in
    vite|expo) build_node_project "$selected_index" ;;
    spring) build_spring_project "$selected_index" ;;
  esac
done

echo
echo "Сборки завершены; отсутствующие или пропущенные тесты указаны выше."

if [[ $build_only -eq 1 ]]; then
  exit 0
fi

reserved_ports=()

port_is_reserved() {
  local candidate="$1"
  local reserved
  for reserved in "${reserved_ports[@]}"; do
    [[ "$reserved" != "$candidate" ]] || return 0
  done
  return 1
}

port_is_free() {
  local port="$1"

  if command -v lsof >/dev/null 2>&1; then
    ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v nc >/dev/null 2>&1; then
    ! nc -z 127.0.0.1 "$port" >/dev/null 2>&1
  else
    ! (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1
  fi
}

choose_port() {
  local candidate="$1"
  local limit=$((candidate + 200))

  while ((candidate <= limit)); do
    if ! port_is_reserved "$candidate" && port_is_free "$candidate"; then
      reserved_ports+=("$candidate")
      chosen_port="$candidate"
      return 0
    fi
    candidate=$((candidate + 1))
  done

  die "не найден свободный порт в диапазоне $1-$limit."
}

spring_jar() {
  local dir="$1"
  local jar
  local selected=""
  local count=0

  for jar in "$dir"/target/*.jar; do
    [[ -f "$jar" ]] || continue
    case "$(basename -- "$jar")" in
      original-*|*-sources.jar|*-javadoc.jar|*-tests.jar|*-test.jar|*-plain.jar) continue ;;
    esac
    selected="$jar"
    count=$((count + 1))
  done
  if [[ $count -eq 0 ]]; then
    echo "В $dir/target нет JAR приложения после сборки." >&2
    return 1
  fi
  if [[ $count -ne 1 ]]; then
    echo "В $dir/target найдено несколько JAR приложения. Запуск отменён: выбирать первый небезопасно." >&2
    echo "Проверьте настройки Maven/classifier: после clean verify должен остаться один запускаемый JAR." >&2
    return 1
  fi
  printf '%s\n' "$selected"
}

spring_url_path() {
  local dir="$1"
  local login_path
  if [[ -n "$spring_ready_path" ]]; then
    echo "$spring_ready_path"
    return
  fi
  # A literal endpoint, never shell code. CLI override has higher priority.
  if [[ -f "$dir/.spring-ready-path" ]]; then
    login_path="$(cat "$dir/.spring-ready-path")"
    if [[ "$login_path" == /* && "$login_path" != //* && "$login_path" != *$'\n'* && "$login_path" != *$'\r'* && ${#login_path} -le 4096 ]]; then
      printf '%s\n' "$login_path"
      return
    fi
    echo "Некорректный .spring-ready-path: нужен один относительный URL, начинающийся с /." >&2
    return 1
  fi
  # Use a declared form-login page. A JWT/API SecurityFilterChain alone does
  # not imply a /login endpoint. Custom endpoints can be supplied explicitly.
  if [[ -d "$dir/src/main" ]]; then
    login_path="$(find "$dir/src/main" -type f -name '*.java' -exec sed -nE 's/.*[.]loginPage[[:space:]]*\([[:space:]]*"(\/[^"[:space:]]*)".*/\1/p' {} \; | LC_ALL=C sort -u)"
    if [[ -n "$login_path" && "$login_path" != *$'\n'* && "$login_path" != //* ]]; then
      printf '%s\n' "$login_path"
      return
    elif [[ -n "$login_path" ]]; then
      echo "Объявлено несколько loginPage; укажите --spring-ready-path." >&2
      return 1
    fi
  fi
  if [[ -d "$dir/src/main" ]] && grep -R -Eq '[.]formLogin[[:space:]]*\(' "$dir/src/main" 2>/dev/null; then
    echo "/login"
  elif [[ -d "$dir/src/main" ]] && grep -R -q '@GetMapping("/booklist")' "$dir/src/main" 2>/dev/null; then
    echo "/booklist"
  else
    echo "/"
  fi
}

launch_ports=()
launch_urls=()
launch_pids=()
launch_logs=()
launch_indices=()
launch_modes=()
started_dirs=()
logs_dir="$(mktemp -d "${TMPDIR:-/tmp}/homework-runner.XXXXXX")"

dir_was_started() {
  local candidate="$1"
  local existing
  for existing in "${started_dirs[@]}"; do
    [[ "$existing" != "$candidate" ]] || return 0
  done
  return 1
}

start_project() {
  local index="$1"
  local port="$2"
  local log_file="$3"
  local dir="${project_dirs[$index]}"
  local type="${project_types[$index]}"
  local jar
  local cli
  local args=()

  case "$type" in
    vite)
      (
        cd "$dir"
        exec npm exec -- vite preview --host 127.0.0.1 --port "$port" --strictPort
      ) >"$log_file" 2>&1 &
      ;;
    expo)
      cli="$(expo_cli_for "$dir")" || die "не найден Expo CLI."
      args=(start --localhost --port "$port")
      if [[ "${project_expo_platforms[$index]}" == "web" ]]; then
        args+=(--web)
      else
        args+=(--go)
        if [[ $no_open -eq 0 ]]; then args+=("--${project_expo_platforms[$index]}"); fi
      fi
      (
        cd "$dir"
        export BROWSER=none
        exec node "$cli" "${args[@]}"
      ) < /dev/null >"$log_file" 2>&1 &
      ;;
    spring)
      jar="$(spring_jar "$dir")" || die "не удалось однозначно выбрать JAR для $dir."
      echo "Запускаю JAR: $jar"
      (
        cd "$dir"
        exec java -jar "$jar" --server.port="$port"
      ) >"$log_file" 2>&1 &
      ;;
  esac

  launch_pids+=("$!")
}

# Bash job control даёт каждому запущенному серверу СОБСТВЕННУЮ группу.
# Завершаем только эти группы: без pkill node, удаления файлов и убийства по порту.
set -m
cleanup_servers() {
  local exit_status=$?
  local pid
  local attempt=0
  local alive
  trap - EXIT
  trap '' INT TERM
  for pid in "${launch_pids[@]}"; do
    kill -TERM -- "-$pid" >/dev/null 2>&1 || true
  done
  while ((attempt < 5)); do
    alive=0
    for pid in "${launch_pids[@]}"; do
      if kill -0 -- "-$pid" >/dev/null 2>&1; then alive=1; fi
    done
    [[ $alive -eq 1 ]] || break
    sleep 1
    attempt=$((attempt + 1))
  done
  for pid in "${launch_pids[@]}"; do
    kill -KILL -- "-$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
  done
  echo "Серверы этого запуска остановлены. Файлы проектов сохранены."
  exit "$exit_status"
}
trap cleanup_servers EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for selected_index in "${selected_indices[@]}"; do
  if dir_was_started "${project_dirs[$selected_index]}"; then
    echo "Один сервер уже представляет общий каталог: ${project_labels[$selected_index]}"
    continue
  fi
  started_dirs+=("${project_dirs[$selected_index]}")

  case "${project_types[$selected_index]}" in
    vite)
      choose_port 4173
      port="$chosen_port"
      url="http://127.0.0.1:$port/"
      ;;
    expo)
      choose_port 8081
      port="$chosen_port"
      url="http://127.0.0.1:$port/"
      ;;
    spring)
      choose_port 8080
      port="$chosen_port"
      url="http://127.0.0.1:$port$(spring_url_path "${project_dirs[$selected_index]}")"
      ;;
  esac

  log_file="$logs_dir/project-$((selected_index + 1)).log"
  launch_ports+=("$port")
  launch_urls+=("$url")
  launch_logs+=("$log_file")
  launch_indices+=("$selected_index")
  launch_modes+=("${project_expo_platforms[$selected_index]:-web}")
  start_project "$selected_index" "$port" "$log_file"
done

wait_until_ready() {
  local pid="$1"
  local url="$2"
  local log_file="$3"
  local mode="$4"
  local type="${5:-node}"
  local attempt=0
  local body
  local status
  local ready_url="$url"

  if [[ "$mode" != "web" ]]; then ready_url="${url}status"; fi

  while ((attempt < ready_timeout)); do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      echo "Сервер завершился до запуска. Последние строки журнала:" >&2
      tail -n 30 "$log_file" >&2 || true
      return 1
    fi
    if [[ "$type" == "spring" ]]; then
      # Публичный /login обязан отвечать 2xx. Защищённый 401/403 не подтверждает готовность.
      if status="$(curl -sS --max-time 2 --output /dev/null --write-out '%{http_code}' "$ready_url" 2>/dev/null)"; then
        case "$status" in
          2??) return 0 ;;
        esac
      fi
    elif body="$(curl -fsS --max-time 2 "$ready_url" 2>/dev/null)"; then
      if [[ "$mode" == "web" ]]; then return 0; fi
      if [[ "$body" == "packager-status:running" ]]; then
        # В SDK 54 эта строка печатается после попытки открытия среды.
        # Один HTTP-ответ Metro ещё не означает завершение установки Expo Go.
        if [[ $no_open -eq 1 ]] || grep -q 'Waiting on ' "$log_file"; then return 0; fi
      fi
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  echo "Сервер не подтвердил HTTP-готовность за $ready_timeout секунд: $ready_url" >&2
  tail -n 30 "$log_file" >&2 || true
  if [[ "$type" == "expo" ]]; then
    echo "Если Expo Go требует подтверждения установки/смены версии, запустите один раз вручную в папке проекта: npx expo start --$mode" >&2
  fi
  return 1
}

open_url() {
  local url="$1"

  if [[ $no_open -eq 1 ]]; then
    return 0
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 || warn "не удалось открыть браузер: $url"
  elif command -v cygstart >/dev/null 2>&1; then
    cygstart "$url" >/dev/null 2>&1 || warn "не удалось открыть браузер: $url"
  elif command -v rundll32.exe >/dev/null 2>&1; then
    rundll32.exe url.dll,FileProtocolHandler "$url" >/dev/null 2>&1 || warn "не удалось открыть браузер: $url"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 || warn "не удалось открыть браузер: $url"
  else
    warn "команда открытия браузера не найдена; откройте вручную: $url"
  fi
}

echo
echo "Жду готовности серверов..."
for ((position = 0; position < ${#launch_pids[@]}; position++)); do
  selected_index="${launch_indices[$position]}"
  echo "Проверяю адрес: ${launch_urls[$position]}"
  echo "Журнал запуска: ${launch_logs[$position]}"
  wait_until_ready \
    "${launch_pids[$position]}" \
    "${launch_urls[$position]}" \
    "${launch_logs[$position]}" \
    "${launch_modes[$position]}" \
    "${project_types[$selected_index]}"
  if [[ "${launch_modes[$position]}" == "web" ]]; then
    open_url "${launch_urls[$position]}"
  else
    echo "Expo ${launch_modes[$position]}: Metro готов. Адрес ниже — сервер, НЕ страница приложения."
    [[ $no_open -eq 0 ]] || echo "Открытие эмулятора отключено (--no-open)."
  fi
done

echo
printf '%-4s %-18s %-9s %-7s %s\n' "№" "Тип" "Режим" "Порт" "Адрес сервера"
printf '%-4s %-18s %-9s %-7s %s\n' "--" "------------------" "---------" "-------" "--------------"
for ((position = 0; position < ${#launch_pids[@]}; position++)); do
  selected_index="${launch_indices[$position]}"
  printf '%-4d %-18s %-9s %-7s %s\n' \
    "$((selected_index + 1))" \
    "$(human_type "${project_types[$selected_index]}")" \
    "${launch_modes[$position]}" \
    "${launch_ports[$position]}" \
    "${launch_urls[$position]}"
done

echo
echo "HTTP-готовность серверов подтверждена. Журналы: $logs_dir"
if [[ $smoke_test -eq 1 ]]; then
  echo "Smoke-проверка завершена; серверы будут остановлены."
  exit 0
fi
echo "Для остановки нажмите Control + C."

while true; do
  for ((position = 0; position < ${#launch_pids[@]}; position++)); do
    pid="${launch_pids[$position]}"
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      echo "Сервер ${project_labels[${launch_indices[$position]}]} неожиданно завершился." >&2
      tail -n 30 "${launch_logs[$position]}" >&2 || true
      exit 1
    fi
  done
  sleep 2
done
__EMBED_BUILD_AND_RUN_SH__

# Normalize pasted Windows/Unix paths without evaluating user input as shell code.
destination="$("${python_cmd[@]}" - "$tool_dir" "$destination" <<'__PREPARE_FOLDER__'
import os, re, subprocess, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from export_project import destination as validate
sys.stdout.reconfigure(encoding='utf-8', newline='\n')
sys.stderr.reconfigure(encoding='utf-8', newline='\n')
try:
    raw = sys.argv[2].removesuffix('\r').strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ('"', "'"): raw = raw[1:-1]
    raw = os.path.expandvars(os.path.expanduser(raw))
    if os.name == 'nt':
        match = re.fullmatch(r'/(?:cygdrive/)?([a-zA-Z])(?:/(.*))?', raw)
        if match: raw = match[1] + ':/' + (match[2] or '')
    elif re.match(r'^[a-zA-Z]:[\\/]', raw):
        raw = subprocess.check_output(['wslpath', '-u', raw], text=True).strip()
    if not raw or any(c in raw for c in '\r\n\t\x00') or '..' in Path(raw).parts:
        raise ValueError('Небезопасный путь назначения.')
    value = Path(os.path.abspath(raw))
    if value == Path.home().resolve() or value == Path.cwd().resolve() or value == Path(value.anchor) or value.name.lower() == '.git':
        raise ValueError('Укажите отдельную папку проекта, не корень, домашнюю или текущую папку.')
    if value.is_symlink() or (value.exists() and not value.is_dir()):
        raise ValueError('Папка занята или является ссылкой. Её содержимое сохранено; выберите новую или пустую папку.')
    for ancestor in (value.parent, *value.parent.parents):
        if os.path.lexists(ancestor / '.git'):
            raise ValueError('Папка находится внутри другого Git-репозитория. Выберите независимую папку.')
    value.parent.mkdir(parents=True, exist_ok=True)
    print(validate(str(value), True).as_posix())
except (OSError, ValueError, subprocess.SubprocessError) as error:
    print('Ошибка: ' + str(error), file=sys.stderr)
    sys.exit(1)
__PREPARE_FOLDER__
)"
if [[ $replace_existing -eq 0 && "$("${python_cmd[@]}" "$tool_dir/export_project.py" nonempty "$destination")" == 1 ]]; then
  [[ -t 0 ]] || die 'Папка уже содержит файлы. Для явной замены передайте --replace.'
  echo
  printf 'Папка %s и её содержимое будут заменены, включая локальный Git и несохранённые изменения. Продолжить? [y/N] ' "$destination"
  read -r replace_answer || die 'Ввод завершён; папка не изменена.'
  case "$replace_answer" in y|Y|yes|YES|да|Да|Д) replace_existing=1 ;; *) die 'Отменено; папка не изменена.' ;; esac
fi
echo
printf 'Проект: %s\nПапка: %s\n' "${project_names[$selected]}" "$destination"
echo '[1/3] Скачиваю исходники и очищаю исходную историю и связи GitHub...'
replace_args=()
if [[ $replace_existing -eq 1 ]]; then replace_args+=(--replace); fi
"$BASH" "$tool_dir/export-project.sh" --repo "${project_repos[$selected]}" --ref "${project_refs[$selected]}" --path "${project_paths[$selected]}" --dest "$destination" --init-git "${replace_args[@]}"
# Preserve the launcher in the client copy for a later start without downloading again.
cp -- "$tool_dir/build-and-run.sh" "$destination/build-and-run.sh"
# Platform choice belongs to the embedded launcher, so both entrypoints
# use exactly one menu and one set of preflight/dependency checks.
if [[ -n "$platform" ]]; then
  build_args+=(--expo-platform "$platform")
  if [[ "$platform" == web ]]; then build_args+=(--install-web-deps); fi
fi
echo '[2/3] Копия готова: новый локальный Git без remote и чужих коммитов.'
printf 'Повторный запуск без скачивания: bash %q --project %q\n' "$destination/build-and-run.sh" "$destination"
echo '[3/3] Устанавливаю зависимости, проверяю, собираю и запускаю...'
if "$BASH" "$destination/build-and-run.sh" --root "$destination" --project "$destination" "${build_args[@]}"; then
  exit 0
else
  result=$?
  printf '\nСборка/запуск завершились с кодом %s. Исходники сохранены: %s\n' "$result" "$destination" >&2
  echo 'Устраните причину, указанную выше, и повторите запуск сохранённого build-and-run.sh.' >&2
  exit "$result"
fi
