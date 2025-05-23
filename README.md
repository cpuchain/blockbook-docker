# blockbook-docker

Prebuilt Binaries / Docker container for [blockbook](https://github.com/trezor/blockbook) with all supported coins, from a single docker image.

### Prebuilt Binaries ( by Github Actions )

Comes with Ubuntu AMD64 / Windows x64 binaries, you can checkout the [release page](https://github.com/cpuchain/blockbook-docker/releases/tag/v0.5.0)

( It is recommended to fork this repository and try building yourself using Github Actions for extra security though )

### Building images

Pull `ghcr.io/cpuchain/blockbook-docker:latest` from Github or build it locally

```bash
docker build -t blockbook .
```

### Testing binary

```bash
docker run --rm -it blockbook --help
```

### Generating config

```bash
docker run --rm -it --entrypoint ./generate.sh blockbook bitcoin_regtest
```

### Running example

Refer docker-compose.yml for basic config and command line flags necessary to run blockbook
