# Complete NDI-Python Implementation Plan

## Objective

Implement **100% feature parity** with NDI-MATLAB and port **every single test** from the MATLAB repository.

**No shortcuts. No "core only" implementations. Complete port.**

---

## Current Status

### ✅ Completed (Phase 1)
- IDO (unique identifiers)
- Document system (basic)
- Database (file-based)
- Session management (basic)
- Query system
- Cache
- Basic Element/Probe/Epoch stubs
- Subject
- **55/55 tests passing** for implemented features

### ❌ Missing (Must Implement)

**35 MATLAB test classes identified. Currently ported: 6. Remaining: 29.**

---

## Implementation Phases

### Phase 2: Epoch & Time System (CRITICAL)
**Required for**: OneEpochTest, many other tests

#### 2.1 Time System (`+time/`)
- [ ] `clocktype.m` → `time/clocktype.py`
- [ ] `timereference.m` → `time/timereference.py`
- [ ] `timemapping.m` → `time/timemapping.py`
- [ ] `timeseries.m` → `time/timeseries.py`
- [ ] `syncgraph.m` → `time/syncgraph.py`
- [ ] `syncrule.m` → `time/syncrule.py`
- [ ] `+syncrule/` subpackage
  - [ ] `filefind.m`
  - [ ] `filematch.m`
  - [ ] `commontriggers.m`
- [ ] `+fun/` utilities
  - [ ] `times2samples.m`
  - [ ] `samples2times.m`

#### 2.2 Epoch System (`+epoch/`)
- [ ] Complete `epoch.m` → `epoch/epoch.py` (beyond stub)
- [ ] `epochset.m` → `epoch/epochset.py` (full implementation)
- [ ] `epochprobemap.m` → `epoch/epochprobemap.py`
- [ ] `epochrange.m` → `epoch/epochrange.py`
- [ ] `findepochnode.m` → `epoch/findepochnode.py`
- [ ] `+epochset/` parameters

**Tests to port after Phase 2**:
- [ ] OneEpochTest.m → test_oneepoch.py

---

### Phase 3: DAQ System (CRITICAL)
**Required for**: ProbeTest, OneEpochTest, data reading

#### 3.1 Core DAQ (`+daq/`)
- [ ] `system.m` → `daq/system.py` (full implementation)
- [ ] `reader.m` → `daq/reader.py`
- [ ] `metadatareader.m` → `daq/metadatareader.py`
- [ ] `daqsystemstring.m` → `daq/daqsystemstring.py`

#### 3.2 DAQ Readers (`+daq/+reader/`)
- [ ] `mfdaq.m` → `daq/reader/mfdaq.py`
- [ ] `cederspike2.m` → `daq/reader/cederspike2.py`
- [ ] `blackrock.m` → `daq/reader/blackrock.py`
- [ ] `intan.m` → `daq/reader/intan.py`
- [ ] `spikegadgets.m` → `daq/reader/spikegadgets.py`

#### 3.3 DAQ System Implementations (`+daq/+system/`)
- [ ] `mfdaq.m` → `daq/system/mfdaq.py`

#### 3.4 Metadata Readers (`+daq/+metadatareader/`)
- [ ] `NewStim.m` → `daq/metadatareader/newstim.py`
- [ ] Nielsen Lab readers

**Tests to port after Phase 3**:
- [ ] ProbeTest.m → test_probe.py (partially)
- [ ] Related DAQ tests

---

### Phase 4: Probe System (HIGH PRIORITY)
**Required for**: ProbeTest, most data access

#### 4.1 Probe Core
- [ ] Complete `probe.m` → `probe/probe.py` (beyond stub)
- [ ] `+probe/+fun/` utilities
  - [ ] `initProbeTypeMap.m` → `probe/fun/init_probe_type_map.py`
  - [ ] `getProbeTypeMap.m` → `probe/fun/get_probe_type_map.py`
  - [ ] Other probe utilities

#### 4.2 Probe Implementations
- [ ] `+probe/+timeseries/` - timeseries probes
- [ ] Specific probe types as needed

**Tests to port after Phase 4**:
- [x] ProbeTest.m → test_probe.py (COMPLETE)

---

### Phase 5: Element System (HIGH PRIORITY)
**Required for**: Element tests, data organization

#### 5.1 Element Core
- [ ] Complete `element.m` → `element/element.py` (full implementation)
- [ ] Element epoch table building
- [ ] Element dependencies
- [ ] `+element/` subpackage if exists

