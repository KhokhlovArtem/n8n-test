# deployment n8n ubuntu
# корневая ссылка
https://docs.n8n.io/hosting/
# Docker install
https://docs.n8n.io/hosting/installation/docker/


# Docker install


# Install n8n
docker volume create n8n_data
docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n

