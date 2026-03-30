"""
AgentService: loads agent .md files and runs them via Claude API Tool-Use.
Translates the My-Brain-Is-Full-Crew agent pattern to claude-sdk calls.
"""
import json
from pathlib import Path
from typing import Any

import anthropic

from config import get_settings

AGENTS_DIR = Path(__file__).parent.parent / "agents"


class AgentService:
    def __init__(self):
        self._settings = get_settings()
        self._client = anthropic.Anthropic(api_key=self._settings.anthropic_api_key)

    def _load_agent(self, name: str) -> str:
        """Load agent system prompt from agents/<name>.md"""
        path = AGENTS_DIR / f"{name}.md"
        if not path.exists():
            raise FileNotFoundError(f"Agent not found: {name}")
        return path.read_text(encoding="utf-8")

    async def run(self, agent_name: str, user_message: str, context: dict | None = None) -> dict:
        """Run an agent and return its response + any tool calls made."""
        system_prompt = self._load_agent(agent_name)

        messages = []
        if context:
            messages.append({
                "role": "user",
                "content": f"Context:\n{json.dumps(context, indent=2, ensure_ascii=False)}\n\n{user_message}",
            })
        else:
            messages.append({"role": "user", "content": user_message})

        response = self._client.messages.create(
            model=self._settings.claude_model,
            max_tokens=2048,
            system=system_prompt,
            messages=messages,
        )

        result = {"agent": agent_name, "content": "", "metadata": {}}

        for block in response.content:
            if block.type == "text":
                try:
                    parsed = json.loads(self._strip_markdown_json(block.text))
                    result["metadata"] = parsed
                    result["content"] = parsed.get("content", block.text)
                except json.JSONDecodeError:
                    result["content"] = block.text

        return result

    @staticmethod
    def _strip_markdown_json(text: str) -> str:
        """Strip ```json ... ``` or ``` ... ``` wrappers Claude sometimes adds."""
        text = text.strip()
        if text.startswith("```"):
            lines = text.splitlines()
            # Remove first line (```json or ```) and last line (```)
            inner = lines[1:-1] if lines[-1].strip() == "```" else lines[1:]
            return "\n".join(inner).strip()
        return text
