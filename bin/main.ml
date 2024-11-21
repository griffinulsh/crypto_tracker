open Crypto_tracker

(* Entry point to start the real-time data fetching *)
let () =
  let symbols = ["BTCUSDT"; "ETHUSDT"; "SOLUSDT"; "BNBUSDT"; "ADAUSDT"; "XRPUSDT"; "DOTUSDT"] in
  Lwt_main.run (fetch_repeatedly symbols 5.0)  (* Start fetching prices every 5 seconds *)
