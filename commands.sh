#!/usr/bin/env bash
set -euo pipefail

tzc originate contract potato-game-v1 transferring 0 from alice running \
    "$(pwd)/build/potato.tz" --init "Pair None {} 42" --burn-cap 1 \
    >build/potato.orig 2>&1

tzc originate contract potato-wallet-alice-v1 transferring 0 from alice running \
    "$(pwd)/build/potato_wallet.tz" --init "Pair \"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb\" {} None {}" --burn-cap 1 \
    >build/potato-wallet.orig.alice 2>&1

tzc originate contract potato-wallet-bob-v1 transferring 0 from bob running \
    "$(pwd)/build/potato_wallet.tz" --init "Pair \"tz1aSkwEot3L2kmUvcoxzjMomb9mvBNuzFK6\" {} None {}" --burn-cap 1 \
    >build/potato-wallet.orig.bob 2>&1

tzc transfer 0 from alice to potato-wallet-alice-v1 --entrypoint "hotPotato" \
    --arg "Pair \"<potato-game-v1>%new_game\" (Pair 42 (Pair 0 3))" --burn-cap 1

tzc transfer 10.0 from bob to potato-game-v1 --entrypoint "buy_potato_for_game" \
    --arg "\"<potato-wallet-bob-v1>%receive\"" --burn-cap 1

tzc transfer 0 from alice to potato-game-v1 --entrypoint "start_game" \
    --arg "42" --burn-cap 1

tzc transfer 0 from bob to potato-wallet-bob-v1 --entrypoint "send" \
    --arg "Pair \"<potato-game-v1>%pass_potato\" 42" --burn-cap 1

tzc transfer 0 from alice to potato-game-v1 --entrypoint "end_game" --burn-cap 1
