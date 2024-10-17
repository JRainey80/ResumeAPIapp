import os
import pytest
from unittest.mock import patch, Mock
from azure.data.tables import TableServiceClient


# --- Unit Test for Function Logic ---
def test_main_function_logic():
    """
    Unit test for your main function logic in function_app.py.
    Mocks a request and tests the response from the main function.
    """
    from api_trig.function_app import main  # Import the main function from function_app.py
    mock_request = Mock()
    mock_request.method = 'GET'
    mock_request.headers = {'Origin': 'https://resume.rainey-cloud.com'}

    result = main(mock_request)  # Call the main function
    assert result.status_code == 200  # Adjust based on your actual expected response
    assert result.body == "Expected Response"  # Adjust based on your actual response


# --- Integration Test for Azure Table API ---
def test_table_api_integration():
    """
    Integration test that interacts with the Azure Table API.
    """
    db_connection_string = os.getenv('DB_CONNECTION_STRING')
    db_table = os.getenv('DB_TABLE')

    # Ensure that the connection string and table name are set
    assert db_connection_string is not None, "DB_CONNECTION_STRING is not set"
    assert db_table is not None, "DB_TABLE is not set"

    # Use TableServiceClient for Table API
    service_client = TableServiceClient.from_connection_string(db_connection_string)
    table_client = service_client.get_table_client(db_table)

    # Now you can interact with the table client
    # Example: Read from the table
    entities = table_client.list_entities()
    for entity in entities:
        print(entity)


# --- Mocked Test for Azure Table API ---
@patch('azure.data.tables.TableServiceClient')
def test_table_api_mock(mock_table_service_client):
    """
    Unit test with mocked Azure Table API interactions.
    This avoids making actual Azure Table API calls.
    """
    # Mock the Table client and its return values
    mock_table_client = mock_table_service_client.return_value.get_table_client.return_value
    mock_table_client.get_entity.return_value = {'id': 'test-id', 'count': 1}

    from api_trig.function_app import main
    mock_request = Mock()
    mock_request.method = 'GET'
    mock_request.headers = {'Origin': 'https://resume.rainey-cloud.com'}

    result = main(mock_request)
    
    # Simulate retrieving an entity from the table
    entity = mock_table_client.get_entity('test-id')

    assert result.status_code == 200  # Adjust based on your actual response
    assert entity['count'] == 1  # Ensure the mock returns the correct value


# --- Mocked Test for Azure Table Write Operation ---
@patch('azure.data.tables.TableServiceClient')
def test_table_api_write_operation(mock_table_service_client):
    """
    Unit test for writing an item to Azure Table using mocks.
    """
    mock_table_client = mock_table_service_client.return_value.get_table_client.return_value

    from api_trig.function_app import write_to_table  # Your function that writes data to the Table API
    test_item = {'PartitionKey': 'test-partition', 'RowKey': 'test-row', 'value': 100}

    # Call the function that writes to the Table API
    write_to_table(test_item)

    # Assert that the `upsert_entity` method was called with the correct arguments
    mock_table_client.upsert_entity.assert_called_once_with(test_item)
