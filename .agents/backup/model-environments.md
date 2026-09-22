# Model Environments & Operational Constraints

## 1. Draper Workplace Environment (STRICT COMPLIANCE)

### Corporate Security Policy:
- **CHINESE MODELS ARE STRICTLY BANNED** at Draper.
- **NEVER** configure, recommend, or invoke Chinese-origin models when in the Draper environment (e.g., **no** Qwen, DeepSeek, Yi, GLM, ChatGLM, Baichuan, etc.).

### Corporate-Provided Internal Models:
Draper provides three specific internal models that Fox CLI must be tuned to use effectively:

| Model ID | Architecture / Tier | Recommended Role in Fox | Context Window |
|---|---|---|---|
| `nemotron-3-ultra-550b-nvfp4` | NVIDIA 550B NVFP4 (Frontier tier) | **Primary Doer / Architect (`@code`, `@plan`)** | 131K (131,072) |
| `gemma-4-31b-nvfp4` | Google Gemma 31B NVFP4 (High speed) | **Guardian Agent (SynOp Anubis)** / Evaluator | 131K (131,072) |
| `gpt-oss-120b` | Open-weight 120B foundation | Flexible Secondary / Subagent Coordinator | 131K (131,072) |

### Draper Quota & Resource Limits:
- **Context Window**: `131,072` tokens (131K)
- **Tokens Per Request Limit**: `300,394` tokens
- **Tokens Per Hour Limit**: `32,768,000` tokens/hour (auto-resets hourly)

### Fox CLI Optimization Goals for Draper:
- Fox's prompt formatting, token counting, and tool-call parsers must be first-class with `nemotron-3-ultra-550b`, `gemma-4-31b`, and `gpt-oss-120b`.
- Pair `gemma-4-31b` as the dedicated lightweight Guardian with `nemotron-3-ultra-550b` as the primary implementation engine.

### Infrastructure & Dev Environment:
- **Client**: Corporate-issued Windows laptop with VPN. **No local development is done on Windows** due to endpoint protection / antivirus interference.
- **Primary Dev Workstation**: Remote dedicated Linux server (twin of home `aorus` machine):
  - **GPU**: **NVIDIA RTX PRO 6000 (Blackwell architecture, 96 GB VRAM)**.
  - **CPU**: AMD Ryzen Pro.
  - **RAM**: 256 GB.
  - **Storage**: NVMe SSDs.
- **Corporate Inference Cluster**: Remote **NVIDIA H200s** (141GB HBM3e VRAM per GPU) serving the corporate model fleet.
- **Dev Workflow & Fox Approval Goal**:
  - Connects from Windows via VS Code Remote SSH to the Linux workstation.
  - Currently uses VS Code + Kilo coding agent; **goal is getting Fox CLI / `fox-acp-client` approved**.
  - Fox runs 100% natively on Linux (fast, zero AV friction, direct access to the 96GB RTX PRO 6000 and H200 models).

---

## 2. Home AI Lab Environment (OPEN RESEARCH & CLUSTER)

### Hardware Topography:
- **`speedy`**: Conductor laptop (current client node where CLI development, orchestration, and Antigravity IDE run).
- **`aorus`**: **2x NVIDIA RTX 3090s** (48GB total VRAM). Ideal for dual-model serving (Doer + Guardian) or 32B/70B Q4 quantized models.
- **`baby`**: **1x NVIDIA RTX 5090** (32GB GDDR7 VRAM). Blazing fast high-throughput inference node.
- **`taichi`**: **1x NVIDIA RTX 5090** (32GB GDDR7 VRAM). Symmetrical high-throughput inference node.
- **Cluster Interconnect**: **InfiniBand** networking across `aorus`, `baby`, and `taichi` for ultra-low latency inter-node communication, distributed inference, and direct MCP peer exchanges.

### Stack & Policy:
- **Unrestricted**: Open-source, Hugging Face, and Chinese-origin models (e.g. Qwen 2.5 Coder 7B/14B/32B, DeepSeek, Hermes 3, Salesforce xLAM) **can and are used**.
- Local LiteLLM proxy running at `http://localhost:8000/v1` (`openai-proxy`).
- Local GPU inference via vLLM / Ollama across the InfiniBand cluster nodes.
- Notice: Machine hostnames (`aorus`, `baby`, `taichi`) are the actual physical bodies of the Federation team members!
