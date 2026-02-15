#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Получение SSL сертификата для n8n ===${NC}"

# Загружаем переменные из .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo -e "${RED}Ошибка: .env файл не найден${NC}"
  echo -e "Создайте его из .env.example: ${YELLOW}cp .env.example .env${NC}"
  exit 1
fi

# Проверяем наличие необходимых переменных
if [ -z "$N8N_HOST" ]; then
  echo -e "${RED}Ошибка: N8N_HOST не задан в .env${NC}"
  exit 1
fi

if [ -z "$LETSENCRYPT_EMAIL" ]; then
  echo -e "${RED}Ошибка: LETSENCRYPT_EMAIL не задан в .env${NC}"
  exit 1
fi

echo -e "${GREEN}Домен: $N8N_HOST${NC}"
echo -e "${GREEN}Email: $LETSENCRYPT_EMAIL${NC}"

# Создаем директории для сертификатов
echo -e "${YELLOW}Создание директорий для сертификатов...${NC}"
mkdir -p certbot/www certbot/conf

# Останавливаем временный nginx если работает
echo -e "${YELLOW}Остановка временного nginx (если запущен)...${NC}"
docker compose --profile first-run down 2>/dev/null || true

# Запускаем временный nginx для верификации
echo -e "${GREEN}Запуск временного nginx для верификации домена...${NC}"
docker compose --profile first-run up -d

# Ожидаем запуска
echo -e "${YELLOW}Ожидание запуска nginx...${NC}"
sleep 5

# Проверяем доступность домена
echo -e "${GREEN}Проверка доступности http://$N8N_HOST ...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$N8N_HOST)
if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
  echo -e "${GREEN}✓ Домен доступен (код ответа: $HTTP_CODE)${NC}"
else
  echo -e "${RED}✗ Домен недоступен (код ответа: $HTTP_CODE)${NC}"
  echo -e "${YELLOW}Проверьте:${NC}"
  echo -e "  - DNS запись указывает на этот сервер"
  echo -e "  - Порт 80 открыт в firewall"
  echo -e "  - Нет другого сервиса на порту 80"
  docker compose --profile first-run down
  exit 1
fi

# Получаем сертификат
echo -e "${GREEN}Получение сертификата от Let's Encrypt...${NC}"
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

# Проверяем результат получения сертификата
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Сертификат успешно получен!${NC}"
  
  # Устанавливаем правильные права доступа
  echo -e "${YELLOW}Установка прав доступа к сертификатам...${NC}"
  
  # Права для директорий
  sudo chmod 755 certbot/conf
  sudo chmod 755 certbot/conf/live
  sudo chmod 755 certbot/conf/live/$N8N_HOST
  sudo chmod 755 certbot/conf/archive
  sudo chmod 755 certbot/conf/renewal
  
  # Права для файлов сертификатов
  sudo chmod 644 certbot/conf/live/$N8N_HOST/fullchain.pem
  sudo chmod 644 certbot/conf/live/$N8N_HOST/chain.pem
  sudo chmod 644 certbot/conf/live/$N8N_HOST/cert.pem
  sudo chmod 600 certbot/conf/live/$N8N_HOST/privkey.pem
  
  # Права для остальных файлов
  sudo chmod 644 certbot/conf/options-ssl-nginx.conf 2>/dev/null || true
  sudo chmod 644 certbot/conf/ssl-dhparams.pem 2>/dev/null || true
  
  echo -e "${GREEN}✓ Права доступа установлены${NC}"
  
  # Показываем информацию о сертификате
  echo -e "\n${GREEN}Информация о сертификате:${NC}"
  echo -e "  📁 Локация: $(pwd)/certbot/conf/live/$N8N_HOST/"
  ls -la certbot/conf/live/$N8N_HOST/ | grep -E "pem$" | sed 's/^/  /'
  
  # Показываем срок действия
  CERT_INFO=$(docker run --rm -v $(pwd)/certbot/conf:/etc/letsencrypt alpine openssl x509 -in /etc/letsencrypt/live/$N8N_HOST/cert.pem -noout -dates 2>/dev/null)
  if [ -n "$CERT_INFO" ]; then
    echo -e "\n${GREEN}Срок действия:${NC}"
    echo "$CERT_INFO" | sed 's/^/  /'
  fi
else
  echo -e "${RED}❌ Ошибка получения сертификата${NC}"
  echo -e "${YELLOW}Возможные причины:${NC}"
  echo -e "  - Домен недоступен из интернета"
  echo -e "  - Слишком много запросов (rate limit)"
  echo -e "  - Проблемы с сетью"
  docker compose --profile first-run down
  exit 1
fi

# Останавливаем временный nginx
echo -e "${YELLOW}Остановка временного nginx...${NC}"
docker compose --profile first-run down

echo -e "\n${GREEN}=== Готово! ===${NC}"
echo -e "Теперь можно запустить полный стек:"
echo -e "  ${YELLOW}docker compose --profile full up -d${NC}"
echo -e "\nПосле запуска проверьте:"
echo -e "  ${YELLOW}curl -I https://$N8N_HOST${NC}"