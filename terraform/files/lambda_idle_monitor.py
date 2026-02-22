"""
ZeroTeir Idle Monitor Lambda
Monitors Headscale connections and auto-stops instance when idle.
"""

import json
import os
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from urllib import request, error
from urllib.parse import urljoin

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')

# Get configuration from environment
INSTANCE_ID = os.environ['INSTANCE_ID']
HEADSCALE_URL = os.environ['HEADSCALE_URL']
IDLE_TIMEOUT_MINUTES = int(os.environ.get('IDLE_TIMEOUT_MINUTES', '60'))
CLOUDWATCH_NAMESPACE = os.environ.get('CLOUDWATCH_NAMESPACE', 'ZeroTeir')


def get_instance_state() -> str:
    """
    Get current EC2 instance state.

    Returns:
        Instance state (running, stopped, pending, etc.)
    """
    try:
        response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
        if not response['Reservations']:
            raise ValueError(f"Instance {INSTANCE_ID} not found")

        instance = response['Reservations'][0]['Instances'][0]
        return instance['State']['Name']

    except ClientError as e:
        logger.error(f"Error getting instance state: {e}")
        raise


def check_headscale_health() -> bool:
    """
    Check if Headscale is responding to health checks.

    Returns:
        True if Headscale is healthy, False otherwise
    """
    try:
        health_url = urljoin(HEADSCALE_URL, '/health')
        logger.info(f"Checking Headscale health at {health_url}")

        req = request.Request(health_url, method='GET')
        req.add_header('User-Agent', 'ZeroTeir-IdleMonitor/1.0')

        with request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                logger.info("Headscale health check passed")
                return True
            else:
                logger.warning(f"Headscale health check returned status {response.status}")
                return False

    except error.URLError as e:
        logger.warning(f"Headscale health check failed: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error checking Headscale health: {e}")
        return False


def get_headscale_nodes() -> Optional[list]:
    """
    Query Headscale API for list of nodes (machines).

    Returns:
        List of nodes or None if query fails
    """
    try:
        # Note: This is a simplified version. In production, you would:
        # 1. Use Headscale API key authentication
        # 2. Query the /api/v1/node endpoint
        # 3. Parse the response for active connections
        #
        # For now, we'll use a health check as a proxy for activity

        nodes_url = urljoin(HEADSCALE_URL, '/api/v1/node')
        logger.info(f"Querying Headscale nodes at {nodes_url}")

        # TODO: Implement proper API authentication
        # This requires storing Headscale API key in AWS Secrets Manager
        # and retrieving it here

        # For MVP, we return None to disable detailed node checking
        logger.warning("Headscale API integration not yet implemented")
        return None

    except Exception as e:
        logger.error(f"Error querying Headscale nodes: {e}")
        return None


def count_active_connections() -> int:
    """
    Count number of active VPN connections.

    Returns:
        Number of active connections (0 if unable to determine)
    """
    # Check if Headscale is responding
    if not check_headscale_health():
        logger.info("Headscale not responding, assuming no active connections")
        return 0

    # Try to get node list
    nodes = get_headscale_nodes()

    if nodes is None:
        # If we can't query the API, assume there's activity if health check passed
        logger.info("Cannot query nodes, assuming activity based on health check")
        return 1

    # Count nodes that have been seen recently (within timeout window)
    now = datetime.now(timezone.utc)
    active_count = 0

    for node in nodes:
        last_seen_str = node.get('lastSeen', '')
        if last_seen_str:
            try:
                last_seen = datetime.fromisoformat(last_seen_str.replace('Z', '+00:00'))
                idle_minutes = (now - last_seen).total_seconds() / 60

                if idle_minutes < IDLE_TIMEOUT_MINUTES:
                    active_count += 1
                    logger.info(f"Node {node.get('name', 'unknown')} active (idle {idle_minutes:.1f}m)")
                else:
                    logger.info(f"Node {node.get('name', 'unknown')} idle ({idle_minutes:.1f}m)")

            except (ValueError, TypeError) as e:
                logger.warning(f"Error parsing lastSeen time: {e}")

    logger.info(f"Total active connections: {active_count}")
    return active_count


def publish_metrics(active_connections: int, instance_state: str) -> None:
    """
    Publish metrics to CloudWatch.

    Args:
        active_connections: Number of active VPN connections
        instance_state: Current EC2 instance state
    """
    try:
        # Map instance state to numeric value
        state_value_map = {
            'running': 1,
            'stopped': 0,
            'pending': 0,
            'stopping': 0,
            'terminated': -1
        }
        state_value = state_value_map.get(instance_state, -1)

        metrics = [
            {
                'MetricName': 'ActiveConnections',
                'Value': active_connections,
                'Unit': 'Count',
                'Timestamp': datetime.now(timezone.utc)
            },
            {
                'MetricName': 'InstanceState',
                'Value': state_value,
                'Unit': 'None',
                'Timestamp': datetime.now(timezone.utc)
            }
        ]

        cloudwatch.put_metric_data(
            Namespace=CLOUDWATCH_NAMESPACE,
            MetricData=metrics
        )

        logger.info(f"Published metrics: ActiveConnections={active_connections}, InstanceState={state_value}")

    except ClientError as e:
        logger.error(f"Error publishing metrics: {e}")
    except Exception as e:
        logger.error(f"Unexpected error publishing metrics: {e}")


def stop_instance() -> bool:
    """
    Stop the EC2 instance.

    Returns:
        True if instance was stopped, False otherwise
    """
    try:
        logger.info(f"Stopping idle instance {INSTANCE_ID}")

        ec2.stop_instances(InstanceIds=[INSTANCE_ID])

        logger.info(f"Instance {INSTANCE_ID} stop initiated")
        return True

    except ClientError as e:
        logger.error(f"Error stopping instance: {e}")
        return False


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for idle monitoring.

    Args:
        event: EventBridge event
        context: Lambda context

    Returns:
        Result dictionary
    """
    logger.info("Idle monitor check started")

    try:
        # Get current instance state
        instance_state = get_instance_state()
        logger.info(f"Instance state: {instance_state}")

        # Only check connections if instance is running
        if instance_state != 'running':
            logger.info(f"Instance not running (state: {instance_state}), skipping idle check")

            # Still publish metrics
            publish_metrics(0, instance_state)

            return {
                'statusCode': 200,
                'action': 'skipped',
                'reason': f'Instance not running (state: {instance_state})',
                'instanceState': instance_state
            }

        # Count active connections
        active_connections = count_active_connections()

        # Publish metrics
        publish_metrics(active_connections, instance_state)

        # Determine if instance should be stopped
        if active_connections == 0:
            logger.info(f"No active connections detected, stopping instance")

            if stop_instance():
                return {
                    'statusCode': 200,
                    'action': 'stopped',
                    'reason': 'No active connections',
                    'activeConnections': active_connections,
                    'instanceState': 'stopping'
                }
            else:
                return {
                    'statusCode': 500,
                    'action': 'error',
                    'reason': 'Failed to stop instance',
                    'activeConnections': active_connections,
                    'instanceState': instance_state
                }
        else:
            logger.info(f"{active_connections} active connection(s), instance remains running")

            return {
                'statusCode': 200,
                'action': 'running',
                'reason': f'{active_connections} active connection(s)',
                'activeConnections': active_connections,
                'instanceState': instance_state
            }

    except Exception as e:
        logger.exception("Unexpected error in idle monitor")

        return {
            'statusCode': 500,
            'action': 'error',
            'reason': str(e)
        }
