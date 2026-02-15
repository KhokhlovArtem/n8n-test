# n8n-test

Проект разворачивает N8N с nginx и SSL сертификатом от Let's Encrypt.

## Содержание
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Управление проектом](#управление-проектом)
- [SSL сертификаты](#ssl-сертификаты)
- [Переменные окружения](#переменные-окружения)
- [Устранение неполадок](#устранение-неполадок)

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
nano .env
```

**Обязательно укажите в `.env`:**
- `N8N_HOST` - ваш домен (например, testn8n.salesystems.ru) - **без точки в конце!**
- `LETSENCRYPT_EMAIL` - ваш email для Let's Encrypt
- `N8N_BASIC_AUTH_PASSWORD` - надежный пароль

### 2. Получение SSL сертификата
```bash
# Сделайте скрипт исполняемым (один раз)
chmod +x scripts/get-cert.sh

# Запустите получение сертификата
./scripts/get-cert.sh
```

Скрипт автоматически:
- Проверит наличие .env файла
- Запустит временный nginx для верификации домена
- Получит сертификат Let's Encrypt
- Установит правильные права доступа
- Остановит временный nginx

### 3. Запуск проекта
```bash
# Запустить все сервисы
docker compose --profile full up -d

# Проверить статус
docker compose ps

# Посмотреть логи
docker compose logs -f
```

### 4. Проверка работы
```bash
# Проверить доступность через HTTPS
curl -I https://ваш-домен.ru

# Открыть в браузере
echo "https://ваш-домен.ru"
```

## Управление проектом

### Основные команды

#### Запуск и остановка
```bash
# Запуск всех сервисов
docker compose --profile full up -d

# Остановка всех сервисов
docker compose --profile full down

# Остановка с удалением томов (очистка данных)
docker compose --profile full down -v

# Перезапуск
docker compose --profile full restart
```

#### Просмотр состояния
```bash
# Статус контейнеров
docker compose ps

# Логи всех сервисов
docker compose --profile full logs -f

# Логи конкретного сервиса
docker compose --profile full logs -f nginx
docker compose --profile full logs -f n8n
docker compose --profile full logs -f certbot
```

#### Работа с конкретными сервисами
```bash
# Перезапуск конкретного сервиса
docker compose --profile full restart nginx

# Просмотр логов конкретного сервиса
docker compose --profile full logs -f certbot
```

## SSL сертификаты

### Получение сертификата (первый запуск)
```bash
./scripts/get-cert.sh
```

### Автоматическое обновление
Сертификаты обновляются автоматически каждые 12 часов через certbot контейнер (входит в состав `profile full`).

### Ручное обновление
```bash
# Обновить сертификаты
docker compose --profile full run --rm certbot renew

# Перезагрузить nginx для применения новых сертификатов
docker compose --profile full exec nginx nginx -s reload
```

### Проверка статуса сертификатов
```bash
docker compose --profile full run --rm certbot certificates
```

## Переменные окружения (.env)

| Переменная | Описание | Пример | Обязательная |
|------------|----------|--------|--------------|
| `N8N_HOST` | Домен для n8n (без точки в конце) | testn8n.salesystems.ru | ✅ Да |
| `N8N_BASIC_AUTH_ACTIVE` | Включить basic auth | true | Нет |
| `N8N_BASIC_AUTH_USER` | Логин для basic auth | admin | Нет |
| `N8N_BASIC_AUTH_PASSWORD` | Пароль для basic auth | secure123 | Нет |
| `LETSENCRYPT_EMAIL` | Email для Let's Encrypt | admin@example.com | ✅ Да |
| `N8N_PORT` | Внутренний порт n8n | 5678 | Нет |

## Устранение неполадок

### Проблема: Nginx не запускается с ошибкой "cannot load certificate"

Если в логах nginx ошибка:
```
cannot load certificate "/etc/letsencrypt/live/ваш-домен.ru./fullchain.pem"
```

Это означает, что nginx добавляет точку в конец домена. Создайте символическую ссылку:

```bash
# Замените ваш-домен.ru на ваш реальный домен из .env
sudo ln -s certbot/conf/live/ваш-домен.ru certbot/conf/live/ваш-домен.ru.

# Перезапустите nginx
docker compose --profile full restart nginx
```

### Проблема: Не удается получить сертификат

```bash
# 1. Проверьте, что домен доступен из интернета
curl -I http://ваш-домен.ru

# 2. Проверьте, что порт 80 открыт
sudo lsof -i :80

# 3. Проверьте переменные в .env
cat .env | grep -E "N8N_HOST|LETSENCRYPT_EMAIL"

# 4. Запустите скрипт с дополнительным выводом
bash -x scripts/get-cert.sh
```

### Проблема: n8n не отвечает

```bash
# Проверьте статус
docker compose ps

# Проверьте логи
docker compose logs n8n

# Проверьте прямую доступность (в обход nginx)
curl http://localhost:5678/healthz
```

### Проблема: После обновления сертификатов HTTPS не работает

```bash
# Проверьте статус сертификатов
docker compose --profile full run --rm certbot certificates

# Принудительно перезагрузите nginx
docker compose --profile full exec nginx nginx -s reload
```

## Структура проекта

```
n8n-test/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── scripts/
│   └── get-cert.sh          # Скрипт получения сертификата
├── nginx/
│   ├── templates/
│   │   └── default.conf.template     # Основной конфиг nginx
│   └── templates-first-run/
│       └── default.conf.template      # Конфиг для первого запуска
└── certbot/                  # Создается автоматически
    ├── www/
    └── conf/
```

## Безопасность

1. **Всегда меняйте пароль** в `.env` файле
2. **Никогда не коммитьте `.env`** в репозиторий (он уже в `.gitignore`)
3. **Регулярно обновляйте** образы Docker
4. **Делайте бэкапы** директории `certbot/conf/`
5. **Следите за логами** на предмет подозрительной активности

## Поддержка

При возникновении проблем:
1. Проверьте статус: `docker compose --profile full ps`
2. Посмотрите логи: `docker compose --profile full logs -f`
3. Проверьте сертификаты: `docker compose --profile full run --rm certbot certificates`
4. Создайте Issue в репозитории с описанием проблемы и логами