function [semantic,issues]=dsap_timeslice_semantics(entries)
% Legacy semantic mapping v1. Exact codes only; Side never implies orientation.
    version='LegacyTIMESlice-semantic-v1';issues={};
    template=struct('Version',version,'Role','','Side','Unknown','Adopted',false, ...
        'NormalizedColor','','Origin',struct());
    semantic=repmat(template,numel(entries),1);
    if isempty(entries),issues={'NoCurrentROIs'};return;end
    assert(all(isfield(entries,{'roiId','baseline','visible','color','serialColor'})), ...
        'DSAP:LegacyMetadata','Fresh ROI and Serial color metadata are required.');
    if numel(unique({entries.roiId}))~=numel(entries),issues{end+1}='DuplicateROIIds';end
    for k=1:numel(entries)
        e=entries(k);assert(isscalar(e.baseline)&&ismember(e.baseline,[false true])&& ...
            isscalar(e.visible)&&ismember(e.visible,[false true]), ...
            'DSAP:LegacyMetadata','baseline and visible must be Boolean values.');
        s=template;s.Origin=e;s.NormalizedColor=upper(strtrim(char(e.color)));
        if e.baseline,s.Role='AIF';
        elseif strcmp(s.NormalizedColor,'#009688'),s.Role='PrimaryTissue';
        else,s.Role='OtherTissue';end
        switch upper(strtrim(char(e.serialColor)))
            case {'#E91E63','#F44336'},s.Side='Affected';
            case '#2196F3',s.Side='Contralateral';
        end
        s.Adopted=logical(e.visible)&&~strcmp(s.Role,'OtherTissue');semantic(k)=s;
        if ~e.visible&&~strcmp(s.Role,'OtherTissue'),issues{end+1}=['HiddenRequiredROI:' e.roiId];end %#ok<AGROW>
    end
    if nnz(strcmp({semantic.Role},'AIF'))~=1,issues{end+1}='ExactlyOneBaselineRequired';end
    if ~any(strcmp({semantic.Role},'PrimaryTissue')),issues{end+1}='NoPrimaryTissue009688';end
    if any(strcmp({semantic.Side},'Unknown')),issues{end+1}='UnknownSerialSide';end
    if numel(unique({semantic.Side}))~=1,issues{end+1}='MixedSerialSides';end
end
