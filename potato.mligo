
(* ok so cant have big maps inside main storage big map
   so need to split into current game and next game?
*)

(* potato is a ticket holding the game ID as string
   each one gets passed to players at start,
   then passed back to try and win
*)
type game_id = string
type game =
[@layout:comb]
{
  game_id: game_id;
  loser: bool;
}

type tkt_book = game ticket

type new_game_data =
[@layout:comb]
{
    game_id: game_id;
    admin: address;
    start_time: timestamp; (* when the game will start *)
    max_players: nat; (* max number players *)
}

type game_data =
[@layout:comb]
{
    game_id: game_id; (* this game *)
    admin: address;
    start_time: timestamp; (* when the game will start *)
    in_progress: bool;
    num_players: nat;
    winner: address option;
    game_over: bool;
}

type storage =
[@layout:comb]
{
    data: game_data;

    tickets: (game_id, tkt_book) big_map; (* one ticket book holding N things per game *)
}

type parameter =
| New_game of new_game_data (* admin opens a new game for people to register up to *)
| Buy_ticket_for_game of (tkt_book contract) (* non-admin register for a game by buying a ticket *)
| Start_game (* admin starts the game *)
| Pass_potato of tkt_book (* non-admin passes the potato (ticket) back *)
| End_game (* admin ends game, winner is last person to give back before end of game *)

type return = operation list * storage

let main (action, store: parameter * storage) : return =
begin
    let {data = data; tickets = tickets} = store in
    ( match action with
      | New_game new_game_data -> begin
            let now = Tezos.now in
            let {game_id = game_id; admin = admin; start_time = start_time; max_players = max_players; } = new_game_data in
            assert (Tezos.sender = admin);
            assert (now < start_time);
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
            let game = {game_id = game_id; loser = true} in
            let ts = Tezos.create_ticket game max_players in
            let (_, tickets) = Big_map.get_and_update game_id (Some ts) tickets in
            ( ([] : operation list), { data = data; tickets=tickets } )
        end

      | Buy_ticket_for_game send_to -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            let purchase_price = Tezos.amount in
            assert (addr <> data.admin);
            assert (now < data.start_time);
            assert (not data.in_progress);
            assert (purchase_price = 1tez);
            assert (not data.game_over);
            match ((Tezos.get_contract_opt data.admin) : unit contract option) with
              | None -> (failwith "contract does not match" : return)
              | Some c -> let op1 = Tezos.transaction () purchase_price c in
                  let (t, tickets) = Big_map.get_and_update data.game_id (None : tkt_book option) tickets in
                  match t with
                    | None -> (failwith "ticket does not exist" : return)
                    | Some t ->
                      let ((_addr,(game, amt)), t) = Tezos.read_ticket t in
                      match (game.game_id = data.game_id, Tezos.split_ticket t (1n, abs(amt-1n))) with
                      | (false, _) -> (failwith "Wrong game" : return)
                      | (true, None) -> (failwith "Out of tickets" : return)
                      | (true, Some (t, ts)) ->
                        let op2 = Tezos.transaction t 0mutez send_to in
                        let (_, tickets) = Big_map.get_and_update data.game_id (Some ts) tickets in
                        ([op1; op2], {data = {data with num_players = data.num_players + 1n}; tickets = tickets; })
      end
      | Start_game -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            assert (addr = data.admin);
            assert (now >= data.start_time);
            assert (not data.in_progress);
            assert (data.num_players > 1n);
            assert (not data.game_over);
            ( ([] : operation list), {data = {data with in_progress = true}; tickets = tickets} )
      end

      | Pass_potato potato -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            assert (addr <> data.admin);
            assert (now >= data.start_time);
            assert (data.in_progress);
            assert (data.num_players > 1n);
            assert (not data.game_over);
            let (t, tickets) = Big_map.get_and_update data.game_id (None : tkt_book option) tickets in
            match t with
              | None -> (failwith "ticket does not exist" : return)
              | Some t ->
                let ((_addr,(game, _amt)), t) = Tezos.read_ticket t in
                match (game.game_id = data.game_id, Tezos.join_tickets (potato, t)) with
                | (false, _) -> (failwith "Wrong game" : return)
                | (true, None) -> (failwith "Wrong game" : return)
                | (true, Some ts) ->
                  let (_, tickets) = Big_map.get_and_update data.game_id (Some ts) tickets in
                  ( ([] : operation list), {data = {data with winner = (Some addr)}; tickets = tickets; } )
      end

      | End_game -> begin
            let now = Tezos.now in
            let addr = Tezos.sender in
            let winnings = Tezos.balance in
            assert (addr = data.admin);
            assert (now >= data.start_time);
            assert (data.in_progress);
            assert (not data.game_over);
            let (_, tickets) = Big_map.get_and_update data.game_id (None : tkt_book option) tickets in
            match (data.winner) with
              | None -> ( ([] : operation list), {data = {data with game_over = true}; tickets = tickets})
              | Some winner ->
                match ((Tezos.get_contract_opt winner) : unit contract option) with
                  | None -> (failwith "contract does not match" : return)
                  | Some c -> let op1 = Tezos.transaction () winnings c in
                    ( [op1], {data = {data with game_over = true}; tickets = tickets})
      end

    )

end

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
    let init_tickets : (game_id, tkt_book) big_map = Big_map.empty in
    let init_storage = { data = init_data; tickets = init_tickets } in
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
