#!/usr/bin/env python3
"""Submit a build that is already in App Store Connect for App Store review.

The App Store counterpart of play_promote.py: the build deploy_ios.sh uploaded
(the one tested in TestFlight) is attached to an App Store version and sent to
review — through the App Store Connect API, with the same API key.

    asc_submit.py <bundle id> <X.Y.Z> <build number>
                  [--notes en="..." --notes sr="..."] [--notes-file notes.json]
                  [--manual-release] [--dry-run]

Steps: find the build and check Apple finished processing it; reuse the App
Store version that is still editable (renamed to X.Y.Z) or create it; attach
the build; set "What's New" on every localization of the version; submit.
--notes / --notes-file give the text by language and release_notes.py matches
it to each localization (a new version has those of the latest one), English
as the fallback. What's New is planned and checked before anything changes:
Apple refuses an update with an empty one. The version goes live as soon as it
is approved, or waits for "Release" in App Store Connect with --manual-release.
--dry-run only reads and prints the plan.

Credentials from the app's ios/deploy.env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
(the key needs the App Manager or Admin role).

Needs: pip3 install pyjwt cryptography requests
"""

import argparse
import os
import sys
import time

import jwt
import requests

import release_notes

API = "https://api.appstoreconnect.apple.com/v1"

# a version in one of these can still be edited and submitted
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY"}


def fail(message):
    print(f"asc_submit: {message}", file=sys.stderr)
    sys.exit(1)


