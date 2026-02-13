# Контейнеризация и развертывание Medusa
# Medusa + Storefront (Next.js) + MinIO + Traefik

> Краткое описание: репозиторий содержит backend на Medusa (админ + API) и Storefront на Next.js. Локальная разработка и тестирование проводятся через Docker (docker-compose). Для production предусмотрён `docker-compose.prod.yml` с Traefik, Postgres, Redis и MinIO.

---

## Содержание файла
- О проекте
- Требования
- Быстрый старт - локально (через `npm run docker:up`)
- Примеры `.env`
- Прод (кратко)
- CI/CD (кратко)

---

## О проекте
Проект состоит из двух основных частей:
- `my-medusa-store/` - Medusa backend (сервер, админ, миграции, seed).
- `my-medusa-store-storefront/` - Next.js storefront.

---

## Требования
- Docker и Docker Compose (поддержка `docker compose`).
- Node.js и npm.
- Домен(ы) и VPS для прод-деплоя.

---

## Быстрый старт - локально
1. Клонируйте репозиторий:
```bash
git clone https://github.com/sxeDexs/medusa_test.git medusa
cd medusa
```

2. Подготовьте env-файлы (см. раздел "Примеры `.env`" ниже).

3. Запуск (в `my-medusa-store` при 1 случае и в корне при втором):
```bash
# 1. Если в package.json есть скрипт
 npm run docker:up
# 2. Или напрямую
docker compose -f docker-compose.local.yml up --build -d
```

4. Проверьте сервисы:
```bash
docker compose -f docker-compose.local.yml ps
curl http://localhost:9000/health   # ожидается: OK
# storefront на http://localhost:8000
```

5. Остановка:
```bash
npm run docker:down
# или
docker compose -f docker-compose.local.yml down
```

