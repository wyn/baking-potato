#!/usr/bin/env python3
import unittest
import os.path
import datetime
from pytezos import ContractInterface, pytezos as ptz
from pytezos.sandbox.node import SandboxedNodeTestCase
from pytezos.contract.result import ContractCallResult

BUILD_DIR = os.path.join(os.path.dirname(__file__), "..", "build")

class SandboxedContractTest(SandboxedNodeTestCase):

    def setUp(self):
        self.maxDiff = None

    def _originate(self, initial_storage):
        # Create client
        import pudb; pu.db
        client = self.client.using(key='bootstrap1')
        client.reveal()

        # Originate contract with initial storage
        contract = ContractInterface.from_file(os.path.join(BUILD_DIR, "potato.tz"))
        opg = contract.using(shell=self.get_node_url(), key='bootstrap1').originate(initial_storage=initial_storage)
        opg = opg.fill().sign().inject()

        self.bake_block()

        # Find originated contract address by operation hash
        opg = client.shell.blocks['head':].find_operation(opg['hash'])
        contract_address = opg['contents'][0]['metadata']['operation_result']['originated_contracts'][0]

        # Load originated contract from blockchain
        originated_contract = client.contract(contract_address).using(shell=self.get_node_url(), key='bootstrap1')
        return client, originated_contract

    def test_new_game_storage(self):
        client, originated_contract = self._originate(None)
        # Perform real contract call
        ts = ptz.now()
        sender = client.key.public_key_hash() #originated_contract.default.address
        new_game = dict(
            game_id=42,
            admin=sender,
            start_time=ts,
            max_players=10,
        )
        call = originated_contract.default(new_game=new_game)
        opg = call.send()

        self.bake_block()

        # Get injected operation and convert to ContractCallResult
        opg = client.shell.blocks['head':].find_operation(opg.hash())
        result = ContractCallResult.from_operation_group(opg)[0]
        expected = {'prim': 'Pair',
                    'args': [{'prim': 'Some',
                              'args': [[{'int': '42'},
                                        {'bytes': '000002298c03ed7d454a101eb7022bc95f7e5f41ac78'},
                                        {'int': str(ts)},
                                        {'prim': 'False'},
                                        {'int': '0'},
                                        {'prim': 'None'},
                                        {'prim': 'False'}]]},
                             {'int': '0'}]}

        self.assertDictEqual(expected, result.storage)



if __name__ == "__main__":
    unittest.main()
