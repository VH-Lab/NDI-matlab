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

*Type this into MATLAB:*
```matlab
% Choose the folder where the dataset is (or will be) stored
% (e.g. /Users/myusername/Documents/MATLAB/Datasets)
dataPath = [userpath filesep 'Datasets'];
cloudDatasetId = '67f723d574f5f79c6062389d';
datasetPath = fullfile(dataPath,cloudDatasetId);
```

### Download or load the NDI dataset <a name="dataset"></a>
The first time you try to access the data, it needs to be downloaded from NDI-cloud. This may take a few minutes. Once you have the **dataset** downloaded, every other time you examine the data you can just load it.

*Type this into MATLAB:*
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

*Type this into MATLAB:*
```matlab
% Retrieve the session from this dataset
[session_ref_list,session_list] = dataset.session_list();
session = dataset.open_session(session_list{1});
```

## View subjects, probes and epochs <a name="metadata"></a>

### View subject summary table <a name="subjects"></a>
Each individual animal is referred to as a **subject** and has a unique alphanumeric `documentID` along with a `localID` which contains references to the animal's strain, species, genotype, experiment date, and cell type. Our database contains documents which store metadata about each subject including their species, strain, genetic strain type, and biological sex which are linked to well-defined ontologies such as [NCBI](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=10116&lvl=3&lin=f&keep=1&srchmode=1&unlock), [RRID](https://rgd.mcw.edu/rgdweb/report/strain/main.html?id=13508588), [PATO](https://www.ebi.ac.uk/ols4/ontologies/pato/classes/http%253A%252F%252Fpurl.obolibrary.org%252Fobo%252FPATO_0000384), and [UBERON](https://www.ebi.ac.uk/ols4/ontologies/uberon/classes/http%253A%252F%252Fpurl.obolibrary.org%252Fobo%252FUBERON_0001880). Additionally, metadata about any **treatments** that a **subject** received such as the location of optogenetic stimulation are stored. A summary table showing the metadata for each **subject**) can be viewed below.

*Type this into MATLAB:*
```matlab
% View summary table of all subject metadata
subjectSummary = ndi.fun.subjectDocTable(dataset)
```

*You will see a table that looks like:*
| subject_id | subject_name | SpeciesName | SpeciesOntology | StrainName | StrainOntology | GeneticStrainTypeName | BiologicalSexName | BiologicalSexOntology | OptogeneticTetanusStimulationTargetLocationName | OptogeneticTetanusStimulationTargetLocationOntology |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 412693bb0b2a75c8_c0dc4139300a673e | `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | |
| 412693bb0b2b7e0f_40d1f45f9e51dc8b | `sd_rat_OTRCre_220214_BNST@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | OTR-IRES-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | | |
| 412693bb0b2c8c53_4099b07714e3a561 | `wi_rat_CRFCre_230213_BNST@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | |
| 412693bb0b2cf772_c0d06cadbb168eb5 | `sd_rat_WT_210401_BNSTIII@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | SD | RRID:RGD_70508 | wildtype | male | PATO:0000384 | | |
| 412693bb0b344f5e_c0d0f30bef37dab8 | `sd_rat_AVPCre_240425_BNSTI_PVN@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | AVP-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | paraventricular nucleus of hypothalamus | UBERON:0001930 |
| 412693bb0b359d16_40d3e5ebc2d9a521 | `sd_rat_AVPCre_221202_BNSTIII_SCN@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | AVP-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | suprachiasmatic nucleus | UBERON:0002034 |
| 412693bb0b367f65_c0c1ae36954547f5 | `sd_rat_AVPCre_221205_BNSTI_SON@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | AVP-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | supraoptic nucleus | UBERON:0001929 |
| 412693bb0ebeaa0d_c09caf14c3d790a7 | `sd_rat_OTRCre_220819_175@dabrowska-lab.rosalindfranklin.edu` | Rattus norvegicus | NCBITaxon:10116 | OTR-IRES-Cre, SD | RRID:RGD_70508 | wildtype, knockin | male | PATO:0000384 | | |

#### Filter subjects <a name="filterSubjects"></a>
We have created tools to filter a table by its values. Try finding **subjects** matching a given criterion.
> Examples:
> 	columnName = StrainName          dataValue = AVP-Cre
> 	columnName = StrainName          dataValue = SD

*Type this into MATLAB:*
```matlab
% Search for subjects
columnName = 'StrainName';
dataValue = 'AVP-Cre';
rowInd = ndi.fun.table.identifyMatchingRows(subjectSummary,...
    columnName{1},dataValue,'stringMatch','contains');
