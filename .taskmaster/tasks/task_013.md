# Task ID: 13

**Title:** Create Phlex view components for the UI

**Status:** pending

**Dependencies:** 12

**Priority:** high

**Description:** Build all UI components using Phlex with Tailwind CSS (dp- prefix, .data-porter scope). Components: Layout, ImportsList, NewImportForm, ImportShow (with Preview table, Progress bar, Summary cards, Actions, Results, Failure alert).

**Details:**

Create Phlex components in lib/data_porter/components/ or app/views/data_porter/components/. All Tailwind classes use dp- prefix. Root wrapper uses .data-porter class for scoping. Components: ImportsList (table with status badges, links), NewImportForm (target select, source type, file upload, config fields), ImportShow (delegates to sub-components based on status), PreviewTable (dynamic columns from target, status icons, error display, row coloring by status), ProgressBar (Stimulus-connected, percentage display), SummaryCards (complete/partial/missing/duplicate counts), ActionButtons (cancel, confirm with count), ResultsSummary (created/errored counts), FailureAlert (error messages, retry button). Use CSS custom properties for theming: --dp-color-complete, --dp-color-partial, --dp-color-missing, --dp-color-primary.

**Test Strategy:**

Test each component renders correct HTML structure. Test conditional rendering based on import status. Test dynamic columns from target. Test CSS class prefixing.
