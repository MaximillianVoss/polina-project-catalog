"""Load a GitHub JSON catalog as data; never evaluate its contents. Python 3.9+."""
import argparse
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
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    sys.stderr.reconfigure(encoding="utf-8", newline="\n")
    try:
        data, _ = load(args.url, args.embedded, offline=args.offline)
        lines = ["\t".join(row[key] for key in ("id", "title", "repo", "ref", "path")) for row in data["projects"]]
        with Path(args.output).open("w", encoding="utf-8", newline="\n") as output:
            output.write("\n".join(lines) + "\n")
    except (OSError, ValueError, UnicodeError) as error:
        print("Ошибка каталога: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