filteredSubjects = subjectSummary(rowInd,:)
```

### View probe and epoch summary tables <a name="probes"></a>
In the NDI framework, a **probe** is an instrument that makes a measurement of or produces a stimulus for a **subject**. Probes are part of a broader class of experiment items that we term **elements**. In these experiments, there are 3 probe types:
1. stimulator
2. patch-Vm
3. patch-I
Each subject is linked to a unique set of probes. The **stimulator** probe is connected to any information about stimuli that the subject received such as electrophysiological bath conditions or experimental approaches (e.g. optogenetic tetanus). The **patch-Vm** and **patch-I** are probes of type **mfdaq** (multifunction data acquisition system) which means that they contain data linked to an acquisition system that stored measurements (i.e. voltage and current) for a set of experimental **epochs**. Each **epoch** corresponds to one of the original `.mat` files.

*Type this into MATLAB:*
```matlab
% View summary table of all probe metadata
probeSummary = ndi.fun.probeDocTable(dataset)
```

*You will see a table that looks like:*
| subject_id | probe_id | probe_name | probe_type | probe_reference | probeLocationName | probeLocationOntology | cellTypeName | cellTypeOntology |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 412693bb0b2cf772_c0d06cadbb168eb5 | 412693bb0bf98cde_40ce5a2a60a82dd2 | bath_210401_BNSTIII_a | stimulator | [1] | | | | |
| 412693bb0b2cf772_c0d06cadbb168eb5 | 412693bb0bf99bbe_c0cb88b37570afba | Vm_210401_BNSTIII_a | patch-Vm | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | Type III BNST neuron | EMPTY:00000170 |
| 412693bb0b2cf772_c0d06cadbb168eb5 | 412693bb0bf9aa56_40ca24db9ac1470d | I_210401_BNSTIII_a | patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | Type III BNST neuron | EMPTY:00000170 |

*Type this into MATLAB:*
```matlab
% View summary table of all epoch metadata for each probe
epochSummary = ndi.fun.epochDocTable(session) % this will take several minutes
```

*You will see a table that looks like:*
| epoch_number | epoch_id | probe_id | subject_id | local_t0 | local_t1 | global_t0 | global_t1 | mixtureName | mixtureOntology | approachName | approachOntology |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | epoch_412693bb00b3b7b2_4087375d5b7ef613 | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9805 | 18-Aug-2021 15:29:59 | 18-Aug-2021 15:31:16 | arginine-vasopressin | NCIm:C1098706 | | |
| 2 | epoch_412693bb00b3b844_c0da15457eb12ac4 | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9388 | 18-Aug-2021 15:31:25 | 18-Aug-2021 15:32:42 | arginine-vasopressin | NCIm:C1098706 | | |
| 3 | epoch_412693bb00b3b88e_c0d9cb8072143524 | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9419 | 18-Aug-2021 15:32:50 | 18-Aug-2021 15:34:07 | arginine-vasopressin | NCIm:C1098706 | | |
| 4 | epoch_412693bb00b3b8cb_40d23dd40a9bc8c5 | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9453 | 18-Aug-2021 15:43:48 | 18-Aug-2021 15:45:05 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |
| 5 | epoch_412693bb00b3b902_c0a16ccb923181df | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9333 | 18-Aug-2021 15:22:55 | 18-Aug-2021 15:24:12 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |
| 6 | epoch_412693bb00b3b93f_c0d772aceb6a808d | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9298 | 18-Aug-2021 15:24:17 | 18-Aug-2021 15:25:34 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |
| 7 | epoch_412693bb00b3b974_c0d54f2d1e92c305 | 412693bb0bf4b173_40d91734313482e2 | 412693bb0b2a75c8_c0dc4139300a673e | 0 | 76.9375 | 18-Aug-2021 15:25:43 | 18-Aug-2021 15:27:00 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |

### Combine metadata tables <a name="combine"></a>
Let's combine all metadata so that there is one row per **epoch**.

*Type this into MATLAB:*
```matlab
% Combine all metadata into one table
combinedSummary = ndi.fun.table.join({subjectSummary,probeSummary,epochSummary},...
    'uniqueVariables','epoch_id');
