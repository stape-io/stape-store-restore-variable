# Stape Store reStore Variable for Google Tag Manager Server Container

The **Stape Store reStore Variable** for Google Tag Manager Server-Side allows you to look up, restore, and update user profiles in **Stape Store** using a set of identifiers (e.g., `user_id`, `client_id`, email).

The variable looks up a user profile using the provided identifiers, restores stored data, and updates the profile with any new information. This is useful for:
- Cookieless and cross-domain tracking
- Cross-device user stitching
- Enriching event data with persistent user attributes

## How to use

1.  Add the **Stape Store reStore Variable** to your server container from the GTM Template Gallery.
2.  Add the **identifiers** you want to use for lookup (e.g., `user_id`, `email`).
3.  Specify the **data points** to manage.
4.  (Optional) Enable **Only restore data** to prevent writing updates to Stape Store.
5.  (Optional) Specify a **Stape Store Collection Name**. Defaults to `default`.
6.  Use this variable in your sGTM tags, triggers and variables to access the restored data object.

## Useful Resources
- [How to use the Stape Store reStore variable](https://stape.io/helpdesk/documentation/stape-store-feature#stape-store-re-store-variable)

## Open Source

The **Stape Store reStore Variable for GTM Server Side** is developed and maintained by [Stape Team](https://stape.io/) under the Apache 2.0 license.
