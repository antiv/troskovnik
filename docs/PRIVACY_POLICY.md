# Privacy Policy — Troškovnik

**Last updated:** 4 June 2026

This Privacy Policy explains how the **Troškovnik** mobile application
("the App", "we", "us") handles your information. The App is published by
**Ant Biocode** (Belgrade, Serbia). For any questions, contact us at
**iantonijevic@gmail.com**.

## Summary

Troškovnik is designed to be **privacy-first**:

- **All your data stays on your device.** We do not operate any server and we
  do not collect, transmit, sell, or share your personal data.
- The local database is **encrypted** on your device (SQLCipher / AES-256).
- The only network connection the App makes is **directly to the official
  Serbian Tax Administration portal** (`suf.purs.gov.rs`) to retrieve the
  details of a receipt you scan — exactly as your web browser would.
- The App contains **no advertising, analytics, or third-party tracking SDKs**.

## What data the App processes

The App processes the following information **locally on your device**:

- **Fiscal receipt data** retrieved from the Tax Administration portal:
  merchant name and tax ID (PIB), location, date/time, invoice and PFR numbers,
  total amount, tax breakdown, payment method, and line items.
- **Verification URL / token** scanned from the receipt QR code, kept as proof
  and to refresh receipt items.
- **Warranty information you enter:** title, purchase date, duration, notes.
- **Photos you choose to attach** as warranty/receipt proof (taken with the
  camera). These images are stored only in the App's private storage.
- **Your preferences** (selected language, "business/personal" flags, notes).

We do **not** collect your name, email, contacts, location (GPS), advertising
identifiers, or any account credentials. The App has **no user accounts**.

## Where your data is stored

All data is stored **exclusively on your device** in a local database that is
**encrypted using SQLCipher (AES-256)**. The encryption key is generated on
first launch and kept in the device's secure storage (Android Keystore /
iOS Keychain). We have no access to your data and we keep no copy of it.

If you uninstall the App, this local data is removed by the operating system.
We do not provide cloud backup; any device backup is governed by your device/OS
settings, not by us.

## Network access

The App connects to the internet **only** to:

- Open the official receipt verification page at **`https://suf.purs.gov.rs`**
  in order to fetch and display the receipt you scanned, and to refresh items
  that are not yet available on the Tax Administration server.

This request goes directly from your device to the Tax Administration. We do
not route it through, log it on, or store it on any server of ours, because we
operate no server. Use of the Tax Administration portal is subject to that
institution's own terms and privacy practices.

## Permissions

- **Camera** — used solely to scan the QR code on a fiscal receipt and to take
  optional proof photos. Images are not uploaded anywhere.
- **Internet / Network state** — used solely to contact `suf.purs.gov.rs` as
  described above and to detect connectivity for retrying.

## Local notifications

The App schedules **local notifications** on your device to remind you before a
warranty expires. These are generated and shown entirely on-device; no
notification data leaves your device and no push/cloud messaging is used.

## Sharing

When you tap "Share" on a proof image, the image is handed to the system share
sheet so **you** can send it via an app of your choice. We do not control or
receive a copy of anything you share.

## Third parties

The App does not include advertising networks, analytics, crash-reporting, or
other third-party data-collection SDKs. Distribution is via Google Play, whose
own privacy terms apply to the download and update process.

## Children

The App is not directed at children and does not knowingly collect any data
from children.

## Data security

Your data is protected by on-device encryption (SQLCipher / AES-256) and the
platform's secure key storage. However, no method of electronic storage is
100% secure; you are responsible for the physical and access security of your
device.

## Your rights

Because all data is local and under your control, you can at any time:

- view, edit, or delete individual receipts and warranties within the App;
- remove all data by uninstalling the App.

We hold no copy of your data, so there is nothing for us to export or delete on
our side.

## Changes to this policy

We may update this Privacy Policy. Material changes will be reflected by the
"Last updated" date above and, where appropriate, communicated within the App
or the Google Play listing.

## Contact

**Ant Biocode**
Email: **iantonijevic@gmail.com**
