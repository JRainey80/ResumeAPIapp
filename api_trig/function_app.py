import logging
import azure.functions as func
from azure.data.tables import TableServiceClient, UpdateMode
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError
import os
import json
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        key_vault_name = os.getenv('KEY_VAULT_NAME')
        if not key_vault_name:
            logging.error("Missing environment variable 'KEY_VAULT_NAME'")
            return func.HttpResponse(
                body=json.dumps({"error": "Missing environment variable 'KEY_VAULT_NAME'"}),
                status_code=500,
                mimetype="application/json"
            )

        kv_uri = f"https://{key_vault_name}.vault.azure.net"
        logging.info(f"Key Vault URI: {kv_uri}")

        credential = DefaultAzureCredential(logging_enable=True)
        client = SecretClient(vault_url=kv_uri, credential=credential)

        secret_name = "keytocity"
        retrieved_secret = client.get_secret(secret_name)
        api_key = retrieved_secret.value
        logging.info(f"Retrieved API key: {api_key}")

        if req.route_params.get('action') == 'getApiKey':
            return func.HttpResponse(
                body=json.dumps({"apiKey": api_key}),
                status_code=200,
                mimetype="application/json"
            )

        request_api_key = req.params.get('code')
        logging.info(f"Request API key: {request_api_key}")
        if not request_api_key:
            return func.HttpResponse(
                body=json.dumps({"error": "API key is missing in the request."}),
                status_code=400,
                mimetype="application/json"
            )
        
        if request_api_key != api_key:
            logging.error("Unauthorized request.")
            return func.HttpResponse(
                body=json.dumps({"error": "Unauthorized request."}),
                status_code=401,
                mimetype="application/json"
            )

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
