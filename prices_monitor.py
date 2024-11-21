import pandas as pd
import time

def read_latest_data(csv_file):
    try:
        df = pd.read_csv('csv_file')
    
        latest_row = df.iloc[-1]

        print(f"Timestamp: {latest_row['timestamp (date/time)']}, BTC Price: {latest_row['btc']}, ETH Price: {latest_row['eth']}, SOL Price: {latest_row['sol']}")

    except Exception as e:
        print(f"Error reading CSV: {e}")
    
if __name__ == "__main__":
    csv_file = "prices.csv"

    while True:
        read_latest_data(csv_file)
        time.sleep(5)