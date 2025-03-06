package main

import (
	"database/sql"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"os"

	_ "github.com/lib/pq"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/template/html/v2"

	"github.com/gabriel-vasile/mimetype"
	"gopkg.in/gographics/imagick.v3/imagick"
)

func main() {
	imagick.Initialize()
	defer imagick.Terminate()
	// mw := imagick.MagickWand{...}
	// defer mw.Destroy()

	// Connect to database
	os.Unsetenv("PGHOSTADDR") // unset deprecated env setting
	connStr := ""             // fallback to env variables ex: PGHOST, PGUSER, PGPASS
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal(err)
	}
	engine := html.New("./views", ".html")
	app := fiber.New(fiber.Config{
		Views: engine,
	})

	app.Get("/", func(c *fiber.Ctx) error {
		return indexHandler(c, db)
	})

	app.Post("/", func(c *fiber.Ctx) error {
		return postHandler(c, db)
	})

	app.Put("/update", func(c *fiber.Ctx) error {
		return putHandler(c, db)
	})

	app.Delete("/delete", func(c *fiber.Ctx) error {
		return deleteHandler(c, db)
	})

	addr := os.Getenv("ADDR") // defaults to all interfaces, override with specific addr
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	app.Static("/", "./public")
	log.Fatalln(app.Listen(fmt.Sprintf("%s:%v", addr, port)))
}

type todo struct {
	Item            string
	MimeType        string
	BackgroundImage string
}

func indexHandler(c *fiber.Ctx, db *sql.DB) error {
	var todos []todo
	rows, err := db.Query("SELECT item, mimetype, image FROM todos")
	defer rows.Close()
	if err != nil {
		log.Fatalln(err)
		c.JSON("An error occured")
	}
	for rows.Next() {
		t := todo{}
		err := rows.Scan(&t.Item, &t.MimeType, &t.BackgroundImage)
		fmt.Println(err)
		todos = append(todos, t)
	}
	return c.Render("index", fiber.Map{
		"Todos": todos,
	})
}

func postHandler(c *fiber.Ctx, db *sql.DB) error {
	newTodo := todo{}

	newTodo.Item = c.FormValue("Item")

	fh, err := c.FormFile("BackgroundImage")
	if err != nil {
		log.Printf("Error parsing form occured: %v", err)
		return c.SendString(err.Error())
	}

	file, err := fh.Open()
	if err != nil {
		log.Printf("Error parsing form occured: %v", err)
		return c.SendString(err.Error())
	}

	b, err := io.ReadAll(file)
	if err != nil {
		log.Printf("Error reading form file: %v", err)
		return c.SendString(err.Error())
	}
	newTodo.MimeType = mimetype.Detect(b).String()
	newTodo.BackgroundImage = base64.StdEncoding.EncodeToString(b)

	if newTodo.Item != "" {
		_, err := db.Exec("INSERT into todos VALUES ($1, $2, $3)", newTodo.Item, newTodo.MimeType, newTodo.BackgroundImage)
		if err != nil {
			log.Fatalf("An error occured while executing query: %v", err)
		}
	}

	return c.Redirect("/")
}

func putHandler(c *fiber.Ctx, db *sql.DB) error {
	olditem := c.Query("olditem")
	newitem := c.Query("newitem")
	db.Exec("UPDATE todos SET item=$1 WHERE item=$2", newitem, olditem)
	return c.Redirect("/")
}

func deleteHandler(c *fiber.Ctx, db *sql.DB) error {
	todoToDelete := c.Query("item")
	db.Exec("DELETE from todos WHERE item=$1", todoToDelete)
	return c.SendString("deleted")
}
