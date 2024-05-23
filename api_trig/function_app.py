import logging
import azure.functions as func
from azure.data.tables import TableServiceClient, UpdateMode
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError
import os
import json

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    connection_string = os.getenv('DB_Table_Connection_String')
    if not connection_string:
        logging.error("Missing CosmosDB connection string")
        return func.HttpResponse("Missing CosmosDB connection string", status_code=500)

    try:
        table_service = TableServiceClient.from_connection_string(conn_str=connection_string)
        table_client = table_service.get_table_client(table_name="VisitorCounts")

        try:
            entity = table_client.get_entity(partition_key="partitionKey", row_key="visitorCount")
            entity["count"] += 1
            table_client.update_entity(entity=entity, mode=UpdateMode.REPLACE)
        except ResourceNotFoundError:
            entity = {
                "PartitionKey": "Counter",
                "RowKey": "SingleRow",
                "count": 1
            }
            table_client.create_entity(entity=entity)

        return func.HttpResponse(
            body=json.dumps({"count": entity['count']}),
            status_code=200,
            mimetype="application/json"
        )

    except HttpResponseError as e:
        logging.error(f"Error interacting with CosmosDB: {e}")
        return func.HttpResponse("Error interacting with CosmosDB", status_code=500)

    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        return func.HttpResponse("Internal server error", status_code=500)

    
