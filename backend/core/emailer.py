import os
import smtplib
from email.message import EmailMessage


def send_email(
    to: str,
    subject: str,
    body: str,
    html: str | None = None,
) -> None:
    host = os.getenv("SMTP_HOST")
    port = int(os.getenv("SMTP_PORT", "587"))
    user = os.getenv("SMTP_USER")
    password = os.getenv("SMTP_PASS")
    sender = os.getenv("SMTP_FROM") or user

    missing = [k for k, v in {
        "SMTP_HOST": host,
        "SMTP_USER": user,
        "SMTP_PASS": password,
        "SMTP_FROM": sender,
    }.items() if not v]

    if missing:
        raise RuntimeError(f"Missing SMTP env vars: {', '.join(missing)}")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to

    # ✅ Plain text fallback
    msg.set_content(body)

    # ✅ HTML version (لو موجودة)
    if html:
        msg.add_alternative(html, subtype="html")

    with smtplib.SMTP(host, port) as smtp:
        smtp.starttls()
        smtp.login(user, password)
        smtp.send_message(msg)
