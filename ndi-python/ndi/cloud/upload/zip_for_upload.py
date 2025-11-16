"""
Create and upload zip files in batches to the NDI cloud.

This module provides functionality to batch binary files into zip archives
and upload them to NDI Cloud with retry logic and progress tracking.

MATLAB Source: ndi/+ndi/+cloud/+upload/zipForUpload.m
"""

import os
import time
import zipfile
import tempfile
import warnings
from typing import List, Dict, Tuple, Any, Optional
from pathlib import Path


def zip_for_upload(
    database: 'ndi.database',
    doc_file_struct: List[Dict[str, Any]],
    total_size: float,
    dataset_id: str,
    verbose: bool = True,
    size_limit: int = 50_000_000,  # 50 MB default
    debug_log: bool = True,
    number_retries: int = 3
) -> Tuple[bool, str]:
    """
    Create and upload zip files in batches to the NDI cloud.

    This function batches binary files into zip archives based on a size limit,
    then uploads each batch to the cloud. It includes retry logic for robustness
    and optional logging for debugging.

    Args:
        database: The ndi.database object (or session with path attribute)
        doc_file_struct: A list of dictionaries with file information containing:
            - 'uid': File unique identifier
            - 'name': File name
            - 'docid': Associated document ID
            - 'bytes': File size in bytes
            - 'is_uploaded': Whether file is already uploaded
        total_size: The total size of all files to be uploaded (in KB).
                   Note: This parameter is kept for compatibility but not used
                   for progress calculation
        dataset_id: The dataset ID for the upload
        verbose: If True, print detailed progress information. Defaults to True
        size_limit: The maximum size of each zip file batch in bytes.
                   Defaults to 50 MB (50e6)
        debug_log: If True, enable logging of zipped files. Defaults to True
        number_retries: Number of retry attempts for failed operations.
                       Defaults to 3

    Returns:
        A tuple containing:
        - success (bool): True if all files were successfully uploaded, False otherwise
        - msg (str): An error message if the operation failed; otherwise empty string

    Example:
        >>> from ndi.cloud.upload import zip_for_upload
        >>> # Assuming you have scanned for files
        >>> doc_structs, file_structs, total_kb = scan_for_upload(session, docs, False, "dataset123")
        >>> success, msg = zip_for_upload(
        ...     session, file_structs, total_kb, "dataset123",
        ...     verbose=True, size_limit=25_000_000
        ... )
        >>> if success:
        ...     print("All files uploaded successfully")
        >>> else:
        ...     print(f"Upload failed: {msg}")

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+upload/zipForUpload.m
    """
    msg = ''
    success = True

    # Filter files that haven't been uploaded yet
    files_to_process = [f for f in doc_file_struct if not f.get('is_uploaded', False)]
    files_left = len(files_to_process)
    files_uploaded_count = 0

    # Get base directory for files
    if hasattr(database, 'path'):
        base_dir = os.path.join(database.path, '.ndi', 'files')
    else:
        base_dir = ''
        if verbose:
            print("WARNING: Could not determine base directory for files")

    skipped_files = []

    if verbose:
        print(f'Beginning upload process. {files_left} files to upload.')

    # --- Log File Initialization ---
    if debug_log:
        # TODO: Implement PathConstants.LogFolder
        # For now, use temp directory
        log_folder = tempfile.gettempdir()
        os.makedirs(log_folder, exist_ok=True)

        # Create/clear log files
        log_files = {
            'zip_log.csv': 'ZipFile,ZippedFile,UncompressedBytes\n',
            'processed_log.csv': 'TotalProcessedBytes\n',
            'skipped_log.csv': 'SkippedFile,UID\n'
        }

        for log_file, header in log_files.items():
            log_path = os.path.join(log_folder, log_file)
            try:
                with open(log_path, 'w') as f:
                    f.write(header)
            except IOError:
                warnings.warn(f'Could not create log file: {log_file}')

    # Track which files have been processed
    file_processed = [False] * len(files_to_process)

    # --- Main Loop: Continue until all files are processed ---
    while not all(file_processed):
        current_batch_size = 0
        files_for_current_batch = []
        indices_for_current_batch = []

        # --- Inner Loop: Find files that fit into the current batch ---
        for i, current_file in enumerate(files_to_process):
            if not file_processed[i]:
                file_path = os.path.join(base_dir, current_file['uid'])
                file_bytes = current_file['bytes']

                # --- Check if file exists on disk ---
                if not os.path.isfile(file_path):
                    if verbose:
                        warnings.warn(f"File {current_file['name']} (UID: {current_file['uid']}) "
                                    f"not found on disk. Skipping.")
                    skipped_files.append(current_file)
                    file_processed[i] = True
                    continue

                # --- Batching Logic ---
                if current_batch_size + file_bytes <= size_limit:
                    files_for_current_batch.append(file_path)
                    current_batch_size += file_bytes
                    indices_for_current_batch.append(i)

        # --- Upload the batch if it contains any files ---
        if files_for_current_batch:
            batch_success, batch_msg, uploaded_count = _zip_and_upload_batch(
                files_for_current_batch,
                dataset_id,
                number_retries,
                verbose=verbose,
                debug_log=debug_log,
                log_folder=log_folder if debug_log else None
            )
            files_uploaded_count += uploaded_count

            if batch_success:
                # Mark files as processed
                for idx in indices_for_current_batch:
                    file_processed[idx] = True
            else:
                success = False
                files_not_uploaded = files_left - sum(file_processed)
                msg = (f'{batch_msg}\n{files_uploaded_count} files were successfully uploaded. '
                      f'{files_not_uploaded} files were not uploaded.')
                return success, msg
        else:
            # No files could be added to a batch, check for oversized files
            unprocessed_files = [files_to_process[i] for i, processed in enumerate(file_processed)
                               if not processed]

            for unprocessed_file in unprocessed_files:
                if unprocessed_file['bytes'] > size_limit:
                    warnings.warn(f"File {unprocessed_file['name']} (UID: {unprocessed_file['uid']}) "
                                f"is larger than the size limit and cannot be uploaded.")
                    skipped_files.append(unprocessed_file)

                    # Find the original index to mark it as processed
                    for i, f in enumerate(files_to_process):
                        if f['uid'] == unprocessed_file['uid']:
                            file_processed[i] = True
                            break

            # If there are still unprocessed files, it's an unexpected state
            if not all(file_processed):
                msg = 'An unexpected error occurred: unable to process remaining files.'
                success = False
                return success, msg

        # --- Update Progress ---
        if verbose:
            progress = sum(file_processed) / files_left if files_left > 0 else 1.0
            print(f'Processed {sum(file_processed)} of {files_left} files '
                  f'({progress*100:.1f}%)...')

    # --- Final Logging ---
    if debug_log and skipped_files:
        skipped_log_file = os.path.join(log_folder, 'skipped_log.csv')
        try:
            with open(skipped_log_file, 'a') as f:
                for skipped in skipped_files:
                    f.write(f'"{skipped["name"]}","{skipped["uid"]}"\n')
        except IOError:
            pass

    if verbose:
        print(f'Upload process finished. {files_uploaded_count} files were included in upload batches.')

    return success, msg


