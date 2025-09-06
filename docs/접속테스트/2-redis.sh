# 0) 네임스페이스
NS=redis

# 1) 루트 비밀번호 확인 (Bitnami 기본 시크릿)
REDIS_PASSWORD=$(
  kubectl -n $NS get secret my-redis \
    -o jsonpath='{.data.redis-password}' | base64 -d
)
echo "$REDIS_PASSWORD" | pbcopy 2>/dev/null || echo "비번: $REDIS_PASSWORD"

# 2) 임시 클라이언트 파드 실행 (redis-cli 포함)
kubectl run redis-client -n $NS --rm -it --restart=Never \
  --image=redis:7-alpine -- sh

# 마스터로 접속 (비번 프롬프트에 방금 복사한 비번 붙여넣기)
redis-cli -h my-redis-master -a thisisredispassword
# 접속되면 테스트
PING
SET smoke ok
GET smoke
INFO replication
# 끝낼 때
QUIT

