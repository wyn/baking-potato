#!/usr/bin/env python3
import unittest
import os.path
import datetime
from pytezos import ContractInterface
from pytezos.sandbox.node import SandboxedNodeTestCase
from pytezos.contract.result import ContractCallResult

BUILD_DIR = os.path.join(os.path.dirname(__file__), "..", "build")

class SandboxedContractTest(SandboxedNodeTestCase):

    def test_deploy_contract(self):

        # Create client
        client = self.client.using(key='bootstrap1')
        client.reveal()

        # Originate contract with initial storage
        contract = ContractInterface.from_file(os.path.join(BUILD_DIR, "potato.tz"))
        opg = contract.using(shell=self.get_node_url(), key='bootstrap1').originate(initial_storage=None)
        opg = opg.fill().sign().inject()

        self.bake_block()

        # Find originated contract address by operation hash
        opg = client.shell.blocks['head':].find_operation(opg['hash'])
        contract_address = opg['contents'][0]['metadata']['operation_result']['originated_contracts'][0]

        # Load originated contract from blockchain
        originated_contract = client.contract(contract_address).using(shell=self.get_node_url(), key='bootstrap1')

        # Perform real contract call
        import pudb; pu.db
        new_game = dict(
            admin=originated_contract.default.address,
            start_time=datetime.datetime.now().toordinal(),
            game_id="first_game"
        )
        call = originated_contract.default(new_game=new_game)
        opg = call.inject()

        self.bake_block()

        # Get injected operation and convert to ContractCallResult
        opg = client.shell.blocks['head':].find_operation(opg['hash'])
        result = ContractCallResult.from_operation_group(opg)[0]

        self.assertEqual({'string': 'foobar'}, result.storage)


if __name__ == "__main__":
    unittest.main()
