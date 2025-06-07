function EEData = getEarlyEyeOpening(D)
% GETEARLYEYEOPENING - Retrieve early eye opening data for subjects in a dataset
%
% EEData = GETEARLYEYEOPENING(D)
%
% Extracts information about early eye opening treatments and associated
% probe data for each subject in an ndi.dataset or ndi.session object D.
%
% The function returns a structure array, EEData, where each element
% corresponds to a subject and contains the following fields:
%
% |-------------------|------------------------------------------------|
% | Field             | Description                                    |
% |-------------------|------------------------------------------------|
% | subject_name      | The local identifier of the subject            |
% | subject_id        | The unique ID of the subject                   |
% | probe_name        | Name of the probe associated with the subject  |
% | probe_hemisphere  | Hemisphere location information of the probe   |
% | left_eye          | Treatment information for the left eye         |
% | right_eye         | Treatment information for the right eye        |
% | spike_data        | A structure with the following fields:         |
% |                   |    element_info: Information about the element | 
% |                   |    epoch_data  : A structure with fields:      |
% |                   |        epoch_id   : Epoch ID                   |
% |                   |        spiketimes : Spike times                |
% |                   |        t0_t1      : Start and end times        |
% |                   |    neuron_info  : Extracellular spike info     |
% |-------------------|------------------------------------------------|
%
% See also: ndi.example.fun.probe2elements(),
%    ndi.example.fun.element2spiketimes()
%
% Example:
%   D = ndi.example.fun.opendataset('early_eye_opening'); 
%   EEData = getEarlyEyeOpening(D);



EEData = vlt.data.emptystruct('subject_name','subject_id',...
   'probe_name','probe_hemisphere','left_eye','right_eye','spike_data');

% Let's inspect our subjects:
s = D.database_search(ndi.query('','isa','subject'));

% let's loop over our subjects

for i=1:numel(s)

    disp(['Working on subject ' s{i}.document_properties.subject.local_identifier '.']);

    fData.subject_name = s{i}.document_properties.subject.local_identifier;
    fData.subject_id = s{i}.id();

    % let's get the eye statuses
    q_treatment_left = ndi.query('treatment.name','exact_string','Treatment: left eye premature eye opening') | ...
        ndi.query('treatment.name','exact_string','Treatment: natural left eye opening');
    q_treatment_right = ndi.query('treatment.name','exact_string','Treatment: right eye premature eye opening') | ...
        ndi.query('treatment.name','exact_string','Treatment: natural right eye opening');
    q_subject_id = ndi.query('','depends_on','subject_id',s{i}.id());

    docLeft = D.database_search(q_treatment_left&q_subject_id);
    docRight = D.database_search(q_treatment_right&q_subject_id);

    fData.left_eye = docLeft{1}.document_properties.treatment;
    fData.right_eye = docRight{1}.document_properties.treatment;

    % let's find probes for this subject

    probes_sub = D.getprobes('type','n-trode','subject_id',s{i}.id());

    for j=1:numel(probes_sub)
        fData.probe_name = probes_sub{j}.elementstring();
    
        q_left = ndi.query('probe_location.name','exact_string','left cerebral hemisphere');
        q_right = ndi.query('probe_location.name','exact_string','right cerebral hemisphere');
        q_probe = ndi.query('','depends_on','probe_id',probes_sub{j}.id());

        locDoc = D.database_search( (q_left | q_right) & q_probe);
        
        if isempty(locDoc)
            fData.probe_hemisphere = 'unknown';
        else
            fData.probe_hemisphere = locDoc{1}.document_properties.probe_location;
        end

        fData.spike_data = ndi.example.fun.probe2spiketimes(probes_sub{j});

        EEData(end+1) = fData;

    end

end

