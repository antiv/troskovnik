#!/usr/bin/env python3
"""Upload an Android App Bundle to a Google Play track.

The Android counterpart of the altool step in deploy_ios.sh: one Play Developer
API "edit" — open, upload the bundle, put its version code on the track, commit.
Shared deploy helper; deploy.sh --upload calls it.

    play_upload.py <bundle.aab> <package name> [--track internal] [--key sa.json]

Credentials are a service account JSON key (PLAY_SERVICE_ACCOUNT_JSON or --key)
that Play Console → Users and permissions granted "Release to testing tracks"
for the app. The API cannot make an app's *first* upload — Play insists that one
goes through the console by hand.

Needs: pip3 install google-api-python-client google-auth
"""

import argparse
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def fail(message):
    print(f"play_upload: {message}", file=sys.stderr)
    sys.exit(1)


def api_message(error):
    """The human-readable part of a Play API error, if the body carries one."""
    try:
        return json.loads(error.content)["error"]["message"]
    except (ValueError, KeyError, TypeError):
        return str(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("aab", help="the App Bundle to upload")
    parser.add_argument("package", help="applicationId, e.g. rs.antonijevic.troskovnik")
    parser.add_argument("--track", default="internal",
                        help="internal | alpha | beta | production (default: internal)")
    parser.add_argument("--key", default=os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"),
                        help="service account JSON key (default: $PLAY_SERVICE_ACCOUNT_JSON)")
    args = parser.parse_args()

    if not args.key:
        fail("no service account key: set PLAY_SERVICE_ACCOUNT_JSON or pass --key")
    if not os.path.isfile(args.key):
        fail(f"service account key not found: {args.key}")
    if not os.path.isfile(args.aab):
        fail(f"bundle not found: {args.aab}")

    credentials = service_account.Credentials.from_service_account_file(args.key, scopes=SCOPES)
    edits = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False).edits()
    package = args.package

    try:
        edit_id = edits.insert(packageName=package, body={}).execute()["id"]

        print(f"==> uploading {args.aab} ({os.path.getsize(args.aab) / 1e6:.1f} MB)")
        media = MediaFileUpload(args.aab, mimetype="application/octet-stream", resumable=True)
        bundle = edits.bundles().upload(packageName=package, editId=edit_id, media_body=media).execute()
        version_code = bundle["versionCode"]

        edits.tracks().update(
            packageName=package, editId=edit_id, track=args.track,
            body={"track": args.track,
                  "releases": [{"versionCodes": [str(version_code)], "status": "completed"}]},
        ).execute()

        # A pending, unrelated console change makes Play refuse to auto-submit the
        # edit for review; the testing tracks do not need one, so commit without it.
        try:
            edits.commit(packageName=package, editId=edit_id).execute()
        except HttpError as error:
            if "changesNotSentForReview" not in api_message(error):
                raise
            edits.commit(packageName=package, editId=edit_id, changesNotSentForReview=True).execute()
    except HttpError as error:
        fail(f"Play API {error.resp.status}: {api_message(error)}")

    print(f"✓ versionCode {version_code} is on the '{args.track}' track of {package}")


if __name__ == "__main__":
    main()

