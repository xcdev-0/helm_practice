# 네임스페이스 변수
NS=mysql

# 0) MySQL Pod 준비 상태 확인
kubectl wait -n $NS --for=condition=ready pod -l app.kubernetes.io/name=mysql --timeout=180s

# 1) 루트 비밀번호 가져오기 (Bitnami 기본 시크릿)
export MYSQL_ROOT_PASSWORD=$(
  kubectl -n $NS get secret my-mysql \
    -o jsonpath='{.data.mysql-root-password}' | base64 -d
)
[ -n "$MYSQL_ROOT_PASSWORD" ] && echo "✅ secret OK" || echo "❌ secret not found"

# 2) 임시 클라이언트 파드로 셸 진입
kubectl run my-mysql-client -n mysql --rm -it --restart=Never \
  --image=docker.io/bitnami/mysql:9.3.0-debian-12-r2 -- bash

# 3) 셸 안에서 접속 (비번 프롬프트 뜨면 방금 복사한 비번 붙여넣기)
mysql -h my-mysql.mysql.svc.cluster.local -uroot -pthisismysqlrootpassword