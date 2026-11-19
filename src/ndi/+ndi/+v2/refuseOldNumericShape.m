function refuseOldNumericShape(what, form)
%REFUSEOLDNUMERICSHAPE Refuse a number stored in the old numeric shape.
%
%   ndi.v2.refuseOldNumericShape(WHAT, FORM) throws the error
%   'ndi:v2:oldNumericShapeReMigrate'. WHAT says what was being read (e.g.
%   'covariate "time"'), FORM the old form found (ndi.v2.oldNumericForm, or
%   for a statement's value 'source_value', 'one cell per reading' or 'a
%   bare logical').
%
%   The old numeric shape is not read as numbers. No v2 database migrated
%   before the writers wrote the new shape (DID-matlab #473, NDI-matlab
%   #1258) is kept, so readers dropped the old shape and a database holding
%   it is migrated again from v1 (did-schema
%   docs/plans/did_v2_numeric_shape_plan.md, section 9 step 4, [no migrated
%   database is kept], Jess Haley, 2026-11-19: "No database exists that was
%   already migrated that we care to keep").
%
%   See also ndi.v2.oldNumericForm.

arguments
    what {mustBeText}
    form {mustBeText} = ''
end
detail = '';
if strlength(string(form)) > 0
    detail = sprintf(' (%s)', char(form));
end
error('ndi:v2:oldNumericShapeReMigrate', ...
    ['%s is stored in the old numeric shape%s, which is no longer read. ' ...
     'Migrate this database again from v1 (did-schema ' ...
     'did_v2_numeric_shape_plan.md [no migrated database is kept]).'], ...
    char(what), detail);
end
