FROM python:3.11-slim

WORKDIR /app

RUN pip install confluent-kafka

CMD ["python", "${PRODUCER}"]
