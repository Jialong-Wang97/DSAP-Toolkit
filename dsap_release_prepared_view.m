function dsap_release_prepared_view(view)
    if isfield(view,'Workspace')&&view.Workspace,return;end
% Cancel/error before ResultReady must not retain hidden placeholder graphics.
    for name={'Perfusion','Table'}
        if isfield(view,name{1})
            fig=view.(name{1});
            if isgraphics(fig)&&~isappdata(fig,'DSAPResultOwnerId'),delete(fig);end
        end
    end
end
