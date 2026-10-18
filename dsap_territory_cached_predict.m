function [prediction,metadata,folder]=dsap_territory_cached_predict(sequence,metadata,configFile,cancelRequested,predictor,cacheRoot)
% Preparation service for the existing territory model, after explicit view selection.
% Cache immutable predictions only; never cache human corrections as predictions.
root=fileparts(mfilename('fullpath'));
if nargin<4,cancelRequested=@() false;end
if nargin<5,predictor=@dsap_territory_predict;end % Test seam; GUI uses only the existing predictor.
if isequal(predictor,@dsap_territory_predict),dsap_require_dependency('territory',configFile);end
if nargin<6,cacheRoot=fullfile(root,'outputs','territory_cache');end
assert(~cancelRequested(),'DSAP:TerritoryCancelled','供血区准备已取消。');
assert(ismember(metadata.view,{'AP','lateral'}),'DSAP:TerritoryView','请先明确选择 AP 或 lateral 投照。');
assert(isnumeric(sequence)&&isreal(sequence)&&all(isfinite(sequence),'all'),'DSAP:TerritoryInput','Expected finite native DSA sequence.');
cfg=jsondecode(fileread(configFile));model=resolve(fileparts(configFile),cfg.model_path);
assert(isfile(model)||isfolder(model),'DSAP:TerritoryModel','配置的供血区模型不存在。');
files={configFile,mfilename('fullpath'),fullfile(root,'dsap_territory_predict.m')};files{2}=[files{2} '.m'];
if isfile(model),files{end+1}=model;
else
 entries=dir(fullfile(model,'**','*'));entries=entries(~[entries.isdir]);
 for k=1:numel(entries),files{end+1}=fullfile(entries(k).folder,entries(k).name);end %#ok<AGROW>
end
if isfield(cfg,'label_mapping_path')&&~isempty(cfg.label_mapping_path),files{end+1}=resolve(fileparts(configFile),cfg.label_mapping_path);end
entries=dir(fullfile(root,'vascular_segmentation','*.py'));
for k=1:numel(entries),files{end+1}=fullfile(entries(k).folder,entries(k).name);end %#ok<AGROW>
hashes=cell(size(files));for k=1:numel(files),v=dsap_source_identity(files{k});hashes{k}=v.SHA256;end
inputMetadata=metadata;transient=intersect(fieldnames(inputMetadata),{'Inference','Transform','PredictionFolder','CacheHit','CacheKey'});
if ~isempty(transient),inputMetadata=rmfield(inputMetadata,transient);end
signature=struct('Metadata',inputMetadata,'Shape',size(sequence),'Files',{hashes},'Predictor',func2str(predictor));
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(uint8(unicode2native(jsonencode(signature),'UTF-8')));
% Bound temporary memory while hashing exactly the single input domain used by the predictor.
for k=1:size(sequence,1)
 slice=single(sequence(k,:,:));digest.update(typecast(slice(:),'uint8'));dsap_task_control('check');
 assert(~cancelRequested(),'DSAP:TerritoryCancelled','供血区准备已取消。');
end
key=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
guard=dsap_preparation_lock(cacheRoot,key,cancelRequested); %#ok<NASGU>
file=fullfile(cacheRoot,[key '.mat']);shape=[size(sequence,2) size(sequence,3)];if ismatrix(sequence),shape=size(sequence);end
if isfile(file)
 try
  s=load(file,'cache');c=s.cache;
  assert(c.Complete&&strcmp(c.Key,key)&&strcmp(c.Metadata.source_id,metadata.source_id)&& ...
   isequal(size(c.Prediction.ACA_mask),shape)&&isequal(size(c.Prediction.MCA_mask),shape));
  assert(islogical(c.Prediction.ACA_mask)&&islogical(c.Prediction.MCA_mask)&&~any(c.Prediction.ACA_mask&c.Prediction.MCA_mask,'all'));
  assert(isfolder(c.Folder)&&isfile(fullfile(c.Folder,'prediction.mat')));
  prediction=c.Prediction;metadata=c.Metadata;metadata.CacheHit=true;metadata.CacheKey=key;folder=c.Folder;return;
 catch e,warning('DSAP:TerritoryCacheInvalid','忽略无效供血区缓存：%s',e.message);end
end
folder=fullfile(cacheRoot,'jobs',char(java.util.UUID.randomUUID()));
[prediction,metadata,folder]=predictor(sequence,inputMetadata,folder,configFile,cancelRequested);
assert(~cancelRequested(),'DSAP:TerritoryCancelled','供血区准备已取消。');dsap_task_control('check');
cache=struct('Complete',true,'Key',key,'Prediction',prediction,'Metadata',metadata,'Folder',folder); %#ok<NASGU>
tmp=[tempname(cacheRoot) '.mat'];cleanup=onCleanup(@() remove_temp(tmp)); %#ok<NASGU>
save(tmp,'cache','-v7');[ok,message]=movefile(tmp,file,'f');assert(ok,'%s',message);
metadata.CacheHit=false;metadata.CacheKey=key;
end
function path=resolve(base,path)
if ~java.io.File(path).isAbsolute(),path=fullfile(base,path);end
end
function remove_temp(file)
if isfile(file),delete(file);end
end
