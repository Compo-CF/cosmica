#!/usr/bin/env python3
"""Cosmica (copied from Ghostline, two targets). One-time (and yearly) iOS signing setup for CI, all by App Store Connect API. Run on Windows:

  python scripts/ci/ios_signing_setup.py              # bundle id + distribution cert + App Store profile
  python scripts/ci/ios_signing_setup.py --set-secrets   # ...and push the 5 repo secrets with gh

What it does (idempotent):
  1. Registers bundle id com.centricfiber.ghostline (IN_APP_PURCHASE capability).
  2. Creates an Apple Distribution certificate from a key generated HERE (the private key never
     leaves this machine except inside the encrypted p12 repo secret). Shared with Neatly: ~/.neatly-signing/ (one team-wide Apple Distribution cert).
     Reused on later runs while valid; re-run after it expires (1 year) to rotate.
  3. (Re)creates the App Store provisioning profile "Ghostline AppStore CI" for that bundle + cert.
  4. --set-secrets: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64, IOS_DIST_P12_BASE64,
     IOS_DIST_P12_PASSWORD on Compo-CF/ghostline (values piped to gh over stdin, never printed).
"""
import base64, datetime, json, os, secrets, subprocess, sys, urllib.error, urllib.request
from pathlib import Path

ASC_DIR = Path.home() / "appstoreconnect"
sys.path.insert(0, str(ASC_DIR))
import asc_api  # noqa: E402  (make_token, KEY_ID, ISSUER_ID, KEY_PATH)

from cryptography import x509  # noqa: E402
from cryptography.hazmat.primitives import hashes, serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: E402
from cryptography.hazmat.primitives.serialization import pkcs12  # noqa: E402
from cryptography.x509.oid import NameOID  # noqa: E402

BUNDLE = "com.centricfiber.cosmica"
APP_NAME = "Cosmica"
PROFILE_NAME = "Cosmica AppStore CI"
REPO = "Compo-CF/cosmica"
# Cosmica has two signed targets; main() runs ensure_bundle/ensure_profile for each.
TARGETS = [("com.centricfiber.cosmica", "Cosmica", "Cosmica AppStore CI"),
           ("com.centricfiber.cosmica.widget", "Cosmica Widget", "Cosmica Widget AppStore CI")]
OUT = Path.home() / ".neatly-signing"
BASE = "https://api.appstoreconnect.apple.com"


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + asc_api.make_token(),
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            txt = r.read().decode()
            return json.loads(txt) if txt else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {path} -> HTTP {e.code}: {e.read().decode(errors='replace')[:600]}")


def ensure_bundle():
    got = call("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE}")["data"]
    got = [b for b in got if b["attributes"]["identifier"] == BUNDLE]
    if got:
        bid = got[0]["id"]
        print(f"bundle id: {BUNDLE} exists ({bid})")
    else:
        bid = call("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": BUNDLE, "name": APP_NAME, "platform": "IOS"}}})["data"]["id"]
        print(f"bundle id: registered {BUNDLE} ({bid})")
    caps = call("GET", f"/v1/bundleIds/{bid}/bundleIdCapabilities")["data"]
    have = {c["attributes"]["capabilityType"] for c in caps}
    if "IN_APP_PURCHASE" not in have and not BUNDLE.endswith(".widget"):   # widgets sell nothing
        try:
            call("POST", "/v1/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
                 "attributes": {"capabilityType": "IN_APP_PURCHASE"},
                 "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}}}}})
            print("bundle id: + IN_APP_PURCHASE")
        except RuntimeError as e:
            print(f"bundle id: IAP capability not added ({str(e)[:120]}); it is on by default for App IDs")
    return bid


def ensure_cert():
    OUT.mkdir(exist_ok=True)
    meta_p = OUT / "dist_cert.json"
    if meta_p.exists() and (OUT / "dist.p12").exists():
        meta = json.loads(meta_p.read_text())
        try:
            c = call("GET", f"/v1/certificates/{meta['id']}")["data"]["attributes"]
            exp = datetime.datetime.fromisoformat(c["expirationDate"].replace("Z", "+00:00"))
            if exp - datetime.datetime.now(datetime.timezone.utc) > datetime.timedelta(days=14):
                print(f"certificate: reusing {meta['id']} (expires {c['expirationDate'][:10]})")
                return meta["id"]
            print("certificate: expiring within 14 days, rotating")
        except RuntimeError:
            print("certificate: saved one no longer exists, creating a new one")
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Neatly CI"),
                                    x509.NameAttribute(NameOID.COUNTRY_NAME, "US")]))
           .sign(key, hashes.SHA256()))
    csr_b64 = base64.b64encode(csr.public_bytes(serialization.Encoding.DER)).decode()
    res = call("POST", "/v1/certificates", {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": csr_b64}}})["data"]
    cert = x509.load_der_x509_certificate(base64.b64decode(res["attributes"]["certificateContent"]))
    password = secrets.token_urlsafe(24)
    p12 = pkcs12.serialize_key_and_certificates(b"neatly-dist", key, cert, None,
                                                serialization.BestAvailableEncryption(password.encode()))
    (OUT / "dist.p12").write_bytes(p12)
    (OUT / "dist_password.txt").write_text(password)
    (OUT / "dist_key.pem").write_bytes(key.private_bytes(serialization.Encoding.PEM,
                                       serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    meta_p.write_text(json.dumps({"id": res["id"], "name": res["attributes"].get("name"),
                                  "expires": res["attributes"].get("expirationDate")}, indent=1))
    print(f"certificate: created {res['id']} {res['attributes'].get('name')} "
          f"(expires {str(res['attributes'].get('expirationDate'))[:10]}) -> {OUT}")
    return res["id"]


def ensure_profile(bid, cert_id):
    old = call("GET", f"/v1/profiles?filter[name]={urllib.request.quote(PROFILE_NAME)}")["data"]
    for p in old:
        call("DELETE", f"/v1/profiles/{p['id']}")
        print(f"profile: deleted old {p['id']}")
    res = call("POST", "/v1/profiles", {"data": {"type": "profiles",
        "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}},
                          "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})["data"]
    print(f"profile: created {res['id']} \"{PROFILE_NAME}\" uuid {res['attributes'].get('uuid')}")


def set_secrets():
    vals = {
        "ASC_KEY_ID": asc_api.KEY_ID,
        "ASC_ISSUER_ID": asc_api.ISSUER_ID,
        "ASC_KEY_P8_BASE64": base64.b64encode(Path(asc_api.KEY_PATH).read_bytes()).decode(),
        "IOS_DIST_P12_BASE64": base64.b64encode((OUT / "dist.p12").read_bytes()).decode(),
        "IOS_DIST_P12_PASSWORD": (OUT / "dist_password.txt").read_text().strip(),
    }
    for name, value in vals.items():
        subprocess.run(["gh", "secret", "set", name, "-R", REPO], input=value.encode(), check=True,
                       stdout=subprocess.DEVNULL)
        print(f"secret: {name} set on {REPO}")


if __name__ == "__main__":
    c = ensure_cert()
    for BUNDLE, APP_NAME, PROFILE_NAME in TARGETS:   # the functions read these module globals
        b = ensure_bundle()
        ensure_profile(b, c)
    if "--set-secrets" in sys.argv:
        set_secrets()
