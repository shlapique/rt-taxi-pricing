FROM flink:1.20.0

WORKDIR /app

RUN apt-get update && apt-get install -y python3 python3-pip \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install apache-flink
RUN curl -o /opt/flink/lib/flink-sql-connector-kafka-3.3.0-1.20.jar \
    https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.3.0-1.20/flink-sql-connector-kafka-3.3.0-1.20.jar
