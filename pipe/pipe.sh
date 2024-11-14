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
export DOCKER_BUILDKIT=0

build_push() {
  info "Login..."
  aws ecr get-login-password | docker login --username AWS --password-stdin ${DOCKER_REGISTRY_URL}

  # Now prefix project name with Docker registry url, so we can build and push the images to the registry from the docker-compose.yml file.
  info "Building..."
  PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}" \
    docker-compose build
  success "Successfully built"

  info "Push..."
  PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}" \
    docker-compose push
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
  info "Deploy..."
  PROJECT_NAME="${DOCKER_REGISTRY_URL}/${PROJECT_NAME}" \
    DOCKER_HOST=${DOCKER_SWARM_HOST} \
      docker stack deploy --with-registry-auth --prune \
        --compose-file docker-compose.yml \
        --compose-file docker-compose.stack.yml \
        ${COMPOSE_PROJECT_NAME}

  success "Cheers! Successfully deployed"
}

create_sentry_release() {
  if [[ -z "${SENTRY_RELEASE}" ]] || [[ -z "${SENTRY_ORG}" ]] || [[ -z "${SENTRY_AUTH_TOKEN}" ]]; then
    return
  fi

  info "Create Sentry release..."

  sentry-cli releases new --finalize --project "${PROJECT_NAME}" "${SENTRY_RELEASE}"
  success "Created new Sentry release"

  sentry-cli releases set-commits --ignore-empty --ignore-missing --auto "${SENTRY_RELEASE}"
  success "Associate commits with the release"
}

set_firewall() {
  if [[ -z "${DIGITALOCEAN_ACCESS_TOKEN}" ]] || [[ -z "${DIGITALOCEAN_FIREWALL_ID}" ]]; then
    return
  fi

  info "Set firewall rule..."

  export PUBLIC_IP=$(curl --silent "https://api.ipify.org")
  doctl compute firewall add-rules ${DIGITALOCEAN_FIREWALL_ID} --inbound-rules protocol:tcp,ports:22,address:${PUBLIC_IP} --access-token ${DIGITALOCEAN_ACCESS_TOKEN}
  success "IP ${PUBLIC_IP} whitelisted"
}

remove_firewall() {
  if [[ -z "${DIGITALOCEAN_ACCESS_TOKEN}" ]] || [[ -z "${PUBLIC_IP}" ]] || [[ -z "${DIGITALOCEAN_FIREWALL_ID}" ]]; then
    return
  fi

  info "Remove firewall rule..."

  doctl compute firewall remove-rules ${DIGITALOCEAN_FIREWALL_ID} --inbound-rules protocol:tcp,ports:22,address:${PUBLIC_IP} --access-token ${DIGITALOCEAN_ACCESS_TOKEN}
  success "IP ${PUBLIC_IP} removed"
}

build_push
setup_ssh
set_firewall
deploy
remove_firewall
create_sentry_release
