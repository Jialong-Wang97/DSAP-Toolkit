function prepared=dsap_prepare_analysis(source,shape,polarity,identity)
% ROI-independent whole-field vascular preparation; scientific scope stays downstream.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'AutoAIF'));
prepared=struct('SourceIdentity',identity,'FullField',[],'WorkerJob','','Network',[], ...
 'Available',false,'Reason','','CacheFile','','GeometryCacheHit',false);
try
 dsap_workspace_bridge('stage','Analysis preparation · 血管');dsap_task_control('check');
 [full,job]=dsap_cave_full_field(source,shape,polarity,~dsap_workspace_bridge('active'));
 assert(strcmp(full.Provenance.source_sha256,identity.SHA256),'DSAP:PreparationSource','准备期间 DSA 来源改变。');
 prepared.FullField=full;prepared.WorkerJob=job;
 dsap_workspace_bridge('stage','Analysis preparation · 中心线 / 半径');
 prepared=dsap_prepare_vascular_geometry(prepared);
catch e
 if ismember(e.identifier,{'DSAP:Cancelled','DSAP:StaleDraft'}),rethrow(e);end
 prepared.Reason=e.message;fprintf(2,'Analysis preparation: %s\n',getReport(e,'extended','hyperlinks','off'));
end
dsap_task_control('check');
end
