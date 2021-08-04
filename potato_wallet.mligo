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
  (* game ticket management *)
  | Receive of TicketBook.tkt
  | Send of send_param
  (* make a new game (minting?) *)
  | HotPotato of hot_potato_param
  (* not sure need this *)
  | SetCurrentGame of TicketBook.game_id

type storage =
  [@layout:comb]
  {
    admin : address;
    tickets : TicketBook.t; (* the tickets this wallet has bought *)
    current_game_id : TicketBook.game_id option;
  }

type return = operation list * storage

let main (arg : parameter * storage) : return =
  begin
    assert (Tezos.amount = 0mutez);
    let (p, storage) = arg in
    let {admin = admin; tickets = tickets; current_game_id = current_game_id} = storage in
    ( match p with

      (* FA2 spec relates to games *)
(*
      | Transfer transfers -> begin
          (([] : operation list), {admin = admin; tickets = tickets; current_game_id = current_game_id})
      end

      | Balance_of bp -> begin
        let _get_balance (req : balance_of_request) : balance_of_response =
            let zero_balance = {request=req; balance=0n} in
            let one_balance = {request=req; balance=1n} in
            match Big_map.find_opt req.owner all_games with
            | Some games -> if Set.mem req.token_id games then one_balance else zero_balance
            | None -> zero_balance
        in
        let resps = List.map _get_balance bp.requests in
        let op = Tezos.transaction resps 0mutez bp.callback in
        ([op], {admin = admin; tickets = tickets; current_game_id = current_game_id})
      end

      | Update_operators _ -> (failwith "NOT IMPLEMENTED" : return)
*)
      (* the rest relates to tickets in games *)

      | Receive ticket -> begin
        let ((_, (game, qty)), ticket) = Tezos.read_ticket ticket in
        assert (qty >= 1n);
        (* TODO check if already have one for this game_id and join it if so *)
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
            | None -> (failwith "Wrong game" : return)
            | Some book ->
                let (_, tickets) = Big_map.get_and_update game.game_id (Some book) tickets in
                (([] : operation list), {
                     admin = admin;
                     tickets = tickets;
                     current_game_id = (Some game.game_id);
                })
        end

      | Send send -> begin
        (*assert (Tezos.sender = admin) ;*)
        let addr = Tezos.sender in
        let (ticket, tickets) = TicketBook.get send.game_id tickets in
        ( match ticket with
          | None -> (failwith "not in game" : return)
          | Some ticket ->
              let op = Tezos.transaction {game_id=send.game_id; ticket=ticket; winner=addr} 0mutez send.destination in
              ([op], {
                  admin = admin;
                  tickets = tickets;
                  current_game_id = (None : TicketBook.game_id option);
              })
        )
      end

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

      | SetCurrentGame game_id -> begin
        let (tkt, tickets) = TicketBook.get game_id tickets in
        match tkt with
        | None -> (failwith "not in game" : return)
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


(* (Pair "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" {} None {}) *)
let sample_storage : storage = {
  admin = ("tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" : address);
  tickets = TicketBook.empty;
  current_game_id = (None : TicketBook.game_id option);
}


#endif
