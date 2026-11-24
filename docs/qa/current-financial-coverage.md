# Financial regression coverage — 2026-11-24

The current review ran 74 app cases and 78 API-layer cases successfully before
cleanup. Eighteen old placeholders were skipped, plus one optional screenshot
capture. The screenshot capture stays optional. Seventeen historical placeholders
were removed because they did not execute assertions; the nextBefore case is now
active and exposed a real pagination defect. Screenshot capture and tests that
require a Tripoli-configured runtime timezone remain conditional. This is not additional coverage or
proof of live financial parity. Existing executed cases below retain the checks.

| Subject of the historical placeholder | Current executed evidence / boundary |
| --- | --- |
| Whole money, invalid values and formatting | `test/money_display_test.dart`, `test/def036_invalid_money_test.dart`, API `test/money_formatter_test.dart`, `test/def036_invalid_money_test.dart` |
| Partial/full payments and cached totals | `test/acceptance/phase8/phase8_reconciliation_test.dart`, `test/ledger_running_balance_test.dart`; server arithmetic is verified in the website repository, not inferred from the fake |
| Summary versus trimmed cards | Phase 8's executed trimmed-window case and `test/customers_summary_total_only_test.dart`; no client sum replaces a server total |
| Overpayment | `test/def031_overpayment_warning_test.dart`, API `test/def031_ack_balance_test.dart`; warning permits an explicitly confirmed operation; server decides the final balance |
| Purchase carried balance | `test/purchase_running_balance_test.dart`, `test/purchase_preview_test.dart`, API `test/purchases_contract_test.dart` |
| Collection DTOs without versions and decisions | API `test/p03_collections_contract_test.dart`, `test/collection_cancel_approval_test.dart` |
| Unlinked receipts and Egyptian accounts | `test/egyptian_link_pause_test.dart`, `test/def035_egyptian_link_test.dart`; the website enforces LYD-only receipts and rejects a currency mismatch |
| Payroll names / notification section keys | API `test/p03_collections_contract_test.dart`, `test/notification_model_test.dart`, `test/employee_totals_test.dart` |
| Permissions without sectionAccess | API `test/p08_permissions_test.dart`, `test/employee_permission_negative_test.dart` |
| MFA mapping | App `test/mfa_login_test.dart`, API `test/error_catalog_test.dart` |
| Serialized CSRF refresh | API `test/p10_csrf_write_queue_test.dart`, `test/csrf_replay_scope_test.dart` |
| Treasury nextBefore | Active `test/contract/site_contract_test.dart` regression plus `test/paged_cursor_test.dart`; null/empty end cursors must stop pagination |

## Evidence limits retained explicitly

- Historical `docs/api/evidence/api-samples.json` and `openapi.json` are snapshots,
  not a complete declaration of the current server. Their five optional/missing
  path notes do not establish an outage of those paths today. Keep the snapshot
  assertions labelled as historical; refreshing the contract needs generated
  current server evidence, not invented response samples.
- `checkDuplicate` / `allowDuplicate` on the generic account request are not
  implemented by the DTO. Removing its non-executing placeholder does not add
  that feature or change the payment flow.
- Mobile fake submission retries do not prove the server's exactly-once rule.
  That rule is tested by `tests/collection-idempotency.test.ts` and the partial
  receipt recovery UI tests in the website repository. No financial write is
  automatically retried by the mobile mutation transport.
- A local read-only financial reconciliation checked the installed website DB:
  16,495 checks, zero mismatches/warnings. It excludes payroll and historical
  report snapshots and does not certify every installed phone's display.
- No financial formula, rounding policy, approval rule or currency decision was
  changed by this cleanup.
