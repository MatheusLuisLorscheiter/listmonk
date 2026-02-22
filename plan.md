# Plan: Add Per‑List Default SMTP Configuration

**TL;DR**  
We’ll extend lists with a new `default_messenger` field (email‑only) so admins can pick a preferred SMTP messenger. Automatic messages (opt‑in confirmations, etc.) will use that setting; campaign creation from a list will pre‑select the matching messenger when there’s no conflict. Unspecified or invalid defaults fall back to the global `"email"` messenger. Work touches DB migrations, models, core logic, HTTP handlers, front‑end forms/pages, and the opt‑in notification hook.

---

### Steps

1.  **Database migration**
    - Add `default_messenger TEXT NULL` to `lists` in [schema.sql](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) and create a new SQL migration under [queries](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) (e.g. `lists_add_default_messenger.sql`).
    - Update any index or constraint if necessary (probably none).
2.  **Go model & queries**
    - Add `DefaultMessenger string` field to `models.List` (models/lists.go).
    - Update relevant SQL in `queries/*.sql`:
        - `lists.sql` queries: `get-lists`, `get-list`, `create-list`, `update-list`, `query-lists`.
    - Adjust [lists.go](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) methods (`CreateList`, `UpdateList`, `GetList`, `QueryLists`) to read/write the field and validate (must be empty or in allowed messengers list).
3.  **Server configuration & validation**
    - Reuse logic from settings handler to validate messenger names; restrict to names starting with `"email"` (same filter as front‑end).
    - Add helper in [settings.go](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) or a new util to validate a messenger exists in `serverConfig.Messengers`.
4.  **HTTP handlers**
    - Update request struct in [lists.go](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) (listCreate, listUpdate) to include `DefaultMessenger`.
    - Bind and validate the field on POST/PUT; respond with 400 on invalid value.
    - Ensure `GET /api/lists` returns the new field.
5.  **Front‑end UI**
    - In `ListForm.vue`: add a `<b-select>` input for default messenger.
        - Populate options from `serverConfig.emailMessengers` (filter on frontend).
        - Allow blank/none.
    - Modify lists listing (`Lists.vue`) to display the value in table or details.
    - In `Campaign.vue`:
        - Watch `selectedLists`; when changed compute the default messenger:
            - If exactly one list selected or all selected lists share the same non-empty default, set `form.messenger` to that value.
            - If they differ or are unset, leave `form.messenger` untouched (clear selection).
        - Display a subtle notice if mixed defaults blocked auto‑select.
    - Update any API helper type definitions to include the new field and ensure swagger spec is refreshed ([collections.yaml](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) etc.).
6.  **Automatic email routing**
    - Update `makeOptinNotifyHook` in [subscribers.go](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html):
        - When iterating `lists` on subscription, fetch each list’s `DefaultMessenger`.
        - Choose messenger: list default if non‑empty and valid; else global `"email"`.
        - Pass messenger to `notifs.Notify` (extend signature to accept messenger string).
    - Modify `notifs` package to support specifying messenger per message; fallback to existing behaviour when argument is empty.
    - Add helper `getListDefaultMessenger(listID int) string` or inline logic.
    - Add unit tests for opt‑in hook behaviour with different list defaults.
7.  **Campaign creation default logic**
    - (Frontend step above) ensure backend `core/campaigns.go` doesn’t need change – the default messenger is a frontend convenience only.
8.  **Error handling & robustness**
    - When SMTP settings change (rename/remove) ensure lists with now-invalid defaults either:
        - Clear the invalid value on settings update (check each list? maybe too heavy).
        - Or show a warning in the list form if selected value is no longer available; prevent saving invalid value.
    - Implement validation in list handlers to catch invalid names.
    - Consider a periodic background job? Probably not required for first iteration.
9.  **Documentation & tests**
    - Update docs under [docs](vscode-file://vscode-app/c:/Users/Mathe/AppData/Local/Programs/Microsoft%20VS%20Code/072586267e/resources/app/out/vs/code/electron-browser/workbench/workbench.html) explaining the new field and behaviour.
    - Add or extend existing Go tests (`internal/core/lists_test.go`, `cmd/subscribers_test.go`) and frontend tests (Cypress e2e for list form, campaign creation scenario).
    - Update swagger definitions if used for API docs.
10. **Migration/testing**
    - Add a migration helper or instructions in README.
    - Verify existing lists continue working no change.
    - Test case: create list with default, subscribe, send opt‑in, campaign seeded with correct messenger, modify SMTP settings and observe warnings.

---

### Verification

- Run `go test [Projetos Concluídos](http://_vscodecontentref_/8).` and ensure new tests pass.
- Use frontend `npm run dev` and:
    1.  Create/modify list, select default messenger.
    2.  Attempt to save invalid messenger (absent in config) – expect validation.
    3.  Create campaigns via list link (`?list_id=…`) and check messenger pre‑selection.
    4.  Subscribe to list and inspect opt‑in message’s messenger (via logs or mocking `manager.Messenger`).
    5.  Change SMTP config (add/remove) and watch UI warnings.
- Ensure swagger docs include `default_messenger` field.

---

### Decisions

- **Allowed messengers:** only those prefixed with `email` (email‑only).
- **Campaign multi‑list logic:** auto‑select only when all selected lists share the same default; otherwise leave blank.
- **Fallback for missing/removed default:** revert to global `"email"` messenger.

> With this plan in hand, the implementation can proceed confidently across backend, frontend, and migrations, ensuring a consistent new feature and minimal regression.