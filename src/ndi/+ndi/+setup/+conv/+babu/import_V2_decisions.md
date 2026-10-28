# `ndi.setup.conv.babu` V2 import — decision log

The running record of the choices for the Babu dataset's V2 (did_v2) import:
the per-dataset reimport whose meaning decisions are recorded here, as
opposed to the generic V1->V2 migration, which carries this dataset's v1
documents exactly as written. No `import_V2` exists for this dataset yet;
the v1 importer is `import.m` in this folder, left unchanged. The layout
follows the Haley import's log, `+haley/import_V2_decisions.md`.

Entries marked **DECIDED** were made by the dataset's owner or the team
(named, with the date); **OPEN** entries are questions still to answer.

Created by [Babu and Soph workbooks] (Jess Haley, 2026-10-27, did-schema
`V_eta_go_forward_class_audit.md`).

## Current rules

A summary of the rule in force today, by topic, read off the log below. The
log is the record: where this summary and a row disagree, the row wins.

### Image stacks

- No rule yet. The v1 video image stacks' time scale is an open item (#1).

### Unresolved

- #1: what the reimport writes for a video's time axis.

## Decisions

| # | Date | Decision | Status |
|---|---|---|---|
| 1 | 2026-10-27 | **A video's frame rate is written where frame spacing is meant.** v1 `import.m` (the imageStack loop) sets `dimScale3 = vidObj.FrameRate` with `dimUnit3 = ',second'` and writes `imageStack_parameters.dimension_scale` `[1,1,dimScale3]`, so the time axis's scale holds frames per second under the unit second, where the spacing (seconds per frame, 1/FrameRate) is meant. The generic V1->V2 migration carries the v1 values exactly as written (did-schema `V_eta_go_forward_class_audit.md` [importer bugs are dataset decisions], Jess Haley, 2026-10-27); what the reimport writes is this dataset's decision. | OPEN |
