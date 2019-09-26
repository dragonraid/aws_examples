#!/usr/bin/env bash

# SANITY CHECK
sanity_check () {
    for command in "$@"
    do
        which $command > /dev/null 2>&1 || (echo "$command not installed. Exiting.." && exit 1)
    done
}

# ERROR EXIT
function error_exit {
    echo "$1 failed with exit code $2"
    exit $2
}

function get_stack_status {
    # TODO distinguish between err types
    status=$(aws cloudformation describe-stacks --stack-name $1 --profile $AWS_PROFILE --region $AWS_REGION 2> /dev/null | jq '.Stacks[0].StackStatus' | tr -d '"')
    echo $status
}

function package {
    packaged_template="$(dirname $1)/pkg_$(basename $1)"
	aws cloudformation package --template-file $1 --s3-bucket $S3_BUCKET --output-template-file $packaged_template --profile $AWS_PROFILE --region $AWS_REGION > /dev/null
    echo $packaged_template
}

function launch {
    echo "Getting $1 stack state"
    status=$(get_stack_status $1)

    # Determine action what to do
    if [ -z "$status" ]
    then
        echo "Stack $1 does not exists. Creating.."
        action="CREATE"
    elif [ "$status" = "CREATE_COMPLETE" ] || [ "$status" = "UPDATE_COMPLETE" ]
    then
        echo "Stack $1 is in $status state. Updating.."
        action="UPDATE"
    else
        echo "Stack in $status state. Exiting.."
        exit 0
    fi

    # package stack or not
    if [ ! -z "$4" ]
    then
        stack_path=$(package "$2")
    else
        stack_path=$2
    fi

    # Take action
    case $action in
        CREATE)
            stack_id=$(aws cloudformation create-stack --stack-name $1 --template-body file://$stack_path --parameters file://$3 --disable-rollback $capabilities --profile $AWS_PROFILE --region $AWS_REGION --output text) || error_exit $0 $?
            echo "Stack ID: $stack_id"
            aws cloudformation wait stack-create-complete --stack-name $1 --profile $AWS_PROFILE --region $AWS_REGION || error_exit $0 $?
            echo "Stack $1 created"
            ;;
        UPDATE)
            stack_id$(aws cloudformation update-stack --stack-name $1 --template-body file://$stack_path --parameters file://$3 $capabilities --profile $AWS_PROFILE --region $AWS_REGION --output text) || error_exit $0 $?
            echo "Stack ID: $stack_id"
            aws cloudformation wait stack-update-complete --stack-name $1 --profile $AWS_PROFILE --region $AWS_REGION || error_exit $0 $?
            echo "Stack $1 updated"
            ;;
        *) echo "$0 Unknown action: $action."
        ;;
    esac
}

function delete {
    echo "Deleting $1 stack"
    aws cloudformation delete-stack --stack-name $1 --profile $AWS_PROFILE --region $AWS_REGION
    aws cloudformation wait stack-delete-complete --stack-name $1 --profile $AWS_PROFILE --region $AWS_REGION
    echo "Stack $1 deleted"
}

sanity_check jq aws 
declare -a PARAMS
while (( "$#" )); do
    case "$1" in
        -P|--profile) AWS_PROFILE=$2
        shift 2
        ;;
        -R|--region) AWS_REGION=$2
        shift 2
        ;;
        -B|--bucket) S3_BUCKET=$2
        shift 2
        ;;
        -c|--capabilities) capabilities="--capabilities $2"
        shift 2
        ;;
        -n|--stack-name) stack_name=$2
        shift 2
        ;;
        -p|--package) package=true
        shift 1
        ;;
        -t|--template_body) template_body=$2
        shift 2
        ;;
        -r|--parameter-file) parameter_file=$2
        shift 2
        ;;
        -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
        ;;
        *) # preserve positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
done

# Execute command
command=${PARAMS//[[:blank:]]/}
case $command in
    launch) launch $stack_name $template_body $parameter_file $package
    exit 0
    ;;
    delete) delete $stack_name
    ;;
    *) echo "Error: Unsupported command $1" >&2
    ;;
esac
