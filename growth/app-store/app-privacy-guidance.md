# App Privacy Guidance

## Contact Info

- **Email Address** — Linked · Not Used to Track · Purpose: App Functionality
  - App uses role-based authentication (Admin/Site Manager/Tradesman) requiring user accounts.

## Identifiers

- **User ID** — Linked · Not Used to Track · Purpose: App Functionality
  - Role-based account system requires user identification to distinguish Admin, Site Manager, and Tradesman roles.

## Location

- **Precise Location** — Linked · Not Used to Track · Purpose: App Functionality
  - App uses geofenced clock-in/clock-out functionality via CLLocationManager for site attendance tracking.

## User Content

- **Photos or Videos** — Linked · Not Used to Track · Purpose: App Functionality
  - App accesses photo library via PHPickerViewController for capturing site photos, materials, and receipts.

## Usage Data

- **Product Interaction** — Not Linked · Not Used to Track · Purpose: Analytics
  - App integrates analytics service to track user interactions and feature usage.

## Diagnostics

- **Crash Data** — Not Linked · Not Used to Track · Purpose: Analytics
  - Analytics integration typically includes crash reporting for app stability monitoring.