#### 5.2 Element Types
- [ ] `element.timeseries` (for OneEpochTest)
- [ ] `element.oneepoch` (for OneEpochTest)
- [ ] Other element types as needed

**Tests to port after Phase 5**:
- [x] OneEpochTest.m → test_oneepoch.py (after timeseries)

---

### Phase 6: File System (MEDIUM PRIORITY)
**Required for**: File navigation tests

#### 6.1 File Navigator (`+file/`)
- [ ] `navigator.m` → `file/navigator.py`
- [ ] `pfilemirror.m` → `file/pfilemirror.py`
- [ ] `temp_name.m` → `file/temp_name.py`
- [ ] `temp_fid.m` → `file/temp_fid.py`
- [ ] `+navigator/epochdir.m` → `file/navigator/epochdir.py`
- [ ] `+type/` file types

**Tests to port after Phase 6**:
- [ ] NDIFileNavigatorTest.m → test_file_navigator.py

---

### Phase 7: Ontology System (MEDIUM PRIORITY)
**Required for**: Ontology tests

#### 7.1 Ontology (`+ontology/`)
- [ ] `ontology.m` → `ontology/ontology.py` (full implementation)
- [ ] Ontology lookup
- [ ] Vocabulary management
- [ ] Caching

**Tests to port after Phase 7**:
- [ ] TestOntologyLookup.m → test_ontology.py

---

### Phase 8: Validators (MEDIUM PRIORITY)
**Required for**: 8 validator test classes

#### 8.1 Validator Functions (`+validators/`)
- [ ] `mustBeID.m` → `validators/must_be_id.py`
- [ ] `mustBeCellArrayOfNdiSessions.m` → (use type hints)
- [ ] `mustBeCellArrayOfNonEmptyCharacterArrays.m` → (use type hints)
- [ ] `mustBeEpochInput.m` → `validators/must_be_epoch_input.py`
- [ ] `mustBeNumericClass.m` → `validators/must_be_numeric_class.py`
- [ ] `mustBeTextLike.m` → `validators/must_be_text_like.py`
- [ ] `mustHaveRequiredColumns.m` → `validators/must_have_required_columns.py`
- [ ] `mustMatchRegex.m` → `validators/must_match_regex.py`

**Tests to port after Phase 8**:
- [ ] mustBeIDTest.m → test_validators_id.py
- [ ] mustBeCellArrayOfNdiSessionsTest.m → test_validators_sessions.py
- [ ] mustBeCellArrayOfNonEmptyCharacterArraysTest.m → test_validators_arrays.py
- [ ] mustBeEpochInputTest.m → test_validators_epoch.py
- [ ] mustBeNumericClassTest.m → test_validators_numeric.py
- [ ] mustBeTextLikeTest.m → test_validators_text.py
- [ ] mustHaveRequiredColumnsTest.m → test_validators_columns.py
- [ ] mustMatchRegexTest.m → test_validators_regex.py

---

### Phase 9: Utility Functions (MEDIUM PRIORITY)
**Required for**: 10+ utility test classes

#### 9.1 Fun Utilities (`+fun/`)
- [ ] `timestamp.m` → `fun/timestamp.py`
- [ ] `check_Matlab_toolboxes.m` → (N/A for Python)
- [ ] `name2variableName.m` → `fun/name2variable_name.py`
- [ ] `stimulustemporalfrequency.m` → `fun/stimulus_temporal_frequency.py`

#### 9.2 Fun Subpackages
- [ ] `+calc/` utilities
- [ ] `+data/` utilities
- [ ] `+dataset/` utilities - **diffTest.m**
- [ ] `+doc/` utilities - **TestAllTypes.m, TestFindFuid.m**
- [ ] `+docTable/` utilities
- [ ] `+epoch/` utilities
- [ ] `+file/` utilities
- [ ] `+plot/` utilities
- [ ] `+probe/` utilities
- [ ] `+stimulus/` utilities
- [ ] `+table/` utilities - **TestVStack.m**

#### 9.3 Util Functions (`+util/`)
- [ ] Date/time utilities - **test_datestamp2datetime.m**
- [ ] Hex utilities - **testHexDiff.m, testHexDump.m, getHexDiffFromFileObjTest.m, hexDiffBytesTest.m**
- [ ] JSON utilities - **TestRehydrateJSONNanNull.m**
- [ ] Table utilities - **TestUnwrapTableCellContent.m**

