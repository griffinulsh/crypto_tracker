open Lwt.Infix
open Cohttp_lwt_unix
open Yojson.Basic.Util
open Postgresql

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

(* Insert the fetched prices into PostgreSQL database using Lwt_preemptive to avoid blocking *)
let insert_prices_to_db conn btc_price eth_price sol_price bnb_price ada_price xrp_price dot_price =
  let query = Printf.sprintf
    "INSERT INTO prices (timestamp, btc_price, eth_price, sol_price, bnb_price, ada_price, xrp_price, dot_price) VALUES (NOW(), %f, %f, %f, %f, %f, %f, %f);"
    btc_price eth_price sol_price bnb_price ada_price xrp_price dot_price
  in
  Lwt_preemptive.detach (fun () -> ignore (conn#exec query)) ()  (* Run the database insertion in a non-blocking way *)

(* Fetch prices for multiple symbols concurrently *)
let fetch_multiple_prices symbols =
  Lwt_list.map_p (fun symbol ->
    fetch_binance_price symbol >|= fun price ->
    (symbol, price)  (* Return a tuple of the symbol and its fetched price *)
  ) symbols

(* Recursively fetch prices every specified interval (in seconds) *)
let rec fetch_repeatedly symbols conn interval =
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
  insert_prices_to_db conn btc_price eth_price sol_price bnb_price ada_price xrp_price dot_price >>= fun () ->
  Lwt_unix.sleep interval >>= fun () ->  (* Wait for the specified interval before repeating *)
  fetch_repeatedly symbols conn interval  (* Recur to fetch prices again *)

(* Main function to start fetching data *)
let () =
  let symbols = ["BTCUSDT"; "ETHUSDT"; "SOLUSDT"; "BNBUSDT"; "ADAUSDT"; "XRPUSDT"; "DOTUSDT"] in  (* List of symbols to fetch prices for *)
  let conninfo =
    let host = Sys.getenv_opt "DB_HOST" |> Option.value ~default:"localhost" in
    let dbname = Sys.getenv_opt "DB_NAME" |> Option.value ~default:"crypto_data" in
    let user = Sys.getenv_opt "DB_USER" |> Option.value ~default:"postgres" in
    let password = Sys.getenv_opt "DB_PASSWORD" |> Option.value ~default:"password" in
    Printf.sprintf "host=%s dbname=%s user=%s password=%s" host dbname user password
  in
  (* Create the connection and pass it to the fetch loop *)
  let conn = new connection ~conninfo () in
  Lwt_main.run (fetch_repeatedly symbols conn 5.0);
  conn#finish  (* Close the PostgreSQL connection when done *)
