FROM n8nio/n8n:latest

# Просто запускаем n8n, ничего лишнего
CMD ["n8n"]

# Определяем USER внутри контейнера как node
USER node
ENTRYPOINT []