**Tests to port after Phase 9**:
- [ ] diffTest.m → test_fun_dataset_diff.py
- [ ] TestAllTypes.m → test_fun_doc_all_types.py
- [ ] TestFindFuid.m → test_fun_doc_find_fuid.py
- [ ] TestVStack.m → test_fun_table_vstack.py
- [ ] test_datestamp2datetime.m → test_util_datestamp.py
- [ ] testHexDiff.m → test_util_hex_diff.py
- [ ] testHexDump.m → test_util_hex_dump.py
- [ ] getHexDiffFromFileObjTest.m → test_util_hex_diff_file.py
- [ ] hexDiffBytesTest.m → test_util_hex_diff_bytes.py
- [ ] TestRehydrateJSONNanNull.m → test_util_json_nan_null.py
- [ ] TestUnwrapTableCellContent.m → test_util_unwrap_table.py

---

### Phase 10: App & Calculator (MEDIUM PRIORITY)
**Required for**: App tests

#### 10.1 App Framework (`+app/`)
- [ ] Complete `app.m` → `app/app.py`
- [ ] Complete `calculator.m` → `app/calculator.py`
- [ ] `pipeline.m` → `app/pipeline.py`
- [ ] `+stimulus/` app tools

#### 10.2 Calc Framework (`+calc/`)
- [ ] `+example/` calculations
- [ ] `+stimulus/` calculations (tuning curves, etc.)

**Tests to port after Phase 10**:
- [ ] TestMarkGarbage.m → test_app_mark_garbage.py

---

### Phase 11: Database Advanced (HIGH PRIORITY)
**Required for**: Database tests

#### 11.1 Database Implementations (`+database/`)
- [ ] `+implementations/binarydoc.m` → `database/implementations/binarydoc.py`
- [ ] `+implementations/database.m` → improved DirectoryDatabase
- [ ] `+fun/` - 30+ helper functions
- [ ] `+metadata/` - schema and metadata
- [ ] `+metadata_app/` - validation UI (skip UI, keep validation)
- [ ] `+app/` - dataset viewer (skip for now)

#### 11.2 Document Advanced
- [ ] Complete JSON schema system
- [ ] Document discovery
- [ ] Document fields validation

**Tests to port after Phase 11**:
- [ ] TestNDIDocumentDiscovery.m → test_document_discovery.py
- [ ] TestNDIDocumentFields.m → test_document_fields.py (enhanced)
- [ ] TestNDIDocumentJSON.m → test_document_json.py (enhanced)

---

### Phase 12: Setup System (LOW PRIORITY)
**Required for**: Setup tests

#### 12.1 Setup (`+setup/`)
- [ ] `+NDIMaker/` - session creation
- [ ] `+daq/` - DAQ configuration
- [ ] `+conv/` - lab-specific conversions
- [ ] `+epoch/` - epoch setup
- [ ] `+stimulus/` - stimulus config
- [ ] Lab implementations (vhlab, marderlab, etc.)

**Tests to port after Phase 12**:
- [ ] SimpleTestCreator.m → test_setup_creator.py
- [ ] testSubjectMaker.m → test_setup_subject.py

---

### Phase 13: Cloud Integration (OPTIONAL - CLARIFY)
**Required for**: 7 cloud test classes

⚠️ **QUESTION FOR USER**: Should cloud integration be included? This requires:
- Network access
- Authentication systems
- Cloud storage backends (S3, etc.)
- API endpoints

If YES, implement:
#### 13.1 Cloud (`+cloud/`)
- [ ] `+api/` - auth, datasets, documents, files, users
- [ ] `+sync/` - dataset synchronization
- [ ] `+upload/` - upload utilities
- [ ] `+download/` - download utilities
- [ ] `+ui/` - UI dialogs (skip)
- [ ] `+admin/` - admin functions

**Tests to port after Phase 13** (if cloud is in scope):
- [ ] AuthTest.m → test_cloud_auth.py
- [ ] DatasetsTest.m → test_cloud_datasets.py
- [ ] DocumentsTest.m → test_cloud_documents.py
- [ ] DuplicatesTest.m → test_cloud_duplicates.py
- [ ] FilesTest.m → test_cloud_files.py
- [ ] FilesDifficult.m → test_cloud_files_difficult.py
- [ ] TestPublishWithDocsAndFiles.m → test_cloud_publish.py

---

### Phase 14: GUI (PROBABLY SKIP)
**Required for**: 1 GUI test class

⚠️ **QUESTION FOR USER**: Should GUI be ported? Python would use different framework (Qt/Tkinter).

