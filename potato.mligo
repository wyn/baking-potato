
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

  let make (timestamp : timestamp)  (stake : stake) : t = {timestamp=timestamp; stake=stake}

  let add (t : t) (other : t) : t =
      let ts : timestamp = if t.timestamp > other.timestamp then t.timestamp else other.timestamp in
      let s = t.stake + other.stake in
      { timestamp=ts; stake=s }


end

module Ts_array = struct

  type data = (nat, Ts_stake.t) map

  type t =
  {
      data: data;
      size: nat;
  }

  let empty : t =
      let data : data = Map.empty in
      {data=data; size=0n}

  let from_list (stakes : Ts_stake.t list) : t =
      let init : t = empty in
      let f (acc, item : t * Ts_stake.t) : t =
          let {data=data; size=size} = acc in
          let size_ = size + 1n in
          let data_ = Map.add size_ item data in
          {data=data_; size=size_}
      in
      List.fold_left f init stakes

  let sorted (t : t) : t =
      t

end


type ts_stakes = (address, Ts_stake.t) map
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
              let init : ts_stakes = Map.literal [(addr, (Ts_stake.make now stake))] in
              let new_stakes : ts_stakes = match (Big_map.find_opt game_id store.stakes) with
                  | None ->  init
                  | Some stakes -> begin
                    let n = Map.size stakes in
                    assert (n < _MAX_PLAYERS);
                    let f (acc, kyvl : ts_stakes * (address * Ts_stake.t)) : ts_stakes =
                        let (addr_, ts_) = kyvl in
                        match Map.find_opt addr_ acc with
                        | Some ts -> let ts = Ts_stake.add ts ts_ in Map.update addr_ (Some ts) acc
                        | None -> Map.add addr_ ts_ acc
                    in
                    Map.fold f stakes init
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
              if (Map.size stakes < 2n) then
                 (failwith "not enough players" : return)
              else
                (* let ts_arr : Ts_array.t = Ts_array.sorted (Ts_array.from_list stakes) in
                let get_address = fun (_i, ts : nat * ts_stake) -> ts.address in
                let players = Map.map get_address ts_arr.data in
                let new_game = { game with in_progress = true; players = players; currently_holding = 0n } in
                let new_games = Big_map.update game_id (Some new_game) store.games in
                (* TODO send potato to player0 *)
                ( ([] : operation list), {store with games = new_games} )
                *)
                ( ([] : operation list), store)
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
