#!/bin/bash

PROM_NAMESPACE="prometheus-monitoring"
EKS_CLUSTER_NAME="demo"


echo "Creating prometheus namespace..."
kubectl create ns ${PROM_NAMESPACE}

echo "Set up service roles for ingestion of metrics..."
pwd
./createIRSA-AMPIngest.sh
./createIRSA-AMPQuery.sh


echo "Setting up ebs for prometheus"
export EBS_CSI_POLICY_NAME="AmazonEBSCSIPolicy"
aws iam create-policy \
--region "us-east-1" \
--policy-name $EBS_CSI_POLICY_NAME \
--policy-document file://ebs-csi-policy.json
export EBS_CSI_POLICY_ARN=$(aws --region us-east-1 iam list-policies --query 'Policies[?PolicyName==`'$EBS_CSI_POLICY_NAME'`].Arn' --output text)
echo $EBS_CSI_POLICY_ARN

eksctl create iamserviceaccount \
  --cluster $EKS_CLUSTER_NAME \
  --name ebs-csi-controller-irsa \
  --namespace kube-system \
  --attach-policy-arn $EBS_CSI_POLICY_ARN \
  --override-existing-serviceaccounts --approve

helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

helm upgrade --install aws-ebs-csi-driver \
  --version=1.2.4 \
  --namespace kube-system \
  --set serviceAccount.controller.create=false \
  --set serviceAccount.snapshot.create=false \
  --set enableVolumeScheduling=true \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true \
  --set serviceAccount.snapshot.name=ebs-csi-controller-irsa \
  --set serviceAccount.controller.name=ebs-csi-controller-irsa \
  aws-ebs-csi-driver/aws-ebs-csi-driver


helm install prometheus-demo prometheus-community/prometheus -n ${PROM_NAMESPACE} -f /home/pravarag/work/git-clones/microservices-demo/aws-prometheus/my_prometheus_values.yaml \
     --set alertmanager.persistentvolume.storageClass="gp2",server.persistentvolume.storageClass="gp2"


# Below part is optional to configure grafana

# kubectl create ns grafana
# helm repo add grafana https://grafana.github.io/helm-charts

# helm install grafana grafana/grafana \
#     --namespace grafana \
#     --set persistence.storageClass="gp2" \
#     --set persistence.enabled=true \
#     --set adminPassword='YOUR_PASSWORD' \
#     --values grafana.yaml \
#     --set service.type=NodePort


