#!/usr/bin/env bash

docker login
docker build --platform linux/amd64 -t programic/pipe-deploy-swarm:latest .
docker push programic/pipe-deploy-swarm:latest