##
# Baking-potato
#
# @file
# @version 0.1
PWD = $(shell pwd)
SLEEP5 = $(shell sleep 5s)

LIGO = ligo compile-contract
MAIN = main
ORIGINATE_CONTRACT = tezos-client originate contract
CALL_ENDPOINT_00 = tezos-client transfer 0
CALL_ENDPOINT_10 = tezos-client transfer 10


VERSION = v1

# SANDBOX addresses
ALICE_ADDRESS = tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb
BOB_ADDRESS = tz1aSkwEot3L2kmUvcoxzjMomb9mvBNuzFK6
CLIVE_ADDRESS = tz1YFWuGimwnzPZ1nLbPQSqtnoBB3J9vw2jF
DEB_ADDRESS = tz1cMtPPqqufFQMbdWw2ZzN4LhZZoLAysEo1
ENOCH_ADDRESS = tz1Tp2vvH75pkiwoYcbKDk1MztqVJpDiKfGC

all: michelson contracts

contracts: wallets game

game: ./build/potato.tz wait
	$(ORIGINATE_CONTRACT) potato-game-$(VERSION) transferring 0 from alice running \
    "$(PWD)/build/potato.tz" --init "Pair {} {} 0" --burn-cap 2 \

wallets: alice_wallet bob_wallet clive_wallet deb_wallet enoch_wallet

alice_wallet: ./build/potato_wallet.tz wait
	$(ORIGINATE_CONTRACT) potato-wallet-alice-$(VERSION) transferring 0 from alice running \
	"$(PWD)/build/potato_wallet.tz" --init "Pair \"$(ALICE_ADDRESS)\" {} None" --burn-cap 1

bob_wallet: ./build/potato_wallet.tz wait
	$(ORIGINATE_CONTRACT) potato-wallet-bob-$(VERSION) transferring 0 from bob running \
    "$(PWD)/build/potato_wallet.tz" --init "Pair \"$(BOB_ADDRESS)\" {} None" --burn-cap 1

clive_wallet: ./build/potato_wallet.tz wait
	$(ORIGINATE_CONTRACT) potato-wallet-clive-$(VERSION) transferring 0 from clive running \
    "$(PWD)/build/potato_wallet.tz" --init "Pair \"$(CLIVE_ADDRESS)\" {} None" --burn-cap 1

deb_wallet: ./build/potato_wallet.tz wait
	$(ORIGINATE_CONTRACT) potato-wallet-deb-$(VERSION) transferring 0 from deb running \
    "$(PWD)/build/potato_wallet.tz" --init "Pair \"$(DEB_ADDRESS)\" {} None" --burn-cap 1

enoch_wallet: ./build/potato_wallet.tz wait
	$(ORIGINATE_CONTRACT) potato-wallet-enoch-$(VERSION) transferring 0 from enoch running \
    "$(PWD)/build/potato_wallet.tz" --init "Pair \"$(ENOCH_ADDRESS)\" {} None" --burn-cap 1

michelson: ./build/potato.tz ./build/potato_wallet.tz

./build/potato.tz: potato.mligo types.mligo
	$(LIGO) potato.mligo $(MAIN) --output-file=./build/potato.tz

./build/potato_wallet.tz: potato_wallet.mligo types.mligo
	$(LIGO) potato_wallet.mligo $(MAIN) --output-file=./build/potato_wallet.tz

wait:
	$(SLEEP5)


clean: clean_michelson clean_contracts

# WARN
# careful need to rm -f here because
# ligo cmdline is a 'docker run' command
# and it makes the file outputs root
clean_michelson:
	rm -f ./build/potato.tz ./build/potato_wallet.tz

clean_contracts:
	tezos-client forget all contracts -force


####################################################################################################

# helpers for doing examples
hot_potato: hot_potato_0 hot_potato_1

# alice configures a game first (will get game_id=0),
# 3 players max
hot_potato_0:
	$(CALL_ENDPOINT_00) from alice to potato-wallet-alice-$(VERSION) --entrypoint "hotPotato" \
    --arg "Pair \"$(POTATO_GAME)%new_game\" (Pair 0 3)" --burn-cap 1

# enoch second (will get game_id=1),
# enough for 20 players
hot_potato_1:
	$(CALL_ENDPOINT_00) from enoch to potato-wallet-enoch-$(VERSION) --entrypoint "hotPotato" \
    --arg "Pair \"$(POTATO_GAME)%new_game\" (Pair 0 20)" --burn-cap 1

buy_in:
	$(CALL_ENDPOINT_10) from $(NAME) to potato-game-$(VERSION) --entrypoint "buy_potato_for_game" \
    --arg "Pair \"$(WALLET)%receive\" $(GAME_ID)" --burn-cap 1

start:
	$(CALL_ENDPOINT_00) from $(NAME) to potato-game-$(VERSION) --entrypoint "start_game" \
    --arg "$(GAME_ID)" --burn-cap 1

too_hot:
	$(CALL_ENDPOINT_00) from $(NAME) to potato-wallet-$(NAME)-$(VERSION) --entrypoint "send" \
    --arg "Pair \"$(POTATO_GAME)%pass_potato\" $(GAME_ID)" --burn-cap 1

stop:
	$(CALL_ENDPOINT_00) from $(NAME) to potato-game-$(VERSION) --entrypoint "end_game" \
    --arg "$(GAME_ID)" --burn-cap 1



# end
