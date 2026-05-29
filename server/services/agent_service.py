"""
AgentService: loads agent .md files and runs them via Claude API Tool-Use.
Translates the My-Brain-Is-Full-Crew agent pattern to claude-sdk calls.
"""
import json
from pathlib import Path
from typing import Any

import anthropic

from config import get_settings
from services.token_usage_service import TokenUsageService

AGENTS_DIR = Path(__file__).parent.parent / "agents"


class AgentService:
    # J6 (Plan v2): prozess-weiter Shared-Singleton. Vorher instanziierte
    # jeder Request einen neuen anthropic.AsyncAnthropic-Client mit eigenem
    # Connection-Pool — verschwenderisch. Router rufen jetzt
    # AgentService.shared(). Constructor bleibt public für Tests.
    _shared: "AgentService | None" = None

    def __init__(self):
        self._settings = get_settings()
        self._client = anthropic.AsyncAnthropic(api_key=self._settings.anthropic_api_key)

    @classmethod
    def shared(cls) -> "AgentService":
        """Geteilte Instanz mit wiederverwendetem HTTP-Connection-Pool."""
        if cls._shared is None:
            cls._shared = cls()
        return cls._shared

    @classmethod
    def reset_shared(cls) -> None:
        """Test-Hook: verwirft die geteilte Instanz, damit ein neuer
        Mock-Client beim nächsten shared()-Aufruf greift."""
        cls._shared = None

    def _load_agent(self, name: str) -> str:
        """Load agent system prompt from agents/<name>.md"""
        path = AGENTS_DIR / f"{name}.md"
        if not path.exists():
            raise FileNotFoundError(f"Agent not found: {name}")
        return path.read_text(encoding="utf-8")

    async def run(
        self,
        agent_name: str,
        user_message: str,
        context: dict | None = None,
        user_id: str | None = None,
        endpoint: str | None = None,
    ) -> dict:
        """Run an agent and return its response + any tool calls made.

        When `user_id` is provided, the user's identity.md content is
        prepended to the system prompt for personalization.
        """
        system_prompt = self._load_agent(agent_name)

        # Prepend user identity context if available (per-user).
        if user_id:
            try:
                from services.identity_service import IdentityService
                identity = IdentityService.for_user(user_id).get()
                if identity:
                    system_prompt = f"## User Identity\n{identity}\n\n---\n\n{system_prompt}"
            except Exception:
                pass

        messages = []
        if context:
            messages.append({
                "role": "user",
                "content": f"Context:\n{json.dumps(context, indent=2, ensure_ascii=False)}\n\n{user_message}",
            })
        else:
            messages.append({"role": "user", "content": user_message})

        response = await self._client.messages.create(
            model=self._settings.claude_model,
            max_tokens=2048,
            system=system_prompt,
            messages=messages,
        )

        # Token-Tracking — niemals den eigentlichen Aufruf brechen.
        try:
            TokenUsageService.record(
                provider="anthropic",
                model=response.model,
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
                user_id=user_id,
                agent=agent_name,
                endpoint=endpoint,
            )
        except Exception as e:
            print(f"token usage record skipped (anthropic): {e}")

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
