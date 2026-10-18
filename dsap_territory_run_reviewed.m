function manifest=dsap_territory_run_reviewed(cases,outputRoot,analysisFunction)
% Batch handoff through existing DSAP replay; only explicitly reviewed sessions.
% Cases table: PatientID, Folder (saved Core with reviewed AIF/limits), Session.
% Optional callback is for testing the handoff without rerunning the engine.
if nargin<3,analysisFunction=@run_interactive_perfusion_remove_large_vessels;end
assert(istable(cases)&&all(ismember({'PatientID','Folder','Session'},cases.Properties.VariableNames)),'DSAP:TerritoryBatch','Expected PatientID/Folder/Session columns.');
assert(~dsap_task_control('active'),'DSAP:TerritoryBusy','Finish current analysis before batch handoff.');
if ~isfolder(outputRoot),mkdir(outputRoot);end
manifest=cases;manifest.Status=repmat("pending",height(cases),1);manifest.AnalysisFolder=strings(height(cases),1);manifest.Message=strings(height(cases),1);
for k=1:height(cases)
 try
  loaded=load(char(string(cases.Session(k))),'territory_session');s=loaded.territory_session;
  assert(s.Confirmed&&s.LabelMappingConfirmed,'DSAP:TerritoryReview','Human review is required before DSAP analysis.');
  r=dsap_load_result(char(string(cases.Folder(k))));assert(isfield(r,'roi_snapshot')&&r.roi_snapshot.Confirmed,'DSAP:TerritoryAIF','Use a saved case with a confirmed AIF and analysis limits.');
  identity=dsap_source_identity(r.source_file);assert(strcmp(identity.SHA256,s.Metadata.source_id),'DSAP:TerritorySource','Reviewed territory belongs to another DSA.');
  definition=dsap_territory_state('definition',s);assert(isequal(size(definition.Masks{1}),size(r.aif_mask)),'DSAP:TerritoryShape','Mask geometry differs.');
  settings=r.roi_snapshot.Settings;replay=settings;replay.SourceFile=r.source_file;replay.AIFMask=r.aif_mask;
  replay.CranialLimits=r.cranial_limits;replay.ManualTissue=definition;replay.VesselMethod='cave';
  if isfield(r,'vessel_features')
   for pair={{'ManualAddedMask','CAVEManualAddedMask'},{'ManualRestoredMask','CAVEManualRestoredMask'}}
    p=pair{1};if isfield(r.vessel_features,p{1}),replay.(p{2})=r.vessel_features.(p{1});end
   end
  end
  snapshot=dsap_build_roi_snapshot(identity,r.aif_mask,r.cranial_limits,definition,settings,'NativeDSAP');
  % Save the concrete reviewed handoff before invoking the unchanged pipeline.
  handoffFile=[tempname(outputRoot) '.mat'];save(handoffFile,'snapshot','replay');
  folder=dsap_run_confirmed_analysis(snapshot,@(~) analysisFunction(replay));
  assert(~isempty(folder),'DSAP:TerritoryAnalysisCancelled','Analysis returned no result.');
  manifest.AnalysisFolder(k)=string(folder);manifest.Status(k)="complete";
 catch e
  manifest.Status(k)="failed";manifest.Message(k)=string(e.message);
  if strcmp(e.identifier,'DSAP:Cancelled'),rethrow(e);end
 end
 writetable(manifest,fullfile(outputRoot,'reviewed_analysis_log.csv'));save(fullfile(outputRoot,'reviewed_analysis_manifest.mat'),'manifest');
end
end
