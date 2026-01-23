---
name: yzma
description: "Use this skill when working with yzma library for Go applications that integrate llama.cpp for local LLM inference. Triggers when creating, modifying, or debugging Go code that uses github.com/hybridgroup/yzma for language models, vision models, embeddings, or tool calling."
---

# Yzma - Go Integration for llama.cpp

This skill provides guidance for using the yzma library to build Go applications with local LLM inference using llama.cpp.

## When to Use This Skill

Use this skill automatically when:
- Writing Go code that imports `github.com/hybridgroup/yzma`
- Creating applications with local language model inference
- Working with GGUF format models
- Implementing chat, vision, embeddings, or tool-calling features
- Debugging yzma-based applications

## Installation and Setup

### Step 1: Install yzma CLI Tool

```bash
# Install the yzma command line tool
go install github.com/hybridgroup/yzma/cmd/yzma@latest

# Verify installation
yzma --help
```

### Step 2: Download llama.cpp Libraries

Choose the appropriate installation based on your hardware:

#### CPU Only (All Platforms)

```bash
# Create a directory for libraries
mkdir -p ~/yzma-lib

# Install CPU-only version
yzma install --lib ~/yzma-lib

# Set environment variable (add to ~/.bashrc or ~/.zshrc)
export YZMA_LIB=~/yzma-lib
```

#### GPU Acceleration - NVIDIA CUDA (Linux/Windows)

```bash
# Prerequisites: Install NVIDIA CUDA drivers first
# See: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/

# Install CUDA-accelerated version
yzma install --lib ~/yzma-lib --processor cuda

export YZMA_LIB=~/yzma-lib
```

#### GPU Acceleration - Vulkan (Linux/Windows)

```bash
# Prerequisites: Install Vulkan drivers
# Linux: sudo apt install -y mesa-vulkan-drivers vulkan-tools

# Install Vulkan-accelerated version
yzma install --lib ~/yzma-lib --processor vulkan

export YZMA_LIB=~/yzma-lib
```

#### GPU Acceleration - Metal (macOS M-series)

```bash
# No prerequisites needed on M-series Macs
# Metal support is built-in

# Install Metal-accelerated version (default on macOS)
yzma install --lib ~/yzma-lib

export YZMA_LIB=~/yzma-lib
```

### Step 3: Download Models

Models must be in GGUF format. Download from Hugging Face:

```bash
# Create models directory
mkdir -p ~/models

# Download a small model (recommended for testing)
yzma model get -u https://huggingface.co/QuantFactory/SmolLM-135M-GGUF/resolve/main/SmolLM-135M.Q4_K_M.gguf

# Download a chat model (recommended for applications)
yzma model get -u https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf

# Download a larger model (better quality, needs more RAM)
yzma model get -u https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf
```

**Model Size Guide:**
- **135M-500M**: Fast, low memory (~1GB RAM), good for testing
- **1B-3B**: Balanced, moderate memory (~4GB RAM), good for most apps
- **7B-13B**: High quality, high memory (~8-16GB RAM), production use
- **70B+**: Best quality, very high memory (~32GB+ RAM), specialized use

**Quantization Guide (Q4_K_M, Q8_0, etc.):**
- **Q2_K**: Smallest, lowest quality, ~2 bits per weight
- **Q4_K_M**: Recommended balance, ~4 bits per weight
- **Q5_K_M**: Better quality, ~5 bits per weight
- **Q8_0**: High quality, ~8 bits per weight
- **F16/F32**: Full precision, largest size, best quality

### Step 4: Verify Installation

```bash
# Check library files exist
ls -lh $YZMA_LIB

# Should see files like:
# libllama.so (Linux)
# libllama.dylib (macOS)
# llama.dll (Windows)
```

## Core Concepts

### Library Loading

Always load the llama.cpp library before using any yzma functions:

```go
import "github.com/hybridgroup/yzma/pkg/llama"

// Option 1: Load from environment variable (recommended)
libPath := os.Getenv("YZMA_LIB")
if libPath == "" {
    libPath = "./lib" // fallback to local directory
}

if err := llama.Load(libPath); err != nil {
    return fmt.Errorf("load llama library: %w", err)
}

// Option 2: Load from command-line flag
var libPath = flag.String("lib", "./lib", "path to llama library")
flag.Parse()
if err := llama.Load(*libPath); err != nil {
    return fmt.Errorf("load llama library: %w", err)
}

// Initialize and defer cleanup
llama.Init()
defer llama.Close()
```

