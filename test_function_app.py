import os
import pytest
from unittest.mock import patch, Mock
from azure.cosmos import CosmosClient


# --- Unit Test for Function Logic ---
def test_main_function_logic():
    """
    Unit test for your main function logic in function_app.py.
    Mocks a request and tests the response from the main function.
    """
    from api_trig.function_app import main  # Import the main function from function_app.py
    mock_request = Mock()
    mock_request.method = 'GET'

    result = main(mock_request)  # Call the main function
    assert result.status_code == 200
    assert result.body == "Expected Response"


# --- Integration Test for Cosmos DB ---
def test_cosmos_db_integration():
    """
    Integration test that interacts with Cosmos DB using environment variables.
    """
    # Access environment variables for secrets
    db_connection_string = os.getenv('DB_CONNECTION_STRING')
    db_table = os.getenv('DB_TABLE')

    # Ensure that environment variables are set
    assert db_connection_string is not None, "DB_CONNECTION_STRING is not set"
    assert db_table is not None, "DB_TABLE is not set"

    # Connect to Cosmos DB using the provided secrets
    client = CosmosClient(db_connection_string, credential=None)
    database = client.get_database_client('your-database-name')
    container = database.get_container_client(db_table)

    # Simulate reading an item from Cosmos DB
    item = container.read_item(item='item-id', partition_key='partition-key')
    assert item['id'] == 'item-id'


# --- Mocked Test for Cosmos DB ---
@patch('azure.cosmos.CosmosClient')
def test_cosmos_db_mock(mock_cosmos_client):
    """
    Unit test with mocked Cosmos DB using environment variables.
    This avoids making actual Cosmos DB calls.
    """
    # Mock the Cosmos DB container and its return values
    mock_container = mock_cosmos_client.return_value.get_container_client.return_value
    mock_container.read_item.return_value = {'id': 'test-id', 'count': 1}

    from function_app import main
    result = main('test-id')  # Adjust this call according to your function logic
    assert result['count'] == 1


# --- Mocked Test for Cosmos DB Write Operation ---
@patch('azure.cosmos.CosmosClient')
def test_cosmos_db_write_operation(mock_cosmos_client):
    """
    Unit test for writing an item to Cosmos DB using mocks.
    """
    mock_container = mock_cosmos_client.return_value.get_container_client.return_value

    from function_app import write_to_cosmos  # Your function that writes data to Cosmos DB
    test_item = {'id': 'test-item', 'value': 100}

    # Call the function that writes to Cosmos DB
    write_to_cosmos(test_item)

    # Assert that the `upsert_item` method was called with the correct arguments
    mock_container.upsert_item.assert_called_once_with(test_item)
