#if !POTATO
#define POTATO

#include "types.mligo"

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

type all_game_data = (TicketBook.game_id, game_data) big_map

type game_storage =
[@layout:comb]
{
    data: all_game_data;

    tickets: TicketBook.t; (* multiple ticket books each of which is holding N things per game *)

    next_game_id : TicketBook.game_id;
}

type parameter =
    (* FA2 stuff first *)
    | Transfer of transfer list
    | Balance_of of balance_of_param
    | Update_operators of update_operator list
    (* potato ticket stuff *)
    | New_game of new_game_param (* admin opens a new game for people to register up to *)
    | Buy_potato_for_game of buy_potato_param (* non-admin register for a game by buying a potato *)
    | Start_game of TicketBook.game_id (* admin starts the game *)
    | Pass_potato of pass_potato_param (* non-admin passes the potato (ticket) back *)
    | End_game of TicketBook.game_id (* admin ends game, winner is last person to give back before end of game *)

type return = operation list * game_storage

type flattened_key = address*address*TicketBook.game_id
type flattened = (flattened_key, nat) map

let main (action, store: parameter * game_storage) : return =
begin
    let {data = data; tickets = tickets; next_game_id = next_game_id} = store in
    ( match action with
      (* FA2 spec relates to games *)

      | Transfer transfers -> begin
          (* NOTE it is important not to modify any of data - a big_map - until
             we know that it is ok to do so.
             Hence strategy is to check everything up front first then
             do a final edit pass on the transfers
             *)

          (* some quick checks before bigger stuff *)
          let _all_token_ids_exist (acc, tdest : bool*transfer_destination) : bool =
              acc && (Big_map.mem tdest.token_id data)
          in

          (* have to be ==0 or 1 as the game is like an NFT too *)
          let _all_amounts_ok_pass1 (acc, tdest : bool*transfer_destination) : bool =
              acc && (tdest.amount < 2n)
          in
          (* this function applies the two quick checkers to the inner lists of each transfer *)
          let quick_check (t : transfer) : unit =
              let token_ids_ok = List.fold _all_token_ids_exist t.txs true in
              let amounts_ok = List.fold _all_amounts_ok_pass1 t.txs true in
              match (token_ids_ok, amounts_ok) with
              | (true, true) -> () (* NOTE this needs to come first *)
              | (false, _) -> (failwith Errors.fa2_TOKEN_UNDEFINED : unit)
              | (_, false) -> (failwith Errors.fa2_INSUFFICIENT_BALANCE : unit)
          in
          let _u : unit = List.iter quick_check transfers in

          (* bigger stuff - flatten down to (from, to, token_id) -> accumulated amount map *)
          let _flatten (from_ : address) (acc, tdest : flattened*transfer_destination) : flattened =
              let key = (from_, tdest.to_, tdest.token_id) in
              let amount_ = match Map.find_opt key acc with
                  | Some amount_ -> amount_ + tdest.amount
                  | None -> 0n
              in
              Map.update key (Some amount_) acc
          in

          let all_amounts = List.fold (
                  fun (acc, t : flattened*transfer) -> List.fold (_flatten t.from_) t.txs acc
              ) transfers (Map.empty : flattened)
          in

          (* can now check accumulated amounts for each to/from/game_id tuple
             and also that the from address is the current owner of the game
          *)
          let full_check ((from_, _to, game_id), amount_ : flattened_key*nat) : unit =
              (* not quite same as before as this is an accumulated total now *)
              if amount_ > 1n then (failwith Errors.fa2_INSUFFICIENT_BALANCE : unit) else
              match Big_map.find_opt game_id data with
              | None -> (failwith Errors.fa2_TOKEN_UNDEFINED : unit) (* same as before but have to deal with it again *)
              | Some game ->
                  (* only allow current admin to send non-zero amounts of their own stuff *)
                  if from_ <> game.admin then
                     if amount_ > 0n then (failwith Errors.fa2_NOT_OPERATOR : unit) else ()
                  else ()
          in
          let _u : unit = Map.iter full_check all_amounts in

          (* Now is safe to edit data - go over one more time to modify admin address if amount_ == 1
             NOTE have to do this after checking everything as dont want to partially change data *)
          let change_admin (acc, ((_from, to_, game_id), amount_) : all_game_data*(flattened_key*nat)) : all_game_data =
              if amount_ = 0n then acc else
              match Big_map.find_opt game_id acc with
              | None -> acc
              | Some game ->
                    let game = {game with admin = to_} in
                    Big_map.update game_id (Some game) acc
          in
          let data = Map.fold change_admin all_amounts data in
          (([] : operation list), {data = data; tickets = tickets; next_game_id = next_game_id})
      end

      | Balance_of bp -> begin
          let _all_token_ids_exist (acc, req : bool*balance_of_request) : bool =
              acc && (Big_map.mem req.token_id data)
          in
          let _get_balance (req : balance_of_request) : balance_of_response =
              let zero_balance = {request=req; balance=0n} in
              let one_balance = {request=req; balance=1n} in
              match Big_map.find_opt req.token_id data with
              | Some game -> if req.owner = game.admin then one_balance else zero_balance
              | None -> zero_balance
          in
          match (List.fold _all_token_ids_exist bp.requests true) with
          | false -> (failwith Errors.fa2_TOKEN_UNDEFINED : return)
          | true ->
              let resps = List.map _get_balance bp.requests in
              let op = Tezos.transaction resps 0mutez bp.callback in
              ([op], {data = data; tickets = tickets; next_game_id = next_game_id})
      end

      | Update_operators _ -> (failwith Errors.fa2_NOT_OPERATOR : return)

      | New_game new_game_param ->
            (*let now = Tezos.now in*)
            if (Big_map.mem next_game_id data) then (failwith "Game already created" : return) else
            let {admin = admin; start_time = start_time; max_players = max_players; } = new_game_param in
            (*assert (Tezos.sender = admin);*)
            (*assert (now < start_time);*)
            if (max_players < 2n) then (failwith "Games should have at least two players" : return) else
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

      | Buy_potato_for_game buy_potato_param -> (
            match (Big_map.find_opt buy_potato_param.game_id data) with
            | None -> (failwith Errors.potato_NO_GAME_DATA : return)
            | Some game_data ->
                (*let now = Tezos.now in*)
                if (buy_potato_param.game_id <> game_data.game_id) then (failwith Errors.potato_WRONG_GAME : return) else
                let purchase_price = Tezos.amount in
                if (purchase_price <> 10tez) then (failwith "Games cost 10tez" : return) else
                let addr = Tezos.sender in
                if (addr = game_data.admin) then (failwith "Game owner cannot buy a potato" : return) else
                (*assert (now < game_data.start_time);*)
                if game_data.in_progress then (failwith "Game already in progress" : return) else
                if game_data.game_over then (failwith "Game already finished" : return) else
                let (tkt, tickets) = TicketBook.get game_data.game_id tickets in (
                match tkt with
                  | None -> (failwith Errors.potato_NO_TICKET : return)
                  | Some tkt ->
                    let ((_addr, (game, amt)), tkt) = Tezos.read_ticket tkt in (
                    match (game.game_id = game_data.game_id, Tezos.split_ticket tkt (1n, abs(amt-1n))) with
                    | (false, _) -> (failwith Errors.potato_WRONG_GAME : return)
                    | (true, None) -> (failwith Errors.potato_EMPTY_TICKETBOOK : return)
                    | (true, Some (tkt, book)) ->
                      let op = Tezos.transaction tkt 0mutez buy_potato_param.dest in
                      let (_, tickets) = Big_map.get_and_update game_data.game_id (Some book) tickets in
                      let game_data = {game_data with num_players = game_data.num_players + 1n} in
                      let data = Big_map.update game_data.game_id (Some game_data) data in
                      ([op], {data = data; tickets = tickets; next_game_id = next_game_id})
                    )
                )
            )

      | Start_game game_id -> (
            match (Big_map.find_opt game_id data) with
            | None -> (failwith Errors.potato_NO_GAME_DATA : return)
            | Some game_data ->
                if (game_id <> game_data.game_id) then (failwith Errors.potato_WRONG_GAME : return) else
                (*let now = Tezos.now in *)
                (*let addr = Tezos.sender in *)
                (*assert (addr = game_data.admin);*)
                (*assert (now >= game_data.start_time);*)
                if game_data.in_progress then (failwith "Game already in progress" : return) else
                if (game_data.num_players = 0n) then (failwith "No players for game" : return) else
                if game_data.game_over then (failwith "Game already finished" : return) else
                let game_data = {game_data with in_progress = true} in
                let data = Big_map.update game_id (Some game_data) data in
                ( ([] : operation list), {data = data ; tickets = tickets; next_game_id = next_game_id} )
            )

      | Pass_potato potato ->
            let {game_id = game_id; ticket=ticket; winner=winner} = potato in (
            match (Big_map.find_opt game_id data) with
            | None -> (failwith Errors.potato_NO_GAME_DATA : return)
            | Some game_data ->
                if (game_id <> game_data.game_id) then (failwith Errors.potato_WRONG_GAME : return) else
                (*let now = Tezos.now in*)
                if (winner = game_data.admin) then (failwith "Game owner cannot win own game" : return) else
                (*assert (now >= game_data.start_time);*)
                if not game_data.in_progress then (failwith "Game not in progress" : return) else
                if game_data.game_over then (failwith "Game already finished" : return) else
                let (tkt, tickets) = TicketBook.get game_id tickets in (
                match tkt with
                  | None -> (failwith Errors.potato_NO_TICKET : return)
                  | Some tkt ->
                    let ((_addr, (game, _amt)), tkt) = Tezos.read_ticket tkt in (
                    match (game_id = game.game_id, Tezos.join_tickets (ticket, tkt)) with
                    | (false, _) -> (failwith Errors.potato_WRONG_GAME : return)
                    | (true, None) -> (failwith Errors.potato_WRONG_GAME : return)
                    | (true, Some book) ->
                      let (_, tickets) = Big_map.get_and_update game_id (Some book) tickets in
                      let game_data = {game_data with winner = (Some winner)} in
                      let data = Big_map.update game_id (Some game_data) data in
                      ( ([] : operation list), {data = data ; tickets = tickets; next_game_id = next_game_id} )
                    )
                )
            )

      | End_game game_id -> (
            match (Big_map.find_opt game_id data) with
            | None -> (failwith Errors.potato_NO_GAME_DATA : return)
            | Some game_data ->
                if (game_id <> game_data.game_id) then (failwith Errors.potato_WRONG_GAME : return) else
                (*let now = Tezos.now in*)
                (*let addr = Tezos.sender in*)
                let winnings = game_data.num_players * 10tez in
                (*assert (addr = game_data.admin);*)
                (*assert (now >= game_data.start_time);*)
                if not game_data.in_progress then (failwith "Game not in progress" : return) else
                if game_data.game_over then (failwith "Game already finished" : return) else
                let game_data = {game_data with game_over = true} in
                let data = Big_map.update game_id (Some game_data) data in
                let (_, tickets) = TicketBook.get game_id tickets in (
                match (game_data.winner) with
                  | None -> ( ([] : operation list), {data = data ; tickets = tickets; next_game_id = next_game_id} )
                  | Some winner -> (
                    match ((Tezos.get_contract_opt winner) : unit contract option) with
                      | None -> (failwith Errors.potato_BAD_CONTRACT : return)
                      | Some c -> let op1 = Tezos.transaction () winnings c in
                        ( [op1], {data = data ; tickets = tickets; next_game_id = next_game_id} )
                    )
                )
            )

    )

end

(* (Pair {} {} 0) *)
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
