#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

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

# Now prefix project name with Docker registry url, so we can push the images to the registry from the docker-compose.yml file.
export PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}"

# Default compose file
compose_files=(docker-compose.yml)

get_compose_files() {
  if [[ -f "docker-compose.swarm.yml" ]]; then
    compose_files+=(docker-compose.swarm.yml)
  fi
}

build_push() {
  aws ecr get-login-password | docker login --username AWS --password-stdin ${DOCKER_REGISTRY_URL}

  docker-compose ${compose_files[@]/#/-f } build
  success "Successfully built"

  docker-compose ${compose_files[@]/#/-f } push
  success "Successfully pushed to registry"
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
  DOCKER_HOST=${DOCKER_SWARM_HOST}

  docker stack deploy --with-registry-auth --prune \
    ${compose_files[@]/#/--compose-file } \
    ${COMPOSE_PROJECT_NAME}

  success "Cheers! Successfully deployed"
}

get_compose_files
build_push
setup_ssh
deploy