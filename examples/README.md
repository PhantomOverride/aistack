# AI Stack Examples

These examples call aistack's OpenAI-compatible proxy at `http://127.0.0.1:1337/v1`. Start a profile first, for example:

```bash
aistack local
```

The proxy is intentionally unauthenticated because it is bound to loopback only. Do not expose it outside the local machine without adding authentication.

## Prerequisites

The shell example needs `curl` and `jq`. The Python examples require Python 3 and the official OpenAI SDK. Install it in a virtual environment:

```bash
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install openai
```

Run the Python examples while that virtual environment is active. This also works on distributions that mark the system Python as externally managed.

## Hello World

Run the shell example from the repository root:

```bash
./examples/helloworld.sh
```

Or use the Python SDK example:

```bash
python3 examples/helloworld.py
```

Both send a non-streaming request to the `default` model alias and print the model response.

## Interactive Chat

```bash
python3 examples/chat.py
```

Chat responses stream to the terminal. The next prompt appears only after the assistant stream finishes, so input is not accepted while it is responding. Press Ctrl+D or Ctrl+C to exit.

`chat.py` defaults to an 8,192-token context window and reserves 2,048 tokens for each model response. It estimates tokens as $\lceil\text{characters}/4\rceil$, so counts are portable across local and remote routed models but not tokenizer-exact. Before each request, it removes the oldest complete user/assistant exchanges until the estimated input plus the output reserve fit the context limit. The current prompt is never removed.

## Configuration

All examples use these defaults, which environment variables can override:

| Setting | Environment variable | Default |
| --- | --- | --- |
| Proxy base URL | `AISTACK_API_BASE` | `http://127.0.0.1:1337/v1` |
| Model alias | `AISTACK_MODEL` | `default` |
| SDK API key | `AISTACK_API_KEY` | `not-needed-for-loopback` |
| Chat context length | `AISTACK_CONTEXT_LENGTH` | `8192` |
| Chat output reserve | `AISTACK_MAX_TOKENS` | `2048` |

For `chat.py`, command-line options override environment variables:

```bash
python3 examples/chat.py --model code --context-length 16384 --max-tokens 4096
```

Run `python3 examples/chat.py --help` to see all options. The API-key value only satisfies the OpenAI SDK; aistack's loopback proxy does not require an upstream credential from client applications.