def _zip_and_upload_batch(
    files_to_zip: List[str],
    dataset_id: str,
    number_retries: int,
    verbose: bool = True,
    debug_log: bool = False,
    log_folder: Optional[str] = None
) -> Tuple[bool, str, int]:
    """
    Helper function to zip and upload a batch of files.

    Args:
        files_to_zip: List of file paths to include in the zip
        dataset_id: The dataset ID for the upload
        number_retries: Number of retry attempts for failed operations
        verbose: If True, print progress information
        debug_log: If True, log zipped files
        log_folder: Path to log folder (required if debug_log is True)

    Returns:
        A tuple containing:
        - success (bool): True if upload succeeded
        - msg (str): Error message if failed, otherwise empty
        - file_count (int): Number of files in the batch
    """
    success = True
    msg = ''
    file_count = len(files_to_zip)

    # Create temporary zip file
    temp_dir = tempfile.gettempdir()
    zip_filename = f"{dataset_id}.{os.urandom(8).hex()}.zip"
    zip_file = os.path.join(temp_dir, zip_filename)

    try:
        if verbose:
            batch_size_bytes = sum(os.path.getsize(f) for f in files_to_zip)
            print(f'Zipping {file_count} files ({batch_size_bytes / 1e6:.2f} MB) for upload...')

        # Create zip file
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for file_path in files_to_zip:
                arcname = os.path.basename(file_path)
                zipf.write(file_path, arcname=arcname)

        # Log zipped files
        if debug_log and log_folder:
            log_file = os.path.join(log_folder, 'zip_log.csv')
            try:
                with open(log_file, 'a') as f:
                    for file_path in files_to_zip:
                        file_size = os.path.getsize(file_path)
                        f.write(f'"{zip_filename}","{file_path}",{file_size}\n')
            except IOError:
                pass

        if verbose:
            print('Getting upload URL for zipped batch...')

        # TODO: Implement get_file_collection_upload_url function
        # This should be added to ndi.cloud.api.files module
        upload_url = ''
        for attempt in range(number_retries):
            # MATLAB code:
            # [success, upload_url_or_err] = ndi.cloud.api.files.getFileCollectionUploadURL(dataset_id)
            # if success:
            #     upload_url = upload_url_or_err
            #     break

            # Placeholder
            success = False
            upload_url_or_err = {'message': 'get_file_collection_upload_url not yet implemented'}

            if success:
                upload_url = upload_url_or_err
                break
            else:
                if verbose:
                    print(f'Attempt {attempt + 1} of {number_retries} to get upload URL failed. '
                          f'Retrying in 5s...')
                time.sleep(5)

        if not success:
            error_msg = upload_url_or_err.get('message', 'Unknown error') if isinstance(upload_url_or_err, dict) else str(upload_url_or_err)
            msg = f'Failed to get upload URL after {number_retries} attempts: {error_msg}'
            raise RuntimeError(msg)

        if verbose:
            print('Uploading zip archive...')

        # TODO: Implement put_files function
        # This should be added to ndi.cloud.api.files module
        for attempt in range(number_retries):
            # MATLAB code:
            # [success, err] = ndi.cloud.api.files.putFiles(upload_url, zip_file)
            # if success:
            #     break

            # Placeholder
            success = False
            err = {'message': 'put_files not yet implemented'}

            if success:
                break
            else:
                if verbose:
                    print(f'Attempt {attempt + 1} of {number_retries} to upload file failed. '
                          f'Retrying in 5s...')
                time.sleep(5)

        if not success:
            error_msg = err.get('message', 'Unknown error') if isinstance(err, dict) else str(err)
            msg = f'Failed to upload file after {number_retries} attempts: {error_msg}'
            raise RuntimeError(msg)

    except Exception as e:
        success = False
        msg = f'An error occurred during the zip/upload process: {str(e)}'

    finally:
        # Clean up zip file
        if os.path.isfile(zip_file):
            os.remove(zip_file)

    if verbose and success:
        print('Batch upload successful.')

    return success, msg, file_count
