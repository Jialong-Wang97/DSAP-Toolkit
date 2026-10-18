function manifest=dsap_territory_batch(cases,outputRoot,configFile)
% Predict only: unreviewed cases NEVER bypass DSAP's final ROI confirmation.
% cases: table with PatientID, Folder (saved DSAP folder or DICOM), View.
if nargin<3,configFile=fullfile(fileparts(mfilename('fullpath')),'vascular_segmentation','config.yaml');end
assert(istable(cases)&&all(ismember({'PatientID','Folder','View'},cases.Properties.VariableNames)),'DSAP:TerritoryBatch','Expected PatientID/Folder/View table.');
if ~isfolder(outputRoot),mkdir(outputRoot);end
n=height(cases);manifest=cases;manifest.Status=repmat("pending",n,1);manifest.OutputFolder=strings(n,1);manifest.Message=strings(n,1);
for k=1:n
 folder=tempname(outputRoot);manifest.OutputFolder(k)=string(folder);
 try
  [sequence,metadata]=dsap_territory_case_input(char(string(cases.Folder(k))));metadata.view=char(string(cases.View(k)));metadata.patient_id=char(string(cases.PatientID(k)));
  [p,metadata]=dsap_territory_predict(sequence,metadata,folder,configFile);territory_session=dsap_territory_state('new',p,metadata); %#ok<NASGU>
  save(fullfile(folder,'automatic_session.mat'),'territory_session');manifest.Status(k)="needs_review";
 catch e
  if strcmp(e.identifier,'DSAP:Cancelled'),rethrow(e);end
  manifest.Status(k)="failed";manifest.Message(k)=string(e.message);
 end
 writetable(manifest,fullfile(outputRoot,'processing_log.csv'));save(fullfile(outputRoot,'batch_manifest.mat'),'manifest');
end
end
