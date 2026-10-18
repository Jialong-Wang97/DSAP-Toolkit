function test_reviewer_package
% Run from a clean checkout with only MATLAB and shipped source on the path.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
restoredefaultpath;addpath(root);report=setup_DSAPI;assert(report.BasicReady);
result=run_synthetic_example;
f=dsap_start;guard=onCleanup(@() delete_if_valid(f));drawnow;
assert(isgraphics(f)&&isappdata(f,'DSAPWorkspaceImport'));
importer=getappdata(f,'DSAPWorkspaceImport');loaded=importer(result.Example.DICOM);
assert(loaded,'GUI failed to load synthetic DICOM.');
state=getappdata(f,'WorkspaceState');assert(strcmp(state.SourceStatus,'selected'));
check_missing(@() run_interactive_perfusion_remove_large_vessels);
check_missing(@() dsap_cave_full_field('unused',[], 'dark',false));
check_missing(@() dsap_territory_predict([],struct()));
check_missing(@() dsap_timeslice_select(root));
g=computeVesselGeometry(result.Example.Centerline,[1 1],struct('UseVTI',true));
assert(g.Valid&&~g.VTIValid&&isnan(g.VTI));
assert(isfile(fullfile(result.Example.OutputDirectory,'geometry_metrics.csv')));
fprintf('PARTIAL_REVIEWER_SMOKE_PASS: setup, GUI, synthetic import, geometry export, missing dependencies.\n');
fprintf('FULL_PERFUSION_WORKFLOW_NOT_TESTED: unresolved external components.\n');
end
function check_missing(fn)
try,fn();catch e,assert(strcmp(e.identifier,'DSAP:MissingDependency'),'%s',e.message);return;end
error('Expected DSAP:MissingDependency.');
end
function delete_if_valid(f)
if isgraphics(f),delete(f);end
end
