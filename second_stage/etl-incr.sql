-- SQL script that will:
-- 1/ update dimension tables
DO $$

DECLARE car_cursor CURSOR FOR
        SELECT * FROM staging.car_info_upd;

BEGIN
    FOR new_car in car_cursor LOOP
        UPDATE public.dim_car
        SET valid_to = TIMESTAMP '2023-04-01 12:00:00', "current_row" =  'inactive'
        WHERE NOT isfinite(valid_to) AND car_key = new_car.car_key;

        INSERT INTO public.dim_car (car_key, company_key, license_plate, make, color, tonnage, "type", valid_from, valid_to, "current_row")
        VALUES (new_car.car_key,
            CAST(new_car.company_key AS INTEGER), new_car.license_plate, new_car.make, new_car.color, CAST(new_car.tonnage AS REAL), new_car.type,
            TIMESTAMP '2023-04-01 12:00:00', 'infinity', 'active');
    END LOOP;
END;

$$ LANGUAGE PLPGSQL;

-- 2/ inserts new facts

-- It must be able to run as is, i.e., psql <etl-incr.sql

-- This script may not be "idempotent", so you may not include commands for "new data cleanup"

-- car_info_upd
-- fact_status_upd
--