### Model Loading Pattern

Standard pattern for loading models:

```go
// Load model with default parameters
model, err := llama.ModelLoadFromFile(modelFile, llama.ModelDefaultParams())
if err != nil {
    return fmt.Errorf("load model from file: %w", err)
}
defer llama.ModelFree(model)

// Create context
ctxParams := llama.ContextDefaultParams()
ctxParams.NCtx = 2048  // Context size
ctxParams.NBatch = 512 // Batch size

lctx, err := llama.InitFromModel(model, ctxParams)
if err != nil {
    return fmt.Errorf("init context from model: %w", err)
}
defer llama.Free(lctx)

// Get vocabulary
vocab := llama.ModelGetVocab(model)
```

### Sampler Configuration

Create samplers for token generation:

```go
// Default sampler with temperature
sp := llama.DefaultSamplerParams()
sp.Temp = 0.7
sp.TopK = 40
sp.TopP = 0.95
sp.MinP = 0.05

// Create sampler with default samplers chain
sampler := llama.NewSampler(model, llama.DefaultSamplers, sp)
defer llama.SamplerFree(sampler)

// Or create custom sampler chain
sampler := llama.SamplerChainInit(llama.SamplerChainDefaultParams())
llama.SamplerChainAdd(sampler, llama.SamplerInitGreedy())
```

## Common Use Cases

### 1. Simple Text Generation

```go
// Tokenize prompt
prompt := "Are you ready to go?"
tokens := llama.Tokenize(vocab, prompt, true, false)

// Create batch
batch := llama.BatchGetOne(tokens)

// Generate tokens
for pos := int32(0); pos < maxTokens; pos += batch.NTokens {
    llama.Decode(lctx, batch)
    token := llama.SamplerSample(sampler, lctx, -1)

    // Check for end of generation
    if llama.VocabIsEOG(vocab, token) {
        break
    }

    // Convert token to text
    buf := make([]byte, 128)
    length := llama.TokenToPiece(vocab, token, buf, 0, true)
    fmt.Print(string(buf[:length]))

    // Prepare next batch
    batch = llama.BatchGetOne([]llama.Token{token})
}
```

### 2. Chat with Templates

```go
import "github.com/hybridgroup/yzma/pkg/llama"

// Get chat template from model
template := llama.ModelChatTemplate(model, "")
if template == "" {
    template = "chatml" // fallback
}

// Build messages
messages := []llama.ChatMessage{
    llama.NewChatMessage("system", "You are a helpful assistant."),
    llama.NewChatMessage("user", "Hello!"),
}

// Apply template
buf := make([]byte, 4096)
length := llama.ChatApplyTemplate(template, messages, true, buf)
prompt := string(buf[:length])

// Tokenize and generate as usual
tokens := llama.Tokenize(vocab, prompt, true, true)
// ... continue with generation
```

### 3. Vision Language Models (VLM)

```go
import (
    "github.com/hybridgroup/yzma/pkg/llama"
    "github.com/hybridgroup/yzma/pkg/mtmd"
)

// Load both libraries
llama.Load(libPath)
mtmd.Load(libPath)

// Initialize multimodal context
mctxParams := mtmd.ContextParamsDefault()
mtmdCtx, err := mtmd.InitFromFile(projFile, model, mctxParams)
if err != nil {
    return fmt.Errorf("init mtmd context: %w", err)
}
defer mtmd.Free(mtmdCtx)

// Prepare prompt with image marker
messages := []llama.ChatMessage{
    llama.NewChatMessage("user", mtmd.DefaultMarker()+"What is in this picture?"),
}

// Load image
bitmap := mtmd.BitmapInitFromFile(mtmdCtx, imageFile)
defer mtmd.BitmapFree(bitmap)

// Tokenize with image
output := mtmd.InputChunksInit()
input := mtmd.NewInputText(chatTemplate(messages), true, true)
mtmd.Tokenize(mtmdCtx, output, input, []mtmd.Bitmap{bitmap})

// Evaluate chunks
var n llama.Pos
mtmd.HelperEvalChunks(mtmdCtx, lctx, output, 0, 0, int32(batchSize), true, &n)

// Generate response
for i := 0; i < maxTokens; i++ {
    token := llama.SamplerSample(sampler, lctx, -1)
    if llama.VocabIsEOG(vocab, token) {
        break
    }

    buf := make([]byte, 128)
    length := llama.TokenToPiece(vocab, token, buf, 0, true)
    fmt.Print(string(buf[:length]))

    batch := llama.BatchGetOne([]llama.Token{token})
    batch.Pos = &n
    llama.Decode(lctx, batch)
    n++
}
```

