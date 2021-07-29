#if !POTATO_WALLET
#define POTATO_WALLET

#include "types.mligo"

type send_parameter =
  [@layout:comb]
  {destination : (TicketBook.tkt*address) contract;
   game_id : TicketBook.game_id}

type receive_parameter = TicketBook.tkt

type metadata = (string, bytes) map

type token_metadata = (TicketBook.game_id, (TicketBook.game_id * metadata)) big_map

type game_parameter =
  [@layout:comb]
  {
    destination : new_game_data contract;
    game_id : TicketBook.game_id;
    start_time : timestamp;
    max_players : nat;
  }

type parameter =
  | Receive of receive_parameter
  | Send of send_parameter
  | HotPotato of game_parameter
  | SetCurrentGame of TicketBook.game_id

type storage =
  [@layout:comb]
  {
    admin : address;
    tickets : TicketBook.t;
    current_game_id : TicketBook.game_id option;
    token_metadata :  token_metadata
  }

type return = operation list * storage

let main (arg : parameter * storage) : return =
  begin
    assert (Tezos.amount = 0mutez);
    let (p, storage) = arg in
    let {admin = admin ; tickets = tickets; current_game_id = current_game_id; token_metadata = token_metadata} = storage in
    ( match p with
      | Receive ticket -> begin
        let ((_,(game, qty)), ticket) = Tezos.read_ticket ticket in
        assert (qty >= 1n);
        (* TODO check if already have one for this game_id and join it if so *)
        let (_, tickets) = Big_map.get_and_update game.game_id (Some ticket) tickets in
        (([] : operation list), {
             admin = admin;
             tickets = tickets;
             current_game_id = (Some game.game_id);
             token_metadata = token_metadata
        })
        end

      | Send send -> begin
        (*assert (Tezos.sender = admin) ;*)
        let addr = Tezos.sender in
        let (ticket, tickets) = TicketBook.get send.game_id tickets in
        ( match ticket with
          | None -> (failwith "not in game" : return)
          | Some ticket ->
              let op = Tezos.transaction (ticket, addr) 0mutez send.destination in
              ([op], {
                  admin = admin;
                  tickets = tickets;
                  current_game_id = (None : TicketBook.game_id option);
                  token_metadata = token_metadata
              })
        )
      end

      | HotPotato game_parameters -> begin
        assert (Tezos.sender = admin);
        let new_game_params : new_game_data = {
            game_id = game_parameters.game_id;
            admin = admin;
            start_time = game_parameters.start_time;
            max_players = game_parameters.max_players;
        } in
        let op = Tezos.transaction new_game_params 0mutez game_parameters.destination in
        ([op], {admin = admin; tickets = tickets; current_game_id = current_game_id; token_metadata = token_metadata})
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
               token_metadata = token_metadata
          })
      end

    )
  end


(* (Pair "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" {} None {}) *)
let sample_storage : storage = {
  admin = ("tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" : address);
  tickets = TicketBook.empty;
  current_game_id = (None : TicketBook.game_id option);
  token_metadata = (Big_map.empty : (TicketBook.game_id, (TicketBook.game_id * metadata)) big_map);
(*  metadata  = Big_map.literal [
    ("", Bytes.pack "tezos-storage:content" );
    (* ("", 0x74657a6f732d73746f726167653a636f6e74656e74); *)
    ("content", 0x00) (* bytes encoded UTF-8 JSON *)
  ];*)
}


#endif
