# NDI-Python 100% Feature Parity Implementation Roadmap

**Version**: 1.0
**Date**: 2025-11-16
**Current Status**: 25-30% Complete
**Target**: 100% Feature Parity with NDI-MATLAB

---

## Executive Summary

This roadmap provides a comprehensive, actionable plan to achieve 100% feature parity between NDI-Python and NDI-MATLAB. The project requires porting **574 files** (~46,000 lines of code) across 6 major phases.

**Total Estimated Effort**: 240-320 hours (6-8 weeks full-time)

**Current Gaps**:
- 574 files missing (85% of codebase)
- 95% of database functionality
- 95% of cloud integration
- 87% of GUI framework
- 98% of utilities
- 39% of Session methods
- 41% of Document methods

---

## Phase Overview

| Phase | Component | Files | Effort | Priority | Dependencies |
|-------|-----------|-------|--------|----------|--------------|
| **1** | Core Classes | 25 methods | 20-30h | Critical | None |
| **2** | Database Backends | 96 files | 60-80h | Critical | Phase 1 |
| **3** | Essential Utilities | 62 files | 30-40h | High | Phase 1 |
| **4** | DAQ & Time | 20 files | 25-35h | High | Phase 1, 3 |
| **5** | Cloud Integration | 144 files | 50-70h | Medium | Phase 1, 2 |
| **6** | Advanced Features | 227 files | 55-65h | Low | All previous |

---

## Phase 1: Core Classes Completion (CRITICAL)

**Goal**: Complete Session and Document classes to full MATLAB parity
**Effort**: 20-30 hours
**Priority**: P0 - Must complete first
**Files**: Modify 2 existing files (session.py, document.py)

### 1.1 Session Class - Missing Methods (13 methods)

**File**: `ndi-python/ndi/session.py`
**MATLAB Source**: `src/ndi/+ndi/session.m` (lines 106-898)

#### High Priority Methods:

1. **`daqsystem_rm(dev)`** - Remove DAQ system
   - **Lines in MATLAB**: 106-135
   - **Complexity**: Medium
   - **Dependencies**: None
   - **Implementation**:
   ```python
   def daqsystem_rm(self, dev) -> 'Session':
       """
       Remove a DAQ system from the session.

       Args:
           dev: DAQ system to remove (object or name)

       Returns:
           Session: Self for chaining
       """
       from .daq.system import DAQSystem

       # Handle both object and name inputs
       if isinstance(dev, str):
           name = dev
       elif isinstance(dev, DAQSystem):
           name = dev.name
       else:
           raise TypeError("dev must be DAQSystem or string name")

       # Search for the DAQ system
       q = Query('', 'isa', 'daqsystem', '') & \
           Query('base.name', 'exact_string', name, '')
       docs = self.database_search(q)

       # Remove all matching documents
       for doc in docs:
           self.database_rm(doc)

       return self
   ```

2. **`daqsystem_clear()`** - Remove all DAQ systems
   - **Lines in MATLAB**: 176-195
   - **Complexity**: Low
   - **Implementation**:
   ```python
   def daqsystem_clear(self) -> 'Session':
       """Remove all DAQ systems from the session."""
       q = Query('', 'isa', 'daqsystem', '')
       docs = self.database_search(q)
       for doc in docs:
           self.database_rm(doc)
       return self
   ```

3. **`validate_documents(document)`** - Validate document session IDs
   - **Lines in MATLAB**: 345-379
   - **Complexity**: Medium
   - **Dependencies**: ndi.validate module
   - **Implementation**:
   ```python
   def validate_documents(self, document: Union[Document, List[Document]]) -> tuple[bool, str]:
       """
       Validate that documents belong to this session.

       Args:
           document: Document or list of documents to validate

       Returns:
           tuple: (is_valid, error_message)
       """
       from .validate import Validate

       docs = document if isinstance(document, list) else [document]

       for doc in docs:
           # Check session ID matches
           if doc.document_properties.get('base.session_id') != self.id():
               return False, f"Document {doc.id()} has wrong session_id"

           # Run full validation
           validator = Validate(doc, self)
           if not validator.is_valid:
               return False, validator.errormsg

       return True, ''
   ```

4. **`database_existbinarydoc(doc_or_id, filename)`** - Check binary doc exists
   - **Lines in MATLAB**: 416-426
   - **Complexity**: Low
   - **Implementation**:
   ```python
   def database_existbinarydoc(self, doc_or_id: Union[str, Document],
                                filename: str) -> tuple[bool, str]:
       """
       Check if a binary file exists for a document.

       Args:
           doc_or_id: Document or document ID
           filename: Binary file name

       Returns:
           tuple: (exists, file_path)
       """
       doc_id = doc_or_id if isinstance(doc_or_id, str) else doc_or_id.id()
       file_path = self.database.get_binary_path(doc_id, filename)
       exists = os.path.isfile(file_path)
       return exists, file_path if exists else ''
   ```

