"""Setup script for NDI-Python."""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="ndi-python",
    version="2.0.0",
    author="NDI Development Team",
    author_email="",
    description="Neuroscience Data Interface - Python Implementation",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/VH-Lab/NDI-python",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "Topic :: Scientific/Engineering :: Bio-Informatics",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=[
        "numpy>=1.20.0",
        "scipy>=1.7.0",
        "pandas>=1.3.0",
        "jsonschema>=4.0.0",
        "python-dateutil>=2.8.0",
        "tinydb>=4.7.0",  # Lightweight NoSQL database
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=3.0.0",
            "black>=22.0.0",
            "flake8>=4.0.0",
            "mypy>=0.950",
        ],
        "cloud": [
            "requests>=2.27.0",
            "boto3>=1.20.0",  # AWS S3 support
        ],
    },
)
