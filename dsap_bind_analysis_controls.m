function dsap_bind_analysis_controls(state)
    fig=state.View.Table;if ~isgraphics(fig),return;end
    h=getappdata(fig,'DSAPResultControls');
    if ~isfield(h,'Edit')||~isgraphics(h.Edit)
        h.Edit=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.59 .025 .17 .09], ...
            'String','编辑组织 ROI','Callback',@dsap_edit_tissue_callback);
        h.Status.Position=[.01 .02 .56 .10];setappdata(fig,'DSAPResultControls',h);
        if isappdata(fig,'DSAPCriticalView')
            h.Edit.Position=[.59 .018 .17 .04];h.Status.Position=[.01 .01 .54 .05];
        end
    end
    setappdata(h.Edit,'SessionToken',struct('SessionId',state.Id,'Revision',state.Revision, ...
        'UpstreamSignature',state.UpstreamSignature));
    h.Edit.Enable='on';
    if isfield(state.Result,'timeslice_import'),h.Edit.String='替换组织 ROI…';end
    setappdata(h.Export,'OutputDirectory',state.OutputDirectory);
    id=state.Id;fig.DeleteFcn=@(~,~) dsap_analysis_session('release',id);
end
