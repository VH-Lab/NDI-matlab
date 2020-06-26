function test_ndi_validate()
% TEST_NDI_DOCUMENT - Test the functionality of the NDI_VALIDATE object 
%
% TEST_NDI_DOCUMENT()
%
% Create a variety of mock ndi_document objects to test if the ndi_validate 
% can correctly detect ndi_document object with invalid types based on its 
% corresponding schema
%

ndi_globals;

% validate classes that don't have depnds-on and have relatively few super-classes
subject_doc = ndi_subject('sample_subject@brandeis.edu', '').newdocument();
validator = ndi_validate(subject_doc);
assert(validator.is_valid == 1, 'fail');
disp('good')

subject_doc = subject_doc.setproperties('subject.description', 5);
validator = ndi_validate(subject_doc);
assert(validator.is_valid == 0, 'fail');
disp('good')

subject_doc = subject_doc.setproperties('ndi_document.database_version', 'not a number');
validator = ndi_validate(subject_doc);
assert(validator.is_valid == 0, 'fail');
disp('good');

% validate more complicated classes that may contain depends-on and more
% super-classes
dirname = [ndi.path.exampleexperpath filesep 'exp1_eg_saved'];
E = ndi_session_dir('exp1',dirname);

disp('Let us clear the database first before we proceed')
E.database_clear('yes');
dt = ndi_filenavigator(E, '.*\.rhd\>');
validator = ndi_validate(dt.newdocument());
assert(validator.is_valid == 1, 'fail');
disp('good')

dev1 = ndi_daqsystem_mfdaq('intan1',dt,ndi_daqreader_mfdaq_intan());
docs = dev1.newdocument();
doc = docs{3};
validator = ndi_validate(doc, E);
assert(validator.is_valid == 0, "fail");
disp('good');

E.database_add(dev1.daqreader.newdocument());
validator = ndi_validate(doc, E);
assert(validator.is_valid == 0, "fail");
disp('good');
E.database_add(docs{1});
validator = ndi_validate(doc, E);
assert(validator.is_valid == 1, "fail");
disp('good');



disp('All test cases have passed.')

end