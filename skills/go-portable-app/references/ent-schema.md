# Ent Schema 与查询详解

> Ent 是类型安全的 ORM，代码生成，编译时检查

**官方文档**: https://entgo.io/docs/getting-started

---

## Ent 核心原则

- 轻松将数据库 schema建模为图结构
- 用 Go 代码定义 schema
- 基于代码生成的静态类型
- 数据库查询和图遍历易于编写
- 通过 Go 模板轻松扩展和自定义

---

## 安装

```bash
go get entgo.io/ent/cmd/ent
```

---

## Schema 定义

### 创建 Schema

```bash
go run -mod=mod entgo.io/ent/cmd/ent new User
go run -mod=mod entgo.io/ent/cmd/ent new Post
go run -mod=mod entgo.io/ent/cmd/ent new Comment
```

### Schema 结构

```go
package schema

import (
    "entgo.io/ent"
    "entgo.io/ent/schema/field"
    "entgo.io/ent/schema/edge"
    "entgo.io/ent/schema/index"
)

type User struct {
    ent.Schema
}

// Fields of the User.
func (User) Fields() []ent.Field {
    return []ent.Field{
        field.Int("age").
            Positive(),
        field.String("name").
            Default("unknown"),
    }
}

// Edges of the User.
func (User) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("groups", Group.Type),
        edge.To("friends", User.Type),
    }
}

// Indexes of the User.
func (User) Indexes() []ent.Index {
    return []ent.Index{
        index.Fields("age", "name").
            Unique(),
    }
}
```

Schema 文件存储在 `ent/schema/` 目录下。

---

## 字段类型

### 基础字段

```go
func (User) Fields() []ent.Field {
    return []ent.Field{
        // 基础类型
        field.String("name"),
        field.Int("age"),
        field.Float("score"),
        field.Bool("active"),
        
        // 时间类型
        field.Time("created_at").Default(time.Now),
        
        // JSON 类型
        field.JSON("metadata", map[string]interface{}{}),
        
        // UUID
        field.UUID("id", uuid.UUID{}).Default(uuid.New),
        
        // 枚举
        field.Enum("status").Values("draft", "published", "archived"),
        
        // 可选字段
        field.String("nickname").Optional(),
        field.Int("count").Optional().Nillable(),
        
        // 敏感字段（不打印）
        field.String("password").Sensitive(),
        
        // 约束
        field.String("email").Unique().NotEmpty(),
        field.Int("age").Positive().Range(0, 150),
    }
}
```

### 字段验证

```go
// Regexp 验证
field.String("name").
    Match(regexp.MustCompile("[a-zA-Z_]+$")),

// 范围验证
field.Int("age").
    Positive().
    Range(0, 150),
```

---

## Edge（关系）

### 一对多（One-to-Many）

```go
// User -> Posts（一个用户多个文章）
func (User) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("posts", Post.Type),
    }
}

func (Post) Edges() []ent.Edge {
    return []ent.Edge{
        edge.From("author", User.Type).
            Ref("posts").
            Unique(),  // 确保文章只有一个作者
    }
}
```

### 多对多（Many-to-Many）

```go
// User <-> Groups
func (User) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("groups", Group.Type),
    }
}

func (Group) Edges() []ent.Edge {
    return []ent.Edge{
        edge.From("users", User.Type).Ref("groups"),
    }
}
```

### 自引用（Self-Reference）

```go
// Post -> Comments（评论有子评论）
func (Comment) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("children", Comment.Type).
            From("parent").
            Unique(),
    }
}
```

---

## 查询操作

### 创建实体

```go
// 创建单个
user, err := client.User.
    Create().
    SetName("Alice").
    SetAge(30).
    SetEmail("alice@example.com").
    Save(ctx)

// 批量创建
bulk := make([]*ent.UserCreate, 100)
for i := 0; i < 100; i++ {
    bulk[i] = client.User.Create().SetName(fmt.Sprintf("User%d", i))
}
users, err := client.User.CreateBulk(bulk...).Save(ctx)
```

### 查询实体

