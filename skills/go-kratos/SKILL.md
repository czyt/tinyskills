---
name: go-kratos
description: Go-Kratos microservice framework development assistant. TRIGGER when: user mentions kratos, protobuf API definition, Go microservice layered architecture, HTTP/gRPC service configuration, middleware development, JWT/Casbin auth, buf generation tool, proto validate, WebSocket/file upload. Trigger even without explicit "kratos" mention when these topics arise, or when project contains buf.yaml, internal/service, internal/biz directories.
---

# Go-Kratos Skill

Assist developers working with go-kratos microservice framework.

## Quick Decision Tree

What are you doing?

| Task | Reference |
|------|-----------|
| Defining new API / proto file | [proto-api-design.md](references/proto-api-design.md) |
| Developing Service/Biz/Data layers | [architecture.md](references/architecture.md) |
| Configuring project / startup params | [configuration.md](references/configuration.md) |
| Customizing HTTP response / WebSocket / files | [http-customization.md](references/http-customization.md) |
| Adding auth / JWT / Casbin | [security-auth.md](references/security-auth.md) |
| Writing middleware / log handling | [middleware-logging.md](references/middleware-logging.md) |
| Encountering issues / errors | [troubleshooting.md](references/troubleshooting.md) |
| MCP / advanced extensions | [advanced-features.md](references/advanced-features.md) |

---

## Quick Code Patterns

Essential snippets for common tasks—use without reading full references.

### 1. Proto Definition Template (with buf.validate)

```protobuf
syntax = "proto3";
package myservice.v1;

import "buf/validate/validate.proto";
import "google/api/annotations.proto";

option go_package = "github.com/myorg/myproject/api/myservice/v1;v1";

service MyService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse) {
    option (google.api.http) = {get: "/v1/users/{user_id}"};
  }
}

message GetUserRequest {
  string user_id = 1 [
    (buf.validate.field).string.min_len = 1,
    (buf.validate.field).string.max_len = 64
  ];
}

message GetUserResponse {
  string name = 1;
  string email = 2;
}
```

### 2. Service Layer Skeleton

```go
package service

import (
    "buf.build/go/protovalidate"
    "context"
    "github.com/go-kratos/kratos/v2/log"
    v1 "github.com/myorg/myproject/api/myservice/v1"
    "github.com/myorg/myproject/internal/biz"
)

type MyService struct {
    v1.UnimplementedMyServiceServer
    log  *log.Helper
    uc   *biz.MyUseCase
    validator protovalidate.Validator
}

func NewMyService(uc *biz.MyUseCase, logger log.Logger, validator protovalidate.Validator) *MyService {
    return &MyService{
        uc: uc,
        validator: validator,
        log: log.NewHelper(log.With(logger, "module", "service/myService")),
    }
}

func (s *MyService) GetUser(ctx context.Context, req *v1.GetUserRequest) (*v1.GetUserResponse, error) {
    if err := s.validator.Validate(req); err != nil {
        return nil, err
    }
    // Call biz layer and convert result
    user, err := s.uc.GetUser(ctx, req.UserId)
    if err != nil {
        return nil, err
    }
    // Convert biz.User to proto response
    return &v1.GetUserResponse{
        Name:  user.Name,
        Email: user.Email,
    }, nil
}
```

### 3. fx Module Registration Pattern

```go
package service

import "go.uber.org/fx"

var Module = fx.Options(
    fx.Provide(NewMyService),
)
```

Similarly for `biz.Module`, `data.Module`, `server.Module`:
```go
// cmd/server/main.go
app := fx.New(
    server.Module,
    data.Module,
    biz.Module,
    service.Module,
    appModule,
)
```

### 4. ResponseEncoder Example

```go
func CustomResponseEncoder() http.ServerOption {
    return http.ResponseEncoder(func(w http.ResponseWriter, r *http.Request, i interface{}) error {
        reply := &v1.BaseResponse{Code: 0}
        if m, ok := i.(proto.Message); ok {
            payload, err := anypb.New(m)
            if err != nil {
                return err
            }
            reply.Data = payload
        }
        codec := encoding.GetCodec("json")
        data, err := codec.Marshal(reply)
        if err != nil {
            return err
        }
        w.Header().Set("Content-Type", "application/json")
        if _, err := w.Write(data); err != nil {
            return err
        }
        return nil
    })
}
```

### 5. JWT Payload from Context

```go
func getPayloadFromCtx(ctx context.Context, partName string) (string, error) {
    if claims, ok := jwt.FromContext(ctx); ok {
        if m, ok := claims.(jwtV4.MapClaims); ok {
            if v, ok := m[partName].(string); ok {
                return v, nil
            }
        }
    }
    return "", errors.New("invalid Jwt")
}
```

### 6. Middleware Skeleton

```go
func MyMiddleware() middleware.Middleware {
    return func(handler middleware.Handler) middleware.Handler {
        return func(ctx context.Context, req interface{}) (reply interface{}, err error) {
            // Pre-processing
            if tr, ok := transport.FromServerContext(ctx); ok {
                // Access headers, operation, etc.
                userAgent := tr.RequestHeader().Get("User-Agent")
            }
            
            // Call next handler
            reply, err = handler(ctx, req)
            
            // Post-processing
            return reply, err
        }
    }
}
```

---

## Is This a Kratos Project?

Check for these signals:
- `buf.yaml` or `buf.gen.yaml` exists
- `internal/service/` directory exists
- `internal/biz/` directory exists
- `internal/data/` directory exists
- Go imports include `github.com/go-kratos/kratos/v2`

---

## Related Skills

Combine with:
- `golang-patterns` - Go idioms and patterns
- `effective-go` - Go best practices
- `go-best-practices` - Production Go patterns

When to use: After Kratos-specific guidance, apply Go best practices to the implementation.

---

## Key Concepts

### Layered Architecture

Kratos follows a clean architecture:
- **Service Layer**: Protocol conversion (HTTP/gRPC → internal), simple validation
- **Biz Layer**: Business logic, domain models, use cases
- **Data Layer**: Data access, repository implementations, external services

**Why this matters**: Each layer has a clear responsibility. Changes to protocols don't affect business logic. Business logic doesn't depend on storage details.

### buf for Proto Management

Kratos recommends buf over raw protoc:
- Centralized plugin management via `buf.gen.yaml`
- Dependency management via `buf.yaml`
- Linting and breaking change detection

**Why this matters**: Consistent proto generation across team, easier dependency updates.

### protovalidate for Field Validation

Use buf's protovalidate (not envoy's protoc-gen-validate):
- CEL expression support for complex rules
- Runtime validation before business logic
- Proto-based validation definition

**Why this matters**: Validation rules stay with data definitions, no separate validation code.