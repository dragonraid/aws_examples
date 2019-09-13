#!/usr/bin/env bash
REGION=$1
PROFILE=$2
if [[ "$3" == "create" ]]
then
    # add if dir exists exit
    if [[ -d ".certs" ]]
    then
        echo "Certificate already exists"
        exit 0
    fi
    # create output directory
    mkdir .certs

    # generate root CA
    openssl genrsa -out .certs/rootCA.key 2048 > /dev/null 2>&1 
    openssl req -x509 -new -nodes -key .certs/rootCA.key -sha256 -days 1024 -out .certs/rootCA.crt -subj "/CN=wakanda\/emailAddress=admin@foo.bar/C=US/ST=Ohio/L=Columbus/O=Widgets Inc/OU=Some Unit" > /dev/null 2>&1
    openssl x509 -in .certs/rootCA.crt -out .certs/rootCA.pem -outform PEM > /dev/null 2>&1

    # generate intermediate CA and sign it with Root CA
    openssl genrsa -out .certs/IntermediateCA.key 2048 > /dev/null 2>&1
    openssl req -new -key .certs/IntermediateCA.key -out .certs/IntermediateCA.csr -subj "/CN=wakanda\/emailAddress=admin@foo.bar/C=US/ST=Ohio/L=Columbus/O=Widgets Inc/OU=Some Unit" > /dev/null 2>&1
    openssl x509 -req -in .certs/IntermediateCA.csr -CA .certs/rootCA.crt -CAkey .certs/rootCA.key -CAcreateserial -out .certs/IntermediateCA.crt -days 500 -sha256 > /dev/null 2>&1
    openssl x509 -in .certs/IntermediateCA.crt -out .certs/IntermediateCA.pem -outform PEM > /dev/null 2>&1

    # generate server certificate and sign it with Intermediate CA
    openssl genrsa -out .certs/Server.key 2048 > /dev/null 2>&1
    openssl req -new -key .certs/Server.key -out .certs/Server.csr -subj "/CN=wakanda\/emailAddress=admin@foo.bar/C=US/ST=Ohio/L=Columbus/O=Widgets Inc/OU=Some Unit" > /dev/null 2>&1
    openssl x509 -req -in .certs/Server.csr -CA .certs/IntermediateCA.crt -CAkey .certs/IntermediateCA.key -CAcreateserial -out .certs/Server.crt -days 500 -sha256 > /dev/null 2>&1
    openssl x509 -in .certs/Server.crt -out .certs/Server.pem -outform PEM > /dev/null 2>&1

    # create certificate chain
    cat .certs/IntermediateCA.pem >> .certs/chain.pem && cat .certs/rootCA.pem >> .certs/chain.pem

    # upload certificate to IAM, cannot to ACM because of not having website url
    cert_arn=$(aws iam upload-server-certificate --server-certificate-name MySelfSignedCert \
                                      --certificate-body file://.certs/Server.pem \
                                      --private-key file://.certs/Server.key --region $REGION --profile $PROFILE | jq '.ServerCertificateMetadata.Arn' | tr -d '"')
    # reference certificate in SSM
    aws ssm put-parameter --name webappCertificate --description "WebApplication certificate" --type String --value $cert_arn  --region $REGION --profile $PROFILE > /dev/null 2>&1
elif [[ "$3" == "delete" ]]
then
    echo "Deleting self-signed certificate"
    aws ssm delete-parameter --name webappCertificate --region $REGION --profile $PROFILE
    aws iam delete-server-certificate --server-certificate-name MySelfSignedCert --region $REGION --profile $PROFILE
    rm -fr .certs .srl
else
    echo "Unknown option $3"
fi