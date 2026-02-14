# n8n-test

Проект разворачивает N8N с nginx и SSL сертификатом от Let's Encrypt.

## Содержание
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Управление проектом](#управление-проектом)
- [SSL сертификаты](#ssl-сертификаты)
- [Доступ](#доступ)
- [Полезные команды](#полезные-команды)

## Требования

- Docker и Docker Compose
- Домен, указывающий на IP сервера
- Открытые порты 80 и 443

## Быстрый старт

### 1. Настройка окружения
```bash
# Клонировать репозиторий
git clone <your-repo-url>
cd n8n-test

# Создать файл .env из примера
cp .env.example .env

# Отредактировать .env файл
# Обязательно укажите:
# - N8N_HOST - ваш домен
# - N8N_BASIC_AUTH_PASSWORD - надежный пароль
# - LETSENCRYPT_EMAIL - ваш email
nano .env
```

### 2. Получение SSL сертификата
```bash
# Сделать скрипт исполняемым и выполнить
chmod +x scripts/init-letsencrypt.sh
./scripts/init-letsencrypt.sh
```

### 3. Запуск проекта
```bash
# Сборка и запуск в фоновом режиме
docker compose up --build -d
```

### 4. Проверка работы
```bash
# Просмотр логов
docker compose logs -f

# Проверка доступности сайта
curl -I https://ваш-домен.ru
```

## Управление проектом

### Основные команды

#### Запуск и остановка
```bash
# Запуск в фоновом режиме
docker compose up -d

# Запуск с пересборкой
docker compose up --build -d

# Остановка
docker compose down

# Остановка с удалением томов (очистка данных)
docker compose down -v

# Перезапуск
docker compose restart
```

#### Просмотр состояния
```bash
# Логи всех сервисов
docker compose logs -f

# Логи конкретного сервиса
docker compose logs -f nginx
docker compose logs -f n8n

# Список запущенных контейнеров
docker compose ps

# Использование ресурсов
docker stats
```

#### Работа с конкретными сервисами
```bash
# Пересборка конкретного сервиса
docker compose up --build --no-deps -d n8n

# Перезапуск конкретного сервиса
docker compose restart nginx

# Просмотр логов конкретного сервиса
docker compose logs -f certbot
```

### Полный рестарт

#### Перезапуск без сборки (если не менялись Dockerfile):
```bash
docker compose restart
```

#### Принудительная пересборка конкретного сервиса:
```bash
docker compose up --build --no-deps -d <service_name>
```

#### Очистка (удаление контейнеров, сетей, образов):
```bash
docker compose down --rmi all -v
```
где:
- `--rmi all` - удаляет все образы
- `-v` или `--volumes` - удаляет тома

**Важно:** Если нужно сохранить данные в томах (volumes), не используйте флаг `-v` в команде `down`, иначе данные будут удалены.

## SSL сертификаты

### Автоматическое обновление
Сертификаты обновляются автоматически каждые 12 часов через certbot контейнер.

### Ручное обновление
```bash
# Обновить сертификаты
docker compose run --rm certbot renew

# Перезагрузить nginx для применения новых сертификатов
docker compose exec nginx nginx -s reload
```

### Проверка статуса сертификатов
```bash
docker compose run --rm certbot certificates
```

### Проблемы с сертификатами?
Если возникли проблемы при получении сертификатов:
```bash
# Проверить, что nginx работает и слушает порт 80
docker compose ps

# Посмотреть логи nginx
docker compose logs nginx

# Попробовать получить сертификат в staging режиме
# Добавьте в .env:
# LETSENCRYPT_STAGING=1
# Затем повторно запустите скрипт
./scripts/init-letsencrypt.sh
```

## Доступ

После запуска n8n будет доступен по адресу:
```
https://ваш-домен.ru
```

Данные для входа (из .env файла):
- **Логин:** значение N8N_BASIC_AUTH_USER
- **Пароль:** значение N8N_BASIC_AUTH_PASSWORD

## Полезные команды

### Работа с данными
```bash
# Создать бэкап данных
docker run --rm -v config-data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz -C /data .

# Восстановить из бэкапа
docker run --rm -v config-data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n-backup-20240101.tar.gz -C /data
```

### Обновление образов
```bash
# Скачать новые версии образов
docker compose pull

# Пересобрать и запустить с новыми образами
docker compose up --build -d
```

### Диагностика
```bash
# Проверка конфигурации nginx
docker compose exec nginx nginx -t

# Проверка доступности n8n изнутри сети
docker compose exec nginx curl http://n8n:5678/healthz

# Просмотр переменных окружения
docker compose exec n8n env | grep N8N
```

## Устранение неполадок

### Проблема: Не работает HTTPS
```bash
# Проверить, что сертификаты существуют
ls -la certbot/conf/live/

# Проверить конфигурацию nginx
docker compose exec nginx nginx -t

# Проверить логи nginx
docker compose logs nginx
```

### Проблема: n8n не отвечает
```bash
# Проверить статус контейнера
docker compose ps n8n

# Посмотреть логи
docker compose logs n8n

# Проверить прямую доступность (в обход nginx)
curl http://localhost:5678/healthz
```

## Безопасность

1. **Всегда меняйте пароль** в .env файле
2. **Не коммитьте .env** в репозиторий (он уже в .gitignore)
3. **Регулярно обновляйте** образы Docker
4. **Делайте бэкапы** важных данных
5. **Следите за логами** на предмет подозрительной активности

## Поддержка

При возникновении проблем:
1. Проверьте логи: `docker compose logs -f`
2. Проверьте статус сертификатов: `docker compose run --rm certbot certificates`
3. Создайте Issue в репозитории с описанием проблемы и логами
