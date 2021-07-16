
(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

(* potato is a ticket holding the durations as a nat
   gets passed around and the nat increases
*)
type duration =
{
    address: address;
    milliseconds: nat;
}
type potato = duration list ticket

type stake = nat

module Ts_stake = struct
  type t =
  {
    timestamp: timestamp;
    stake: stake;
  }

  let add (t, other : t * t) : t =
      let ts : timestamp = if t.timestamp > other.timestamp then t.timestamp else other.timestamp in
      let s = t.stake + other.stake in
      { timestamp=ts; stake=s }


end

type ts_stake =   {
     address: address;
     timestamp: timestamp;
     stake: stake;
}

type ts_stakes = ts_stake list

module Ts_array = struct

  type data = (nat, ts_stake) map

  type t =
  {
      data: data;
      size: nat;
  }

  let empty : t =
      let data : data = Map.empty in
      {data=data; size=0n}

  let from_list (stakes : ts_stakes) : t =
      let init : (nat*data) = (0n, empty.data) in
      let f (iacc, item : (nat*data) * ts_stake) : (nat*data) =
          let (i, acc) = iacc in
          let acc_ = Map.add i item acc in
          let i_ = i + 1n in
          (i_, acc_)
      in
      let iret : (nat*data) = List.fold_left f init stakes in
      let (i, ret) = iret in
      {data=ret; size=i}

  let sorted (t : t) : t =
      t

end

type address_array = (nat, address) map
type game_id = string

type new_game_data =
[@layout:comb]
{
    admin: address;
    start_time: timestamp; (* when the game will start *)
    game_id: game_id;
}

type game_data =
[@layout:comb]
{
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    players: address_array; (* 'array' of players as represented by their stakes, limited to _MAX_PLAYERS, gets set when game starts, ordered by stake and timestamp *)
    currently_holding: nat; (* when the game starts this will be 0 ie players[0] and index is incremented when potato is passed *)
}

type storage =
[@layout:comb]
{
    games: (game_id, game_data) big_map;

    stakes: (game_id, ts_stakes) big_map;
}


type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Register_for_game of (game_id * stake) (* non-admin register for a game by commiting tez *)
| Start_game of game_id (* admin starts the game *)
| Pass_potato of game_id (* non-admin passes the potato *)
| End_game of game_id (* person holding the potato loses their stake, anyone who held and passed gets their weighted reward, anyone who didnt hold loses their money *)

type return = operation list * storage

let main (action, store: parameter * storage) : return =
let _MAX_PLAYERS : nat = 10n in
begin
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {admin = admin; start_time = start_time; game_id = game_id; } = new_game_data in
            assert (Tezos.sender = admin);
            assert (not Big_map.mem game_id store.games);
            assert (now < start_time);
            let players : address_array = Map.empty in
            let game_data : game_data = {
                admin = admin;
                start_time = start_time;
                in_progress = false;
                players = players;
                currently_holding = 0n;
            } in
            let new_games = Big_map.add game_id game_data store.games in
            ( ([] : operation list), { store with games = new_games } )
        end

      | Register_for_game (game_id, stake) -> begin
            let now = Tezos.now in
            match (Big_map.find_opt game_id store.games) with
            | None -> (failwith "no game" : return)
            | Some game -> begin
              let addr = Tezos.sender in
              assert (addr <> game.admin);
              assert (now < game.start_time);
              assert (not game.in_progress);
              let ts_new_stake : ts_stake = {address=addr; timestamp=now; stake=stake} in
              let new_stakes = match (Big_map.find_opt game_id store.stakes) with
                  | None ->  [ts_new_stake]
                  | Some stakes -> begin
                    let n = List.length stakes in
                    assert (n <= _MAX_PLAYERS);
                    let f (merged, ts_old: (ts_stake * ts_stakes) * ts_stake) : (ts_stake * ts_stakes) =
                        let (ts_merged, others) = merged in
                        match ts_old.address = addr with
                        | true -> ({ts_merged with timestamp = now; stake = stake + ts_old.stake}, others)
                        | false -> (ts_merged, ts_old :: others)
                    in
                    let tss : ts_stakes = [] in
                    let init : (ts_stake * ts_stakes) = (ts_new_stake, tss) in
                    let (ts, others) : (ts_stake * ts_stakes) = List.fold_left f init stakes in
                    ts :: others
                  end
              in
              let new_stakes = Big_map.update game_id (Some new_stakes) store.stakes in
              ( ([] : operation list), {store with stakes = new_stakes} )
            end
      end

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
              match stakes with
              | [] -> (failwith "not enough players" : return)
              | [_] -> (failwith "not enough players, only one" : return)
              | stakes ->
                let ts_arr : Ts_array.t = Ts_array.sorted (Ts_array.from_list stakes) in
                let get_address = fun (_i, ts : nat * ts_stake) -> ts.address in
                let players = Map.map get_address ts_arr.data in
                let new_game = { game with in_progress = true; players = players; currently_holding = 0n } in
                let new_games = Big_map.update game_id (Some new_game) store.games in
                (* TODO send potato to player0 *)
                ( ([] : operation list), {store with games = new_games} )
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
              (* TODO work out reqards and distribute to players who held *)
              ( ([] : operation list), store )
            end
      end
    )

end
