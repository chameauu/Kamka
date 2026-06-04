FROM node:18-alpine

# Install curl for Docker healthcheck
RUN apk add --no-cache curl

WORKDIR /app

COPY package.json .
RUN npm install --production

COPY server.js .

EXPOSE 3000

CMD ["npm", "start"]
