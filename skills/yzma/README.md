# Yzma Skill for Claude Code

This skill provides comprehensive guidance for working with the [yzma](https://github.com/hybridgroup/yzma) library - a Go package that integrates llama.cpp for local LLM inference with hardware acceleration.

## What is Yzma?

Yzma is a Go library that lets you:
- Run language models locally without external servers
- Use hardware acceleration (CUDA, Metal, Vulkan, etc.)
- Work with GGUF format models from llama.cpp
- Build applications with text generation, chat, vision, embeddings, and tool calling
- Avoid CGo by using purego and ffi packages

## Skill Features

This skill helps you:

1. **Set up yzma projects** - Proper library loading, initialization, and cleanup
2. **Load and configure models** - Model loading, context creation, and parameter tuning
3. **Implement common patterns** - Text generation, chat, vision models, embeddings, tool calling
4. **Handle resources correctly** - Proper defer patterns and error handling
5. **Optimize performance** - Context sizing, batch configuration, sampler tuning
6. **Debug issues** - Common problems and solutions

## When This Skill Activates

The skill automatically activates when you:
- Import `github.com/hybridgroup/yzma` packages
- Work with GGUF models or llama.cpp
- Create LLM-powered Go applications
- Debug yzma-related code

## Quick Example

Here's what the skill helps you build:

```go
package main

import (
    "fmt"
    "os"
    "github.com/hybridgroup/yzma/pkg/llama"
)

func main() {
    // Load library
    llama.Load(os.Getenv("YZMA_LIB"))
    llama.LogSet(llama.LogSilent())
    llama.Init()
    defer llama.Close()

    // Load model
    model, _ := llama.ModelLoadFromFile("model.gguf", llama.ModelDefaultParams())
    defer llama.ModelFree(model)

    // Create context
    lctx, _ := llama.InitFromModel(model, llama.ContextDefaultParams())
    defer llama.Free(lctx)

    // Generate text
    vocab := llama.ModelGetVocab(model)
    tokens := llama.Tokenize(vocab, "Hello", true, false)
    batch := llama.BatchGetOne(tokens)

    sampler := llama.SamplerChainInit(llama.SamplerChainDefaultParams())
    llama.SamplerChainAdd(sampler, llama.SamplerInitGreedy())

    for i := 0; i < 50; i++ {
        llama.Decode(lctx, batch)
        token := llama.SamplerSample(sampler, lctx, -1)

        if llama.VocabIsEOG(vocab, token) {
            break
        }

        buf := make([]byte, 128)
        length := llama.TokenToPiece(vocab, token, buf, 0, true)
        fmt.Print(string(buf[:length]))

        batch = llama.BatchGetOne([]llama.Token{token})
    }
}
```

## Supported Use Cases

### 1. Text Generation
Simple prompt-to-text generation with customizable sampling parameters.

### 2. Interactive Chat
Multi-turn conversations with chat templates and message history.

### 3. Vision Language Models (VLM)
Process images with text prompts using multimodal models.

### 4. Tool Calling
Enable LLMs to call functions and use external tools.

### 5. Embeddings
Generate vector embeddings for semantic search and similarity.

### 6. Model Information
Query model metadata, vocabulary, and capabilities.

## Installation

The skill includes guidance for:

```bash
# Install yzma CLI
go install github.com/hybridgroup/yzma/cmd/yzma@latest

# Install llama.cpp libraries
yzma install --lib ~/yzma-lib --processor cuda

# Download models
yzma model get -u https://huggingface.co/model.gguf

# Set environment
export YZMA_LIB=~/yzma-lib
```

## Hardware Acceleration

The skill covers all supported acceleration backends:

- **Linux**: CPU, CUDA, Vulkan, HIP, ROCm, SYCL
- **macOS**: CPU, Metal (M-series)
- **Windows**: CPU, CUDA, Vulkan, HIP, SYCL, OpenCL

## Best Practices Enforced

1. **Always defer cleanup** - Model, context, sampler cleanup
2. **Check errors** - Proper error handling with context
3. **Set YZMA_LIB** - Environment variable for library path
4. **Use appropriate context sizes** - Based on model and use case
5. **Silent logging in production** - Use `llama.LogSilent()`
6. **Proper token handling** - Check for EOG tokens
7. **Resource management** - Free resources in correct order

## Examples Covered

The skill provides patterns for all official yzma examples:

- `hello` - Basic text generation
- `chat` - Interactive chat with templates
- `vlm` - Vision language models
- `tooluse` - Function calling
- `embeddings` - Vector embeddings
- `modelinfo` - Model metadata
- `systeminfo` - System capabilities
- `multitool` - Multiple tool calling
- `describe` - Image description
- `installer` - Library installation

## References

- [Yzma GitHub](https://github.com/hybridgroup/yzma)
- [Yzma Documentation](https://pkg.go.dev/github.com/hybridgroup/yzma)
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [GGUF Models](https://huggingface.co/models?library=gguf)
- [Installation Guide](https://github.com/hybridgroup/yzma/blob/main/INSTALL.md)

## Contributing

To improve this skill:

1. Add new patterns from yzma examples
2. Update for new yzma releases
3. Add troubleshooting tips
4. Include performance optimization techniques
5. Document edge cases and gotchas

## License

This skill documentation follows the same license as the yzma project (Apache 2.0).
