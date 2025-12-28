FROM n8nio/n8n:latest

# Установите зависимости один раз
USER root
RUN npm install @sberdevices/giga-chat
USER node