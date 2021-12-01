# Bitbucket pipeline example
The example below shows how to use the Bitbucket pipe in your bitbucket-pipelines.yml.

```yaml
script:
  - pipe: docker://programic/pipe-deploy-swarm:latest
    variables:
      PROJECT_NAME: "my-repository-sub" # Custom value for monorepo or $BITBUCKET_REPO_SLUG
      DOCKER_SWARM_HOST: $DOCKER_SWARM_HOST # E.g. ssh://user@server
      DOCKER_REGISTRY_URL: $DOCKER_REGISTRY_URL # E.g. XXXXXXXXX.dkr.ecr.eu-central-1.amazonaws.com
      AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
      AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION
```

# Implementation example
The Docker images are built from the docker-compose.yml file. Below is an example of what this file might look like, 
to automatically build and deploy Docker images based on your Bitbucklet pipeline.

```yaml
version: '3.8'
services:

  php:
    image: ${PROJECT_NAME}-php:${PROJECT_ENVIRONMENT}
    build:
      context: .
      dockerfile: ./dockerfiles/php.dockerfile
    secrets:
      - source: laravel-env
        target: /var/www/.env

secrets:
  laravel-env:
    file: .laravel.env
    # Make the secret unique so that stack deploy doesn't fail
    name: ${COMPOSE_PROJECT_NAME}_laravel-env-${TIMESTAMP}
```