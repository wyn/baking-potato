type game_id = string;
type stake = (nat ticket); (* a stake is a ticket holding an amout in mutez *)

type game_data =
[@layout:comb]
{
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    players_left: (address list); (* before the start all players are in 'players_left' *)
    currently_holding: (address option); (* when the game starts the first player is moved to here *)
    previously_held: (address, timestamp) big_map; (* when the potato is passed the current holder is put in here, and the next play is assigned to currently holding *)
}

type new_game_data =
[@layout:comb]
{
    game_id: game_id;
    admin: address;
    start_time: timestamp; (* when the game will start *)
}

type storage =
[@layout:comb]
{
    data: (game_id, game_data) big_map;
    stakes: (game_id * address, stake) big_map; (* all addresses for a game_id should be either in 'players_left', 'currently_holding' or 'previously_help' for that game_id *)
}


type parameter =
| New_game of game_id * timestamp (* admin opens a new game for people to register up to *)
| Register_for_game of (game_id * stake) (* non-admin register for a game by commiting tez *)
| Start_game of game_id (* admin starts the game *)
| Pass_potato of game_id (* non-admin passes the potato *)
| Drop_potato of game_id (* admin signals run out of time *)
| End_game of game_id (* person holding the potato loses their stake, anyone who held and passed gets their weighted reward, anyone who didnt hold gets their money back *)

type return = operation list * storage

let main (action, store: parameter * storage) : return =
begin
    let {data = data; stakes = stakes} = store in
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {game_id = game_id; admin = admin; start_time = start_time } = new_game_data in
            assert (Tezos.source = admin);
            assert (not Big_map.mem game_id data);
            assert (now < start_time);
            let previously_held : (address, timestamp) big_map = Big_map.empty in
            let game_data : game_data = {
                admin = admin;
                start_time = start_time;
                in_progress = false;
                players_left = [];
                currently_holding = None;
                previously_help = previously_held;
            } in
            let new_data = Big_map.add game_id game_data data in
            ( ([] : operation list), { data = new_data; stakes = stakes } )
        end
    )

end