combinedSummary = ndi.fun.table.moveColumnsLeft(combinedSummary,...
    {'subject_name','epoch_number'})
```

*You will see a table that looks like:*
| subject_name | epoch_number | epoch_id | subject_id | SpeciesName | SpeciesOntology | StrainName | StrainOntology | GeneticStrainTypeName | BiologicalSexName | BiologicalSexOntology | OptogeneticTetanusStimulationTargetLocationName | OptogeneticTetanusStimulationTargetLocationOntology | probe_id | probe_name | probe_type | probe_reference | probeLocationName | probeLocationOntology | cellTypeName | cellTypeOntology | local_t0 | local_t1 | global_t0 | global_t1 | mixtureName | mixtureOntology | approachName | approachOntology |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 1 | epoch_412693bb00b3b7b2_4087375d5b7ef613 | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9805 | 18-Aug-2021 15:29:59 | 18-Aug-2021 15:31:16 | arginine-vasopressin | NCIm:C1098706 | | |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 2 | epoch_412693bb00b3b844_c0da15457eb12ac4 | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9388 | 18-Aug-2021 15:31:25 | 18-Aug-2021 15:32:42 | arginine-vasopressin | NCIm:C1098706 | | |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 3 | epoch_412693bb00b3b88e_c0d9cb8072143524 | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9419 | 18-Aug-2021 15:32:50 | 18-Aug-2021 15:34:07 | arginine-vasopressin | NCIm:C1098706 | | |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 4 | epoch_412693bb00b3b8cb_40d23dd40a9bc8c5 | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9453 | 18-Aug-2021 15:43:48 | 18-Aug-2021 15:45:05 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 5 | epoch_412693bb00b3b902_c0a16ccb923181df | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9333 | 18-Aug-2021 15:22:55 | 18-Aug-2021 15:24:12 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 6 | epoch_412693bb00b3b93f_c0d772aceb6a808d | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9298 | 18-Aug-2021 15:24:17 | 18-Aug-2021 15:25:34 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |
| `wi_rat_CRFCre_210818_BNST@dabrowska-lab.rosalindfranklin.edu` | 7 | epoch_412693bb00b3b974_c0d54f2d1e92c305 | 412693bb0b2a75c8_c0dc4139300a673e | Rattus norvegicus | NCBITaxon:10116 | CRF-Cre, WI | RRID:RGD_13508588 | wildtype, knockin | male | PATO:0000384 | | | 412693bb0bf4b173_40d91734313482e2,412693bb0bf4df3a_c0d30c9167e204ef,412693bb0bf4f693_40c45799b1c5e963 | bath_210818_BNST_a,Vm_210818_BNST_a,I_210818_BNST_a | stimulator,patch-Vm,patch-I | [1] | bed nucleus of stria terminalis (BNST) | UBERON:0001880 | | | 0 | 76.9375 | 18-Aug-2021 15:25:43 | 18-Aug-2021 15:27:00 | sodium chloride,potassium chloride,sodium bicarbonate,sodium phosphate, monobasic, anhydrous,calcium chloride dihydrate,D-glucose,magnesium chloride hexahydrate,pH,carbogen,osm | NCIm:C0037494,NCIm:C0032825,NCIm:C0074722,NCIm:C1165377,CHEBI:86158,NCIm:C0017725,NCIm:C0724622,NCIm:C4048290,NCIm:CL1445492,NCIm:C0439186 | | |

#### Filter epochs <a name="filterEpochs"></a>
Try finding epochs matching a given criterion.
>Examples:
>	columnName = approachName     dataValue = optogenetic           stringMatch = contains
>	columnName = mixtureName      dataValue = FE201874              stringMatch = contains
>	columnName = cellTypeName     dataValue = Type I BNST neuron    stringMatch = identical
>	columnName = global_t0        dataValue = Jun-2023              stringMatch = contains

*Type this into MATLAB:*
```matlab
% Search for epochs
columnName = 'approachName';
dataValue = 'Jun-2023';
stringMatch = 'contains';
rowInd = ndi.fun.table.identifyMatchingRows(combinedSummary,...
    columnName{1},dataValue,'stringMatch',stringMatch{1});
