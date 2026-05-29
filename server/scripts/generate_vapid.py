"""Generiert ein VAPID-Keypair für Web Push (Notifications-Phase).

Einmal lokal laufen lassen, die ausgegebenen ENV-Variablen beim Server-
Host (Railway/Fly) setzen. Der Public-Key wird zusätzlich vom Client
über GET /push/vapid-public-key abgeholt — nicht im Build hardcoden.

    python scripts/generate_vapid.py

Sicherheit: der Private-Key ist ein Secret. Nicht committen, nur als
ENV setzen.
"""
import base64

from cryptography.hazmat.primitives import serialization
from py_vapid import Vapid


def main() -> None:
    v = Vapid()
    v.generate_keys()

    private_pem = v.private_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()

    public_raw = v.public_key.public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    public_b64 = base64.urlsafe_b64encode(public_raw).decode().rstrip("=")

    print("# ── VAPID keypair — beim Server-Host als ENV setzen ──")
    print("# (Private-Key NIEMALS committen)\n")
    print(f'VAPID_PUBLIC_KEY={public_b64}\n')
    print("# Private-Key ist mehrzeilig (PEM). Bei Railway/Fly als")
    print("# Multiline-Secret einfügen, oder \\n-escaped als eine Zeile:")
    print("VAPID_PRIVATE_KEY<<'EOF'")
    print(private_pem.strip())
    print("EOF\n")
    print("VAPID_SUBJECT=mailto:deine-email@example.com")


if __name__ == "__main__":
    main()
