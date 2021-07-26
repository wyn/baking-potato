
(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

(* potato is a ticket holding the durations as a nat
   gets passed around and the nat increases
*)
type game_id = string
type tkt_book = game_id ticket

type new_game_data =
[@layout:comb]
{
    game_id: game_id;
    admin: address;
    start_time: timestamp; (* when the game will start *)
    max_players: nat; (* max number players *)
}

type game_data =
[@layout:comb]
{
    game_id: game_id; (* this game *)
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    num_players: nat;
}

type storage =
[@layout:comb]
{
    data: game_data;

    tickets: (game_id, tkt_book) big_map; (* one ticket holding N things per game *)
}


type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Buy_ticket_for_game of (tkt_book contract) (* non-admin register for a game by buying a ticket *)
| Start_game (* admin starts the game *)
(*
| Pass_potato of game_id (* non-admin passes the potato (ticket) back *)

| End_game of game_id (* winner is person who held the longest but gave back before game ended *)
*)
type return = operation list * storage

let main (action, store: parameter * storage) : return =
begin
    let {data = data; tickets = tickets} = store in
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {game_id = game_id; admin = admin; start_time = start_time; max_players = max_players; } = new_game_data in
            assert (Tezos.sender = admin);
            assert (now < start_time);
            assert (max_players > 2n);
            let data : game_data = {
                game_id = game_id;
                admin = admin;
                start_time = start_time;
                in_progress = false;
                num_players = 0n;
            } in
            let ts = Tezos.create_ticket game_id max_players in
            let (_, tickets) = Big_map.get_and_update game_id (Some ts) tickets in
            ( ([] : operation list), { data = data; tickets=tickets } )
        end

      | Buy_ticket_for_game send_to -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            let purchase_price = Tezos.amount in
            assert (addr <> data.admin);
            assert (now < data.start_time);
            assert (not data.in_progress);
            assert (purchase_price = 1tez);
            match ((Tezos.get_contract_opt data.admin) : unit contract option) with
              | None -> (failwith "contract does not match" : return)
              | Some c -> let op1 = Tezos.transaction () purchase_price c in
                  let (t, tickets) = Big_map.get_and_update data.game_id (None : tkt_book option) tickets in
                  match t with
                    | None -> (failwith "ticket does not exist" : return)
                    | Some t ->
                      let ((_addr,(game_id, amt)), t) = Tezos.read_ticket t in
                      match (game_id = data.game_id, Tezos.split_ticket t (1n, abs(amt-1n))) with
                      | (false, _) -> (failwith "Wrong game" : return)
                      | (true, None) -> (failwith "Out of tickets" : return)
                      | (true, Some (t, ts)) ->
                        let op2 = Tezos.transaction t 0mutez send_to in
                        let (_, tickets) = Big_map.get_and_update data.game_id (Some ts) tickets in
                        ([op1; op2], {data = {data with num_players = data.num_players + 1n}; tickets = tickets; })
      end
      | Start_game -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            assert (addr = data.admin);
            assert (now >= data.start_time);
            assert (not data.in_progress);
            assert (data.num_players > 1n);
            ( ([] : operation list), {data = {data with in_progress = true}; tickets = tickets} )
      end
(*

      | Pass_potato game_id -> begin
            let now = Tezos.now in
            match (Big_map.find_opt game_id store.games) with
            | None -> (failwith "no game" : return)
            | Some game -> begin
              let addr = Tezos.sender in
              assert (addr <> game.admin);
              assert (now >= game.start_time);
              assert (game.in_progress);
              let new_game = { game with currently_holding = game.currently_holding + 1n } in
              let new_games = Big_map.update game_id (Some new_game) store.games in
              (* TODO record duration for playerN and send potato to playerN+1 *)
              ( ([] : operation list), {store with games = new_games} )
            end
      end

      | End_game game_id -> begin
            let now = Tezos.now in
            match (Big_map.find_opt game_id store.games) with
            | None -> (failwith "no game" : return)
            | Some game -> begin
              let addr = Tezos.sender in
              assert (addr = game.admin);
              assert (now >= game.start_time);
              assert (game.in_progress);
              (* TODO work out rewards and distribute to players who held *)
              (* delete the game data and stakes for this game *)
              let games = Big_map.update game_id (None : game_data option) store.games in
              let stakes = Big_map.update game_id (None : ts_stakes option) store.stakes in
              ( ([] : operation list), {games=games; stakes=stakes})
            end
      end *)
    )

end
