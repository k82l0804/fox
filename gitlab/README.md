# Local GitLab Community Edition (CE)

Lightweight, local GitLab Community Edition instance running in Docker for testing Fox agent integrations, GitLab provider APIs, pull/merge request detection, and local Git workflows.

## Features

- **Isolated & Lightweight**: Tuned Puma workers and Sidekiq concurrency to keep active RAM footprint around ~2.5–3.5 GB (instead of default 6–8 GB).
- **Non-Conflicting Ports**: Defaults to port `8929` for Web/REST API and port `2222` for SSH, avoiding conflicts with host SSH (port 22) or LiteLLM / dev servers (ports 80, 8000, 8080).
- **Persistent Docker Volumes**: Uses named volumes (`fox_gitlab_config`, `fox_gitlab_logs`, `fox_gitlab_data`) to prevent Linux permission issues on host worktree files.
- **Convenient Tooling**: `Makefile` with targets for lifecycle management, health monitoring, initial password extraction, and test token creation.

---

## Quick Start

### 1. Start GitLab
```bash
make up
```
This will start the container and monitor until `http://localhost:8929/-/health` reports ready.

> **Note**: On the first startup, GitLab performs internal database migrations and Puma initialization. This usually takes 2–4 minutes.

### 2. Retrieve Initial Root Password
```bash
make root-password
```
Use this password to log in to `http://localhost:8929` as user `root`.

*(Note: The initial password file is automatically deleted by GitLab after 24 hours).*

### 3. Generate a Test Personal Access Token (PAT)
To test Fox CLI or API integrations with an admin PAT:
```bash
make create-token
```
This creates a token with full API and repo access:
`glpat-fox-local-dev-token-12345`

### 4. Verify API Access
```bash
curl -sf -H "PRIVATE-TOKEN: glpat-fox-local-dev-token-12345" http://localhost:8929/api/v4/version
```

---

## Management Commands

| Command | Description |
|---|---|
| `make up` | Start GitLab container and wait for readiness |
| `make down` | Stop container (preserves all data in volumes) |
| `make stop` | Pause container |
| `make start` | Resume container |
| `make restart` | Restart container |
| `make status` | Show container status |
| `make logs` | Follow container logs (`Ctrl-C` to exit) |
| `make health` | Check instance health endpoint |
| `make root-password` | Display the initial root password |
| `make create-token` | Generate preconfigured API PAT for root user |
| `make reset` | Destroy container and delete all persistent volumes |

---

## Configuration

Settings can be customized in `.env` (copied automatically from `.env.example`):

```env
GITLAB_VERSION=latest
GITLAB_HTTP_PORT=8929
GITLAB_SSH_PORT=2222
GITLAB_EXTERNAL_URL=http://localhost:8929

# Worker & concurrency limits for low memory usage
GITLAB_PUMA_WORKERS=2
GITLAB_PUMA_MIN_THREADS=1
GITLAB_PUMA_MAX_THREADS=4
GITLAB_SIDEKIQ_CONCURRENCY=5
```

---

## Testing with Fox Code CLI

To point Fox CLI or git operations to your local GitLab instance:

1. **Git Clone / Push**:
   ```bash
   git clone ssh://git@localhost:2222/root/my-test-repo.git
   # or via HTTP:
   git clone http://root:glpat-fox-local-dev-token-12345@localhost:8929/root/my-test-repo.git
   ```

2. **GitLab Provider / Token**:
   Set environment variables:
   ```bash
   export GITLAB_INSTANCE_URL="http://localhost:8929"
   export GITLAB_TOKEN="glpat-fox-local-dev-token-12345"
   ```

---

## CI/CD Runners

To execute GitLab CI/CD pipelines locally, register a Docker-based GitLab Runner connected to the `gitlab_default` Docker network.

### 1. Create Runner in GitLab Web UI
1. Navigate to your project (or admin area) → **Settings → CI/CD → Runners**.
2. Click **New project runner**.
3. Configure the fields:
   - **Platform**: `Linux`
   - **Tags**: Optional (can leave blank).
   - **Run untagged jobs**: **Checked** (essential if your `.gitlab-ci.yml` jobs don't specify tags).
   - **Description**: `local-docker-runner`
   - **Lock to current projects**: Checked (or unchecked to share).
4. Click **Create runner** and copy the generated token (`glrt-...`).

### 2. Start and Register the Runner Container
Start the runner container:
```bash
docker run -d \
  --name fox-gitlab-runner \
  --restart unless-stopped \
  --network gitlab_default \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v fox_gitlab_runner_config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

Register it using your `glrt-...` token:
```bash
docker exec -it fox-gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab:8929" \
  --token "<YOUR_glrt_TOKEN>" \
  --executor "docker" \
  --docker-image "gcc:latest" \
  --docker-network-mode "gitlab_default" \
  --clone-url "http://gitlab:8929"
```

> **Key Networking Settings**:
> - `--network gitlab_default` and `--docker-network-mode "gitlab_default"` allow the runner and spawned job containers to communicate with the GitLab CE container.
> - `--clone-url "http://gitlab:8929"` ensures build containers clone repository data over the internal Docker network rather than failing on host `localhost:8929`.