6. Доступ к сервисам после запуска: 
   - **Medusa Admin** - откройте в браузере http://localhost:9000/app  
     - Логин: `admin@test.com`  
     - Пароль: `supersecret`  
     (эти учётные данные создаются автоматически при первом запуске через start.sh) 
        Если по какой-то причине указанные данные не подходят, вы можете создать нового администратора вручную:
        ```bash
        docker exec -it medusa_backend npx medusa user -e admin@example.com -p securepassword
        ``` 
   - **Storefront** - доступен по адресу http://localhost:8000
        **Примечание:** он будет недоступен из-за неверного NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY. Для этого через админку найдите его (http://localhost:9000/app/settings/publishable-api-keys), скопируйте и вставьте в `my-medusa-store-storefront/.env.local`. Перезапустите только storefront:
        ```bash
        docker compose -f docker-compose.local.yml restart storefront
        ```
   - **MinIO** - доступен по адресу http://localhost:9003 
     - Логин: `minio`  
     - Пароль: `minio123`   

---

## Примеры `.env` (локально)
**my-medusa-store/.env**
```env
DATABASE_URL=postgres://postgres:postgres@postgres:5432/medusa-store
REDIS_URL=redis://redis:6379

STORE_CORS=http://localhost:8000,https://docs.medusajs.com
ADMIN_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com
AUTH_CORS=http://localhost:5173,http://localhost:9000,http://localhost:8000,https://docs.medusajs.com

JWT_SECRET=supersecret
COOKIE_SECRET=supersecret

S3_ENDPOINT=http://minio:9000
S3_BUCKET=medusa
S3_ACCESS_KEY=minio
S3_SECRET_KEY=minio123
S3_FORCE_PATH_STYLE=true
S3_REGION=us-east-1

MEDUSA_ADMIN_ONBOARDING_TYPE=nextjs
MEDUSA_ADMIN_ONBOARDING_NEXTJS_DIRECTORY=my-medusa-store-storefront
NODE_ENV=development
PORT=9000
```

**my-medusa-store-storefront/.env.local**
```env
MEDUSA_BACKEND_URL=http://medusa:9000
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_local_key
NEXT_PUBLIC_BASE_URL=http://localhost:8000
NEXT_PUBLIC_DEFAULT_REGION=us
REVALIDATE_SECRET=supersecret
```

---

# Прод

Для production развертывания используется отдельный Compose-файл `docker-compose.prod.yml`.  
Он включает:

- **PostgreSQL, Redis, MinIO** - как и в локальной версии.
- **Medusa backend** - собирается из `my-medusa-store` с использованием `Dockerfile.prod`.  
  Запускается с переменными окружения из `.env.prod`.  
  В `start.prod.sh` выполняются миграции, создаётся admin-пользователь (если заданы `MEDUSA_ADMIN_EMAIL`/`PASSWORD`), а затем запускается сервер.
- **Storefront (Next.js)** - собирается из `my-medusa-store-storefront` с `Dockerfile.prod`.  
  При сборке через `--build-arg` передаются `NEXT_PUBLIC_MEDUSA_BACKEND_URL` и `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY`, чтобы `next build` мог обращаться к работающему бэкенду.
- **Traefik** - в качестве reverse proxy. Автоматически получает SSL-сертификаты Let's Encrypt для доменов `mm.dev.gorgojs.ru` (storefront) и `admin.mm.dev.gorgojs.ru` (admin/API).  
  Все сервисы изолированы внутри Docker-сети, наружу открыты только порты 80 и 443.

Переменные окружения для production хранятся в файлах `.env` (корневой, для общих секретов), `my-medusa-store/.env.prod` и `my-medusa-store-storefront/.env.prod`.  

---

# CI/CD – GitHub Actions

В репозитории настроен GitHub Actions workflow `deploy.yml`, который автоматически разворачивает приложение на VPS при каждом push в ветку `main`.

## Основные этапы деплоя

1. **Копирование файлов на сервер**  
   Через `rsync` отправляются `docker-compose.prod.yml` и папки с исходным кодом (`my-medusa-store`, `my-medusa-store-storefront`) в `/opt/medusa/`.

2. **Создание `.env` файлов**  
   На сервере генерируются все необходимые `.env` файлы с использованием секретов GitHub (например, `POSTGRES_PASSWORD`, `JWT_SECRET`, `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY` и т.д.).  
   Это гарантирует, что ни один секрет не попадёт в код.

3. **Сборка образа Medusa**  
   Запускается `docker compose build medusa` с передачей аргумента `MEDUSA_ADMIN_BACKEND_URL` (значение из секретов).  
   На этом этапе также собирается админка и все backend-зависимости.

4. **Запуск зависимостей и Medusa**  
   Поднимаются контейнеры `postgres`, `redis`, `minio` и `medusa`.  
   Выполняется health‑check: ожидается ответ `OK` от `http://medusa:9000/health` (через `docker exec` внутри контейнера).

5. **Healthcheck Medusa**  

6. **Сборка образа Storefront**  
   Сборка `storefront` с явной передачей аргументов:
   - `NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://admin.mm.dev.gorgojs.ru` (публичный URL бэкенда)
   - `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY` (значение из секретов)

   Благодаря этому `next build` может обращаться к уже работающему бэкенду через Traefik.

   **Замечание:** на этом этапе пайплайн обрывается с ошибкой `ECONNREFUSED`.

7. **Запуск Storefront**  
   После успешной сборки запускается контейнер `storefront`.

8. **Финальный подъём всех сервисов**  
   Команда `docker compose up -d` убеждается, что все контейнеры запущены.

## Примечания

- Последовательность шагов критична: сначала должен быть готов бэкенд, и только потом можно собирать storefront, потому что при генерации статических страниц Next.js выполняет запросы к API.
- В репозитории добавлены корректные файлы .gitignore и .dockerignore, чтобы:
    - исключить из Git все секреты (.env, .env.prod, .env.local и т.д.)
    - не загружать node_modules в репозиторий
    - не отправлять временные файлы, логи и build-артефакты
    - не копировать лишние файлы в Docker-образ (что ускоряет сборку и уменьшает размер image)

---

После первого успешного деплоя необходимо:
- Зайти в админку `https://admin.mm.dev.gorgojs.ru/app` и создать настоящий publishable key.
- Заменить значение секрета `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY` в GitHub Secrets на полученный ключ.
- Перезапустить workflow (или вручную перезапустить storefront на сервере).
