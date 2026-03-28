import os


def verify_google_id_token(raw_token: str) -> dict:
    """
    Validate a Google Sign-In ID token.
    Set GOOGLE_CLIENT_ID or GOOGLE_CLIENT_IDS (comma-separated) to your OAuth client IDs.
    """
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token

    raw = os.getenv("GOOGLE_CLIENT_IDS") or os.getenv("GOOGLE_CLIENT_ID") or ""
    audiences = [x.strip() for x in raw.split(",") if x.strip()]
    if not audiences:
        raise ValueError("GOOGLE_CLIENT_ID or GOOGLE_CLIENT_IDS is not configured")
    last_err: Exception | None = None
    req = google_requests.Request()
    for aud in audiences:
        try:
            return id_token.verify_oauth2_token(raw_token, req, aud)
        except ValueError as e:
            last_err = e
            continue
    if last_err:
        raise last_err
    raise ValueError("Invalid Google credential")
