#if !POTATO
#define POTATO

#include "thirdparty/fa2/shared/fa2/fa2_interface.mligo"
#include "types.mligo"

(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

type game_storage =
[@layout:comb]
{
    data: game_data option;

    tickets: TicketBook.t; (* one ticket book holding N things per game *)
}

type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Buy_ticket_for_game of (TicketBook.tkt contract) (* non-admin register for a game by buying a ticket *)
| Start_game (* admin starts the game *)
| Pass_potato of TicketBook.tkt*address (* non-admin passes the potato (ticket) back *)
| End_game (* admin ends game, winner is last person to give back before end of game *)

type return = operation list * game_storage

let main (action, store: parameter * game_storage) : return =
begin
    let {data = data; tickets = tickets} = store in
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {game_id = game_id; admin = admin; start_time = start_time; max_players = max_players; } = new_game_data in
            (*assert (Tezos.sender = admin);*)
            (*assert (now < start_time);*)
            assert (max_players > 2n);
            let winner : address option = None in
            let data : game_data = {
                game_id = game_id;
                admin = admin;
                start_time = start_time;
                in_progress = false;
                num_players = 0n;
                winner = winner;
                game_over = false;
            } in
            let tickets = TicketBook.create_with game_id max_players tickets in
            ( ([] : operation list), { data = Some data; tickets=tickets } )
        end

      | Buy_ticket_for_game send_to -> begin
            match data with
            | None -> (failwith "No game data" : return)
            | Some data -> begin
                let now = Tezos.now in
                let addr = Tezos.sender in
                let purchase_price = Tezos.amount in
                assert (purchase_price = 1tez);
                assert (addr <> data.admin);
                (*assert (now < data.start_time);*)
                assert (not data.in_progress);
                assert (not data.game_over);
                match ((Tezos.get_contract_opt data.admin) : unit contract option) with
                  | None -> (failwith "contract does not match" : return)
                  | Some c -> let op1 = Tezos.transaction () purchase_price c in
                      let (tkt, tickets) = TicketBook.get data.game_id tickets in
                      match tkt with
                        | None -> (failwith "ticket does not exist" : return)
                        | Some tkt ->
                          let ((_addr,(game, amt)), tkt) = Tezos.read_ticket tkt in
                          match (game.game_id = data.game_id, Tezos.split_ticket tkt (1n, abs(amt-1n))) with
                          | (false, _) -> (failwith "Wrong game" : return)
                          | (true, None) -> (failwith "Out of tickets" : return)
                          | (true, Some (tkt, book)) ->
                            let op2 = Tezos.transaction tkt 0mutez send_to in
                            let (_, tickets) = Big_map.get_and_update data.game_id (Some book) tickets in
                            ([op1; op2], {data = Some {data with num_players = data.num_players + 1n}; tickets = tickets; })
            end
      end

      | Start_game -> begin
            match data with
            | None -> (failwith "No game data" : return)
            | Some data -> begin
                let now = Tezos.now in
                let addr = Tezos.sender in
                (*assert (addr = data.admin);*)
                (*assert (now >= data.start_time);*)
                assert (not data.in_progress);
                assert (data.num_players >= 1n);
                assert (not data.game_over);
                ( ([] : operation list), {data = Some {data with in_progress = true}; tickets = tickets} )
            end
      end

      | Pass_potato potato_addr -> begin
            let (potato, addr) = potato_addr in
            match data with
            | None -> (failwith "No game data" : return)
            | Some data -> begin
                let now = Tezos.now in
                (*let addr = Tezos.sender in*)
                assert (addr <> data.admin);
                (*assert (now >= data.start_time);*)
                assert (data.in_progress);
                assert (data.num_players >= 1n);
                assert (not data.game_over);
                let (tkt, tickets) = TicketBook.get data.game_id tickets in
                match tkt with
                  | None -> (failwith "ticket does not exist" : return)
                  | Some tkt ->
                    let ((_addr,(game, _amt)), tkt) = Tezos.read_ticket tkt in
                    match (game.game_id = data.game_id, Tezos.join_tickets (potato, tkt)) with
                    | (false, _) -> (failwith "Wrong game" : return)
                    | (true, None) -> (failwith "Wrong game" : return)
                    | (true, Some book) ->
                      let (_, tickets) = Big_map.get_and_update data.game_id (Some book) tickets in
                      ( ([] : operation list), {data = Some {data with winner = (Some addr)}; tickets = tickets; } )
            end
      end

      | End_game -> begin
            match data with
            | None -> (failwith "No game data" : return)
            | Some data -> begin
                let now = Tezos.now in
                let addr = Tezos.sender in
                let winnings = data.num_players * 1tez in
                (*assert (addr = data.admin);*)
                (*assert (now >= data.start_time);*)
                assert (data.in_progress);
                assert (not data.game_over);
                let (_, tickets) = TicketBook.get data.game_id tickets in
                match (data.winner) with
                  | None -> ( ([] : operation list), {data = Some {data with game_over = true}; tickets = tickets})
                  | Some winner ->
                    match ((Tezos.get_contract_opt winner) : unit contract option) with
                      | None -> (failwith "contract does not match" : return)
                      | Some c -> let op1 = Tezos.transaction () winnings c in
                        ( [op1], {data = Some {data with game_over = true}; tickets = tickets})
            end
      end

    )

end

(* (Pair None {}) *)
let sample_storage : game_storage = {
    data = (None : game_data option);
    tickets = TicketBook.empty;
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
    let new_game_data = {
        game_id = "game01";
        admin = admin;
        start_time = ("2021-07-26t16:45:10Z" : timestamp);
        max_players = 10n;
    } in
    let () = Test.transfer_to_contract_exn c (New_game new_game_data) 1mutez in
    let actual = Test.get_storage taddr in
    let _ = _check_game_data actual.data init_data in
    ()
*)
#endif
