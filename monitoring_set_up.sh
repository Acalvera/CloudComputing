#!/bin/sh
# ----------------------------------------------------------------------------------
# File: monitoring_set_up.sh
# Author: Alejandro Calvera Tonin
# Date: May 2025
# Description: Script to automatically set up monitoring tools on a fresh instance
# ----------------------------------------------------------------------------------

# Install Docker
sudo apt update
sudo apt install -y docker.io docker-compose

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Installation of grafana + prometheus to monitor the resources of the server
# Create a directory to save the set up configuration
mkdir /grafana-monitoring && cd /grafana-monitoring

# Create and add the following configuration to "docker-compose.yml"
echo "version: '3'

services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: always

  node-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
    restart: always

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    restart: always
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
" >docker-compose.yml

# Create and add the following configuration to "prometheus.yml"
echo "global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
" >prometheus.yml

# Start the docker container
sudo docker-compose up -d

#Installation of portainer to manage the installed docker containers on the server
# Create a directory to save the set up configuration
mkdir /portainer-docker-management && cd /portainer-docker-management

# Create and add the following configuration to "docker-compose.yml"
echo "version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data:
" >docker-compose.yml

# Start the docker container
sudo docker-compose up -d
