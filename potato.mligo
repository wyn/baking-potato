#if !POTATO
#define POTATO

(* #include "thirdparty/fa2/shared/fa2/fa2_interface.mligo" *)
#include "types.mligo"

(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

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


type game_data =
[@layout:comb]
{
    game_id: TicketBook.game_id; (* this game *)
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    num_players: nat; (* number of currently registered players *)
    winner: address option;
    game_over: bool;
}

type game_storage =
[@layout:comb]
{
    data: (TicketBook.game_id, game_data) big_map;

    tickets: TicketBook.t; (* multiple ticket books each of which is holding N things per game *)

    next_game_id : TicketBook.game_id;
}

type parameter =
    (* FA2 stuff first *)
    (*| Transfer of transfer list
    | Balance_of of balance_of_param
    | Update_operators of update_operator list*)
    | New_game of new_game_param (* admin opens a new game for people to register up to *)
    | Buy_potato_for_game of buy_potato_param (* non-admin register for a game by buying a potato *)
    | Start_game of TicketBook.game_id (* admin starts the game *)
    | Pass_potato of pass_potato_param (* non-admin passes the potato (ticket) back *)
    | End_game of TicketBook.game_id (* admin ends game, winner is last person to give back before end of game *)

type return = operation list * game_storage

let main (action, store: parameter * game_storage) : return =
begin
    let {data = data; tickets = tickets; next_game_id = next_game_id} = store in
    ( match action with
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
      | New_game new_game_param -> begin
            (*let now = Tezos.now in*)
            assert (not Big_map.mem next_game_id data);
            let {admin = admin; start_time = start_time; max_players = max_players; } = new_game_param in
            (*assert (Tezos.sender = admin);*)
            (*assert (now < start_time);*)
            assert (max_players > 2n);
            let winner : address option = None in
            let game_data : game_data = {
                game_id = next_game_id;
                admin = admin;
                start_time = start_time;
                in_progress = false;
                num_players = 0n;
                winner = winner;
                game_over = false;
            } in
            let data = Big_map.add next_game_id game_data data in
            let tickets = TicketBook.create_with next_game_id max_players tickets in
            ( ([] : operation list), { data = data; tickets=tickets; next_game_id = (next_game_id + 1n) } )
        end

      | Buy_potato_for_game buy_potato_param -> begin
            match (Big_map.find_opt buy_potato_param.game_id data) with
            | None -> (failwith "No game data" : return)
            | Some game_data -> begin
                (*let now = Tezos.now in*)
                assert (buy_potato_param.game_id = game_data.game_id);
                let addr = Tezos.sender in
                let purchase_price = Tezos.amount in
                assert (purchase_price = 10tez);
                assert (addr <> game_data.admin);
                (*assert (now < game_data.start_time);*)
                assert (not game_data.in_progress);
                assert (not game_data.game_over);
                let (tkt, tickets) = TicketBook.get game_data.game_id tickets in
                match tkt with
                  | None -> (failwith "ticket does not exist" : return)
                  | Some tkt ->
                    let ((_addr, (game, amt)), tkt) = Tezos.read_ticket tkt in
                    match (game.game_id = game_data.game_id, Tezos.split_ticket tkt (1n, abs(amt-1n))) with
                    | (false, _) -> (failwith "Wrong game" : return)
                    | (true, None) -> (failwith "Out of tickets" : return)
                    | (true, Some (tkt, book)) ->
                      let op = Tezos.transaction tkt 0mutez buy_potato_param.dest in
                      let (_, tickets) = Big_map.get_and_update game_data.game_id (Some book) tickets in
                      let game_data = {game_data with num_players = game_data.num_players + 1n} in
                      let data = Big_map.update game_data.game_id (Some game_data) data in
                      ([op], {data = data; tickets = tickets; next_game_id = next_game_id})
            end
      end

      | Start_game game_id -> begin
            match (Big_map.find_opt game_id data) with
            | None -> (failwith "No game data" : return)
            | Some game_data -> begin
                assert (game_id = game_data.game_id);
                (*let now = Tezos.now in *)
                (*let addr = Tezos.sender in *)
                (*assert (addr = game_data.admin);*)
                (*assert (now >= game_data.start_time);*)
                assert (not game_data.in_progress);
                assert (game_data.num_players >= 1n);
                assert (not game_data.game_over);
                let game_data = {game_data with in_progress = true} in
                let data = Big_map.update game_id (Some game_data) data in
                ( ([] : operation list), {data = data ; tickets = tickets; next_game_id = next_game_id} )
            end
      end

      | Pass_potato potato -> begin
            let {game_id = game_id; ticket=ticket; winner=winner} = potato in
            match (Big_map.find_opt game_id data) with
            | None -> (failwith "No game data" : return)
            | Some game_data -> begin
                assert (game_id = game_data.game_id);
                (*let now = Tezos.now in*)
                assert (winner <> game_data.admin);
                (*assert (now >= game_data.start_time);*)
                assert (game_data.in_progress);
                assert (game_data.num_players >= 1n);
                assert (not game_data.game_over);
                let (tkt, tickets) = TicketBook.get game_id tickets in
                match tkt with
                  | None -> (failwith "ticket does not exist" : return)
                  | Some tkt ->
                    let ((_addr, (game, _amt)), tkt) = Tezos.read_ticket tkt in
                    match (game_id = game.game_id, Tezos.join_tickets (ticket, tkt)) with
                    | (false, _) -> (failwith "Wrong game" : return)
                    | (true, None) -> (failwith "Wrong game" : return)
                    | (true, Some book) ->
                      let (_, tickets) = Big_map.get_and_update game_id (Some book) tickets in
                      let game_data = {game_data with winner = (Some winner)} in
                      let data = Big_map.update game_id (Some game_data) data in
                      ( ([] : operation list), {data = data ; tickets = tickets; next_game_id = next_game_id} )
            end
      end

      | End_game game_id -> begin
            match (Big_map.find_opt game_id data) with
            | None -> (failwith "No game data" : return)
            | Some game_data -> begin
                assert (game_id = game_data.game_id);
                (*let now = Tezos.now in*)
                (*let addr = Tezos.sender in*)
                let winnings = game_data.num_players * 10tez in
                (*assert (addr = game_data.admin);*)
                (*assert (now >= game_data.start_time);*)
                assert (game_data.in_progress);
                assert (not game_data.game_over);
                let game_data = {game_data with game_over = true} in
                let data = Big_map.update game_id (Some game_data) data in
                let (_, tickets) = TicketBook.get game_id tickets in
                match (game_data.winner) with
                  | None -> ( ([] : operation list), {data = data ; tickets = tickets; next_game_id = next_game_id} )
                  | Some winner ->
                    match ((Tezos.get_contract_opt winner) : unit contract option) with
                      | None -> (failwith "contract does not match" : return)
                      | Some c -> let op1 = Tezos.transaction () winnings c in
                        ( [op1], {data = data ; tickets = tickets; next_game_id = next_game_id} )
            end
      end

    )

end

(* (Pair None {} 0n) *)
let sample_storage : game_storage = {
    data = (Big_map.empty : (TicketBook.game_id, game_data) big_map);
    tickets = TicketBook.empty;
    next_game_id = 0n;
}


(*


let test =
    let _check_game_data = fun (actual : game_data) (expected : game_data) ->
        let _ = assert (actual.game_id = expected.game_id) in
        let _ = assert (actual.admin = expected.admin) in
        let _ = assert (actual.start_time = expected.start_time) in
        let _ = assert (actual.in_progress = expected.in_progress) in
        let _ = assert (actual.num_players = expected.num_players) in
        let _ = assert (actual.winner = expected.winner) in
        let _ = assert (actual.game_over = expected.game_over) in
        ()
    in
    let admin = ("tz1KqTpEZ7Yob7QbPE4Hy4Wo8fHG8LhKxZSx" : address) in
    let _ = Test.set_source admin in
    let init_data = {
        game_id = "";
        admin = admin;
        start_time = ("2021-07-26t15:45:10Z" : timestamp);
        in_progress = false;
        num_players = 0n;
        winner = (None : address option);
        game_over = false;
    } in
    let init_tickets : (game_id, TicketBook.tkt) big_map = Big_map.empty in
    let init_storage = { data = (None : game_data option); tickets = init_tickets } in
    let (taddr, _, _) = Test.originate main init_storage 0tez in
    let actual = Test.get_storage taddr in
    let _ = _check_game_data actual.data init_data in
    let _ = assert (false = Big_map.mem "game01" actual.tickets) in

    let c = Test.to_contract taddr in
    let new_game_param = {
        game_id = "game01";
        admin = admin;
        start_time = ("2021-07-26t16:45:10Z" : timestamp);
        max_players = 10n;
    } in
    let () = Test.transfer_to_contract_exn c (New_game new_game_param) 1mutez in
    let actual = Test.get_storage taddr in
    let _ = _check_game_data actual.data init_data in
    ()
*)
#endif
