#!/bin/bash

set -e

if [ -z "$KUBECONFIG" ]; then
    kci="kubectl --insecure-skip-tls-verify"
    kubectl="kubectl"
else
    kci="kubectl --kubeconfig=${KUBECONFIG} --insecure-skip-tls-verify"
    kubectl="kubectl --kubeconfig=${KUBECONFIG}"
fi

USER="$1"
OU="$2"
ROLE="$3"


if [ -z "$USER" ]; then
    echo -e "\e[33;1mUSAGE: $0 <your_username> <certificate_OU> <assume_role>\e[0m"
    exit 1
fi

if [ -z "$ROLE" ]; then
    ROLE="cluster-admin"
fi

if [ -z "$OU" ]; then
    OU="IT Department"
fi

CLUSTER=$(${kci} config view -o jsonpath='{.clusters[0].name}')
SERVER=$(${kci} config view -o jsonpath='{.clusters[0].cluster.server}')
CSR_TEMPLATE=$(cat ./k8s-csr-template.yaml)


echo -e "\e[1;32mGenerating your key and CSR...\e[0m"
openssl req -new -newkey rsa:4096 -nodes -keyout ./"${USER}.key" -out ./"${USER}.csr" -subj "/CN=$USER/O=$OU"

echo "$(echo "$CSR_TEMPLATE" | sed s/USER/${USER}/g | sed s/REQUEST/$(cat ./${USER}.csr | base64 | tr -d '\n')/g)" > ./"${USER}-k8s-csr.yaml"

echo -e "\e[1;32mRequesting certificate...\e[0m"
${kci} apply -f ./"${USER}-k8s-csr.yaml"

${kci} certificate approve "${USER}-k8s-access"

${kci} get csr "${USER}-k8s-access" -o jsonpath='{.status.certificate}' | base64 --decode > ./"${USER}-k8s-access.crt"

${kci} config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode - > ./k8s-ca.crt

echo -e "\e[1;32mGenerating kubectl config...\e[0m"
${kubectl} config set-cluster "${CLUSTER}" --server="${SERVER}" --certificate-authority=./k8s-ca.crt --kubeconfig=./"${USER}-k8s-config" --embed-certs
${kci} config set-credentials "${USER}" --client-certificate=./"${USER}-k8s-access.crt" --client-key=./"${USER}.key" --embed-certs --kubeconfig=./"${USER}-k8s-config"
${kci} config set-context "${USER}@${CLUSTER}" --cluster="${CLUSTER}" --user="${USER}" --kubeconfig="${USER}-k8s-config"
${kci} config use-context "${USER}@${CLUSTER}" --kubeconfig="${USER}-k8s-config"

$kci get clusterrolebinding "${USER}-${ROLE}" 1>/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "\e[1;32mCreating cluster rolebinding...\e[0m"
    ${kci} create clusterrolebinding "${USER}-${ROLE}" --clusterrole="${ROLE}" --user="${USER}"
fi

echo -e "\e[1;32mCleaning up...\e[0m"

${kci} delete csr "${USER}-k8s-access"

rm ./"${USER}.csr"
rm ./"${USER}.key"
rm ./"${USER}-k8s-access.crt"
rm ./"${USER}-k8s-csr.yaml"

echo -e "\e[1;32mYour config \"${USER}-k8s-config\" is ready. Now download it to your machine and put it to ~/.kube/config. \e[31mDO NOT FORGET TO DELETE IT FROM THE CURRENT DIRECTORY AFTERWARDS!\e[0m"