5. **`syncgraph_addrule(rule)`** - Add sync rule to graph
   - **Lines in MATLAB**: 448-458
   - **Complexity**: Low
   - **Dependencies**: ndi.time.syncgraph
   - **Implementation**:
   ```python
   def syncgraph_addrule(self, rule) -> 'Session':
       """
       Add a synchronization rule to the syncgraph.

       Args:
           rule: ndi.time.syncrule object

       Returns:
           Session: Self for chaining
       """
       if self.syncgraph is None:
           from .time.syncgraph import SyncGraph
           self.syncgraph = SyncGraph(self)

       self.syncgraph.add_rule(rule)
       return self
   ```

6. **`syncgraph_rmrule(index)`** - Remove sync rule
   - **Lines in MATLAB**: 460-470
   - **Complexity**: Low
   - **Implementation**:
   ```python
   def syncgraph_rmrule(self, index: int) -> 'Session':
       """Remove a synchronization rule by index."""
       if self.syncgraph:
           self.syncgraph.remove_rule(index)
       return self
   ```

#### Medium Priority Methods:

7. **`ingest()`** - Ingest raw data and sync info
   - **Lines in MATLAB**: 472-502
   - **Complexity**: High
   - **Dependencies**: DAQ systems, sync rules, file navigator
   - **Notes**: Complex - handles data ingestion pipeline
   - **Estimated time**: 4-6 hours

8. **`get_ingested_docs()`** - Get ingested documents
   - **Lines in MATLAB**: 504-519
   - **Complexity**: Low
   - **Implementation**:
   ```python
   def get_ingested_docs(self) -> List[Document]:
       """Get all documents marked as ingested."""
       q = Query('', 'isa', 'daqreader_epochdata_ingested', '')
       return self.database_search(q)
   ```

9. **`is_fully_ingested()`** - Check if fully ingested
   - **Lines in MATLAB**: 521-549
   - **Complexity**: Medium
   - **Notes**: Checks if all epochs are ingested

10. **`findexpobj(obj_name, obj_classname)`** - Find experiment object
    - **Lines in MATLAB**: 570-613
    - **Complexity**: Medium
    - **Notes**: Generic object finder by name and class

#### Low Priority Methods:

11. **`creator_args()`** - Return constructor arguments
    - **Lines in MATLAB**: 758-775
    - **Complexity**: Low
    - **Notes**: For session reconstruction

12. **`docinput2docs(doc_input)`** - Convert doc input to docs (static)
    - **Lines in MATLAB**: 839-896
    - **Complexity**: Medium
    - **Notes**: Helper for document input parsing

13. **`all_docs_in_session(docs, session_id)`** - Validate docs in session (static)
    - **Lines in MATLAB**: 898-927
    - **Complexity**: Low
    - **Notes**: Batch validation helper

### 1.2 Document Class - Missing Methods (12+ methods)

**File**: `ndi-python/ndi/document.py`
**MATLAB Source**: `src/ndi/+ndi/document.m`

#### Critical Methods:

1. **`add_dependency_value_n(name, value)`** - Add numbered dependency
   - **Implementation**:
   ```python
   def add_dependency_value_n(self, name: str, value: str) -> None:
       """
       Add a numbered dependency value.

       Args:
           name: Base dependency name (e.g., 'element_id')
           value: ID value to add
       """
       # Find next available number
       n = 1
       while f'depends_on.{name}_{n}' in self.document_properties:
           n += 1

       self.document_properties[f'depends_on.{name}_{n}'] = value
   ```

2. **`dependency_value_n(name, n)`** - Get numbered dependency
   ```python
   def dependency_value_n(self, name: str, n: int) -> Optional[str]:
       """Get the nth dependency value."""
       key = f'depends_on.{name}_{n}'
       return self.document_properties.get(key)
   ```

3. **`to_table()`** - Convert to table format
   - **Complexity**: Medium
   - **Dependencies**: pandas
   - **Notes**: Returns pandas DataFrame

4. **File Management Methods** (7 methods):
   - `has_files()` - Check if document has files
   - `add_file(filename, filedata)` - Add file to document
   - `remove_file(filename)` - Remove file
   - `reset_file_info()` - Reset file information
   - `is_in_file_list(filename)` - Check file in list
   - `get_fuid()` - Get file UID
   - `current_file_list()` - Get current files

5. **Utility Methods**:
   - `plus(other)` / `__add__()` - Add documents together
   - `remove_dependency_value_n(name, n)` - Remove numbered dependency
   - `setproperties(**kwargs)` - Batch set properties
   - `validate()` - Validate document

6. **Static Methods**:
   - `find_doc_by_id(docs, doc_id)` - Find doc in array by ID
   - `find_newest(docs)` - Find newest doc in array

### 1.3 Phase 1 Implementation Plan

**Week 1** (40 hours):
- Days 1-2: Session methods 1-6 (12h)
- Days 3-4: Session methods 7-13 (12h)
- Day 5: Document methods 1-6 (8h)
- Day 5: Document methods 7-12 (8h)

**Testing** (8 hours):
- Write unit tests for all new methods
- Integration tests with existing code
- Test coverage > 90%

**Deliverables**:
- ✅ Full Session class parity
- ✅ Full Document class parity
- ✅ Comprehensive test suite
- ✅ Updated documentation

---

## Phase 2: Database Backends (CRITICAL)

