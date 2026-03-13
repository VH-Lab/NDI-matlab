# NDI Symmetry Artifacts Instructions

This folder contains MATLAB unit tests whose purpose is to generate standard NDI artifacts for symmetry testing with other NDI language ports (e.g., Python).

## Rules for `makeArtifacts` tests:

1. **Artifact Location**: Tests must store their generated artifacts in the system's temporary directory (`tempdir`).
2. **Directory Structure**: Inside the temporary directory, artifacts must be placed in a specific nested folder structure:
   `NDI/symmetryTest/matlabArtifacts/<namespace>/<class_name>/<test_name>/`

   - `<namespace>`: The last part of the MATLAB package namespace. For example, for a test located at `tests/+ndi/+symmetry/+makeArtifacts/+session`, the namespace is `session`.
   - `<class_name>`: The name of the test class (e.g., `buildSession`).
   - `<test_name>`: The specific name of the test method being executed (e.g., `testBuildSessionArtifacts`).

## Example:
For a test class `buildSession.m` in `tests/+ndi/+symmetry/+makeArtifacts/+session` with a test method `testBuildSessionArtifacts`, the artifacts should be saved to:
`[tempdir(), 'NDI/symmetryTest/matlabArtifacts/session/buildSession/testBuildSessionArtifacts/']`