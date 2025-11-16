"""Compare a local NDI dataset with its cloud counterpart.

Ported from: ndi.cloud.sync.validate (MATLAB)
"""

from typing import Tuple, Dict, List, Any, Literal, TYPE_CHECKING

from ndi.cloud.sync.internal.list_local_documents import list_local_documents
from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def validate(
    ndi_dataset: 'Dataset',
    mode: Literal["bulk", "serial"] = "bulk",
    verbose: bool = True,
    cloud_dataset_id: str = ""
) -> Tuple[Dict[str, Any], List[Dict], List[Dict]]:
    """Compare a local NDI dataset with its cloud counterpart.

    This function compares the documents of a local ndi.dataset object with
    the documents in its corresponding remote NDI cloud dataset. It identifies
    documents that exist only locally, only remotely, or on both, and for
    common documents, it checks if their content matches (excluding the 'files' field).

    Args:
        ndi_dataset: The local NDI dataset object to be validated against its
            remote counterpart
        mode: Specifies the comparison strategy. Default is "bulk".
            - "bulk": Downloads all remote documents in a single batch for
              comparison. This is generally faster, especially for datasets
              with many documents.
            - "serial": Downloads and compares each remote document one by one.
              This can be slower but may be useful for very large individual
              documents or for debugging.
        verbose: If True, detailed progress messages are printed to the console
        cloud_dataset_id: Cloud dataset ID (optional). If not provided, will be
            retrieved from the local dataset

    Returns:
        A tuple containing:
            - comparison_report: A dictionary summarizing the comparison results:
                - local_only_ids: List of NDI IDs found only in the local dataset
                - remote_only_ids: List of NDI IDs found only on the remote dataset
                - common_ids: List of NDI IDs found in both datasets
                - mismatched_ids: List of NDI IDs of common documents whose content
                  does not match
                - mismatch_details: List of dictionaries with details for each mismatch
            - local_comparison_structs: A list of the local document property
              structures for each mismatched document, ready for inspection
            - remote_comparison_structs: A list of the remote document property
              structures for each mismatched document, ready for inspection

    See also:
        ndi.cloud.sync_dataset
        ndi.cloud.download.download_document_collection
    """
    from ndi.cloud.internal.get_cloud_dataset_id_for_local_dataset import get_cloud_dataset_id_for_local_dataset
    from ndi.cloud.download.download_document_collection import download_document_collection
    from ndi.cloud.api.documents import get_document

    if verbose:
        print(f'Starting validation for dataset: {ndi_dataset.path}')

    # Initialize the report structure
    comparison_report = {
        'local_only_ids': [],
        'remote_only_ids': [],
        'common_ids': [],
        'mismatched_ids': [],
        'mismatch_details': []
    }

    # Initialize new outputs for debugging
    local_comparison_structs = []
    remote_comparison_structs = []

    # Step 1: Get the cloud dataset ID from the local dataset
    if not cloud_dataset_id:
        try:
            cloud_dataset_id = get_cloud_dataset_id_for_local_dataset(ndi_dataset)
            if verbose:
                print(f'Cloud Dataset ID: {cloud_dataset_id}')
        except Exception as e:
            raise RuntimeError(
                f'Could not retrieve cloud dataset ID. Ensure the local dataset is '
                f'linked to a remote one. Original error: {str(e)}'
            ) from e

    # Step 2: Get lists of local and remote documents
    if verbose:
        print('Fetching local and remote document lists...')

    local_docs, local_doc_ids = list_local_documents(ndi_dataset)
    remote_doc_id_map = list_remote_document_ids(cloud_dataset_id)
    remote_doc_ids = remote_doc_id_map['ndi_id']

    if verbose:
        print(f'Found {len(local_doc_ids)} local documents and {len(remote_doc_ids)} '
              f'remote documents.')

    # Step 3: Identify differences in document presence
    local_doc_ids_set = set(local_doc_ids)
    remote_doc_ids_set = set(remote_doc_ids)

    comparison_report['local_only_ids'] = sorted(local_doc_ids_set - remote_doc_ids_set)
    comparison_report['remote_only_ids'] = sorted(remote_doc_ids_set - local_doc_ids_set)

    # Find common IDs and their indices
    common_ids = sorted(local_doc_ids_set & remote_doc_ids_set)
    comparison_report['common_ids'] = common_ids

    # Create index maps
    local_id_to_idx = {doc_id: i for i, doc_id in enumerate(local_doc_ids)}
    remote_id_to_idx = {doc_id: i for i, doc_id in enumerate(remote_doc_ids)}

    local_common_indices = [local_id_to_idx[doc_id] for doc_id in common_ids]
    remote_common_indices = [remote_id_to_idx[doc_id] for doc_id in common_ids]

    if verbose:
        print(f'{len(comparison_report["local_only_ids"])} documents are local only.')
        print(f'{len(comparison_report["remote_only_ids"])} documents are remote only.')
        print(f'{len(comparison_report["common_ids"])} documents are common and will be compared.')

    if not comparison_report['common_ids']:
        if verbose:
            print('No common documents to compare. Validation complete.')
        return comparison_report, local_comparison_structs, remote_comparison_structs

    # Step 4: Compare common documents based on the selected mode
    common_local_docs = [local_docs[i] for i in local_common_indices]
    common_remote_api_ids = [remote_doc_id_map['api_id'][i] for i in remote_common_indices]

    mismatched_ids_list = []
    mismatch_details_list = []

    if mode == "bulk":
        if verbose:
            print('Starting comparison in BULK mode...')

        # Download all common remote documents at once
        if verbose:
            print(f'Downloading {len(common_remote_api_ids)} remote documents for comparison...')

        remote_docs_downloaded = download_document_collection(cloud_dataset_id, common_remote_api_ids)

        # Create a map for easy lookup
        remote_docs_map = {doc.id(): doc for doc in remote_docs_downloaded}

        for i, local_doc in enumerate(common_local_docs):
            ndi_id = local_doc.id()

            if ndi_id in remote_docs_map:
                remote_doc = remote_docs_map[ndi_id]

                # Prepare for comparison by removing 'files' and 'id' fields
                local_props = local_doc.document_properties.copy()
                remote_props = remote_doc.document_properties.copy()

                if 'files' in local_props:
                    del local_props['files']
                if 'files' in remote_props:
                    del remote_props['files']
                if 'id' in remote_props:
                    del remote_props['id']

                if local_props != remote_props:
                    mismatched_ids_list.append(ndi_id)
                    mismatch_details_list.append({
                        'ndiId': ndi_id,
                        'apiId': common_remote_api_ids[i],
                        'reason': 'Document properties do not match.'
                    })
                    # Capture structs for debugging
                    local_comparison_structs.append(local_props)
                    remote_comparison_structs.append(remote_props)
            else:
                mismatched_ids_list.append(ndi_id)
                mismatch_details_list.append({
                    'ndiId': ndi_id,
                    'apiId': common_remote_api_ids[i],
                    'reason': 'Remote document could not be found in bulk download.'
                })

    elif mode == "serial":
        if verbose:
            print('Starting comparison in SERIAL mode...')

        for i, ndi_id in enumerate(comparison_report['common_ids']):
            api_id = common_remote_api_ids[i]

            if verbose:
                print(f'Comparing document {i+1}/{len(comparison_report["common_ids"])}: {ndi_id}')

            success, remote_doc_struct = get_document(cloud_dataset_id, api_id)
            if not success:
                mismatched_ids_list.append(ndi_id)
                mismatch_details_list.append({
                    'ndiId': ndi_id,
                    'apiId': api_id,
                    'reason': 'Failed to retrieve remote document.'
                })
                continue

            local_doc = common_local_docs[i]

            # Prepare for comparison
            local_props = local_doc.document_properties.copy()
            remote_props = remote_doc_struct.copy()

            if 'files' in local_props:
                del local_props['files']
            if 'files' in remote_props:
                del remote_props['files']
            if 'id' in remote_props:
                del remote_props['id']

            if local_props != remote_props:
                mismatched_ids_list.append(ndi_id)
                mismatch_details_list.append({
                    'ndiId': ndi_id,
                    'apiId': api_id,
                    'reason': 'Document properties do not match.'
                })
                # Capture structs for debugging
                local_comparison_structs.append(local_props)
                remote_comparison_structs.append(remote_props)

    if mismatched_ids_list:
        comparison_report['mismatched_ids'] = mismatched_ids_list
        comparison_report['mismatch_details'] = mismatch_details_list

    if verbose:
        print(f'{len(comparison_report["mismatched_ids"])} mismatched documents found.')
        print('Validation complete.')

    return comparison_report, local_comparison_structs, remote_comparison_structs
