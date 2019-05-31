import os
import sys
import json
import yaml
import boto3
import botocore
import click
import subprocess
import re
import colorama
from colorama import Fore

colorama.init(autoreset=True)


@click.group()
@click.option('--debug', '-d', is_flag=True)
@click.option('--profile-name', '-p', type=str)
@click.option('--region-name', '-r', type=str)
@click.pass_context
def cli(ctx, debug, profile_name, region_name):
    session = boto3.session.Session(profile_name=profile_name,
                                    region_name=region_name)
    ctx.obj = {
        'session': session,
        'profile_name': profile_name,
        'region_name': region_name
    }


@cli.command(name='create-key-pair')
@click.option('--key-name', '-k', type=str, required=True)
@click.pass_context
def create_key_pair(ctx, key_name):
    ec2 = ctx.obj['session'].client('ec2')
    try:
        response = ec2.create_key_pair(KeyName=key_name)
    except botocore.exceptions.ClientError as e:
        print(Fore.YELLOW + str(e))
        sys.exit(0)
    with open(key_name + '.pem', 'w+') as pem:
        pem.write(response['KeyMaterial'])
    os.chmod(key_name + '.pem', 0o400)


@cli.command(name='delete-key-pair')
@click.option('--key-name', '-k', type=str, required=True)
@click.pass_context
def delete_key_pair(ctx, key_name):
    ec2 = ctx.obj['session'].client('ec2')
    try:
        ec2.describe_key_pairs(KeyNames=[
            key_name,
        ], )
    except botocore.exceptions.ClientError as e:
        print(Fore.YELLOW + str(e))
        sys.exit(0)
    ec2.delete_key_pair(KeyName=key_name)
    os.remove(key_name + '.pem')


@cli.command(name='launch-stack')
@click.option('--stack-name', '-s', type=str, required=True)
@click.option('--template-body', '-t', type=str, required=True)
@click.option('--parameter-file', '-P', type=str)
@click.pass_context
def launch_stack(ctx, stack_name, template_body, parameter_file):
    cfn = ctx.obj['session'].client('cloudformation')
    try:
        stack_description = cfn.describe_stacks(StackName=stack_name)
        stack_state = stack_description['Stacks'][0]['StackStatus']
    except botocore.exceptions.ClientError:
        stack_state = "NON_EXISTENT"

    if parameter_file:
        parameters = _get_parameters(parameter_file)
    else:
        parameters = {}
    if stack_state == 'CREATE_COMPLETE' or stack_state == 'UPDATE_COMPLETE':
        try:
            response = cfn.update_stack(
                StackName=stack_name,
                TemplateBody=_get_template(template_body),
                Parameters=parameters)
        except botocore.exceptions.ClientError as e:
            print(Fore.YELLOW + str(e))
            sys.exit(0)
        waiter = cfn.get_waiter('stack_update_complete')
    else:
        response = cfn.create_stack(StackName=stack_name,
                                    TemplateBody=_get_template(template_body),
                                    Parameters=parameters)
        waiter = cfn.get_waiter('stack_create_complete')
    print(Fore.GREEN +
          'Launching stack, Stack Id: {}'.format(response['StackId']))
    try:
        waiter.wait(StackName=response['StackId'],
                    WaiterConfig={
                        'Delay': 10,
                        'MaxAttempts': 123
                    })
    except botocore.exceptions.WaiterError as e:
        print(Fore.RED + str(e))


@cli.command(name='delete-stack')
@click.option('--stack-name', '-s', type=str, required=True)
@click.pass_context
def delete_stack(ctx, stack_name):
    cfn = ctx.obj['session'].client('cloudformation')
    cfn.delete_stack(StackName=stack_name)
    print('Deleting stack: {}'.format(stack_name))
    waiter = cfn.get_waiter('stack_delete_complete')
    waiter.wait(StackName=stack_name,
                WaiterConfig={
                    'Delay': 10,
                    'MaxAttempts': 123
                })
    print(Fore.YELLOW + 'Stack {} deleted'.format(stack_name))


@cli.command(name='package')
@click.option('--template-body', '-t', type=str, required=True)
@click.option('--output-template', '-o', type=str, default='')
@click.option('--bucket-name', '-b', type=str, required=True)
@click.pass_context
def package(ctx, template_body, output_template, bucket_name):
    if not output_template:
        output_template = re.sub(".+/", "", template_body)
        output_template = 'pkg_' + output_template
    cmd = 'aws cloudformation package'
    cmd += ' --template-file {}'.format(template_body)
    cmd += ' --s3-bucket {}'.format(bucket_name)
    cmd += ' --output-template-file {}'.format(output_template)
    cmd += ' --profile {}'.format(ctx.obj['profile_name'])
    cmd += ' --region {}'.format(ctx.obj['region_name'])
    process = subprocess.Popen([cmd],
                               stdout=subprocess.PIPE,
                               shell=True,
                               universal_newlines=True)
    print(Fore.GREEN + process.communicate()[0])


@cli.command(name='get-bastions-endpoints')
@click.pass_context
@click.option('--key-name', '-k', type=str, required=True)
def get_bastions_endpoints(ctx, key_name):
    filters = [{
        "Name": "tag:Service",
        "Values": ["bastion"]
    }, {
        "Name": "instance-state-name",
        "Values": ["running"]
    }]
    response = describe_instances(ctx, filters)
    endpoints = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            endpoints.append(instance['PublicDnsName'])
    print(Fore.GREEN +
          'You can now access bastions with command(s) printed below')
    for endpoint in endpoints:
        print('ssh -i {}.pem ec2-user@{}'.format(key_name, endpoint))


def describe_instances(ctx, filters):
    ec2 = ctx.obj['session'].client('ec2')
    response = ec2.describe_instances(Filters=filters)
    return response


def _get_parameters(file):
    with open(file, 'r') as parameters:
        data = json.load(parameters)
    return data


def _get_template(file):
    with open(file, 'r') as template:
        data = yaml.safe_load(template)
    return json.dumps(data)


if __name__ == '__main__':
    cli()
