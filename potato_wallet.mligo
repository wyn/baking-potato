#if !POTATO_WALLET
#define POTATO_WALLET

#include "types.mligo"

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


type send_parameter =
  [@layout:comb]
  {destination : (pass_potato_param) contract;
   game_id : TicketBook.game_id}

type game_parameter =
  [@layout:comb]
  {
    destination : new_game_param contract;
    game_id : TicketBook.game_id;
    start_time : timestamp;
    max_players : nat;
  }

type balance_of_request =
[@layout:comb]
{
  owner : address;
  game_id : TicketBook.game_id;
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


type parameter =
  (* FA2 stuff first *)
  | Transfer of transfer list
  | Balance_of of balance_of_param
  | Update_operators of update_operator list
  (* game ticket management *)
  | Receive of TicketBook.tkt
  | Send of send_parameter
  (* make a new game (minting?) *)
  | HotPotato of game_parameter
  (* not sure need this *)
  | SetCurrentGame of TicketBook.game_id

type storage =
  [@layout:comb]
  {
    admin : address;
    all_games : (address, TicketBook.game_id set) big_map;
    tickets : TicketBook.t;
    current_game_id : TicketBook.game_id option; (* TODO use this to +=1 to make new game ids *)
  }

type return = operation list * storage

let main (arg : parameter * storage) : return =
  begin
    assert (Tezos.amount = 0mutez);
    let (p, storage) = arg in
    let {admin = admin; all_games = all_games; tickets = tickets; current_game_id = current_game_id} = storage in
    ( match p with

      (* FA2 spec relates to games *)

      | Transfer transfers -> begin
      (* games are NFTs too *)
      (* transfering must take it out this owners slot and put it into new owners slot *)
      (* amount has to be 0 or 1 *)
      (* NOTE also there are some standard errors *)
        (([] : operation list), {admin = admin; all_games = all_games; tickets = tickets; current_game_id = current_game_id})
      end

      | Balance_of bp -> begin
        let _get_balance (req : balance_of_request) : balance_of_response =
            let zero_balance = {request=req; balance=0n} in
            let one_balance = {request=req; balance=1n} in
            match Big_map.find_opt req.owner all_games with
            | Some games -> if Set.mem req.game_id games then one_balance else zero_balance
            | None -> zero_balance
        in
        let resps = List.map _get_balance bp.requests in
        let op = Tezos.transaction resps 0mutez bp.callback in
        ([op], {admin = admin; all_games = all_games; tickets = tickets; current_game_id = current_game_id})
      end

      | Update_operators _ -> (failwith "NOT IMPLEMENTED" : return)

      (* the rest relates to tickets in games *)

      | Receive ticket -> begin
        let ((_,(game, qty)), ticket) = Tezos.read_ticket ticket in
        assert (qty >= 1n);
        (* TODO check if already have one for this game_id and join it if so *)
        let (_, tickets) = Big_map.get_and_update game.game_id (Some ticket) tickets in
        (([] : operation list), {
             admin = admin;
             all_games = all_games;
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
              let op = Tezos.transaction {ticket=ticket; winner=addr} 0mutez send.destination in
              ([op], {
                  admin = admin;
                  all_games = all_games;
                  tickets = tickets;
                  current_game_id = (None : TicketBook.game_id option);
              })
        )
      end

      | HotPotato game_parameters -> begin
        assert (Tezos.sender = admin);
        let new_game_param : new_game_param = {
            game_id = game_parameters.game_id;
            admin = admin;
            start_time = game_parameters.start_time;
            max_players = game_parameters.max_players;
        }
        in
        let game_ids : TicketBook.game_id set =
            match Big_map.find_opt admin all_games with
            | Some game_ids -> begin
                match Set.mem game_parameters.game_id game_ids with
                | true -> (failwith "Game exists all ready" : TicketBook.game_id set)
                | false -> game_ids
            end
            | None -> begin
                let game_ids = (Set.empty : TicketBook.game_id set) in
                Set.add game_parameters.game_id game_ids
            end
        in
        let all_games = Big_map.add admin game_ids all_games in
        let op = Tezos.transaction new_game_param 0mutez game_parameters.destination in
        ([op], {admin = admin; all_games = all_games; tickets = tickets; current_game_id = current_game_id})
      end

      | SetCurrentGame game_id -> begin
        let (tkt, tickets) = TicketBook.get game_id tickets in
        match tkt with
        | None -> (failwith "not in game" : return)
        | Some tkt ->
          let (_, tickets) = Big_map.get_and_update game_id (Some tkt) tickets in
          (([] : operation list), {
               admin = admin;
               all_games = all_games;
               tickets = tickets;
               current_game_id = (Some game_id);
          })
      end

    )
  end


(* (Pair "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" {} None {}) *)
let sample_storage : storage = {
  admin = ("tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb" : address);
  all_games = (Big_map.empty : (address, TicketBook.game_id set) big_map);
  tickets = TicketBook.empty;
  current_game_id = (None : TicketBook.game_id option);
}


#endif
