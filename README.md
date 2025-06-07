# NDI
[![MATLAB Tests](.github/badges/tests.svg)](https://github.com/VH-Lab/NDI-matlab/actions/workflows/run_tests.yml)
[![codecov](https://codecov.io/gh/VH-Lab/NDI-matlab/branch/main/graph/badge.svg?token=5K3PA9KOT9)](https://codecov.io/gh/VH-Lab/NDI-matlab)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/VH-Lab/NDI-matlab/security/code-scanning)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/VH-Lab/NDI-matlab/graphs/commit-activity)

Neuroscience Data Interface - A means of specifying and accessing neuroscience data and analyses

2024-04-29: The main branch now holds the code for NDI 2 beta. You can get NDI 1.0.1 on the `ndi1_legacy` branch. Bear with us a couple of days as we roll this out. If you install today, use DID-matlab branch `ndi2beta`. Exciting changes coming!

- Available at https://github.com/VH-Lab/NDI-matlab
- Documentation is at https://vh-lab.github.io/NDI-matlab/
- Installation instructions: https://vh-lab.github.io/NDI-matlab/installation/
- Notes for those installing manually (not recommended): 
  - NDI depends on functions in vhlab-toolbox-matlab, available at https://github.com/VH-Lab/vhlab-toolbox-matlab
  - NDI Depends on functions in vhlab-thirdparty-matlab, available at https://github.com/VH-Lab/vhlab-thirdparty-matlab
  - It is recommended that the developer also install vhlab_vhtools, available at https://github.com/VH-Lab/vhlab_vhtools
  - It is assumed that the function `ndi_Init.m` is run at startup. Please add this to your `startup.m` file. (If you use the http://github.com/VH-Lab/vhlab_vhtools distribution, it will be run automatically.)

Please post issues to [the issues page on GitHub](https://github.com/VH-Lab/NDI-matlab/issues)

We have an RRID now: RRID:SCR_023368
