# pre-build stage
FROM ruby:3.3.3-alpine3.19 AS pre-builder

# Definindo argumento para versão da aplicação
ARG APP_VERSION=latest
ENV APP_VERSION=${APP_VERSION}

# ARG default to production settings
# For development docker-compose file overrides ARGS
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.1.2

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}

# Removing openssl-legacy-provider flag which may cause issues with Node 20+
ARG NODE_OPTIONS="--max-old-space-size=4096"
ENV NODE_OPTIONS=${NODE_OPTIONS}

ENV BUNDLE_PATH="/gems"

RUN apk update && apk add --no-cache \
  openssl \
  tar \
  build-base \
  tzdata \
  postgresql-dev \
  postgresql-client \
  # Use a more specific Node.js version without pinning patch version
  nodejs~=20.15 \
  npm \
  yarn \
  git \
  && mkdir -p /var/app \
  && gem install bundler \
  && npm install -g pnpm

WORKDIR /app

COPY Gemfile Gemfile.lock ./

# natively compile grpc and protobuf to support alpine musl (dialogflow-docker workflow)
# https://github.com/googleapis/google-cloud-ruby/issues/13306
# adding xz as nokogiri was failing to build libxml
# https://github.com/chatwoot/chatwoot/issues/4045
RUN apk update && apk add --no-cache build-base musl ruby-full ruby-dev gcc make musl-dev openssl openssl-dev g++ linux-headers xz vips \
  && bundle config set --local force_ruby_platform true

# Do not install development or test gems in production
RUN if [ "$RAILS_ENV" = "production" ]; then \
  bundle config set without 'development test'; \
  bundle install -j 4 -r 3; \
else \
  bundle install -j 4 -r 3; \
  fi

COPY package.json yarn.lock ./
RUN yarn install --network-concurrency 1 --network-timeout 600000

# Extrair versão do package.json se não for fornecida externamente
RUN if [ "$APP_VERSION" = "latest" ]; then \
      APP_VERSION=$(cat package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[:space:]'); \
      echo "Detected version: $APP_VERSION"; \
      export APP_VERSION=$APP_VERSION; \
    fi

COPY . /app

# creating a log directory so that image wont fail when RAILS_LOG_TO_STDOUT is false
# https://github.com/chatwoot/chatwoot/issues/701
RUN mkdir -p /app/log

# generate production assets if production environment
# Modified asset precompilation command with better error output and removed openssl-legacy-provider flag
RUN if [ "$RAILS_ENV" = "production" ]; then \
  SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile --trace || exit 1; \
  rm -rf spec node_modules tmp/cache; \
  fi

# Generate .git_sha file with current commit hash
RUN git rev-parse HEAD > /app/.git_sha

# Remove build dependencies
RUN apk del --no-cache build-base musl ruby-dev gcc musl-dev openssl-dev g++ linux-headers xz \
  && rm -rf /var/cache/apk/*

# Remove unnecessary files
RUN rm -rf /gems/ruby/3.3.0/cache/*.gem \
  && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git \
  && rm .gitignore

# final build stage
FROM ruby:3.3.3-alpine3.19

# Passando a versão para o estágio final
ARG APP_VERSION
ENV APP_VERSION=${APP_VERSION}

# Adicionando labels com metadados da versão
LABEL version="${APP_VERSION}"
LABEL org.opencontainers.image.version="${APP_VERSION}"
LABEL description="Chatwoot versão ${APP_VERSION}"

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.1.2

ARG EXECJS_RUNTIME="Disabled"
ENV EXECJS_RUNTIME=${EXECJS_RUNTIME}

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

ARG BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_FORCE_RUBY_PLATFORM=${BUNDLE_FORCE_RUBY_PLATFORM}

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

RUN apk update && apk add --no-cache \
  build-base \
  openssl \
  tzdata \
  postgresql-client \
  imagemagick \
  git \
  vips \
  && gem install bundler

RUN if [ "$RAILS_ENV" != "production" ]; then \
  apk add --no-cache nodejs-current yarn npm; \
  fi

COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

# Copy .git_sha file from pre-builder stage
COPY --from=pre-builder /app/.git_sha /app/.git_sha

WORKDIR /app

# permisos para rails
RUN chmod -R 777 ./docker

EXPOSE 3000
