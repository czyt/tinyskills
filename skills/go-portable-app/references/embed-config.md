# Go Embed 配置详解

> Go 1.16+ 内置功能，将文件嵌入到二进制文件

**官方文档**: https://pkg.go.dev/embed

---

## 核心概念

Package embed 提供访问运行时 Go 程序中嵌入文件的能力。

Go 源文件导入 "embed" 可以使用 `//go:embed` 指令，在编译时从包目录读取文件内容，初始化 string、[]byte 或 FS 类型变量。

---

## 基础用法

### 嵌入单个文件到 string

```go
import _ "embed"

//go:embed hello.txt
var s string
print(s)
```

### 嵌入单个文件到 []byte

```go
import _ "embed"

//go:embed hello.txt
var b []byte
print(string(b))
```

### 嵌入文件到文件系统

```go
import "embed"

//go:embed hello.txt
var f embed.FS
data, _ := f.ReadFile("hello.txt")
print(string(data))
```

---

## 指令规则

### 基本规则

1. `//go:embed` 指令必须在变量声明上方
2. 指令和声明之间只允许空行和 `//` 注释
3. 变量类型必须是 string、[]byte 或 FS（或其别名）
4. 只能在包级别使用，不能用于局部变量

### 多模式支持

```go
package server

import "embed"

//go:embed image/* template/*
//go:embed html/index.html
var content embed.FS
```

- 掯令接受多个空格分隔的模式
- 模式相对于包含源文件的包目录
- 路径分隔符为 `/`（即使在 Windows）
- 模式不能包含 `.` 或 `..` 或空路径元素
- 模式不能以 `/` 开头或结尾

---

## 目录嵌入规则

### 默认规则

如果模式命名目录，则嵌入该目录下的所有文件（递归），但：
- 以 `.` 开头的文件被排除
- 以 `_` 开头的文件被排除

```go
//go:embed image
var content embed.FS
// 不包含 image/.tempfile 和 image/dir/.tempfile
```

### 使用 `all:` 前缀

```go
//go:embed all:image
var content embed.FS
// 包含 image/.tempfile 和 image/dir/.tempfile
```

---

## FS 类型

### 类型定义

```go
type FS struct {
    // contains filtered or unexported fields
}
```

FS 是只读文件集合，通常通过 `//go:embed` 初始化。

### 特性

- 实现 fs.FS 接口
- 可与 net/http、text/template、html/template 等包配合使用
- 空 FS（无指令）是空文件系统
- 可安全并发使用

### 方法

```go
// Open 打开命名文件
func (f FS) Open(name string) (fs.File, error)

// ReadDir 读取整个目录
func (f FS) ReadDir(name string) ([]fs.DirEntry, error)

// ReadFile 读取文件内容
func (f FS) ReadFile(name string) ([]byte, error)
```

---

## HTTP 服务器配置

### 基础配置

```go
package main

import (
    "embed"
    "io/fs"
    "net/http"
    
    "github.com/labstack/echo/v5"
)

//go:embed web/dist
var webFS embed.FS

func main() {
    e := echo.New()
    
    // API 路由（优先）
    api := e.Group("/api/v1")
    api.GET("/users", getUsersHandler)
    
    // 前端静态文件（兜底）
    distFS, err := fs.Sub(webFS, "web/dist")
    if err != nil {
        panic(err)
    }
    e.GET("/*", echo.WrapHandler(http.FileServer(http.FS(distFS))))
    
    e.Start(":8080")
}
```

### SPA 路由处理

```go
func setupSPA(e *echo.Echo, webFS embed.FS) {
    distFS, _ := fs.Sub(webFS, "web/dist")
    fileServer := http.FileServer(http.FS(distFS))
    
    e.GET("/*", func(c echo.Context) error {
        path := c.Param("*")
        
        // 尝试打开文件
        f, err := distFS.Open(path)
        if err != nil {
            // 文件不存在，返回 index.html（SPA 路由）
            f, err = distFS.Open("index.html")
            if err != nil {
                return echo.NewHTTPError(http.StatusNotFound)
            }
        }
        f.Close()
        
        return echo.WrapHandler(fileServer)(c)
    })
}
```

### 使用 http.FS

```go
http.Handle("/static/", 
    http.StripPrefix("/static/", 
        http.FileServer(http.FS(content))))

template.ParseFS(content, "*.tmpl")
```

---

## 构建标签

### 条件嵌入

```go
// +build embed

package main

import "embed"

//go:embed web/dist
var webFS embed.FS
```

### 构建

```bash
# 启用 embed
go build -tags embed -o bin/app ./cmd/app

# 不嵌入（开发时）
go build -o bin/app ./cmd/app
```

---

## 配置文件嵌入

### YAML 配置