**Goal**: Add all 3 database backends and essential utilities
**Effort**: 60-80 hours
**Priority**: P0
**Files**: 96 new files

### 2.1 SQLite Database Backend

**File**: `ndi-python/ndi/database/sqlite.py`
**MATLAB Source**: `src/ndi/+ndi/+database/didsqlite.m`
**Effort**: 15-20 hours

**Key Features**:
- Full SQL schema for documents
- Binary large object (BLOB) support
- Indexed queries for performance
- Transaction support

**Implementation Template**:
```python
import sqlite3
from typing import List, Optional
from ..document import Document
from ..query import Query
from .database import Database

class SQLiteDatabase(Database):
    """
    SQLite-based document database for NDI.

    Provides persistent storage with SQL query optimization.
    """

    def __init__(self, db_path: str):
        """
        Initialize SQLite database.

        Args:
            db_path: Path to SQLite database file
        """
        super().__init__()
        self.db_path = db_path
        self.conn = None
        self._init_database()

    def _init_database(self):
        """Initialize database schema."""
        self.conn = sqlite3.connect(self.db_path)
        cursor = self.conn.cursor()

        # Create documents table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                session_id TEXT,
                doc_type TEXT,
                datestamp TEXT,
                properties TEXT,
                INDEX idx_session (session_id),
                INDEX idx_type (doc_type)
            )
        ''')

        # Create binary files table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS binary_files (
                doc_id TEXT,
                filename TEXT,
                data BLOB,
                PRIMARY KEY (doc_id, filename),
                FOREIGN KEY (doc_id) REFERENCES documents(id)
            )
        ''')

        self.conn.commit()

    def add(self, document: Document) -> None:
        """Add document to SQLite database."""
        import json
        cursor = self.conn.cursor()

        cursor.execute('''
            INSERT OR REPLACE INTO documents
            (id, session_id, doc_type, datestamp, properties)
            VALUES (?, ?, ?, ?, ?)
        ''', (
            document.id(),
            document.document_properties.get('base.session_id'),
            document.document_properties.get('document_class.class_name'),
            document.document_properties.get('base.datestamp'),
            json.dumps(document.document_properties)
        ))

        self.conn.commit()

    def search(self, query: Query) -> List[Document]:
        """Search documents using SQL optimizations."""
        # Convert NDI query to SQL WHERE clause
        where_clause, params = self._query_to_sql(query)

        cursor = self.conn.cursor()
        cursor.execute(f'''
            SELECT properties FROM documents
            WHERE {where_clause}
        ''', params)

        docs = []
        for row in cursor.fetchall():
            props = json.loads(row[0])
            doc = Document.from_properties(props)
            docs.append(doc)

        return docs

    def _query_to_sql(self, query: Query) -> tuple:
        """Convert NDI Query to SQL WHERE clause."""
        # Implementation of query translation
        # This is complex - needs to handle:
        # - exact_string, contains_string
        # - exact_number, greater_than, less_than
        # - regexp
        # - isa (class hierarchy)
        # - AND/OR logic
        pass
```

### 2.2 JSON Database Backends

**Files**:
- `ndi-python/ndi/database/matlabdumbjsondb.py` (10-15h)
- `ndi-python/ndi/database/matlabdumbjsondb2.py` (10-15h)

**Features**:
- Human-readable JSON storage
- Version 1 vs Version 2 differences
- File-based indexing

### 2.3 Database Utilities (Top 20 Most Critical)

**Directory**: `ndi-python/ndi/database/`
**Effort**: 30-40 hours

**Priority 1 - Essential** (10 files, 15h):

1. **`docs_from_ids.py`** - Batch document retrieval
   ```python
   def docs_from_ids(session, doc_ids: List[str]) -> List[Document]:
       """
       Retrieve multiple documents by ID efficiently.

       Args:
           session: NDI session
           doc_ids: List of document IDs

       Returns:
           List of documents
       """
       docs = []
       for doc_id in doc_ids:
           doc = session.database.read(doc_id)
           if doc:
               docs.append(doc)
       return docs
   ```

2. **`findalldependencies.py`** - Forward dependency search
3. **`findallantecedents.py`** - Backward dependency search
4. **`docs2graph.py`** - Build dependency graph
5. **`extract_docs_files.py`** - Extract document files
6. **`ndicloud_metadata.py`** - Cloud metadata preparation
7. **`dataset_create.py`** - Create dataset
8. **`dataset_update.py`** - Update dataset
9. **`dataset_delete.py`** - Delete dataset
10. **`dataset_publish.py`** - Publish dataset

**Priority 2 - OpenMINDS** (5 files, 10h):
11-15. OpenMINDS integration modules

**Priority 3 - Analysis** (5 files, 10h):
16-20. Graph analysis and visualization

### 2.4 Phase 2 Implementation Plan

**Week 2-3** (80 hours):
- Days 1-3: SQLite backend (20h)
- Days 4-5: JSON backends (16h)
- Days 6-8: Essential utilities 1-10 (24h)
- Days 9-10: OpenMINDS integration (16h)
- Testing: 4h

---

## Phase 3: Essential Utilities (HIGH)

