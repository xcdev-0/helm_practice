좋은 질문! 핵심만 딱 정리해줄게.

## SAN을 어디에 넣어야 해?

* **CA 만들 때:** ❌ 필요 없음 (CA는 서버가 아니라 서명자)
* **서버(브로커) 인증서 만들 때:** ✅ 필요

  * **최소 한 곳**: **CSR 생성** *또는* **서명 단계** 중 **한 곳**에만 확실히 넣어도 됨
  * **권장(안전빵)**: **CSR 생성**에도 넣고, **서명 단계**에서도 한 번 더 지정 → 어떤 도구/버전에서도 SAN이 최종 인증서에 확실히 들어감

---

## 왜 두 군데(또는 한 군데)인가?

* `keytool`로 만든 **CSR**에 SAN을 넣어도, **OpenSSL 서명** 과정에서 SAN을 **복사하지 않는** 설정이면 빠질 수 있음.
* 반대로 CSR에 SAN이 없어도, **서명 단계에서 SAN을 지정**하면 최종 인증서에 들어감.
* 그래서 **CSR에도 넣고, 서명 때도 확실히 지정**하는 게 안정적.

---

## 네 스크립트에 적용하는 딱 맞는 방법

### 1) SAN 목록 변수로 정의

```bash
SAN="dns:kafka.kafka-headless.default.svc,\
dns:kafka-0.kafka-headless.default.svc.cluster.local,\
dns:kafka-1.kafka-headless.default.svc.cluster.local,\
dns:kafka-2.kafka-headless.default.svc.cluster.local"
```

> 외부 노출 미정이면 지금은 내부 주소만. 나중에 외부 도메인 정해지면 **새 인증서** 만들어서 교체(Secret 업데이트 + 롤링 재시작).

### 2) keystore 생성 시(선택, 편의)

> 임시 self-signed cert에도 SAN을 넣어 둠(필수는 아님)

```bash
keytool -keystore "$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME" \
  -alias localhost -validity "$VALIDITY_IN_DAYS" -keyalg RSA -genkey \
  -dname "CN=${CN}, OU=Dev, O=pknu, L=Busan, ST=Busan, C=KR" \
  -ext "SAN=${SAN}" \
  -storepass "$KEY_STORE_PASS"
```

### 3) CSR 생성 시(권장: 반드시)

```bash
keytool -keystore "$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME" \
  -alias localhost -certreq -file "$KEYSTORE_SIGN_REQUEST" \
  -ext "SAN=${SAN}" \
  -storepass "$KEY_STORE_PASS"
```

### 4) 서명 시 SAN 보장(둘 중 하나 택1, **B가 가장 확실**)

**A. CSR의 확장을 복사(환경에 따라 동작 안 할 수 있음)**

```bash
openssl x509 -req \
  -in "$KEYSTORE_SIGN_REQUEST" \
  -CA "$CA_CERT_FILE" -CAkey "$trust_store_private_key_file" \
  -out "$KEYSTORE_SIGNED_CERT" \
  -days "$VALIDITY_IN_DAYS" -CAcreateserial \
  -copy_extensions copy \
  -passin pass:"$CA_PASS"
```

**B. SAN을 extfile로 다시 명시(항상 확실, 추천)**

```bash
cat > openssl-san.cnf <<'EOF'
[v3_req]
subjectAltName = DNS:kafka.kafka-headless.default.svc,DNS:kafka-0.kafka-headless.default.svc.cluster.local,DNS:kafka-1.kafka-headless.default.svc.cluster.local,DNS:kafka-2.kafka-headless.default.svc.cluster.local
EOF

openssl x509 -req \
  -in "$KEYSTORE_SIGN_REQUEST" \
  -CA "$CA_CERT_FILE" -CAkey "$trust_store_private_key_file" \
  -out "$KEYSTORE_SIGNED_CERT" \
  -days "$VALIDITY_IN_DAYS" -CAcreateserial \
  -extfile openssl-san.cnf -extensions v3_req \
  -passin pass:"$CA_PASS"
```

> 이렇게 하면 최종 **서명된 인증서**에 SAN이 반드시 들어감.

---

## 마지막 체크포인트

```bash
keytool -list -v -keystore "$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME" -storepass "$KEY_STORE_PASS"
# → Entry type: PrivateKeyEntry
# → Certificate chain length: 2 (서버 cert + CA)
# → Extensions에 SubjectAlternativeName가 우리가 넣은 SAN 목록과 일치해야 함
```

---

## 요약

* **CA 단계엔 SAN 불필요.**
* **서버 인증서**에만 SAN 필요.
* **CSR 생성 시 `-ext SAN=...`** 넣고, **서명 시에도 SAN 지정**(또는 `-copy_extensions copy`) → 이 조합이 베스트.
* 외부 도메인은 나중에 결정되면 **새 인증서 발급/교체**하면 됨(Secret 교체 후 롤링 재시작).

원하면 네 스크립트에 위 옵션들 바로 붙여서 **최종 동작하는 버전** 만들어줄게. SAN 목록만 확정해줘!
