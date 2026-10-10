# ChromaDB

Persistent ChromaDB server (official `chromadb/chroma` image) on the allocation port. Data in `/home/container/data`; a backup script is written to `/home/container/scripts/chromadb-backup.sh`.

## Authentication

Chroma 1.x (the pinned 1.5.3 image) has **no built-in auth**: the old `CHROMA_SERVER_AUTHN_PROVIDER` / `CHROMA_SERVER_AUTHN_CREDENTIALS` settings were removed in 1.0 and are silently ignored. So this egg:

- runs Chroma on `127.0.0.1:18000` inside the container (not reachable from outside), and
- runs a pinned Caddy 2.10.2 reverse proxy (downloaded at install, sha512-checked) on the allocation port. It forwards only requests that carry the token and answers everything else with `401`.

The token is 64 random hex characters, generated at install and stored in `/home/container/.chroma-token` (mode 0600, never printed to the console). Read it in the panel file manager. To use your own token, set the **Auth token** variable (32-128 chars of `A-Z a-z 0-9 . _ ~ -`). It replaces the stored token on next start. To rotate, delete `.chroma-token` (with the variable blank) and restart.

### Connecting clients

Send the token as `Authorization: Bearer <token>` or `X-Chroma-Token: <token>`.

Python:

```python
import chromadb
client = chromadb.HttpClient(
    host="<allocation-ip>", port=<port>,
    headers={"Authorization": "Bearer <token>"},
)
client.heartbeat()
```

JavaScript:

```js
import { ChromaClient } from "chromadb";
const client = new ChromaClient({
  path: "http://<allocation-ip>:<port>",
  fetchOptions: { headers: { Authorization: "Bearer <token>" } },
});
```

curl: `curl -H "Authorization: Bearer <token>" http://<allocation-ip>:<port>/api/v2/heartbeat`

Traffic is plain HTTP. Over untrusted networks, put it behind TLS or a tunnel (Cloudflare/Tailscale eggs) so the token isn't sent in clear.

Existing servers need a **Reinstall** after importing the updated egg (to get `start.sh`, `Caddyfile`, Caddy and the token). Data in `/home/container/data` is kept.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-chromadb.json`.

## Images

- ChromaDB 1.5.3: `chromadb/chroma:1.5.3`

Author: Mox Neo
