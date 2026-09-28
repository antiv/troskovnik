#!/usr/bin/env python3
"""Promote a release that is already on a Google Play track to another track.

The production counterpart of play_upload.py: nothing is uploaded, the version
code that tested fine on the internal track is put on production as is — one
Play Developer API edit: open, read the source track, update the target, commit.

    play_promote.py <package> <versionCode> [--from internal] [--to production]
                    [--rollout 0.2] [--notes en="..." --notes sr="..."] [--notes-file notes.json]
                    [--key sa.json] [--dry-run]

--rollout below 1 is a staged rollout (status inProgress); omitted, the release
goes to everyone. --notes / --notes-file set "What's new" by language (see
release_notes.py): every language of the app's store listing gets its note, or
the English one as a fallback; without notes, the ones the release already has
on the source track are carried over.
--dry-run opens the edit, applies it, has Play validate it and throws it away.

The service account needs "Release apps to production" in Play Console →
Users and permissions, on top of the testing-track permission play_upload.py
needs. Production changes go to Google's review before they are live.

Needs: pip3 install google-api-python-client google-auth
"""

import argparse
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

import release_notes

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def fail(message):
    print(f"play_promote: {message}", file=sys.stderr)
    sys.exit(1)


def api_message(error):
    try:
        return json.loads(error.content)["error"]["message"]
    except (ValueError, KeyError, TypeError):
        return str(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("package", help="applicationId, e.g. rs.antonijevic.bird_tracker")
    parser.add_argument("version_code", help="the versionCode to promote, e.g. 34")
    parser.add_argument("--from", dest="source", default="internal", help="source track (default: internal)")
    parser.add_argument("--to", dest="target", default="production", help="target track (default: production)")
    parser.add_argument("--rollout", type=float, help="staged rollout fraction, 0 < f < 1")
    parser.add_argument("--notes", action="append", metavar="LANG=TEXT", help="release notes, repeatable")
    parser.add_argument("--notes-file", help="release notes as JSON: {\"en\": \"...\", \"de\": \"...\"}")
    parser.add_argument("--key", default=os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"),
                        help="service account JSON key (default: $PLAY_SERVICE_ACCOUNT_JSON)")
    parser.add_argument("--dry-run", action="store_true", help="validate the edit, then discard it")
    args = parser.parse_args()

    if not args.key or not os.path.isfile(args.key):
        fail(f"service account key not found: {args.key}")
    if args.rollout is not None and not 0 < args.rollout < 1:
        fail("--rollout must be between 0 and 1 (omit it for a full release)")
    notes = release_notes.load(args.notes, args.notes_file, fail)
    code = str(args.version_code)
    package = args.package

    credentials = service_account.Credentials.from_service_account_file(args.key, scopes=SCOPES)
    edits = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False).edits()

    try:
        edit_id = edits.insert(packageName=package, body={}).execute()["id"]
        try:
            source = edits.tracks().get(packageName=package, editId=edit_id, track=args.source).execute()
            release = next((r for r in source.get("releases", []) if code in r.get("versionCodes", [])), None)
            if release is None:
                on_track = [c for r in source.get("releases", []) for c in r.get("versionCodes", [])]
                fail(f"versionCode {code} is not on the '{args.source}' track of {package} "
                     f"(it has: {', '.join(on_track) or 'nothing'})")

            target_release = {"versionCodes": [code], "status": "completed"}
            if release.get("name"):
                target_release["name"] = release["name"]
            if args.rollout is not None:
                target_release.update(status="inProgress", userFraction=args.rollout)
            if notes:
                listings = edits.listings().list(packageName=package, editId=edit_id).execute()
                target_release["releaseNotes"] = []
                for language in [l["language"] for l in listings.get("listings", [])]:
                    text, used = release_notes.match(notes, language)
                    if text is None:
                        print(f"    notes [{language}]: none — no {language} or English note given")
                        continue
                    print(f"    notes [{language}] ← {used}: {release_notes.preview(text)}")
                    target_release["releaseNotes"].append({"language": language, "text": text})

                # Play shows release notes in the device language even with no store
                # listing in it (Serbian notes on an English-only listing), so a note
                # no listing took goes out under Play's code for its language
                covered = {n["language"].split("-")[0].lower() for n in target_release["releaseNotes"]}
                for key, text in notes.items():
                    language = release_notes.play_language(key)
                    if language.split("-")[0].lower() in covered:
                        continue
                    covered.add(language.split("-")[0].lower())
                    print(f"    notes [{language}] ← {key} (no listing in it): {release_notes.preview(text)}")
                    target_release["releaseNotes"].append({"language": language, "text": text})
            elif release.get("releaseNotes"):
                target_release["releaseNotes"] = release["releaseNotes"]

            edits.tracks().update(
                packageName=package, editId=edit_id, track=args.target,
                body={"track": args.target, "releases": [target_release]},
            ).execute()

            languages = ", ".join(n["language"] for n in target_release.get("releaseNotes", [])) or "none"
            share = f"{args.rollout:.0%} staged rollout" if args.rollout is not None else "full rollout"
            summary = f"versionCode {code} → '{args.target}' of {package} ({share}; release notes: {languages})"

            if args.dry_run:
                edits.validate(packageName=package, editId=edit_id).execute()
                print(f"✓ dry run, Play accepted: {summary}")
                return
            edits.commit(packageName=package, editId=edit_id).execute()
            edit_id = None
            print(f"✓ {summary}")
            print("  Google reviews production changes; the release goes live once approved.")
        finally:
            if edit_id is not None:
                edits.delete(packageName=package, editId=edit_id).execute()
    except HttpError as error:
        fail(f"Play API {error.resp.status}: {api_message(error)}")


if __name__ == "__main__":
    main()
