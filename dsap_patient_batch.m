function folder=dsap_patient_batch(files,runSequence,root,readInfo)
% Sequential manual workflows; commit each saved series before advancing.
if nargin<4,readInfo=@dicominfo;end
assert(~isempty(files),'DSAP:EmptyBatch','请先选择序列。');
files=unique(files,'stable');infos=cellfun(readInfo,files,'UniformOutput',false);
identity=patient_identity(infos{1});
assert(~isempty(identity),'DSAP:BatchIdentity','影像缺少患者身份，不能自动合并。');
for k=2:numel(infos)
 assert(strcmp(identity,patient_identity(infos{k})),'DSAP:MixedPatients','所选影像的患者身份不一致，请按患者分别选择。');
end
if ~isfolder(root),mkdir(root);end
folder=fullfile(root,['patient_' datestr(now,'yyyymmdd_HHMMSS') '_' char(java.util.UUID.randomUUID())]);
mkdir(folder);
manifest=struct('PatientIdentity',identity,'Files',{files},'Completed',0, ...
 'Status','in_progress','Outputs',{{}},'Error','');
write_manifest();
try
 for k=1:numel(files)
  output=runSequence(files{k},k,numel(files));
  if isempty(output),manifest.Status='stopped';break;end
  saved=load(fullfile(output,'analysis_status.mat'),'analysis_complete');
  assert(saved.analysis_complete,'DSAP:IncompleteCore','当前序列尚未完整保存，批次已停止。');
  destination=fullfile(folder,sprintf('sequence_%03d',k));
  [ok,message]=copyfile(output,destination);assert(ok,'DSAP:BatchCopy','%s',message);
  manifest.Outputs{end+1}=destination;manifest.Completed=k;
  write_summary();write_manifest();
 end
 if manifest.Completed==numel(files),manifest.Status='complete';end
 write_summary();write_manifest();
catch e
 manifest.Status='failed';manifest.Error=e.message;write_manifest();
 error('DSAP:PatientBatch','多序列分析停止。已完成 %d / %d；结果目录：%s\n%s',manifest.Completed,numel(files),folder,e.message);
end
 function write_manifest()
  save(fullfile(folder,'patient_batch.mat'),'manifest');
  fid=fopen(fullfile(folder,'patient_batch.json'),'w','n','UTF-8');
  assert(fid>=0,'DSAP:BatchManifest','无法保存患者批次清单。');
  cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid,'%s',jsonencode(manifest,'PrettyPrint',true));
 end
 function write_summary()
  % Retain the full parameter schema in per-series files; the combined table
  % uses the stable scientific summary shared by every analysis mode.
  combined=table();
  for n=1:manifest.Completed
   data=load(fullfile(manifest.Outputs{n},'interactive_perfusion_results.mat'),'summary_table');
   current=data.summary_table;
   current.BatchSequence=repmat(n,height(current),1);
   current.SourceFile=repmat(string(files{n}),height(current),1);
   current.PatientIdentity=repmat(string(identity),height(current),1);
   combined=[combined;current]; %#ok<AGROW>
  end
  if manifest.Completed>0,writetable(combined,fullfile(folder,'patient_ROI_summary.csv'));end
 end
end
function identity=patient_identity(info)
% PatientID alone may collide across issuers; include recorded name/issuer.
identity='';id='';name='';issuer='';
if isfield(info,'PatientID'),id=strtrim(char(string(info.PatientID)));end
if isfield(info,'IssuerOfPatientID'),issuer=strtrim(char(string(info.IssuerOfPatientID)));end
if isfield(info,'PatientName')
 value=info.PatientName;
 if isstruct(value),name=jsonencode(value);else,name=strtrim(char(string(value)));end
end
if ~isempty(id),identity=jsonencode({issuer,id,name});end
end
