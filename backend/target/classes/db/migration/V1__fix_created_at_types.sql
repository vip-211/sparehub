BEGIN;

ALTER TABLE users
    ALTER COLUMN created_at TYPE timestamp(6) without time zone USING created_at::timestamp(6) without time zone,
    ALTER COLUMN updated_at TYPE timestamp(6) without time zone USING updated_at::timestamp(6) without time zone,
    ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE products
    ALTER COLUMN created_at TYPE timestamp(6) without time zone USING created_at::timestamp(6) without time zone,
    ALTER COLUMN updated_at TYPE timestamp(6) without time zone USING updated_at::timestamp(6) without time zone,
    ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE orders
    ALTER COLUMN created_at TYPE timestamp(6) without time zone USING created_at::timestamp(6) without time zone,
    ALTER COLUMN updated_at TYPE timestamp(6) without time zone USING updated_at::timestamp(6) without time zone,
    ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE payments
    ALTER COLUMN created_at TYPE timestamp(6) without time zone USING created_at::timestamp(6) without time zone,
    ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE retailer_inventory
    ALTER COLUMN created_at TYPE timestamp(6) without time zone USING created_at::timestamp(6) without time zone,
    ALTER COLUMN updated_at TYPE timestamp(6) without time zone USING updated_at::timestamp(6) without time zone,
    ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE notifications
    ALTER COLUMN created_at TYPE timestamp(6) without time zone USING created_at::timestamp(6) without time zone,
    ALTER COLUMN created_at SET DEFAULT now();

COMMIT;

