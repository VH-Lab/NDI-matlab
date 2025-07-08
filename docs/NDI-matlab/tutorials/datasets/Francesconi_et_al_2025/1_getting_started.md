# Francesconi et al (2025) Tutorial: Getting Started

This is a tutorial to view the electrophysiology and behavioral data which relates to:

> **Paper**: Francesconi W, Olivera-Pasilio V, Berton F, Olson SL, Chudoba R, Monroy LM, Krabichler Q, Grinvech V, Dabrowska J (2025). Vasopressin and oxytocin excite BNST neurons via oxytocin receptors, which reduce anxious arousal. *Cell Reports* **44**(6): 115768. DOI: [10.1016/j.celrep.2025.115768](https://doi.org/10.1016/j.celrep.2025.115768).

> **Dataset**: DOI: [10.63884/ndic.2025.jyxfer8m](https://doi.org/10.63884/ndic.2025.jyxfer8m)


## Table of Contents
1. [Download NDI](#NDI)
2. [Import the NDI dataset](#import)
	- [Download or load the NDI dataset](#dataset)
	- [Retrieve the NDI session](#session)
3. [View subjects, probes and epochs](#metadata)
	- [View subject summary table](#subjects)
        - [Filter subjects](#filterSubjects)
    - [View probe and epoch summary tables](#probes)
    - [Combine metadata tables](#combine)
        - [Filter epochs](#filterEpochs)
4. [Plot electrophysiology data](#electrophysiology)
5. [Plot Elevated Plus Maze data](#EPM)
6. [Plot Fear-Potentiated Startle data](#FPS)

## Download NDI <a name="NDI"></a>
In order to view the dataset, you will need access to the NDI platform. If you haven't already downloaded NDI, follow the [installation instructions](https://vh-lab.github.io/NDI-matlab/NDI-matlab/installation/) to download NDI and gain access to the suite of tools we have created!

## Import the NDI dataset <a name="import"></a>
Define the dataset path and id.
```matlab
% Choose the folder where the dataset is (or will be) stored
% (e.g. /Users/myusername/Documents/MATLAB/Datasets)
dataPath = [userpath filesep 'Datasets'];
cloudDatasetId = '67f723d574f5f79c6062389d';
datasetPath = fullfile(dataPath,cloudDatasetId);
```

### Download or load the NDI dataset <a name="dataset"></a>
The first time you try to access the data, it needs to be downloaded from NDI-cloud. This may take a few minutes. Once you have the **dataset** downloaded, every other time you examine the data you can just load it.
```matlab
if isfolder(datasetPath)
    % Load if already downloaded
    dataset = ndi.dataset.dir(datasetPath);
else
    % Download
    if ~isfolder(dataPath), mkdir(dataPath); end
    dataset = ndi.cloud.downloadDataset(cloudDatasetId,dataPath);
end
```

### Retrieve the NDI session <a name="session"></a>
A dataset can have multiple **sessions**, but this **dataset** has only one. We must retrieve it in order to access the accompanying experimental **probes** (i.e. a virtual or physical instrument that makes a measurement of or produces a stimulus for a **subject**).
```matlab
% Retrieve the session from this dataset
[session_ref_list,session_list] = dataset.session_list();
session = dataset.open_session(session_list{1});
```

## View subjects, probes and epochs <a name="metadata"></a>

### View subject summary table
Each individual animal is referred to as a subject and has a unique alphanumeric documentID along with a localID which contains references to the animal's strain, species, genotype, experiment date, and cell type. Our database contains documents which store metadata about each subject including their species, strain, genetic strain type, and biological sex which are linked to well-defined ontologies such as NCBI, RRID, and PATO. Additionally, metadata about any treatments that a subject received such as the location of optogenetic stimulation are stored. A summary table showing the metadata for each subject can be viewed below.