If YES:
- [ ] Choose Python GUI framework (PyQt5, Tkinter, etc.)
- [ ] Port `+gui/` components
- [ ] TestProgressBarWindow.m → test_gui_progress.py

If NO:
- Document that GUI is out of scope for Python CLI version

---

## Execution Strategy

### Chunking Approach

**Week 1**: Phases 2-3 (Epoch + DAQ + Time)
- Days 1-2: Time system
- Days 3-4: Epoch system
- Day 5: DAQ core
- Days 6-7: DAQ readers

**Week 2**: Phases 4-5 (Probe + Element)
- Days 1-3: Probe system + type map
- Days 4-5: Element system
- Days 6-7: Port ProbeTest + OneEpochTest

**Week 3**: Phases 6-7 (File + Ontology)
- Days 1-3: File navigator
- Days 4-5: Ontology
- Days 6-7: Port tests

**Week 4**: Phases 8-9 (Validators + Utilities)
- Days 1-3: All validators
- Days 4-7: All utilities + tests

**Week 5**: Phases 10-11 (Apps + Database Advanced)
- Days 1-3: App/Calculator framework
- Days 4-7: Database enhancements + tests

**Week 6**: Phase 12-14 (Setup + Cloud + Final)
- Days 1-2: Setup system
- Days 3-5: Cloud (if in scope)
- Days 6-7: Final testing + documentation

---

## Test Coverage Goal

**Target**: 100% of MATLAB tests ported

### Current Status
- ✅ 6 test files ported (55 tests)
- ❌ 29 test files remaining

### Remaining Tests to Port

#### High Priority (Functional)
1. ❌ ProbeTest.m
2. ❌ OneEpochTest.m
3. ❌ NDIFileNavigatorTest.m
4. ❌ TestNDIDocumentDiscovery.m
5. ❌ TestNDIDocumentFields.m (enhanced)
6. ❌ TestNDIDocumentJSON.m (enhanced)
7. ❌ TestOntologyLookup.m

#### Medium Priority (Validators - 8 tests)
8. ❌ mustBeIDTest.m
9. ❌ mustBeCellArrayOfNdiSessionsTest.m
10. ❌ mustBeCellArrayOfNonEmptyCharacterArraysTest.m
11. ❌ mustBeEpochInputTest.m
12. ❌ mustBeNumericClassTest.m
13. ❌ mustBeTextLikeTest.m
14. ❌ mustHaveRequiredColumnsTest.m
15. ❌ mustMatchRegexTest.m
16. ❌ TestMustBeCellArrayOfClass.m

#### Medium Priority (Utilities - 11 tests)
17. ❌ diffTest.m
18. ❌ TestAllTypes.m
19. ❌ TestFindFuid.m
20. ❌ TestVStack.m
21. ❌ test_datestamp2datetime.m
22. ❌ testHexDiff.m
23. ❌ testHexDump.m
24. ❌ getHexDiffFromFileObjTest.m
25. ❌ hexDiffBytesTest.m
26. ❌ TestRehydrateJSONNanNull.m
27. ❌ TestUnwrapTableCellContent.m

#### Low Priority (Setup/App - 2 tests)
28. ❌ TestMarkGarbage.m
29. ❌ SimpleTestCreator.m
30. ❌ testSubjectMaker.m

#### Cloud (7 tests) - **PENDING USER INPUT**
31. ❓ AuthTest.m
32. ❓ DatasetsTest.m
33. ❓ DocumentsTest.m
34. ❓ DuplicatesTest.m
35. ❓ FilesTest.m
36. ❓ FilesDifficult.m
37. ❓ TestPublishWithDocsAndFiles.m

#### GUI (1 test) - **PENDING USER INPUT**
38. ❓ TestProgressBarWindow.m

---

## Questions for User

Before proceeding with full implementation:

1. **Cloud Integration**: Should the cloud API be implemented? This is substantial work involving network protocols, authentication, and cloud storage.
   - YES → Implement all 7 cloud test classes
   - NO → Document as out of scope

2. **GUI Components**: Should GUI be ported to Python?
   - YES → Choose framework (PyQt5/Tkinter) and port
   - NO → Document as CLI-only

3. **Priority Order**: Should I proceed with the week-by-week plan above, or prioritize differently?

---

## Success Criteria

✅ Every MATLAB test class has corresponding Python test(s)
✅ 100% test pass rate
✅ Feature parity with MATLAB for all implemented features
✅ Complete documentation
✅ No "stub" implementations - everything fully functional

**No compromises. Complete port.**
