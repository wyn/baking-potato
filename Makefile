##
# Baking-potato
#
# @file
# @version 0.1

LIGO = ligo compile-contract
MAIN = main

all: ./build/potato.tz ./build/potato_wallet.tz

./build/potato.tz: potato.mligo
	$(LIGO) potato.mligo $(MAIN) --output-file=./build/potato.tz

./build/potato_wallet.tz: potato_wallet.mligo
	$(LIGO) potato_wallet.mligo $(MAIN) --output-file=./build/potato_wallet.tz

clean:
	rm ./build/potato.tz ./build/potato_wallet.tz

# end
