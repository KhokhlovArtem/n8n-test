#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка наличия docker-compose
if ! [ -x "$(command -v docker-compose)" ]; then
  echo -e "${RED}Error: docker-compose is not installed.${NC}" >&2
  exit 1
fi

# Загрузка переменных из .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo -e "${RED}Error: .env file not found. Please create it from .env.example${NC}"
  exit 1
fi

# Проверка наличия N8N_HOST
if [ -z "$N8N_HOST" ]; then
  echo -e "${RED}Error: N8N_HOST is not set in .env file${NC}"
  exit 1
fi

domains=($N8N_HOST)
rsa_key_size=4096
data_path="./certbot"
email=${LETSENCRYPT_EMAIL:-admin@example.com}
staging=${LETSENCRYPT_STAGING:-0} # Установить 1 для тестирования

echo -e "${GREEN}=== Инициализация SSL сертификата для ${domains} ===${NC}"
echo -e "Email: $email"
echo -e "Staging mode: $staging\n"

# Проверка существующих сертификатов
if [ -d "$data_path/conf/live/${domains[0]}" ]; then
  echo -e "${YELLOW}Existing data found for ${domains[0]}.${NC}"
  read -p "Do you want to continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
  echo -e "${YELLOW}Removing existing certificates...${NC}"
  rm -rf "$data_path/conf/live/${domains[0]}"
  rm -rf "$data_path/conf/archive/${domains[0]}"
  rm -rf "$data_path/conf/renewal/${domains[0]}.conf"
fi

# Создание директорий
echo -e "${GREEN}Creating required directories...${NC}"
mkdir -p "$data_path/www"
mkdir -p "$data_path/conf"

# Запуск nginx
echo -e "${GREEN}Starting nginx container...${NC}"
docker-compose up -d nginx

# Небольшая пауза для запуска nginx
sleep 5

# Получение сертификата
echo -e "${GREEN}Requesting Let's Encrypt certificate for ${domains[0]} ...${NC}"

# Выбор параметров в зависимости от staging
staging_arg=""
if [ $staging != "0" ]; then
  staging_arg="--staging"
  echo -e "${YELLOW}STAGING MODE: Using test certificates${NC}"
fi

# Создание временного скрипта для certbot
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot \
  $staging_arg \
  --email $email \
  -d ${domains[0]} \
  --rsa-key-size $rsa_key_size \
  --agree-tos \
  --force-renewal \
  --noninteractive

# Проверка успешности получения сертификата
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Certificate obtained successfully!${NC}"
  
  # Перезапуск nginx для применения сертификата
  echo -e "${GREEN}Reloading nginx...${NC}"
  docker-compose exec nginx nginx -s reload
  
  echo -e "\n${GREEN}=== SSL Certificate Setup Complete ===${NC}"
  echo -e "Your site is now available at: ${GREEN}https://${domains[0]}${NC}"
else
  echo -e "${RED}Failed to obtain certificate. Check the logs above.${NC}"
  exit 1
fi