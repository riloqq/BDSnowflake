# Инструкция по запуску лабораторной работы

## Требования

| Инструмент | Версия | Назначение |
|---|---|---|
| Docker Desktop | 4.x+ | запуск PostgreSQL в контейнере |
| DBeaver (опционально) | любая | визуальная работа с БД |

---

## Структура проекта

```
.
├── исходные данные/
│   ├── MOCK_DATA.csv          # файл 0 (строки 1–1000)
│   ├── MOCK_DATA (1).csv      # файл 1
│   └── ... (всего 10 файлов)
├── sql/
│   ├── 01_staging.sql         # создание staging-таблицы
│   ├── 02_import.sh           # импорт CSV в staging
│   ├── 03_ddl.sql             # создание таблиц снежинки
│   └── 04_dml.sql             # наполнение таблиц из staging
├── docker-compose.yml
└── SETUP.md                   # этот файл
```

---

## Запуск

### 1. Поднять контейнер

Из папки с проектом:

```bash
docker-compose up -d
```

Docker при первом запуске:
1. Скачает образ `postgres:16`
2. Создаст БД `snowflake_db`
3. Выполнит скрипты из `sql/` в порядке `01 → 02 → 03 → 04`

Дождитесь статуса `healthy` (~30–60 секунд):

```bash
docker-compose ps
```

Смотреть логи инициализации:

```bash
docker-compose logs postgres
```

В конце логов должна появиться таблица с количеством строк — это вывод верификационного запроса из `04_dml.sql`.

### 2. Подключиться через DBeaver

| Параметр | Значение |
|---|---|
| Host | `localhost` |
| Port | **`5434`** |
| Database | `snowflake_db` |
| User | `postgres` |
| Password | `postgres` |

> Порт **5434** (не стандартный 5432/5433).

### 3. Подключиться через psql

```bash
docker exec -it pet_store_snowflake psql -U postgres -d snowflake_db
```

---

## Схема «Снежинка»

```
                        dim_pet_type
                             ▲
dim_date   dim_pet_breed ──► dim_pet ◄── dim_customer
   ▲                                          ▲
   │                                          │
fact_sales ◄───────────────────────── dim_seller
   │
   ├──► dim_store
   │
   └──► dim_product ──► dim_product_category
              └──────► dim_supplier
```

### Таблицы

| Таблица | Тип | Описание |
|---|---|---|
| `staging_mock_data` | staging | сырые данные из CSV (все 50 колонок — TEXT) |
| `dim_date` | измерение | даты продаж с разбивкой по году/месяцу/кварталу |
| `dim_customer` | измерение | покупатели |
| `dim_pet` | суб-измерение | питомцы покупателей |
| `dim_pet_type` | суб-измерение | виды питомцев (cat, dog, bird…) |
| `dim_pet_breed` | суб-измерение | породы (Labrador, Siamese…) |
| `dim_seller` | измерение | продавцы |
| `dim_store` | измерение | магазины |
| `dim_product` | измерение | товары |
| `dim_product_category` | суб-измерение | категория + вид питомца |
| `dim_supplier` | суб-измерение | поставщики |
| `fact_sales` | факт | продажи (количество, сумма, FK на все измерения) |

---

## Примеры аналитических запросов

### Топ-5 товаров по выручке

```sql
SELECT
    p.product_name,
    p.brand,
    SUM(f.sale_total_price) AS total_revenue
FROM fact_sales f
JOIN dim_product p USING (product_id)
GROUP BY p.product_name, p.brand
ORDER BY total_revenue DESC
LIMIT 5;
```

### Продажи по кварталам

```sql
SELECT
    d.year,
    d.quarter,
    COUNT(*)              AS sales_count,
    SUM(f.sale_total_price) AS revenue
FROM fact_sales f
JOIN dim_date d USING (date_id)
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;
```

### Выручка по категории товара и виду питомца

```sql
SELECT
    pc.category_name,
    pc.pet_category,
    SUM(f.sale_total_price) AS revenue
FROM fact_sales f
JOIN dim_product p          USING (product_id)
JOIN dim_product_category pc USING (category_id)
GROUP BY pc.category_name, pc.pet_category
ORDER BY revenue DESC;
```

### Покупатели с их питомцами

```sql
SELECT
    c.first_name || ' ' || c.last_name AS customer,
    pt.type_name                        AS pet_type,
    pb.breed_name                       AS pet_breed,
    dp.pet_name
FROM dim_customer c
JOIN dim_pet      dp USING (customer_id)
JOIN dim_pet_type pt USING (type_id)
JOIN dim_pet_breed pb USING (breed_id)
ORDER BY customer;
```

---

## Остановка и сброс

Остановить контейнер (данные сохраняются):

```bash
docker-compose down
```

Полный сброс (удалить все данные и начать заново):

```bash
docker-compose down -v
docker-compose up -d
```