**Goal**: Port critical utility functions
**Effort**: 30-40 hours
**Priority**: P1
**Files**: 62 files

### 3.1 ndi.fun Package (Priority Subset)

**Directory**: `ndi-python/ndi/fun/`
**Total in MATLAB**: 51 files
**Port**: Top 15 most critical

#### Critical Functions (10 files, 15h):

1. **`console.py`** - Console logging
   ```python
   import sys
   from datetime import datetime

   def console(message: str, priority: int = 0) -> None:
       """
       Log message to console with timestamp.

       Args:
           message: Message to log
           priority: 0=info, 1=warning, 2=error
       """
       timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
       prefix = ['INFO', 'WARN', 'ERROR'][min(priority, 2)]
       print(f'[{timestamp}] {prefix}: {message}', file=sys.stderr)
   ```

2. **`errlog.py`** - Error logging
3. **`debuglog.py`** - Debug logging
4. **`syslog.py`** - System logging
5. **`timestamp.py`** - Timestamp generation
6. **`check_toolboxes.py`** - Check dependencies
7. **`channelname2prefixnumber.py`** - Parse channel names
8. **`find_calc_directories.py`** - Find calculator directories
9. **`pseudorandomint.py`** - Random number generation
10. **`name2variablename.py`** - ✅ Already ported

#### Specialized Functions (5 files, 10h):

11. **`plot_extracellular_spikeshapes.py`** - Spike visualization
12. **`stimulustemporalfrequency.py`** - Stimulus analysis
13. **`convertoldnsd2ndi.py`** - Legacy conversion
14. **`run_platform_checks.py`** - Platform compatibility
15. **`assertAddonOnPath.py`** - Dependency checking

### 3.2 ndi.util Package

**Directory**: `ndi-python/ndi/util/`
**Current**: 6 files ✅
**Missing**: 7 files

**Missing Files** (7 files, 8h):
1. `document_utils.py` - Document manipulation helpers
2. `table_utils.py` - Enhanced table operations (extend existing)
3. `file_utils.py` - File I/O helpers
4. `string_utils.py` - String manipulation
5. `math_utils.py` - Mathematical utilities
6. `plot_utils.py` - Plotting helpers
7. `cache_utils.py` - Cache management utilities

### 3.3 ndi.common Package

**Directory**: `ndi-python/ndi/common/`
**Current**: 1 file ✅ (PathConstants)
**Missing**: 4 files

**Missing Files** (4 files, 5h):
1. `logger.py` - Logging infrastructure
2. `did_integration.py` - DID package integration
3. `assertDIDInstalled.py` - DID dependency check
4. `getLogger.py` - Logger factory

### 3.4 Phase 3 Implementation Plan

**Week 4** (40 hours):
- Days 1-2: ndi.fun critical (15h)
- Day 3: ndi.fun specialized (10h)
- Day 4: ndi.util missing (8h)
- Day 5: ndi.common (5h)
- Testing: 2h

---

## Phase 4: DAQ & Time Systems (HIGH)

**Goal**: Complete DAQ readers and time synchronization
**Effort**: 25-35 hours
**Priority**: P1
**Files**: 20 files

### 4.1 Missing DAQ Readers

**Directory**: `ndi-python/ndi/daq/reader/`

#### 1. Multi-Function DAQ Reader (mfdaq)

**File**: `mfdaq.py`
**MATLAB Source**: `src/ndi/+ndi/+daq/+reader/mfdaq.m`
**Effort**: 8-10 hours

**Features**:
- Reads multiple file formats in single DAQ
- Channel mapping
- Metadata integration

**Template**:
```python
from typing import List, Dict, Any
from ..reader import Reader
import numpy as np

class MFDAQReader(Reader):
    """
    Multi-function DAQ reader.

    Reads data from multiple file formats within a single
    data acquisition system.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.readers = {}  # Sub-readers for each format

    def read_channels(self, channel_type: str, channel_list: List[int],
                     epoch_number: int, t0: float, t1: float) -> Dict[str, Any]:
        """
        Read data from multiple channels across multiple files.

        Args:
            channel_type: Type of channels ('analog', 'digital', etc.)
            channel_list: List of channel numbers
            epoch_number: Epoch to read from
            t0: Start time
            t1: End time

        Returns:
            Dictionary with 'data', 'timestamps', 'samplerate'
        """
        # Determine which reader handles each channel
        # Aggregate data from multiple readers
        # Return unified result
        pass
```

#### 2. NDR Format Reader

**File**: `ndr.py`
**Effort**: 6-8 hours

### 4.2 Time Synchronization Utilities

**Directory**: `ndi-python/ndi/time/`
**Current**: 6 files ✅
**Missing**: 5 files

#### Missing Files (5 files, 10h):

1. **`commontriggers.py`** - Common trigger detection
   ```python
   from typing import List, Tuple
   import numpy as np
   from .syncrule import SyncRule

   class CommonTriggers(SyncRule):
       """
       Sync rule based on common triggers between devices.

       Finds common trigger events across devices to establish
       time synchronization.
       """

       def __init__(self, trigger_threshold: float = 0.5):
           super().__init__()
           self.trigger_threshold = trigger_threshold

       def apply(self, dev1_times: np.ndarray, dev2_times: np.ndarray) -> Tuple:
           """
           Find common triggers and compute time mapping.

           Args:
               dev1_times: Trigger times from device 1
               dev2_times: Trigger times from device 2

           Returns:
               Tuple of (mapping_coefficients, match_quality)
           """
           # Implement trigger matching algorithm
           # Return polynomial mapping coefficients
           pass
   ```

