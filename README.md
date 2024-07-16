# testnet-scripts

A set of Bash scripts that will let you quickly register a stake address, a stake pool, update pool info and register a DRep. These scripts are meant to be used on testnets only.

## Prerequisites

The scripts assume the following locations:
- Stake, payment and pool keys: `~/(prime|preprod|preview|sanchonet|vector)/`
- Node config files: `/etc/(apex|cardano)/(prime|preprod|preview|sanchonet|vector)/[keys]`
- Node socket path: `/var/lib/(apex|cardano)/(prime|preprod|preview|sanchonet|vector)/node.socket`

Ensure the `poolMetadata(Prime|Preprod|Preview|Sanchonet|Vector).json` and `poolMetadataHash(Prime|Preprod|Preview|Sanchonet|Vector).txt` files are present before running the scripts. There is no error checking in the scripts so commands will ungracefully fail if any file is missing or a location is incorrect.

## Usage
Before running a script, open it in your favorite editor and adjust the configaration variables to your liking.

Files needed by the scripts will be taken from `~/(prime|preprod|preview|sanchonet|vector)/`. Files generated will be put in `~/(prime|preprod|preview|sanchonet|vector)/`.

The scripts take two parameters: 1) network and 2) era. Examples: `reg-pool.sh sanchonet conway` or `reg-pool.sh prime babbage`.