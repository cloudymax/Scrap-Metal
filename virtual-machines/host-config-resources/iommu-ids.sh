#!/bin/bash

get_iommu_data(){
    shopt -s nullglob
    for d in /sys/kernel/iommu_groups/{0..64}/devices/*; do
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        printf 'IOMMU Group %s ' "$n"
        lspci -nns "${d##*/}"
    done;
}

# Takes a vendor name: NVIDIA/Intel/AMD etc...
# Only tested on NVIDIA hardware.
get_iommu_ids(){

    LIST=$(get_iommu_data)
    COUNT=$(echo "$LIST" |grep -c $1 )
    DEVICE_IDS=""

    for ((i=1;i<=$COUNT;i++)); do

        ID=$(echo "$LIST" |grep $1 |awk '{print $(NF-2)}' |head -$i |tail -1 |sed 's/[][]//g')

        # Regex Explanation:
        # 1. search the data for lines onctaining VENDOR_NAME
        #    echo "$LIST" |grep $1
        # 2. find the second-to-last field of the line
        #    awk '{print $(NF-2)}'
        # 3. Show only the current item in the itteration
        #    head -$i |tail -1
        # 4. cut off bracktes from the resulting value
        #    sed 's/[][]//g'

        if [[ "$i" -eq 1 ]]; then
            DEVICE_IDS="$ID"
        else
            DEVICE_IDS="$DEVICE_IDS,$ID"
        fi

    done

    echo $DEVICE_IDS
}

"$@"
