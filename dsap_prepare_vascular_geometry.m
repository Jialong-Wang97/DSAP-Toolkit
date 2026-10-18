function prepared=dsap_prepare_vascular_geometry(prepared,cacheRoot)
% Reuse geometry only when source/masks and all contributing code match.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'AutoAIF'));
if nargin<2,cacheRoot=fullfile(root,'outputs','vascular_cache');end
if ~isfolder(cacheRoot),mkdir(cacheRoot);end
full=prepared.FullField;assert(any(full.ArteryMask,'all'),'DSAP:NoArtery','已有血管结果中没有可用动脉。');
files={fullfile(root,'dsap_prepare_vascular_geometry.m'),fullfile(root,'AutoAIF','prepare_lumen_geometry.m'),fullfile(root,'AutoAIF','build_centerline_graph.m')};
geometry=dir(fullfile(root,'src','geometry','*.m'));
for k=1:numel(geometry),files{end+1}=fullfile(geometry(k).folder,geometry(k).name);end %#ok<AGROW>
hashes=cell(size(files));for k=1:numel(files),v=dsap_source_identity(files{k});hashes{k}=v.SHA256;end
signature=struct('Version',1,'VascularKey',full.Provenance.cache_key,'Source',prepared.SourceIdentity.SHA256,'Code',{hashes});
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(uint8(jsonencode(signature)));
key=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
file=fullfile(cacheRoot,[key '.mat']);prepared.CacheFile=file;
guard=dsap_preparation_lock(cacheRoot,key); %#ok<NASGU>
if isfile(file)
 try
  entry=load(file,'cache');cache=entry.cache;
  assert(cache.Complete&&strcmp(cache.Key,key)&&isequal(cache.FullField.ArteryMask,full.ArteryMask)&& ...
   isequal(cache.FullField.VeinMask,full.VeinMask)&&isequal(cache.Network.PreparedGeometry.Mask,full.ArteryMask));
  prepared.Network=cache.Network;prepared.Available=true;prepared.GeometryCacheHit=true;return;
 catch e
  warning('DSAP:VascularCacheInvalid','忽略无效血管几何缓存：%s',e.message);
 end
end
dsap_task_control('check');
network=prepare_lumen_geometry(full.ArteryMask,[]);
dsap_task_control('check');
cache=struct('Complete',true,'Key',key,'Signature',signature,'SourceIdentity',prepared.SourceIdentity, ...
 'FullField',full,'Network',network,'Units','px'); %#ok<NASGU>
tmp=[tempname(cacheRoot) '.mat'];cleanup=onCleanup(@() remove_temp(tmp)); %#ok<NASGU>
save(tmp,'cache','-v7');dsap_task_control('check');[ok,message]=movefile(tmp,file,'f');assert(ok,'%s',message);
prepared.Network=network;prepared.Available=true;prepared.GeometryCacheHit=false;
end
function remove_temp(file)
if isfile(file),delete(file);end
end
