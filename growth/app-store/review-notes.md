# Review Notes

- This app is for authorised subcontractors and staff of My Project Group Ltd only. Account creation is not open to the public; access requires credentials issued by the company.
- A demo tradesman account and a demo admin account are available for review — see the demo account checklist below.
- The app uses location only when the user actively clocks in, clocks out, or uploads site evidence. There is no background location tracking.
- Camera and photo library permissions are used to capture and attach site photos and supplier receipts to job records.
- GPS geofencing is used to confirm the user is near the allocated job site at clock-in and clock-out.
- The Apple Sign In entitlement is present as an additional authentication option alongside Supabase Auth email/password login.
- Associated Domains entitlement supports universal links to deep-link into specific job or invoice records.
