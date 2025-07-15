FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    streamlit \
    clickhouse-connect \
    seaborn \
    pandas \
    matplotlib \
    plotly

EXPOSE 8501

CMD ["streamlit", "run", "${APP}"]
