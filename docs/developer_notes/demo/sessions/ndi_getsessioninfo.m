function [daqsystems, probes, elements, subjects, documents] = ndi_getsessioninfo(ndi_session_obj)
% NDI_GETSESSION_INFO - return all of the daq systems, probes, elements, and documents from an NDI_SESSION object
%
% [DAQSYSTEMS, PROBES, ELEMENTS, SUBJECTS, DOCUMENTS] = NDI_GETSESSION_INFO(NDI_SESSION_OBJ)
%
% Returns a list of all DAQSYSTEMS, PROBES, ELEMENTS, SUBJECTS, and DOCUMENTS from
% an NDI_SESSION_OBJ.
%

daqsystems = ndi_session_obj.daqsystem_load('name','(.*)');

probes = ndi_session_obj.getprobes();

elements = ndi_session_obj.getelements();

documents = ndi_session_obj.database_search({'ndi.document.id','(.*)'});

subjects_id = {};

for i=1:numel(probes),
    subjects_id{i} = probes{i}.subject_id;
end;

for i=1:numel(elements),
    subjects_id{end+1} = elements{i}.subject_id;
end;

subjects_id = unique(subjects_id);

subjects = {};

for i=1:numel(subjects_id),
    subjects{i} = ndi_session_obj.database_search(ndi.query('ndi.document.id','exact_string',subjects_id{i},''));
end;


