# Case Log

An iPhone case log for cardiac surgery. It records each operation with the patient's
PHI, post-op events and discharge, and makes a weekly discharge list as a PDF that you
share into your corporate Outlook.

This is **Phase 1**: everything stays on one iPhone. Phase 2 (sending the email from the
app via Microsoft Graph) and Phase 3 (Azure backup and sync) come later.

## Build and run

You need a Mac with Xcode 15 or later, and an iPhone on iOS 17 or later.

1. Install XcodeGen, which creates the Xcode project from `project.yml`:
   ```sh
   brew install xcodegen
   ```
2. In this folder, generate and open the project:
   ```sh
   xcodegen generate
   open CaseLog.xcodeproj
   ```
3. In Xcode, select the **CaseLog** target, open **Signing & Capabilities**, and pick your
   team. If the bundle id `com.jeffgibson.caselog` is taken, change it there.
4. Plug in your iPhone, select it as the run destination, and press **Run** (⌘R).
   The first time, iOS asks you to trust the developer under
   Settings > General > VPN & Device Management.
5. To run the tests, press ⌘U with an iOS simulator selected.

Run `xcodegen generate` again whenever files are added or `project.yml` changes.
The generated `CaseLog.xcodeproj` is not committed.

## What Phase 1 does

- **Cases:** first and last name, DOB (typed as MM/DD/YYYY), gender, surgery date
  (age is calculated), surgeon, referring provider, procedures. Name, DOB, gender,
  surgery date and at least one procedure are required before a case can be saved;
  none of them has a default.
- **Post-op events:** the STS-style categories and subcategories from the
  Tristar discharge spreadsheet, each with a date and a note. Each case must have
  either at least one event or **None** turned on.
- **Discharge:** date, destination (Home, SNF, Rehab, LTAC, Hospice, Another
  institution, Deceased) and notes.
- **Weekly discharge list:** pick a Monday-to-Sunday week, check the list, tap
  **Share PDF**, and choose Outlook. The PDF has the same columns as the spreadsheet's
  Discharge List sheet. Only complete records are included: every required field,
  post-op events answered, and a discharge date and destination. Discharged patients
  with incomplete records are listed separately on that screen, with what's missing.

## Changing the database later

The database layout is versioned (`CaseLog/Models/Schema.swift`). Any change to a stored
field needs a new schema version and a migration step, as described in that file, so
cases already on the phone are carried forward. Pick-list values (gender, discharge
destination) are stored as fixed codes: add new options freely, but never rename or
remove a code.

## HIPAA safeguards in this build

| Safeguard | How |
| --- | --- |
| Encryption at rest | Data Protection *Complete* on the database and the exported PDF; the app refuses to show PHI if the iPhone has no passcode |
| No cloud copies | The store is excluded from iCloud and computer backups, and CloudKit is off |
| Access control | Face ID / Touch ID / passcode on launch, and again after 2 minutes in the background (adjustable in Settings) |
| Screen privacy | A cover hides PHI in the app switcher |
| Audit log | Unlocks, views, creates, edits, deletes, restores and exports are logged on the device (Settings > Audit log). The log holds no PHI |
| Integrity | Deleted cases go to Recently Deleted for 30 days before they're purged |
| Export | The PDF file name and metadata hold no PHI; AirDrop, Messages, Apple Mail, Print, Copy and Save to Photos are removed from the share sheet; the file is deleted as soon as sharing ends |
| Third parties | No analytics, crash reporting or other SDKs |

Not yet done, and planned before wider use: blocking copy and paste of PHI, wiping after
repeated failed unlocks, and a written risk assessment. Deleting the app deletes all its
cases, since nothing is backed up until Phase 3.
