#if !TYPES
#define TYPES
(* potato is a ticket holding the game ID as string
   each one gets passed to players at start,
   then passed back to try and win
*)

module TicketBook = struct
    type game_id = string
    type game =
    [@layout:comb]
    {
      game_id: game_id;
      loser: bool;
    }

    type tkt = game ticket
    type t = (game_id, tkt) big_map

    let empty : t = Big_map.empty

    let create_with (game_id : game_id) (max_players : nat) (t : t) : t =
        let game = {game_id = game_id; loser = true} in
        let tkt = Tezos.create_ticket game max_players in
        let (_, t) = Big_map.get_and_update game_id (Some tkt) t in
        t

    let get (game_id : game_id) (t : t) : (tkt option)*t =
        let (tkt, t) = Big_map.get_and_update game_id (None : tkt option) t in
        (tkt, t)

end

type new_game_data =
[@layout:comb]
{
    game_id: TicketBook.game_id;
    admin: address;
    start_time: timestamp; (* when the game will start *)
    max_players: nat; (* max number players *)
}

type game_data =
[@layout:comb]
{
    game_id: TicketBook.game_id; (* this game *)
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    num_players: nat;
    winner: address option;
    game_over: bool;
}
#endif
