function dsap_export_mca_training(catalogFile,outputRoot)
% Export user-authorized complete MCA annotations; no edits to source files.
root=fileparts(mfilename('fullpath'));catalog=jsondecode(fileread(catalogFile));e=catalog.entries;
roles=dsap_territory_training_roles(e);selected=find(roles.EligibleForExtentReview);
if ~isfolder(outputRoot),mkdir(outputRoot);end
writetable(roles,fullfile(outputRoot,'role_admission.csv'));
approved=load(fullfile(root,'contracts','TIMESlice_Legacy_Orientation_Contract_v1.mat'),'contract');records=cell(numel(selected),1);
for j=1:numel(selected)
 entry=e(selected(j));id=['mca_' entry.roiId];pairFile=fullfile(outputRoot,[id '.mat']);recordFile=fullfile(outputRoot,[id '.json']);
 if isfile(recordFile),prior=jsondecode(fileread(recordFile));if strcmp(prior.Status,'ready')&&isfile(pairFile),records{j}=prior;continue;end,end
 rec=struct('CaseID',id,'ROIId',entry.roiId,'Status','excluded','Reason','','PairFile',pairFile);
 try
  entries=e(strcmp({e.stackId},entry.stackId));origin=rmfield(catalog,{'entries','skipped'});origin.SelectedStackSkipped=struct([]);
  if ~isempty(catalog.skipped),origin.SelectedStackSkipped=catalog.skipped(strcmp({catalog.skipped.stackId},entry.stackId));end
  info=dicominfo(entry.dicomFile);identity=dsap_timeslice_validate_source(entries,entry.dicomFile,info,origin);
  observed=dsap_legacy_observable_profile(entry,origin);mapping=dsap_validate_orientation_contract(approved.contract,origin,observed,[info.Rows info.Columns]);
  before=dsap_source_identity(entry.maskFile);masks=dsap_timeslice_load_masks(entry,[info.Rows info.Columns],mapping);after=dsap_source_identity(entry.maskFile);
  assert(strcmp(before.SHA256,after.SHA256),'DSAP:TrainingChanged','Source mask changed while reading.');
  mca_native=masks{1};fraction=nnz(mca_native)/numel(mca_native);
  assert(fraction>=.005&&fraction<=.9,'DSAP:TrainingArea','Full MCA area outside broad QC range (0.5%% to 90%%).');
  assert(isfield(info,'PositionerPrimaryAngle'),'DSAP:TrainingView','Missing view angle.');
  angle=abs(mod(double(info.PositionerPrimaryAngle)+90,180)-90);
  if angle<=30,view='AP';elseif angle>=60,view='lateral';else,error('DSAP:TrainingOblique','Oblique view excluded.');end
  [seq,meta,minip_native]=dsap_territory_case_input(entry.dicomFile);
  assert(strcmp(meta.source_id,identity.SHA256),'DSAP:TrainingChanged','Source DICOM changed while reading.');
  assert(~isfield(info,'PhotometricInterpretation')||strcmp(info.PhotometricInterpretation,'MONOCHROME2'),'DSAP:TrainingPolarity','Unverified polarity.');
  intensity_range=double([min(seq,[],'all'),max(seq,[],'all')]);frame_count=size(seq,1);clear seq;
  assert(diff(intensity_range)>0,'DSAP:TrainingConstant','Constant sequence.');
  patient=dsap_analysis_signature(entry.patientId);meta.view=view;meta.view_selection_required=false;
  meta.training_annotation=struct('Label','MCA','CompleteTerritory',true,'Authorization','user confirmed complete MCA and requested training', ...
   'ROIId',entry.roiId,'MaskSHA256',before.SHA256,'MaskToNativeMapping',mapping,'ContractSignature',approved.contract.Signature);
  metadata_json=jsonencode(meta);save(pairFile,'minip_native','mca_native','intensity_range','frame_count','metadata_json','-v7');
  cc=bwconncomp(mca_native);rec.Status='ready';rec.SourceSHA256=identity.SHA256;rec.MaskSHA256=before.SHA256;
  rec.PatientGroup=patient;rec.Fold=mod(hex2dec(patient(1:8)),5);rec.View=view;rec.AreaFraction=fraction;rec.Components=cc.NumObjects;
  rec.SeriesSide='Unknown';if ismember(upper(entry.serialColor),{'#E91E63','#F44336'}),rec.SeriesSide='Affected';elseif strcmpi(entry.serialColor,'#2196F3'),rec.SeriesSide='Contralateral';end
 catch exception,rec.Reason=[exception.identifier ': ' exception.message];end
 records{j}=rec;write_json(recordFile,rec);
 fprintf('MCA_EXPORT %d/%d %s %s\n',j,numel(selected),rec.Status,rec.Reason);
end
write_json(fullfile(outputRoot,'manifest.json'),struct('Records',{records},'Complete',true,'CandidateCount',numel(selected)));
end
function write_json(path,data)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(data,PrettyPrint=true));
end