2. **`filefind.py`** - File-based time finding
3. **`filematch.py`** - File-based time matching
4. **`samples2times.py`** - Sample to time conversion
   ```python
   def samples2times(samples: np.ndarray, samplerate: float,
                     t0: float = 0.0) -> np.ndarray:
       """
       Convert sample numbers to times.

       Args:
           samples: Array of sample numbers
           samplerate: Sampling rate in Hz
           t0: Time of sample 0

       Returns:
           Array of times
       """
       return (samples / samplerate) + t0
   ```

5. **`times2samples.py`** - Time to sample conversion
   ```python
   def times2samples(times: np.ndarray, samplerate: float,
                     t0: float = 0.0) -> np.ndarray:
       """
       Convert times to sample numbers.

       Args:
           times: Array of times
           samplerate: Sampling rate in Hz
           t0: Time of sample 0

       Returns:
           Array of sample numbers (rounded to nearest)
       """
       return np.round((times - t0) * samplerate).astype(int)
   ```

### 4.3 DAQ System String Parser

**File**: `ndi-python/ndi/daq/daqsystemstring.py`
**Effort**: 2-3 hours

### 4.4 Phase 4 Implementation Plan

**Week 5** (32 hours):
- Days 1-2: MFDAQ reader (16h)
- Day 3: NDR reader (8h)
- Day 4: Time utilities (6h)
- Day 5: Testing (2h)

---

## Phase 5: Cloud Integration (MEDIUM)

**Goal**: Add cloud sync, publishing, and DOI registration
**Effort**: 50-70 hours
**Priority**: P2
**Files**: 137 new files (from current 7)

### 5.1 Cloud Architecture

**Current State**: Basic API wrappers (7 files)
**Target**: Full cloud integration (144 files)

### 5.2 Synchronization Engine (Priority 1)

**Directory**: `ndi-python/ndi/cloud/sync/`
**Files**: 10 new files
**Effort**: 20-25 hours

#### Key Files:

1. **`two_way_sync.py`** - Two-way synchronization
   ```python
   from typing import Dict, List
   from ..api.datasets import DatasetsAPI
   from ..api.documents import DocumentsAPI

   class TwoWaySync:
       """
       Two-way synchronization between local and cloud.

       Handles conflict resolution, incremental updates,
       and bidirectional data flow.
       """

       def __init__(self, session, credentials):
           self.session = session
           self.credentials = credentials
           self.datasets_api = DatasetsAPI(credentials)
           self.docs_api = DocumentsAPI(credentials)

       def sync(self, strategy: str = 'newest_wins') -> Dict:
           """
           Perform two-way sync.

           Args:
               strategy: Conflict resolution ('newest_wins', 'local_wins', 'cloud_wins')

           Returns:
               Sync report with statistics
           """
           # 1. Build local and cloud indexes
           # 2. Identify differences
           # 3. Resolve conflicts
           # 4. Upload local changes
           # 5. Download cloud changes
           # 6. Update sync metadata
           pass
   ```

2. **`mirror_to_remote.py`** - Upload mirroring
3. **`mirror_from_remote.py`** - Download mirroring
4. **`create_sync_index.py`** - Sync index creation
5. **`update_sync_index.py`** - Sync index updates
6. **`diff_sync_index.py`** - Index comparison
7. **`conflict_resolver.py`** - Conflict resolution
8. **`incremental_sync.py`** - Incremental updates
9. **`sync_strategy.py`** - Sync strategies
10. **`sync_metadata.py`** - Sync metadata tracking

### 5.3 Bulk Operations (Priority 2)

**Files**: 15 new files
**Effort**: 15-20 hours

1. `bulk_upload.py` - Batch document upload
2. `bulk_download.py` - Batch document download
3. `bulk_delete.py` - Batch document deletion
4. `bulk_update.py` - Batch document updates
5. `scan_for_upload.py` - Find files to upload
6. `zip_for_upload.py` - Package for upload
7. `unzip_download.py` - Extract downloads
8. `upload_queue.py` - Upload queue management
9. `download_queue.py` - Download queue management
10. `progress_tracker.py` - Transfer progress
11-15. Additional bulk utilities

### 5.4 Publishing & DOI (Priority 3)

**Files**: 10 new files
**Effort**: 12-15 hours

1. **`publish_dataset.py`** - Dataset publishing
2. **`create_doi.py`** - DOI creation
3. **`register_doi.py`** - DOI registration with Crossref
4. **`doi_metadata.py`** - DOI metadata preparation
5. **`crossref_submission.py`** - Crossref batch submission
6. **`validate_publication.py`** - Pre-publication validation
7. **`publication_workflow.py`** - Publishing workflow
8-10. Additional publishing utilities

### 5.5 Metadata & Validation (Priority 2)

