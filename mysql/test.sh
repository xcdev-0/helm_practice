apiVersion: v1
kind: Pod
metadata:
  name: image-pull-check
  namespace: app
spec:
  imagePullSecrets:
    - name: regcred
  containers:
    - name: check
      image: dockeracckai/my-chat-server:1.0.0
      command: ["sh", "-c", "echo OK && sleep 3600"]
  restartPolicy: Never

