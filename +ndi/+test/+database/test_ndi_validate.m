function test_ndi_validate()
% TEST_NDI_DOCUMENT - Test the functionality of the NDI_VALIDATE object 
%
% ndi.test.document()
%
% Create a variety of mock ndi.document objects to test if the ndi.validate 
% can correctly detect ndi.document object with invalid types based on its 
% corresponding schema
%


error('this function is out of date.');


ndi.globals;

% validate classes that don't have depnds-on and have relatively few super-classes
subject_doc = ndi.subject('sample_subject@brandeis.edu', '').newdocument();
validator = ndi.validate(subject_doc);
assert(validator.is_valid == 1, 'fail');
disp('good')

subject_doc = subject_doc.setproperties('subject.description', 5);
validator = ndi.validate(subject_doc);
assert(validator.is_valid == 0, 'fail');

try
    assert(validator.is_valid == 0, "fail");
    validator.throw_error();
catch e
    errormsg = e.message;
end
disp("good" + newline)
disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
disp("")

subject_doc = subject_doc.setproperties('ndi_document.database_version', 'not a number');
validator = ndi.validate(subject_doc);
assert(validator.is_valid == 0, 'fail');
disp('good');

try
    validator.throw_error();
catch e
    errormsg = e.message;
end
disp("good" + newline)
disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
disp("")

% validate more complicated classes that may contain depends-on and more
% super-classes
dirname = [ndi_globals.path.exampleexperpath filesep 'exp1_eg_saved'];
E = ndi.session.dir('exp1',dirname);

disp('Let us clear the database first before we proceed')
E.database_clear('yes');
dt = ndi.file.navigator(E, '.*\.rhd\>');
validator = ndi.validate(dt.newdocument());
assert(validator.is_valid == 1, 'fail');
disp('good')

dev1 = ndi.daq.system.mfdaq('intan1',dt,ndi.daq.reader.mfdaq.intan());
docs = dev1.newdocument();
doc = docs{3};
validator = ndi.validate(doc, E);
assert(validator.is_valid == 0, "fail");

try
    validator.throw_error();
catch e
    errormsg = e.message;
end
disp("good" + newline)
disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
disp("")

E.database_add(dev1.daqreader.newdocument());
validator = ndi.validate(doc, E);
assert(validator.is_valid == 0, "fail");

try
    validator.throw_error();
catch e
    errormsg = e.message;
end
disp("good" + newline)
disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
disp("")

E.database_add(docs{1});
validator = ndi.validate(doc, E);
assert(validator.is_valid == 1, "fail");
disp('good');

%test format_validators
animal_subject_good_doc = ndi.document('ndi_document_animalsubject.json', 'animalsubject.scientific_name', 'Aboma etheostoma', 'animalsubject.genbank_commonname', 'scaly goby');
validator = ndi.validate(animal_subject_good_doc);
assert(validator.is_valid == 1, "fail");
disp('good')

animal_subject_bad_doc_with_hint = ndi.document('ndi_document_animalsubject.json', 'animalsubject.scientific_name', 'scaly goby', 'animalsubject.genbank_commonname', 'Aboma etheostoma');
errormsg = "";
try
    validator = ndi.validate(animal_subject_bad_doc_with_hint);
    assert(validator.is_valid == 0, "fail");
    validator.throw_error();
catch e
    errormsg = e.message;
end
disp("good" + newline)
disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
disp("")

animal_subject_bad_doc = ndi.document('ndi_document_animalsubject.json', 'animalsubject.scientific_name', 'invalid_scientific_name', 'animalsubject.genbank_commonname', 'invalid_genbank_commonname');
try
    validator = ndi.validate(animal_subject_bad_doc);
    assert(validator.is_valid == 0, "fail");
    validator.throw_error();
catch e
    errormsg = e.message;
end
disp("good" + newline)
disp("Here is the error message that is supposed to display" + newline + errormsg)
disp("")
disp('All test cases have passed.')

end