**Files**: 10 new files
**Effort**: 8-10 hours

### 5.6 Phase 5 Implementation Plan

**Week 6-7** (60 hours):
- Days 1-3: Sync engine (24h)
- Days 4-5: Bulk operations (16h)
- Days 6-7: Publishing/DOI (12h)
- Day 8: Metadata/validation (8h)

---

## Phase 6: Advanced Features (LOW)

**Goal**: GUI, Setup, Mock, Examples, Dataset
**Effort**: 55-65 hours
**Priority**: P3
**Files**: 227 files

### 6.1 Setup & Configuration

**Directory**: `ndi-python/ndi/setup/`
**Files**: 77 new files
**Effort**: 25-30 hours

#### Priority Structure:

**Tier 1 - Core Setup** (6 files, 8h):
1. `lab.py` - Base lab configuration
2. `vhlab.py` - VH Lab config
3. `DaqSystemConfiguration.py` - DAQ config builder
4-6. Core setup utilities

**Tier 2 - Lab Configs** (5 files, 10h):
7. `angeluccilab.py`
8. `dbkatzlab.py`
9. `marderlab.py`
10. `yangyangwang.py`
11. Additional lab configs

**Tier 3 - Conversion Utilities** (30 files, 10h):
- Lab-specific data format converters
- Import/export tools

**Tier 4 - Helpers** (36 files, 7h):
- DAQ setup helpers
- Epoch setup utilities
- Stimulus setup

### 6.2 Mock Objects & Testing

**Directory**: `ndi-python/ndi/mock/`
**Files**: 5 new files
**Effort**: 4-5 hours

1. `session.py` - Mock session
2. `database.py` - Mock database
3. `daqsystem.py` - Mock DAQ system
4. `probe.py` - Mock probe
5. `utilities.py` - Mock utilities

### 6.3 Examples & Tutorials

**Directory**: `ndi-python/ndi/example/`
**Files**: 13 new files
**Effort**: 8-10 hours

1. `tutorial_01_basics.py` - Basic usage
2. `tutorial_02_daq.py` - DAQ systems
3. `tutorial_03_analysis.py` - Analysis workflow
4-13. Additional examples

### 6.4 Dataset Management

**Directory**: `ndi-python/ndi/dataset/`
**Files**: 1 new file
**Effort**: 6-8 hours

**File**: `dataset.py`
```python
from typing import List, Dict
from ..session import Session

class Dataset:
    """
    Multi-session container for NDI.

    Manages collection of sessions with metadata
    and cross-session operations.
    """

    def __init__(self, reference: str):
        self.reference = reference
        self.session_array: List[Session] = []
        self.session_info: List[Dict] = []

    def add_linked_session(self, session: Session, metadata: Dict = None):
        """Add a session to the dataset without ingestion."""
        self.session_array.append(session)
        info = metadata or {}
        info['session_id'] = session.id()
        info['reference'] = session.reference
        self.session_info.append(info)

    def build_session_info(self):
        """Refresh session metadata."""
        self.session_info = []
        for session in self.session_array:
            info = {
                'session_id': session.id(),
                'reference': session.reference,
                # Add more metadata
            }
            self.session_info.append(info)
```

### 6.5 Documentation System

**Directory**: `ndi-python/ndi/docs/`
**Files**: 7 new files
**Effort**: 5-6 hours

### 6.6 Internal Test Framework

**Directory**: `ndi-python/ndi/test/`
**Files**: 44 new files
**Effort**: 10-12 hours

### 6.7 Phase 6 Implementation Plan

**Week 8** (56 hours):
- Days 1-3: Setup/config (24h)
- Day 4: Mock objects (5h)
- Day 4-5: Examples (9h)
- Day 5: Dataset (8h)
- Day 6: Docs system (5h)
- Day 7: Test framework (5h)

---

## Testing Strategy

### Test Coverage Requirements

**Phase 1**: >95% coverage for Session and Document
**Phase 2**: >90% coverage for Database backends
**Phase 3**: >85% coverage for Utilities
**Phase 4**: >90% coverage for DAQ/Time
**Phase 5**: >80% coverage for Cloud
**Phase 6**: >75% coverage for Advanced

### Test Types

1. **Unit Tests** - Every method, every file
2. **Integration Tests** - Cross-component workflows
3. **System Tests** - End-to-end scenarios
4. **Compatibility Tests** - MATLAB equivalence
5. **Performance Tests** - Benchmarks vs MATLAB

### MATLAB Test Porting

Port corresponding MATLAB tests for each component:

**Current MATLAB Tests**: 49 test files
**Current Python Tests**: 12 test files
**Target**: 49+ test files

**Porting Priority**:
1. Phase 1: Port Session/Document tests
2. Phase 2: Port Database tests
3. Phase 3: Port Utility tests
4. Phase 4: Port DAQ/Time tests
5. Phase 5: Port Cloud tests (if applicable)
6. Phase 6: Port remaining tests

---

## Code Templates & Patterns

### Template 1: Basic Class Port

