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
read -p "This will overwrite existing keys! Press Ctrl+C to cancel..."

deposit=$(sudo -E $binCardanoCli query protocol-parameters --socket-path /var/lib/${bc}/${network}/node.socket --testnet-magic ${magic} | jq -r .stakeAddressDeposit)

sudo -E $binCardanoCli query protocol-parameters --socket-path /var/lib/${bc}/${network}/node.socket --testnet-magic ${magic} > ~/${network}/params.json

$binCardanoCli $era address key-gen \
    --verification-key-file ~/${network}/payment_${network}.vkey \
    --signing-key-file ~/${network}/payment_${network}.skey

$binCardanoCli $era stake-address key-gen \
    --verification-key-file ~/${network}/stake_${network}.vkey \
    --signing-key-file ~/${network}/stake_${network}.skey

$binCardanoCli $era address build \
    --payment-verification-key-file ~/${network}/payment_${network}.vkey \
    --stake-verification-key-file ~/${network}/stake_${network}.vkey \
    --out-file ~/${network}/payment_${network}.addr \
    --testnet-magic ${magic}

echo "Payment address: `cat ~/${network}/payment_${network}.addr`"

$binCardanoCli $era stake-address build \
    --stake-verification-key-file ~/${network}/stake_${network}.vkey \
    --out-file ~/${network}/stake_${network}.addr \
    --testnet-magic ${magic}

echo "Stake address: `cat ~/${network}/stake_${network}.addr`"
read -p "Fund the payment address and press any key when done..."

$binCardanoCli $era stake-address registration-certificate \
    --stake-verification-key-file ~/${network}/stake_${network}.vkey \
    --key-reg-deposit-amt ${deposit} \
    --out-file ~/${network}/registration.cert

paymentAddr=$(cat ~/${network}/payment_${network}.addr)
utxos=$(sudo -E $binCardanoCli query utxo --address ${paymentAddr} --socket-path /var/lib/${bc}/${network}/node.socket --testnet-magic ${magic} --out-file  /dev/stdout | jq -r 'keys[0]')
sudo -E $binCardanoCli $era transaction build \
    --testnet-magic ${magic} \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --witness-override 2 \
    --tx-in ${utxos} \
    --change-address $(cat ~/${network}/payment_${network}.addr) \
    --certificate-file ~/${network}/registration.cert \
    --out-file ~/${network}/tx.raw

sudo -E $binCardanoCli $era transaction sign \
    --tx-body-file ~/${network}/tx.raw \
    --signing-key-file ~/${network}/payment_${network}.skey \
    --signing-key-file ~/${network}/stake_${network}.skey \
    --testnet-magic ${magic} \
    --out-file ~/${network}/tx.signed

sudo -E $binCardanoCli $era transaction submit \
    --testnet-magic ${magic} \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --tx-file ~/${network}/tx.signed

sudo rm ~/${network}/tx.{raw,signed}
echo "Stake address registered."