```go
package conf

import "embed"

//go:embed config.yaml
var defaultConfig string

func LoadConfig() (*Config, error) {
    // 优先使用外部配置文件
    if data, err := os.ReadFile("config.yaml"); err == nil {
        return parseConfig(data)
    }
    
    // 使用嵌入的默认配置
    return parseConfig([]byte(defaultConfig))
}
```

### 多环境配置

```go
//go:embed configs/dev.yaml
var devConfig string

//go:embed configs/prod.yaml
var prodConfig string

func LoadConfig(env string) (*Config, error) {
    var configData string
    
    switch env {
    case "dev":
        configData = devConfig
    case "prod":
        configData = prodConfig
    default:
        if data, err := os.ReadFile("config.yaml"); err == nil {
            return parseConfig(data)
        }
        configData = devConfig
    }
    
    return parseConfig([]byte(configData))
}
```

---

## 模板嵌入

```go
package main

import (
    "embed"
    "html/template"
)

//go:embed templates/*.html
var templateFS embed.FS

var templates *template.Template

func init() {
    templates = template.Must(template.ParseFS(templateFS, "templates/*.html"))
}

func renderTemplate(name string, data interface{}) (string, error) {
    var buf bytes.Buffer
    err := templates.ExecuteTemplate(&buf, name, data)
    return buf.String(), err
}
```

---

## 开发与生产配置

### 开发环境（不嵌入）

```go
package main

import (
    "embed"
    "io/fs"
    "net/http"
    "os"
)

var webFS http.FileSystem

func init() {
    // 生产：使用 embed
    if os.Getenv("APP_ENV") == "prod" {
        //go:embed web/dist
        var embedFS embed.FS
        distFS, _ := fs.Sub(embedFS, "web/dist")
        webFS = http.FS(distFS)
    } else {
        // 开发：读取本地文件
        webFS = http.Dir("web/dist")
    }
}
```

### 条件编译

```go
// embed.go
// +build embed

package main

import "embed"

//go:embed web/dist
var WebFS embed.FS

// noembed.go
// +build !embed

package main

import "embed"

var WebFS embed.FS // 空，开发时使用 os.ReadFile
```

---

## 常见问题

### 文件不存在

```
embed: pattern matches no files
```

**解决**：确保文件/目录存在，且相对路径正确

### 文件太大

```
embed: file too large
```

**解决**：压缩文件或减少嵌入内容

### 路径错误

```
fs.Sub: invalid path
```

**解决**：检查 fs.Sub 的路径参数

### 模式无效

```
embed: pattern contains special characters
```

**解决**：模式不能匹配包含特殊字符的文件名（`" * < > ? ` ' | / \ :`）

---

## 推荐限制

| 资源类型 | 推荐大小限制 |
|---------|-------------|
| 配置文件 | < 10KB |
| 模板文件 | < 100KB |
| 前端资源 | < 50MB |
| 总嵌入大小 | < 100MB |

---

## 完整示例

```go
package main

import (
    "embed"
    "io/fs"
    "net/http"
    "os"
    
    "github.com/labstack/echo/v5"
    "github.com/labstack/echo/v5/middleware"
)

//go:embed web/dist
var webFS embed.FS

//go:embed config.yaml
var defaultConfig string

func main() {
    e := echo.New()
    
    // 中间件
    e.Use(middleware.Logger())
    e.Use(middleware.Recover())
    
    // API
    api := e.Group("/api/v1")
    api.GET("/health", healthHandler)
    api.GET("/users", getUsersHandler)
    
    // 前端
    setupFrontend(e)
    
    // 启动
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    e.Start(":" + port)
}

func setupFrontend(e *echo.Echo) {
    distFS, _ := fs.Sub(webFS, "web/dist")
    fileServer := http.FileServer(http.FS(distFS))
    
    e.GET("/*", func(c echo.Context) error {
        path := c.Param("*")
        
        // API 路由已处理，这里是前端
        if path == "" || path == "index.html" {
            return echo.WrapHandler(fileServer)(c)
        }
        
        // 检查文件
        f, err := distFS.Open(path)
        if err != nil {
            // 返回 index.html（SPA 路由）
            c.Request().URL.Path = "/"
            return echo.WrapHandler(fileServer)(c)
        }
        f.Close()
        
        return echo.WrapHandler(fileServer)(c)
    })
}
```

---

## 构建流程

```bash
# 1. 前端构建
cd web && npm run build

# 2. 检查前端产物
ls -la web/dist/

# 3. 后端构建（嵌入）
go build -tags embed -ldflags="-s -w" -o bin/app ./cmd/app

# 4. 验证嵌入
ls -lh bin/app  # 文件大小应增加

# 5. 运行
./bin/app

# 6. 测试
curl http://localhost:8080/        # 前端
curl http://localhost:8080/api/v1/health  # API
```

---

## 参考资料

- [Go embed Package](https://pkg.go.dev/embed)
- [Go 1.16 Release Notes](https://go.dev/doc/go1.16#embed)