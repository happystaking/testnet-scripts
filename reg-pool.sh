#!/bin/bash

# Function to check for errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "An error occurred: $1"
        read -p "Do you want to continue despite the error? (y/n): " continue_script
        if [ "$continue_script" != "y" ]; then
            echo "Exiting..."
            exit 1
        fi
    fi
}

# Function for logging and prompting
log_and_prompt() {
    echo " "
    echo "$1"
    read -p "Press any key to continue..."
    echo "*****************************************"

network=${1:-sanchonet}
era=${2:-conway}

binCardanoCli="cardano-cli-8.24.0.0"
poolPledge=100000000
poolCost=170000000
poolMargin=0.01
poolRelayIp="${network}.happystaking.io"
poolRelayPort=3001
metadataUrl="https://happystaking.io/poolMetadata${network^}.json"

if   [ "$network" == "preprod" ]; then magic=1 bc=cardano;
elif [ "$network" == "preview" ]; then magic=2 bc=cardano;
elif [ "$network" == "sanchonet" ]; then magic=4 bc=cardano;
elif [ "$network" == "prime" ]; then magic=3311 bc=apex;
elif [ "$network" == "vector" ]; then magic=1177 bc=apex;
else echo "Invalid network"; exit; fi

echo "#####################"
echo " "
echo "Network: $network"
echo "Era: $era"
echo "Magic: $magic"
echo "Blockchain: $bc"
echo " "
echo "#####################"

mkdir -p ~/${network}
echo "Ensure ~/${network} contains payment_${network}.skey, stake_${network}.skey and cold.skey."
read -p "This will overwrite existing keys! Press Ctrl+C to cancel..."

$binCardanoCli $era node key-gen \
    --cold-verification-key-file ~/${network}/cold.vkey \
    --cold-signing-key-file ~/${network}/cold.skey \
    --operational-certificate-issue-counter-file ~/${network}/opcert.counter

log_and_prompt "Generating node cold vkey & skeys"
$binCardanoCli $era node key-gen-KES \
    --verification-key-file ~/${network}/kes.vkey \
    --signing-key-file ~/${network}/kes.skey
check_error "Failed to generate cold keys."    

log_and_prompt "Generating node KES vkey & skeys"
$binCardanoCli $era node key-gen-VRF \
    --verification-key-file ~/${network}/vrf.vkey \
    --signing-key-file ~/${network}/vrf.skey
check_error "Failed to generate KES keys."

log_and_prompt "Generating Pool metadata hash file"
$binCardanoCli $era stake-pool metadata-hash \
    --pool-metadata-file ~/${network}/poolMetadata${network^}.json \
    --out-file ~/${network}/poolMetadataHash${network^}.txt
check_error "Failed to generate metadata hash."

log_and_prompt "Creating stake-pool registration-certificate"
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
check_error "Failed to create pool registration certificate."

log_and_prompt "Creating stake-pool delegation-certificate"
$binCardanoCli $era stake-address stake-delegation-certificate \
    --stake-verification-key-file ~/${network}/stake_${network}.vkey \
    --cold-verification-key-file ~/${network}/cold.vkey \
    --out-file ~/${network}/delegation.cert
check_error "Failed to create delegation certificate."

paymentAddr=$(cat ~/${network}/payment_${network}.addr)
echo "Payment address: $paymentAddr"

utxos=$(sudo -E $binCardanoCli query utxo  --socket-path /var/lib/${bc}/${network}/node.socket --address ${paymentAddr} --testnet-magic ${magic} --out-file  /dev/stdout | jq -r 'keys[0]')
check_error "Failed to query UTXOs."

log_and_prompt "Building transaction"
sudo -E $binCardanoCli $era transaction build \
    --testnet-magic ${magic} \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --witness-override 3 \
    --tx-in ${utxos} \
    --change-address $(cat ~/${network}/payment_${network}.addr) \
    --certificate-file ~/${network}/pool-registration.cert \
    --certificate-file ~/${network}/delegation.cert \
    --out-file ~/${network}/tx.raw
check_error "Failed to build transaction."

log_and_prompt "Signing transaction"
sudo -E $binCardanoCli $era transaction sign \
    --tx-body-file ~/${network}/tx.raw \
    --signing-key-file ~/${network}/payment_${network}.skey \
    --signing-key-file ~/${network}/cold.skey \
    --signing-key-file ~/${network}/stake_${network}.skey \
    --testnet-magic ${magic} \
    --out-file ~/${network}/tx.signed
check_error "Failed to sign transaction."

log_and_prompt "Submitting transaction"
sudo -E $binCardanoCli $era transaction submit \
    --testnet-magic ${magic} \
    --socket-path /var/lib/${bc}/${network}/node.socket \
    --tx-file ~/${network}/tx.signed
sudo rm ~/${network}/tx.{raw,signed}
check_error "Failed to submit transaction."

log_and_prompt "Generating stake-pool ID Bech32 format"
sudo -E $binCardanoCli $era stake-pool id \
    --cold-verification-key-file ~/${network}/cold.vkey \
    --output-format bech32 \
    --out-file ~/${network}/stakepool.${network}.bech32
check_error "Failed to get stake pool id in bech32 format."
echo "Bech32: `sudo cat stakepool.${network}.bech32`"

log_and_prompt "Generating stake-pool ID HEX format"
sudo -E $binCardanoCli $era stake-pool id \
    --cold-verification-key-file ~/${network}/cold.vkey \
    --output-format hex \
    --out-file ~/${network}/stakepool.${network}.hex
check_error "Failed to get kesPeriod."    
echo "Hex: `sudo cat stakepool.${network}.hex`"

sudo chown `whoami`: ~/${network}/stakepool.${network}.bech32
sudo chown `whoami`: ~/${network}/stakepool.${network}.hex

log_and_prompt "Checking kesPeriod info"
slotsPerKESPeriod=$(cat /etc/${bc}/${network}/shelley-genesis.json | jq -r '.slotsPerKESPeriod')
slotNo=$(sudo -E $binCardanoCli query tip  --socket-path /var/lib/${bc}/${network}/node.socket --testnet-magic ${magic} | jq -r '.slot')
kesPeriod=$((${slotNo} / ${slotsPerKESPeriod}))
check_error "Failed to get kesPeriod."
echo "kesPeriod: $kesPeriod"

log_and_prompt "Issueing node-op-cert"
$binCardanoCli $era node issue-op-cert \
    --kes-verification-key-file ~/${network}/kes.vkey \
    --cold-signing-key-file ~/${network}/cold.skey \
    --operational-certificate-issue-counter-file ~/${network}/opcert.counter \
    --kes-period ${kesPeriod} \
    --out-file ~/${network}/node.cert
check_error "Failed to issue node operational certificate."
echo "Node certificate issued."

sudo mkdir -p /etc/cardano/${network}/keys
sudo cp ~/${network}/{vrf,kes}.skey /etc/cardano/${network}/keys/
sudo cp ~/${network}/node.cert /etc/cardano/${network}/keys/
sudo chown -R cardano:root /etc/cardano/${network}/keys
sudo chmod 0600 /etc/cardano/${network}/keys/*

echo "Stake pool created and keys copied."
echo "Restart the node in block producer mode and get delegation from the faucet."
