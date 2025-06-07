FROM ubuntu:noble AS blockbook-build

RUN apt-get update \
  && apt-get install -y \
    software-properties-common \
    ca-certificates \
    build-essential \
    libtool \
    git \
    pkg-config \
    autoconf \
    curl \
    librocksdb-dev \
    libzmq3-dev \
    libgflags-dev \
    libsnappy-dev \
    zlib1g-dev \
    libbz2-dev \
    libzstd-dev \
    liblz4-dev

RUN add-apt-repository -y ppa:longsleep/golang-backports && \
  apt-get install -y golang-go

# Build ZeroMQ 4.3.5
ENV ZEROMQ_COMMIT=622fc6dde99ee172ebaa9c8628d85a7a1995a21d
RUN mkdir /libzmq
WORKDIR /libzmq

RUN git init && \
  git remote add origin https://github.com/zeromq/libzmq.git && \
  git fetch --depth 1 origin $ZEROMQ_COMMIT && \
  git checkout $ZEROMQ_COMMIT

RUN ./autogen.sh && \
  ./configure --enable-static --disable-shared --without-documentation && \
  make -j$(nproc)

# Build RocksDB 10.2.1
ENV ROCKSDB_COMMIT=4b2122578e475cb88aef4dcf152cccd5dbf51060
RUN mkdir /rocksdb
WORKDIR /rocksdb

RUN git init && \
  git remote add origin https://github.com/facebook/rocksdb.git && \
  git fetch --depth 1 origin $ROCKSDB_COMMIT && \
  git checkout $ROCKSDB_COMMIT

RUN PORTABLE=1 CFLAGS=-fPIC CXXFLAGS=-fPIC make -j $(nproc --all) static_lib

# Clone Blockbook
ENV BLOCKBOOK_VERSION=0.5.0
ENV BLOCKBOOK_COMMIT=de7aabb60b02814fef1e6aa0594a37386edb7d45
RUN mkdir /blockbook
WORKDIR /blockbook

RUN git init && \
  git remote add origin https://github.com/cpuchain/blockbook.git && \
  git fetch --depth 1 origin $BLOCKBOOK_COMMIT && \
  git checkout $BLOCKBOOK_COMMIT

# Update Go Deps
RUN go get -u -v github.com/linxGnu/grocksdb@latest && \
  go get -u -v github.com/pebbe/zmq4@v1.2.11 && \
  go mod tidy

# Build Blockbook
RUN LDFLAGS="-X github.com/trezor/blockbook/common.version=${BLOCKBOOK_VERSION} \
             -X github.com/trezor/blockbook/common.gitcommit=$(git describe --always) \
             -X github.com/trezor/blockbook/common.buildtime=$(date --iso-8601=seconds)" && \
  CGO_CFLAGS="-I/libzmq/include -I/rocksdb/include -I/usr/include" \
  CGO_LDFLAGS="-L/libzmq/src/.libs -L/rocksdb -L/usr/lib -L/usr/lib/x86_64-linux-gnu -Wl,--no-as-needed -lzmq -lpthread -lrocksdb -lstdc++ -lm -lc -lgcc -lz -ldl -lbz2 -lsnappy -llz4 -lzstd" \
  go build -v -ldflags="-s -w ${LDFLAGS} -extldflags '-static'" -o blockbook blockbook.go && \
  go build -v -o blockbookgen build/templates/generate.go && \
  tar -czvf blockbook.tar.gz blockbook blockbookgen static configs build

# The blockbook runtime image with only the executable and necessary libraries
FROM ubuntu:noble AS blockbook

COPY --from=blockbook-build /blockbook/blockbook.tar.gz /blockbook/blockbook.tar.gz

WORKDIR /blockbook

RUN tar -xzvf blockbook.tar.gz && \
  ln -s /blockbook/blockbook /usr/local/bin/blockbook && \
  ln -s /blockbook/blockbookgen /usr/local/bin/blockbookgen

RUN printf '#!/bin/sh\nexec ./blockbook "$@"' >> entrypoint.sh && \
  printf '#!/bin/sh\n./blockbookgen "$@"\nexec cat build/pkg-defs/blockbook/blockchaincfg.json' >> generate.sh && \
  chmod u+x entrypoint.sh && \
  chmod u+x generate.sh

ENTRYPOINT [ "./entrypoint.sh" ]
