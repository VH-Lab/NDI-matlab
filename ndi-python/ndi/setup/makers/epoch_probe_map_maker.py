"""
NDI Epoch Probe Map Maker - Create epoch probe map files for NDI sessions.

This module provides EpochProbeMapMaker class for automating the generation
of '.epochprobemap.txt' files that map experimental epochs to data acquisition
probes and devices.
"""

from typing import List, Dict, Any, Optional, Union
import os
import logging
import pandas as pd
import numpy as np


class EpochProbeMapMaker:
    """
    Creates or updates epoch probe map files for NDI sessions.

    The EpochProbeMapMaker class automates the generation of '.epochprobemap.txt'
    files. These files map experimental epochs to data acquisition probes and devices.
    The class takes a base path (typically an NDI session directory), a table
    defining epoch-specific variables, and a table defining probe characteristics.

    Attributes:
        path (str): Base directory path where session folders are located.
        variable_table (pd.DataFrame): Input table containing epoch definition information.
                                       Must contain 'SubjectString' column and row names.
        probe_table (pd.DataFrame): Input table containing probe characteristics.
                                   Must contain 'name', 'reference', 'type', 'deviceString' columns.

    Example:
        >>> import pandas as pd
        >>> from ndi.setup.makers import EpochProbeMapMaker
        >>>
        >>> # Create variable table with epoch information
        >>> var_data = {
        ...     'SubjectString': ['subject_001', 'subject_001'],
        ... }
        >>> variable_table = pd.DataFrame(var_data, index=['epoch1', 'epoch2'])
        >>>
        >>> # Create probe table
        >>> probe_data = {
        ...     'name': ['probe1', 'probe2'],
        ...     'reference': [1, 2],
        ...     'type': ['electrode', 'electrode'],
        ...     'deviceString': ['dev1', 'dev2']
        ... }
        >>> probe_table = pd.DataFrame(probe_data)
        >>>
        >>> # Create epoch probe maps
        >>> maker = EpochProbeMapMaker('/path/to/session', variable_table, probe_table)
    """

    def __init__(self,
                 path: str,
                 variable_table: pd.DataFrame,
                 probe_table: pd.DataFrame,
                 overwrite: bool = False,
                 non_nan_variable_names: Optional[List[str]] = None,
                 probe_postfix: Union[str, List[str], None] = None,
                 show_progress: bool = True):
        """
        Initialize EpochProbeMapMaker and create epoch probe map files.

        Args:
            path: The absolute path to an NDI session directory where
                  '.epochprobemap.txt' files will be saved.
            variable_table: A DataFrame defining epoch-specific variables.
                           Index values serve as base filenames for output files.
                           Must contain a 'SubjectString' column.
            probe_table: A DataFrame defining probe characteristics. Must contain:
                        - 'name': Name of the probe
                        - 'reference': Reference number of the probe
                        - 'type': Type of the probe
                        - 'deviceString': Device string associated with the probe
            overwrite: If True, existing epoch probe maps will be overwritten.
                      Default: False.
            non_nan_variable_names: Column names in variable_table whose values
                                   must not be NaN for valid epoch. Default: None.
            probe_postfix: Optional postfix to append to probe names. Can be:
                          - String: Applied to all probes
                          - List[str]: One per probe or per epoch
                          Default: None.
            show_progress: Whether to display progress. Default: True.

        Raises:
            ValueError: If required columns are missing or path doesn't exist.
        """
        from ...util.table import identify_valid_rows
        from ...gui import ProgressTracker, ConsoleProgressMonitor

        # Validate inputs
        if not os.path.isdir(path):
            raise ValueError(f"Path does not exist: {path}")

        if 'SubjectString' not in variable_table.columns:
            raise ValueError("variable_table must contain 'SubjectString' column")

        required_probe_cols = ['name', 'reference', 'type', 'deviceString']
        missing_cols = [col for col in required_probe_cols if col not in probe_table.columns]
        if missing_cols:
            raise ValueError(f"probe_table missing required columns: {', '.join(missing_cols)}")

        # Assign properties
        self.path = path
        self.variable_table = variable_table
        self.probe_table = probe_table

        # Get valid epoch rows
        if non_nan_variable_names is None:
            non_nan_variable_names = []

        valid_ind = identify_valid_rows(variable_table, non_nan_variable_names)

        if not any(valid_ind):
            logging.warning('No valid epochs found in variable_table. No epoch probe maps will be created.')
            return

        # Get valid indices
        valid_indices = np.where(valid_ind)[0]

        # Get epoch identifiers from index (row names)
        if variable_table.index.name is None and all(isinstance(idx, int) for idx in variable_table.index):
            # Default integer index - use row number
            epoch_ids = [f"epoch_{i}" for i in valid_indices]
        else:
            # Use actual index values
            epoch_ids = [variable_table.index[i] for i in valid_indices]

        logging.info(f"Creating epoch probe map files for {len(epoch_ids)} epoch(s)...")

        # Setup progress monitoring
        progress_tracker = None
        progress_monitor = None
        if show_progress and len(epoch_ids) > 0:
            progress_tracker = ProgressTracker()
            progress_monitor = ConsoleProgressMonitor("Creating Epoch Probe Map(s)", tracker=progress_tracker)
            progress_tracker.start()

        # Process each valid epoch
        for idx, epoch_idx in enumerate(valid_indices):
            epoch_id = epoch_ids[idx]

            # Construct the full filename for the epoch probe map file
            probe_filename = os.path.join(path, f"{epoch_id}.epochprobemap.txt")

            # Skip if not overwriting and file exists
            if not overwrite and os.path.exists(probe_filename):
                logging.debug(f"Epoch {idx+1}/{len(epoch_ids)}: Skipping existing '{epoch_id}'")
                continue

            # Create probe map entries for this epoch
            probe_map_entries = []

            for p in range(len(probe_table)):
                probe_name = probe_table.iloc[p]['name']

                # Apply probe postfix if provided
                if probe_postfix is not None:
                    if isinstance(probe_postfix, str):
                        # Check if it's a variable name in variable_table
                        if probe_postfix in variable_table.columns:
                            postfix_value = variable_table.iloc[epoch_idx][probe_postfix]
                            if postfix_value is not None and postfix_value != '':
                                probe_name = f"{probe_name}{postfix_value}"
                        else:
                            # Use as literal string
                            probe_name = f"{probe_name}{probe_postfix}"

                    elif isinstance(probe_postfix, list):
                        # Multiple postfix options
                        if len(probe_postfix) == len(variable_table):
                            # One per epoch
                            postfix_value = probe_postfix[epoch_idx]
                            if postfix_value:
                                probe_name = f"{probe_name}{postfix_value}"
                        elif len(probe_postfix) == len(probe_table):
                            # One per probe
                            postfix_value = probe_postfix[p]
                            if postfix_value:
                                # Check if it's a variable name
                                if postfix_value in variable_table.columns:
                                    var_value = variable_table.iloc[epoch_idx][postfix_value]
                                    if var_value is not None and var_value != '':
                                        probe_name = f"{probe_name}{var_value}"
                                else:
                                    probe_name = f"{probe_name}{postfix_value}"
                        else:
                            logging.warning(f"probe_postfix length ({len(probe_postfix)}) doesn't match "
                                          f"epochs ({len(variable_table)}) or probes ({len(probe_table)})")

                # Get probe information
                probe_ref = probe_table.iloc[p]['reference']
                probe_type = probe_table.iloc[p]['type']
                device_string = probe_table.iloc[p]['deviceString']
                subject_string = variable_table.iloc[epoch_idx]['SubjectString']

                # Create probe map entry
                # Format: name reference type deviceString subjectString
                entry = f"{probe_name}\t{probe_ref}\t{probe_type}\t{device_string}\t{subject_string}"
                probe_map_entries.append(entry)

            # Write the epoch probe map file
            try:
                with open(probe_filename, 'w') as f:
                    f.write('\n'.join(probe_map_entries))
                    f.write('\n')  # End with newline

                logging.info(f"Epoch {idx+1}/{len(epoch_ids)}: Created '{epoch_id}.epochprobemap.txt' "
                           f"with {len(probe_map_entries)} probe(s)")

            except Exception as e:
                logging.error(f"Failed to write epoch probe map file '{probe_filename}': {e}")

            # Update progress
            if progress_tracker:
                progress_tracker.update_progress(
                    (idx + 1) / len(epoch_ids),
                    f"Epoch {idx+1}/{len(epoch_ids)}: {epoch_id}"
                )

        # Mark progress complete
        if progress_tracker:
            progress_tracker.mark_complete()

        logging.info(f"Completed epoch probe map creation for {len(epoch_ids)} epoch(s)")

    def __repr__(self) -> str:
        """String representation of EpochProbeMapMaker."""
        return (f"EpochProbeMapMaker(path='{self.path}', "
                f"epochs={len(self.variable_table)}, "
                f"probes={len(self.probe_table)})")
