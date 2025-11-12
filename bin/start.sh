#!/bin/bash

set -e

echo "Starting the application..."
echo "Environment: ${ENV:-development}"

# Add your application startup commands here

# Run the docker compose file
docker-compose build --no-cache && docker-compose up -d

mix phx.server

echo "Application started successfully!" 