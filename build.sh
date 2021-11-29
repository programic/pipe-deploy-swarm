#!/usr/bin/env bash

docker login
docker build -t programic/pipe-deploy-swarm:latest .
docker push programic/pipe-deploy-swarm:latest