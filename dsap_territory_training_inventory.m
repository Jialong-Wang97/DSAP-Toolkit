function manifest=dsap_territory_training_inventory(catalogFile,outputRoot,color,sampleCount)
% User-confirmed complete MCA annotations; case-level quality still needs review.
if nargin<3,color='#009688';end;if nargin<4,sampleCount=3;end
assert(~isfolder(outputRoot),'DSAP:TrainingAuditOverwrite','Use a new audit directory.');mkdir(outputRoot);
root=fileparts(mfilename('fullpath'));catalog=jsondecode(fileread(catalogFile));
roleConfig=jsondecode(fileread(fullfile(root,'vascular_segmentation','timeslice_annotation_roles.json')));
e=catalog.entries;selected=e(strcmpi({e.color},color)&[e.visible]&~[e.baseline]);n=numel(selected);
roles=dsap_territory_training_roles(e);writetable(roles,fullfile(outputRoot,'all_roi_roles.csv'));
assert(n>0,'DSAP:TrainingCandidates','No visible non-AIF candidates for this color.');
ids=string({selected.roiId})';groups=strings(n,1);
for k=1:n,hash=dsap_analysis_signature(selected(k).patientId);groups(k)=string(hash(1:16));end
manifest=table(ids,groups,string({selected.dicomFile})',string({selected.maskFile})', ...
 repmat("Unconfirmed",n,1),false(n,1),false(n,1),repmat("Unconfirmed",n,1), ...
 'VariableNames',{'ROIId','PatientGroup','SourceFile','MaskFile','Label','FullTerritoryConfirmed','Approved','View'});
[~,roleIndex]=ismember(ids,roles.ROIId);manifest.Label=roles.Role(roleIndex);
manifest.FullTerritoryConfirmed=manifest.Label=="MCA"&roleConfig.full_territory_extent_confirmed;
manifest.ProposedPatientFold=zeros(n,1);manifest.RecordedSeriesSide=repmat("Unknown",n,1);
for k=1:n
 manifest.ProposedPatientFold(k)=mod(hex2dec(extractBefore(groups(k),9)),5);
 switch upper(selected(k).serialColor)
  case {'#E91E63','#F44336'},manifest.RecordedSeriesSide(k)="Affected";
  case '#2196F3',manifest.RecordedSeriesSide(k)="Contralateral";
 end
end
manifest.EligibleForExtentReview=roles.EligibleForExtentReview(roleIndex);manifest.ReviewIssues=roles.ReviewIssues(roleIndex);
writetable(manifest,fullfile(outputRoot,'review_manifest.csv'));
approved=load(fullfile(root,'contracts','TIMESlice_Legacy_Orientation_Contract_v1.mat'),'contract');
[~,sample]=unique(groups,'stable');sample=sample(1:min(sampleCount,numel(sample)));records=cell(numel(sample),1);
for j=1:numel(sample)
 k=sample(j);entry=selected(k);record=struct('ROIId',entry.roiId,'Status','failed','Message','');
 try
  entries=e(strcmp({e.stackId},entry.stackId));origin=rmfield(catalog,{'entries','skipped'});origin.SelectedStackSkipped=struct([]);
  if ~isempty(catalog.skipped),origin.SelectedStackSkipped=catalog.skipped(strcmp({catalog.skipped.stackId},entry.stackId));end
  info=dicominfo(entry.dicomFile);identity=dsap_timeslice_validate_source(entries,entry.dicomFile,info,origin);
  observed=dsap_legacy_observable_profile(entry,origin);
  mapping=dsap_validate_orientation_contract(approved.contract,origin,observed,[info.Rows info.Columns]);
  before=dsap_source_identity(entry.maskFile);masks=dsap_timeslice_load_masks(entry,[info.Rows info.Columns],mapping);
  after=dsap_source_identity(entry.maskFile);assert(strcmp(before.SHA256,after.SHA256),'DSAP:TrainingMaskChanged','Mask changed during audit.');
  annotation_mask_native=masks{1};assert(nnz(annotation_mask_native)>=3,'DSAP:TrainingEmpty','Current annotation is empty.');
  [~,meta,minip_native]=dsap_territory_case_input(entry.dicomFile);
  metadata=struct('SourceSHA256',identity.SHA256,'MaskSHA256',before.SHA256,'ROIId',entry.roiId, ...
   'PatientGroup',char(groups(k)),'MaskToNativeMapping',mapping,'OrientationContract',approved.contract.Signature, ...
   'Label',char(manifest.Label(k)),'FullTerritoryConfirmed',manifest.FullTerritoryConfirmed(k),'Approved',false,'SourceMetadata',meta);
  folder=fullfile(outputRoot,sprintf('sample_%02d',j));mkdir(folder);
  save(fullfile(folder,'annotation_review.mat'),'minip_native','annotation_mask_native','metadata','-v7');
  f=figure('Visible','off');ax=axes(f);imshow(minip_native,[],'Parent',ax);hold(ax,'on');
  visboundaries(ax,annotation_mask_native,'Color',[0 .8 .6],'LineWidth',1);
  title(ax,sprintf('TIMESlice current ROI | sample %d | %s, quality UNREVIEWED',j,manifest.Label(k)));
  exportgraphics(ax,fullfile(folder,'annotation_overlay.png'),'Resolution',140);close(f);
  record.Status='geometry_verified_quality_pending';record.Pixels=nnz(annotation_mask_native);record.Folder=folder;
 catch exception,record.Message=exception.message;
 end
 records{j}=record;fprintf('TRAINING_AUDIT_SAMPLE_%d %s\n',j,record.Status);
end
audit=struct('Catalog',catalogFile,'CandidateColor',color,'CandidateCount',n,'PatientCount',numel(unique(groups)), ...
 'Samples',{records},'TrainingStarted',false,'Reason','Complete MCA extent confirmed by user for both acquisition sides; case-level quality and flagged exceptions still require review.');
fid=fopen(fullfile(outputRoot,'audit.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(audit,PrettyPrint=true));fclose(fid);
end
