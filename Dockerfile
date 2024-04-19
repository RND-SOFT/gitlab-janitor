ARG RUBY_VERSION=3.1

FROM ruby:${RUBY_VERSION}-alpine

WORKDIR /home/app

RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc \
  && echo 'gem: --no-document' > ~/.gemrc

ENV \
  BUILDKIT_INLINE_CACHE="1" \
  BUILDKIT_PROGRESS="plain" \
  DOCKER_BUILDKIT="1" \
  DOCKER_CLI_EXPERIMENTAL="1" 

RUN set -ex \
  && apk add --no-cache docker-cli docker-cli-buildx

ADD Gemfile Gemfile.lock gitlab-janitor.gemspec /home/app/
ADD lib/gitlab_janitor/version.rb /home/app/lib/gitlab_janitor/

RUN set -ex \
  && gem install bundler && gem update bundler \
  && bundle config set --local system 'true' \
  && bundle config set --local without 'development' \
  && bundle install --jobs=3 \
  && bundle clean --force \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

ADD . /home/app/

RUN set -ex \
  && bundle install --jobs=3 \
  && bundle clean --force \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

ARG \
  CREATED="2022-08-05 15:22:36+03:00" \
  VERSION="unknown" \
  REVISION="unknown" \
  REFNAME="unknown"

LABEL \
  org.opencontainers.image.created="${CREATED}" \
  org.opencontainers.image.authors="Samoylenko Yuri <kinnalru@yandex.ru>" \
  org.opencontainers.image.url="https://github.com/RND-SOFT/gitlab-janitor" \
  org.opencontainers.image.documentation="https://github.com/RND-SOFT/gitlab-janitor" \
  org.opencontainers.image.source="https://github.com/RND-SOFT/gitlab-janitor" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.revision="${REVISION}" \
  org.opencontainers.image.vendor="RNDSOFT" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.ref.name="${REFNAME}" \
  org.opencontainers.image.title="GitLab Janitor is a tool to automatically manage stalled and dangling resources when using Docker in Gitlab CI/CD" \
  org.opencontainers.image.description="GitLab Janitor is a tool to automatically manage stalled and dangling resources when using Docker in Gitlab CI/CD"

CMD ["bundle", "exec", "bin/gitlab-janitor"]


