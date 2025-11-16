"""
Tutorial 03: Dataset Management.

This tutorial demonstrates working with datasets - collections of sessions:
- Creating datasets
- Adding sessions to datasets (linked and ingested)
- Searching across multiple sessions
- Managing dataset metadata

This script is a code template - modify paths and parameters for your use.
"""

import tempfile
from pathlib import Path

from ndi.dataset.dir import Dir as DatasetDir
from ndi.session import SessionDir
from ndi.document import Document
from ndi.query import Query
from ndi.subject import Subject


def tutorial_dataset():
    """
    Demonstrate dataset operations.

    This example shows how to:
    1. Create a dataset
    2. Create multiple sessions
    3. Link sessions to the dataset
    4. Search across all sessions
    5. Manage dataset-level metadata
    """

    print("=" * 70)
    print("Tutorial 03: Dataset Management")
    print("=" * 70)

    # Step 1: Create a dataset
    dataset_path = tempfile.mkdtemp(prefix='ndi_dataset_')
    print(f"\nStep 1: Creating dataset at: {dataset_path}")

    dataset = DatasetDir('experiment_2024', dataset_path)
    print(f"Dataset ID: {dataset.id()}")
    print(f"Dataset reference: {dataset.session.reference}")

    # Step 2: Create multiple sessions
    print("\nStep 2: Creating experimental sessions")

    sessions = []
    temp_dir = Path(tempfile.mkdtemp(prefix='ndi_sessions_'))

    for i in range(3):
        # Create a session
        session_path = temp_dir / f'session_{i}'
        session = SessionDir(str(session_path), f'recording_{i}')

        # Add some data to each session
        subject = Subject(session, f'subject_{i % 2}')  # 2 subjects across 3 sessions
        session.database_add(subject.newdocument())

        # Add custom metadata
        metadata_doc = session.newdocument('base')
        metadata_doc.document_properties['recording'] = {
            'session_number': i,
            'date': f'2024-01-{i+10:02d}',
            'quality': 'good' if i % 2 == 0 else 'excellent'
        }
        session.database_add(metadata_doc)

        sessions.append(session)
        print(f"  Created session {i}: {session.reference}")

    # Step 3: Link sessions to the dataset
    print("\nStep 3: Linking sessions to dataset")

    for i, session in enumerate(sessions):
        dataset.add_linked_session(session)
        print(f"  Linked session {i}")

    # Step 4: Verify session list
    print("\nStep 4: Listing dataset sessions")

    refs, ids = dataset.session_list()
    print(f"Dataset contains {len(refs)} sessions:")
    for i, (ref, sid) in enumerate(zip(refs, ids)):
        print(f"  {i+1}. {ref} (ID: {sid[:16]}...)")

    # Step 5: Search across all sessions
    print("\nStep 5: Cross-session search")

    # Search for all subject documents across all sessions
    subject_query = Query('', 'isa', 'subject')
    all_subjects = dataset.database_search(subject_query)
    print(f"Found {len(all_subjects)} subject documents across all sessions")

    # Count unique subjects
    unique_subjects = set()
    for subj_doc in all_subjects:
        subj_id = subj_doc.document_properties.get('subject', {}).get('local_identifier', '')
        if subj_id:
            unique_subjects.add(subj_id)
    print(f"Unique subjects: {sorted(unique_subjects)}")

    # Step 6: Search for documents with specific properties
    print("\nStep 6: Advanced searching")

    # Note: More complex queries would require full implementation
    # This demonstrates the concept
    all_docs = dataset.database_search(Query('', 'isa', ''))
    print(f"Total documents in dataset: {len(all_docs)}")

    # Step 7: Add dataset-level metadata
    print("\nStep 7: Dataset-level metadata")

    dataset_metadata = dataset.session.newdocument('base')
    dataset_metadata.document_properties['experiment'] = {
        'name': 'Visual Cortex Recording Experiment',
        'pi': 'Dr. Smith',
        'description': 'Multi-session recordings from mouse visual cortex',
        'num_sessions': len(sessions)
    }
    dataset.database_add(dataset_metadata)
    print("Added dataset-level metadata")

    # Step 8: Open a specific session from the dataset
    print("\nStep 8: Opening sessions from dataset")

    first_session_id = ids[0]
    reopened_session = dataset.open_session(first_session_id)
    print(f"Reopened session: {reopened_session.reference}")

    # Step 9: Dataset persistence
    print("\nStep 9: Dataset persistence")

    print("Closing and reopening dataset...")
    dataset_id = dataset.id()

    # Create a new dataset object pointing to the same location
    dataset2 = DatasetDir(dataset_path)
    print(f"Reopened dataset ID: {dataset2.id()}")
    print(f"IDs match: {dataset_id == dataset2.id()}")

    refs2, ids2 = dataset2.session_list()
    print(f"Sessions still available: {len(refs2)}")

    print("\n" + "=" * 70)
    print("Tutorial complete!")
    print("\nKey concepts:")
    print("  - Datasets group multiple sessions")
    print("  - Linked sessions maintain separate storage")
    print("  - Ingested sessions copy data into dataset")
    print("  - Cross-session search enables multi-session analysis")
    print("  - Datasets persist and can be reopened")
    print("=" * 70)

    return dataset, dataset_path


def main():
    """Run the tutorial."""
    dataset, path = tutorial_dataset()

    # Clean up (uncomment if you want to remove the temporary dataset)
    # import shutil
    # shutil.rmtree(path, ignore_errors=True)
    # print(f"\nCleaned up dataset at {path}")


if __name__ == '__main__':
    main()
