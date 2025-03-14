###################
# BUILD FOR LOCAL DEVELOPMENT
###################
# In this step we copy over everything we need and install all dependancies
# We stop at the end of this step in development, so it also includes the deploy command
# We install jest, eslint and ts-node so we can run tests and lint.

FROM node:lts AS development

ENV NODE_ENV=development

# Create app directory
WORKDIR /usr/src/app

# Copy application dependency manifests to the container image.
# A wildcard is used to ensure copying both package.json AND package-lock.json (when available).
# Copying this first prevents re-running npm install on every code change.
COPY --chown=node:node package*.json ./

# Install app dependencies using the `npm ci` command instead of `npm install`
# Use NPM CI even though this may be your first time, cuz package-lock already thinks you installed stuff
RUN npm ci

# Bundle app source
COPY --chown=node:node . .

# Use the node user from the image (instead of the root user)
# USER node

# For container development, the following command runs forever, so we can inspect the container
CMD ["npm", "run", ".dev"]

###################
# BUILD FOR PRODUCTION
###################
# This stage prepares for and builds the production .js code
# We copy over the node_modules directory from the development image to ensure that the production image has access to all the dependencies it needs
# Then we copy over everything else that may be needed to run
# We run the build command which creates the production bundle
# We run npm ci --only=production to ensure that only the production dependencies are installed

FROM node:lts-alpine AS build

ENV NODE_ENV=production

# Create app directory
WORKDIR /usr/src/app

# In order to run `npm run build` we need access to the Nest CLI which is a dev dependency. In the previous development stage we ran `npm ci` which installed all dependencies, so we can copy over the node_modules directory from the development image
COPY --chown=node:node --from=development /usr/src/app/node_modules ./node_modules

# Copy over the existing source code
COPY --chown=node:node . .

# Build the production bundle
RUN npx next build

# Use the node user from the image (instead of the root user)
USER node

# Running `npm ci` removes the existing node_modules directory and passing in --only=production ensures that only the production dependencies are installed. This ensures that the node_modules directory is as optimized as possible
RUN npm ci --omit:dev && npm cache clean --force

###################
# PRODUCTION
###################
# This stage creates the final, small-as-can-be, production image
# We copy over the node_modules directory from the build stage
# Then we copy over the /.next folder with the built code
# Then we copy over the public folder with the static assets
# Then we copy over the package.json file
# We set the user to node so that the container runs as the node user instead of root
# We run the start command to start the application

FROM node:lts-alpine AS production

ENV NODE_ENV=production

# Create app directory
WORKDIR /usr/src/app

# # Copy the bundled code from the build stage to the production image
COPY --chown=node:node --from=build /usr/src/app/.next ./.next
COPY --chown=node:node --from=build /usr/src/app/public  ./public 
COPY --chown=node:node --from=build /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=build /usr/src/app/package.json ./
COPY --chown=node:node --from=build /usr/src/app/static ./static

USER node

CMD ["npm", "run", ".start"]