### 4. Tool Calling

```go
import (
    "github.com/hybridgroup/yzma/pkg/llama"
    "github.com/hybridgroup/yzma/pkg/message"
    "github.com/hybridgroup/yzma/pkg/template"
)

// Define tools in system prompt
systemPrompt := `You are a helpful assistant with access to tools.
When you need to use a tool, respond with:
<tool_call>
{"name": "function_name", "arguments": {"arg1": "value1"}}
</tool_call>`

// Build messages
messages := []message.Message{
    message.Chat{Role: "system", Content: systemPrompt},
    message.Chat{Role: "user", Content: "What's the weather?"},
}

// Apply template
chatTemplate := llama.ModelChatTemplate(model, "")
prompt, err := template.Apply(chatTemplate, messages, true)
if err != nil {
    return fmt.Errorf("apply template: %w", err)
}

// Generate and parse tool calls
tokens := llama.Tokenize(vocab, prompt, true, false)
response := generate(lctx, vocab, sampler, tokens)

toolCalls := message.ParseToolCalls(response)
for _, call := range toolCalls {
    // Execute tool
    result := executeToolCall(call)

    // Add tool response to messages
    messages = append(messages, message.Tool{
        Role:      "assistant",
        ToolCalls: []message.ToolCall{call},
    })
    messages = append(messages, message.ToolResponse{
        Role:    "tool",
        Name:    call.Function.Name,
        Content: result,
    })
}

// Generate final response with tool results
prompt, _ = template.Apply(chatTemplate, messages, true)
// Clear KV cache and regenerate
mem, _ := llama.GetMemory(lctx)
llama.MemoryClear(mem, true)
// ... continue generation
```

### 5. Embeddings

```go
// Create embedding context
ctxParams := llama.ContextDefaultParams()
ctxParams.Embeddings = true
ctxParams.NCtx = 512

lctx, err := llama.InitFromModel(model, ctxParams)
if err != nil {
    return fmt.Errorf("init embedding context: %w", err)
}
defer llama.Free(lctx)

// Tokenize text
text := "Hello, world!"
tokens := llama.Tokenize(vocab, text, true, false)

// Create batch
batch := llama.BatchGetOne(tokens)

// Decode to get embeddings
llama.Decode(lctx, batch)

// Get embeddings
nEmbd := llama.ModelNEmbd(model)
embeddings := llama.GetEmbeddingsSeq(lctx, 0)[:nEmbd]
```

## Best Practices

### Error Handling

Always check errors and wrap them with context:

```go
model, err := llama.ModelLoadFromFile(modelFile, llama.ModelDefaultParams())
if err != nil {
    return fmt.Errorf("load model from %s: %w", modelFile, err)
}
if model == 0 {
    return fmt.Errorf("model is null after loading from %s", modelFile)
}
```

### Resource Management

Always defer cleanup of resources:

```go
llama.Init()
defer llama.Close()

model, _ := llama.ModelLoadFromFile(modelFile, params)
defer llama.ModelFree(model)

lctx, _ := llama.InitFromModel(model, ctxParams)
defer llama.Free(lctx)

sampler := llama.NewSampler(model, samplers, sp)
defer llama.SamplerFree(sampler)
```

### Logging

Control logging verbosity:

```go
// Silent mode (recommended for production)
llama.LogSet(llama.LogSilent())

// Or use default logging for debugging
// (no call to LogSet)
```

### Context Size Management

Set appropriate context sizes based on your needs:

