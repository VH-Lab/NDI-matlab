"""
NDI App - Base class for NDI applications.

This module provides the base App class for creating NDI applications that
operate on sessions and create app documents.
"""

import platform
import sys
import subprocess
from typing import Optional, Any, Dict, List, Tuple
from .documentservice import DocumentService


class App(DocumentService):
    """
    Base class for NDI applications.

    An App is a program or algorithm that operates on an NDI session and
    creates documents to record its work. Apps can have associated
    version information and can create documents with app metadata.

    Attributes:
        session: The ndi.session object that the app operates on
        name: The name of the app

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> app = App(session, 'my_app')
        >>> app.name
        'my_app'
    """

    def __init__(self, session: Optional[Any] = None, name: str = 'generic'):
        """
        Create a new ndi.app object.

        Args:
            session: The ndi.session object that the app will operate on
            name: The name of the app (default: 'generic')

        Examples:
            >>> app = App(session, 'feature_extractor')
            >>> app.name
            'feature_extractor'
        """
        super().__init__()
        self.session = session
        self.name = name

    def varappname(self) -> str:
        """
        Return the name of the application for use in variable creation.

        Returns the name of the app modified for use as a variable name,
        either as a Python variable or a name in a document.

        Returns:
            Valid Python variable name based on app name

        Examples:
            >>> app = App(None, 'my-cool-app')
            >>> app.varappname()
            'my_cool_app'

            >>> app2 = App(None, '123invalid')
            >>> app2.varappname()
            'app_123invalid'
        """
        from .fun import name2variableName
        return name2variableName(self.name)

    def version_url(self) -> Tuple[str, str]:
        """
        Return the app version and url.

        In the base class, it is assumed that Git is used and is available
        from the command line, and the version and url are read from the
        git repository.

        Developers should override this method if they use a different
        version control system.

        Returns:
            Tuple of (version, url) strings

        Examples:
            >>> app = App(None, 'test_app')
            >>> version, url = app.version_url()
            >>> isinstance(version, str)
            True
            >>> isinstance(url, str)
            True
        """
        # Try to get git information
        try:
            # Get the directory of this class file
            import os
            import inspect
            class_file = inspect.getfile(self.__class__)
            parent_dir = os.path.dirname(os.path.abspath(class_file))

            # Try to get git commit hash
            try:
                result = subprocess.run(
                    ['git', '-C', parent_dir, 'rev-parse', 'HEAD'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    version = result.stdout.strip()
                else:
                    version = '$Format:%H$'
            except (subprocess.TimeoutExpired, FileNotFoundError):
                version = '$Format:%H$'

            # Try to get git remote url
            try:
                result = subprocess.run(
                    ['git', '-C', parent_dir, 'config', '--get', 'remote.origin.url'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    url = result.stdout.strip()
                else:
                    url = 'https://github.com/VH-Lab/NDI-matlab'
            except (subprocess.TimeoutExpired, FileNotFoundError):
                url = 'https://github.com/VH-Lab/NDI-matlab'

        except Exception:
            version = '$Format:%H$'
            url = 'https://github.com/VH-Lab/NDI-matlab'

        return version, url

    def searchquery(self) -> Dict[str, Any]:
        """
        Return a search query for an ndi.document related to this app.

        Returns a dict that allows the creation or searching of an
        ndi.database document for this app with field 'app' that has
        subfield 'name' equal to the app's varappname.

        Returns:
            Dictionary with search criteria

        Examples:
            >>> app = App(session, 'my_app')
            >>> query = app.searchquery()
            >>> 'app.name' in query
            True
        """
        if self.session is None:
            raise ValueError('App has no session, cannot create search query')

        return {
            'base.session_id': self.session.id(),
            'app.name': self.varappname()
        }

    def newdocument(self, document_type: str = 'app', **properties) -> Any:
        """
        Return a new database document based on this app.

        Creates a blank ndi.document object of type 'app'. The 'app.name'
        field is filled out with the name of this app's varappname(),
        along with version, OS, and interpreter information.

        Args:
            document_type: Type of document to create (default: 'app')
            **properties: Additional property name/value pairs

        Returns:
            ndi.document object with app metadata

        Examples:
            >>> app = App(session, 'my_app')
            >>> doc = app.newdocument()
            >>> doc.document_properties.app.name
            'my_app'
        """
        if self.session is None:
            raise ValueError('App has no session, cannot create document')

        # Get OS information
        os_name = platform.system()
        os_version = platform.release()

        # Get Python version
        python_version = f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}'

        # Get app version and URL
        version, url = self.version_url()

        # Build properties dictionary
        app_properties = {
            'app.name': self.name,
            'app.version': version,
            'app.url': url,
            'app.os': os_name,
            'app.os_version': os_version,
            'app.interpreter': 'Python',
            'app.interpreter_version': python_version
        }

        # Merge with additional properties
        app_properties.update(properties)

        # Create and return document
        return self.session.newdocument(document_type, **app_properties)
