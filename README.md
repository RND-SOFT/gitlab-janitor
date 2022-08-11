# gitlab-janitor

<div align="center">

[![Gem Version](https://badge.fury.io/rb/gitlab-janitor.svg)](https://rubygems.org/gems/gitlab-janitor)
[![Gem](https://img.shields.io/gem/dt/gitlab-janitor.svg)](https://rubygems.org/gems/gitlab-janitor/versions)
[![YARD](https://badgen.net/badge/YARD/doc/blue)](http://www.rubydoc.info/gems/gitlab-janitor)
[![outdated](https://lysander.rnds.pro/api/v1/badges/gitlab-janitor_outdated.svg)](https://lysander.rnds.pro/api/v1/badges/gitlab-janitor_outdated.html)



[![Docker Pulls](https://badgen.net/docker/pulls/rnds/gitlab-janitor?icon=docker&label=pulls)](https://hub.docker.com/r/rnds/gitlab-janitor/)
[![Docker Stars](https://badgen.net/docker/stars/rnds/gitlab-janitor?icon=docker&label=stars)](https://hub.docker.com/r/rnds/gitlab-janitor/)



</div>

Gitlab Janitor это утилита для автоматической очистки зависших и брошенных ресурсов при использовании Docker в `Gitlab` CI/CD. Проект вдохновлён утилитой [GitLab Runner Docker Cleanup](https://gitlab.com/gitlab-org/gitlab-runner-docker-cleanup).

---

GitLab Janitor is a tool to automatically manage stalled and dangling resources when using Docker in `Gitlab` CI/CD. Project inpired by [GitLab Runner Docker Cleanup](https://gitlab.com/gitlab-org/gitlab-runner-docker-cleanup).

Возможности / Features

- Удаление повисших контейнеров / Remove dangling containers
- Удаление неиспользуемых хранилищ / Remove unused anonymous volumes
- Удаление неиспользуемых образов / Remove unused images
- Отслеживание вререни использвоания образов / Track image usage timestamp 
- Очистка кешей Docker (build cache) / Cleanup docker build cache
- Готовый [docker-образ](https://hub.docker.com/r/rnds/gitlab-janitor) / Production ready [docker image](https://hub.docker.com/r/rnds/gitlab-janitor)

## Установка / Installation

```sh
$ gem install gitlab-janitor
```

При установке `Gitlab Janitor` через bundler добавте следующую строку в `Gemfile`, установив `require` параметр в `false`:

---

If you'd rather install `Gitlab Janitor` using bundler, add a line for it in your `Gemfile` (but set the `require` option to `false`, as it is a standalone tool):

```sh
gem 'rubocop', require: false
```

Для установки с помощью docker контейнера [скачайте образ](https://hub.docker.com/r/rnds/gitlab-janitor):

---

To install as docker container just [pull the image](https://hub.docker.com/r/rnds/gitlab-janitor):


```sh
docker pull rnds/gitlab-janitor:latest
```

## Быстрый запуск / Quickstart

Запустите `gitlab-janitor` и смотрите за процессом или запустите docker:

---

Just type `gitlab-janitor` and watch the magic happen or run in docker:

```sh
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock rnds/gitlab-janitor:latest
```

## Документация / Documentation

Параметры командной строки, переменные окружения и значения по-умолчанию:

Commain line options, environment variables and default values:

```sh
$ gitlab-janitor --help

Usage: gitlab-janitor [options] 
        --clean-delay=30m            ENV[CLEAN_DELAY]         Delay between clean operation.
        --include=*units*            ENV[INCLUDE]             <List> Include container for removal.
        --exclude=*gitlab*           ENV[EXCLUDE]             <List> Exclude container from removal by name.
        --container-deadline=1h10m   ENV[CONTAINER_DEADLINE]  Maximum container run duration.
        --volume-include=runner*cache*
                                     ENV[VOLUME_INCLUDE]      <List> Include volumes for removal.
        --volume-deadline=2d6h       ENV[VOLUME_DEADLINE]     Maximum volume life duration.
        --image-deadline=20d         ENV[IMAGE_DEADLINE]      Maximum image life duration.
        --image-store=./images.txt   ENV[IMAGE_STORE]         File to store images timestamps.
        --cache-size=10G             ENV[CACHE_SIZE]          Size of docker cache to keep.
        --remove                     ENV[REMOVE]              Real remove instead of dry run.
        --docker=unix:///tmp/mysock  ENV[DOCKER_HOST]         Docker api endpoint.
        --debug                      ENV[LOG_LEVEL]           Verbose logs. ENV values: debug, info, warn, error
```

### Удаление зависших контейнеров / Removing stalled containers

Порядок определения контейнреов для удаления:

- `include=[*units*]` - в список на удаление включаются контейнеры удовлетворяющие шаблону;
- `exclude=[*gitlab*]` - из спсика исключаются контейнеры по шаблону;
- `container-deadline=[1h10m]` - результирующий список проверяется на длительность запуска контенйра;

---

Containers deleted when:

- `include=[*units*]` - select containers by matching name by pattern;
- `exclude=[*gitlab*]` - **reject** containers by matching name by pattern;
- `container-deadline=[1h10m]` - when container lifetime exceeding the deadline it is removed;

### Удаление ненужных volumes / Removing unused volumes

Порядок определения вольюмов для удаления:

- на удаление попадают вольюмы, не являющиеся именованными;
- `volume-include=[runner*cache*]`- дополнительные волюмы для удаления;
- `volume-deadline=[2d6h]` - результирующий список проверяется на длительность существования вольюма;

---

Volumes deleted when:

- select all anonymous volumes;
- `volume-include=[runner*cache*]`- add volumes by matching name by pattern;
- `volume-deadline=[2d6h]` -  when volume lifetime exceeding the deadline it is removed;

### Removing images / Удаление образов

Docker не сохраняет временную метку образа при скачивании (pull), таким образом используя средства `Docker API` невозможно понять как давно образ был скачан и когда его пора удалять. Для решения этой задачи сервис сохраняет информацию о скачанных образах, отслеживая таким образом интервалы устаревания.

Порядок определения образов для удаления:

- При первой встрече нового образа врменная метка сохраняется в локальное хранилище (файл);
- При достижении лимита хранения образ удаляется;
- При обнаружении запущенного контейнера временная метка для соответствующего образа обнуляется;
- `image-deadline=[20d]` - результирующий список проверяется на длительность существования образа;


---

Docker don't track timestamp when puling image, so there is impossible track lifetime through `Docker API`. To solve this problem, the service saves information about downloaded images, thus keeping track of lifetime deadline. 

Images deleted when:

- When a new image is first encountered, the timestamp is stored in local storage (file);
- When a running container is found, the timestamp for the corresponding image is reset to zero;
- `image-deadline=[20d]` - when lifetime exceeding the deadline image it is removed (`docker rmi <image>`);

## Приеры / Examples

Конфиг для продуктового режима / Production ready config:

```sh
REMOVE=true INCLUDE="*integr*, *units*" EXCLUDE="*gitlab*" CONTAINER_DEADLINE="1h10m" VOLUME_DEADLINE="3d" IMAGE_DEADLINE="20d" gitlab-janitor
```

## Запуск в докере / Running in docker

```sh
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e REMOVE=true \
  -e INCLUDE="*integr*, *units*" \
  -e EXCLUDE="*gitlab*" \
  -e CONTAINER_DEADLINE="1h10m" \
  -e VOLUME_DEADLINE="3d" \
  -e IMAGE_DEADLINE="20d" \
  rnds/gitlab-janitor:latest
```

## Лицензия / License

[MIT](./LICENSE)