from __future__ import annotations

import re
from typing import Iterable, Optional
from typing import Any

_SAFE_DEFAULT_NAME = "file"

def split_object_key(key: str) -> tuple[str, str]:
    """
    Split a storage object key into (folder, basename).

    Examples:
      "a/b/c/file.pdf" -> ("a/b/c", "file.pdf")
      "file.pdf"       -> ("", "file.pdf")
      "/a/b/"          -> ("a", "b")  # normalized
    """
    k = (key or "").strip().strip("/")
    if not k:
        return "", ""
    if "/" not in k:
        return "", k
    folder, basename = k.rsplit("/", 1)
    return folder, basename



def sanitize_filename(filename: str, *, 
                      default_name: str = _SAFE_DEFAULT_NAME,
                      allowed_extensions: Optional[Iterable[str]] = None, 
                      default_extension: Optional[str] = None,
                      keep_original_extension: bool = True, 
                      max_length: int = 120,) -> str:
    """
    Produce a safe filename for object storage.

    What it does:
    - Strips any path parts ("/" or "\\")
    - Collapses whitespace -> underscore
    - Removes unsafe characters (keeps A-Z a-z 0-9 . _ -)
    - Normalizes/validates extension if allowed_extensions is provided
    - Enforces max_length (tries to preserve extension)

    Args:
      filename: user-provided filename
      default_name: used if filename becomes empty
      allowed_extensions: e.g. {"pdf"} or {"pdf","png","jpg","jpeg"}
                         Values may include or exclude the leading dot.
      default_extension: e.g. "pdf" (or ".pdf"). Used when:
                         - no extension, OR
                         - extension not allowed (when allowed_extensions is set), OR
                         - keep_original_extension=False
      keep_original_extension: if False, forces default_extension (if provided)
      max_length: final filename max length

    Returns:
      Safe filename (string). If extension rules produce no extension, returns name only.
    """
    name = (filename or "").strip()
    if not name:
        name = default_name

    # remove any path parts
    name = name.replace("\\", "/").split("/")[-1].strip()
    if not name:
        name = default_name

    # collapse whitespace
    name = re.sub(r"\s+", "_", name)

    # keep safe chars
    name = re.sub(r"[^A-Za-z0-9._-]", "", name)

    # If still empty, fallback
    if not name or name in {".", ".."}:
        name = default_name

    # Split base/ext (last dot only)
    base = name
    ext = ""
    if "." in name:
        base, ext = name.rsplit(".", 1)
        # handle ".bashrc" like names: base becomes "", ext becomes "bashrc"
        if base == "":
            base = default_name

    # normalize extension sets
    allowed = None
    if allowed_extensions is not None:
        allowed = {e.lower().lstrip(".") for e in allowed_extensions if str(e).strip()}
        if not allowed:
            allowed = None

    def _norm_ext(e: Optional[str]) -> str:
        if not e:
            return ""
        return str(e).lower().lstrip(".")

    default_ext = _norm_ext(default_extension)

    # extension decision
    final_ext = _norm_ext(ext) if keep_original_extension else ""
    if allowed is not None:
        if final_ext not in allowed:
            final_ext = default_ext if default_ext in allowed else (next(iter(allowed)) if allowed else "")
    else:
        # no allowed list => just use original unless forced
        if not keep_original_extension:
            final_ext = default_ext

    # build final name
    if final_ext:
        final_name = f"{base}.{final_ext}"
    else:
        final_name = base

    # enforce max length (preserve ext if possible)
    if max_length and len(final_name) > max_length:
        if final_ext:
            # reserve for dot + ext
            reserve = 1 + len(final_ext)
            cut = max_length - reserve
            if cut <= 0:
                # extreme case: ext alone too long => truncate ext
                final_ext = final_ext[: max_length - 1] if max_length > 1 else ""
                final_name = f"{default_name}.{final_ext}" if final_ext else default_name
            else:
                base_trunc = base[:cut]
                if not base_trunc:
                    base_trunc = default_name[:cut] or default_name
                final_name = f"{base_trunc}.{final_ext}"
        else:
            final_name = final_name[:max_length] or default_name

    return final_name



def delete_storage_object(*, supabase_client: Any, bucket: str, storage_key: str) -> None:
    storage_key = (storage_key or "").strip()
    bucket = (bucket or "").strip()

    if not bucket:
        raise ValueError("bucket is required")

    if not storage_key:
        raise ValueError("storage_key is required")

    try:
        result = supabase_client.storage.from_(bucket).remove([storage_key])
    except Exception as e:
        raise RuntimeError(f"Failed to delete storage object: {str(e)}") from e

    error = None

    if isinstance(result, dict):
        error = result.get("error")
    else:
        error = getattr(result, "error", None)
        data = getattr(result, "data", None)

        # بعض الإصدارات ترجع error داخل data
        if not error and isinstance(data, dict):
            error = data.get("error")

    if error:
        msg = error.get("message") if isinstance(error, dict) else str(error)
        raise RuntimeError(f"Failed to delete storage object: {msg}")