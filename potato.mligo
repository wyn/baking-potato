
(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

(* potato is a ticket holding the durations as a nat
   gets passed around and the nat increases
*)
type game_id = string
type tkt = game_id ticket

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
}

type storage =
[@layout:comb]
{
    game_data: game_data;

    tickets: (nat, tkt) big_map; (* one ticket holding N things per game *)
}


type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Buy_ticket_for_game of (tkt contract) (* non-admin register for a game by buying a ticket *)
(*
| Start_game of game_id (* admin starts the game *)
| Pass_potato of game_id (* non-admin passes the potato (ticket) back *)
| End_game of game_id (* winner is person who held the longest but gave back before game ended *)
*)
type return = operation list * storage

let main (action, store: parameter * storage) : return =
begin
    let {game_data = game_data; tickets = tickets} = store in
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {game_id = game_id; admin = admin; start_time = start_time; max_players = max_players; } = new_game_data in
            assert (Tezos.sender = admin);
            assert (now < start_time);
            assert (max_players > 2n);
            let game_data : game_data = {
                game_id = game_id;
                admin = admin;
                start_time = start_time;
                in_progress = false;
            } in
            let ticket = Tezos.create_ticket game_id max_players in
            let (_, tickets) = Big_map.get_and_update 0n (Some ticket) tickets in
            ( ([] : operation list), { game_data = game_data; tickets=tickets } )
        end

      | Buy_ticket_for_game _send_to -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            assert (addr <> game_data.admin);
            assert (now < game_data.start_time);
            assert (not game_data.in_progress);
            ( ([] : operation list), { game_data = game_data; tickets=tickets } )

      end
(*
      | Start_game game_id -> begin
            let now = Tezos.now in
            match (Big_map.find_opt game_id store.games, Big_map.find_opt game_id store.stakes) with
            | (None, _) -> (failwith "no game" : return)
            | (_, None) -> (failwith "no stakes" : return)
            | (Some game, Some stakes) -> begin
              let addr = Tezos.sender in
              assert (addr = game.admin);
              assert (now >= game.start_time);
              assert (not game.in_progress);
              (* stakes is a list {
                            address: address;
                            timestamp: timestamp;
                            stake: nat;
              }
              need to sort by stake and then timestamp
              *)
              if (Map.size stakes < 2n) then
                 (failwith "not enough players" : return)
              else begin
                let f (x : Ts_array.el) (y : Ts_array.el) : bool = if x.stake = y.stake then x.timestamp > y.timestamp else x.stake > y.stake in
                let players : address_array = Ts_array.to_address_array (Ts_array.sort_by f (Ts_array.from_addresses stakes)) in
                let new_game = { game with in_progress = true; players = players; currently_holding = 0n } in
                let new_games = Big_map.update game_id (Some new_game) store.games in
                (* TODO send potato to player0 *)
                let potato = Tezos.create_ticket ([] : duration list) 1n in
                let op = Tezos.transaction ticket 0mutez
                ( ([] : operation list), {store with games = new_games} )
              end
            end
      end

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
