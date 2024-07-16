#!/bin/bash

network=${1:-sanchonet}
era=${2:-conway}

binCardanoCli="cardano-cli-8.24.0.0"

if   [ "$network" == "preprod" ]; then magic=1 bc=cardano;
elif [ "$network" == "preview" ]; then magic=2 bc=cardano;
elif [ "$network" == "sanchonet" ]; then magic=4 bc=cardano;
elif [ "$network" == "prime" ]; then magic=3311 bc=apex;
elif [ "$network" == "vector" ]; then magic=1177 bc=apex;
else echo "Invalid network"; exit; fi

mkdir -p ~/${network}
echo "Ensure ~/${network} contains payment_${network}.skey."
read -p "This will overwrite existing keys! Press Ctrl+C to cancel..."

$binCardanoCli $era governance drep key-gen \
    --verification-key-file ~/${network}/drep.vkey \
    --signing-key-file ~/${network}/drep.skey

$binCardanoCli $era governance drep id \
    --drep-verification-key-file ~/${network}/drep.vkey \
    --out-file ~/${network}/drep.id
echo "DRep id: `cat ~/${network}/drep.id`"

$binCardanoCli $era governance drep registration-certificate \
    --drep-verification-key-file ~/${network}/drep.vkey \
    --key-reg-deposit-amt 500000000 \
    --out-file ~/${network}/drep-register.cert

paymentAddr=$(cat ~/${network}/payment_${network}.addr)
utxos=$(sudo -E $binCardanoCli query utxo --address ${paymentAddr} --testnet-magic ${magic} --socket-path /var/lib/${bc}/${network}/node.socket --out-file  /dev/stdout | jq -r 'keys[0]')
sudo -E $binCardanoCli $era transaction build \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --testnet-magic ${magic} \
    --witness-override 2 \
    --tx-in ${utxos} \
    --change-address $(cat ~/${network}/payment_${network}.addr) \
    --certificate-file ~/${network}/drep-register.cert \
    --out-file ~/${network}/tx.raw

sudo -E $binCardanoCli $era transaction sign \
    --tx-body-file ~/${network}/tx.raw \
    --signing-key-file ~/${network}/payment_${network}.skey \
    --signing-key-file ~/${network}/drep.skey \
    --testnet-magic ${magic} \
    --out-file ~/${network}/tx.signed

sudo -E $binCardanoCli $era transaction submit \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --testnet-magic ${magic} \
    --tx-file ~/${network}/tx.signed
echo "DRep registered."
sudo rm ~/${network}/tx.{raw,signed}
