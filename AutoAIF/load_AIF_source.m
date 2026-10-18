function [mask,network,provenance]=load_AIF_source(filename,identity,shape)
% Require byte-identical DSA identity before reusing a saved vessel mask.
fields=whos('-file',filename);names=intersect({fields.name},{'source_identity','source_file','large_vessel_mask','cave_full_field','vessel_features','AutoAIFNetwork'});
r=load(filename,names{:});
if isfield(r,'source_identity'),saved=r.source_identity;
elseif isfield(r,'source_file')&&isfile(r.source_file),saved=dsap_source_identity(r.source_file);
else,error('AutoAIF:Identity','Saved vessel source has no verifiable DSA identity.');end
assert(strcmp(saved.SHA256,identity.SHA256),'AutoAIF:Identity','Vessel result belongs to another DSA sequence.');
mask=[];field='';network=[];
choices={};labels={};
if isfield(r,'cave_full_field')&&isfield(r.cave_full_field,'ArteryMask')
 choices{end+1}=r.cave_full_field.ArteryMask;labels{end+1}='cave_full_field.ArteryMask';
end
if isfield(r,'vessel_features')&&isfield(r.vessel_features,'ArteryMask')
 choices{end+1}=r.vessel_features.ArteryMask;labels{end+1}='vessel_features.ArteryMask';
end
if isfield(r,'large_vessel_mask')
 choices{end+1}=r.large_vessel_mask;labels{end+1}='large_vessel_mask';
end
for k=1:numel(choices)
 value=choices{k};if isequal(size(value),shape)&&all(isfinite(value),'all')&&any(value,'all'),mask=value;field=labels{k};break;end
end
assert(isequal(size(mask),shape)&&all(isfinite(mask),'all')&&any(mask,'all'),'AutoAIF:Mask','No matching existing vessel mask.');
mask=logical(mask);if isfield(r,'AutoAIFNetwork'),network=r.AutoAIFNetwork;end
provenance=struct('File',filename,'MaskField',field,'SourceIdentity',saved,'NetworkReused',~isempty(network));
end
