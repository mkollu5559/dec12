#!/usr/bin/env bash
set -e

########################################
# REQUIRED CI VARIABLES 
########################################
: "${ENV_CONTEXT:?missing ENV_CONTEXT (dev|prod)}"
: "${TERRAFORM_ACTION:?missing TERRAFORM_ACTION (plan|appl)}"
: "${CUSTOMER_CODE:?missing CUSTOMER_CODE}"
: "${REGION:?missing REGION (east|west)}"

########################################
# PROXY
########################################
no_proxy=""
export http_proxy="${http_proxy}"
export https_proxy="${http_proxy}"
export HTTP_PROXY="${http_proxy}"
export HTTPS_PROXY="${http_proxy}"
export no_proxy="${no_proxy}"
export NO_PROXY="${no_proxy}"

echo "no_proxy: ${no_proxy}"
echo "http_proxy: ${http_proxy}"

########################################
# PIPELINE SERVICE URL (REQUIRED)
########################################
matter_set_up () {
  if [ "${ENV_CONTEXT}" = "prod" ]; then
    export PIPELINE_SERVICE_URL="h"
  else
    export PIPELINE_SERVICE_URL="http"
  fi
}
matter_set_up
env | grep PIPELINE_SERVICE_URL

########################################
# TERRAFORM INIT (UNCHANGED + REGION SAFE)
########################################
tf_init () {
  cd terraform
  rm -rf .terraform

  echo "CUSTOMER_CODE: ${CUSTOMER_CODE}"
  echo "ENV_CONTEXT: ${ENV_CONTEXT}"
  echo "REGION: ${REGION}"

  terraform init \
    -app "cfs-${CUSTOMER_CODE}-lz-def" \
    -context "cfs-base01-gov.${CUSTOMER_CODE}.${ENV_CONTEXT}.${REGION}" \
    -backend-config="environments/${ENV_CONTEXT}/${REGION}/backend.tf"
}

########################################
# TERRAFORM ACTION (UNCHANGED)
########################################
tf_action () {
  if [ "${TERRAFORM_ACTION}" = "plan" ]; then
    terraform plan \
      -var-file="environments/${ENV_CONTEXT}/${REGION}.tfvars" -n -k
  elif [ "${TERRAFORM_ACTION}" = "apply" ]; then
    terraform apply \
      -var-file="environments/${ENV_CONTEXT}/${REGION}.tfvars" -n -k
  elif [ "${TERRAFORM_ACTION}" = "destroy" ]; then
    terraform destroy \
      -var-file="environments/${ENV_CONTEXT}/${REGION}.tfvars"
  else
    exit 1
  fi
}

########################################
# RUN
########################################
tf_init
tf_action
