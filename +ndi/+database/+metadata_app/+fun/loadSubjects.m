function subjectData = loadSubjects(S)
    % LOADSUBJECTS loads the subject data from ndi session
    %
    %  ndi.database.metadata_app.fun.loadSubjects(S)
    % Inputs:
    %  S - ndi.session.dir object
    % Output:
    %  SUBJECTDATA - a ndi.database.metadata_app.class.SubjectData object that contains all the subject data in session S
        
        if (~isa(S,'ndi.session.dir'))
           error('METADATA_APP:loadSubjects:InvalidSession',...
              'Input must be an ndi.session object.'); 
        end

        subjects = S.database_search(ndi.query('','isa','subject'));
        subjectData = ndi.database.metadata_app.class.SubjectData();

        for i = 1:numel(subjects)
            subject_obj = subjectData.addItem();
            subject_obj.SubjectName = subjects{i}.document_properties.subject.local_identifier;
            subject_obj.sessionIdentifier = subjects{i}.document_properties.base.session_id;
        end
    end