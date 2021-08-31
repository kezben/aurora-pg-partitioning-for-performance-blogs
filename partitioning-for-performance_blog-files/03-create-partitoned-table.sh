#!/bin/bash

unset AWS_DEFAULT_REGION

while getopts 's:r:ch' flag; do
  case "${flag}" in
    s) AURORA_DB_CFSTACK_NAME="${OPTARG}" ;;
    r) AWS_DEFAULT_REGION="${OPTARG}" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

# Check that region var is set
if [ -z $AURORA_DB_CFSTACK_NAME ]
then
    printf "The AWS stack var isn't set. Please use -s to set this stack, and ensure it's already completed sucessfully.\n"
    exit 1
else
    printf "The AWS Stack is set, continuing.\n"
fi

# Check that region var is set
if [ -z $AWS_DEFAULT_REGION ]
then
    printf "The AWS default region var isn't set. Please use -r to set this stack.\n"
    exit 1
else
    printf "The AWS default region is set, continuing.\n"
fi

## Mainline

echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME

SrcRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')
TgtRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')

echo "RDS Source endpoint:" $SrcRDSEndPoint
echo "RDS Destination endpoint" $TgtRDSEndPoint


export SrcDBUsername="pgadmin"
export SrcDBPassword="auradmin"
export TgtDBUsername="pgadmin"
export TgtDBPassword="auradmin"



# install schema in data_mart_new schema

psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"create schema data_mart_new;"
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -f data_mart.events-pre-schema.sql

echo "Using pgpartman to create partitioned tables"
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"CREATE SCHEMA partman;CREATE EXTENSION pg_partman WITH SCHEMA partman;"
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"SELECT partman.create_parent( p_parent_table => 'data_mart_new.events', \
p_control => 'created_at', \
p_type => 'native', \
p_interval=> 'monthly', \
p_premake => 12);"

