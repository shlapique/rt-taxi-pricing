CREATE TABLE ride_requests (
    `details` ROW(`client_id` BIGINT, 
    `pickup_location` ROW(`x` DOUBLE, `y` DOUBLE), 
    `dropoff_location` ROW(`x` DOUBLE, `y` DOUBLE), 
    `order_id` BIGINT),
    `timestamp` DOUBLE,
    `event_time` AS TO_TIMESTAMP_LTZ(`timestamp` * 1000, 3),
    `event_type` STRING,
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '10' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ride_req',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'ride_req_group',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);

CREATE TABLE ride_done (
    `details` ROW(`client_id` BIGINT, 
    `pickup_location` ROW(`x` DOUBLE, `y` DOUBLE), 
    `status` STRING,
    `dropoff_location` ROW(`x` DOUBLE, `y` DOUBLE), 
    `order_id` BIGINT),
    `timestamp` DOUBLE,
    `event_time` AS TO_TIMESTAMP_LTZ(`timestamp` * 1000, 3),
    `event_type` STRING,
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '10' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ride_done',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'ride_done_group',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);

CREATE TABLE telemetry (
    `details` ROW(`id` BIGINT, 
    `location` ROW(`x` DOUBLE, `y` DOUBLE), 
    `state` STRING),
    `timestamp` DOUBLE,
    `event_time` AS TO_TIMESTAMP_LTZ(`timestamp` * 1000, 3),
    `event_type` STRING,
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '10' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'telem',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'telem_group',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);

SET 'execution.runtime-mode' = 'streaming';
SET 'sql-client.execution.result-mode' = 'tableau';

-- REQEST
SELECT
    grid_x,
    grid_y,
    window_start,
    completed_rides_count,
    request_count,
    CASE
        WHEN completed_rides_count = 0 THEN 1000 -- Высокая стоимость при отсутствии поездок
        ELSE 10 + (request_count / completed_rides_count) * 50
    END AS fare
FROM (
    SELECT
        rd.grid_x,
        rd.grid_y,
        rd.window_start,
        rd.completed_rides_count,
        COALESCE(rr.request_count, 0) AS request_count
    FROM (
        SELECT
            FLOOR(details.pickup_location.x / 2000) AS grid_x,
            FLOOR(details.pickup_location.y / 2000) AS grid_y,
            COUNT(*) AS completed_rides_count,
            TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS window_start
        FROM ride_done
        WHERE details.status = 'completed'
        GROUP BY 
            FLOOR(details.pickup_location.x / 2000),
            FLOOR(details.pickup_location.y / 2000),
            TUMBLE(event_time, INTERVAL '1' MINUTE)
    ) AS rd
    LEFT JOIN (
        SELECT
            FLOOR(details.pickup_location.x / 2000) AS grid_x,
            FLOOR(details.pickup_location.y / 2000) AS grid_y,
            COUNT(*) AS request_count,
            TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS window_start
        FROM ride_requests
        GROUP BY 
            FLOOR(details.pickup_location.x / 2000),
            FLOOR(details.pickup_location.y / 2000),
            TUMBLE(event_time, INTERVAL '1' MINUTE)
    ) AS rr
    ON rd.grid_x = rr.grid_x 
       AND rd.grid_y = rr.grid_y 
       AND rd.window_start = rr.window_start
);
