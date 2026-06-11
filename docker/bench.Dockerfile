# syntax=docker/dockerfile:1.7
FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG GLEAM_VERSION=1.17.0
ARG GLEAM_TARGET=
ARG RUST_VERSION=1.95.0
ARG RUBY_VERSION=4.0.5
ARG GLEAM_MARMOT_REPO=git@github.com:pairshaped/marmot.git
ARG GLEAM_MARMOT_REF=
ARG RUST_MARMOT_REPO=git@github.com:pairshaped/marmot-rust.git
ARG RUST_MARMOT_REF=
ARG BENCHMARK_GIT_REV=unknown

ENV PATH="/root/.cargo/bin:/usr/local/ruby/bin:${PATH}"
ENV BUNDLE_PATH="/app/ruby/vendor/bundle"
ENV BUNDLE_WITHOUT="development:test"
ENV BENCHMARK_GIT_REV="${BENCHMARK_GIT_REV}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    ca-certificates \
    curl \
    erlang-dev \
    erlang-nox \
    gcc \
    git \
    libc6-dev \
    libffi-dev \
    libgdbm-dev \
    libreadline-dev \
    libssl-dev \
    libyaml-dev \
    make \
    openssh-client \
    openssl \
    pkg-config \
    postgresql \
    postgresql-client \
    tar \
    unzip \
    xz-utils \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 \
  && chmod +x /usr/local/bin/rebar3 \
  && rebar3 --version

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --profile minimal --default-toolchain "${RUST_VERSION}"

RUN case "${GLEAM_TARGET:-}" in \
    "") \
      case "${TARGETARCH}" in \
        amd64) gleam_target="x86_64-unknown-linux-musl" ;; \
        arm64) gleam_target="aarch64-unknown-linux-musl" ;; \
        *) echo "Unsupported Docker architecture: ${TARGETARCH}" >&2; exit 1 ;; \
      esac ;; \
    *) gleam_target="${GLEAM_TARGET}" ;; \
  esac \
  && curl -fsSL \
    "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-${gleam_target}.tar.gz" \
    -o /tmp/gleam.tar.gz \
  && tar -xzf /tmp/gleam.tar.gz -C /usr/local/bin gleam \
  && rm /tmp/gleam.tar.gz

RUN git clone --depth 1 https://github.com/rbenv/ruby-build.git /tmp/ruby-build \
  && PREFIX=/usr/local /tmp/ruby-build/install.sh \
  && ruby-build "${RUBY_VERSION}" /usr/local/ruby \
  && rm -rf /tmp/ruby-build \
  && gem install bundler

RUN mkdir -p /root/.ssh \
  && ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN --mount=type=ssh \
  git clone --depth 1 "${GLEAM_MARMOT_REPO}" /marmot \
  && if [ -n "${GLEAM_MARMOT_REF}" ]; then \
    cd /marmot && git fetch --depth 1 origin "${GLEAM_MARMOT_REF}" && git checkout FETCH_HEAD; \
  fi \
  && git clone --depth 1 "${RUST_MARMOT_REPO}" /marmot-rust \
  && if [ -n "${RUST_MARMOT_REF}" ]; then \
    cd /marmot-rust && git fetch --depth 1 origin "${RUST_MARMOT_REF}" && git checkout FETCH_HEAD; \
  fi

WORKDIR /app
COPY gleam ./gleam
COPY rust ./rust
COPY ruby ./ruby

RUN cd gleam \
  && gleam deps download

RUN cd gleam \
  && gleam run 1 >/tmp/gleam_seed_for_marmot.txt \
  && gleam run -m marmot \
  && gleam build

RUN cd rust \
  && cargo build --release \
  && ./target/release/sqlite_tests_rust 1 >/tmp/rust_seed_for_marmot.txt \
  && cd /marmot-rust \
  && cargo run --release -- generate \
    --database /app/rust/rust_benchmark.sqlite3 \
    --source-root /app/rust/src \
    --output /app/rust/src/generated/sql \
  && cd /app/rust \
  && cargo build --release

RUN cd ruby \
  && bundle install

COPY scripts ./scripts
COPY README.md REPORT.md ./

ENTRYPOINT ["./scripts/run_all.sh"]
CMD ["10000"]
