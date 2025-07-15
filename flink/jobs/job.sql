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

CREATE TABLE fares (
    `grid_x` DOUBLE,
    `grid_y` DOUBLE,
    `window_start` TIMESTAMP(3),
    `taxis` BIGINT,
    `orders` BIGINT,
    `fare` BIGINT
) WITH (
    'connector' = 'kafka',
    'topic' = 'fares',
    'properties.bootstrap.servers' = 'kafka:9092',
    'format' = 'json'
);

INSERT INTO fares
SELECT
    COALESCE(telem_counts.grid_x, req_counts.grid_x) as grid_x,
    COALESCE(telem_counts.grid_y, req_counts.grid_y) as grid_y,
    COALESCE(telem_counts.window_start, req_counts.window_start) AS window_start,
    telem_counts.taxi_count as taxis,
    req_counts.order_count as orders,
    8000 * NULLIF(req_counts.order_count, 0) / NULLIF(telem_counts.taxi_count, 1) AS fare
FROM (
    SELECT
        FLOOR(details.location.x / 2000) AS grid_x,
        FLOOR(details.location.y / 2000) AS grid_y,
        TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS window_start,
        COUNT(*) as taxi_count
    FROM telemetry
    WHERE details.state = 'idle'
    GROUP BY 
        FLOOR(details.location.x / 2000),
        FLOOR(details.location.y / 2000),
        TUMBLE(event_time, INTERVAL '1' MINUTE)
    ) as telem_counts

    JOIN (

    SELECT
        FLOOR(details.pickup_location.x / 2000) AS grid_x,
        FLOOR(details.pickup_location.y / 2000) AS grid_y,
        TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS window_start,
        COUNT(*) as order_count
    FROM ride_requests
    GROUP BY 
        FLOOR(details.pickup_location.x / 2000),
        FLOOR(details.pickup_location.y / 2000),
        TUMBLE(event_time, INTERVAL '1' MINUTE)
    ) as req_counts

    ON telem_counts.grid_x = req_counts.grid_x 
    AND telem_counts.grid_y = req_counts.grid_y 
    AND telem_counts.window_start = req_counts.window_start;
