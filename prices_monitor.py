import pandas as pd
import time

def read_latest_data(csv_file):
    try:
        df = pd.read_csv(csv_file)  # Use the csv_file variable instead of the literal string
    
        latest_row = df.iloc[-1]  # Get the latest row of the DataFrame

        # Print the latest prices for each symbol
        print(f"Timestamp: {latest_row['timestamp (date/time)']}, BTC Price: {latest_row['btc']}, ETH Price: {latest_row['eth']}, SOL Price: {latest_row['sol']}")

    except Exception as e:
        print(f"Error reading CSV: {e}")
    
if __name__ == "__main__":
    csv_file = "prices.csv"  # Define the file name to be read

    while True:
        read_latest_data(csv_file)  # Read the latest data from the CSV
        time.sleep(5)  # Wait for 5 seconds before reading again