```go
// 查询单个
user, err := client.User.Query().Where(user.ID(id)).Only(ctx)

// 查询所有
users, err := client.User.Query().All(ctx)

// 计数
count, err := client.User.Query().Count(ctx)

// 存在检查
exists, err := client.User.Query().Where(user.ID(id)).Exist(ctx)
```

### 条件查询

```go
// 等于/不等于
users, err := client.User.Query().
    Where(user.NameEQ("Alice")).   // 等于
    Where(user.NameNEQ("Alice")).  // 不等于
    All(ctx)

// 比较
users, err := client.User.Query().
    Where(user.AgeGT(18)).      // 大于
    Where(user.AgeGTE(18)).     // 大于等于
    Where(user.AgeLT(30)).      // 小于
    Where(user.AgeLTE(30)).     // 小于等于
    Where(user.AgeIn(18, 20, 22)). // IN
    Where(user.AgeNotIn(18, 20)).  // NOT IN
    All(ctx)

// 模糊匹配
users, err := client.User.Query().
    Where(user.NameContains("Ali")).     // LIKE '%Ali%'
    Where(user.NameHasPrefix("Ali")).    // LIKE 'Ali%'
    Where(user.NameHasSuffix("ice")).    // LIKE '%ice'
    All(ctx)

// NULL 检查
users, err := client.User.Query().
    Where(user.NicknameIsNil()).     // IS NULL
    Where(user.NicknameNotNil()).    // IS NOT NULL
    All(ctx)

// OR 条件
users, err := client.User.Query().
    Where(
        user.Or(
            user.AgeGT(18),
            user.NameEQ("Alice"),
        ),
    ).All(ctx)

// NOT 条件
users, err := client.User.Query().
    Where(
        user.Not(
            user.AgeGT(30),
        ),
    ).All(ctx)
```

### 排序和分页

```go
// 排序
users, err := client.User.Query().
    OrderBy(user.AgeAsc(), user.NameDesc()). // 升序/降序
    All(ctx)

// 分页
users, err := client.User.Query().
    Limit(10).
    Offset(20).
    All(ctx)
```

---

## 图遍历（Graph Traversal）

Ent 支持通过关系链式查询：

```go
// 查询 "GitHub" 组所有用户的汽车
cars, err := client.Group.
    Query().
    Where(group.Name("GitHub")). // (Group(Name=GitHub),)
    QueryUsers().                // (User(Name=Ariel, Age=30),)
    QueryCars().                 // (Car(Model=Tesla), Car(Model=Mazda),)
    All(ctx)

// 从用户 Ariel 开始遍历
a8m := client.User.Query().
    Where(
        user.HasCars(),
        user.Name("Ariel"),
    ).
    OnlyX(ctx)

cars, err := a8m.
    QueryGroups().              // 用户所在组
    QueryUsers().               // 组内所有用户
    QueryCars().                // 用户们的汽车
    Where(
        car.Not(
            car.Model("Mazda"), // 过滤掉 Mazda
        ),
    ).
    All(ctx)
```

---

## Eager Loading（避免 N+1）

```go
// 加载关联（一次查询）
users, err := client.User.Query().
    WithPosts().           // 加载文章
    WithComments().        // 加载评论
    WithGroups(func(q *ent.GroupQuery) {
        q.WithMembers()    // 嵌套加载
    }).
    All(ctx)

// 使用关联
for _, u := range users {
    posts := u.Edges.Posts.Nodes
    comments := u.Edges.Comments.Nodes
}
```

---

## 更新操作

```go
// 更新单个
user, err := client.User.UpdateOneID(id).
    SetName("Bob").
    SetAge(25).
    Save(ctx)

// 批量更新
affected, err := client.User.Update().
    Where(user.AgeLT(18)).
    SetActive(false).
    Save(ctx)

// 增减操作
affected, err := client.User.Update().
    Where(user.ID(id)).
    AddAge(1).        // 加1
    ClearNickname().  // 清空字段
    Save(ctx)
```

---

## 删除操作

```go
// 删除单个
err := client.User.DeleteOneID(id).Exec(ctx)

// 批量删除
affected, err := client.User.Delete().
    Where(user.AgeLT(18)).
    Exec(ctx)
```

