#!/usr/bin/env bash

set -o errexit
set -o pipefail

# Include common.sh script
source "$(dirname "${0}")/common.sh"

: ${PROJECT_NAME?"You need to set the PROJECT_NAME environment variable."}
: ${DOCKER_REGISTRY_URL?"You need to set the DOCKER_REGISTRY_URL environment variable."}
: ${DOCKER_SWARM_HOST?"You need to set the DOCKER_SWARM_HOST environment variable."}
: ${AWS_ACCESS_KEY_ID?"You need to set the AWS_ACCESS_KEY_ID environment variable."}
: ${AWS_SECRET_ACCESS_KEY?"You need to set the AWS_SECRET_ACCESS_KEY environment variable."}
: ${AWS_DEFAULT_REGION?"You need to set the AWS_DEFAULT_REGION environment variable."}
: ${BITBUCKET_DEPLOYMENT_ENVIRONMENT?"You need to set the BITBUCKET_DEPLOYMENT_ENVIRONMENT environment variable."}

# Set environment vars for build, push and deployment
export PROJECT_ENVIRONMENT=${BITBUCKET_DEPLOYMENT_ENVIRONMENT}
export COMPOSE_PROJECT_NAME="${PROJECT_NAME}_${PROJECT_ENVIRONMENT}"
export TIMESTAMP=$(date +%s)

valid_sentry_credentials() {
  if [[ -n "${SENTRY_RELEASE}" ]] && [[ -n "${SENTRY_ORG}" ]] && [[ -n "${SENTRY_AUTH_TOKEN}" ]]; then
    return 1
  fi

  return 0
}

create_sentry_release() {
  valid_sentry_credentials && return

  sentry-cli releases new -p "${PROJECT_NAME}" "${SENTRY_RELEASE}"
  success "Created new Sentry release"

  sentry-cli releases set-commits --auto "${SENTRY_RELEASE}"
  success "Associate commits with the release"
}

finalize_sentry_release() {
  valid_sentry_credentials && return

  sentry-cli releases finalize "${SENTRY_RELEASE}"
  success "Sentry release successfully finalized"
}

build_push() {
  aws ecr get-login-password | docker login --username AWS --password-stdin ${DOCKER_REGISTRY_URL}

  # Now prefix project name with Docker registry url, so we can build and push the images to the registry from the docker-compose.yml file.
  PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}" \
    docker-compose build
  success "Successfully built"

  PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}" \
    docker-compose push
  success "Successfully pushed to registry"

  create_sentry_release
}

setup_ssh() {
  injected_ssh_config_dir="/opt/atlassian/pipelines/agent/ssh"
  identity_file="${injected_ssh_config_dir}/id_rsa_tmp"
  known_hosts_file="${injected_ssh_config_dir}/known_hosts"

  if [[ ! -f ${identity_file} ]]; then
    fail "No default SSH key configured in Pipelines"
  fi

  if [[ ! -f ${known_hosts_file} ]]; then
    fail "No SSH known_hosts configured in Pipelines"
  fi

  mkdir -p ~/.ssh
  touch ~/.ssh/authorized_keys
  cp ${identity_file} ~/.ssh/pipelines_id
  cat ${known_hosts_file} >> ~/.ssh/known_hosts
  echo "IdentityFile ~/.ssh/pipelines_id" >> ~/.ssh/config
  chmod -R go-rwx ~/.ssh/

  success "SSH key has been successfully set"
}

deploy() {
  PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}" \
    DOCKER_HOST=${DOCKER_SWARM_HOST} \
      docker stack deploy --with-registry-auth --prune \
        --compose-file docker-compose.yml \
        --compose-file docker-compose.stack.yml \
        ${COMPOSE_PROJECT_NAME}

  success "Cheers! Successfully deployed"

  finalize_sentry_release
}

build_push
setup_ssh
deploy