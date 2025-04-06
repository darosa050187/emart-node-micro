FROM node:14
WORKDIR /app
COPY package*.json ./
copy . .
RUN ls
EXPOSE 5000
CMD ["/bin/sh", "-c", "cd /usr/src/app/ && npm start"]