---

## 事务

```go
// 开启事务
tx, err := client.Tx(ctx)
if err != nil {
    return err
}

// 使用事务客户端
user, err := tx.User.Create().SetName("Alice").Save(ctx)
if err != nil {
    return rollback(tx, err)  // 失败回滚
}

post, err := tx.Post.Create().SetTitle("Hello").SetAuthor(user).Save(ctx)
if err != nil {
    return rollback(tx, err)
}

// 提交
return tx.Commit()

// 回滚辅助函数
func rollback(tx *ent.Tx, err error) error {
    if rerr := tx.Rollback(); rerr != nil {
        err = fmt.Errorf("%w: %v", err, rerr)
    }
    return err
}
```

---

## 钩子（Hooks）

```go
// Schema 级定义钩子
func (User) Hooks() []ent.Hook {
    return []ent.Hook{
        hook.On(ValidateUser, ent.OpCreate|ent.OpUpdate),
        hook.On(LogChanges, ent.OpDelete),
    }
}

// 验证钩子
func ValidateUser(next ent.Mutator) ent.Mutator {
    return ent.MutatorFunc(func(ctx context.Context, m ent.Mutation) (ent.Value, error) {
        if m.Op().Is(ent.OpCreate) {
            if name, ok := m.Field("name"); ok {
                if len(name.(string)) < 3 {
                    return nil, fmt.Errorf("name too short")
                }
            }
        }
        return next.Mutate(ctx, m)
    })
}
```

---

## 索引定义

```go
func (User) Indexes() []ent.Index {
    return []ent.Index{
        // 单字段索引
        index.Fields("email"),
        
        // 唯一索引
        index.Fields("username").Unique(),
        
        // 复合索引
        index.Fields("first_name", "last_name"),
        
        // 复合唯一索引
        index.Fields("email", "status").Unique(),
    }
}
```

---

## 性能优化

### 批量操作

```go
// 批量创建（比循环创建快10倍）
bulk := make([]*ent.UserCreate, len(users))
for i, u := range users {
    bulk[i] = client.User.Create().SetName(u.Name)
}
users, err := client.User.CreateBulk(bulk...).Save(ctx)
```

### 避免 N+1 问题

```go
// ❌ 错误：每个用户查一次文章
for _, u := range users {
    posts, _ := client.Post.Query().Where(post.AuthorID(u.ID)).All(ctx)
}

// ✅ 正确：一次查询加载所有关联
users, _ := client.User.Query().WithPosts().All(ctx)
for _, u := range users {
    posts := u.Edges.Posts.Nodes
}
```

---

## 错误处理

```go
user, err := client.User.Query().Where(user.ID(id)).Only(ctx)
if err != nil {
    if ent.IsNotFound(err) {
        // 未找到
        return nil, fmt.Errorf("user not found")
    }
    if ent.IsConstraintError(err) {
        // 约束冲突（唯一键等）
        return nil, fmt.Errorf("user already exists")
    }
    if ent.IsValidationError(err) {
        // 验证失败
        return nil, fmt.Errorf("validation failed")
    }
    return nil, err
}
```

---

## 生成代码

```bash
# 生成所有 schema
go generate ./ent

# 指定 schema
go run -mod=mod entgo.io/ent/cmd/ent generate ./ent/schema
```

### go.mod 配置

```go
//go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema
```

---

## Schema 可视化

使用 Atlas 可视化 Ent schema：

```bash
# 安装 Atlas
brew install ariga/tap/atlas

# 可视化 ERD
atlas schema inspect \
  -u "ent://ent/schema" \
  --dev-url "sqlite://file?mode=memory&_fk=1" \
  -w  # 在浏览器中打开
```

---

## 参考资料

- [Ent Getting Started](https://entgo.io/docs/getting-started)
- [Ent Schema Definition](https://entgo.io/docs/schema-def)
- [Ent CRUD Operations](https://entgo.io/docs/crud)
- [Ent Schema Edges](https://entgo.io/docs/schema-edges)