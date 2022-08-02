ARG RUBY_VERSION=3.1

FROM ruby:${RUBY_VERSION}-alpine

WORKDIR /home/app

RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc \
  && echo 'gem: --no-document' > ~/.gemrc

RUN set -ex \
  && apk add --no-cache docker-cli

ADD Gemfile Gemfile.lock gitlab-janitor.gemspec /home/app/
ADD lib/gitlab-_anitor/version.rb /home/app/lib/gitlab_janitor/

RUN set -ex \
  && gem install bundler && gem update bundler \
  && bundle config set --local system 'true' \
  && bundle install --jobs=3 \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

ADD . /home/app/

RUN set -ex \
  && bundle install --jobs=3 \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

CMD ["bundle", "exec", "bin/gitlab-janitor"]


