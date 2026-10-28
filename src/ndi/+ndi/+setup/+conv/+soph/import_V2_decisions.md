# Soph dataset V2 import — decision log

The running record of the choices for the Soph dataset's V2 (did_v2) import:
the per-dataset reimport whose meaning decisions are recorded here, as
opposed to the generic V1->V2 migration, which carries this dataset's v1
documents exactly as written. NDI-matlab holds no importer for this dataset
(no `+setup/+conv` folder existed before this one); its v1 documents are the
Soph corpus that `TestMigrateLocalEtaSoph` migrates. The layout follows the
Haley import's log, `+haley/import_V2_decisions.md`.

Entries marked **DECIDED** were made by the dataset's owner or the team
(named, with the date); **OPEN** entries are questions still to answer.

Created by [Babu and Soph workbooks] (Jess Haley, 2026-10-27, did-schema
`V_eta_go_forward_class_audit.md`).

## Current rules

A summary of the rule in force today, by topic, read off the log below. The
log is the record: where this summary and a row disagree, the row wins.

### Tuning curves

- No rule yet. The contrast tuning curves' recorded spatial frequency is an
  open item (#1).

### Unresolved

- #1: what the reimport records as the contrast tuning curves' spatial
  frequency.

## Decisions

| # | Date | Decision | Status |
|---|---|---|---|
| 1 | 2026-10-27 | **Every contrast tuning curve records spatial frequency 0.04.** All 22,896 v1 contrast tuning curves in the corpus record a spatial frequency of 0.04, from an NDI writer bug fixed later (as stated in Claude's proposal 16f, which Jess Haley accepted). The generic V1->V2 migration carries the recorded value unchanged (did-schema `V_eta_go_forward_class_audit.md` [contrast SF bug is a dataset decision], Jess Haley, 2026-10-27); what the reimport records is this dataset's decision. | OPEN |
