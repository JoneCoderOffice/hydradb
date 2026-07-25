package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/plugin/dbresolver"
)

// User represents the users table schema.
type User struct {
	ID    uint   `gorm:"primaryKey;autoIncrement" json:"id"`
	Name  string `gorm:"type:varchar;not null" json:"name"`
	Email string `gorm:"type:varchar;not null" json:"email"`
}

func (User) TableName() string {
	return "user"
}

// DbDiagnostic maps the raw PG server status response.
type DbDiagnostic struct {
	IsReplica bool   `gorm:"column:is_replica"`
	Port      string `gorm:"column:port"`
	ServerIP  string `gorm:"column:server_ip"`
}

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func main() {
	// Load .env file if present
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on system environment variables")
	}

	// 1. Read environment variables
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbHost := os.Getenv("DB_HOST")
	if dbHost == "" {
		dbHost = "localhost"
	}

	dbPortWrite := os.Getenv("DB_PORT_WRITE")
	if dbPortWrite == "" {
		dbPortWrite = "5432"
	}

	dbPortRead := os.Getenv("DB_PORT_READ")
	if dbPortRead == "" {
		dbPortRead = "5433"
	}

	dbUser := os.Getenv("DB_USERNAME")
	if dbUser == "" {
		dbUser = "hydra_user"
	}

	dbPassword := os.Getenv("DB_PASSWORD")
	if dbPassword == "" {
		dbPassword = "hydra_pwd"
	}

	dbName := os.Getenv("DB_DATABASE")
	if dbName == "" {
		dbName = "hydra_db"
	}

	// 2. Build DSNs
	writeDSN := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPortWrite, dbUser, dbPassword, dbName)
	readDSN := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPortRead, dbUser, dbPassword, dbName)

	log.Printf("Connecting to Write Database: %s:%s", dbHost, dbPortWrite)
	log.Printf("Connecting to Read Database: %s:%s", dbHost, dbPortRead)

	// 3. Connect to Primary (Write) database
	db, err := gorm.Open(postgres.Open(writeDSN), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect to primary database: %v", err)
	}

	// 4. Configure GORM DBResolver to segregate reads to replicas (slaves)
	err = db.Use(dbresolver.Register(dbresolver.Config{
		Replicas: []gorm.Dialector{postgres.Open(readDSN)},
		Policy:   dbresolver.RandomPolicy{},
	}))
	if err != nil {
		log.Fatalf("Failed to register GORM dbresolver: %v", err)
	}

	// 5. Automatically migrate schema (creates the users table if not exists)
	if err := db.AutoMigrate(&User{}); err != nil {
		log.Fatalf("Failed to execute database migration: %v", err)
	}

	// 6. Set up Gin Engine
	r := gin.Default()
	r.Use(CORSMiddleware())

	// 7. Route Handlers

	// Homepage dashboard (plain HTML)
	r.GET("/", func(c *gin.Context) {
		c.File("./views/index.html")
	})

	// Static Topology Image
	r.GET("/hydradb.drawio.svg", func(c *gin.Context) {
		c.File("./assets/hydradb.drawio.svg")
	})

	// Swagger API Docs HTML
	r.GET("/docs", func(c *gin.Context) {
		c.File("./docs/swagger.html")
	})

	// Swagger API Docs JSON Schema
	r.GET("/docs/swagger.json", func(c *gin.Context) {
		c.File("./docs/swagger.json")
	})

	// Create User Endpoint (automatically routed to Master/Write)
	r.POST("/users", func(c *gin.Context) {
		var req struct {
			Name  string `json:"name" binding:"required"`
			Email string `json:"email" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		user := User{
			Name:  req.Name,
			Email: req.Email,
		}

		// GORM directs this write operation to the primary database source
		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user: " + err.Error()})
			return
		}

		c.JSON(http.StatusCreated, user)
	})

	// Find Users Endpoint with pagination (automatically routed to Replica/Read)
	r.GET("/users", func(c *gin.Context) {
		pageStr := c.DefaultQuery("page", "1")
		limitStr := c.DefaultQuery("limit", "10")

		page, err := strconv.Atoi(pageStr)
		if err != nil || page < 1 {
			page = 1
		}

		limit, err := strconv.Atoi(limitStr)
		if err != nil || limit < 1 {
			limit = 10
		}

		offset := (page - 1) * limit

		var users []User
		var total int64

		// Query total count of records (GORM routes this read operation to the replica)
		if err := db.Model(&User{}).Count(&total).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count users: " + err.Error()})
			return
		}

		// Query paginated users (GORM routes this read operation to the replica)
		if err := db.Order("id ASC").Offset(offset).Limit(limit).Find(&users).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query users: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"data":  users,
			"total": total,
			"page":  page,
			"limit": limit,
		})
	})

	// Diagnostic Endpoint (manually routes queries to verify server details)
	r.GET("/users/db-info", func(c *gin.Context) {
		query := "SELECT pg_is_in_recovery() AS is_replica, current_setting('port') as port, inet_server_addr() as server_ip"

		var masterInfo DbDiagnostic
		// Explicitly direct query to the Master database connection pool
		if err := db.Clauses(dbresolver.Write).Raw(query).Scan(&masterInfo).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed querying write database details: " + err.Error()})
			return
		}

		var replicaInfo DbDiagnostic
		// Explicitly direct query to the Replica database connection pool
		if err := db.Clauses(dbresolver.Read).Raw(query).Scan(&replicaInfo).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed querying read database details: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"writeConnection": gin.H{
				"description": "Routed automatically to Master (read-write primary)",
				"is_replica":  masterInfo.IsReplica,
				"port":        masterInfo.Port,
				"server_ip":   masterInfo.ServerIP,
			},
			"readConnection": gin.H{
				"description": "Routed automatically to Slave (read-only replica)",
				"is_replica":  replicaInfo.IsReplica,
				"port":        replicaInfo.Port,
				"server_ip":   replicaInfo.ServerIP,
			},
		})
	})

	// 8. Start Service
	log.Printf("Starting Go Gin API Server on port %s...", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Server startup failed: %v", err)
	}
}