```python
"""
Module docstring - what this module does.

Ported from MATLAB: src/ndi/+ndi/+package/ClassName.m
"""

from typing import List, Optional, Union
# Other imports

class ClassName:
    """
    Brief class description.

    Longer description explaining purpose, usage, and key concepts.
    Matches MATLAB class: ndi.package.ClassName

    Attributes:
        property1: Description
        property2: Description

    Example:
        >>> obj = ClassName(param1)
        >>> result = obj.method1()
    """

    def __init__(self, param1: str, param2: int = 0):
        """
        Initialize ClassName.

        Args:
            param1: Description
            param2: Description (default: 0)

        Raises:
            ValueError: If param1 is invalid
        """
        self.property1 = param1
        self.property2 = param2

    def method1(self, arg1: str) -> bool:
        """
        Brief method description.

        Longer description of what the method does, matching
        MATLAB behavior.

        Args:
            arg1: Description

        Returns:
            Description of return value

        Raises:
            ValueError: When...

        Example:
            >>> obj.method1('test')
            True
        """
        # Implementation
        pass
```

### Template 2: Static Method Port

```python
@staticmethod
def static_method(arg1: str, arg2: int = 0) -> List[str]:
    """
    Static method description.

    MATLAB equivalent: ndi.package.ClassName.staticMethod()

    Args:
        arg1: Description
        arg2: Description (default: 0)

    Returns:
        List of results
    """
    # Implementation
    pass
```

### Template 3: Property with Getter/Setter

```python
@property
def property_name(self) -> str:
    """Get property description."""
    return self._property_name

@property_name.setter
def property_name(self, value: str) -> None:
    """
    Set property description.

    Args:
        value: New value

    Raises:
        ValueError: If value is invalid
    """
    if not value:
        raise ValueError("Property cannot be empty")
    self._property_name = value
```

### Template 4: Database Operation

```python
def database_operation(self, query: Query) -> List[Document]:
    """
    Perform database operation.

    Args:
        query: Search query

    Returns:
        List of matching documents

    Raises:
        DatabaseError: If operation fails
    """
    try:
        results = self.database.search(query)
        return results
    except Exception as e:
        raise DatabaseError(f"Operation failed: {e}") from e
```

---

## Migration Guide

### From Current State (25-30%) to Phase 1 Complete (40%)

**Breaking Changes**: None
**New Features**: Full Session/Document APIs
**Migration Steps**:
1. Update imports if methods moved
2. Test existing code - should work unchanged
3. Adopt new methods as needed

### From Phase 1 to Phase 2 (60%)

**Breaking Changes**: Database backend selection
**New Features**: SQLite, JSON backends
**Migration Steps**:
1. Choose backend in session initialization
2. Migrate existing DirectoryDatabase to chosen backend
3. Update database paths in configuration

### From Phase 2 to Phase 3 (70%)

**Breaking Changes**: Logging system changes
**New Features**: Full utility library
**Migration Steps**:
1. Replace ad-hoc logging with ndi.fun.console/errlog
2. Adopt new utility functions
3. Remove duplicate utility code

### From Phase 3 to Phase 4 (80%)

**Breaking Changes**: None
**New Features**: Complete DAQ/Time systems
**Migration Steps**:
1. Update DAQ reader instantiation
2. Use new time conversion utilities
3. Test time synchronization

### From Phase 4 to Phase 5 (90%)

**Breaking Changes**: Cloud API authentication
**New Features**: Full cloud integration
**Migration Steps**:
1. Set up cloud credentials
2. Configure sync strategy
3. Test cloud operations

### From Phase 5 to Phase 6 (100%)

**Breaking Changes**: None
**New Features**: All advanced features
**Migration Steps**:
1. Review setup configurations
2. Adopt lab-specific helpers if needed
3. Use mock objects for testing

---

## Quick Reference

### File Priority Matrix

| File/Module | Phase | Priority | Effort | Dependencies |
|-------------|-------|----------|--------|--------------|
| Session.daqsystem_rm | 1 | P0 | 1h | None |
| Session.validate_documents | 1 | P0 | 2h | validate module |
| Document.add_dependency_value_n | 1 | P0 | 1h | None |
| SQLiteDatabase | 2 | P0 | 20h | Phase 1 |
| MFDAQReader | 4 | P1 | 10h | Phase 1 |
| TwoWaySync | 5 | P2 | 12h | Phase 2 |
| Dataset | 6 | P3 | 8h | Phase 1 |

### Complexity Ratings

- **Low** (1-2h): Simple function ports, property additions
- **Medium** (3-6h): Standard class ports, moderate algorithms
- **High** (8-12h): Complex classes, intricate algorithms
- **Very High** (15-20h): Major subsystems, database backends

### Testing Time Estimates

- **Low complexity**: 30 min testing
- **Medium complexity**: 1h testing
- **High complexity**: 2h testing
- **Very High complexity**: 4h testing

### Recommended Development Order

**By Dependency**:
1. Phase 1 (enables everything)
2. Phase 3 (utilities needed by 2, 4, 5)
3. Phase 2 (databases needed by 5)
4. Phase 4 (DAQ/Time independent)
5. Phase 5 (cloud requires 1, 2)
6. Phase 6 (advanced uses everything)

