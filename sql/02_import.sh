#!/bin/bash
set -e

echo "=== Importing CSV data into staging_mock_data ==="

run_copy() {
    local file="$1"
    echo "Importing: $file"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
        "COPY staging_mock_data FROM '$file' WITH (FORMAT CSV, HEADER TRUE, QUOTE '\"', ENCODING 'UTF8');"
}

run_copy '/data/MOCK_DATA.csv'
run_copy '/data/MOCK_DATA (1).csv'
run_copy '/data/MOCK_DATA (2).csv'
run_copy '/data/MOCK_DATA (3).csv'
run_copy '/data/MOCK_DATA (4).csv'
run_copy '/data/MOCK_DATA (5).csv'
run_copy '/data/MOCK_DATA (6).csv'
run_copy '/data/MOCK_DATA (7).csv'
run_copy '/data/MOCK_DATA (8).csv'
run_copy '/data/MOCK_DATA (9).csv'

echo "=== Import complete. Total rows in staging: ==="
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
    "SELECT COUNT(*) AS total_rows FROM staging_mock_data;"
