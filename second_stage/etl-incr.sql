-- SQL script that will:
-- 1/ update dimension tables
-- Car dimension
DO $$
DECLARE
  car_cursor
  CURSOR FOR
    SELECT *
    FROM   staging.car_info_upd;BEGIN
  FOR new_car IN car_cursor
  LOOP
    UPDATE PUBLIC.dim_car
    SET    valid_to = timestamp '2023-04-01 12:00:00',
           "current_row" = 'inactive'
    WHERE  NOT isfinite(valid_to)
    AND    car_key = new_car.car_key;

    INSERT INTO PUBLIC.dim_car
                (
                            car_key,
                            company_key,
                            license_plate,
                            make,
                            color,
                            tonnage,
                            "type",
                            valid_from,
                            valid_to,
                            "current_row"
                )
                VALUES
                (
                            new_car.car_key,
                            cast(new_car.company_key AS INTEGER),
                            new_car.license_plate,
                            new_car.make,
                            new_car.color,
                            cast(new_car.tonnage AS REAL),
                            new_car.TYPE,
                            timestamp '2023-04-01 12:00:00',
                            'infinity',
                            'active'
                );

  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Date dimension
INSERT INTO PUBLIC.dim_date
            ("day",
             "month",
             "year",
             quarter,
             day_of_week,
             "date")
SELECT Extract('Day' FROM Date("time")),
       Extract('Month' FROM Date("time")),
       Extract('Year' FROM Date("time")),
       Extract('Quarter' FROM Date("time")),
       Extract('DOW' FROM Date("time")),
       Date("time")
FROM   staging.fact_status_upd
WHERE  Date("time") NOT IN (SELECT "date"
                            FROM   PUBLIC.dim_date)
GROUP  BY Date("time");

-- 2/ inserts new facts
INSERT INTO PUBLIC.fact_status
            (company_id,
             car_id,
             driver_id,
             time_id,
             date_id,
             operator_id,
             device_name,
             sim_imsi,
             program_ver,
             tracking_mode,
             "time",
             pos_gps,
             operator_changed,
             app_run_time,
             dev_run_time,
             battery_level,
             conn_count)
SELECT COALESCE(comp.company_id, -1),
       COALESCE(car.car_id, -1),
       COALESCE(driver.driver_id, -1),
       "time".time_id,
       "date".date_id,
       COALESCE(op.operator_id, -1),
       device_name,
       sim_imsi,
       program_ver,
       Cast(tracking_mode AS INTEGER),
       f.time,
       Point(pos_gps_lat, pos_gps_lon),
       operator_changed,
       app_run_time,
       dev_run_time,
       Cast(battery_level AS INTEGER),
       conn_count
FROM   staging.fact_status_upd AS f
       LEFT JOIN PUBLIC.dim_car AS car
              ON f.car_key = car.car_key
       LEFT JOIN PUBLIC.dim_company AS comp
              ON car.company_key = comp.company_key
       LEFT JOIN PUBLIC.dim_driver AS driver
              ON f.driver_key = driver.driver_key
       LEFT JOIN PUBLIC.dim_time AS "time"
              ON Cast(Date_trunc('minutes', f.time) AS TIME) = "time"."time"
       LEFT JOIN PUBLIC.dim_date AS "date"
              ON Date(f.time) = "date"."date"
       LEFT JOIN PUBLIC.dim_operator AS op
              ON f.gsmnet_id = op.mcc
                               || op.mnc
WHERE  ( f.time BETWEEN car.valid_from AND car.valid_to
          OR car.current_row = 'active' OR car.car_key IS NUll)
       AND ( f.time BETWEEN comp.valid_from AND comp.valid_to
              OR comp.current_row = 'active' OR comp.company_key IS NULL)
       AND ( f.time BETWEEN driver.valid_from AND driver.valid_to
              OR driver.current_row = 'active' OR driver.driver_key IS NULL)
	   AND f.time IS NOT NULL;
