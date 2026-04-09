import os
from datetime import datetime
from typing import Literal


class Settings:
    def __init__(self):
        # App URLs
        self.api_base_url: str = os.getenv("API_BASE_URL", "http://127.0.0.1:8000")
        self.frontend_base_url: str = os.getenv("FRONTEND_BASE_URL", "http://localhost:5173")

        # JWT
        self.jwt_secret: str = os.getenv("JWT_SECRET", "")
        self.jwt_alg: str = os.getenv("JWT_ALG", "HS256")
        self.jwt_expire_min: int = int(os.getenv("JWT_EXPIRE_MIN", "60"))

        # Invite tokens (HMAC)
        self.invite_token_secret: str = os.getenv("INVITE_TOKEN_SECRET", "")

        # SMTP
        self.smtp_host: str = os.getenv("SMTP_HOST", "")
        self.smtp_port: int = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user: str = os.getenv("SMTP_USER", "")
        self.smtp_pass: str = os.getenv("SMTP_PASS", "")

        # Email branding
        self.email_logo_url: str = os.getenv("EMAIL_LOGO_URL", "")
        self.email_support_email: str = os.getenv("EMAIL_SUPPORT_EMAIL", "support@learnova.com")
        self.email_brand_year: int = int(os.getenv("EMAIL_BRAND_YEAR", str(datetime.now().year)))

        # Refresh token
        self.refresh_token_secret: str = os.getenv("REFRESH_TOKEN_SECRET", "")
        self.refresh_cookie_name: str = os.getenv("REFRESH_COOKIE_NAME", "refresh_token")
        self.refresh_token_expire_days_short: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS_SHORT", "1"))
        self.refresh_token_expire_days_remember: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS_REMEMBER", "30"))

        # ─── Cookie settings ─────────────────────────────────────────────────────
        # Auto-detected from ENV variable (default = development):
        #
        # Development  → SameSite=lax,  Secure=false
        #   Works on localhost because frontend & backend share the same host.
        #   Flutter Web XHR sends cookies automatically (same-site).
        #
        # Production   → SameSite=none, Secure=true
        #   Required for cross-domain cookies (different domains with HTTPS).
        #   Set ENV=production in your server environment variables.
        # ─────────────────────────────────────────────────────────────────────────
        is_production = os.getenv("ENV", "development").lower() == "production"

        self.cookie_secure: bool   = is_production
        self.cookie_samesite: str  = "none" if is_production else "lax"
        self.cookie_path: str      = os.getenv("COOKIE_PATH", "/")

        # Supabase Storage
        self.supabase_url: str = os.getenv("SUPABASE_URL", "")
        self.supabase_service_role_key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
        self.supabase_public_bucket: str = os.getenv("SUPABASE_PUBLIC_BUCKET", "learnova-public-assets")
        self.supabase_private_bucket: str = os.getenv("SUPABASE_PRIVATE_BUCKET", "learnova-private-assets")


settings = Settings()