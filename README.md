# aistack

aistack provides an unauthenticated OpenAI-compatible LiteLLM endpoint at `http://127.0.0.1:1337/v1`, a preconfigured Open WebUI at `http://127.0.0.1:1339`, and stable aliases such as `default` and `code` for local or remote inference.

It uses rootless Podman. LiteLLM, Ollama, and Open WebUI publish ports only on loopback, so no external network interface is exposed. Ollama also remains directly available at `http://127.0.0.1:1338` when the local profile is active. Open WebUI is preconfigured to call LiteLLM through the Compose network rather than Ollama directly. The private Compose network allows LiteLLM to reach Ollama and, for remote profiles, its configured upstream.

```
Linux laptop (rootless Podman)

  Browser -- 127.0.0.1:1339 --> [ Open WebUI ]
                                        |
                                        | Compose network only
  Local clients -- 127.0.0.1:1337/v1 -> [ LiteLLM ]
                                        | aliases: default, code,
                                        | translate, fast, embed
                        +---------------+----------------+
                        |                                |
                 local / lite profiles             lab / cloud profiles
                        |                                |
                    [ Ollama ]                    remote upstream
                        |
  Local clients -- 127.0.0.1:1338 --> local models

  All published ports bind to 127.0.0.1; only LiteLLM has remote egress.
```

Open WebUI starts in text-only mode: function/tool calling is disabled in local LiteLLM alias metadata, and Open WebUI disables memories, web search, search-query generation, code execution/interpreter, direct connections, and user webhooks. This avoids unsupported native-tool flows with local models. Enable a feature only after validating it with the selected model.

## Prerequisites

Install rootless Podman and a Podman Compose provider for your distribution. On Debian, Kali, or Ubuntu:

```bash
sudo apt update
sudo apt install -y podman podman-compose gettext-base
```

`gettext-base` provides `envsubst` for remote profile rendering.

Run `podman info` as the target user before installation. It must succeed without `sudo`.

## NVIDIA GPU Setup

Local inference works on CPU without extra configuration. To forward an NVIDIA GPU into rootless Ollama, install an NVIDIA driver, the NVIDIA Container Toolkit, and register the GPU as a CDI device for Podman.

On Debian-family distributions with the appropriate NVIDIA package repository enabled, a typical installation is:

```bash
sudo apt update
sudo apt install -y nvidia-driver

# Reboot to load driver

sudo apt-get update && sudo apt-get install -y --no-install-recommends \
   ca-certificates \
   curl \
   gnupg2

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.20.1-1
sudo apt-get install -y \
   nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
   nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
   libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
   libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

# Ready!
```

Restart after installing or updating the NVIDIA driver, then verify the host driver:

```bash
nvidia-smi
```

Generate the CDI specification and verify that Podman can discover the GPU. The exact CDI file location is distribution-dependent; `nvidia-ctk cdi generate` writes the standard system location when run with `sudo`.

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
nvidia-ctk cdi list
```

The list must include `nvidia.com/gpu=all`. Confirm rootless container access before enabling it for AI Stack. The first command may pull the CUDA image:

```bash
podman --remote run --rm --device nvidia.com/gpu=all \
  docker.io/nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
