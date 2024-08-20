import azure.functions as func
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError
import os
import json
import logging

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

       
    origin = req.headers.get("Origin")
    allowed_origins = ["https://cdn-raineycloud.azureedge.net", "https://portal.azure.com", "https://api.rainey-cloud.com", "https://raineyresume.z13.web.core.windows.net", "https://resumeapiapp.azurewebsites.net/api/api_trig", "https://resume.rainey-cloud.com"]  

    if origin not in allowed_origins:
        logging.warning(f"Unauthorized origin: {origin}")
        return func.HttpResponse(
            status_code=403,  
            body=json.dumps({"error": "Forbidden"}),
            headers={
                "Access-Control-Allow-Origin": origin,
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
            }
        )

    if req.method == "OPTIONS":
        headers = {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "3600",
        }
        return func.HttpResponse(status_code=204, headers=headers)
        
    connection_string = os.getenv('DB_Table_Connection_String')
    if not connection_string:
        logging.error("Missing CosmosDB connection string")
        return func.HttpResponse(
            body=json.dumps({"error": "Missing CosmosDB connection string"}),
            status_code=500,
            mimetype="application/json"
        )

    table_name = os.getenv('COSMOS_DB_TABLE')
    if not table_name:
        logging.error("Missing environment variable 'COSMOS_DB_TABLE'")
        return func.HttpResponse(
            body=json.dumps({"error": "Missing environment variable 'COSMOS_DB_TABLE'"}),
            status_code=500,
            mimetype="application/json"
        )

    table_service = TableServiceClient.from_connection_string(conn_str=connection_string)
    table_client = table_service.get_table_client(table_name=table_name)

    try:
        entity = table_client.get_entity(partition_key="Counter", row_key="SingleRow")
        entity["count"] += 1
        table_client.update_entity(entity=entity, mode=UpdateMode.REPLACE)
        logging.info(f"Updated entity: {entity}")
    except ResourceNotFoundError:
        entity = {
            "PartitionKey": "Counter",
            "RowKey": "SingleRow",
            "count": 1
        }
        table_client.create_entity(entity=entity)
        logging.info(f"Created new entity: {entity}")

    except HttpResponseError as e:
        logging.error(f"HttpResponseError: {e.message}")
        return func.HttpResponse(
            body=json.dumps({"error": f"HttpResponseError: {e.message}"}), 
            status_code=e.status_code,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse(
            body=json.dumps({"error": f"An error occurred: {str(e)}"}), 
            status_code=500,
            mimetype="application/json"
        )

    return func.HttpResponse(
        body=json.dumps({"count": entity['count']}),
        status_code=200,
        mimetype="application/json"
    )
