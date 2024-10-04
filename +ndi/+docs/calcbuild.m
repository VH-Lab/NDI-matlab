function calcbuild(ndicalc_path)
% ndi.docs.calcbuild - build NDI calculator markdown documentation from Matlab source
%
% ndi.docs.calcbuild(DIRNAME)
%
% Builds the documentation locally in NDI calculator GitHub directories.
%
% **Example**:
%   ndi.docs.calcbuild('/Users/myname/Documents/MATLAB/tools/NDIcalc-vis-matlab');
%   % builds documentation for NDIcalc-vis
%

ndi.globals

disp(['Writing NDI calculator document documentation...']);

ndi.docs.all_documents2markdown('input_path', ...
	[ndicalc_path filesep 'ndi_common' filesep 'database_documents'],...
	'output_path',...
	[ndicalc_path filesep 'docs' filesep 'documents' filesep]);

disp(['Now writing function reference...']);

ndi_docs = [ndicalc_path filesep 'docs' filesep 'reference']; % code reference path
ymlpath = 'reference';

url_prefix = vlt.file.textfile2char([ndicalc_path filesep 'docs' filesep 'url_prefix.txt']);

disp(['Writing documents pass 1']);

out1 = vlt.docs.matlab2markdown(ndicalc_path,ndi_docs,ymlpath,[],'',url_prefix);
os = vlt.docs.markdownoutput2objectstruct(out1); % get object structures

ndi_os = load([ndi.common.PathConstants.RootFolder filesep 'docs' filesep 'documentation_structure.mat']);
os = cat(2,os,ndi_os.os);

disp(['Writing documents pass 2, with all links']);
out2 = vlt.docs.matlab2markdown(ndicalc_path,ndi_docs,ymlpath, os,'',url_prefix);

T = vlt.docs.mkdocsnavtext(out2,4);

ymlfile.references = [ndicalc_path filesep 'docs' filesep 'mkdocs-references.yml'];
ymlfile.start = [ndicalc_path filesep 'docs' filesep 'mkdocs-start.yml'];
ymlfile.end = [ndicalc_path filesep 'docs' filesep 'mkdocs-end.yml'];
ymlfile.documents = [ndicalc_path filesep 'docs' filesep 'documents' filesep 'documents.yml'];
ymlfile.main = [ndicalc_path filesep 'mkdocs.yml'];

vlt.file.str2text(ymlfile.references,T);

T0 = vlt.file.text2cellstr(ymlfile.start);
T1 = vlt.file.text2cellstr(ymlfile.documents);
T1_1 = {'  - Code reference:'};
T2 = vlt.file.text2cellstr(ymlfile.references);
T3 = vlt.file.text2cellstr(ymlfile.end);

Tnew = cat(2,T0,T1,T1_1,T2,T3);

vlt.file.cellstr2text(ymlfile.main,Tnew);

