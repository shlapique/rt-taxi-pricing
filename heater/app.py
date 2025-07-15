import streamlit as st
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import plotly.graph_objects as go

import clickhouse_connect

import os
import time
from datetime import datetime, timedelta

HOST = os.getenv("CLICKHOUSE_HOST")
PORT = os.getenv("CLICKHOUSE_PORT")
USER = os.getenv("CLICKHOUSE_USER")
PASS = os.getenv("CLICKHOUSE_PASSWORD")
SOURCE_TABLE = os.getenv("CLICKHOUSE_SOURCE_TABLE")

UPDATE_INTERVAL = 10

st.title("Fares by region")

error_container = st.empty()

plot_container = st.empty()
text_container = st.empty()
warn_container = st.empty()
time_container = st.empty()

last_update_time = time.time()
fig = go.Figure()


def get_client(error_container):
    attempts = 0
    client = None
    while True:
        try:
            client = clickhouse_connect.get_client(host=HOST, port=PORT, user=USER, password=PASS)
            print(f"Connected to {HOST} on {PORT}")
            return client
        except Exception as e:
            attempts += 1
            error_container.error(f"Unable to connect -- host: {HOST}, port: {PORT}." 
                                  f"Retrying... Num. Attempts = {attempts}")
            time.sleep(15)

def check_data():
    query = f"""
    select count (*) from {SOURCE_TABLE} 
    """
    r = client.query_df(query)
    return r.iloc[0, 0]

def get_data(client):
    query = f"""
    select * from {SOURCE_TABLE} 
    order by window_start desc 
    limit 16
    """
    return client.query_df(query)

def fetch_and_plot(client, fig):
    table_size = check_data()
    text_container.write(f"Количество строк в таблице: {table_size}")
    
    if table_size >= 1:
        data = get_data(client)
        if not data.empty:
            warn_container.empty()
            data_pivot = pd.DataFrame(0, index=range(4), columns=range(4))
            txt_matrix = pd.DataFrame("", index=range(4), columns=range(4))
            for _, row in data.iterrows():
                grid_x = row['grid_x']
                grid_y = row['grid_y']
                fare = row['fare']
                taxis = row['taxis']
                if 0 <= grid_x < 4 and 0 <= grid_y < 4:
                    data_pivot.at[grid_y, grid_x] = fare
                    txt_matrix.at[grid_y, grid_x] = f"Fare: {fare}<br>Taxis: {taxis}"

            fig.update(data=[go.Heatmap(z=data_pivot.values, colorscale='OrRd',
                                        text=txt_matrix.values,
                                        hoverinfo="text")])
            plot_container.plotly_chart(fig, use_container_width=True, key=str(time.time()))
        else:
            plot_container.warning("Нет данных для отображения!")
    else:
        warn_container.warning("Не хватает данных для построения heatmap!" 
                               "Скорее всего, надо запустить Flink-джобу...")


def run():
    while True:
        time.sleep(UPDATE_INTERVAL)
        fetch_and_plot(client, fig)
        t = datetime.utcnow() + timedelta(hours=3)
        time_container.write(f"Updated: {t.strftime('%Y-%m-%d %H:%M:%S')}")

client = get_client(error_container)
fetch_and_plot(client, fig)
run()
