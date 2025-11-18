import json
import boto3
import os
from datetime import datetime

batch_client = boto3.client('batch')


def load_tenant_codes():
    """tenant_codes.jsonからテナントコードを読み込む"""
    config_path = os.path.join(os.path.dirname(__file__), 'tenant_codes.json')
    with open(config_path, 'r') as f:
        config = json.load(f)
    return config.get('tenant_codes', [])


def lambda_handler(event, context):
    """
    tenant_codes.jsonからテナントコードを読み込み、AWS Batchジョブを実行する

    Event format (オプション):
    {
        "tenant_codes": ["acme", "techcorp"]  # 指定した場合はファイルを上書き
    }
    or
    {}  # 空の場合はファイルから読み込み
    """
    print(f"Received event: {json.dumps(event)}")

    # 環境変数から設定を取得
    job_queue = os.environ.get('BATCH_JOB_QUEUE')
    job_definition = os.environ.get('BATCH_JOB_DEFINITION')

    if not job_queue or not job_definition:
        raise ValueError("BATCH_JOB_QUEUE and BATCH_JOB_DEFINITION must be set")

    # tenant_codesを取得（イベントで指定されていない場合はファイルから読み込み）
    tenant_codes = []

    if 'tenant_codes' in event:
        codes = event['tenant_codes']
        if isinstance(codes, str):
            tenant_codes = [code.strip() for code in codes.split(',')]
        elif isinstance(codes, list):
            tenant_codes = codes
    elif 'tenant_code' in event:
        tenant_codes = [event['tenant_code']]
    else:
        # ファイルから読み込み
        tenant_codes = load_tenant_codes()
        print(f"Loaded tenant codes from file: {tenant_codes}")

    if not tenant_codes:
        raise ValueError("No tenant codes provided")

    print(f"Processing tenant codes: {tenant_codes}")

    # ジョブ名を生成
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    job_name = f"lambda-specific-batch-{timestamp}"

    # AWS Batchジョブを実行
    # テナントコードをカンマ区切り文字列として渡す（8192文字制限対策）
    tenant_codes_str = ','.join(tenant_codes)
    response = batch_client.submit_job(
        jobName=job_name,
        jobQueue=job_queue,
        jobDefinition=job_definition,
        containerOverrides={
            'command': [tenant_codes_str]
        }
    )

    print(f"Job submitted: {response['jobId']}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Batch job submitted successfully',
            'jobId': response['jobId'],
            'jobName': job_name,
            'tenantCodes': tenant_codes
        })
    }
