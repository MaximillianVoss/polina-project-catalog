# Каталог учебных проектов

Единый список приложений и самостоятельный загрузчик. Скачайте один файл
[download-and-run.sh](https://raw.githubusercontent.com/MaximillianVoss/polina-project-catalog/main/download-and-run.sh)
и запустите `bash download-and-run.sh`. Нужны Bash 3.2+, Git и Python 3.9+;
для выбранного приложения также Node.js или Java из его README.

Выберите проект и новую или пустую конечную папку. Загрузчик скачает исходники,
создаст новый локальный Git без чужой истории и remote, установит зависимости,
проверит, соберёт и запустит приложение. При повторном запуске используйте
сохранённый в папке приложения `build-and-run.sh`.

Меню при каждом запуске читает **projects.json из этого репозитория**.
При сбое сети используется последний корректный каталог, затем встроенный
резервный. В таблице показываются тип приложения (Vite, Expo или Spring Boot)
и дата создания репозитория GitHub; устаревший кэш без этих полей отклоняется.
`--offline` отключает только обновление списка; исходники и npm/Maven
могут по-прежнему требовать сеть. Каталог обрабатывается как JSON, без eval.

```sh
bash download-and-run.sh --list
bash download-and-run.sh --project web-car-shop --dest "$HOME/Projects/Car Shop"
bash download-and-run.sh --project web-car-shop --dest "$HOME/Projects/Car Shop" --smoke-test --no-open
```

Две последние команды — альтернативные примеры: повторно скачивать в занятую
папку нельзя. Существующие файлы не удаляются. Обычный запуск сохраняет сервер
до Ctrl+C; smoke-test проверяет HTTP и останавливает только свой сервер.

## Добавить проект без замены загрузчика

1. Опубликуйте самостоятельный проект в отдельном GitHub-репозитории.
2. Добавьте одну карточку в `projects.json` и сохраните её в ветке `main`.
3. Проверьте карточки: `python3 -c 'from pathlib import Path; from project_catalog import decode; print(len(decode(Path("projects.json").read_bytes())["projects"]))'`.

Формат карточки (в массиве `projects`, schema `polina-project-catalog/v1`):

```json
{
  "id": "web-example",
  "title": "React — Example",
  "repo": "https://github.com/OWNER/REPOSITORY.git",
  "ref": "main",
  "path": ".",
  "type": "vite",
  "createdAt": "2026-10-14T16:08:47Z"
}
```

Сохраняйте существующие ID и порядок: новые проекты добавляйте в конец.
`ref` — ветка, тег или commit; `path` — папка приложения внутри репозитория,
для самостоятельных проектов `.`; `type` — `vite`, `expo` или `spring`, а
`createdAt` — дата создания репозитория в формате ISO 8601, полученная из GitHub.
Не помещайте в список токены или личные данные.
Карточки поддерживаемых React/Vite, Expo и Spring проектов появляются в уже
скачанном загрузчике после обновления каталога; менять скрипты приложений не нужно.
Изменения самого механизма сборки потребуют новой версии загрузчика.

## Проекты

| № | ID | Приложение | Репозиторий |
|---|---|---|---|
| 1 | web-profile | React — Profile Card | [polina-profile-card](https://github.com/MaximillianVoss/polina-profile-card) |
| 2 | web-counter | React — Counter | [polina-counter](https://github.com/MaximillianVoss/polina-counter) |
| 3 | web-feedback | React — User Feedback | [polina-user-feedback](https://github.com/MaximillianVoss/polina-user-feedback) |
| 4 | web-quiz | React — Simple Quiz | [polina-simple-quiz](https://github.com/MaximillianVoss/polina-simple-quiz) |
| 5 | web-budget | React — Budget Tracker | [polina-budget-tracker](https://github.com/MaximillianVoss/polina-budget-tracker) |
| 6 | web-trivia | React — Trivia API | [polina-trivia-api](https://github.com/MaximillianVoss/polina-trivia-api) |
| 7 | web-github | React — GitHub Explorer | [polina-github-explorer](https://github.com/MaximillianVoss/polina-github-explorer) |
| 8 | web-trainer | React — Personal Trainer, итоговый проект | [polina-personal-trainer](https://github.com/MaximillianVoss/polina-personal-trainer) |
| 9 | mob-calculator | React Native — Calculator, история и страницы | [polina-calculator](https://github.com/MaximillianVoss/polina-calculator) |
| 10 | mob-shopping | React Native — Shopping List, SQLite и Paper | [polina-shopping-list](https://github.com/MaximillianVoss/polina-shopping-list) |
| 11 | mob-firebase | React Native — Shopping List Firebase | [polina-shopping-list-firebase](https://github.com/MaximillianVoss/polina-shopping-list-firebase) |
| 12 | mob-guess | React Native — Number Guessing Game | [polina-number-guessing-game](https://github.com/MaximillianVoss/polina-number-guessing-game) |
| 13 | mob-recipe | React Native — Recipe Finder | [polina-recipe-finder](https://github.com/MaximillianVoss/polina-recipe-finder) |
| 14 | mob-euro | React Native — Euro Converter | [polina-euro-converter](https://github.com/MaximillianVoss/polina-euro-converter) |
| 15 | mob-address | React Native — Find Address | [polina-find-address](https://github.com/MaximillianVoss/polina-find-address) |
| 16 | mob-weather | React Native — Weather Forecast | [polina-weather-forecast](https://github.com/MaximillianVoss/polina-weather-forecast) |
| 17 | mob-contacts | React Native — Contacts | [polina-contacts](https://github.com/MaximillianVoss/polina-contacts) |
| 18 | mob-speech | React Native — Text to Speech | [polina-text-to-speech](https://github.com/MaximillianVoss/polina-text-to-speech) |
| 19 | mob-places | React Native — My Places | [polina-my-places](https://github.com/MaximillianVoss/polina-my-places) |
| 20 | mob-soundshades | React Native — SoundShades, итоговый проект | [polina-soundshades](https://github.com/MaximillianVoss/polina-soundshades) |
| 21 | spring-endpoints | Spring Boot — Controller Endpoints | [polina-controller-endpoints](https://github.com/MaximillianVoss/polina-controller-endpoints) |
| 22 | spring-params | Spring Boot — Request Parameters | [polina-request-parameters](https://github.com/MaximillianVoss/polina-request-parameters) |
| 23 | spring-bookstore | Spring Boot — Bookstore, главы 3–6 и Testing | [polina-bookstore](https://github.com/MaximillianVoss/polina-bookstore) |
| 24 | spring-whichone | Spring Boot — WhichOne, итоговый проект | [polina-whichone](https://github.com/MaximillianVoss/polina-whichone) |
| 25 | web-car-shop | React — Car Shop, управление автомобилями | [polina-car-shop](https://github.com/MaximillianVoss/polina-car-shop) |