class Api:
    def __init__(self, key_id, issuer, key_path):
        with open(key_path) as f:
            key = f.read()
        now = int(time.time())
        token = jwt.encode({"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
                           key, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {token}", "Content-Type": "application/json"})

    def call(self, method, path, **kwargs):
        response = self.session.request(method, f"{API}{path}", timeout=60, **kwargs)
        if response.status_code >= 400:
            try:
                errors = response.json()["errors"]
                detail = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors)
            except (ValueError, KeyError):
                detail = response.text[:500]
            fail(f"{method} {path} → {response.status_code}: {detail}")
        return response.json() if response.content else {}

    def get(self, path, **params):
        return self.call("GET", path, params=params)

    def post(self, path, data):
        return self.call("POST", path, json={"data": data})["data"]

    def patch(self, path, data):
        return self.call("PATCH", path, json={"data": data})


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("bundle_id", help="e.g. rs.antonijevic.birdTracker")
    parser.add_argument("version", help="App Store version string, X.Y.Z")
    parser.add_argument("build", help="build number (the +N of pubspec)")
    parser.add_argument("--notes", action="append", metavar="LANG=TEXT", help="What's New, repeatable")
    parser.add_argument("--notes-file", help="What's New as JSON: {\"en\": \"...\", \"de\": \"...\"}")
    parser.add_argument("--manual-release", action="store_true", help="wait for a manual release after approval")
    parser.add_argument("--dry-run", action="store_true", help="read only, print the plan")
    args = parser.parse_args()

    for var in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"):
        if not os.environ.get(var):
            fail(f"{var} is not set (source the app's ios/deploy.env)")
    if not os.path.isfile(os.environ["ASC_KEY_PATH"]):
        fail(f"API key not found: {os.environ['ASC_KEY_PATH']}")
    notes = release_notes.load(args.notes, args.notes_file, fail)
    api = Api(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"])
    dry = "(dry run) " if args.dry_run else ""

    apps = api.get("/apps", **{"filter[bundleId]": args.bundle_id})["data"]
    if not apps:
        fail(f"no app with bundle id {args.bundle_id} in App Store Connect")
    app = apps[0]
    print(f"==> {app['attributes']['name']} ({args.bundle_id})")

    builds = api.get("/builds", **{"filter[app]": app["id"], "filter[version]": args.build,
                                   "filter[preReleaseVersion.version]": args.version})["data"]
    if not builds:
        fail(f"build {args.version} ({args.build}) is not in App Store Connect — was it uploaded?")
    build = builds[0]
    state = build["attributes"]["processingState"]
    expired = build["attributes"].get("expired")
    if state != "VALID" or expired:
        fail(f"build {args.version} ({args.build}) is {state}{' and expired' if expired else ''}"
             " — wait until Apple finishes processing it")
    print(f"    build {args.version} ({args.build}): processed")

    versions = api.get(f"/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "IOS", "limit": 20})["data"]
    same = next((v for v in versions if v["attributes"]["versionString"] == args.version), None)
    if same and same["attributes"]["appStoreState"] not in EDITABLE:
        fail(f"version {args.version} is already {same['attributes']['appStoreState']} — nothing to submit")
    editable = same or next((v for v in versions if v["attributes"]["appStoreState"] in EDITABLE), None)
    first_release = not any(v["attributes"]["appStoreState"] == "READY_FOR_SALE" for v in versions)
    release_type = "MANUAL" if args.manual_release else "AFTER_APPROVAL"

    # What's New is planned, and checked, before anything in App Store Connect
    # changes. It is not allowed on an app's first version and required on every
    # later one; a new version copies its localizations from the latest one.
    whats_new = {}
    if first_release:
        print("    first release of the app: no What's New")
    else:
        source = editable or versions[0]
        for loc in api.get(f"/appStoreVersions/{source['id']}/appStoreVersionLocalizations")["data"]:
            locale = loc["attributes"]["locale"]
            text, used = release_notes.match(notes, locale)
            if text is not None:
                whats_new[locale] = text
                print(f"    {dry}What's New [{locale}] ← {used}: {release_notes.preview(text)}")
            elif editable is not None and loc["attributes"].get("whatsNew"):
                print(f"    What's New [{locale}]: kept")
            else:
                fail(f"What's New is missing for {locale}: pass --notes en=... "
                     f"(or {locale.split('-')[0].lower()}=...)")

    if editable is None:
        print(f"    {dry}create version {args.version}")
        version = None if args.dry_run else api.post("/appStoreVersions", {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": args.version, "releaseType": release_type},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}},
        })
    else:
        old = editable["attributes"]["versionString"]
        rename = "" if old == args.version else f", renamed from {old}"
        print(f"    {dry}reuse version {args.version} ({editable['attributes']['appStoreState']}{rename})")
        version = editable
        if not args.dry_run:
            api.patch(f"/appStoreVersions/{version['id']}", {
                "type": "appStoreVersions", "id": version["id"],
                "attributes": {"versionString": args.version, "releaseType": release_type},
            })

    print(f"    {dry}attach build {args.build}; release {'manually' if args.manual_release else 'on approval'}")
    if version is not None and not args.dry_run:
        api.patch(f"/appStoreVersions/{version['id']}/relationships/build",
                  {"type": "builds", "id": build["id"]})

    if not first_release and version is not None and not args.dry_run:
        for loc in api.get(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]:
            locale = loc["attributes"]["locale"]
            text = whats_new.get(locale) or release_notes.match(notes, locale)[0]
            if text:
                api.patch(f"/appStoreVersionLocalizations/{loc['id']}", {
                    "type": "appStoreVersionLocalizations", "id": loc["id"],
                    "attributes": {"whatsNew": text},
                })
            elif not loc["attributes"].get("whatsNew"):
                fail(f"What's New is missing for {locale} — the version is prepared but not submitted; "
                     f"rerun with --notes {locale.split('-')[0].lower()}=...")

    if args.dry_run:
        print("✓ dry run: nothing was changed; without --dry-run the version is submitted for review")
        return

    existing = api.get("/reviewSubmissions", **{"filter[app]": app["id"], "filter[platform]": "IOS",
                                                 "filter[state]": "READY_FOR_REVIEW"})["data"]
    submission = existing[0] if existing else api.post("/reviewSubmissions", {
        "type": "reviewSubmissions",
        "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}},
    })
    api.post("/reviewSubmissionItems", {
        "type": "reviewSubmissionItems",
        "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}},
        },
    })
    api.patch(f"/reviewSubmissions/{submission['id']}", {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True},
    })
    print(f"✓ {args.version} ({args.build}) submitted for App Store review; "
          f"{'release it by hand once approved' if args.manual_release else 'it goes live once approved'}")


if __name__ == "__main__":
    main()
