
(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

type game_id = string
type game_player = game_id * address

(* potato is a ticket holding an amout in mutez
   gets passed around and the nat increases
*)
type stake = nat
type potato = stake ticket


type game_data =
[@layout:comb]
{
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    players: address list; (* 'array' of players as represented by their stakes, limited to 100 *)
    currently_holding: address option; (* before the game it is None, when the game starts this will be Something players[0] and is incremented when potato is passed *)
}

type new_game_data =
[@layout:comb]
{
    admin: address;
    start_time: timestamp; (* when the game will start *)
    game_id: game_id;
}

type storage =
[@layout:comb]
{
    games: (game_id, game_data) big_map;

    (* all addresses for a game_id should be either in 'players_left', 'currently_holding' or 'previously_help' for that game_id *)
    stakes: (game_player, stake) big_map;

    (* when the potato is passed the current holder's duration in milliseconds is put in here, and the next player is assigned to currently holding
       TODO might not need it, can derive from blockchain data
    *)
    durations: (game_player, nat) big_map;
}


type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Register_for_game of (game_id * stake) (* non-admin register for a game by commiting tez *)
| Start_game of game_id (* admin starts the game *)
| Pass_potato of game_id (* non-admin passes the potato *)
| Drop_potato of game_id (* admin signals run out of time *)
| End_game of game_id (* person holding the potato loses their stake, anyone who held and passed gets their weighted reward, anyone who didnt hold gets their money back *)

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
            let players : address list = [] in
            let durations : (game_player, nat) big_map = Big_map.empty in
            let currently_holding : address option = None in
            let game_data : game_data = {
                admin = admin;
                start_time = start_time;
                in_progress = false;
                players = players;
                currently_holding = currently_holding;
            } in
            let new_games = Big_map.add game_id game_data store.games in
            ( ([] : operation list), { store with games = new_games; } )
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
