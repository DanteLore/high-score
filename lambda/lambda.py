import os
import json
import decimal
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

# DynamoDB client/resource initialization
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

# JSON encoder to handle DynamoDB Decimal types
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            # Convert int-like decimals to int, otherwise float
            if o % 1 == 0:
                return int(o)
            return float(o)
        return super(DecimalEncoder, self).default(o)


def lambda_handler(event, context):
    method = (
        event.get('requestContext', {})
             .get('http', {})
             .get('method', event.get('httpMethod', 'GET'))
    )
    path = event.get('rawPath', event.get('path', '/score'))

    if method == 'POST' and path == '/score':
        return store_score(event)
    elif method == 'GET' and path.startswith('/score/'):
        game_id = event.get('pathParameters', {}).get('game_id')
        return get_top_scores(event, game_id)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Not Found'})
        }
    

def store_score(event):
    try:
        payload = json.loads(event.get('body') or '{}')
        game_id     = payload['game_id']
        player_name = payload['player_name']
        timestamp   = payload['timestamp']
        score       = decimal.Decimal(str(payload['score']))
    except (KeyError, TypeError, ValueError) as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': f'Invalid request payload: {e}'})
        }

    try:
        table.put_item(Item={
            'game_id'     : game_id,
            'score'       : score,
            'player_name' : player_name,
            'timestamp'   : timestamp
        })
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Failed to write score: {e.response["Error"]["Message"]}'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Score recorded'})
    }


def get_top_scores(event, game_id):
    if not game_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Missing required path parameter: game_id'})
        }

    try:
        resp = table.query(
            KeyConditionExpression=Key('game_id').eq(game_id),
            ScanIndexForward=False,  # descending on sort key
            Limit=10
        )
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Error retrieving scores: {e.response["Error"]["Message"]}'})
        }

    items = resp.get('Items', [])

    if not items:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message' : f'No scores found for game_id "{game_id}"',
                'scores'  : []
            })
        }

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message' : 'Top scores retrieved',
            'scores'  : items
        }, cls=DecimalEncoder)
    }
