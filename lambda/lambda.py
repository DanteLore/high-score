import os
import re
import json
import decimal
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError
from better_profanity import profanity

# DynamoDB client/resource initialization

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

# Pre-compiled regex patterns
URL_EMAIL_PATTERN = re.compile(
    r"(https?://\S+|www\.\S+|\b[\w.+-]+@[\w-]+\.[\w.-]+\b)",
    re.IGNORECASE
)
# Allow alphanumeric characters and spaces
NON_ALNUM_PATTERN = re.compile(r"[^A-Za-z0-9 ]")

# Initialize profanity filter (loads default word list)
profanity.load_censor_words()

# JSON encoder to handle DynamoDB Decimal types
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            # Convert int-like decimals to int, otherwise float
            if o % 1 == 0:
                return int(o)
            return float(o)
        return super(DecimalEncoder, self).default(o)


def sanitize_name(raw_name: str, max_length: int = 20) -> str:
    """
    Cleans up the player name by removing URLs, email addresses,
    stripping non-alphanumeric (except spaces) characters, filtering profanity,
    and truncating to max_length.
    """
    # Remove URLs and email addresses
    name = URL_EMAIL_PATTERN.sub('', raw_name)
    # Remove non-alphanumeric (except spaces) characters
    name = NON_ALNUM_PATTERN.sub('', name)
    # Trim whitespace
    name = name.strip()
    # Mask any swear words
    name = profanity.censor(name)
    # Truncate to max_length
    return name[:max_length] if name else ''


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
        return get_top_scores(game_id)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Not Found'})
        }


def store_score(event):
    try:
        payload = json.loads(event.get('body') or '{}')
        game_id     = payload['game_id']
        raw_name    = payload['player_name']
        timestamp   = payload['timestamp']
        score       = decimal.Decimal(str(payload['score']))
    except (KeyError, TypeError, ValueError) as e:
        return {'statusCode': 400, 'body': json.dumps({'message': f'Invalid request payload: {e}'})}

    sanitized_name = sanitize_name(raw_name)

    # Validate sanitized name
    if not sanitized_name or set(sanitized_name) == {'*'}:
        return {'statusCode': 400, 'body': json.dumps({'message': 'player_name contains no valid characters or is entirely profane'})}

    try:
        table.put_item(Item={
            'game_id'     : game_id,
            'score'       : score,
            'player_name' : sanitized_name,
            'timestamp'   : timestamp
        })
    except ClientError as e:
        return {'statusCode': 500, 'body': json.dumps({'message': f'Failed to write score: {e.response["Error"]["Message"]}'})}

    return {'statusCode': 200, 'body': json.dumps({'message': 'Score recorded'})}


def get_top_scores(game_id: str):
    if not game_id:
        return {'statusCode': 400, 'body': json.dumps({'message': 'Missing required path parameter: game_id'})}

    try:
        resp = table.query(
            KeyConditionExpression=Key('game_id').eq(game_id),
            ScanIndexForward=False,
            Limit=10
        )
    except ClientError as e:
        return {'statusCode': 500, 'body': json.dumps({'message': f'Error retrieving scores: {e.response["Error"]["Message"]}'})}

    items = resp.get('Items', [])
    if not items:
        return {'statusCode': 200, 'body': json.dumps({'message': f'No scores found for game_id "{game_id}"', 'scores': []})}

    return {'statusCode': 200, 'body': json.dumps({'message': 'Top scores retrieved', 'scores': items}, cls=DecimalEncoder)}
