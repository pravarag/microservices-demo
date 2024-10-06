#!/bin/bash

set -o errexit
set -o pipefail


export TF_CONF_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cd ../../terraform-modules/tf-create-eks-cluster

# execute terraform

echo "Executing terraform scripts to create demo cluster..."
terraform init
terraform plan
terraform apply --auto-approve

echo "Setting up kubeconfig with the latest cluster values....."
aws eks --region us-east-1 update-kubeconfig --name demo

echo "Get latest context"
kubectl config current-context

kubectl cluster-info
kubectl get nodes

echo "Setting for prometheus..."
createIRSA-AMPIngest.sh
createIRSA-AMPQuery.sh

kubectl create ns prometheus-monitoring
echo "Now okay to deploy prometheus helm chart"
