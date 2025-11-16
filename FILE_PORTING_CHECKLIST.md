# NDI-Python File Porting Checklist

**Track progress porting MATLAB files to Python**

Legend:
- ⬜ Not started
- 🟨 In progress
- ✅ Complete
- ⏭️ Skipped (not needed in Python)
- 🔄 Needs revision

---

## Phase 1: Core Classes (25 methods)

### Session Class Methods

| Status | Method | MATLAB Lines | Python Lines | Effort | Assignee | Notes |
|--------|--------|--------------|--------------|--------|----------|-------|
| ✅ | `__init__` | 18-39 | 27-40 | - | Done | Complete |
| ✅ | `id()` | 41-49 | 42-49 | - | Done | Complete |
| ✅ | `newdocument()` | 197-217 | 51-63 | - | Done | Complete |
| ✅ | `searchquery()` | 219-234 | 65-73 | - | Done | Complete |
| ✅ | `database_add()` | 236-267 | 75-99 | - | Done | Complete |
| ✅ | `database_search()` | 314-343 | 101-114 | - | Done | Complete |
| ✅ | `database_rm()` | 269-312 | 116-127 | - | Done | Complete |
| ✅ | `database_openbinarydoc()` | 381-414 | 145-168 | - | Done | Complete |
| ✅ | `database_closebinarydoc()` | 428-446 | 170-182 | - | Done | Complete |
| ✅ | `daqsystem_add()` | 72-104 | 184-208 | - | Done | Complete |
| ✅ | `daqsystem_load()` | 137-174 | 210-242 | - | Done | Complete |
| ✅ | `getprobes()` | 615-711 | 244-262 | - | Done | Complete |
| ✅ | `getelements()` | 713-743 | 264-280 | - | Done | Complete |
| ⬜ | `daqsystem_rm()` | 106-135 | TBD | 1h | - | **TODO** |
| ⬜ | `daqsystem_clear()` | 176-195 | TBD | 1h | - | **TODO** |
| ⬜ | `validate_documents()` | 345-379 | TBD | 2h | - | **TODO** - Needs validate module |
| ⬜ | `database_existbinarydoc()` | 416-426 | TBD | 1h | - | **TODO** |
| ⬜ | `syncgraph_addrule()` | 448-458 | TBD | 1h | - | **TODO** |
| ⬜ | `syncgraph_rmrule()` | 460-470 | TBD | 1h | - | **TODO** |
| ⬜ | `ingest()` | 472-502 | TBD | 6h | - | **TODO** - Complex |
| ⬜ | `get_ingested_docs()` | 504-519 | TBD | 1h | - | **TODO** |
| ⬜ | `is_fully_ingested()` | 521-549 | TBD | 2h | - | **TODO** |
| ⬜ | `findexpobj()` | 570-613 | TBD | 2h | - | **TODO** |
| ⬜ | `creator_args()` | 758-775 | TBD | 1h | - | **TODO** |
| ⬜ | `docinput2docs()` (static) | 839-896 | TBD | 2h | - | **TODO** |
| ⬜ | `all_docs_in_session()` (static) | 898-927 | TBD | 1h | - | **TODO** |

**Session Progress**: 13/26 methods (50%)

### Document Class Methods

