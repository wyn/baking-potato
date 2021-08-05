#if !TYPES
#define TYPES

(* potato is a ticket holding the game ID as Nat and loser flag
   each individual ticket in the ticketbook gets passed to players at start,
   then passed back to try and win,
   last one to pass back before the game ends is the winner
*)

module TicketBook = struct
    type game_id = nat
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

    let burn (game_id : game_id) (t : t) : t =
        let t = Big_map.update game_id (None : tkt option) t in
        t

    let next_game (game_id : game_id) : game_id = game_id + 1n

    (*
    let join_key : int = -1

    let join (game_id : game_id) (t : t) : t =
        let (tkt, t) = Big_map.get_and_update game_id (None : tkt option) t in
        let (potato, t) = Big_map.get_and_update (join_key game_id) (None : tkt option) t in
        match (tkt, potato) with
          | (None, _) -> (failwith "ticket does not exist" : t)
          | (_, None) -> (failwith "join ticket does not exist" : t)
          | (Some tkt, Some potato) -> begin
            match Tezos.join_tickets (tkt, potato) with
            | None -> (failwith "Wrong game" : t)
            | Some book ->
              let (_, t) = Big_map.get_and_update game_id (Some book) t in
              t
          end
          *)
end

type new_game_param =
[@layout:comb]
{
    admin: address;
    start_time: timestamp; (* when the game will start *)
    max_players: nat; (* max number players *)
}

type buy_potato_param =
[@layout:comb]
{
    game_id : TicketBook.game_id;
    dest : (TicketBook.tkt contract);
}

type pass_potato_param =
[@layout:comb]
{
    game_id : TicketBook.game_id;
    ticket: TicketBook.tkt;
    winner: address;
}

(* FA2 stuff - FA2 token is the game itself, tickets take care of potato passing semantics *)
type transfer_destination =
[@layout:comb]
{
  to_ : address;
  token_id : TicketBook.game_id;
  amount : nat;
}

type transfer =
[@layout:comb]
{
  from_ : address;
  txs : transfer_destination list;
}

type balance_of_request =
[@layout:comb]
{
  owner : address;
  token_id : TicketBook.game_id;
}

type balance_of_response =
[@layout:comb]
{
  request : balance_of_request;
  balance : nat;
}

type balance_of_param =
[@layout:comb]
{
  requests : balance_of_request list;
  callback : (balance_of_response list) contract;
}

type operator_param =
[@layout:comb]
{
  owner : address;
  operator : address;
  token_id : TicketBook.game_id;
}

type update_operator =
  [@layout:comb]
  | Add_operator of operator_param
  | Remove_operator of operator_param

module Errors = struct
    let fa2_INSUFFICIENT_BALANCE = "FA2_INSUFFICIENT_BALANCE"
    let fa2_TOKEN_UNDEFINED = "FA2_TOKEN_UNDEFINED"
    let fa2_NOT_OPERATOR = "FA2_NOT_OPERATOR"

    let potato_BAD_CONTRACT = "Contract does not match"
    let potato_NO_GAME_DATA = "No game data"
    let potato_WRONG_GAME = "Wrong game"
    let potato_NO_TICKET = "Ticket does not exist"
    let potato_EMPTY_TICKETBOOK = "Out of tickets"
end


#endif
