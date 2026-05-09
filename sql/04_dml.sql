-- =============================================================
-- DML: populate snowflake schema from staging_mock_data
-- =============================================================
-- Execution order matters: sub-dimensions before their parents,
-- dimensions before the fact table.
-- =============================================================

-- 1. dim_date ─────────────────────────────────────────────────
INSERT INTO dim_date (full_date, year, month, day, quarter)
SELECT DISTINCT
    TO_DATE(sale_date, 'MM/DD/YYYY')                                    AS full_date,
    EXTRACT(YEAR    FROM TO_DATE(sale_date, 'MM/DD/YYYY'))::INT         AS year,
    EXTRACT(MONTH   FROM TO_DATE(sale_date, 'MM/DD/YYYY'))::INT         AS month,
    EXTRACT(DAY     FROM TO_DATE(sale_date, 'MM/DD/YYYY'))::INT         AS day,
    EXTRACT(QUARTER FROM TO_DATE(sale_date, 'MM/DD/YYYY'))::INT         AS quarter
FROM staging_mock_data
WHERE sale_date IS NOT NULL AND sale_date <> ''
ON CONFLICT (full_date) DO NOTHING;

-- 2. dim_pet_type ─────────────────────────────────────────────
INSERT INTO dim_pet_type (type_name)
SELECT DISTINCT customer_pet_type
FROM staging_mock_data
WHERE customer_pet_type IS NOT NULL AND customer_pet_type <> ''
ON CONFLICT (type_name) DO NOTHING;

-- 3. dim_pet_breed ────────────────────────────────────────────
INSERT INTO dim_pet_breed (breed_name)
SELECT DISTINCT customer_pet_breed
FROM staging_mock_data
WHERE customer_pet_breed IS NOT NULL AND customer_pet_breed <> ''
ON CONFLICT (breed_name) DO NOTHING;

-- 4. dim_customer ─────────────────────────────────────────────
-- One row per unique customer email; take first encountered record
INSERT INTO dim_customer (first_name, last_name, age, email, country, postal_code)
SELECT DISTINCT ON (customer_email)
    customer_first_name,
    customer_last_name,
    NULLIF(customer_age, '')::INT,
    customer_email,
    NULLIF(customer_country, ''),
    NULLIF(customer_postal_code, '')
FROM staging_mock_data
WHERE customer_email IS NOT NULL AND customer_email <> ''
ORDER BY customer_email
ON CONFLICT (email) DO NOTHING;

-- 5. dim_pet ──────────────────────────────────────────────────
-- One pet record per (customer, pet_name) pair
INSERT INTO dim_pet (customer_id, pet_name, type_id, breed_id)
SELECT DISTINCT ON (c.customer_id, s.customer_pet_name)
    c.customer_id,
    s.customer_pet_name,
    pt.type_id,
    pb.breed_id
FROM staging_mock_data s
JOIN dim_customer  c  ON c.email       = s.customer_email
JOIN dim_pet_type  pt ON pt.type_name  = s.customer_pet_type
JOIN dim_pet_breed pb ON pb.breed_name = s.customer_pet_breed
WHERE s.customer_pet_name IS NOT NULL AND s.customer_pet_name <> ''
ORDER BY c.customer_id, s.customer_pet_name;

-- 6. dim_seller ───────────────────────────────────────────────
INSERT INTO dim_seller (first_name, last_name, email, country, postal_code)
SELECT DISTINCT ON (seller_email)
    seller_first_name,
    seller_last_name,
    seller_email,
    NULLIF(seller_country, ''),
    NULLIF(seller_postal_code, '')
FROM staging_mock_data
WHERE seller_email IS NOT NULL AND seller_email <> ''
ORDER BY seller_email
ON CONFLICT (email) DO NOTHING;

-- 7. dim_store ────────────────────────────────────────────────
-- Natural key: store_name + city (no surrogate in source data)
INSERT INTO dim_store (store_name, location, city, state, country, phone, email)
SELECT DISTINCT ON (store_name, store_city)
    store_name,
    NULLIF(store_location, ''),
    NULLIF(store_city, ''),
    NULLIF(store_state, ''),
    NULLIF(store_country, ''),
    NULLIF(store_phone, ''),
    NULLIF(store_email, '')
FROM staging_mock_data
WHERE store_name IS NOT NULL AND store_name <> ''
ORDER BY store_name, store_city;

-- 8. dim_product_category ─────────────────────────────────────
-- Combination of product_category (Food/Toy/Cage) and pet_category (Cats/Dogs/…)
INSERT INTO dim_product_category (category_name, pet_category)
SELECT DISTINCT
    product_category,
    NULLIF(pet_category, '')
FROM staging_mock_data
WHERE product_category IS NOT NULL AND product_category <> '';

