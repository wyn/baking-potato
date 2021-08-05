#if !POTATO_WALLET
#define POTATO_WALLET

#include "types.mligo"

(* game types *)
type send_param =
  [@layout:comb]
  {destination : (pass_potato_param) contract;
   game_id : TicketBook.game_id}

type hot_potato_param =
  [@layout:comb]
  {
    destination : new_game_param contract;
    start_time : timestamp;
    max_players : nat;
  }

type parameter =
  (* make a new game (minting?) *)
  | HotPotato of hot_potato_param
  (* game ticket management *)
  | Receive of TicketBook.tkt
  | Send of send_param
  (* not sure need this really *)
  | SetCurrentGame of TicketBook.game_id

type storage =
  [@layout:comb]
  {
    admin : address; (* owner of this wallet *)
    tickets : TicketBook.t; (* the tickets this wallet has bought *)
    current_game_id : TicketBook.game_id option; (* pointer to current game ID *)
  }

type return = operation list * storage

let main (arg : parameter * storage) : return =
  begin
    assert (Tezos.amount = 0mutez);
    let (p, storage) = arg in
    let {admin = admin; tickets = tickets; current_game_id = current_game_id} = storage in
    ( match p with
      (* Kick off a new game for people to buy into,
         max_players denotes how many tickets in the ticket book
         for this game_id - the tickets actually get minted by the potato contract,
         that max limit is then enforced by the ticket semantics FOR EVER.
         Wallet owner becomes admin for that game_id *)
      | HotPotato hot_potato_param -> begin
        assert (Tezos.sender = admin);
        let new_game_param : new_game_param = {
            admin = admin;
            start_time = hot_potato_param.start_time;
            max_players = hot_potato_param.max_players;
        }
        in
        let op = Tezos.transaction new_game_param 0mutez hot_potato_param.destination in
        ([op], {admin = admin; tickets = tickets; current_game_id = current_game_id})
      end

      (* when receiving a ticket check whether this wallet has one similar and merge if nec *)
      | Receive ticket -> begin
        let ((_, (game, qty)), ticket) = Tezos.read_ticket ticket in
        assert (qty >= 1n);
        (* check if already have one for this game_id and join it if so *)
        (* NOTE we also update the current_game_id pointer *)
        let (tkt, tickets) = Big_map.get_and_update game.game_id (None : TicketBook.tkt option) tickets in
        match tkt with
        | None ->
            let (_, tickets) = Big_map.get_and_update game.game_id (Some ticket) tickets in
            (([] : operation list), {
                 admin = admin;
                 tickets = tickets;
                 current_game_id = (Some game.game_id);
            })
        | Some tkt ->
            match (Tezos.join_tickets (ticket, tkt)) with
            | None -> (failwith Errors.potato_WRONG_GAME : return)
            | Some book ->
                let (_, tickets) = Big_map.get_and_update game.game_id (Some book) tickets in
                (([] : operation list), {
                     admin = admin;
                     tickets = tickets;
                     current_game_id = (Some game.game_id);
                })
        end

      (* when sending a ticket back to the game, note self as the winner,
         time ordering will work out who is the actual winner.
         Anyone left holding a ticket after the game ends will have one that says 'loser',
         anyone that managed to hand their's back will no longer have one - but there is only ever one winner *)
      | Send send -> begin
        (*assert (Tezos.sender = admin) ;*)
        let addr = Tezos.sender in
        let (ticket, tickets) = TicketBook.get send.game_id tickets in
        ( match ticket with
          | None -> (failwith Errors.potato_NOT_IN_GAME : return)
          | Some ticket ->
              let op = Tezos.transaction {game_id=send.game_id; ticket=ticket; winner=addr} 0mutez send.destination in
              ([op], {
                  admin = admin;
                  tickets = tickets;
                  current_game_id = (None : TicketBook.game_id option);
              })
        )
      end

      (* check if this wallet is playing in game_id and if so, set that to the current_game_id *)
      | SetCurrentGame game_id -> begin
        let (tkt, tickets) = TicketBook.get game_id tickets in
        match tkt with
        | None -> (failwith Errors.potato_NOT_IN_GAME : return)
        | Some tkt ->
          let (_, tickets) = Big_map.get_and_update game_id (Some tkt) tickets in
          (([] : operation list), {
               admin = admin;
               tickets = tickets;
               current_game_id = (Some game_id);
          })
      end

    )
  end


(* (Pair "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" {} None) *)
let sample_storage : storage = {
  admin = ("tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" : address);
  tickets = TicketBook.empty;
  current_game_id = (None : TicketBook.game_id option);
}


#endif
