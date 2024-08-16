import json
import boto3

# Obtener el cliente de DynamoDB
dynamodb = boto3.client('dynamodb')
# Nombre de la tabla DynamoDB a la que quieres acceder
TABLE_NAME = "tu_nombre_de_tabla" # Reemplaza con el nombre de tu tabla

def lambda_handler(event, context):
    try:
        # Realizar la lectura en la tabla DynamoDB
        response = dynamodb.scan(TableName=TABLE_NAME)

        # Obtener los elementos de la respuesta
        items = response.get('Items', [])

        # Devolver los datos como respuesta de la API
        return {
            'statusCode': 200,
            'body': json.dumps(items),
            'headers': {
                'Content-Type': 'application/json'
            }
        }

    except Exception as e:
        # Manejo de errores básicos
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }