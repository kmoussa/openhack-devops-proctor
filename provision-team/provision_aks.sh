#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: provision_aks.sh -i <subscriptionId> -g <resourceGroupName> -c <clusterName> -l <resourceGroupLocation>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName=""
declare clusterName=""
declare resourceGroupLocation=""

# Initialize parameters specified from command line
while getopts ":i:g:c:l:" arg; do
    case "${arg}" in
        i)
            subscriptionId=${OPTARG}
        ;;
        g)
            resourceGroupName=${OPTARG}
        ;;
        c)
            clusterName=${OPTARG}
        ;;
        l)
            resourceGroupLocation=${OPTARG}
        ;;
    esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
    echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
    echo "Enter your subscription ID:"
    read subscriptionId
    [[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
    echo "This script will look for an existing resource group, otherwise a new one will be created "
    echo "You can create new resource groups with the CLI using: az group create "
    echo "Enter a resource group name"
    read resourceGroupName
    [[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$clusterName" ]]; then
    echo "Enter a name for the Azure AKS Cluster you want to create:"
    read clusterName
fi

if [[ -z "$resourceGroupLocation" ]]; then
    echo "If creating a *new* resource group, you need to set a location "
    echo "You can lookup locations with the CLI using: az account list-locations "

    echo "Enter resource group location:"
    read resourceGroupLocation
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$clusterName" ]; then
    echo "Either one of subscriptionId, resourceGroupName, clusterName is empty"
    usage
fi

if [ -f "~/.azure/aksServicePrincipal.json" ]; then
    NOW=$(date +"%Y%m%d-%H%M")
    mv ~/.azure/aksServicePrincipal.json ~/.azure/aksServicePrincipal_$NOW.json
    echo "renamed existing local AKS Service Principal to ~/.azure/aksServicePrincipal_"$NOW".json"
fi

echo "Creating AKS Cluster..."
(
    set -x
    az aks create -g $resourceGroupName -n $clusterName -l $resourceGroupLocation --enable-rbac --node-count 3 --generate-ssh-keys -k 1.9.9
)

if [ $? == 0 ];
then
    echo "Cluster AKS:" $clusterName "created successfully..."
fi

if [ $? == 0 ];
then
    echo "kubernetes CLI for AKS:" $clusterName "installed successfully..."
fi

echo "Getting Credentials for AKS cluster..."
(
    set -x
    az aks get-credentials --resource-group=$resourceGroupName --name=$clusterName
)

if [ $? == 0 ];
then
    echo "Credentials for AKS: "$clusterName" retrieved successfully..."
fi
