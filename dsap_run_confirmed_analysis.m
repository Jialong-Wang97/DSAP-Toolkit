function output=dsap_run_confirmed_analysis(snapshot,scientific_pipeline,varargin)
% Single gate for both input adapters. Source never selects scientific math.
    dsap_validate_roi_snapshot(snapshot,dsap_source_identity(snapshot.SourceIdentity.Path));
    assert(isa(scientific_pipeline,'function_handle'),'DSAP:ScientificEntry','Scientific pipeline handle required.');
    output=scientific_pipeline(snapshot,varargin{:});
end