```

Enable the CDI device in the private AI Stack configuration, then recreate the local profile:

```bash
printf '\nOLLAMA_GPU_DEVICE=nvidia.com/gpu=all\n' >> ~/.config/aistack/config.env
chmod 600 ~/.config/aistack/config.env
aistack local
```

Check GPU discovery in the Ollama log:

```bash
podman --remote logs --tail 100 aistack-ollama
```

Look for `library=CUDA` and the NVIDIA GPU model. During an inference request, `nvidia-smi` should show Ollama using GPU memory.

## Install

```bash
./scripts/install.sh
```

The installer places the helper in `~/.local/bin/aistack` and creates a mode-`0600` user configuration file at `~/.config/aistack/config.env`. Add `~/.local/bin` to `PATH` if needed. If the configuration already exists, the installer asks before overwriting it and keeps the existing file by default.

Every profile reads `~/.config/aistack/config.env`, so it must exist before running any command; the installer seeds it from `config/config.env.example`. Run `./scripts/install.sh uninstall` to remove the helper symlink and the configuration directory. Uninstall leaves containers and volumes untouched; run `aistack reset all` first to remove those.

## Profiles

```bash
aistack local
aistack lite
aistack local --insecure-pull
aistack lab
aistack cloud
aistack status
aistack models
aistack stop
aistack reset all
aistack reset ollama
aistack reset openwebui
```

`local` starts Ollama, pulls models such as `gemma4:e4b-it-qat` once into the persistent `ollama-models` volume, and starts LiteLLM and Open WebUI. `lite` targets battery and CPU-first laptops and pulls lighter models. `lab` and `cloud` stop Ollama and route aliases to the configured OpenAI-compatible endpoint. Switching between `local` and `lite` force-recreates Ollama, LiteLLM, and Open WebUI; cached models remain in the persistent volume. The user configuration holds every profile's per-alias model IDs, the container image references, the remote endpoint URLs, and the API keys; do not commit it. Override any default loopback port in that configuration when it is already occupied.

When an Ollama model registry requires redirects that its default pull client cannot follow, use `aistack local --insecure-pull` or `aistack lite --insecure-pull`. This passes `--insecure` only to model downloads performed by that command.

Every local alias has an Ollama context window setting. `local` uses 16K by default and 64K for `code` and `offensive`; `lite` uses 4K by default and 32K for `code` and `offensive`. The remaining local aliases initially use their profile default. Adjust the matching `*_CONTEXT` variables in the private configuration for the available memory and model limits. The lab profile sends the same settings as `local` as Ollama-compatible request options. Cloud routing does not set them because context behavior is provider and model specific.

`aistack reset all` stops the stack and removes its persistent Ollama model cache and Open WebUI data volumes. `aistack reset ollama` removes only the Ollama model cache; `aistack reset openwebui` removes only Open WebUI data. Reset does not remove images, Podman data from other projects, or `~/.config/aistack/config.env`. The next `local` or `lite` run downloads required models again.

Local aliases are for this demo are:

| Alias | Ollama model |
| --- | --- |
| `default`, `code` | `gemma4:e4b-it-qat` |
| `translate` | `translategemma:4b` |
| `fast` | `llama3.2:3b` |
| `offensive` | `hf.co/prithivMLmods/Qwen3.8-27B-abliterated-GGUF:Q4_K_M` |
| `embed` | `bge-m3` |


`config/config.env.example` documents equivalent per-alias settings for both remote profiles, including `LAB_EMBED_MODEL` and `CLOUD_EMBED_MODEL` so the `embed` alias works on `lab` and `cloud` as well. `CLOUD_API_BASE=https://api.openai.com/v1` uses OpenAI directly; any OpenAI-compatible base URL is also supported.

## Security Boundary

There is intentionally no LiteLLM master key and no Ollama authentication. This is acceptable only because Compose binds both services explicitly to `127.0.0.1`. Do not change those bindings to `0.0.0.0` or another externally reachable address without adding authentication and reviewing access controls.

Remote credentials are supplied to LiteLLM only through the rendered active profile configuration. They are never needed by applications that call localhost.

## Verify

After `aistack local` completes, test the endpoint:

```bash
curl http://127.0.0.1:1337/v1/models
curl http://127.0.0.1:1338/api/tags
curl http://127.0.0.1:1337/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"default","messages":[{"role":"user","content":"Reply with one word: ready"}]}'
curl -sS http://127.0.0.1:1337/v1/embeddings \
  -H 'content-type: application/json' \
  -d '{"model":"embed","input":"text to index"}'
```

Open `http://127.0.0.1:1339` to use the preconfigured Open WebUI. It is intentionally unauthenticated because it is loopback-only, like LiteLLM and Ollama.

Inspect published addresses with `podman --remote ps --format '{{.Names}} {{.Ports}}'`; every published port must start with `127.0.0.1:`. Switching to `lab` or `cloud` should leave LiteLLM and Open WebUI running.

## Logs And Diagnostics

The Docker Compose provider uses Podman's rootless API socket, so use `podman --remote` for container inspection and logs.

```bash
# Stack status and loopback port bindings.
aistack status
podman --remote ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Follow logs. Press Ctrl+C to stop following without stopping the service.
podman --remote logs -f aistack-litellm
podman --remote logs -f aistack-open-webui
podman --remote logs -f aistack-ollama

# Inspect recent logs without following them.
podman --remote logs --tail 200 aistack-litellm
podman --remote logs --tail 200 aistack-open-webui
podman --remote logs --tail 200 aistack-ollama
```

Check loaded models and context in ollama:
```
podman --remote exec aistack-ollama ollama ps
```

Use these checks to separate proxy, model, and UI problems:

```bash
# Confirm the proxy aliases and the local Ollama model cache.
curl -fsS http://127.0.0.1:1337/v1/models
aistack models

# Send a direct request through LiteLLM, bypassing Open WebUI.
curl -i -sS http://127.0.0.1:1337/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"default","messages":[{"role":"user","content":"Reply exactly: ready"}],"stream":false}'

# Check the direct local Ollama endpoint while the local profile is active.
curl -i -sS http://127.0.0.1:1338/api/tags

# Render the effective local Compose configuration without changing containers.
cd /home/kali/aistack
LITELLM_CONFIG=$PWD/config/litellm.local.yaml.template podman compose -f compose.yaml config
```

LiteLLM runs with `--detailed_debug`; inspect its log first when a request reaches the proxy but does not produce the expected model response.
