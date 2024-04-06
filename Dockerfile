# syntax=docker/dockerfile:1

ARG NODE_VERSION=21.7.1

################################################################################
# Use node image for base image for all stages.
FROM node:${NODE_VERSION}-alpine as base

# Set working directory for all build stages.
WORKDIR /usr/src/app

################################################################################
# Create a stage for installing production dependecies.
FROM base as deps

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.npm to speed up subsequent builds.
# Leverage bind mounts to package.json and package-lock.json to avoid having to 
# copy them into this layer.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci \
        --ignore-scripts \
        --omit=dev

################################################################################
# Create a stage for building the application.
FROM deps as build

# Download additional development dependencies before building, as the project
# require "devDependencies" to be installed to build.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci \
        --ignore-scripts

# Copy the rest of the source files into the image.
COPY . .
# Run the build script.
RUN npm run build

################################################################################
# Create a new stage to run the application with minimal runtime dependencies
# where the necessary files are copied from the build stage.
FROM base as final

# Use production node environment by default.
ENV NODE_ENV production

# Copy package.json so that package manager commands can be used.
COPY package.json .

# Copy the production dependencies from the deps stage and also
# the built application from the build stage into the image.
# Note: .dockerignore will filter out dependencies and non-production files.
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/ .

# Create GitProxy custom folders and make it writable to GitProxy.
RUN mkdir .data .remote .tmp
RUN chown node .data .remote .tmp

# Default port for the git proxy server
ENV GIT_PROXY_PORT="80"
# Default port for the API server
ENV GIT_PROXY_API_PORT="8080"

# Expose the port that the application listens on.
EXPOSE ${GIT_PROXY_PORT}
EXPOSE ${GIT_PROXY_API_PORT}

# Run the application as a non-root user.
USER node

# Run the application.
CMD \
    export GIT_PROXY_SERVER_PORT=${GIT_PROXY_PORT} && \
    export GIT_PROXY_UI_PORT=${GIT_PROXY_API_PORT} && \
    npm run server -- --config docker.proxy.config.json