# Instructions for AI Agents

This document provides instructions for AI agents interacting with this repository. Please adhere to these guidelines to ensure code integrity and a smooth development workflow.

---

## Primary Language

This project is developed and maintained primarily in **MATLAB**. All scripts and functions with the `.m` extension are MATLAB code and are intended to be executed by the MATLAB interpreter.

Use the Matlab arguments block for validation and to help the user use tab-completion for inputs.

New variables and function names should be written in camelCase. Existing variables can be maintained as they were for backward compatibility. 

---

## Environment Requirements

All execution, testing, and validation of the code in this repository **require a licensed installation of MATLAB**.

* **Do not** attempt to run or test the code in any other environment, such as GNU Octave, Python, or other MATLAB-like interpreters.
* Compatibility with other environments is not guaranteed, and attempting to run the code outside of a proper MATLAB environment may produce incorrect results or errors.

---

## Workflow and Testing Protocol

Your actions should be determined by your access to a MATLAB environment.

### #  If you have access to a MATLAB environment:

You may proceed with analyzing, modifying, and running tests to validate changes directly. Ensure all tests pass before committing any changes.

### #  If you DO NOT have access to a MATLAB environment:

1.  **DO NOT** attempt to execute, test, or validate any MATLAB (`.m`) files. Your role is restricted to static code analysis and generation.
2.  After generating or modifying code, package all your changes into a **new branch** or submit them as a **pull request (PR)**.
3.  Clearly describe the changes in the branch name or PR description. A human developer with access to MATLAB will review, test, and merge your proposed changes.


