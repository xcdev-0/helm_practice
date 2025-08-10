## **1. Truststore (JKS)**

> 목적: **“누구를 믿을지”** 정의하는 저장소
> 내용: **CA 공개 인증서만** (개인키 없음)

### **Truststore에 저장해야 할 것**

* **CA 공개 인증서** (`ca.crt` / `$CA_CERT_FILE`)

  * Kafka 클라이언트/브로커가 통신 시, 상대방 인증서가 이 CA로 서명됐는지 검증하는 데 사용.

### **생성과정**

1. **CA 개인키 + CA 인증서 생성**

   ```bash
   openssl req -new -x509 \
     -keyout ca-key \
     -out ca.crt \
     -days 3650
   ```

   * **개인키**: `ca-key` (비밀 / Truststore에 넣지 않음)
   * **인증서**: `ca.crt` (공개 / Truststore에 넣음)

2. **CA 인증서를 Truststore에 import**

   ```bash
   keytool -keystore kafka.truststore.jks \
     -alias CARoot \
     -import -file ca.crt
   ```

   * 비밀번호(truststore storepass) 입력 → Truststore 생성 완료.

---

## **2. Keystore (JKS)**

> 목적: **“우리가 우리임을 증명”** + 해당 인증서의 비밀키 보관
> 내용: **서버(브로커) 개인키 + 서버 인증서(서명됨) + CA 체인**

### **Keystore에 저장해야 할 것**

* **서버 개인키** (keystore 생성 시 내부에 자동 저장)
* **서명된 서버 인증서** (CSR을 CA로 서명한 결과)
* **CA 공개 인증서** (체인 완성을 위해)

### **생성과정**

1. **Keystore + 서버 개인키 생성**

   ```bash
   keytool -keystore kafka.keystore.jks \
     -alias broker1 \
     -validity 3650 \
     -genkey -keyalg RSA \
     -ext SAN=dns:broker1,dns:broker1.kafka.svc.cluster.local
   ```

   * CN(Common Name) → 일반적으로 브로커 FQDN.
   * SAN은 hostname verification 통과를 위해 반드시 포함.

2. **CSR 생성**

   ```bash
   keytool -keystore kafka.keystore.jks \
     -alias broker1 \
     -certreq -file broker1.csr
   ```

3. **CA로 CSR 서명**

   ```bash
   openssl x509 -req \
     -CA ca.crt -CAkey ca-key \
     -in broker1.csr \
     -out broker1-signed.crt \
     -days 3650 -CAcreateserial
   ```

   * 이때 **CA 개인키 비밀번호** 입력.

4. **Keystore에 CA 인증서(CARoot) import**

   ```bash
   keytool -keystore kafka.keystore.jks \
     -alias CARoot \
     -import -file ca.crt
   ```

5. **Keystore에 서명된 서버 인증서 import**

   ```bash
   keytool -keystore kafka.keystore.jks \
     -alias broker1 \
     -import -file broker1-signed.crt
   ```

6. **검증**

   ```bash
   keytool -list -v -keystore kafka.keystore.jks
   ```

   * `PrivateKeyEntry` 1개, Certificate chain length=2 (서버 cert + CA cert) 나와야 정상.

---

## **정리 표**

| 저장소            | 목적              | 저장 내용                      | 생성 핵심 단계                                                                            |
| -------------- | --------------- | -------------------------- | ----------------------------------------------------------------------------------- |
| **Truststore** | 신뢰할 CA 저장소      | CA 공개 인증서만                 | `openssl req` → `keytool -import`                                                   |
| **Keystore**   | 서버 인증서 + 개인키 보관 | 서버 개인키, 서명된 서버 인증서, CA 인증서 | `keytool -genkey` → `CSR` → `CA 서명` → `keytool -import CA` → `keytool -import cert` |

---

💡 **Kafka 배포 시**

* 브로커: keystore.jks, truststore.jks 둘 다 필요
* 클라이언트: truststore.jks만 필수, mTLS 사용 시 keystore.jks도 필요