-- 9. dim_supplier ─────────────────────────────────────────────
-- Natural key: supplier_name + city
INSERT INTO dim_supplier (supplier_name, contact_name, email, phone, address, city, country)
SELECT DISTINCT ON (supplier_name, supplier_city)
    supplier_name,
    NULLIF(supplier_contact, ''),
    NULLIF(supplier_email, ''),
    NULLIF(supplier_phone, ''),
    NULLIF(supplier_address, ''),
    NULLIF(supplier_city, ''),
    NULLIF(supplier_country, '')
FROM staging_mock_data
WHERE supplier_name IS NOT NULL AND supplier_name <> ''
ORDER BY supplier_name, supplier_city;

-- 10. dim_product ─────────────────────────────────────────────
-- Natural key: product_name + brand
INSERT INTO dim_product (
    product_name, category_id, supplier_id,
    price, quantity, weight, color, size, brand, material,
    description, rating, reviews, release_date, expiry_date
)
SELECT DISTINCT ON (s.product_name, s.product_brand)
    s.product_name,
    pc.category_id,
    sup.supplier_id,
    NULLIF(s.product_price,    '')::NUMERIC,
    NULLIF(s.product_quantity, '')::INT,
    NULLIF(s.product_weight,   '')::NUMERIC,
    NULLIF(s.product_color,    ''),
    NULLIF(s.product_size,     ''),
    NULLIF(s.product_brand,    ''),
    NULLIF(s.product_material, ''),
    NULLIF(s.product_description, ''),
    NULLIF(s.product_rating,   '')::NUMERIC,
    NULLIF(s.product_reviews,  '')::INT,
    CASE WHEN s.product_release_date IS NOT NULL AND s.product_release_date <> ''
         THEN TO_DATE(s.product_release_date, 'MM/DD/YYYY') END,
    CASE WHEN s.product_expiry_date IS NOT NULL AND s.product_expiry_date <> ''
         THEN TO_DATE(s.product_expiry_date, 'MM/DD/YYYY') END
FROM staging_mock_data s
JOIN dim_product_category pc
    ON  pc.category_name = s.product_category
    AND pc.pet_category IS NOT DISTINCT FROM NULLIF(s.pet_category, '')
JOIN dim_supplier sup
    ON  sup.supplier_name = s.supplier_name
    AND sup.city IS NOT DISTINCT FROM NULLIF(s.supplier_city, '')
WHERE s.product_name IS NOT NULL AND s.product_name <> ''
ORDER BY s.product_name, s.product_brand;

-- 11. fact_sales ──────────────────────────────────────────────
-- Every staging row is one sale; join to surrogate keys via natural keys
INSERT INTO fact_sales (
    customer_id, seller_id, product_id, store_id, date_id,
    sale_quantity, sale_total_price
)
SELECT
    c.customer_id,
    sel.seller_id,
    p.product_id,
    st.store_id,
    d.date_id,
    NULLIF(s.sale_quantity,    '')::INT,
    NULLIF(s.sale_total_price, '')::NUMERIC
FROM staging_mock_data s
JOIN dim_customer c   ON  c.email        = s.customer_email
JOIN dim_seller   sel ON  sel.email      = s.seller_email
JOIN dim_product  p   ON  p.product_name = s.product_name
                      AND p.brand IS NOT DISTINCT FROM NULLIF(s.product_brand, '')
JOIN dim_store    st  ON  st.store_name  = s.store_name
                      AND st.city IS NOT DISTINCT FROM NULLIF(s.store_city, '')
JOIN dim_date     d   ON  d.full_date    = TO_DATE(s.sale_date, 'MM/DD/YYYY')
WHERE s.sale_date     IS NOT NULL AND s.sale_date     <> ''
  AND s.customer_email IS NOT NULL AND s.customer_email <> ''
  AND s.seller_email   IS NOT NULL AND s.seller_email   <> '';

-- =============================================================
-- Verification: row counts for every table
-- =============================================================
SELECT 'staging_mock_data'    AS tbl, COUNT(*) FROM staging_mock_data
UNION ALL
SELECT 'dim_date',                    COUNT(*) FROM dim_date
UNION ALL
SELECT 'dim_pet_type',                COUNT(*) FROM dim_pet_type
UNION ALL
SELECT 'dim_pet_breed',               COUNT(*) FROM dim_pet_breed
UNION ALL
SELECT 'dim_customer',                COUNT(*) FROM dim_customer
UNION ALL
SELECT 'dim_pet',                     COUNT(*) FROM dim_pet
UNION ALL
SELECT 'dim_seller',                  COUNT(*) FROM dim_seller
UNION ALL
SELECT 'dim_store',                   COUNT(*) FROM dim_store
UNION ALL
SELECT 'dim_product_category',        COUNT(*) FROM dim_product_category
UNION ALL
SELECT 'dim_supplier',                COUNT(*) FROM dim_supplier
UNION ALL
SELECT 'dim_product',                 COUNT(*) FROM dim_product
UNION ALL
SELECT 'fact_sales',                  COUNT(*) FROM fact_sales
ORDER BY tbl;
