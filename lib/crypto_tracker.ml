open Lwt.Infix
open Cohttp_lwt_unix
open Yojson.Basic.Util

(* Fetch the current price for a specific symbol from Binance API *)
let fetch_binance_price symbol =
  let url = "https://api.binance.us/api/v3/ticker/price?symbol=" ^ symbol in  (* Construct the URL for the Binance API with the given symbol *)
  Client.get (Uri.of_string url) >>= fun (_, body) ->  (* Make an asynchronous GET request to the constructed URL *)
  Cohttp_lwt.Body.to_string body >|= fun json_string ->  (* Convert the HTTP response body to a string *)
  let json = Yojson.Basic.from_string json_string in  (* Parse the JSON string into a Yojson object *)
  match json |> member "price" |> to_option to_string with  (* Extract the "price" field from the JSON *)
  | Some price_str -> float_of_string price_str  (* Convert the "price" value from string to float if it exists *)
  | None ->  (* Handle the case where "price" field is missing or null *)
      Printf.printf "Error: 'price' field missing or null for symbol: %s\n" symbol;
      nan  (* Return NaN to indicate failure *)

(* Write the fetched prices to a CSV file *)
let write_prices_to_csv filename btc_price eth_price sol_price bnb_price ada_price xrp_price dot_price =
  let time_now () =
    let tm = Unix.localtime (Unix.gettimeofday ()) in
    Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
      (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec  (* Format the timestamp as YYYY-MM-DD HH:MM:SS *)
  in
  let header_written = Sys.file_exists filename && (Unix.stat filename).st_size > 0 in  (* Check if the file exists and is non-empty *)
  let oc = open_out_gen [Open_creat; Open_text; Open_append] 0o666 filename in
  if not header_written then Printf.fprintf oc "timestamp (date/time),btc,eth,sol,bnb,ada,xrp,dot\n";  (* Write header if the file is new or empty *)
  Printf.fprintf oc "%s,%f,%f,%f,%f,%f,%f,%f\n" (time_now ()) btc_price eth_price sol_price bnb_price ada_price xrp_price dot_price;  (* Write the formatted timestamp, prices of all coins *)
  close_out oc  (* Close the CSV file *)


(* Fetch prices for multiple symbols concurrently *)
let fetch_multiple_prices symbols =
  Lwt_list.map_p (fun symbol ->
    fetch_binance_price symbol >|= fun price ->
    (symbol, price)  (* Return a tuple of the symbol and its fetched price *)
  ) symbols

(* Recursively fetch prices every specified interval (in seconds) *)
let rec fetch_repeatedly symbols interval =
  fetch_multiple_prices symbols >>= fun prices ->  (* Fetch prices for all symbols *)
  List.iter (fun (symbol, price) ->
    Printf.printf "Current price of %s: %f\n" symbol price  (* Print the fetched price for each symbol *)
  ) prices;
  let btc_price = List.assoc "BTCUSDT" prices in
  let eth_price = List.assoc "ETHUSDT" prices in
  let sol_price = List.assoc "SOLUSDT" prices in
  let bnb_price = List.assoc "BNBUSDT" prices in
  let ada_price = List.assoc "ADAUSDT" prices in
  let xrp_price = List.assoc "XRPUSDT" prices in
  let dot_price = List.assoc "DOTUSDT" prices in
  write_prices_to_csv "prices.csv" btc_price eth_price sol_price bnb_price ada_price xrp_price dot_price;  (* Log the fetched prices to a CSV file *)
  Lwt_unix.sleep interval >>= fun () ->  (* Wait for the specified interval before repeating *)
  fetch_repeatedly symbols interval  (* Recur to fetch prices again *)


(* Main function to start fetching data *)
let () =
let symbols = ["BTCUSDT"; "ETHUSDT"; "SOLUSDT"; "BNBUSDT"; "ADAUSDT"; "XRPUSDT"; "DOTUSDT"]  in  (* List of symbols to fetch prices for *)
  Lwt_main.run (fetch_repeatedly symbols 5.0)  (* Start fetching prices every 5 seconds *)