**By Value**:
1. Phase 1 (40% -> most impact)
2. Phase 2 (20% -> databases critical)
3. Phase 4 (10% -> DAQ core feature)
4. Phase 3 (5% -> utilities helpful)
5. Phase 5 (5% -> cloud nice-to-have)
6. Phase 6 (5% -> advanced optional)

---

## Success Criteria

### Phase 1 Complete When:
- ✅ All 13 Session methods implemented
- ✅ All 12 Document methods implemented
- ✅ >95% test coverage
- ✅ All existing tests still pass
- ✅ New tests for new methods pass

### Phase 2 Complete When:
- ✅ SQLite backend working
- ✅ JSON backends working
- ✅ Top 20 database utilities ported
- ✅ >90% test coverage
- ✅ Performance tests pass

### Phase 3 Complete When:
- ✅ Top 15 ndi.fun utilities ported
- ✅ All ndi.util files complete
- ✅ All ndi.common files complete
- ✅ Logging system functional
- ✅ >85% test coverage

### Phase 4 Complete When:
- ✅ MFDAQ reader working
- ✅ NDR reader working
- ✅ All time utilities functional
- ✅ Time sync tests pass
- ✅ >90% test coverage

### Phase 5 Complete When:
- ✅ Two-way sync working
- ✅ Bulk operations functional
- ✅ Publishing/DOI working
- ✅ Cloud integration tests pass
- ✅ >80% test coverage

### Phase 6 Complete When:
- ✅ Setup system functional
- ✅ Mock objects working
- ✅ Examples run successfully
- ✅ Dataset management working
- ✅ Documentation system functional

### 100% Complete When:
- ✅ All 6 phases complete
- ✅ 198/198 tests passing (currently 162/198)
- ✅ >90% overall test coverage
- ✅ All MATLAB test equivalents ported
- ✅ Documentation updated and accurate
- ✅ Performance benchmarks acceptable
- ✅ Code review complete

---

## Maintenance & Evolution

### Version Control Strategy

**Branch**: `feature/100-percent-port`
**Commit Strategy**: One commit per completed file/module
**PR Strategy**: One PR per phase completion

### Documentation Updates

After each phase:
1. Update README.md with new features
2. Update IMPLEMENTATION_SUMMARY.md with progress
3. Update TEST_COVERAGE_MAPPING.md with new tests
4. Create release notes

### Performance Monitoring

Track performance vs MATLAB for:
- Document search time
- Database operations
- File I/O
- Time synchronization
- Cloud operations

Target: Within 20% of MATLAB performance

---

## Risk Mitigation

### Risk 1: MATLAB-Python Behavioral Differences

**Mitigation**:
- Extensive compatibility testing
- Port MATLAB tests exactly
- Document any unavoidable differences

### Risk 2: External Dependencies

**Mitigation**:
- Pin dependency versions
- Test with multiple Python versions
- Provide installation scripts

### Risk 3: Scope Creep

**Mitigation**:
- Stick to phase boundaries
- Defer non-critical features
- Regular progress reviews

### Risk 4: Testing Gaps

**Mitigation**:
- Require >90% coverage for P0/P1
- Port all MATLAB tests
- Add integration tests

---

## Resources & Tools

### Development Tools

- **IDE**: VS Code with Python extension
- **Testing**: pytest, pytest-cov
- **Linting**: pylint, mypy (type checking)
- **Formatting**: black, isort
- **Documentation**: Sphinx

### Reference Materials

- **MATLAB Source**: `src/ndi/+ndi/`
- **Current Python**: `ndi-python/ndi/`
- **MATLAB Docs**: https://vh-lab.github.io/NDI-matlab/
- **This Roadmap**: NDI_PYTHON_100_PERCENT_IMPLEMENTATION_ROADMAP.md

### Communication

- **Issues**: GitHub issue tracker
- **Questions**: Code comments with `# QUESTION:`
- **Decisions**: Code comments with `# DECISION:`

---

## Appendices

### Appendix A: Complete File Checklist

See separate document: `FILE_PORTING_CHECKLIST.md` (to be created)

### Appendix B: MATLAB-Python API Mappings

See separate document: `API_MAPPING_GUIDE.md` (to be created)

### Appendix C: Test Coverage Report

See: Current test report at `FINAL_TEST_REPORT.md`

### Appendix D: Known Issues & Workarounds

See: GitHub issues tagged `matlab-compatibility`

---

## Conclusion

This roadmap provides a comprehensive, phase-by-phase plan to achieve 100% feature parity between NDI-Python and NDI-MATLAB. By following this structured approach:

- **Total Time**: 240-320 hours (6-8 weeks full-time)
- **Incremental Value**: Each phase adds 10-20% functionality
- **Risk-Managed**: Dependencies clear, testing rigorous
- **Maintainable**: Well-documented, tested, reviewed

**Next Steps**:
1. Review and approve this roadmap
2. Set up development environment
3. Begin Phase 1: Complete Session class
4. Regular progress reviews after each phase

**Success Metric**: 100% of MATLAB features working in Python with >90% test coverage and acceptable performance.

---

**END OF ROADMAP**

*Document Version: 1.0*
*Last Updated: 2025-11-16*
*Maintainer: NDI-Python Development Team*
