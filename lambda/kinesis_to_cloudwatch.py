import json
import boto3
import base64
import gzip
import re
import logging
import os
import traceback
from datetime import datetime

cloudwatch_logs = boto3.client('logs')
# Default log group (can be overridden via LOG_GROUP_NAME env var)
log_group_name = os.environ.get('LOG_GROUP_NAME', '/aws/cloudfront/realtime-logs')

# Configure module-level logger
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO').upper()
logger = logging.getLogger(__name__)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
logger.setLevel(LOG_LEVEL)

def handler(event, context):
    logger.info("Processing %d records", len(event.get('Records', [])))
    
    for record in event['Records']:
        try:
            # Decode the Kinesis data
            payload = base64.b64decode(record['kinesis']['data'])
            
            # Try to decompress if it's gzipped
            try:
                payload = gzip.decompress(payload)
            except:
                pass  # Not gzipped
            
            # Convert bytes to string
            log_data_str = payload.decode('utf-8')
            logger.debug("Raw log data: %s...", log_data_str[:200])  # Print first 200 chars for debugging
            
            # CloudFront real-time logs are tab-separated values, not JSON
            # Let's try to parse as JSON first, if that fails, treat as TSV
            try:
                log_data = json.loads(log_data_str)
                # Try to extract client IP from common JSON fields
                client_ip = None
                for key in ("clientIp", "client_ip", "c-ip", "c_ip", "clientIpAddress", "x-forwarded-for"):
                    if isinstance(log_data, dict) and key in log_data:
                        client_ip = log_data.get(key)
                        break

                # If x-forwarded-for contains multiple IPs, take first
                if isinstance(client_ip, str) and "," in client_ip:
                    client_ip = client_ip.split(",")[0].strip()

                # Fallback: regex search in the raw string
                if not client_ip:
                    m = re.search(r"(\d{1,3}(?:\.\d{1,3}){3})", log_data_str)
                    client_ip = m.group(1) if m else None

                # Include client_ip into the message for visibility
                try:
                    if isinstance(log_data, dict):
                        log_data["client_ip"] = client_ip
                        message = json.dumps(log_data)
                    else:
                        message = json.dumps({"payload": log_data, "client_ip": client_ip})
                except Exception:
                    message = json.dumps(log_data)
            except json.JSONDecodeError:
                # If it's not JSON, treat it as CloudFront log format
                # CloudFront real-time logs are typically tab-separated
                lines = log_data_str.strip().split('\n')
                for line in lines:
                    if line.strip() and not line.startswith('#'):
                        # Process each log line
                        fields = line.split('\t')
                        # Try to extract client IP from the line using regex fallback
                        m = re.search(r"(\d{1,3}(?:\.\d{1,3}){3})", line)
                        client_ip = m.group(1) if m else None

                        if len(fields) >= 10:  # Basic validation
                            # Create a structured message and append client IP when available
                            message = f"CloudFront Log: {line}"
                        else:
                            message = f"Raw CloudFront Data: {line}"

                        if client_ip:
                            message = f"{message} | client_ip={client_ip}"
                        
                        # Create log stream name with timestamp
                        timestamp = datetime.now()
                        log_stream_name = f"cloudfront-logs-{timestamp.strftime('%Y-%m-%d-%H')}"
                        
                        # Create log stream if it doesn't exist
                        try:
                            cloudwatch_logs.create_log_stream(
                                logGroupName=log_group_name,
                                logStreamName=log_stream_name
                            )
                        except cloudwatch_logs.exceptions.ResourceAlreadyExistsException:
                            pass
                        except Exception:
                            logger.exception("Error creating log stream")
                        
                        # Send log event to CloudWatch
                        try:
                            cloudwatch_logs.put_log_events(
                                logGroupName=log_group_name,
                                logStreamName=log_stream_name,
                                logEvents=[
                                    {
                                        'timestamp': int(timestamp.timestamp() * 1000),
                                        'message': message
                                    }
                                ]
                            )
                        except Exception:
                            logger.exception("Error sending to CloudWatch")
                continue
            
            # If we got here, it was valid JSON
            timestamp = datetime.now()
            log_stream_name = f"cloudfront-logs-{timestamp.strftime('%Y-%m-%d-%H')}"
            
            # Create log stream if it doesn't exist
            try:
                cloudwatch_logs.create_log_stream(
                    logGroupName=log_group_name,
                    logStreamName=log_stream_name
                )
            except cloudwatch_logs.exceptions.ResourceAlreadyExistsException:
                pass
            except Exception:
                logger.exception("Error creating log stream")
            
            # Send log event to CloudWatch
            try:
                cloudwatch_logs.put_log_events(
                    logGroupName=log_group_name,
                    logStreamName=log_stream_name,
                    logEvents=[
                        {
                            'timestamp': int(timestamp.timestamp() * 1000),
                            'message': message
                        }
                    ]
                )
            except Exception:
                logger.exception("Error sending to CloudWatch")
                
        except Exception:
            logger.exception("Error processing record; record=%s", record)
            continue
    
    return {'statusCode': 200}


def lambda_handler(event, context):
    """Compatibility wrapper for AWS Lambda handler name used in Terraform.
    Calls the existing handler function and returns its result.
    """
    # Allow overriding the log group name from environment variables if set
    try:
        import os
        env_log_group = os.environ.get('LOG_GROUP_NAME')
        if env_log_group:
            global log_group_name
            log_group_name = env_log_group
    except Exception:
        pass

    return handler(event, context)