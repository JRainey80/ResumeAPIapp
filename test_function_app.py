import os
import pytest
from unittest.mock import patch, Mock
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError


# --- Unit Test for Main Function Logic ---
@patch('api_trig.function_app.write_to_table')
def test_main_function_logic(mock_write_to_table):
    """
    Unit test for your main function logic in function_app.py.
    Mocks a request and tests the response from the main function.
    """
    from api_trig.function_app import main  # Import the main function from function_app.py
    
    # Simulate successful table operation
    mock_write_to_table.return_value = {"PartitionKey": "Counter", "RowKey": "SingleRow", "count": 5}

    # Create a mock HTTP request
    mock_request = Mock()
    mock_request.method = 'GET'
    mock_request.headers = {'Origin': 'https://resume.rainey-cloud.com'}

    # Call the main function
    result = main(mock_request)
    
    # Check the response status code and body
    assert result.status_code == 200  # Adjust based on your actual expected response
    assert '"count": 5' in result.get_body().decode()  # Make sure count is included


# --- Integration Test for Azure Table API ---
def test_table_api_integration():
    """
    Integration test that interacts with the Azure Table API.
    """
    db_connection_string = os.getenv('DB_Table_Connection_String')
    db_table = os.getenv('COSMOS_DB_TABLE')

    # Ensure that the connection string and table name are set
    assert db_connection_string is not None, "DB_connection_string is not set"
    assert db_table is not None, "COSMOS_DB_TABLE is not set"

    # Use TableServiceClient for Table API
    service_client = TableServiceClient.from_connection_string(db_connection_string)
    table_client = service_client.get_table_client(db_table)

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
    mock_table_client.get_entity.return_value = {'PartitionKey': 'Counter', 'RowKey': 'SingleRow', 'count': 1}

    from api_trig.function_app import main
    mock_request = Mock()
    mock_request.method = 'GET'
    mock_request.headers = {'Origin': 'https://resume.rainey-cloud.com'}

    result = main(mock_request)
    
    # Simulate retrieving an entity from the table
    entity = mock_table_client.get_entity('Counter', 'SingleRow')

    assert result.status_code == 200  # Adjust based on your actual response
    assert entity['count'] == 1  # Ensure the mock returns the correct value


# --- Mocked Test for Azure Table Write Operation ---
@patch('azure.data.tables.TableServiceClient')
def test_table_api_write_operation(mock_table_service_client):
    """
    Unit test for writing an item to Azure Table using mocks.
    """
    # Mock the Table client
    mock_table_client = mock_table_service_client.return_value.get_table_client.return_value

    # Simulate the entity already existing in the table by returning a mock entity
    mock_table_client.get_entity.return_value = {
        'PartitionKey': 'test-partition',
        'RowKey': 'test-row',
        'count': 5
    }

    from api_trig.function_app import write_to_table  # Import your `write_to_table` function
    
    # Call the function that writes to the Table API
    write_to_table(mock_table_client, 'test-partition', 'test-row')
    
    # Ensure that the `update_entity` method was called with the correct updated entity
    mock_table_client.update_entity.assert_called_once_with(
        entity={'PartitionKey': 'test-partition', 'RowKey': 'test-row', 'count': 6},
        mode=mock_table_client.update_entity.call_args[1]['mode']  # Match the mode from the function
    )

