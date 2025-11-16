"""SyncOptions class for controlling sync behavior.

Ported from: ndi.cloud.sync.SyncOptions (MATLAB)
"""

from typing import Dict, Any, Literal


class SyncOptions:
    """Options class for controlling sync behavior.

    This class defines a set of configurable options used when performing
    dataset synchronization tasks, i.e document synchronization.

    This class is meant to be used in argument blocks of various sync
    functions in order to provide a reusable set of sync options.

    Attributes:
        sync_files: If True, files will be synced (default: False)
        verbose: If True, verbose output is printed (default: True)
        dry_run: If True, actions are simulated but not performed (default: False)
        file_upload_strategy: "serial" to upload files one by one or "batch"
            (default) to upload bundles of files using zip files. The "batch"
            option is recommended when uploading many files, and the serial
            option can be used as a fallback if batch upload fails.
    """

    def __init__(
        self,
        sync_files: bool = False,
        verbose: bool = True,
        dry_run: bool = False,
        file_upload_strategy: Literal["serial", "batch"] = "batch",
        **kwargs
    ) -> None:
        """Construct a new SyncOptions object.

        Args:
            sync_files: Whether to sync file portion (binary data) of documents
            verbose: Whether to print verbose output
            dry_run: Simulate actions without executing
            file_upload_strategy: Upload strategy ("serial" or "batch")
            **kwargs: Additional options to set from a dictionary

        Raises:
            ValueError: If file_upload_strategy is not "serial" or "batch"
        """
        if file_upload_strategy not in ("serial", "batch"):
            raise ValueError(
                f"file_upload_strategy must be 'serial' or 'batch', "
                f"got '{file_upload_strategy}'"
            )

        self.sync_files = sync_files
        self.verbose = verbose
        self.dry_run = dry_run
        self.file_upload_strategy = file_upload_strategy

        # Set any additional options from kwargs
        for key, value in kwargs.items():
            # Convert camelCase to snake_case
            snake_key = self._camel_to_snake(key)
            if hasattr(self, snake_key):
                setattr(self, snake_key, value)

    @staticmethod
    def _camel_to_snake(name: str) -> str:
        """Convert camelCase to snake_case.

        Args:
            name: The camelCase name

        Returns:
            The snake_case name
        """
        import re
        name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).lower()

    def to_dict(self) -> Dict[str, Any]:
        """Convert properties to a dictionary.

        Returns:
            A dictionary containing the property names and values of the object,
            suitable for use as keyword arguments in other functions.

        Example:
            >>> opts = SyncOptions(sync_files=True, verbose=False)
            >>> some_function(**opts.to_dict())
        """
        return {
            'sync_files': self.sync_files,
            'verbose': self.verbose,
            'dry_run': self.dry_run,
            'file_upload_strategy': self.file_upload_strategy
        }

    def __repr__(self) -> str:
        """Return a string representation of the SyncOptions object."""
        return (
            f"SyncOptions(sync_files={self.sync_files}, verbose={self.verbose}, "
            f"dry_run={self.dry_run}, file_upload_strategy='{self.file_upload_strategy}')"
        )
