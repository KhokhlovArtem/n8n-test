#!/bin/bash

# Загружаем переменные из .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found"
  exit 1
fi

# Проверяем наличие необходимых переменных
if [ -z "$N8N_HOST" ] || [ -z "$LETSENCRYPT_EMAIL" ]; then
  echo "Error: N8N_HOST or LETSENCRYPT_EMAIL not set in .env"
  exit 1
fi

# Создаем директории
mkdir -p certbot/www certbot/conf

# Получаем сертификат
docker run -it --rm \
  -v $(pwd)/certbot/www:/var/www/certbot \
  -v $(pwd)/certbot/conf:/etc/letsencrypt \
  certbot/certbot certonly --webroot \
  -w /var/www/certbot \
  -d $N8N_HOST \
  --email $LETSENCRYPT_EMAIL \
  --agree-tos \
  --no-eff-email \
  --force-renewal

# Проверка результата
if [ $? -eq 0 ]; then
  echo -e "\n✅ Сертификат успешно получен!"
  echo "📁 Локация: $(pwd)/certbot/conf/live/$N8N_HOST/"
  ls -la certbot/conf/live/$N8N_HOST/
else
  echo -e "\n❌ Ошибка получения сертификата"
  exit 1
fi