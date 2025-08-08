#!/usr/bin/env bash

set -e  # Exit on any error

# Configurable variables
KAFKA_NAME="kafka-0"
CN="${KAFKA_NAME}.kafka-headless.default.svc"
KEYSTORE_FILENAME="${KAFKA_NAME}.keystore.jks"
CA_PASS="capassword"
STORE_PASS="storepassword"

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
  openssl req -new -x509 \
    -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
    -out $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE \
    -days $VALIDITY_IN_DAYS \
    -subj "/CN=${CN}/O=pknu/C=KR" \
    -passout pass:"$CA_PASS"

  trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

  echo "⛏️ creating truststore file"
  # Import the CA cert into the truststore
  keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
    -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE \
    -storepass "$STORE_PASS" 

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

# ===============================
# Generate the keystore and self-signed cert
# ===============================

# Generate the keystore and self-signed cert
# 이 keytool -genkey로 만들어진 self-signed cert는 실제로는 쓰지 않고,
# 다음 단계에서 CSR을 만들고 CA로 다시 서명하는 과정을 거침
# 발급된 인증서는 다시 keystore에 덮어씌어짐

keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
  -alias localhost \
  -validity $VALIDITY_IN_DAYS \
  -keyalg RSA \
  -genkey \
  -dname "CN=${CN}, OU=Dev, O=pknu, L=Busan, ST=Busan, C=KR" \
  -storepass "$STORE_PASS" 

echo "🪸 generating csr"
# Export the CA cert from truststore (to sign CSR)
keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE \
  -storepass "$STORE_PASS"

# Generate CSR (certificate signing request)
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -certreq -file $KEYSTORE_SIGN_REQUEST \
  -storepass "$STORE_PASS"


echo "🪸 generating crt using ca'cert"
# Sign the CSR with the CA private key
openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
  -in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
  -days $VALIDITY_IN_DAYS -CAcreateserial \
  -passin pass:"$CA_PASS" 


echo "🪼 import ca cert into keystore"
# Import CA cert into keystore
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
  -import -file $CA_CERT_FILE \
  -storepass "$STORE_PASS"

rm $CA_CERT_FILE

# Import the signed cert into keystore
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -import -file $KEYSTORE_SIGNED_CERT \
  -storepass "$STORE_PASS"

# Ask user if intermediate files should be deleted
read -p "Delete intermediate files? [yn] " delete_intermediate_files
if [ "$delete_intermediate_files" == "y" ]; then
  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT
fi
