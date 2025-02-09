FROM ubuntu:noble AS blockbook-build

RUN apt-get update \
  && apt-get install -y \
    software-properties-common \
    ca-certificates \
    build-essential \
    git \
    pkg-config \
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

# 9.10.0 with build fix
#ENV ROCKSDB_COMMIT=62a7ddb39c28d313d1d83350ccdf20dcad7bb6f6

# clone rocksdb
#RUN mkdir /rocksdb

#WORKDIR /rocksdb

#RUN git init && \
#  git remote add origin https://github.com/facebook/rocksdb.git && \
#  git fetch --depth 1 origin $ROCKSDB_COMMIT && \
#  git checkout $ROCKSDB_COMMIT

# build rocksdb
#RUN CFLAGS=-fPIC CXXFLAGS=-fPIC make -j $(nproc --all) release

# latest master branch
ENV BLOCKBOOK_VERSION=0.4.0
ENV BLOCKBOOK_COMMIT=783ab61cf6b63b52e0f62b2bac2bf815a0ccbbe4

# clone blockbook
RUN mkdir /blockbook

WORKDIR /blockbook

RUN git init && \
  git remote add origin https://github.com/trezor/blockbook.git && \
  git fetch --depth 1 origin $BLOCKBOOK_COMMIT && \
  git checkout $BLOCKBOOK_COMMIT

# update deps
# go get -u -v github.com/linxGnu/grocksdb@v1.9.8
RUN go get -u -v github.com/linxGnu/grocksdb@v1.8.12

# build blockbook
#RUN CGO_CFLAGS="-I/rocksdb/include" \
#  CGO_LDFLAGS="-L/rocksdb -lrocksdb -lstdc++ -lm -lz -ldl -lbz2 -lsnappy -llz4 -lzstd" \
#  go build -v -o blockbook blockbook.go
RUN export LDFLAGS="-X github.com/trezor/blockbook/common.version=$BLOCKBOOK_VERSION -X github.com/trezor/blockbook/common.gitcommit=$(git describe --always) -X github.com/trezor/blockbook/common.buildtime=$(date --iso-8601=seconds)" && \
  go build -v -ldflags="-s -w $LDFLAGS" -o blockbook blockbook.go && \
  go build -v -o blockbookgen build/templates/generate.go

# The blockbook runtime image with only the executable and necessary libraries
FROM ubuntu:noble AS blockbook

RUN apt-get update \
  && apt-get install -y \
    curl \
    librocksdb-dev \
    libsnappy-dev \
    libzmq3-dev \
    zlib1g-dev \
    libbz2-dev \
    libzstd-dev \
    liblz4-dev

COPY --from=blockbook-build /blockbook /blockbook

WORKDIR /blockbook

RUN ln -s /blockbook/blockbook /usr/local/bin/blockbook
RUN ln -s /blockbook/blockbookgen /usr/local/bin/blockbookgen

RUN printf '#!/bin/sh\nexec ./blockbook "$@"' >> entrypoint.sh
RUN printf '#!/bin/sh\n./blockbookgen "$@"\nexec cat build/pkg-defs/blockbook/blockchaincfg.json' >> generate.sh
RUN chmod u+x entrypoint.sh
RUN chmod u+x generate.sh

ENTRYPOINT [ "./entrypoint.sh" ]