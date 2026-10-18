function [mask,tissue,model,features,cancelled,qc]=dsap_cave_production_review(reference,aif,brain,scope,model,features)
% Production QC is read-only; no reclassification or manual correction.
    empty=false(size(aif));
    % Preserve the old review's accept-with-no-edits path, including metadata.
    [mask,tissue,model,features]=dsap_apply_cave_corrections(model,features,empty,empty,scope,brain,aif);
    if dsap_workspace_bridge('active')
        choice=dsap_workspace_bridge('cave',reference,mask);
    else
    fig=figure('Name','CAVE · 只读 QC','NumberTitle','off','Color','w');
    cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    ax=axes(fig,'Position',[.05 .22 .90 .73]);imshow(reference,[],'Parent',ax);hold(ax,'on');
    visboundaries(ax,mask,'Color',[1 .2 .1]);title(ax,'自动 CAVE 血管边界：只读审核');
    choice=dsap_wait_for_review_choice(fig,'不修改模型输出；异常标记仅记录 QC。', ...
        {'接受','accept';'标记异常并接受','flag';'取消分析','cancel'});
    end
    cancelled=~ismember(choice,{'accept','flag'});
    qc=struct('Mode','ProductionReadOnly','FlaggedAbnormal',strcmp(choice,'flag'), ...
        'Accepted',~cancelled,'TimestampUTC',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
end
