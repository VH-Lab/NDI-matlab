# Francesconi et al (2025) Tutorial: Getting Started

This is a tutorial to view the electrophysiology and behavioral data which relates to:

> Francesconi W, Olivera-Pasilio V, Berton F, Olson SL, Chudoba R, Monroy LM, Krabichler Q, Grinvech V, Dabrowska J (2025). Vasopressin and oxytocin excite BNST neurons via oxytocin receptors, which reduce anxious arousal. *Cell Reports* **44**(6): 115768. DOI: [10.1016/j.celrep.2025.115768](https://doi.org/10.1016/j.celrep.2025.115768).

> Francesconi W, Olivera-Pasilio V, Berton F, Olson SL, Chudoba R, Monroy LM, Krabichler Q, Grinvech V, Dabrowska J (2025). Dataset: vasopressin and oxytocin excite BNST neurons via oxytocin receptors, which reduce anxious arousal. *NDI Cloud*. DOI: [10.63884/ndic.2025.jyxfer8m](https://doi.org/10.63884/ndic.2025.jyxfer8m).


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
In order to view the dataset, you will need access to the NDI platform. If you haven't already downloaded NDI, follow the [installation instructions](https://vh-lab.github.io/NDI-matlab/NDI-matlab/installation/) to download NDI and gain access to the suite of tools we have created! You can find more information and tutorials on the [NDI website](https://vh-lab.github.io/NDI-matlab/NDI-matlab/).

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

### View subject summary table <a name="subjects"></a>
Each individual animal is referred to as a **subject** and has a unique alphanumeric `documentID` along with a `localID` which contains references to the animal's strain, species, genotype, experiment date, and cell type. Our database contains documents which store metadata about each subject including their species, strain, genetic strain type, and biological sex which are linked to well-defined ontologies such as [NCBI](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=10116&lvl=3&lin=f&keep=1&srchmode=1&unlock), [RRID](https://rgd.mcw.edu/rgdweb/report/strain/main.html?id=13508588), [PATO](https://www.ebi.ac.uk/ols4/ontologies/pato/classes/http%253A%252F%252Fpurl.obolibrary.org%252Fobo%252FPATO_0000384), and [UBERON](https://www.ebi.ac.uk/ols4/ontologies/uberon/classes/http%253A%252F%252Fpurl.obolibrary.org%252Fobo%252FUBERON_0001880). Additionally, metadata about any **treatments** that a **subject** received such as the location of optogenetic stimulation are stored. A summary table showing the metadata for each **subject**) can be viewed below.
```matlab
% View summary table of all subject metadata
subjectSummary = ndi.fun.subjectDocTable(dataset)
```
| subject_id | subject_name | SpeciesName | SpeciesOntology | StrainName | StrainOntology | GeneticStrainTypeName | BiologicalSexName | BiologicalSexOntology | OptogeneticTetanusStimulationTargetLocationName | OptogeneticTetanusStimulationTargetLocationOntology |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 412693bb0b2a75c8_c0dc4139300a673e | wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | |
| 412693bb0b2b7e0f_40d1f45f9e51dc8b | sd_rat_OTRCre_220214_BNST@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | OTR-IRES-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | | |
| 412693bb0b2c8c53_4099b07714e3a561 | wi_rat_CRFCre_230213_BNST@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | |
| 412693bb0b2cf772_c0d06cadbb168eb5 | sd_rat_WT_210401_BNSTIII@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | SD | RRID:RGD_70508 | wildtype | male | PATO:0000384 | | |
| 412693bb0b344f5e_c0d0f30bef37dab8 | sd_rat_AVPCre_240425_BNSTI_PVN@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | AVP-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | paraventricular nucleus of hypothalamus | UBERON:0001930 |
| 412693bb0b359d16_40d3e5ebc2d9a521 | sd_rat_AVPCre_221202_BNSTIII_SCN@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | AVP-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | suprachiasmatic nucleus | UBERON:0002034 |
| 412693bb0b367f65_c0c1ae36954547f5 | sd_rat_AVPCre_221205_BNSTI_SON@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | AVP-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | supraoptic nucleus | UBERON:0001929 |
| 412693bb0ebeaa0d_c09caf14c3d790a7 | sd_rat_OTRCre_220819_175@dabrowska-lab.rosalindfranklin.edu | Rattus norvegicus | NCBITaxon:10116 | OTR-IRES-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | | |

###