import os
import hashlib
import hmac
import base64


_ITERATIONS = 310_000  # رقم كويس حالياً
_SALT_BYTES = 16
_DKLEN = 32


def hash_password(password: str) -> str:
    salt = os.urandom(_SALT_BYTES)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, _ITERATIONS, dklen=_DKLEN)
    # نخزنها في صيغة واحدة داخل string: iterations$salt$hash
    return f"{_ITERATIONS}${base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        it_str, salt_b64, dk_b64 = stored.split("$", 2)
        iterations = int(it_str)
        salt = base64.b64decode(salt_b64.encode())
        dk_expected = base64.b64decode(dk_b64.encode())
    except Exception:
        return False

    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations, dklen=len(dk_expected))
    return hmac.compare_digest(dk, dk_expected)


def hmac_sha256_hex(message: str, secret: str) -> str:
    return hmac.new(
        key=secret.encode("utf-8"),
        msg=message.encode("utf-8"),
        digestmod=hashlib.sha256,
    ).hexdigest()