#!/usr/bin/env python3
"""Simple Hello World in Python that connects to the local interface."""

import os

from openai import OpenAI


API_BASE = os.getenv("AISTACK_API_BASE", "http://127.0.0.1:1337/v1")
API_KEY = os.getenv("AISTACK_API_KEY", "not-needed-for-loopback")
MODEL = os.getenv("AISTACK_MODEL", "default")


def main() -> None:
    client = OpenAI(base_url=API_BASE, api_key=API_KEY)
    completion = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "Say hello world."}],
    )
    print(completion.choices[0].message.content or "")


if __name__ == "__main__":
    main()