# NDI-Python

**Neuroscience Data Interface - Python Implementation**

This is a Python port of the NDI-matlab system, providing format-independent access to neuroscience data and analysis results.

## About

NDI (Neuroscience Data Interface) is a cross-platform interface standard for reading neuroscience data and storing the results of analyses. This Python implementation maintains full compatibility with the MATLAB version.

## Installation

```bash
pip install -e .
```

## Features

- **Format-Independent Data Access**: Read data regardless of file format or organization
- **NoSQL Document Database**: Flexible, schema-less data storage with dependency tracking
- **Multi-Clock Time Synchronization**: Handle multiple concurrent time references
- **Epoch-Based Organization**: Organize data into temporal epochs
- **Hardware Abstraction**: Work with various DAQ systems through a unified interface
- **Analysis Pipelines**: Build reproducible analysis workflows
- **Cloud Integration**: Sync data with cloud storage

## Core Concepts

- **Session**: A collection of recordings or measurements taken at one sitting
- **Probe**: Any instrument that makes a measurement or provides stimulation
- **Element**: Physical or logical measurement/stimulation elements
- **Subject**: The object being sampled (animal, human, test resistor, etc.)
- **Epoch**: An interval of time during which a DAQ system records data
- **Document**: Unit of storage in the NoSQL database

## Quick Start

```python
import ndi

# Create or open a session
session = ndi.session.dir('/path/to/data', 'my_experiment')

# Search for documents
results = session.database_search(ndi.query('base.name', 'exact_string', 'my_probe'))

# Access probes
probes = session.getprobes()
```

## Documentation

Full documentation is available at: https://vh-lab.github.io/NDI-matlab/

## Citation

If you use NDI in your research, please cite:

Van Hooser SD, et al. (2022) NDI: A Platform-Independent Data Interface and Database for Neuroscience Physiology and Imaging Experiments. eNeuro 9(1):ENEURO.0073-21.2022

## License

[Include appropriate license information]

## Development Status

This is an active port of the MATLAB version. API compatibility is maintained where possible, with Pythonic idioms where appropriate.
