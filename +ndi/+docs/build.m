function build()
% ndi.docs.build - build the NDI markdown documentation from Matlab source
%
% Builds the NDI documentation locally in $NDI-matlab/docs and updates the mkdocs-yml file
% in the $NDI-matlab directory.
%
% **Example**:
%   ndi.docs.build();
%
% Need to move mkdocs.yml to the root directory of the repo before running `mkdocs gh-deploy`
% on regular command line (not Matlab command line).
%

disp(['Writing NDI document documentation...']);

ndi.docs.all_documents2markdown();

 % make sure we don't traverse the the 'site' directory
ndi_path = ndi.common.PathConstants.RootFolder;

if ~isfolder([ndi_path filesep 'site']),
    mkdir([ndi_path filesep 'site']);
end;

vlt.file.touch([ndi_path filesep 'site' filesep '.matlab2markdown-ignore']);

disp(['Now writing function reference...']);

ndi_docs = [ndi_path filesep 'docs' filesep 'NDI-matlab' filesep 'reference']; % code reference path
ymlpath = 'NDI-matlab/reference';

disp(['Writing documents pass 1']);

out1 = vlt.docs.matlab2markdown(ndi_path,ndi_docs,ymlpath,[],'','https://vh-lab.github.io/NDI-matlab/');
os = vlt.docs.markdownoutput2objectstruct(out1); % get object structures

save([ndi_path filesep 'docs' filesep 'documentation_structure.mat'],'os','-mat');

disp(['Writing documents pass 2, with all links']);
out2 = vlt.docs.matlab2markdown(ndi_path,ndi_docs,ymlpath, os,'','https://vh-lab.github.io/NDI-matlab/');

spaces = 6; % used to be 4 when only 1 set of tools
T = vlt.docs.mkdocsnavtext(out2,spaces);

ymlfile.references = [ndi_path filesep 'docs' filesep 'NDI-matlab' filesep 'mkdocs-references.yml'];
ymlfile.start = [ndi_path filesep 'docs' filesep 'NDI-matlab' filesep 'mkdocs-start.yml'];
ymlfile.end = [ndi_path filesep 'docs' filesep 'NDI-matlab' filesep 'mkdocs-end.yml'];
ymlfile.documents = [ndi_path filesep 'docs' filesep 'NDI-matlab' filesep 'documents' filesep 'documents.yml'];
ymlfile.main = [ndi_path filesep 'docs' filesep 'NDI-matlab' filesep 'mkdocs.yml'];

vlt.file.str2text(ymlfile.references,T);

T0 = vlt.file.text2cellstr(ymlfile.start);
T1 = vlt.file.text2cellstr(ymlfile.documents);
T1_1 = {'    - Code reference:'};
T2 = vlt.file.text2cellstr(ymlfile.references);
T3 = vlt.file.text2cellstr(ymlfile.end);

Tnew = cat(2,T0,T1,T1_1,T2,T3);

vlt.file.cellstr2text(ymlfile.main,Tnew);

