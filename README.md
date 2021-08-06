# Baking-potato

A 'hot-potato' game built on the Tezos blockchain implemented as a FA2 contract that makes use of the recent 'tickets' innovation from February's 'edo' upgrade.

## How to play

Players buy in to a game and receive their own unique hot potato.

Buy ins are collected together to form the prize pot for that game.

Players hold on to their potato for as long as they can stand, then pass the potato back when they run out of nerves.

The last person to pass the potato back before the game is ended wins the pot.

## In detail

Baking-potato is written in LIGO (caml syntax) and runs on the Tezos blockchain.

A working prototype has been originated on the [Florence testnet](https://florencenet.tzkt.io/KT1TzA4siyBUa6gkfAQgY2s81jYCwsf69Xr6/operations/).

Baking-potato has two contract types

- potato.mligo: the FA2 contract that defines unique hot-potato games as NFTs (WARNING: FA2 aspects not fully tested yet)

- potato_wallet.mligo: supporting smart contract that represents players in the Baking Potato metaverse.

Any holder of the potato wallet can

- initiate and manage a game or

- participate in a game initiated by someone else.

Each game is unique and non-divisible, they have Non-Fungible semantics (NFTs) and are represented in the Baking Potato world by an FA2 contract.

Each game holds a fixed set of potatos, represented by [tickets](https://tezos.gitlab.io/protocols/008_edo.html#tickets), that can only be passed between the game they were created in and the players of that game.

These potatoes are also NFTs with the uniqueness semantics being enforced at the Michelson level by the ticket [linear type](https://tezos.gitlab.io/active/michelson.html#michelsontickets).

## Originated contracts

A working prototype has been originated on the Florence testnet along with a set of potato wallets belonging to players (who have already played a couple of games):

### The game contract

- potato-game-v1: [KT1TzA4siyBUa6gkfAQgY2s81jYCwsf69Xr6](https://florencenet.tzkt.io/KT1TzA4siyBUa6gkfAQgY2s81jYCwsf69Xr6/operations/)

### The players

- alice: [tz1N5kutqpK8DE5v1W5to1RRsoCj5usCJFRm](https://florencenet.tzkt.io/tz1N5kutqpK8DE5v1W5to1RRsoCj5usCJFRm/operations/),

- bob: [tz1Ng1XWdYWm3dfxdprx2rBEwETiZjtsBh5L](https://florencenet.tzkt.io/tz1Ng1XWdYWm3dfxdprx2rBEwETiZjtsBh5L/operations/),

- clive: [tz1SkaPFfX9pBaauAxaVfCbUjhC8P6XMdgch](https://florencenet.tzkt.io/tz1SkaPFfX9pBaauAxaVfCbUjhC8P6XMdgch/operations/),

- deb: [tz1Y1eU8hXYwU8ebiFHZ8hasx5VSQ2fvQJyu](https://florencenet.tzkt.io/tz1Y1eU8hXYwU8ebiFHZ8hasx5VSQ2fvQJyu/operations/),

- enoch: [tz1bfgrf9dpZHZKbv2XAhXPr85ojBHf7Dj6M](https://florencenet.tzkt.io/tz1bfgrf9dpZHZKbv2XAhXPr85ojBHf7Dj6M/operations/),

### Their wallets

- potato-wallet-alice-v1: [KT1G7YyDK7pKwBuLo3HwiSGpSGNxgRBxL3MT](https://florencenet.tzkt.io/KT1G7YyDK7pKwBuLo3HwiSGpSGNxgRBxL3MT/operations/),

- potato-wallet-bob-v1: [KT1VncseMqgcSDyVdjso49arLPGFmqfGaWQK](https://florencenet.tzkt.io/KT1VncseMqgcSDyVdjso49arLPGFmqfGaWQK/operations/),

- potato-wallet-clive-v1: [KT1UetyRiKwihrKoEwg8VpC8tX9r54YXTuUy](https://florencenet.tzkt.io/KT1UetyRiKwihrKoEwg8VpC8tX9r54YXTuUy/operations/),

- potato-wallet-deb-v1: [KT1XZGfpYxEaEiZqKcyN9PgaCFahJPYPDK1v](https://florencenet.tzkt.io/KT1XZGfpYxEaEiZqKcyN9PgaCFahJPYPDK1v/operations/),

- potato-wallet-enoch-v1: [KT1XkYZmySBkzKangHpBmy9gs1Dd3QfpdbYg](https://florencenet.tzkt.io/KT1XkYZmySBkzKangHpBmy9gs1Dd3QfpdbYg/operations/),

## Thanks

Many thanks to [Eli Guenzburger](https://medium.com/@eliguenzburger) for his super-helpful [tutorials](https://medium.com/tqtezos/tickets-on-tezos-part-1-a7cad8cc71cd) and [code](https://github.com/tqtezos/ticket-tutorials).

- Specifically the [Dutch auction](https://assets.tqtezos.com/docs/experimental/ticket-auction/) example was the starting point for the Baking-potato game code.
