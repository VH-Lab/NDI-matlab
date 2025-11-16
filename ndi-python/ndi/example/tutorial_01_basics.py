"""
Tutorial 01: NDI Basics - Sessions, Documents, and Database.

This tutorial demonstrates the fundamental concepts of NDI:
- Creating and managing sessions
- Creating and storing documents
- Searching the database
- Working with session metadata

This script is a code template - modify the paths and parameters for your use.
"""

import tempfile
from pathlib import Path

# Import NDI classes
from ndi.session import SessionDir
from ndi.document import Document
from ndi.query import Query
from ndi.subject import Subject


def tutorial_basics():
    """
    Demonstrate basic NDI session operations.

    This example shows how to:
    1. Create a new session
    2. Add metadata (subject information)
    3. Create and add custom documents
    4. Search the database
    5. Retrieve documents
    """

    print("=" * 70)
    print("Tutorial 01: NDI Basics - Sessions, Documents, and Database")
    print("=" * 70)

    # Step 1: Create a session
    # In practice, replace with your actual data directory
    session_path = tempfile.mkdtemp(prefix='ndi_tutorial_')
    print(f"\nStep 1: Creating session at: {session_path}")

    session = SessionDir(session_path, 'tutorial_session')
    print(f"Session ID: {session.id()}")
    print(f"Session reference: {session.reference}")

    # Step 2: Add a subject to the session
    print("\nStep 2: Adding subject information")

    subject = Subject(session, 'subject_001', species='mouse', age='P30')
    subject_doc = subject.newdocument()
    session.database_add(subject_doc)
    print(f"Added subject: subject_001 (mouse, P30)")

    # Step 3: Create and add a custom document
    print("\nStep 3: Creating custom documents")

    # Create a base document
    doc = session.newdocument('base')

    # You can add custom properties
    doc.document_properties['custom'] = {
        'experiment_name': 'my_experiment',
        'notes': 'This is a test experiment',
        'recording_quality': 'good'
    }

    session.database_add(doc)
    print(f"Added custom document with ID: {doc.id()[:16]}...")

    # Step 4: Search the database
    print("\nStep 4: Searching the database")

    # Search for all documents
    all_docs = session.database_search(Query('', 'isa', ''))
    print(f"Total documents in session: {len(all_docs)}")

    # Search for subject documents
    subject_query = Query('', 'isa', 'subject')
    subjects = session.database_search(subject_query)
    print(f"Subject documents found: {len(subjects)}")

    # Search for a specific field
    name_query = Query('subject.local_identifier', 'exact_string', 'subject_001')
    named_subjects = session.database_search(name_query)
    if named_subjects:
        print(f"Found subject with ID 'subject_001'")

    # Step 5: Retrieve and examine documents
    print("\nStep 5: Retrieving document details")

    if subjects:
        subj = subjects[0]
        print(f"Subject document ID: {subj.id()[:16]}...")
        print(f"Subject properties: {subj.document_properties.get('subject', {})}")

    # Step 6: Remove documents (optional)
    print("\nStep 6: Removing documents")

    # You can remove documents by ID or by the document itself
    # session.database_rm(doc)
    # print(f"Removed document")

    # Step 7: Session cleanup
    print("\nStep 7: Summary")
    final_count = len(session.database_search(Query('', 'isa', '')))
    print(f"Final document count: {final_count}")

    print("\n" + "=" * 70)
    print("Tutorial complete!")
    print(f"Session data stored at: {session_path}")
    print("=" * 70)

    return session, session_path


def main():
    """Run the tutorial."""
    session, path = tutorial_basics()

    # Clean up (uncomment if you want to remove the temporary session)
    # import shutil
    # shutil.rmtree(path, ignore_errors=True)
    # print(f"\nCleaned up session at {path}")


if __name__ == '__main__':
    main()
