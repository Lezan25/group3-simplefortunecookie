apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-__ENV__-canary
  labels:
    app: frontend
    env: __ENV__
    track: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
      env: __ENV__
      track: canary
  template:
    metadata:
      labels:
        app: frontend
        env: __ENV__
        track: canary
    spec:
      containers:
        - name: frontend
          image: aljazkni/simplefortunecookie-frontend:__IMAGE_TAG__
          ports:
            - containerPort: 8080
          env:
            - name: BACKEND_DNS
              value: "backend-__ENV__"
            - name: BACKEND_PORT
              value: "9000"
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10