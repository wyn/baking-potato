
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
    address: address;
  }

  let make (timestamp : timestamp)  (stake : stake) (addr : address) : t = {timestamp=timestamp; stake=stake; address=addr}

  let _add (other : t) (t : t) : t =
      let ts : timestamp = if t.timestamp > other.timestamp then t.timestamp else other.timestamp in
      let s = t.stake + other.stake in
      { t with timestamp=ts; stake=s }

  let add (other : t) (t : t) : t option =
      if t.address = other.address then Some (_add other t) else None

  let add_exn (other : t) (t : t) : t = begin
      assert (t.address = other.address);
      _add other t
  end


end

type address_array = (nat, address) map

module Ts_array = struct

  type el = Ts_stake.t
  type data = (nat, el) map

  type t =
  {
      data: data;
      size: nat;
  }

  let empty : t =
      let data : data = Map.empty in
      {data=data; size=0n}

  let from_list (stakes : el list) : t =
      let init : t = empty in
      let f (acc, item : t * el) : t =
          let {data=data; size=size} = acc in
          let size_ = size + 1n in
          let data_ = Map.add size_ item data in
          {data=data_; size=size_}
      in
      List.fold_left f init stakes

  let from_addresses (stakes : (address, el) map) : t =
      let init : t = empty in
      let f (acc, kyvl : t * (address * el)) : t =
          let {data=data; size=size} = acc in
          let (_addr, item) = kyvl in
          let size_ = size + 1n in
          let data_ = Map.add size_ item data in
          {data=data_; size=size_}
      in
      Map.fold f stakes init


  let get (i : nat) (t : t) : el option = begin
      Map.find_opt i t.data
  end

  let to_address_array (t : t) : address_array =
      let init : address_array = Map.empty in
      let f (acc, kyvl : address_array * (nat * el)) : address_array =
          let (ky, vl) = kyvl in
          Map.add ky vl.address acc
      in
      Map.fold f t.data init

  let to_list (t : t) : el list =
      let init : el list = [] in
      let init : el list * nat = (init, 0n) in
      let f (acc, _kyvl : (el list * nat) * (nat * el)) : el list * nat =
          let (xs, i) = acc in
          match (Map.find_opt i t.data) with
          | Some x -> (x :: xs, i+1n)
          | None -> (xs, i+1n)
      in
      let (ls, _i) = Map.fold f t.data init in
      ls

  let _swap (i : nat) (j : nat) (t : t) : t = begin
      assert (i < t.size);
      assert (j < t.size);
      let data = if (i = j) then t.data else begin
         let jval = Map.find_opt i t.data in
         let (ival, data_) = Map.get_and_update i jval t.data in
         Map.update j ival data_
      end
      in
      {t with data=data}
  end

  let sort_by (f : el -> el -> bool) (t : t) : t =
      t

end


type ts_stakes = (address, Ts_stake.t) map
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
              let init : ts_stakes = Map.literal [(addr, (Ts_stake.make now stake addr))] in
              let new_stakes : ts_stakes = match (Big_map.find_opt game_id store.stakes) with
                  | None ->  init
                  | Some stakes -> begin
                    let n = Map.size stakes in
                    assert (n < _MAX_PLAYERS);
                    let f (acc, kyvl : ts_stakes * (address * Ts_stake.t)) : ts_stakes =
                        let (addr_, ts_) = kyvl in
                        match Map.find_opt addr_ acc with
                        | Some ts -> let ts_merged = Ts_stake.add ts_ ts in Map.update addr_ ts_merged acc
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
              else begin
                let f (x : Ts_array.el) (y : Ts_array.el) : bool = if x.stake = y.stake then x.timestamp > y.timestamp else x.stake > y.stake in
                let players : address_array = Ts_array.to_address_array (Ts_array.sort_by f (Ts_array.from_addresses stakes)) in
                let new_game = { game with in_progress = true; players = players; currently_holding = 0n } in
                let new_games = Big_map.update game_id (Some new_game) store.games in
                (* TODO send potato to player0 *)
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
              (* TODO work out reqards and distribute to players who held *)
              (* delete the game data and stakes for this game *)
              let games = Big_map.update game_id (None : game_data option) store.games in
              let stakes = Big_map.update game_id (None : ts_stakes option) store.stakes in
              ( ([] : operation list), {games=games; stakes=stakes})
            end
      end
    )

end
