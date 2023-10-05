function org = testCreateOrganization(field, value)
    try 
        org = openminds.core.Organization(field, value);
    catch ME
        uialert(app.UIFigure, ME.message, 'Invalid input')
    end
end

