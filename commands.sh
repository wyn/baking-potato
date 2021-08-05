#!/usr/bin/env bash
set -euo pipefail

# originating contracts is done in the makefile

tzc transfer 0 from alice to potato-wallet-alice-v1 --entrypoint "hotPotato" \
    --arg "Pair \"<potato-game-v1>%new_game\" (Pair 0 3)" --burn-cap 1

tzc transfer 10.0 from bob to potato-game-v1 --entrypoint "buy_potato_for_game" \
    --arg "Pair \"<potato-wallet-bob-v1>%receive\" 0" --burn-cap 1

tzc transfer 0 from alice to potato-game-v1 --entrypoint "start_game" \
    --arg "0" --burn-cap 1

tzc transfer 0 from bob to potato-wallet-bob-v1 --entrypoint "send" \
    --arg "Pair \"<potato-game-v1>%pass_potato\" 0" --burn-cap 1

tzc transfer 0 from alice to potato-game-v1 --entrypoint "end_game" \
    --arg "0" --burn-cap 1
