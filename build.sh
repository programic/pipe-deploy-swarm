#!/usr/bin/env bash

docker login
docker buildx create --name docker-multiplatform --bootstrap --use
docker buildx build --push --platform linux/amd64,linux/arm64,linux/arm/v8 -t programic/pipe-deploy-swarm:latest .