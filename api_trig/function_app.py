import os
import logging
import azure.functions as func
from azure.data.tables import TableServiceClient, UpdateMode
from azure.core.exceptions import ResourceNotFoundError

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    # Retrieve connection string from environment variables
    connection_string = os.getenv('CosmosDBConnectionString')
    if not connection_string:
        return func.HttpResponse("Missing CosmosDB connection string", status_code=400)

    table_service = TableServiceClient.from_connection_string(conn_str=connection_string)
    table_client = table_service.get_table_client(table_name="VisitorCounts")

    try:
        entity = table_client.get_entity(partition_key="partitionKey", row_key="visitorCount")
        entity["count"] += 1
        table_client.update_entity(entity=entity, mode=UpdateMode.REPLACE)
    except ResourceNotFoundError:
        entity = {
            "PartitionKey": "partitionKey",
            "RowKey": "visitorCount",
            "count": 1
        }
        table_client.create_entity(entity=entity)

    return func.HttpResponse(
        f"Visitor count: {entity['count']}",
        status_code=200
    )
