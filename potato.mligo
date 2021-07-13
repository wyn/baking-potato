
(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

type game_id = string
type game_player = game_id * address
type address_array = (nat, address) map

(* potato is a ticket holding an amout in mutez
   gets passed around and the nat increases
*)
type stake = nat
type potato = stake ticket
type timestamped_stake = timestamp * stake

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
    players: address_array; (* 'array' of players as represented by their stakes, limited to _MAX_PLAYERS *)
    currently_holding: nat; (* when the game starts this will be 0 ie players[0] and index is incremented when potato is passed *)
}

type storage =
[@layout:comb]
{
    games: (game_id, game_data) big_map;

    (* all addresses for a game_id should be either in 'players', 'currently_holding' or 'durations' for that game_id *)
    stakes: (game_player, timestamped_stake) big_map;

    (* when the potato is passed the current holder's duration in milliseconds is put in here, and the next player is assigned to currently holding
       TODO might not need it, can derive from blockchain data - though probably more reliable to keep track here
    *)
    durations: (game_player, nat) big_map;
}


type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Register_for_game of (game_id * stake) (* non-admin register for a game by commiting tez *)
| Start_game of game_id (* admin starts the game *)
| Pass_potato of game_id (* non-admin passes the potato *)
| Drop_potato of game_id (* admin signals run out of time *)
| End_game of game_id (* person holding the potato loses their stake, anyone who held and passed gets their weighted reward, anyone who didnt hold loses their money *)

type return = operation list * storage

let main (action, store: parameter * storage) : return =
let _MAX_PLAYERS : nat = 50n in
begin
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {admin = admin; start_time = start_time; game_id = game_id; } = new_game_data in
            assert (Tezos.source = admin);
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
            let durations : (game_player, nat) big_map = Big_map.empty in
            ( ([] : operation list), { store with games = new_games; durations = durations} )
        end

      | Register_for_game (game_id, stake) ->
            ( ([] : operation list), store )

      | Start_game game_id ->
            ( ([] : operation list), store )

      | Pass_potato game_id ->
            ( ([] : operation list), store )

      | Drop_potato game_id ->
            ( ([] : operation list), store )

      | End_game game_id ->
            ( ([] : operation list), store )
    )

end
