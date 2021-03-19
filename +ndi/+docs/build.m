function build()
% ndi.docs.build - build the NDI markdown documentation from Matlab source
%
% Builds the NDI documentation locally in $NDI-matlab/docs and updates the mkdocs-yml file
% in the $NDI-matlab directory.
%
% **Example**:
%   ndi.docs.build();
%

ndi.globals

ndi_path = ndi_globals.path.path;
ndi_docs = [ndi_path filesep 'docs' filesep 'reference']; % code reference path
ymlpath = 'reference';

disp(['Writing documents pass 1']);

out1 = vlt.docs.matlab2markdown(ndi_path,ndi_docs,ymlpath);
os = vlt.docs.markdownoutput2objectstruct(out); % get object structures

disp(['Writing documents pass 2, with all links']);
out2 = vlt.docs.matlab2markdown(ndi_path,ndi_docs,ymlpath, os);

T = vlt.docs.mkdocsnavtext(out2,2);

ymlfile.references = [ndi_path filesep 'docs' filesep 'mkdocs-references.yml'];
ymlfile.start = [ndi_path filesep 'docs' filesep 'mkdocs-start.yml'];
ymlfile.end = [ndi_path filesep 'docs' filesep 'mkdocs-end.yml'];
ymlfile.documents = [ndi_path filesep 'docs' filesep 'documents' filesep 'documents.yml'];
ymlfile.main = [ndi_path filesep 'mkdocs.yml'];

vlt.file.str2text(ymlfile.references,T);

T0 = vlt.file.text2cellstr(ymlfile.start);
T1 = vlt.file.text2cellstr(ymlfile.documents);
T2 = vlt.file.text2cellstr(ymlfile.references);
T3 = vlt.file.text2cellstr(ymlfile.end);

Tnew = cat(2,T0,T1,T2,T3);

vlt.file.cellstr2text(ymlfile.main,Tnew);

