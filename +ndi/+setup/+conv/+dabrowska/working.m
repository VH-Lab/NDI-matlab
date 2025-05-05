

myPath = '/Users/vanhoosr/Library/CloudStorage/GoogleDrive-steve@walthamdatascience.com/Shared drives/Dabrowska';


[fileList,isDir] = vlt.file.manifest(myPath);
filefileList = fileList(~isDir);

incl = []; for i=1:numel(filefileList), if ~contains(filefileList{i},'/._'), incl(end+1) = i; end; end
filefileList = filefileList(incl);
incl = []; for i=1:numel(filefileList), if ~startsWith(filefileList{i},'._'), incl(end+1) = i; end; end
filefileList = filefileList(incl);

t = ndi.setup.conv.datalocation.processFileManifest(filefileList,j,'relativePathPrefix','Dabrowska/');

 % constants

t{:,"SpeciesOntologyID"} = "NCBITaxon:10116"; % Rattus norvegicus
t{:,"SubjectPostfix"} = "@dabrowska-lab.rosalindfranklin.edu";

 % how to assign strains?

 % how to assign species:

sp = openminds.controlledterms.Species;
sp.preferredOntologyIdentifier="NCBITaxon:10116";
sp.name = "Rattus norvegicus";

st_sd = openminds.core.research.Strain;
st_sd.geneticStrainType = "wildtype";
st_sd.species = sp;
st_sd.ontologyIdentifier = "RRID:RGD_70508";
st_sd.name = "SD"; 

st_wi = openminds.core.research.Strain;
st_wi.geneticStrainType = "wildtype";
st_wi.species = sp;
st_wi.ontologyIdentifier = "RRID:RGD_13508588";
st_wi.name = "WI"; 

st_trans = openminds.core.research.Strain;
st_trans.geneticStrainType = "knockin";
st_trans.species = sp;
st_trans.backgroundStrain = [st_sd st_wi ];

st_avpcre = st_trans;
st_avpcre.name = 'AVP-Cre';

st_crfcre = st_trans;
st_crfcre.name = 'CRF-Cre';

st_otrirescre = st_trans;
st_otrirescre.name = 'OTR-IRES-Cre';

  % hangers on

L1 = (cellfun(@(x) ~isequaln(x,NaN), t.IsExpMatFile)) & cellfun(@(x) isequaln(x,NaN), t.BathConditionString);


 % need to add table constant elements, join 
 % epochprobmap_daqsystem: dabrowska_intracell
 % probes: dabrowska_current: patch-I
 %    dabrowska_voltage: patch-V
 %    dabrowska_stimulator: stimulator

bath_background


What are the species?



What are the strains?


