# Spec 02: Local Model Subsystem

> Technical specification for Fox CLI's local model integration, OpenAI-compatible protocol client, streaming processor, and local inference targets.

---

## 1. Overview & Objectives

Fox CLI is engineered for **offline, local-first environments**. Unlike Kilo Code CLI, which bundles 20+ proprietary cloud providers (AWS Bedrock, GCP Vertex, Anthropic, Azure, Groq, Mistral, etc.) and complex credential managers, Fox CLI interacts exclusively with **OpenAI-compatible HTTP endpoints**.

### Core Requirements
1. **Single Unified Protocol**: Rely entirely on the standard `POST /v1/chat/completions` API with Server-Sent Events (SSE) streaming.
2. **Zero Cloud Dependencies**: No cloud SDKs (`@ai-sdk/amazon-bedrock`, `@ai-sdk/google-vertex`, etc.), no IAM credential lookups, and no telemetry pings.
3. **Seamless Dev-to-Prod Transition**:
   - In development: Connect to `openai-proxy` (`http://localhost:8000/v1`) using LiteLLM to simulate local inference.
   - In production: Connect to native local LLM runners (Ollama, vLLM, LM Studio, llama.cpp, LocalAI) without code modifications.
4. **Structured Tool Calling**: Support standard OpenAI tool definitions (`tools: [{ type: "function", function: { ... } }]`) and streaming tool call deltas (`delta.tool_calls`).
5. **Robust Streaming & Reasoning Extraction**: Parse incoming tokens, handle reasoning/thinking tokens (e.g., `<think>` tags or `delta.reasoning_content`), and maintain keep-alive stability.

---

## 2. Target Environments & Supported Backends

| Backend | Typical Endpoint | Default Models | Capabilities | Notes |
|---|---|---|---|---|
| **Fox Dev Proxy (`openai-proxy`)** | `http://localhost:8000/v1` | `gpt-4o-mini`, `gpt-4o` | Tools, Streaming, JSON Schema | LiteLLM routing to Google Gemini; requires API key in proxy `.env`. |
| **Ollama** | `http://localhost:11434/v1` | `qwen2.5-coder`, `llama3.3`, `deepseek-coder` | Tools, Streaming | Native OpenAI-compatible compatibility layer at `/v1`. |
| **vLLM** | `http://localhost:8000/v1` | Any hosted GGUF/AWQ/Safetensors | High-throughput, Tools, PagedAttention | High-performance enterprise local hosting. |
| **LM Studio** | `http://localhost:1234/v1` | Any loaded model | Local GUI server, Tools, Streaming | User-friendly desktop local inference. |
| **llama.cpp server** | `http://localhost:8080/v1` | Any `.gguf` file | Fast CPU/Metal/CUDA inference | Ultra-lightweight native runner. |

---

## 3. Configuration & Environment Resolution

The model client determines its connection parameters using a prioritized resolution order:
1. CLI Flags (`--base-url`, `--model`, `--api-key`)
2. Environment Variables (`OPENAI_BASE_URL`, `OPENAI_API_KEY`, `FOX_MODEL`)
3. Workspace Config (`.fox/config.json`)
4. Global User Config (`~/.config/fox/config.json`)
5. Built-in Defaults

### Configuration Schema

```typescript
export interface ModelConfig {
  /** Base URL for OpenAI-compatible endpoint. Defaults to http://localhost:8000/v1 */
  baseUrl: string;
  
  /** Authentication bearer token. Defaults to 'local-dev' */
  apiKey: string;
  
  /** Model identifier. Defaults to 'gpt-4o-mini' */
  model: string;
  
  /** Sampling temperature (0.0 to 1.0). Defaults to 0.1 for coding precision */
  temperature: number;
  
  /** Maximum generation tokens. Defaults to 4096 */
  maxTokens?: number;
  
  /** Context window limit in tokens. Defaults to 32768 */
  contextWindow: number;
  
  /** Request timeout in milliseconds. Defaults to 120000 (2 minutes) */
  timeoutMs: number;
}
```

### Environment Variable Defaults
```bash
OPENAI_BASE_URL="http://localhost:8000/v1"
OPENAI_API_KEY="local-dev"
FOX_MODEL="gpt-4o-mini"
FOX_CONTEXT_WINDOW=32768
FOX_TEMPERATURE=0.1
```

---

## 4. Chat Completion Protocol & Request Structure

Requests sent to the local endpoint follow standard OpenAI format:

