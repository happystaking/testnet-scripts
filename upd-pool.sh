#!/bin/bash

network=${1:-sanchonet}
era=${2:-conway}

binCardanoCli="cardano-cli-8.24.0.0"
poolPledge=100000000
poolCost=170000000
poolMargin=0.02
poolRelayIp="${network}.happystaking.io"
poolRelayPort=3001
metadataUrl="https://happystaking.io/poolMetadata${network^}.json"

if   [ "$network" == "preprod" ]; then magic=1 bc=cardano;
elif [ "$network" == "preview" ]; then magic=2 bc=cardano;
elif [ "$network" == "sanchonet" ]; then magic=4 bc=cardano;
elif [ "$network" == "prime" ]; then magic=3311 bc=apex;
elif [ "$network" == "vector" ]; then magic=1177 bc=apex;
else echo "Invalid network"; exit; fi

mkdir -p ~/${network}
echo "Ensure ~/${network} contains payment_${network}.skey, stake_${network}.skey and cold.skey."
read -p "Press Ctrl+C to cancel..."

$binCardanoCli $era stake-pool metadata-hash \
    --pool-metadata-file ~/${network}/poolMetadata${network^}.json \
    --out-file ~/${network}/poolMetadataHash${network^}.txt

$binCardanoCli $era stake-pool registration-certificate \
    --cold-verification-key-file ~/${network}/cold.vkey \
    --vrf-verification-key-file ~/${network}/vrf.vkey \
    --pool-pledge ${poolPledge} \
    --pool-cost ${poolCost} \
    --pool-margin ${poolMargin} \
    --pool-reward-account-verification-key-file ~/${network}/stake_${network}.vkey \
    --pool-owner-stake-verification-key-file ~/${network}/stake_${network}.vkey \
    --testnet-magic ${magic} \
    --single-host-pool-relay ${poolRelayIp} \
    --pool-relay-port ${poolRelayPort} \
    --metadata-url ${metadataUrl} \
    --metadata-hash $(cat ~/${network}/poolMetadataHash${network^}.txt) \
    --out-file ~/${network}/pool-registration.cert

$binCardanoCli $era stake-address stake-delegation-certificate \
    --stake-verification-key-file ~/${network}/stake_${network}.vkey \
    --cold-verification-key-file ~/${network}/cold.vkey \
    --out-file ~/${network}/delegation.cert

paymentAddr=$(cat ~/${network}/payment_${network}.addr)
utxos=$(sudo -E $binCardanoCli query utxo --address ${paymentAddr} --testnet-magic ${magic} --socket-path /var/lib/${bc}/${network}/node.socket --out-file  /dev/stdout | jq -r 'keys[0]')
sudo -E $binCardanoCli $era transaction build \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --testnet-magic ${magic} \
    --witness-override 3 \
    --tx-in ${utxos} \
    --change-address $(cat ~/${network}/payment_${network}.addr) \
    --certificate-file ~/${network}/pool-registration.cert \
    --certificate-file ~/${network}/delegation.cert \
    --out-file ~/${network}/tx.raw

sudo -E $binCardanoCli $era transaction sign \
    --tx-body-file ~/${network}/tx.raw \
    --signing-key-file ~/${network}/payment_${network}.skey \
    --signing-key-file ~/${network}/cold.skey \
    --signing-key-file ~/${network}/stake_${network}.skey \
    --testnet-magic ${magic} \
    --out-file ~/${network}/tx.signed

sudo -E $binCardanoCli $era transaction submit \
    --testnet-magic ${magic} \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --tx-file ~/${network}/tx.signed
echo "Stakepool updated. New pool-registration.cert and delegation.cert generated."
sudo rm ~/${network}/tx.{raw,signed}
