# Baking-potato

A 'hot-potato' game built on the Tezos blockchain implemented as a FA2 contract that makes use of the recent 'tickets' innovation from February 2021 'edo' upgrade.

## How to play

Players buy in to a game and receive their own unique hot potato.

Buy ins are collected together to form the prize pot for that game.

Players hold on to their potato for as long as they can stand, then pass the potato back when they run out of nerves.

The last person to pass the potato back before the game is ended wins the pot.

## Details

Baking-potato is written in [LIGO](https://ligolang.org/docs/intro/introduction) (caml syntax) and runs on the Tezos blockchain.

A working [prototype](https://florencenet.tzkt.io/KT1TzA4siyBUa6gkfAQgY2s81jYCwsf69Xr6/operations/) has been originated on the [Florence testnet](https://florencenet.tzkt.io/).

There is no front-end as yet, all interactions must be done with the command-line.

Baking-potato has two contracts

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

## Building and running

To compile the mligo files you will need the [ligo compiler](https://ligolang.org/docs/intro/installation) available to use as the command 'ligo':

```sh
$ which ligo
/usr/local/bin/ligo
```

To originate contracts locally you will need the [Flextesa](https://gitlab.com/tezos/flextesa) Tezos sandbox running locally.

Installation instructions are found [here](https://assets.tqtezos.com/docs/setup/2-sandbox/).

The standard Flextesa install will provide two users, Alice and Bob, however to test interesting Baking-potato games you will need more users.

Included in the Baking-potato codebase is the flobox-x5.sh script which spins up Flextesa with five accounts Alice, Bob, Clive, Deb and Enoch.

It can be used in the Flextesa Docker instance with a volume mount:

```sh
$ docker run --rm --detach \
    --name flextesa-sandbox \
    -p 20000:20000 \
    -v $PWD/flobox-x5.sh:/usr/bin/flobox-x5 \
    tqtezos/flextesa:20210602 \
    flobox-x5 start

```

Finally you will also need the tezos-client, installation instructions can be found [here](https://assets.tqtezos.com/docs/setup/1-tezos-client/).

> Note however that setup of the client should follow the instructions [here](https://assets.tqtezos.com/docs/setup/2-sandbox/) (after sandbox setup).

With these pieces in place the included Makefile can be used to build code and originate contracts locally:

```sh
$ make all # from source code root directory
```

will compile the mligo code to Michelson and also originate the game contract and the five wallets,

```sh
$ make clean
```

will delete the build artifacts and all contracts.

### Playing a game

There is no front-end yet, game-play must be directed through tezos-client calls.

At the end of the Makefile are some helper functions that allow you to set up two games and play through them.

The first game, initiated by Alice has a maximum of three players.

The second game, initiated by Enoch has space for 20 players.

The game contract address, wallet addresses, names and game_ids will need to be passed via environment variables e.g.

```sh
$ POTATO_GAME=KT1TBxEnWcPiBtWnsCiv81s6FNdq8HxCDD9q make hot_potato
```

for a game contract originated locally at "KT1TBxEnWcPiBtWnsCiv81s6FNdq8HxCDD9q".

POTATO_GAME, NAME, WALLET and GAME_ID will all need to specified as environment variables to use these helper functions.

Contract addresses and user addresses can be found in the tezos-client config directory, usually found at:

```sh
$ ls -alh ~/.tezos-client
total 24K
drwxr-xr-x  2 wyn wyn 4.0K Aug  5 18:10 .
drwxr-xr-x 46 wyn wyn 4.0K Aug  6 08:04 ..
-rw-rw-r--  1 wyn wyn  546 Aug  5 18:21 contracts
-rw-rw-r--  1 wyn wyn  356 Aug  5 18:04 public_key_hashs
-rw-rw-r--  1 wyn wyn 1.1K Aug  5 18:21 public_keys
-rw-rw-r--  1 wyn wyn  556 Aug  5 18:04 secret_keys

```

## Testing

The game mechanics of Baking-potato have been manually tested on a local [Flextesa](https://gitlab.com/tezos/flextesa) instance and on the [Florence testnet](https://florencenet.tzkt.io/).

## Thanks

Many thanks to [Eli Guenzburger](https://medium.com/@eliguenzburger) for his super-helpful [tutorials](https://medium.com/tqtezos/tickets-on-tezos-part-1-a7cad8cc71cd) and [code](https://github.com/tqtezos/ticket-tutorials).

- Specifically the [Dutch auction](https://assets.tqtezos.com/docs/experimental/ticket-auction/) example was the starting point for the Baking-potato game code.

Also thanks to [Flextesa](https://gitlab.com/tezos/flextesa) for providing an easy-to-use local Tezos sandbox.