| Status | Method | MATLAB Lines | Python Lines | Effort | Assignee | Notes |
|--------|--------|--------------|--------------|--------|----------|-------|
| ✅ | `__init__` | - | - | - | Done | Complete |
| ✅ | `id()` | - | - | - | Done | Complete |
| ✅ | `set_session_id()` | - | - | - | Done | Complete |
| ✅ | `doc_class()` | - | - | - | Done | Complete |
| ✅ | `dependency_value()` | - | - | - | Done | Complete |
| ✅ | `add_file()` | - | - | - | Done | Basic version |
| ✅ | `__eq__()` | - | - | - | Done | Complete |
| ✅ | `__add__()` (merge) | - | - | - | Done | Complete |
| ⬜ | `add_dependency_value_n()` | TBD | TBD | 1h | - | **TODO** |
| ⬜ | `dependency_value_n()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `to_table()` | TBD | TBD | 2h | - | **TODO** - Returns DataFrame |
| ⬜ | `has_files()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `remove_file()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `reset_file_info()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `is_in_file_list()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `get_fuid()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `current_file_list()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `remove_dependency_value_n()` | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `setproperties()` | TBD | TBD | 1h | - | **TODO** |
| ⬜ | `validate()` | TBD | TBD | 1h | - | **TODO** - Needs validate module |
| ⬜ | `find_doc_by_id()` (static) | TBD | TBD | 30m | - | **TODO** |
| ⬜ | `find_newest()` (static) | TBD | TBD | 30m | - | **TODO** |

**Document Progress**: 8/20 methods (40%)

**Phase 1 Total Progress**: 21/46 methods (46%)

---

## Phase 2: Database Backends (96 files)

### Core Database Implementations

| Status | File | MATLAB Source | Effort | Assignee | Notes |
|--------|------|---------------|--------|----------|-------|
| ✅ | `database.py` | `database.m` | - | Done | Abstract base |
| ✅ | `DirectoryDatabase` | `database.m` | - | Done | File-based impl |
| ⬜ | `sqlite.py` | `didsqlite.m` | 20h | - | **TODO** - High priority |
| ⬜ | `matlabdumbjsondb.py` | `matlabdumbjsondb.m` | 15h | - | **TODO** |
| ⬜ | `matlabdumbjsondb2.py` | `matlabdumbjsondb2.m` | 15h | - | **TODO** |
| ⬜ | `binarydoc.py` | `binarydoc.m` | 4h | - | **TODO** - Binary doc handling |

### Database Utilities (Top 20)

| Status | File | MATLAB Source | Effort | Priority | Notes |
|--------|------|---------------|--------|----------|-------|
| ⬜ | `docs_from_ids.py` | `docs2docs.m` | 2h | P1 | Batch retrieval |
| ⬜ | `findalldependencies.py` | `findalldependencies.m` | 3h | P1 | Forward deps |
| ⬜ | `findallantecedents.py` | `findallantecedents.m` | 3h | P1 | Backward deps |
| ⬜ | `docs2graph.py` | `docs2graph.m` | 4h | P1 | Dependency graph |
| ⬜ | `extract_docs_files.py` | `extract_docs_files.m` | 2h | P1 | File extraction |
| ⬜ | `ndicloud_metadata.py` | `ndicloud_metadata.m` | 3h | P2 | Cloud metadata |
| ⬜ | `dataset_create.py` | Various | 4h | P1 | Dataset creation |
| ⬜ | `dataset_update.py` | Various | 3h | P1 | Dataset updates |
| ⬜ | `dataset_delete.py` | Various | 2h | P1 | Dataset deletion |
| ⬜ | `dataset_publish.py` | Various | 4h | P2 | Publishing |
| ⬜ | `openminds_subject.py` | OpenMINDS files | 3h | P2 | OpenMINDS integration |
| ⬜ | `openminds_element.py` | OpenMINDS files | 3h | P2 | OpenMINDS integration |
| ⬜ | `openminds_stimulus.py` | OpenMINDS files | 3h | P2 | OpenMINDS integration |
| ⬜ | `openminds.py` | OpenMINDS files | 2h | P2 | OpenMINDS base |
| ⬜ | `plotinteractivedocgraph.py` | `plotinteractivedocgraph.m` | 4h | P3 | Graph visualization |
| ⬜ | `uberon_lookup.py` | `uberon_ontology_lookup.m` | 2h | P2 | Ontology helper |
| ⬜ | `ncbi_lookup.py` | NCBI files | 2h | P2 | Ontology helper |
| ⬜ | `doi_register.py` | DOI files | 4h | P2 | DOI registration |
| ⬜ | `crossref_submit.py` | Crossref files | 3h | P2 | Crossref integration |
| ⬜ | `metadata_editor.py` | `metadata_editor.m` | 3h | P2 | Metadata editing |

**Phase 2 Progress**: 2/26 files (8%)

---

## Phase 3: Essential Utilities (62 files)

### ndi.fun Package (Top 15)

| Status | File | MATLAB Source | Effort | Priority | Notes |
|--------|------|---------------|--------|----------|-------|
| ⬜ | `console.py` | `console.m` | 1h | P1 | Console logging |
| ⬜ | `errlog.py` | `errlog.m` | 1h | P1 | Error logging |
| ⬜ | `debuglog.py` | `debuglog.m` | 1h | P1 | Debug logging |
| ⬜ | `syslog.py` | `syslog.m` | 1h | P1 | System logging |
| ⬜ | `timestamp.py` | `timestamp.m` | 30m | P1 | Timestamps |
| ⬜ | `check_toolboxes.py` | `check_Matlab_toolboxes.m` | 2h | P1 | Dependency check |
| ⬜ | `channelname2prefixnumber.py` | `channelname2prefixnumber.m` | 1h | P2 | Parse channels |
| ⬜ | `find_calc_directories.py` | `find_calc_directories.m` | 2h | P1 | Find calculators |
| ⬜ | `pseudorandomint.py` | `pseudorandomint.m` | 1h | P2 | Random numbers |
| ✅ | `name2variablename.py` | `name2variablename.m` | - | - | Complete |
| ⬜ | `plot_spikeshapes.py` | `plot_extracellular_spikeshapes.m` | 3h | P2 | Spike plotting |
| ⬜ | `stimulustemporalfrequency.py` | `stimulustemporalfrequency.m` | 2h | P2 | Stimulus analysis |
| ⬜ | `convertoldnsd2ndi.py` | `convertoldnsd2ndi.m` | 3h | P3 | Legacy conversion |
| ⬜ | `run_platform_checks.py` | `run_Linux_checks.m` | 2h | P2 | Platform checks |
| ⬜ | `assertAddonOnPath.py` | `assertAddonOnPath.m` | 1h | P2 | Path checking |

### ndi.util Package

| Status | File | Effort | Priority | Notes |
|--------|------|--------|----------|-------|
| ✅ | `validators.py` | - | - | Complete |
| ✅ | `hex.py` | - | - | Complete |
| ✅ | `datetime_utils.py` | - | - | Complete |
| ✅ | `json_utils.py` | - | - | Complete |
| ✅ | `table_utils.py` | - | - | Partial - needs expansion |
| ✅ | `document_utils.py` | - | - | Complete |
| ⬜ | `file_utils.py` | 2h | P2 | File I/O helpers |
| ⬜ | `string_utils.py` | 2h | P2 | String manipulation |
| ⬜ | `math_utils.py` | 2h | P2 | Math utilities |
| ⬜ | `plot_utils.py` | 3h | P3 | Plotting helpers |
| ⬜ | `cache_utils.py` | 2h | P2 | Cache helpers |

### ndi.common Package

| Status | File | MATLAB Source | Effort | Priority | Notes |
|--------|------|---------------|--------|----------|-------|
| ✅ | `common.py` (PathConstants) | `PathConstants.m` | - | - | Complete |
| ⬜ | `logger.py` | `getLogger.m` | 2h | P1 | Logging infrastructure |
| ⬜ | `did_integration.py` | Various | 2h | P2 | DID integration |
| ⬜ | `assertDIDInstalled.py` | `assertDIDInstalled.m` | 1h | P2 | DID check |

**Phase 3 Progress**: 7/33 files (21%)

---

## Phase 4: DAQ & Time Systems (20 files)

### DAQ Readers

| Status | File | MATLAB Source | Effort | Priority | Notes |
|--------|------|---------------|--------|----------|-------|
| ✅ | `system.py` | `system.m` | - | - | Complete |
| ✅ | `reader.py` | `reader.m` | - | - | Complete |
| ✅ | `metadatareader.py` | `metadatareader.m` | - | - | Complete |
| ✅ | `blackrock.py` | `blackrock.m` | - | - | Complete |
| ✅ | `cedspike2.py` | `cedspike2.m` | - | - | Complete |
| ✅ | `intan.py` | `intan.m` | - | - | Complete |
| ✅ | `spikegadgets.py` | `spikegadgets.m` | - | - | Complete |
| ⬜ | `mfdaq.py` | `mfdaq.m` | 10h | P1 | **TODO** - Multi-function DAQ |
| ⬜ | `ndr.py` | `ndr.m` | 8h | P2 | **TODO** - NDR format |
| ⬜ | `daqsystemstring.py` | `daqsystemstring.m` | 3h | P2 | **TODO** - String parser |

### Time Synchronization

| Status | File | MATLAB Source | Effort | Priority | Notes |
|--------|------|---------------|--------|----------|-------|
| ✅ | `clocktype.py` | `clocktype.m` | - | - | Complete |
| ✅ | `syncgraph.py` | `syncgraph.m` | - | - | Complete |
| ✅ | `syncrule.py` | `syncrule.m` | - | - | Complete |
| ✅ | `timemapping.py` | `timemapping.m` | - | - | Complete |
| ✅ | `timereference.py` | `timereference.m` | - | - | Complete |
| ✅ | `timeseries.py` | `timeseries.m` | - | - | Complete |
| ⬜ | `commontriggers.py` | `commontriggers.m` | 4h | P1 | **TODO** - Trigger detection |
| ⬜ | `filefind.py` | `filefind.m` | 3h | P2 | **TODO** - File-based finding |
| ⬜ | `filematch.py` | `filematch.m` | 3h | P2 | **TODO** - File-based matching |
| ⬜ | `samples2times.py` | `samples2times.m` | 1h | P1 | **TODO** - Conversion utility |
| ⬜ | `times2samples.py` | `times2samples.m` | 1h | P1 | **TODO** - Conversion utility |

**Phase 4 Progress**: 13/21 files (62%)

---

## Phase 5: Cloud Integration (144 files)

### Synchronization Engine

| Status | File | Effort | Priority | Notes |
|--------|------|--------|----------|-------|
| ⬜ | `two_way_sync.py` | 12h | P1 | Core sync |
| ⬜ | `mirror_to_remote.py` | 4h | P1 | Upload mirror |
| ⬜ | `mirror_from_remote.py` | 4h | P1 | Download mirror |
| ⬜ | `create_sync_index.py` | 3h | P1 | Index creation |
| ⬜ | `update_sync_index.py` | 2h | P1 | Index updates |
| ⬜ | `diff_sync_index.py` | 3h | P1 | Index diff |
| ⬜ | `conflict_resolver.py` | 4h | P1 | Conflicts |
| ⬜ | `incremental_sync.py` | 4h | P2 | Incremental |
| ⬜ | `sync_strategy.py` | 2h | P2 | Strategies |
| ⬜ | `sync_metadata.py` | 2h | P2 | Metadata |

### Bulk Operations (15 files)

| Status | File | Effort | Priority |
|--------|------|--------|----------|
| ⬜ | `bulk_upload.py` | 3h | P1 |
| ⬜ | `bulk_download.py` | 3h | P1 |
| ⬜ | `bulk_delete.py` | 2h | P2 |
| ⬜ | `bulk_update.py` | 3h | P2 |
| ⬜ | `scan_for_upload.py` | 2h | P1 |
| ⬜ | `zip_for_upload.py` | 3h | P1 |
| ⬜ | `unzip_download.py` | 2h | P1 |
| ⬜ | Others... | 12h | P2-P3 |

### Publishing & DOI (10 files)

| Status | File | Effort | Priority |
|--------|------|--------|----------|
| ⬜ | `publish_dataset.py` | 4h | P2 |
| ⬜ | `create_doi.py` | 3h | P2 |
| ⬜ | `register_doi.py` | 4h | P2 |
| ⬜ | Others... | 8h | P2-P3 |

### Current Cloud Files (Basic API)

| Status | File | Notes |
|--------|------|-------|
| ✅ | `auth.py` | Basic auth |
| ✅ | `base.py` | Base client |
| ✅ | `client.py` | Main client |
| ✅ | `datasets.py` | Dataset ops |
| ✅ | `documents.py` | Doc ops |
| ✅ | `files.py` | File ops |
| ✅ | `users.py` | User ops |

**Phase 5 Progress**: 7/144 files (5%)

---

## Phase 6: Advanced Features (227 files)

### Setup & Configuration (77 files)

**Tier 1 - Core** (6 files):
| Status | File | Effort | Priority |
|--------|------|--------|----------|
| ⬜ | `lab.py` | 3h | P1 |
| ⬜ | `vhlab.py` | 2h | P1 |
| ⬜ | `DaqSystemConfiguration.py` | 8h | P1 |
| ⬜ | Others... | 5h | P2 |

**Tier 2 - Lab Configs** (5 files):
| Status | File | Effort |
|--------|------|--------|
| ⬜ | `angeluccilab.py` | 2h |
| ⬜ | `dbkatzlab.py` | 2h |
| ⬜ | `marderlab.py` | 2h |
| ⬜ | `yangyangwang.py` | 2h |
| ⬜ | Others... | 2h |

**Tier 3 & 4** (66 files):
- Conversion utilities: 30 files, ~10h
- Helpers: 36 files, ~7h

**Phase 6 Setup Progress**: 0/77 files (0%)

### Mock Objects (5 files)

| Status | File | Effort |
|--------|------|--------|
| ⬜ | `session.py` | 2h |
| ⬜ | `database.py` | 2h |
| ⬜ | `daqsystem.py` | 1h |
| ⬜ | `probe.py` | 1h |
| ⬜ | `utilities.py` | 1h |

### Examples & Tutorials (13 files)

| Status | File | Effort |
|--------|------|--------|
| ⬜ | `tutorial_01_basics.py` | 2h |
| ⬜ | `tutorial_02_daq.py` | 2h |
| ⬜ | `tutorial_03_analysis.py` | 2h |
| ⬜ | Others... | 10h |

### Other Phase 6

| Component | Files | Progress |
|-----------|-------|----------|
| Dataset | 1 | ⬜ 0/1 |
| Docs | 7 | ⬜ 0/7 |
| Test Framework | 44 | ⬜ 0/44 |

**Phase 6 Total Progress**: 0/227 files (0%)

---

## Overall Progress Summary

| Phase | Component | Complete | Total | % Done | Effort Remaining |
|-------|-----------|----------|-------|--------|------------------|
| 1 | Core Classes | 21 | 46 | 46% | ~20h |
| 2 | Database | 2 | 26 | 8% | ~60h |
| 3 | Utilities | 7 | 33 | 21% | ~30h |
| 4 | DAQ/Time | 13 | 21 | 62% | ~25h |
| 5 | Cloud | 7 | 144 | 5% | ~50h |
| 6 | Advanced | 0 | 227 | 0% | ~55h |
| **TOTAL** | **ALL** | **50** | **497** | **10%** | **240h** |

**Current Overall Status**: ~30% functionality (when counting implemented features)
**File Count Status**: ~10% files complete
**Target**: 100% files, 100% functionality

---

## How to Use This Checklist

1. **Pick a file**: Choose unchecked (⬜) file to work on
2. **Update status**: Change to 🟨 when starting
3. **Implement**: Write Python code following templates
4. **Test**: Write unit tests
5. **Complete**: Change to ✅ when done
6. **Commit**: Git commit with reference to checklist

### Status Codes

- ⬜ **Not started** - Ready to work on
- 🟨 **In progress** - Currently being implemented
- ✅ **Complete** - Fully implemented and tested
- ⏭️ **Skipped** - Not needed in Python version
- 🔄 **Needs revision** - Complete but needs updates
- 🐛 **Has bugs** - Implemented but failing tests
- 📝 **Needs docs** - Code done, docs missing

### Priority Codes

- **P0** - Critical, blocking other work
- **P1** - High priority, core functionality
- **P2** - Medium priority, important features
- **P3** - Low priority, nice to have

---

## Next Actions

**Immediate** (This week):
1. ⬜ Complete Session.daqsystem_rm()
2. ⬜ Complete Session.daqsystem_clear()
3. ⬜ Complete Session.database_existbinarydoc()
4. ⬜ Complete Document.add_dependency_value_n()
5. ⬜ Complete Document.dependency_value_n()

**Short-term** (This month):
1. ⬜ Finish all Phase 1 methods
2. ⬜ Start SQLite database backend
3. ⬜ Port top 5 database utilities

**Long-term** (This quarter):
1. ⬜ Complete Phases 1-3
2. ⬜ Begin Phase 4 (DAQ/Time completion)
3. ⬜ Achieve 60% overall completion

---

**END OF CHECKLIST**

*Last Updated*: 2025-11-16
*Next Review*: Weekly