```json
POST /v1/chat/completions
Content-Type: application/json
Authorization: Bearer local-dev

{
  "model": "gpt-4o-mini",
  "stream": true,
  "temperature": 0.1,
  "max_tokens": 4096,
  "messages": [
    {
      "role": "system",
      "content": "You are Fox, an expert autonomous coding assistant..."
    },
    {
      "role": "user",
      "content": "Read the package.json and summarize its dependencies."
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "read_file",
        "description": "Read file contents from workspace",
        "parameters": {
          "type": "object",
          "properties": {
            "path": { "type": "string" },
            "startLine": { "type": "integer" },
            "endLine": { "type": "integer" }
          },
          "required": ["path"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}
```

---

## 5. Streaming Processor & SSE Event Handling

Local models stream tokens over Server-Sent Events (`text/event-stream`). The Fox streaming client parses each `data: {...}` line, tracking three concurrent streams:
1. **Content Stream**: General conversational text sent to the user/session.
2. **Reasoning / Thought Stream**: Reasoning tokens (from `delta.reasoning_content` or `<think>...</think>` tags common in DeepSeek and local reasoning models).
3. **Tool Call Stream**: Accumulated tool calls indexed by `delta.tool_calls[i]`.

### Streaming Lifecycle

```
HTTP Connection Opened (POST /v1/chat/completions, stream=true)
    │
    ├── [data: {"choices":[{"delta":{"role":"assistant"}}]}]  -> onStart()
    │
    ├── [data: {"choices":[{"delta":{"content":"Let me "}}]}]  -> onTextDelta("Let me ")
    │
    ├── [data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"read_file","arguments":""}}]}}]}]
    │       -> onToolCallStart({ id: "call_1", name: "read_file" })
    │
    ├── [data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"path\":"}}]}}]}]
    │       -> onToolCallDelta({ id: "call_1", args: "{\"path\":" })
    │
    ├── [data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"package.json\"}"}}]}}]}]
    │       -> onToolCallDelta({ id: "call_1", args: "\"package.json\"}" })
    │
    ├── [data: {"choices":[{"finish_reason":"tool_calls"}]}]
    │       -> onToolCallComplete({ id: "call_1", name: "read_file", args: { path: "package.json" } })
    │
    └── [data: [DONE]]  -> onFinish()
```

### Thinking / Reasoning Tag Normalizer
Certain local models (e.g. `deepseek-r1`, `qwq`) output thoughts directly into the content stream wrapped in `<think>...</think>` tags instead of structured API fields. The streaming processor includes a lightweight state machine to intercept these tokens:
- When `<think>` is encountered: Route subsequent content deltas to the `reasoning` channel.
- When `</think>` is encountered: Resume routing content deltas to the standard `content` channel.
- This ensures clean separation in ACP and REST event streams.

---

## 6. Token Counting & Context Management

Local inference engines often have smaller context windows (e.g., 8k, 16k, 32k tokens) compared to frontier cloud models. Exceeding the window results in severe performance degradation or runtime errors.

### Fast Token Estimation
Fox uses a dual-strategy token estimator:
1. **Accurate (Node.js)**: Fast BPE tokenizer (`gpt-tokenizer` or `tiktoken`) for OpenAI-compatible token estimates.
2. **Fallback / Fast Heuristic**: 1 token ≈ 3.7 characters for source code and English text.

### Truncation & Compaction Trigger
- **Threshold**: When context size reaches **80% of `contextWindow`**, the agent orchestrator initiates **Context Compaction**.
- **Action**: Older message turns are summarized into a concise state checkpoint, and intermediate tool call outputs (e.g. large file reads or compiler logs) are truncated.
- **Pinned Context**: System prompt, current user prompt, active task list, and recent turns are preserved verbatim.

---

## 7. Model Discovery & Verification (`fox models`)

Fox CLI provides a built-in verification mechanism to test local model connectivity:

```bash
fox models
```

### Verification Flow
1. Sends `GET {baseUrl}/models` with `Authorization: Bearer {apiKey}`.
2. Validates HTTP 200 response and parses the returned model IDs.
3. Performs a lightweight 1-token test prompt (`"ping"`) to verify inference readiness and streaming response latency.
4. Prints a formatted status table in the terminal:

```
Fox Model Subsystem Status
─────────────────────────────────────────────
Base URL:       http://localhost:8000/v1
Active Model:   gpt-4o-mini
Status:         CONNECTED (Latency: 42ms)

Available Models at Endpoint:
  • gpt-4o-mini   (Active)
  • gpt-4o
  • qwen2.5-coder:14b
─────────────────────────────────────────────
```
