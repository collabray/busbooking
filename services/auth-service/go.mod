module github.com/omnibus-ea/auth-service

go 1.22

require (
	github.com/golang-jwt/jwt/v5 v5.2.0
	github.com/go-webauthn/webauthn v0.10.2
	github.com/gin-gonic/gin v1.9.1
	github.com/lib/pq v1.10.9
	github.com/redis/go-redis/v9 v9.5.1
	github.com/aws/aws-sdk-go-v2 v1.26.0
	github.com/aws/aws-sdk-go-v2/service/kms v1.30.0
	github.com/aws/aws-sdk-go-v2/config v1.27.0
	golang.org/x/crypto v0.22.0
	google.golang.org/grpc v1.63.0
	google.golang.org/protobuf v1.33.0
	github.com/sirupsen/logrus v1.9.3
	github.com/prometheus/client_golang v1.19.0
	github.com/spf13/viper v1.18.2
)