```go
ctxParams := llama.ContextDefaultParams()
ctxParams.NCtx = 2048    // Total context window
ctxParams.NBatch = 512   // Batch size for processing
ctxParams.NUbatch = 512  // Micro-batch size
```

### Mixture of Experts (MoE) Models

For MoE models, configure tensor buffer overrides:

```go
mParams := llama.ModelDefaultParams()

// Option 1: All FFN experts on CPU
overrides := []llama.TensorBuftOverride{
    llama.NewTensorBuftAllFFNExprsOverride(),
}
mParams.SetTensorBufOverrides(overrides)

// Option 2: Specific blocks on CPU
overrides := make([]llama.TensorBuftOverride, 0)
for i := 0; i < numBlocks; i++ {
    overrides = append(overrides, llama.NewTensorBuftBlockOverride(i))
}
mParams.SetTensorBufOverrides(overrides)
```

## Installation

### Quick Start

```bash
# Install yzma CLI
go install github.com/hybridgroup/yzma/cmd/yzma@latest

# Install llama.cpp libraries (CPU)
yzma install --lib /path/to/lib

# Install with GPU acceleration
yzma install --lib /path/to/lib --processor cuda
yzma install --lib /path/to/lib --processor vulkan

# Set environment variable
export YZMA_LIB=/path/to/lib
```

### Download Models

```bash
# Download a model
yzma model get -u https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf
```

## Hardware Acceleration

Yzma supports multiple hardware acceleration backends:

| OS      | CPU          | GPU                             |
|---------|--------------|----------------------------------|
| Linux   | amd64, arm64 | CUDA, Vulkan, HIP, ROCm, SYCL   |
| macOS   | arm64        | Metal                           |
| Windows | amd64        | CUDA, Vulkan, HIP, SYCL, OpenCL |

The appropriate backend is selected automatically based on the installed library.

## Model Formats

Yzma uses GGUF format models from llama.cpp. Find models at:
- https://huggingface.co/models?library=gguf

Popular model types:
- **SLM/LLM**: Text generation (Qwen, Gemma, Llama, SmolLM)
- **VLM**: Vision + text (Qwen2.5-VL, LLaVA)
- **Embeddings**: Text embeddings (nomic-embed-text)

## Common Patterns

### Interactive Chat Loop

```go
scanner := bufio.NewScanner(os.Stdin)
for {
    fmt.Print("USER> ")
    if !scanner.Scan() {
        break
    }

    userInput := scanner.Text()
    messages = append(messages, llama.NewChatMessage("user", userInput))

    // Apply template and generate
    prompt := applyTemplate(messages)
    tokens := llama.Tokenize(vocab, prompt, true, true)
    response := generate(lctx, vocab, sampler, tokens)

    fmt.Printf("ASSISTANT> %s\n", response)
    messages = append(messages, llama.NewChatMessage("assistant", response))
}
```

### Encoder-Decoder Models

```go
batch := llama.BatchGetOne(tokens)

if llama.ModelHasEncoder(model) {
    // Encode input
    llama.Encode(lctx, batch)

    // Get decoder start token
    start := llama.ModelDecoderStartToken(model)
    if start == llama.TokenNull {
        start = llama.VocabBOS(vocab)
    }

    // Start decoding
    batch = llama.BatchGetOne([]llama.Token{start})
}

// Continue with normal decoding
llama.Decode(lctx, batch)
```

## Troubleshooting

### Library Not Found

Ensure `YZMA_LIB` environment variable is set:

```bash
export YZMA_LIB=/path/to/lib
```

### Model Loading Fails

Check:
- Model file exists and is readable
- Model is in GGUF format
- Sufficient memory available

### Out of Context

Reduce context size or implement context management:

```go
// Clear KV cache
mem, _ := llama.GetMemory(lctx)
llama.MemoryClear(mem, true)

// Or implement sliding window
// Keep only recent tokens in context
```

## References

- GitHub: https://github.com/hybridgroup/yzma
- Documentation: https://pkg.go.dev/github.com/hybridgroup/yzma
- Examples: https://github.com/hybridgroup/yzma/tree/main/examples
- llama.cpp: https://github.com/ggml-org/llama.cpp
- Models: https://huggingface.co/models?library=gguf
