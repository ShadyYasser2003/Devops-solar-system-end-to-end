FROM node:18-alpine3.17

WORKDIR /usr/app

COPY package*.json /usr/app/

RUN npm install

COPY . .

ENV MONGO_URI=""
ENV MONGO_USERNAME=""
ENV MONGO_PASSWORD=""

EXPOSE 3000

CMD [ "npm", "start" ]