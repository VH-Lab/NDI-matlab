% The problem:
%
% Find all recording sessions that exhibit variation in a stimulus_parameter
% called 'Command temperature constant'.  Sessions should be from the marderlab
% (from subjects that have '@marderlab.brandeis.edu' in the 'local_identifier' field).
% Then, for each subject, plot epochs from probe that is located in
% the 'lateral ventricular nerve' as a function of command temperature.

% Step 1: Find all sessions that have marder lab subjects

qm = ndi.query('subject.local_identifier','contains_string','@marderlab.brandeis.edu');
m_doc = S.database_search(qm);

% We will now loop over sessions

for i=1:numel(m_doc)

    % Step 2: Find all eopchs in this session that have a constant temperature stimulus

    item_const = ndi.database.fun.ndicloud_ontology_lookup('Name','Command temperature constant');
    const_o = ['NDIC:' int2str(item_const.Identifier)];

    q_m = ndi.query('base.session_id','exact_string',m_doc{i}.document_properties.base.session_id);
    q_const = ndi.query('stimulus_parameter.ontology_name','exact_string',const_o);

    stim_param_docs = S.database_search(q_m & q_const);

    lvn = ndi.database.fun.uberon_ontology_lookup('Name','lateral ventricular nerve (sensu Cancer borealis)');
    probe_locs_q = ndi.query('probe_location.ontology_name','exact_string',['UBERON:' int2str(lvn.Identifier)]);
    pD = S.database_search(probe_locs_q);
    P = {}; % probe list
    for p=1:numel(pD)
        probeObj = S.database_search(ndi.query('base.id','exact_string',pD{p}.dependency_value('probe_id')));
        P{p} = ndi.database.fun.ndi_document2ndi_object(probeObj{1},S);
    end;

    % Sort by epochid, only include epochs of lvn_1

    epoch_ids = {};
    temps = [];

    pet = P{1}.epochtable();
    for j=1:numel(stim_param_docs)
        if ismember(stim_param_docs{j}.document_properties.epochid.epochid,{pet.epoch_id})
            epoch_ids{end+1} = stim_param_docs{j}.document_properties.epochid.epochid;
            temps(end+1) = stim_param_docs{j}.document_properties.stimulus_parameter.value;
        end
    end;
    [epoch_ids_sorted,epoch_id_sortorder] = sort(epoch_ids);
    temps_sorted = temps(epoch_id_sortorder);
    all_temps = unique(temps_sorted);

    % Step 3, plot the records

    %
    for p=1:numel(P) % loop over probes
        subject_here = S.database_search(ndi.query('base.id','exact_string',P{p}.subject_id));
        figure;
        for t=1:numel(all_temps)
            index = find(temps_sorted==all_temps(t));
            if all_temps(t)==11 %
                index = index(1); % for 11, start with first
            else
                index = index(end); % find the last one
            end;
            [D,ts] = P{p}.readtimeseries(epoch_ids_sorted{index},-Inf,Inf);
            D = 0.5 * D./prctile(abs(D(:)),95);
            plot(ts(1:size(D,1)),D+all_temps(t),'k','linewidth',1);
            hold on;
        end;
        a = axis;
        axis([0 min(20,max(ts)) a(3) a(4)]);
        box off;
        title([P{p}.name ' of ' m_doc{i}.document_properties.subject.local_identifier],'interp','none');
        xlabel('Time(s)');
        ylabel('Temperature (C)');
    end;

end; % loop over sessions
