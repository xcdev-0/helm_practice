#!/usr/bin/env bash

set -e  # Exit on any error

# Configurable variables
CN="kafka.kafka-headless.default.svc"
KEYSTORE_FILENAME="kafka.keystore.jks"
CA_PASS="capassword"
TRUST_STORE_PASS="thisistruststorepassword"

VALIDITY_IN_DAYS=3650
DEFAULT_TRUSTSTORE_FILENAME="kafka.truststore.jks"
TRUSTSTORE_WORKING_DIRECTORY="truststore"
KEYSTORE_WORKING_DIRECTORY="keystore"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"

# Helper to prevent overwriting existing files
function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

# Check that important files do not already exist
for file in "$KEYSTORE_WORKING_DIRECTORY" "$CA_CERT_FILE" "$KEYSTORE_SIGN_REQUEST" "$KEYSTORE_SIGN_REQUEST_SRL" "$KEYSTORE_SIGNED_CERT"
do
  if [ -e "$file" ]; then
    file_exists_and_exit $file
  fi
done

# Welcome message
echo "Welcome to the Kafka SSL keystore and truststore generator script."
echo

# Ask user whether to generate a new truststore
read -p "Do you need to generate a trust store and associated private key? [yn] " generate_trust_store

trust_store_file=""
trust_store_private_key_file=""

if [ "$generate_trust_store" == "y" ]; then
  # Make sure truststore dir doesn't already exist
  if [ -e "$TRUSTSTORE_WORKING_DIRECTORY" ]; then
    file_exists_and_exit $TRUSTSTORE_WORKING_DIRECTORY
  fi

  mkdir $TRUSTSTORE_WORKING_DIRECTORY

  # Generate CA private key and cert
  # -out: certificate, -keyout: private key
  # ca 인증서와 키 생성
  openssl req -new -x509 \
    -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
    -out $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE \
    -days $VALIDITY_IN_DAYS \
    -subj "/CN=ca/O=pknu/C=KR" \
    -passout pass:"$CA_PASS"

  trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

  # CA 인증서를 JKS truststore 파일에 넣는 작업
  echo "⛏️ creating truststore file"
  # Import the CA cert into the truststore
  keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
    -storetype JKS \
    -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE \
    -storepass "$TRUST_STORE_PASS" 

  trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

  # Remove the temporary cert file (it's now inside the truststore)
  rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE
else
  # User supplies paths to existing truststore and CA key
  read -e -p "Enter the path of the trust store file: " trust_store_file
  [ -f $trust_store_file ] || { echo "$trust_store_file isn't a file. Exiting."; exit 1; }

  read -e -p "Enter the path of the trust store's private key: " trust_store_private_key_file
  [ -f $trust_store_private_key_file ] || { echo "$trust_store_private_key_file isn't a file. Exiting."; exit 1; }
fi

echo "Continuing with:
 - trust store file:        $trust_store_file
 - trust store private key: $trust_store_private_key_file"

mkdir $KEYSTORE_WORKING_DIRECTORY
