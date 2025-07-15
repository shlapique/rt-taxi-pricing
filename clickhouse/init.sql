CREATE TABLE fares_kafka (
    grid_x Float64,
    grid_y Float64,
    window_start DateTime,
    taxis Int64,
    orders Int64,
    fare Int64
) ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list = 'fares',
         kafka_group_name = 'fares_consumer_group',
         kafka_format = 'JSONEachRow',
         kafka_num_consumers = 1;

CREATE TABLE fares_final (
    grid_x Float64,
    grid_y Float64,
    window_start DateTime,
    taxis Int64,
    orders Int64,
    fare Int64
) ENGINE = ReplacingMergeTree(window_start)
ORDER BY (grid_x, grid_y);

CREATE MATERIALIZED VIEW fares_mv TO fares_final AS
SELECT *
FROM (
    SELECT *, rowNumberInAllBlocks() AS row_num
    FROM fares_kafka 
    ORDER BY window_start DESC
)
WHERE row_num <= 16;
