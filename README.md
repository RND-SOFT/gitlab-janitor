# gitlab-janitor

[![Gem Version](https://badge.fury.io/rb/gitlab-janitor.svg)](https://rubygems.org/gems/gitlab-janitor)
[![Gem](https://img.shields.io/gem/dt/gitlab-janitor.svg)](https://rubygems.org/gems/gitlab-janitor/versions)
[![YARD](https://badgen.net/badge/YARD/doc/blue)](http://www.rubydoc.info/gems/gitlab-janitor)

GitLab Janitor is a tool to automatically manage stalled containers when using Docker.

## Installation

```sh
$ gem install gitlab-janitor
```

If you'd rather install Gitlab Janitor using bundler, add a line for it in your Gemfile (but set the require option to false, as it is a standalone tool):

```sh
gem 'rubocop', require: false
```

To install as docker container just pull the image:


```sh
docker pull rnds/gitlab-janitor:latest
```

## Quickstart

Just type `gitlab-janitor` and watch the magic happen or run in docker:

```sh
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock rnds/gitlab-janitor:latest
```

## Documentation

Commain line options and default values:

```bash
$ gitlab-janitor --help

Usage: gitlab-janitor [options] 
        --clean-delay=30m            Delay between clean operation ENV[CLEAN_DELAY]
        --include=*units*            <List> Include container for removal. ENV[INCLUDE]
        --exclude=*gitlab*           <List> Exclude container from removal by name. ENV[EXCLUDE]
        --container-deadline=1s      Maximum container run duration. ENV[CONTAINER_DEADLINE]
        --volume-deadline=2d6h       Maximum volume life dudation. ENV[VOLUME_DEADLINE]
        --image-deadline=20d         Maximum image life duration. ENV[IMAGE_DEADLINE]
        --remove                     Real remove instead of dry run. ENV[REMOVE]
        --docker=unix:///var/run/docker.sock
                                     Docker api endpoint. ENV[DOCKER_HOST]
```

### Удаление зависших контейнеров

Порядок определения контейнреов для удаления:

- `include=[*units*]` - в список на удаление включаются контейнеры удовлетворябющие шаблону;
- `exclude=[*gitlab*]` - из спсика исключаются контейнеры по шаблону;
- `container-deadline=[1h10m]` - результирующий список проверяется на длительность запуска контенйра;

### Удаление ненужных volumes

Порядок определения вольюмов для удаления:

- на удаление попадают только вольюмы, не являющиеся именованными;
- `volume-deadline=[2d6h]` - результирующий список проверяется на длительность существования вольюма;

### Удаление образов

Docker не сохраняет временную метку образа при скачивании (pull), таким образом используя средства Docker API невозможно понять как давно образ был скачан и когда его пора удалять. Для решения этой задачи сервис сохраняет информацию о скачанных образах, отслеживая таким образом интервалы устаревания.

Порядок определения образов для удалени:

- на удаление попадают только образы, не имеющие тэг `latest`;
- `image-deadline=[20d]` - результирующий список проверяется на длительность существования образа;


## Examples

Production ready config:

```bash
REMOVE=true INCLUDE="*integr*, *units*" EXCLUDE="*gitlab*" CONTAINER_DEADLINE="1h10m" VOLUME_DEADLINE="3d" IMAGE_DEADLINE="20d" gitlab-janitor
```

## Запуск в докере

```bash
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