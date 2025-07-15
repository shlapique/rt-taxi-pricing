import os
import json
from confluent_kafka import Producer
import time

TOPIC_NAME = os.getenv("TOPIC")
FILE_PATH = os.getenv("DATA")


def real_time_produce(producer, topic, file_path):
    batch = []
    current_timestamp = None

    with open(file_path, 'r') as f:
        for line in f:
            event = json.loads(line.strip())
            event_timestamp = event['timestamp']

            if current_timestamp is None:
                current_timestamp = event_timestamp

            if event_timestamp == current_timestamp:
                batch.append(event)
            else:
                for e in batch:
                    producer.produce(topic, value=json.dumps(e))
                producer.flush()

                wait_time = event_timestamp - current_timestamp
                time.sleep(wait_time)

                batch = [event]
                current_timestamp = event_timestamp

        if batch:
            for e in batch:
                producer.produce(topic, value=json.dumps(e))
            producer.flush()


if __name__ == "__main__":
    conf = {'bootstrap.servers': 'kafka:9092'}
    producer = Producer(conf)
    topic = TOPIC_NAME
    file = FILE_PATH

    while True:
        print(f'Streaming file: {file}')
        real_time_produce(producer, topic, file)
        time.sleep(10)
