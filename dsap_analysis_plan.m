function [geometry,stats]=dsap_analysis_plan(state,request)
% Strict R1 admission; never silently fall back to R2 or a full workflow.
    allowed={'SessionId','Revision','UpstreamSignature','Partition','TimesliceImport'};
    assert(all(ismember(fieldnames(request),allowed)),'DSAP:UnsupportedEdit','R1 请求包含非组织 ROI 变更。');
    assert(strcmp(request.SessionId,state.Id)&&request.Revision==state.Revision, ...
        'DSAP:StaleCallback','请求属于旧患者或旧 revision。');
    assert(strcmp(request.UpstreamSignature,state.UpstreamSignature)&& ...
        strcmp(dsap_analysis_upstream(state.Result,state.Source),state.UpstreamSignature), ...
        'DSAP:UpstreamChanged','上游 signatures 已改变，不能使用 R1。');
    r=state.Result;geometry=struct();
    if isfield(r,'partition')
        assert(isfield(request,'Partition')&&~isfield(request,'TimesliceImport'),'DSAP:ROIMode','组织类型不匹配。');
        p=request.Partition;
        assert(isequal(p.CranialLimits,r.cranial_limits),'DSAP:UpstreamChanged','R1 不允许修改上下限。');
        assert(isequal(p.Confirmed,true),'DSAP:Unconfirmed','只提交用户确认的几何。');
        p2=dsap_partition_from_controls(p.OuterControlPoints,p.InnerControlPoints,size(r.aif_mask),r.cranial_limits);
        p2.Confirmed=true;if isfield(p,'TemplateFitBox'),p2.TemplateFitBox=p.TemplateFitBox;end
        assert(isequal(p2.OuterMask,state.Cache.Domain),'DSAP:R2Required','OuterMask 改变，需要 R2；本次未执行任何重算。');
        geometry.partition=p2;
        stats=dsap_partition_statistics(p2,r.large_vessel_mask,r.aif_mask,state.NumericalValid,r.signal_quality_features.NonfiniteInputMask);
    else
        assert(isfield(request,'TimesliceImport')&&~isfield(request,'Partition'),'DSAP:ROIMode','组织类型不匹配。');
        imported=request.TimesliceImport;old=r.timeslice_import;
        assert(isequal(imported.Confirmed,true),'DSAP:Unconfirmed','导入组织 ROI 必须确认。');
        assert(isequaln(imported.AIFMask,old.AIFMask)&&isequaln(imported.AIFEntry,old.AIFEntry), ...
            'DSAP:UpstreamChanged','R1 不允许修改导入 AIF。');
        % Tissue masks/names may change; source/provenance and all other inputs may not.
        protected=setdiff(fieldnames(old),{'Masks','Names','Entries'});
        assert(all(isfield(imported,protected)),'DSAP:UpstreamChanged','导入来源信息缺失。');
        for k=1:numel(protected),assert(isequaln(old.(protected{k}),imported.(protected{k})),'DSAP:UpstreamChanged','导入上游信息改变。');end
        union=false(size(r.aif_mask));for k=1:numel(imported.Masks),union=union|logical(imported.Masks{k})&r.cranial_limit_mask;end
        assert(isequal(union,state.Cache.Domain),'DSAP:R2Required','组织 union 改变，需要 R2；本次未执行任何重算。');
        geometry.timeslice_import=imported;
        stats=dsap_imported_statistics(imported,r.cranial_limit_mask,r.large_vessel_mask,r.aif_mask,state.NumericalValid,r.signal_quality_features.NonfiniteInputMask);
    end
end
