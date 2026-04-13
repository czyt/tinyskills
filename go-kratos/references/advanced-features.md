# Advanced Features

Guide for MCP server integration and other advanced Kratos features.

## When to Use

- Integrating Kratos with AI agents via MCP
- Building tool-enabled microservices

---

## MCP Server Integration

Kratos v2+ supports MCP (Model Context Protocol) server capability, allowing Kratos services to act as MCP servers for AI agents.

### What is MCP?

MCP is a protocol for AI agents to discover and call tools. Kratos services can expose their functionality as MCP tools, enabling:

- AI agents to call Kratos APIs directly
- Tool discovery and schema validation
- Structured input/output handling

### Basic Setup

```go
import (
    "context"
    "fmt"
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/log"
    tm "github.com/go-kratos/kratos/contrib/transport/mcp/v2"
    mcp "github.com/mark3labs/mcp-go/mcp"
)
```

### MCP Server Creation

```go
func main() {
    // Create MCP server
    srv := tm.NewServer(
        "kratos-mcp",     // Server name
        "v1.0.0",         // Version
        tm.Address(":8000"),
    )
    
    // Define tool
    tool := mcp.NewTool("hello_world",
        mcp.WithDescription("Say hello to someone"),
        mcp.WithString("name",
            mcp.Required(),
            mcp.Description("Name of the person to greet"),
        ),
    )
    
    // Add tool handler
    srv.AddTool(tool, helloHandler)
    
    // Create Kratos app
    app := kratos.New(
        kratos.Name("kratos-mcp"),
        kratos.Server(srv),
    )
    
    if err := app.Run(); err != nil {
        panic(err)
    }
}
```

### Tool Handler

```go
func helloHandler(ctx context.Context, request mcp.CallToolRequest) (*mcp.CallToolResult, error) {
    // Extract arguments
    name, ok := request.Params.Arguments["name"].(string)
    if !ok {
        return nil, errors.New("name must be a string")
    }
    
    // Return result
    return mcp.NewToolResultText(fmt.Sprintf("Hello, %s!", name)), nil
}
```

### Multiple Tools

```go
func main() {
    srv := tm.NewServer("my-mcp-server", "v1.0.0", tm.Address(":8000"))
    
    // Tool 1: User lookup
    userTool := mcp.NewTool("get_user",
        mcp.WithDescription("Get user by ID"),
        mcp.WithString("user_id",
            mcp.Required(),
            mcp.Description("User identifier"),
        ),
    )
    srv.AddTool(userTool, getUserHandler)
    
    // Tool 2: Order creation
    orderTool := mcp.NewTool("create_order",
        mcp.WithDescription("Create a new order"),
        mcp.WithString("user_id", mcp.Required()),
        mcp.WithString("product_id", mcp.Required()),
        mcp.WithNumber("quantity", mcp.Required()),
    )
    srv.AddTool(orderTool, createOrderHandler)
    
    // Run
    app := kratos.New(kratos.Name("my-mcp"), kratos.Server(srv))
    app.Run()
}

func getUserHandler(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
    userID := req.Params.Arguments["user_id"].(string)
    // Call biz layer
    user, err := userUC.GetUser(ctx, userID)
    if err != nil {
        return mcp.NewToolResultError(err.Error()), nil
    }
    return mcp.NewToolResultText(fmt.Sprintf("User: %s, Email: %s", user.Name, user.Email)), nil
}

func createOrderHandler(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
    userID := req.Params.Arguments["user_id"].(string)
    productID := req.Params.Arguments["product_id"].(string)
    quantity := req.Params.Arguments["quantity"].(float64)
    
    // Call biz layer
    order, err := orderUC.CreateOrder(ctx, userID, productID, int(quantity))
    if err != nil {
        return mcp.NewToolResultError(err.Error()), nil
    }
    
    return mcp.NewToolResultText(fmt.Sprintf("Order created: %s", order.ID)), nil
}
```

### MCP with Middleware

Add custom middleware for logging, auth, etc.:

```go
func MCPLoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        log.Infof("MCP request: %s %s", r.Method, r.URL.Path)
        next.ServeHTTP(w, r)
    })
}

srv := tm.NewServer(
    "kratos-mcp",
    "v1.0.0",
    tm.Address(":8000"),
    tm.Middleware(MCPLoggingMiddleware),
)
```

### Health Check

Add health check endpoint:

```go
func HealthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path == "/health/ready" {
            w.WriteHeader(http.StatusOK)
            return
        }
        next.ServeHTTP(w, r)
    })
}

srv := tm.NewServer(
    "kratos-mcp",
    "v1.0.0",
    tm.Address(":8000"),
    tm.Middleware(HealthMiddleware),
)
```

---

## MCP Tool Schema Types

### String Parameter

```go
mcp.WithString("name",
    mcp.Required(),
    mcp.Description("Description of parameter"),
    mcp.Pattern("^[a-z]+$"),  // Optional: regex pattern
)
```

### Number Parameter

```go
mcp.WithNumber("quantity",
    mcp.Required(),
    mcp.Description("Number of items"),
    mcp.MinNumber(1),      // Optional: minimum
    mcp.MaxNumber(100),    // Optional: maximum
)
```

### Boolean Parameter

```go
mcp.WithBoolean("enabled",
    mcp.Description("Enable feature"),
)
```

### Object Parameter

```go
mcp.WithObject("config",
    mcp.Description("Configuration object"),
    mcp.Properties(map[string]mcp.Property{
        "timeout": mcp.NewNumberProperty(30),
        "retries": mcp.NewNumberProperty(3),
    }),
)
```

---

## Result Types

### Text Result

```go
mcp.NewToolResultText("Operation completed successfully")
```

### Error Result

```go
mcp.NewToolResultError("Invalid input: user_id required")
```

### JSON Result

```go
mcp.NewToolResultJSON(map[string]interface{}{
    "user_id": "123",
    "name": "John",
    "email": "john@example.com",
})
```

---

## MCP Client Integration

AI agents discover and call tools via MCP protocol:

1. **Discovery**: Agent calls `list_tools` to get available tools
2. **Schema**: Agent receives tool definitions with parameters
3. **Invocation**: Agent calls `call_tool` with arguments
4. **Response**: Server returns structured result

### Integration Example

Claude Code MCP client configuration:

```json
{
    "mcpServers": {
        "kratos-mcp": {
            "url": "http://localhost:8000/mcp"
        }
    }
}
```

---

## Future Extensions

This reference file can be extended with:

- Plugin system integration
- Custom transport protocols
- Service mesh patterns
- GraphQL gateway
- Event-driven architecture

Check official Kratos documentation for updates: https://go-kratos.dev