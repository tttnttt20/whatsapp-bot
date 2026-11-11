FROM node:20
RUN apt-get update && apt-get install -y python3 ffmpeg && ln -sf /usr/bin/python3 /usr/bin/python
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "index.js"]
