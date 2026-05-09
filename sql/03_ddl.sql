-- =============================================================
-- DDL: Snowflake schema for pet store sales data
-- =============================================================
-- Schema structure:
--
--   fact_sales
--   ├── dim_date
--   ├── dim_customer
--   │   └── dim_pet ── dim_pet_type
--   │              └── dim_pet_breed
--   ├── dim_seller
--   ├── dim_store
--   └── dim_product
--       ├── dim_product_category
--       └── dim_supplier
-- =============================================================

-- Date dimension
CREATE TABLE dim_date (
    date_id   SERIAL PRIMARY KEY,
    full_date DATE    NOT NULL UNIQUE,
    year      INT     NOT NULL,
    month     INT     NOT NULL,
    day       INT     NOT NULL,
    quarter   INT     NOT NULL
);

-- Pet type sub-dimension (cat, dog, bird, …)
CREATE TABLE dim_pet_type (
    type_id   SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE
);

-- Pet breed sub-dimension (Labrador Retriever, Siamese, …)
CREATE TABLE dim_pet_breed (
    breed_id   SERIAL PRIMARY KEY,
    breed_name VARCHAR(100) NOT NULL UNIQUE
);

-- Customer dimension
CREATE TABLE dim_customer (
    customer_id SERIAL PRIMARY KEY,
    first_name  VARCHAR(100),
    last_name   VARCHAR(100),
    age         INT,
    email       VARCHAR(200) NOT NULL UNIQUE,
    country     VARCHAR(100),
    postal_code VARCHAR(20)
);

-- Pet sub-dimension (linked to customer; normalises type and breed)
CREATE TABLE dim_pet (
    pet_id      SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES dim_customer(customer_id),
    pet_name    VARCHAR(100),
    type_id     INT REFERENCES dim_pet_type(type_id),
    breed_id    INT REFERENCES dim_pet_breed(breed_id)
);

-- Seller dimension
CREATE TABLE dim_seller (
    seller_id   SERIAL PRIMARY KEY,
    first_name  VARCHAR(100),
    last_name   VARCHAR(100),
    email       VARCHAR(200) NOT NULL UNIQUE,
    country     VARCHAR(100),
    postal_code VARCHAR(20)
);

-- Store dimension
CREATE TABLE dim_store (
    store_id   SERIAL PRIMARY KEY,
    store_name VARCHAR(200),
    location   VARCHAR(100),
    city       VARCHAR(100),
    state      VARCHAR(100),
    country    VARCHAR(100),
    phone      VARCHAR(50),
    email      VARCHAR(200)
);

-- Product category sub-dimension (Food/Cats, Cage/Dogs, Toy/Birds, …)
CREATE TABLE dim_product_category (
    category_id   SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    pet_category  VARCHAR(100)
);

-- Supplier sub-dimension
CREATE TABLE dim_supplier (
    supplier_id   SERIAL PRIMARY KEY,
    supplier_name VARCHAR(200) NOT NULL,
    contact_name  VARCHAR(200),
    email         VARCHAR(200),
    phone         VARCHAR(50),
    address       VARCHAR(200),
    city          VARCHAR(100),
    country       VARCHAR(100)
);

-- Product dimension (linked to category and supplier)
CREATE TABLE dim_product (
    product_id   SERIAL PRIMARY KEY,
    product_name VARCHAR(200),
    category_id  INT REFERENCES dim_product_category(category_id),
    supplier_id  INT REFERENCES dim_supplier(supplier_id),
    price        NUMERIC(10, 2),
    quantity     INT,
    weight       NUMERIC(10, 2),
    color        VARCHAR(50),
    size         VARCHAR(50),
    brand        VARCHAR(100),
    material     VARCHAR(100),
    description  TEXT,
    rating       NUMERIC(3, 1),
    reviews      INT,
    release_date DATE,
    expiry_date  DATE
);

-- Sales fact table
CREATE TABLE fact_sales (
    sale_id          SERIAL PRIMARY KEY,
    customer_id      INT            NOT NULL REFERENCES dim_customer(customer_id),
    seller_id        INT            NOT NULL REFERENCES dim_seller(seller_id),
    product_id       INT            NOT NULL REFERENCES dim_product(product_id),
    store_id         INT            NOT NULL REFERENCES dim_store(store_id),
    date_id          INT            NOT NULL REFERENCES dim_date(date_id),
    sale_quantity    INT,
    sale_total_price NUMERIC(10, 2)
);
