function [mask,network,provenance]=resolve_AIF_vascular(context,shape,resultsRoot)
% Reuse same-source vascular data; no file picker, model or image recognition.
% Optional current-run input: VascularResult.SourceIdentity/Mask/Network.
assert(isfield(context,'SourceIdentity')&&isfield(context.SourceIdentity,'SHA256'),'AutoAIF:Identity','当前序列缺少来源校验信息。');
if isfield(context,'VascularResult')
 v=context.VascularResult;
 if isfield(v,'Available'),assert(v.Available,'AutoAIF:Preparation','血管准备不可用：%s',v.Reason);end
 assert(isfield(v,'SourceIdentity')&&strcmp(v.SourceIdentity.SHA256,context.SourceIdentity.SHA256),'AutoAIF:Identity','血管结果不属于当前 DSA。');
 assert(isfield(v,'Mask')&&isequal(size(v.Mask),shape)&&all(isfinite(v.Mask),'all')&&any(v.Mask,'all'),'AutoAIF:Mask','当前血管 mask 无效。');
 mask=logical(v.Mask);network=[];if isfield(v,'Network'),network=v.Network;end
 provenance=struct('File','','MaskField','VascularResult.Mask','SourceIdentity',v.SourceIdentity,'NetworkReused',~isempty(network));return;
end
if isfield(context,'VascularResultFile')
 [mask,network,provenance]=load_AIF_source(context.VascularResultFile,context.SourceIdentity,shape);return;
end
files=dir(fullfile(resultsRoot,'**','interactive_perfusion_results.mat'));
[~,order]=sort([files.datenum],'descend');problems={};
% Production result folders start with the original source basename. Try
% only those; retain SHA256 validation. Renamed sources can use the explicit
% VascularResultFile adapter rather than scanning hundreds of large MATs.
if isfield(context.SourceIdentity,'Path')
 [~,base]=fileparts(context.SourceIdentity.Path);base=regexprep(base,'[^a-zA-Z0-9_-]','_');
 preferred=false(size(order));
 for j=1:numel(order)
  [~,folderName]=fileparts(files(order(j)).folder);preferred(j)=startsWith(folderName,[base '_']);
 end
 order=order(preferred);
end
for k=order
 file=fullfile(files(k).folder,files(k).name);
 try
  fields=whos('-file',file);names={fields.name};
  if ismember('source_identity',names)
   s=load(file,'source_identity');identity=s.source_identity;
  elseif ismember('source_file',names)
   s=load(file,'source_file');
   if ~isfield(context.SourceIdentity,'Path')||~strcmpi(char(s.source_file),context.SourceIdentity.Path),continue;end
   identity=dsap_source_identity(s.source_file);
  else,continue;end
  if ~strcmp(identity.SHA256,context.SourceIdentity.SHA256),continue;end
  [mask,network,provenance]=load_AIF_source(file,context.SourceIdentity,shape);return;
 catch e
  problems{end+1}=sprintf('%s: %s',file,e.message); %#ok<AGROW>
 end
end
detail='';if ~isempty(problems),detail=strjoin(problems,newline);end
error('AutoAIF:NoVascularResult','没有可复用的同一序列血管结果；已切回 Manual AIF。首次分析需先使用人工 AIF 完成已有血管流程。%s',detail);
end
