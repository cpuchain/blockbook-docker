# blockbook-docker

Docker container for [blockbook](https://github.com/trezor/blockbook) with all supported coins, from a single docker image.

### Building images

Pull `cpuchain/blockbook-docker:latest` from dockerhub or build it locally

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