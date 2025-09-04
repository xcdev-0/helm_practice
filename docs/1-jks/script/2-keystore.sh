FULLNAME="my-kafka"       
NS="kafka"
CLUSTER_DOMAIN="cluster.local"

cat > openssl-san.cnf <<EOF
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${FULLNAME}.${NS}.svc.cluster.local
DNS.2 = ${FULLNAME}.${NS}.svc
DNS.3 = *.${FULLNAME}-controller-headless.${NS}.svc.cluster.local
DNS.4 = *.${FULLNAME}-controller-headless.${NS}.svc
DNS.5 = *.${FULLNAME}-broker-headless.${NS}.svc.cluster.local
DNS.6 = *.${FULLNAME}-broker-headless.${NS}.svc
EOF

CN="kafka.kafka-headless.${NS}.svc"
KEYSTORE_FILENAME="kafka.keystore.jks"
CA_PASS="capassword"
KEY_STORE_PASS="thisiskeystorepassword"
TRUST_STORE_PASS="thisistruststorepassword"

VALIDITY_IN_DAYS=3650
DEFAULT_TRUSTSTORE_FILENAME="kafka.truststore.jks"
TRUSTSTORE_WORKING_DIRECTORY="truststore"
KEYSTORE_WORKING_DIRECTORY="keystore"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"


trust_store_private_key_file="truststore/ca-key"
trust_store_file="truststore/kafka.truststore.jks"


mkdir -p "$KEYSTORE_WORKING_DIRECTORY"

# ===============================
# Generate the keystore and self-signed cert
# ===============================

# Generate the keystore and self-signed cert
# 이 keytool -genkey로 만들어진 self-signed cert는 실제로는 쓰지 않고,
# 다음 단계에서 CSR을 만들고 CA로 다시 서명하는 과정을 거침
# 발급된 인증서는 다시 keystore에 덮어씌어짐

echo "🪸 자체 서명된 인증서 & keystore 생성"
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
  -storetype JKS \
  -alias localhost \
  -validity $VALIDITY_IN_DAYS \
  -keyalg RSA \
  -genkey \
  -dname "CN=${CN}, OU=Dev, O=pknu, L=Busan, ST=Busan, C=KR" \
  -storepass "$KEY_STORE_PASS" \
  -keypass "$KEY_STORE_PASS"

echo "🍀 CA 인증서를 trust store에서 추출: ${CA_CERT_FILE}"
keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE \
  -storetype JKS \
  -storepass "$TRUST_STORE_PASS"

echo "🪸 CSR 생성"
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -storetype JKS \
  -certreq -file $KEYSTORE_SIGN_REQUEST \
  -storepass "$KEY_STORE_PASS" \
  -keypass "$KEY_STORE_PASS"


echo "🪸 CA 인증서 & 개인키로 CSR 서명(${CA_CERT_FILE}, ${trust_store_private_key_file})"
echo "openssl-san.cnf 파일을 사용하여 SAN을 복사"

openssl x509 -req \
  -in "$KEYSTORE_SIGN_REQUEST" \
  -CA "$CA_CERT_FILE" -CAkey "$trust_store_private_key_file" \
  -out "$KEYSTORE_SIGNED_CERT" \
  -days "$VALIDITY_IN_DAYS" -CAcreateserial \
  -extfile openssl-san.cnf -extensions v3_req \
  -passin pass:"$CA_PASS"


echo "🪼 CA 인증서를 keystore에 추가"
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
  -storetype JKS \
  -import -file $CA_CERT_FILE \
  -storepass "$KEY_STORE_PASS" \
  -noprompt

rm $CA_CERT_FILE

echo "🪼 서명된 인증서를 keystore에 추가"
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -storetype JKS \
  -import -file $KEYSTORE_SIGNED_CERT \
  -storepass "$KEY_STORE_PASS" \
  -noprompt

# Ask user if intermediate files should be deleted
read -p "Delete intermediate files? [yn] " delete_intermediate_files
if [ "$delete_intermediate_files" == "y" ]; then
  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT
fi