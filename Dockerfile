# Use Elixir base image
FROM elixir:1.15-alpine

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    postgresql-client \
    inotify-tools

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Note: We don't copy files or compile here because
# docker-compose mounts the local directory at runtime.
# All setup happens in the docker-compose command.

# Expose Phoenix port
EXPOSE 4000

# Start the Phoenix server
CMD ["sh", "-c", "mix ecto.create && mix ecto.migrate && mix phx.server"]

