#!/usr/bin/env python3
"""A streaming terminal chat client that uses the local interface."""

import argparse
import math
import os
import sys
from collections.abc import Sequence

from openai import OpenAI


DEFAULT_API_BASE = "http://127.0.0.1:1337/v1"
DEFAULT_API_KEY = "not-needed-for-loopback"
DEFAULT_MODEL = "default"
DEFAULT_CONTEXT_LENGTH = 8192
DEFAULT_MAX_TOKENS = 2048


def environment_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError(f"{name} must be an integer") from error


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--api-base",
        default=os.getenv("AISTACK_API_BASE", DEFAULT_API_BASE),
        help="OpenAI-compatible base URL",
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("AISTACK_API_KEY", DEFAULT_API_KEY),
        help="API key required by the SDK; the loopback proxy does not authenticate it",
    )
    parser.add_argument(
        "--model",
        default=os.getenv("AISTACK_MODEL", DEFAULT_MODEL),
        help="Model alias",
    )
    parser.add_argument(
        "--context-length",
        type=int,
        default=environment_int("AISTACK_CONTEXT_LENGTH", DEFAULT_CONTEXT_LENGTH),
        help="maximum model context in tokens (default: %(default)s)",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=environment_int("AISTACK_MAX_TOKENS", DEFAULT_MAX_TOKENS),
        help="tokens reserved for each assistant response (default: %(default)s)",
    )
    args = parser.parse_args()
    if args.context_length <= 0:
        parser.error("--context-length must be positive")
    if args.max_tokens <= 0:
        parser.error("--max-tokens must be positive")
    if args.max_tokens >= args.context_length:
        parser.error("--max-tokens must be smaller than --context-length")
    return args


def estimate_tokens(messages: Sequence[dict[str, str]]) -> int:
    """Use a portable approximation when the routed model tokenizer is unknown."""
    return sum(math.ceil(len(message["content"]) / 4) for message in messages)


def trim_history(
    messages: list[dict[str, str]], context_length: int, max_tokens: int
) -> int:
    """Remove oldest completed user/assistant turns, never the pending user prompt."""
    purged_turns = 0
    while estimate_tokens(messages) + max_tokens > context_length:
        start = 1 if messages and messages[0]["role"] == "system" else 0
        for index in range(start, len(messages) - 1):
            if messages[index]["role"] == "user" and messages[index + 1]["role"] == "assistant":
                del messages[index : index + 2]
                purged_turns += 1
                break
        else:
            break
    return purged_turns


def main() -> None:
    args = parse_args()
    client = OpenAI(base_url=args.api_base, api_key=args.api_key)
    messages: list[dict[str, str]] = []

    print(f"Chatting with {args.model}. Press Ctrl+D or Ctrl+C to exit.")
    while True:
        try:
            prompt = input("You> ").strip()
        except EOFError:
            print()
            return
        except KeyboardInterrupt:
            print()
            return

        if not prompt:
            continue

        messages.append({"role": "user", "content": prompt})
        purged_turns = trim_history(messages, args.context_length, args.max_tokens)
        if purged_turns:
            print(f"[Purged {purged_turns} oldest turn(s) to fit the context limit.]")
        if estimate_tokens(messages) + args.max_tokens > args.context_length:
            print("[The current prompt exceeds the configured input budget.]", file=sys.stderr)

        try:
            stream = client.chat.completions.create(
                model=args.model,
                messages=messages,
                max_tokens=args.max_tokens,
                stream=True,
            )
            response_parts: list[str] = []
            print("Assistant> ", end="", flush=True)
            for chunk in stream:
                content = chunk.choices[0].delta.content if chunk.choices else None
                if content:
                    response_parts.append(content)
                    print(content, end="", flush=True)
            print()
            messages.append({"role": "assistant", "content": "".join(response_parts)})
        except KeyboardInterrupt:
            print()
            messages.pop()
        except Exception as error:
            print(f"Request failed: {error}", file=sys.stderr)
            messages.pop()


if __name__ == "__main__":
    main()