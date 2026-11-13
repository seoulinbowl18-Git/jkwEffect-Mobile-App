"""Entry point production (Railway/Railpack): `python main.py`.

Railway memberikan port lewat env var PORT. `app` juga diekspor agar
`uvicorn main:app` tetap bisa dipakai.
"""
import os

import uvicorn

from server import app  # noqa: F401  (diekspor untuk `uvicorn main:app`)

if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=int(os.environ.get("PORT", "8000")),
        proxy_headers=True,  # hormati X-Forwarded-* dari proxy Railway (https, host)
        forwarded_allow_ips="*",
    )
