module hydradb/goapp

go 1.22

require (
	github.com/gin-gonic/gin v1.10.0
	github.com/joho/godotenv v1.5.1
	gorm.io/driver/postgres v1.5.9
	gorm.io/gorm v1.25.11
	gorm.io/plugin/dbresolver v1.5.2
)

replace github.com/rogpeppe/go-internal => github.com/rogpeppe/go-internal v1.14.0

