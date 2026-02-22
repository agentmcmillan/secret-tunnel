"""
ZeroTeir Instance Control Lambda
Handles starting, stopping, and status checking of the VPN EC2 instance.
"""

import json
import os
import logging
from typing import Dict, Any

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2 = boto3.client('ec2')

# Get configuration from environment
INSTANCE_ID = os.environ['INSTANCE_ID']


def cors_headers() -> Dict[str, str]:
    """Return CORS headers for API responses."""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,x-api-key',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        'Content-Type': 'application/json'
    }


def success_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Format a successful API response."""
    return {
        'statusCode': status_code,
        'headers': cors_headers(),
        'body': json.dumps(body)
    }


def error_response(status_code: int, message: str, error_type: str = 'Error') -> Dict[str, Any]:
    """Format an error API response."""
    return {
        'statusCode': status_code,
        'headers': cors_headers(),
        'body': json.dumps({
            'error': error_type,
            'message': message
        })
    }


def get_instance_info() -> Dict[str, Any]:
    """
    Retrieve current instance information.

    Returns:
        Dictionary containing instance state, public IP, and launch time
    """
    try:
        response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])

        if not response['Reservations']:
            raise ValueError(f"Instance {INSTANCE_ID} not found")

        instance = response['Reservations'][0]['Instances'][0]

        return {
            'instanceId': INSTANCE_ID,
            'state': instance['State']['Name'],
            'publicIp': instance.get('PublicIpAddress', None),
            'launchTime': instance.get('LaunchTime', '').isoformat() if instance.get('LaunchTime') else None,
            'instanceType': instance.get('InstanceType', 'unknown')
        }

    except ClientError as e:
        logger.error(f"AWS API error: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting instance info: {e}")
        raise


def start_instance() -> Dict[str, Any]:
    """
    Start the VPN instance and wait for it to be running.

    Returns:
        Dictionary containing the instance status after starting
    """
    try:
        logger.info(f"Starting instance {INSTANCE_ID}")

        # Check current state
        instance_info = get_instance_info()
        current_state = instance_info['state']

        if current_state == 'running':
            logger.info("Instance is already running")
            return {
                'action': 'start',
                'message': 'Instance is already running',
                **instance_info
            }

        if current_state == 'pending':
            logger.info("Instance is already starting")
            return {
                'action': 'start',
                'message': 'Instance is already starting',
                **instance_info
            }

        # Start the instance
        ec2.start_instances(InstanceIds=[INSTANCE_ID])
        logger.info(f"Start command sent for {INSTANCE_ID}")

        # Wait for instance to be running (with timeout)
        waiter = ec2.get_waiter('instance_running')
        waiter.wait(
            InstanceIds=[INSTANCE_ID],
            WaiterConfig={
                'Delay': 5,
                'MaxAttempts': 40  # 40 * 5 = 200 seconds max
            }
        )

        # Get updated instance info
        instance_info = get_instance_info()
        logger.info(f"Instance started successfully: {instance_info['publicIp']}")

        return {
            'action': 'start',
            'message': 'Instance started successfully',
            **instance_info
        }

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f"Failed to start instance: {error_code} - {error_message}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error starting instance: {e}")
        raise


def stop_instance() -> Dict[str, Any]:
    """
    Stop the VPN instance.

    Returns:
        Dictionary containing the instance status
    """
    try:
        logger.info(f"Stopping instance {INSTANCE_ID}")

        # Check current state
        instance_info = get_instance_info()
        current_state = instance_info['state']

        if current_state in ['stopped', 'stopping']:
            logger.info(f"Instance is already {current_state}")
            return {
                'action': 'stop',
                'message': f'Instance is already {current_state}',
                **instance_info
            }

        # Stop the instance
        ec2.stop_instances(InstanceIds=[INSTANCE_ID])
        logger.info(f"Stop command sent for {INSTANCE_ID}")

        # Get updated instance info (don't wait for stopped state)
        instance_info = get_instance_info()

        return {
            'action': 'stop',
            'message': 'Instance stop initiated',
            **instance_info
        }

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f"Failed to stop instance: {error_code} - {error_message}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error stopping instance: {e}")
        raise


def get_status() -> Dict[str, Any]:
    """
    Get current instance status.

    Returns:
        Dictionary containing the current instance status
    """
    try:
        logger.info(f"Getting status for instance {INSTANCE_ID}")
        instance_info = get_instance_info()

        return {
            'action': 'status',
            **instance_info
        }

    except Exception as e:
        logger.error(f"Error getting instance status: {e}")
        raise


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for instance control operations.

    Args:
        event: API Gateway event
        context: Lambda context

    Returns:
        API Gateway response
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # Handle OPTIONS for CORS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return success_response(200, {'message': 'OK'})

    try:
        # Extract path and method
        path = event.get('path', '')
        method = event.get('httpMethod', '')

        logger.info(f"Processing {method} {path}")

        # Route to appropriate handler
        if path.endswith('/start') and method == 'POST':
            result = start_instance()
            return success_response(200, result)

        elif path.endswith('/stop') and method == 'POST':
            result = stop_instance()
            return success_response(200, result)

        elif path.endswith('/status') and method == 'GET':
            result = get_status()
            return success_response(200, result)

        else:
            return error_response(404, f"Not found: {method} {path}", "NotFound")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'UnauthorizedOperation':
            return error_response(403, "Insufficient permissions", "Forbidden")
        elif error_code in ['InvalidInstanceID.NotFound', 'InvalidInstanceID.Malformed']:
            return error_response(404, f"Instance not found: {INSTANCE_ID}", "NotFound")
        else:
            return error_response(500, f"AWS error: {error_message}", error_code)

    except ValueError as e:
        return error_response(400, str(e), "ValidationError")

    except Exception as e:
        logger.exception("Unexpected error in lambda_handler")
        return error_response(500, f"Internal server error: {str(e)}", "InternalError")