filteredEpochs = combinedSummary(rowInd,:)
```

## Plot electrophysiology data <a name="electrophysiology"></a>
Each **subject** is associated with a set of experimental **epochs**. One **epoch** corresponds to one of the original ``.mat` files. Select a **subject** to view that subject's **epochs** and the associated stimulus conditions for each epoch. This may take a minute to load.

*Type this into MATLAB:*
```matlab
% Select a subject
subjectID = subjectSummary.subject_id;
subjectNames = subjectSummary.subject_name;
subjectName = 'sd_rat_AVPCre_230706_BNSTIII_SON@dabrowska-lab.rosalindfranklin.edu';
subjectIndex = strcmpi(subjectNames,subjectName);
epochIndex = ndi.fun.table.identifyMatchingRows(combinedSummary,'subject_id',...
    subjectID{subjectIndex});

% Check that the subject has epochs
if ~any(epochIndex)
    error(['This subject is part of the behavioral dataset. ' ...
        'Please select a subject in the electrophysiology dataset.'])
end

% Get the patch-Vm probe
patchVm = session.getprobes('subject_id',subjectID{subjectIndex},...
    'type','patch-Vm');
patchVm = patchVm{1};

% Get the patch-I probe
patchI = session.getprobes('subject_id',subjectID{subjectIndex},...
    'type','patch-I');
patchI = patchI{1};

% View summary table of epochs for this subject
epochConditions = combinedSummary(epochIndex,:)
```

Select an epoch to view the associated electrophysiology traces. This may take a minute to load.

*Type this into MATLAB:*
```matlab
% Select an epoch
epochNum = 3;

% Read the patch-Vm timeseries
[dataVm,time] = patchVm.readtimeseries(epochNum,-inf,inf);

% Read the patch-I timeseries
[dataI,~] = patchI.readtimeseries(epochNum,-inf,inf);

% Find indices where traces start and end
traceStarts = find(diff([1;isnan(dataI)]) == -1);
traceEnds = find(diff([isnan(dataI);0]) == 1);

% Get number of current steps and number of timepoints per step
numSteps = numel(traceStarts);
numTimepoints = max(traceEnds - traceStarts) + 1;

% Reformat data into a matrix (time x steps)
timeMatrix = time(1:numTimepoints);
dataVmMatrix = nan(numTimepoints,numSteps);
dataIMatrix = nan(numTimepoints,numSteps);
for i = 1:numSteps
    dataVmMatrix(:,i) = dataVm(traceStarts(i):traceEnds(i));
    dataIMatrix(:,i) = dataI(traceStarts(i):traceEnds(i));
end

% Get current step values
[~,rowInd] = max(abs(dataIMatrix));
colInd = 1:size(dataIMatrix,2);
ind = sub2ind(size(dataIMatrix),rowInd,colInd);
currentSteps = dataIMatrix(ind);

% Plot reformatted traces
figure; hold on; ax = gca;
colormap(ax, turbo); clim(ax, [min(currentSteps) max(currentSteps)]);
colors = turbo(max(currentSteps) - min(currentSteps) + 1);
for i = 1:size(dataVmMatrix, 2) % Iterate through each column of dataVmMatrix
    colorInd = currentSteps(i) - min(currentSteps) + 1;
    plot(ax,timeMatrix, dataVmMatrix(:, i), 'Color', colors(colorInd, :));
end
xlabel('Time (s)'); ylabel('Voltage (mV)')
cb = colorbar(ax); cb.Label.String = 'Current (pA)';
```

*You will see a plot that looks like:*
~[Electrophysiology traces](electrophysiology_traces.png)



